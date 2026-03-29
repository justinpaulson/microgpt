# frozen_string_literal: true

# FusedTrainer: uses the fused C kernel for the entire training step.
# All computation happens in C — no Ruby↔C conversion during training.

module MicroGPT
  class FusedTrainer
    attr_reader :step, :corpus

    def initialize(config, lr: 1e-3)
      @config = config
      @handle = FusedKernel.init(
        config.n_embd, config.n_layer, config.n_head,
        config.block_size, config.vocab_size, lr
      )
      @corpus = []
      @lr = lr
    end

    def add_text(text)
      chunk_size = Tokenizer.bpe? ? 100_000 : text.length
      i = 0
      while i < text.length
        chunk = text[i, chunk_size]
        @corpus.concat(Tokenizer.encode(chunk))
        i += chunk_size
        if Tokenizer.bpe? && text.length > chunk_size * 5
          print "\r  encoding... #{(i * 100 / text.length).clamp(0, 100)}%"
        end
      end
      puts "\r  encoding... done!        " if Tokenizer.bpe? && text.length > chunk_size * 5
    end

    def train_step
      bs = @config.block_size
      return nil if @corpus.length < bs + 1

      idx = rand(@corpus.length - bs - 1)
      input = @corpus[idx, bs]
      target = @corpus[idx + 1, bs]

      loss = FusedKernel.train_step(@handle, input, target)
      loss
    end

    def step
      FusedKernel.step(@handle)
    end

    # Load params from a Model object (for initializing from existing weights)
    def load_from_model(model)
      params_flat = model.param_tensors.flat_map(&:data)
      FusedKernel.load_params(@handle, params_flat)
    end

    # Get params back as a flat array (for checkpointing)
    def get_params
      FusedKernel.get_params(@handle)
    end

    # Get logits for last position (for generation)
    def forward_logits(tokens)
      FusedKernel.forward(@handle, tokens)
    end

    # Generate text autoregressively
    def generate(prompt_tokens, max_len: 200, temperature: 0.8, stop_sequence: nil)
      tokens = prompt_tokens.dup
      stop_bytes = stop_sequence ? Tokenizer.encode(stop_sequence) : nil

      max_len.times do
        ctx = tokens.last(@config.block_size)
        logits = forward_logits(ctx)

        # Sample from logits
        next_tok = sample_token(logits, temperature)
        tokens << next_tok

        if stop_bytes && tokens.length >= stop_bytes.length
          break if tokens.last(stop_bytes.length) == stop_bytes
        end
      end
      tokens
    end

    # Serialize state for checkpointing
    def state
      {
        step: step,
        corpus: @corpus,
        lr: @lr,
        params: get_params,
        adam_m: FusedKernel.get_adam_state(@handle)[0],
        adam_v: FusedKernel.get_adam_state(@handle)[1],
      }
    end

    def restore_state(s)
      FusedKernel.load_params(@handle, s[:params])
      FusedKernel.set_step(@handle, s[:step])
      @corpus = s[:corpus]
      @lr = s[:lr] if s[:lr]
      if s[:adam_m] && s[:adam_v]
        FusedKernel.set_adam_state(@handle, s[:adam_m], s[:adam_v])
      end
    end

    def free
      FusedKernel.free(@handle)
    end

    private

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
