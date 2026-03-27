# frozen_string_literal: true

module MicroGPT
  class Trainer
    attr_reader :step, :corpus

    def initialize(model, lr: 1e-3, beta1: 0.9, beta2: 0.99, eps: 1e-8)
      @model = model
      @lr = lr
      @beta1 = beta1
      @beta2 = beta2
      @eps = eps
      @step = 0
      @corpus = [] # flat array of byte tokens
      @adam_m = model.param_tensors.map { |p| Array.new(p.data.size, 0.0) }
      @adam_v = model.param_tensors.map { |p| Array.new(p.data.size, 0.0) }
    end

    # Add text to the training corpus (encodes in chunks for progress reporting)
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

    # Run a single training step on a random window from the corpus.
    # Returns the loss value, or nil if corpus is too small.
    def train_step
      bs = @model.config.block_size
      return nil if @corpus.length < bs + 1

      idx = rand(@corpus.length - bs - 1)
      tokens = @corpus[idx, bs]
      targets = @corpus[idx + 1, bs]

      loss = @model.forward(tokens, targets)
      loss.backward
      adam_update
      @step += 1
      loss.data[0]
    end

    # Serialize trainer state for checkpointing
    def state
      {
        step: @step,
        corpus: @corpus,
        lr: @lr,
        beta1: @beta1,
        beta2: @beta2,
        eps: @eps,
        adam_m: @adam_m,
        adam_v: @adam_v,
      }
    end

    # Restore trainer state from checkpoint
    def restore_state(s)
      @step = s[:step]
      @corpus = s[:corpus]
      @lr = s[:lr] if s[:lr]
      @beta1 = s[:beta1] if s[:beta1]
      @beta2 = s[:beta2] if s[:beta2]
      @eps = s[:eps] if s[:eps]
      @adam_m = s[:adam_m]
      @adam_v = s[:adam_v]
    end

    private

    def adam_update
      params = @model.param_tensors
      bc1 = 1.0 / (1.0 - @beta1**(@step + 1))
      bc2 = 1.0 / (1.0 - @beta2**(@step + 1))
      ob1 = 1.0 - @beta1
      ob2 = 1.0 - @beta2

      params.each_with_index do |p, pi|
        m_buf = @adam_m[pi]; v_buf = @adam_v[pi]
        i = 0; n = p.data.size
        while i < n
          g = p.grad[i]
          m_buf[i] = @beta1 * m_buf[i] + ob1 * g
          v_buf[i] = @beta2 * v_buf[i] + ob2 * g * g
          p.data[i] -= @lr * (m_buf[i] * bc1) / (Math.sqrt(v_buf[i] * bc2) + @eps)
          p.grad[i] = 0.0
          i += 1
        end
      end
    end
  end
end
