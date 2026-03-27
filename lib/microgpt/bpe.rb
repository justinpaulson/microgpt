# frozen_string_literal: true

# Byte Pair Encoding tokenizer for MicroGPT.
# Learns common byte sequences and merges them into single tokens.
# This lets the model think in words/subwords instead of individual characters.

module MicroGPT
  class BPE
    attr_reader :merges, :vocab_size

    def initialize(merges)
      @merges = merges
      @vocab_size = 256 + merges.length

      # Merge priority lookup: [token_a, token_b] -> rank (lower = higher priority)
      @merge_rank = {}
      merges.each_with_index { |(a, b), i| @merge_rank[[a, b]] = i }

      # Decode table: token_id -> byte sequence
      @vocab = (0...256).map { |i| [i] }
      merges.each { |a, b| @vocab << (@vocab[a] + @vocab[b]) }
    end

    # Train BPE on text, learning merge rules from the most frequent byte pairs.
    def self.train(text, num_merges: 2000)
      # Use a sample for efficiency (BPE training is O(n * num_merges))
      sample = text.length > 2_000_000 ? text[0, 2_000_000] : text
      tokens = sample.bytes
      merges = []
      vocab = (0...256).map { |i| [i] }

      puts "training BPE (#{num_merges} merges on #{tokens.length} bytes)..."

      num_merges.times do |i|
        # Count adjacent pairs
        counts = Hash.new(0)
        j = 0
        while j < tokens.length - 1
          counts[[tokens[j], tokens[j + 1]]] += 1
          j += 1
        end

        break if counts.empty?

        # Find most frequent pair
        best_pair, best_count = counts.max_by(&:last)
        break if best_count < 2

        new_id = 256 + i
        merges << best_pair
        vocab << (vocab[best_pair[0]] + vocab[best_pair[1]])

        # Replace all occurrences
        new_tokens = []
        j = 0
        while j < tokens.length
          if j < tokens.length - 1 && tokens[j] == best_pair[0] && tokens[j + 1] == best_pair[1]
            new_tokens << new_id
            j += 2
          else
            new_tokens << tokens[j]
            j += 1
          end
        end
        tokens = new_tokens

        if (i + 1) % 200 == 0 || i + 1 == num_merges
          repr = vocab[new_id].pack("C*").force_encoding("UTF-8") rescue "?"
          compression = (sample.length.to_f / tokens.length).round(2)
          puts "  merge #{(i + 1).to_s.rjust(4)}/#{num_merges}: " \
               "#{repr.inspect.ljust(12)} (count: #{best_count}, compression: #{compression}x)"
        end
      end

      bpe = new(merges)
      puts "  done: vocab_size=#{bpe.vocab_size}, " \
           "compression=#{(sample.length.to_f / tokens.length).round(2)}x"
      bpe
    end

    # Encode text to token IDs.
    # Applies merges sequentially in priority order — equivalent to the iterative
    # "find best merge" approach but O(n * merges) instead of O(n^2).
    def encode(text)
      return [] if text.empty?
      tokens = text.bytes
      @merges.each_with_index do |(a, b), i|
        new_id = 256 + i
        new_tokens = []
        j = 0
        while j < tokens.length
          if j < tokens.length - 1 && tokens[j] == a && tokens[j + 1] == b
            new_tokens << new_id
            j += 2
          else
            new_tokens << tokens[j]
            j += 1
          end
        end
        tokens = new_tokens
      end
      tokens
    end

    # Decode token IDs to string
    def decode(tokens)
      bytes = []
      tokens.each { |t| bytes.concat(@vocab[t]) if t < @vocab.length }
      bytes.pack("C*").force_encoding("UTF-8")
    end

    # Decode but filter to printable characters
    def decode_printable(tokens)
      bytes = []
      tokens.each { |t| bytes.concat(@vocab[t]) if t < @vocab.length }
      bytes.select { |b| (b >= 32 && b <= 126) || b == 10 || b == 9 }
           .pack("C*").force_encoding("UTF-8")
    end

    # Show what a token represents
    def token_to_str(token_id)
      return nil if token_id >= @vocab.length
      @vocab[token_id].pack("C*").force_encoding("UTF-8") rescue "?"
    end

    def save(path)
      File.binwrite(path, Marshal.dump(@merges))
    end

    def self.load(path)
      new(Marshal.load(File.binread(path)))
    end
  end
end
