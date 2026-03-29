# frozen_string_literal: true

module MicroGPT
  PRESETS = {
    tiny:   { n_embd: 32,  n_layer: 2, n_head: 2, block_size: 32 },
    small:  { n_embd: 48,  n_layer: 4, n_head: 4, block_size: 64 },
    medium: { n_embd: 96,  n_layer: 6, n_head: 6, block_size: 128 },
    large:  { n_embd: 192, n_layer: 8, n_head: 8, block_size: 256 },
  }

  Config = Struct.new(:n_embd, :n_layer, :n_head, :block_size, :vocab_size, keyword_init: true) do
    def head_dim
      n_embd / n_head
    end

    def self.preset(name)
      p = PRESETS.fetch(name)
      new(**p, vocab_size: 256)
    end
  end
end
