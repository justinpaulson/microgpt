# frozen_string_literal: true
# MicroGPT trained on rhyming word pairs
# Learns character-level patterns of rhyming from the CMU Pronouncing Dictionary

require 'open-uri'

srand(42)

# --- Build rhyming pair dataset from CMU Pronouncing Dictionary ---
cmu_file = 'cmudict.dict'
unless File.exist?(cmu_file)
  puts "downloading CMU pronouncing dictionary..."
  url = 'https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict'
  File.write(cmu_file, URI.open(url).read)
end

puts "building rhyming pair dataset..."

# Parse CMU dict: word -> phoneme list
words = {}
File.readlines(cmu_file).each do |line|
  next if line.start_with?(';;;')
  parts = line.strip.split
  next if parts.length < 2
  word = parts[0].downcase
  next if word.include?('(') # skip alternate pronunciations
  next if word.length > 6    # keep short words for 16-char context
  next if word.length < 2
  phonemes = parts[1..]
  words[word] = phonemes
end

# Group by rhyming ending (last vowel + everything after it)
rhyme_groups = Hash.new { |h, k| h[k] = [] }
words.each do |word, phonemes|
  # Find last stressed vowel and take everything from there
  last_vowel_idx = nil
  phonemes.each_with_index do |p, i|
    # Vowels have stress markers (digits)
    last_vowel_idx = i if p.match?(/\d/)
  end
  next unless last_vowel_idx

  # Strip stress markers for grouping
  ending = phonemes[last_vowel_idx..].map { |p| p.gsub(/\d/, '') }.join(' ')
  rhyme_groups[ending] << word
end

# Generate rhyming pairs (word1 word2) where both words rhyme
docs = []
rhyme_groups.each_value do |group|
  next if group.length < 2
  # Generate pairs within each rhyme group
  group.combination(2) do |w1, w2|
    pair = "#{w1} #{w2}"
    next if pair.length > 14 # must fit in 16-char context (+ 2 BOS)
    docs << pair
  end
end

docs.shuffle!
puts "num rhyming pairs: #{docs.length}"
puts "examples: #{docs.first(10).inspect}"

# Save dataset
File.write('rhymes.txt', docs.join("\n"))

# --- Now train MicroGPT on it ---

uchars = docs.join.chars.uniq.sort
BOS = uchars.length
VOCAB_SIZE = uchars.length + 1
puts "vocab size: #{VOCAB_SIZE}"

class Value
  attr_accessor :data, :grad
  attr_reader :_children, :_local_grads

  def initialize(data, children = nil, local_grads = nil)
    @data = data.to_f
    @grad = 0.0
    @_children = children
    @_local_grads = local_grads
  end

  def +(other)
    if other.is_a?(Value)
      Value.new(@data + other.data, [self, other], [1.0, 1.0])
    else
      Value.new(@data + other, [self], [1.0])
    end
  end

  def *(other)
    if other.is_a?(Value)
      Value.new(@data * other.data, [self, other], [other.data, @data])
    else
      Value.new(@data * other, [self], [other.to_f])
    end
  end

  def **(other)
    Value.new(@data**other, [self], [other * @data**(other - 1)])
  end

  def log
    Value.new(Math.log(@data), [self], [1.0 / @data])
  end

  def exp
    e = Math.exp(@data)
    Value.new(e, [self], [e])
  end

  def relu
    Value.new(@data > 0.0 ? @data : 0.0, [self], [@data > 0.0 ? 1.0 : 0.0])
  end

  def sub_scalar(s)
    Value.new(@data - s, [self], [1.0])
  end

  def -@
    Value.new(-@data, [self], [-1.0])
  end

  def -(other)
    if other.is_a?(Value)
      Value.new(@data - other.data, [self, other], [1.0, -1.0])
    else
      Value.new(@data - other, [self], [1.0])
    end
  end

  def /(other)
    if other.is_a?(Value)
      self * (other**-1)
    else
      Value.new(@data / other, [self], [1.0 / other])
    end
  end

  def coerce(other)
    [Value.new(other), self]
  end

  def backward
    topo = []
    visited = {}
    stack = [self]
    until stack.empty?
      v = stack.last
      vid = v.object_id
      unless visited.key?(vid)
        visited[vid] = false
        children = v._children
        if children
          children.each { |child| stack.push(child) unless visited.key?(child.object_id) }
        end
        if stack.last.equal?(v)
          stack.pop
          visited[vid] = true
          topo << v
        end
      else
        stack.pop
        unless visited[vid]
          visited[vid] = true
          topo << v
        end
      end
    end
    @grad = 1.0
    i = topo.size - 1
    while i >= 0
      v = topo[i]
      children = v._children
      if children
        local_grads = v._local_grads
        vgrad = v.grad
        j = 0
        while j < children.size
          children[j].grad += local_grads[j] * vgrad
          j += 1
        end
      end
      i -= 1
    end
  end
end

N_LAYER = 1
N_EMBD = 16
BLOCK_SIZE = 16
N_HEAD = 4
HEAD_DIM = N_EMBD / N_HEAD
INV_SQRT_HEAD_DIM = 1.0 / Math.sqrt(HEAD_DIM)

def gauss(mean, std)
  u1 = rand
  u2 = rand
  z = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
  mean + std * z
end

def make_matrix(nout, nin, std = 0.08)
  Array.new(nout) { Array.new(nin) { Value.new(gauss(0, std)) } }
end

STATE_DICT = {
  'wte' => make_matrix(VOCAB_SIZE, N_EMBD),
  'wpe' => make_matrix(BLOCK_SIZE, N_EMBD),
  'lm_head' => make_matrix(VOCAB_SIZE, N_EMBD)
}

LAYER_KEYS = N_LAYER.times.map do |i|
  { wq: "layer#{i}.attn_wq".freeze, wk: "layer#{i}.attn_wk".freeze,
    wv: "layer#{i}.attn_wv".freeze, wo: "layer#{i}.attn_wo".freeze,
    fc1: "layer#{i}.mlp_fc1".freeze, fc2: "layer#{i}.mlp_fc2".freeze }
end

N_LAYER.times do |i|
  lk = LAYER_KEYS[i]
  STATE_DICT[lk[:wq]] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT[lk[:wk]] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT[lk[:wv]] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT[lk[:wo]] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT[lk[:fc1]] = make_matrix(4 * N_EMBD, N_EMBD)
  STATE_DICT[lk[:fc2]] = make_matrix(N_EMBD, 4 * N_EMBD)
end

PARAMS = STATE_DICT.values.flat_map { |mat| mat.flat_map { |row| row } }
puts "num params: #{PARAMS.length}"

def linear(x, w)
  xlen = x.size
  w.map do |wo|
    acc = wo[0] * x[0]
    i = 1
    while i < xlen
      acc = acc + wo[i] * x[i]
      i += 1
    end
    acc
  end
end

def softmax(logits)
  max_val = -Float::INFINITY
  logits.each { |v| max_val = v.data if v.data > max_val }
  exps = logits.map { |val| val.sub_scalar(max_val).exp }
  total = exps[0]
  i = 1
  while i < exps.size
    total = total + exps[i]
    i += 1
  end
  exps.map { |e| e / total }
end

def rmsnorm(x)
  n = x.length
  acc = x[0] * x[0]
  i = 1
  while i < n
    acc = acc + x[i] * x[i]
    i += 1
  end
  ms = acc / n
  scale = (ms + 1e-5)**-0.5
  x.map { |xi| xi * scale }
end

def gpt(token_id, pos_id, keys, values)
  tok_emb = STATE_DICT['wte'][token_id]
  pos_emb = STATE_DICT['wpe'][pos_id]
  x = Array.new(N_EMBD) { |i| tok_emb[i] + pos_emb[i] }
  x = rmsnorm(x)

  N_LAYER.times do |li|
    lk = LAYER_KEYS[li]
    x_residual = x
    x = rmsnorm(x)
    q = linear(x, STATE_DICT[lk[:wq]])
    k = linear(x, STATE_DICT[lk[:wk]])
    v = linear(x, STATE_DICT[lk[:wv]])
    keys[li] << k
    values[li] << v

    x_attn = Array.new(N_EMBD)
    N_HEAD.times do |h|
      hs = h * HEAD_DIM
      n_kv = keys[li].size
      attn_logits = Array.new(n_kv)
      t = 0
      while t < n_kv
        kt = keys[li][t]
        acc = q[hs] * kt[hs]
        j = 1
        while j < HEAD_DIM
          acc = acc + q[hs + j] * kt[hs + j]
          j += 1
        end
        attn_logits[t] = acc * INV_SQRT_HEAD_DIM
        t += 1
      end
      attn_weights = softmax(attn_logits)
      j = 0
      while j < HEAD_DIM
        acc = attn_weights[0] * values[li][0][hs + j]
        t = 1
        while t < n_kv
          acc = acc + attn_weights[t] * values[li][t][hs + j]
          t += 1
        end
        x_attn[hs + j] = acc
        j += 1
      end
    end

    x = linear(x_attn, STATE_DICT[lk[:wo]])
    i = 0
    while i < N_EMBD
      x[i] = x[i] + x_residual[i]
      i += 1
    end

    x_residual = x
    x = rmsnorm(x)
    x = linear(x, STATE_DICT[lk[:fc1]])
    x.map!(&:relu)
    x = linear(x, STATE_DICT[lk[:fc2]])
    i = 0
    while i < N_EMBD
      x[i] = x[i] + x_residual[i]
      i += 1
    end
  end

  linear(x, STATE_DICT['lm_head'])
end

def weighted_choice(weights)
  total = weights.sum
  r = rand * total
  cumulative = 0.0
  weights.each_with_index do |w, i|
    cumulative += w
    return i if r <= cumulative
  end
  weights.length - 1
end

# Adam optimizer
learning_rate = 0.01
beta1 = 0.85
beta2 = 0.99
eps_adam = 1e-8
m = Array.new(PARAMS.length, 0.0)
v = Array.new(PARAMS.length, 0.0)
num_params = PARAMS.length

num_steps = (ENV['NUM_STEPS'] || 3000).to_i
num_steps.times do |step|
  doc = docs[step % docs.length]
  tokens = [BOS] + doc.chars.map { |ch| uchars.index(ch) } + [BOS]
  n = [BLOCK_SIZE, tokens.length - 1].min

  keys = Array.new(N_LAYER) { [] }
  vals = Array.new(N_LAYER) { [] }
  losses = []

  n.times do |pos_id|
    token_id = tokens[pos_id]
    target_id = tokens[pos_id + 1]
    logits = gpt(token_id, pos_id, keys, vals)
    probs = softmax(logits)
    loss_t = -probs[target_id].log
    losses << loss_t
  end

  loss_sum = losses[0]
  li = 1
  while li < losses.size
    loss_sum = loss_sum + losses[li]
    li += 1
  end
  loss = loss_sum / n
  loss.backward

  lr_t = learning_rate * (1.0 - step.to_f / num_steps)
  one_minus_beta1 = 1.0 - beta1
  one_minus_beta2 = 1.0 - beta2
  bias_correction1 = 1.0 / (1.0 - beta1**(step + 1))
  bias_correction2 = 1.0 / (1.0 - beta2**(step + 1))

  i = 0
  while i < num_params
    p = PARAMS[i]
    g = p.grad
    m[i] = beta1 * m[i] + one_minus_beta1 * g
    v[i] = beta2 * v[i] + one_minus_beta2 * g * g
    m_hat = m[i] * bias_correction1
    v_hat = v[i] * bias_correction2
    p.data -= lr_t * m_hat / (Math.sqrt(v_hat) + eps_adam)
    p.grad = 0.0
    i += 1
  end

  if (step + 1) % 100 == 0 || step == 0
    print "\rstep #{(step + 1).to_s.rjust(4)} / #{num_steps.to_s.rjust(4)} | loss #{format('%.4f', loss.data)}"
  end
end

# Inference
temperature = 0.5
inv_temp = 1.0 / temperature
puts "\n\n--- generated rhyming pairs ---"
40.times do |sample_idx|
  keys = Array.new(N_LAYER) { [] }
  vals = Array.new(N_LAYER) { [] }
  token_id = BOS
  sample = []

  BLOCK_SIZE.times do |pos_id|
    logits = gpt(token_id, pos_id, keys, vals)
    probs = softmax(logits.map { |l| l * inv_temp })
    token_id = weighted_choice(probs.map(&:data))

    break if token_id == BOS
    sample << uchars[token_id]
  end

  result = sample.join
  words = result.split(' ')
  # Mark pairs where endings match (visual indicator of rhyming)
  rhyme_marker = if words.length == 2
    w1, w2 = words
    suffix_len = [w1.length, w2.length, 3].min
    matching = (1..suffix_len).count { |i| w1[-i] == w2[-i] }
    matching >= 2 ? " *" : ""
  else
    ""
  end
  puts "  #{(sample_idx + 1).to_s.rjust(2)}: #{result}#{rhyme_marker}"
end
