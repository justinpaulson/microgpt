# frozen_string_literal: true

require_relative 'microgpt/tensor'
require_relative 'microgpt/config'
require_relative 'microgpt/tokenizer'
require_relative 'microgpt/bpe'
require_relative 'microgpt/model'
require_relative 'microgpt/trainer'
require_relative 'microgpt/checkpoint'
require_relative 'microgpt/chat'
require_relative 'microgpt/fused_trainer'
require_relative 'microgpt/native_ops' # C extension override (falls back to pure Ruby)
