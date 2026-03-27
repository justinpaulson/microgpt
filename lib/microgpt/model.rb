# frozen_string_literal: true

module MicroGPT
  class Model
    attr_reader :config

    def initialize(config)
      @config = config
      @inv_sqrt_hd = 1.0 / Math.sqrt(config.head_dim)
      init_params
    end

    # Training forward pass — returns loss Tensor (with autograd graph)
    def forward(tokens, targets)
      x = embed(tokens)
      @layers.each { |l| x = transformer_block(x, l) }
      logits = Ops.matmul(x, @lm_head)
      Ops.cross_entropy(logits, targets)
    end

    # Inference forward pass — returns logits array for last position (plain floats)
    def forward_logits(tokens)
      tokens = tokens.last(@config.block_size)
      x = embed(tokens)
      @layers.each { |l| x = transformer_block(x, l) }
      logits = Ops.matmul(x, @lm_head)
      vs = @config.vocab_size
      logits.data[(tokens.length - 1) * vs, vs]
    end

    # Autoregressive text generation
    def generate(prompt_tokens, max_len: 200, temperature: 0.8, stop_sequence: nil)
      tokens = prompt_tokens.dup
      stop_bytes = stop_sequence&.bytes
      MicroGPT.no_grad do
        max_len.times do
          ctx = tokens.last(@config.block_size)
          logits = forward_logits(ctx)
          next_tok = sample_token(logits, temperature)
          tokens << next_tok
          if stop_bytes && tokens.length >= stop_bytes.length
            break if tokens.last(stop_bytes.length) == stop_bytes
          end
        end
      end
      tokens
    end

    # Flat list of all parameter tensors (for optimizer)
    def param_tensors
      [@wte, @wpe, @lm_head] + @layers.flat_map(&:values)
    end

    def num_params
      param_tensors.sum { |p| p.data.size }
    end

    private

    def embed(tokens)
      tok_emb = Ops.embedding(@wte, tokens)
      pos_emb = Ops.embedding(@wpe, (0...tokens.length).to_a)
      Ops.rmsnorm(Ops.add(tok_emb, pos_emb))
    end

    def transformer_block(x, layer)
      # Multi-head causal self-attention
      x_res = x
      x = Ops.rmsnorm(x)
      q = Ops.matmul(x, layer[:wq])
      k = Ops.matmul(x, layer[:wk])
      v = Ops.matmul(x, layer[:wv])

      q_heads = Ops.split_cols(q, @config.n_head)
      k_heads = Ops.split_cols(k, @config.n_head)
      v_heads = Ops.split_cols(v, @config.n_head)

      head_outs = @config.n_head.times.map do |h|
        scores = Ops.matmul(q_heads[h], Ops.transpose(k_heads[h]))
        scores = Ops.scale_and_causal_mask(scores, @inv_sqrt_hd)
        attn = Ops.softmax(scores)
        Ops.matmul(attn, v_heads[h])
      end

      x_attn = Ops.matmul(Ops.concat_cols(head_outs), layer[:wo])
      x = Ops.add(x_attn, x_res)

      # Feed-forward MLP
      x_res = x
      x = Ops.rmsnorm(x)
      x = Ops.relu(Ops.matmul(x, layer[:fc1]))
      x = Ops.matmul(x, layer[:fc2])
      Ops.add(x, x_res)
    end

    def init_params
      c = @config
      @wte = make_param(c.vocab_size, c.n_embd)
      @wpe = make_param(c.block_size, c.n_embd)
      @lm_head = make_param(c.n_embd, c.vocab_size)
      @layers = c.n_layer.times.map do
        { wq: make_param(c.n_embd, c.n_embd),
          wk: make_param(c.n_embd, c.n_embd),
          wv: make_param(c.n_embd, c.n_embd),
          wo: make_param(c.n_embd, c.n_embd),
          fc1: make_param(c.n_embd, 4 * c.n_embd),
          fc2: make_param(4 * c.n_embd, c.n_embd) }
      end
    end

    def make_param(rows, cols, std = 0.02)
      t = Tensor.new(Array.new(rows * cols) { gauss(0, std) }, [rows, cols])
      t.ensure_grad
      t
    end

    def gauss(mean, std)
      u1 = rand; u2 = rand
      Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2) * std + mean
    end

    def sample_token(logits, temperature)
      vs = logits.length
      if temperature <= 0
        logits.each_with_index.max_by(&:first).last
      else
        max_val = -Float::INFINITY
        vs.times { |j| v = logits[j] / temperature; max_val = v if v > max_val }
        probs = Array.new(vs)
        sum = 0.0
        vs.times do |j|
          e = Math.exp(logits[j] / temperature - max_val)
          probs[j] = e; sum += e
        end
        probs.map! { |p| p / sum }
        r = rand; cum = 0.0
        probs.each_with_index { |p, i| cum += p; return i if r <= cum }
        vs - 1
      end
    end
  end
end
