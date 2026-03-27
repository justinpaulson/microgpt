# frozen_string_literal: true

module MicroGPT
  class Chat
    def initialize(model, trainer, checkpoint_path: nil)
      @model = model
      @trainer = trainer
      @checkpoint_path = checkpoint_path
      @training = false
      @train_thread = nil
      @training_mutex = Mutex.new
      @losses = []
    end

    def run
      puts "MicroGPT Chat"
      puts "  model: #{@model.config.n_layer}L/#{@model.config.n_embd}D/#{@model.config.n_head}H | #{@model.num_params} params"
      puts "  corpus: #{@trainer.corpus.length} bytes | step: #{@trainer.step}"
      puts ""
      puts "Commands:"
      puts "  /train <file>   — ingest a text file into the training corpus"
      puts "  /status         — show training progress"
      puts "  /sample [len]   — generate a raw text sample"
      puts "  /save [path]    — save model checkpoint"
      puts "  /temp <value>   — set generation temperature (current: #{@temperature = 0.8})"
      puts "  /quit           — exit"
      puts ""
      puts "Training runs in the background while you type."
      puts "The model learns from your conversations + any ingested files."
      puts ""

      start_training

      loop do
        print "You: "
        $stdout.flush
        input = $stdin.gets
        break if input.nil? # EOF

        input = input.chomp
        next if input.empty?

        case input
        when "/quit", "/exit"
          break
        when "/status"
          show_status
          next
        when /\A\/save(?:\s+(.+))?\z/
          save_checkpoint($1&.strip)
          next
        when /\A\/train\s+(.+)\z/
          ingest_file($1.strip)
          next
        when /\A\/sample(?:\s+(\d+))?\z/
          show_sample(($1 || 200).to_i)
          next
        when /\A\/temp\s+([\d.]+)\z/
          @temperature = $1.to_f
          puts "  temperature set to #{@temperature}\n\n"
          next
        when /\A\//
          puts "  unknown command: #{input}\n\n"
          next
        end

        # Generate a response
        response = nil
        @training_mutex.synchronize do
          response = generate_response(input)
        end

        puts "Bot: #{response}\n\n"

        # Add conversation to corpus so the model learns from it
        conversation = "You: #{input}\nBot: #{response}\n"
        @training_mutex.synchronize do
          @trainer.add_text(conversation)
        end
      end

      stop_training
      auto_save
      puts "Goodbye! (#{@trainer.step} training steps completed)"
    end

    private

    def generate_response(input)
      prompt = "You: #{input}\nBot:"
      prompt_tokens = Tokenizer.encode(prompt)

      output_tokens = @model.generate(
        prompt_tokens,
        max_len: 150,
        temperature: @temperature,
        stop_sequence: "\nYou:"
      )

      response = Tokenizer.decode(output_tokens[prompt_tokens.length..])
      # Clean up: remove trailing turn marker if present
      response = response.split("\nYou:").first || response
      response = response.split("\nBot:").first || response
      response.strip
    end

    def show_sample(len)
      sample = nil
      @training_mutex.synchronize do
        # Start from a newline character
        tokens = @model.generate([10], max_len: len, temperature: @temperature)
        sample = Tokenizer.decode(tokens)
      end
      puts "\n--- sample (#{len} tokens) ---"
      puts sample
      puts "---\n\n"
    end

    def show_status
      if @losses.empty?
        avg_loss = "n/a"
      else
        recent = @losses.last(100)
        avg_loss = format("%.4f", recent.sum / recent.size)
      end
      puts ""
      puts "  step:   #{@trainer.step}"
      puts "  corpus: #{format_bytes(@trainer.corpus.length)}"
      puts "  loss:   #{avg_loss} (avg last 100)"
      puts ""
    end

    def save_checkpoint(path = nil)
      path ||= @checkpoint_path || "checkpoints/model.bin"
      @training_mutex.synchronize do
        size = Checkpoint.save(path, model: @model, trainer: @trainer)
        puts "  saved to #{path} (#{format_bytes(size)})\n\n"
      end
    end

    def auto_save
      return unless @checkpoint_path
      @training_mutex.synchronize do
        Checkpoint.save(@checkpoint_path, model: @model, trainer: @trainer)
        puts "  auto-saved to #{@checkpoint_path}"
      end
    end

    def ingest_file(path)
      unless File.exist?(path)
        puts "  file not found: #{path}\n\n"
        return
      end
      text = File.read(path)
      @training_mutex.synchronize do
        @trainer.add_text(text)
      end
      puts "  ingested #{format_bytes(text.bytesize)} from #{path}\n\n"
    end

    def start_training
      @training = true
      @train_thread = Thread.new do
        while @training
          if @trainer.corpus.length <= @model.config.block_size
            sleep 0.1
            next
          end
          @training_mutex.synchronize do
            loss = @trainer.train_step
            @losses << loss if loss
          end
          Thread.pass
        end
      end
    end

    def stop_training
      @training = false
      @train_thread&.join
    end

    def format_bytes(n)
      if n < 1024
        "#{n}B"
      elsif n < 1024 * 1024
        format("%.1fKB", n / 1024.0)
      else
        format("%.1fMB", n / (1024.0 * 1024))
      end
    end
  end
end
