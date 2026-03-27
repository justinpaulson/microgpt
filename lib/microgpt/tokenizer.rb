# frozen_string_literal: true

# Byte-level tokenizer: each byte (0-255) is a token.
# Handles any text, zero configuration needed.

module MicroGPT
  module Tokenizer
    VOCAB_SIZE = 256

    def self.encode(text)
      text.bytes
    end

    def self.decode(tokens)
      # Filter to printable ASCII + whitespace for clean terminal output
      tokens.select { |t| (t >= 32 && t <= 126) || t == 10 || t == 13 || t == 9 }
            .pack("C*")
            .force_encoding("UTF-8")
    end

    def self.decode_raw(tokens)
      tokens.pack("C*").force_encoding("UTF-8")
    end
  end
end
