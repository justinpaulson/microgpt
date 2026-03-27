# frozen_string_literal: true

# Tokenizer facade: delegates to either byte-level (default) or BPE.
# Swap the backend with Tokenizer.use_bpe(bpe_instance).

module MicroGPT
  module Tokenizer
    @bpe = nil

    def self.use_bpe(bpe)
      @bpe = bpe
    end

    def self.bpe
      @bpe
    end

    def self.bpe?
      !@bpe.nil?
    end

    def self.vocab_size
      @bpe ? @bpe.vocab_size : 256
    end

    def self.encode(text)
      @bpe ? @bpe.encode(text) : text.bytes
    end

    def self.decode(tokens)
      if @bpe
        @bpe.decode_printable(tokens)
      else
        tokens.select { |t| (t >= 32 && t <= 126) || t == 10 || t == 13 || t == 9 }
              .pack("C*")
              .force_encoding("UTF-8")
      end
    end

    def self.decode_raw(tokens)
      @bpe ? @bpe.decode(tokens) : tokens.pack("C*").force_encoding("UTF-8")
    end
  end
end
