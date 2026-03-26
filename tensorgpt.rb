# frozen_string_literal: true
# TensorGPT: Character-level GPT trained on Tiny Shakespeare
# Pure Ruby, no dependencies. Tensor autograd instead of scalar autograd.
# Based on MicroGPT by @karpathy

require_relative 'tensor'
require 'open-uri'

$stdout.sync = true
srand(42)

# ======================== Data ========================

unless File.exist?('shakespeare.txt')
  puts "downloading tiny shakespeare..."
  url = 'https://raw.githubusercontent.com/karpathy/char-rnn/master/data/tinyshakespeare/input.txt'
  File.write('shakespeare.txt', URI.open(url).read)
end

text = File.read('shakespeare.txt')
chars = text.chars.uniq.sort
STOI = chars.each_with_index.to_h
ITOS = chars
VOCAB_SIZE = chars.length
data = text.chars.map { |c| STOI[c] }
split = (data.length * 0.9).to_i
TRAIN_DATA = data[0...split]
puts "dataset: #{text.length} chars | vocab: #{VOCAB_SIZE} | train: #{TRAIN_DATA.length}"

# ======================== Model Config ========================

N_EMBD = 48
N_LAYER = 4
N_HEAD = 4
HEAD_DIM = N_EMBD / N_HEAD
BLOCK_SIZE = 32
INV_SQRT_HD = 1.0 / Math.sqrt(HEAD_DIM)

# ======================== Parameters ========================

def gauss(mean, std)
  u1 = rand; u2 = rand
  Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2) * std + mean
end

def make_param(rows, cols, std = 0.02)
  t = Tensor.new(Array.new(rows * cols) { gauss(0, std) }, [rows, cols])
  t.ensure_grad
  t
end

WTE = make_param(VOCAB_SIZE, N_EMBD)
WPE = make_param(BLOCK_SIZE, N_EMBD)
LM_HEAD = make_param(N_EMBD, VOCAB_SIZE)

LAYERS = N_LAYER.times.map do
  { wq: make_param(N_EMBD, N_EMBD), wk: make_param(N_EMBD, N_EMBD),
    wv: make_param(N_EMBD, N_EMBD), wo: make_param(N_EMBD, N_EMBD),
    fc1: make_param(N_EMBD, 4 * N_EMBD), fc2: make_param(4 * N_EMBD, N_EMBD) }
end

PARAMS = [WTE, WPE, LM_HEAD] + LAYERS.flat_map(&:values)
num_params = PARAMS.sum { |p| p.data.size }
puts "model: #{N_LAYER} layers, #{N_EMBD} embd, #{N_HEAD} heads, #{BLOCK_SIZE} ctx | #{num_params} params"

# ======================== Forward Pass ========================

def transformer_block(x, layer)
  # Multi-head causal self-attention
  x_res = x
  x = Ops.rmsnorm(x)
  q = Ops.matmul(x, layer[:wq])
  k = Ops.matmul(x, layer[:wk])
  v = Ops.matmul(x, layer[:wv])

  q_heads = Ops.split_cols(q, N_HEAD)
  k_heads = Ops.split_cols(k, N_HEAD)
  v_heads = Ops.split_cols(v, N_HEAD)

  head_outs = N_HEAD.times.map do |h|
    scores = Ops.matmul(q_heads[h], Ops.transpose(k_heads[h]))
    scores = Ops.scale_and_causal_mask(scores, INV_SQRT_HD)
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

def forward(tokens, targets)
  tok_emb = Ops.embedding(WTE, tokens)
  pos_emb = Ops.embedding(WPE, (0...tokens.length).to_a)
  x = Ops.add(tok_emb, pos_emb)
  x = Ops.rmsnorm(x)
  LAYERS.each { |layer| x = transformer_block(x, layer) }
  logits = Ops.matmul(x, LM_HEAD)
  Ops.cross_entropy(logits, targets)
end

# ======================== Text Generation ========================

def generate(max_len = 200, temperature = 0.8)
  tokens = [STOI["\n"]]
  max_len.times do
    ctx = tokens.last(BLOCK_SIZE)
    tok_emb = Ops.embedding(WTE, ctx)
    pos_emb = Ops.embedding(WPE, (0...ctx.length).to_a)
    x = Ops.add(tok_emb, pos_emb)
    x = Ops.rmsnorm(x)
    LAYERS.each { |layer| x = transformer_block(x, layer) }
    logits = Ops.matmul(x, LM_HEAD)

    # Sample from last position
    last = (ctx.length - 1) * VOCAB_SIZE
    max_val = -Float::INFINITY
    VOCAB_SIZE.times { |j| v = logits.data[last + j] / temperature; max_val = v if v > max_val }
    probs = Array.new(VOCAB_SIZE)
    sum = 0.0
    VOCAB_SIZE.times do |j|
      e = Math.exp(logits.data[last + j] / temperature - max_val)
      probs[j] = e; sum += e
    end
    probs.map! { |p| p / sum }

    r = rand; cum = 0.0; next_tok = 0
    probs.each_with_index { |p, i| cum += p; (next_tok = i; break) if r <= cum }
    tokens << next_tok
  end
  tokens.map { |t| ITOS[t] }.join
end

# ======================== Training ========================

lr = 1e-3
beta1, beta2, eps = 0.9, 0.99, 1e-8
adam_m = PARAMS.map { |p| Array.new(p.data.size, 0.0) }
adam_v = PARAMS.map { |p| Array.new(p.data.size, 0.0) }
num_steps = (ENV['NUM_STEPS'] || 3000).to_i

puts "training for #{num_steps} steps...\n\n"

# Show untrained sample
puts "=== before training ==="
puts generate(100, 1.0)
puts "=======================\n\n"

t0 = Time.now
num_steps.times do |step|
  # Sample random chunk from training data
  idx = rand(TRAIN_DATA.length - BLOCK_SIZE - 1)
  tokens = TRAIN_DATA[idx, BLOCK_SIZE]
  targets = TRAIN_DATA[idx + 1, BLOCK_SIZE]

  # Forward + backward
  loss = forward(tokens, targets)
  loss.backward

  # Adam update
  lr_t = lr * (1.0 - step.to_f / num_steps)
  bc1 = 1.0 / (1.0 - beta1**(step + 1))
  bc2 = 1.0 / (1.0 - beta2**(step + 1))

  PARAMS.each_with_index do |p, pi|
    m_buf = adam_m[pi]; v_buf = adam_v[pi]
    i = 0; n = p.data.size
    while i < n
      g = p.grad[i]
      m_buf[i] = beta1 * m_buf[i] + (1 - beta1) * g
      v_buf[i] = beta2 * v_buf[i] + (1 - beta2) * g * g
      p.data[i] -= lr_t * (m_buf[i] * bc1) / (Math.sqrt(v_buf[i] * bc2) + eps)
      p.grad[i] = 0.0
      i += 1
    end
  end

  # Logging
  elapsed = Time.now - t0
  ms_per_step = step > 0 ? (elapsed / step * 1000).round : 0
  if step == 0 || (step + 1) % 100 == 0
    print "\rstep #{(step + 1).to_s.rjust(4)}/#{num_steps} | loss #{format('%.4f', loss.data[0])} | #{ms_per_step}ms/step"
  end

  # Generate sample periodically
  if (step + 1) % 500 == 0
    puts "\n\n--- sample @ step #{step + 1} ---"
    puts generate(150, 0.8)
    puts "---\n\n"
  end
end

elapsed = Time.now - t0
puts "\n\ntraining done in #{format('%.1f', elapsed)}s (#{format('%.0f', elapsed / num_steps * 1000)}ms/step)"
puts "\n=== generated shakespeare ==="
3.times do |i|
  puts "\n--- sample #{i + 1} ---"
  puts generate(300, 0.8)
end
