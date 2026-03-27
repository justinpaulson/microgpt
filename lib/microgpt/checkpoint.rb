# frozen_string_literal: true

module MicroGPT
  module Checkpoint
    def self.save(path, model:, trainer:)
      dir = File.dirname(path)
      Dir.mkdir(dir) unless Dir.exist?(dir)

      data = {
        config: {
          n_embd: model.config.n_embd,
          n_layer: model.config.n_layer,
          n_head: model.config.n_head,
          block_size: model.config.block_size,
          vocab_size: model.config.vocab_size,
        },
        weights: model.param_tensors.map { |p| p.data.dup },
        trainer: trainer.state,
        bpe_merges: Tokenizer.bpe? ? Tokenizer.bpe.merges : nil,
      }
      File.binwrite(path, Marshal.dump(data))
      File.size(path)
    end

    def self.load(path)
      data = Marshal.load(File.binread(path))

      # Restore BPE tokenizer if present
      if data[:bpe_merges]
        bpe = BPE.new(data[:bpe_merges])
        Tokenizer.use_bpe(bpe)
      end

      config = Config.new(**data[:config])
      model = Model.new(config)

      # Restore weights
      model.param_tensors.zip(data[:weights]).each do |param, saved_data|
        param.data.replace(saved_data)
      end

      trainer = Trainer.new(model)
      trainer.restore_state(data[:trainer])

      [model, trainer]
    end

    def self.exists?(path)
      File.exist?(path)
    end
  end
end
