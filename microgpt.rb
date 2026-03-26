# The most atomic way to train and run inference for a GPT in pure, dependency-free Ruby.
# This file is the complete algorithm.
# Everything else is just efficiency.
# @karpathy (original Python), re-created in Ruby

require 'open-uri'

srand(42) # Let there be order among chaos

# Let there be a Dataset `docs`: list of documents (e.g. a list of names)
unless File.exist?('input.txt')
  names_url = 'https://raw.githubusercontent.com/karpathy/makemore/988aa59/names.txt'
  File.write('input.txt', URI.open(names_url).read)
end

docs = File.readlines('input.txt').map(&:strip).reject(&:empty?)
docs.shuffle!
puts "num docs: #{docs.length}"

# Let there be a Tokenizer
uchars = docs.join.chars.uniq.sort
BOS = uchars.length
VOCAB_SIZE = uchars.length + 1
puts "vocab size: #{VOCAB_SIZE}"

# Let there be Autograd
class Value
  attr_accessor :data, :grad
  attr_reader :_children, :_local_grads

  def initialize(data, children = [], local_grads = [])
    @data = data.to_f
    @grad = 0.0
    @_children = children
    @_local_grads = local_grads
  end

  def +(other)
    other = Value.new(other) unless other.is_a?(Value)
    Value.new(@data + other.data, [self, other], [1.0, 1.0])
  end

  def *(other)
    other = Value.new(other) unless other.is_a?(Value)
    Value.new(@data * other.data, [self, other], [other.data, @data])
  end

  def **(other)
    Value.new(@data**other, [self], [other * @data**(other - 1)])
  end

  def log
    Value.new(Math.log(@data), [self], [1.0 / @data])
  end

  def exp
    Value.new(Math.exp(@data), [self], [Math.exp(@data)])
  end

  def relu
    Value.new([@data, 0.0].max, [self], [@data > 0 ? 1.0 : 0.0])
  end

  def -@
    self * -1
  end

  def -(other)
    self + (-other)
  end

  def /(other)
    other = Value.new(other) unless other.is_a?(Value)
    self * (other**-1)
  end

  def coerce(other)
    [Value.new(other), self]
  end

  def backward
    topo = []
    visited = Set.new

    build_topo = ->(v) {
      unless visited.include?(v.object_id)
        visited.add(v.object_id)
        v._children.each { |child| build_topo.call(child) }
        topo << v
      end
    }

    build_topo.call(self)
    @grad = 1.0
    topo.reverse_each do |v|
      v._children.zip(v._local_grads).each do |child, local_grad|
        child.grad += local_grad * v.grad
      end
    end
  end
end

require 'set'

# Initialize parameters
N_LAYER = 1
N_EMBD = 16
BLOCK_SIZE = 16
N_HEAD = 4
HEAD_DIM = N_EMBD / N_HEAD

def make_matrix(nout, nin, std = 0.08)
  Array.new(nout) { Array.new(nin) { Value.new(gauss(0, std)) } }
end

# Box-Muller transform for Gaussian random numbers
def gauss(mean, std)
  u1 = rand
  u2 = rand
  z = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
  mean + std * z
end

STATE_DICT = {
  'wte' => make_matrix(VOCAB_SIZE, N_EMBD),
  'wpe' => make_matrix(BLOCK_SIZE, N_EMBD),
  'lm_head' => make_matrix(VOCAB_SIZE, N_EMBD)
}

N_LAYER.times do |i|
  STATE_DICT["layer#{i}.attn_wq"] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT["layer#{i}.attn_wk"] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT["layer#{i}.attn_wv"] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT["layer#{i}.attn_wo"] = make_matrix(N_EMBD, N_EMBD)
  STATE_DICT["layer#{i}.mlp_fc1"] = make_matrix(4 * N_EMBD, N_EMBD)
  STATE_DICT["layer#{i}.mlp_fc2"] = make_matrix(N_EMBD, 4 * N_EMBD)
end

PARAMS = STATE_DICT.values.flat_map { |mat| mat.flat_map { |row| row } }
puts "num params: #{PARAMS.length}"

# Define model architecture
def linear(x, w)
  w.map { |wo| wo.zip(x).map { |wi, xi| wi * xi }.reduce(:+) }
end

def softmax(logits)
  max_val = logits.map(&:data).max
  exps = logits.map { |val| (val - max_val).exp }
  total = exps.reduce(:+)
  exps.map { |e| e / total }
end

def rmsnorm(x)
  ms = x.map { |xi| xi * xi }.reduce(:+) / x.length
  scale = (ms + 1e-5)**-0.5
  x.map { |xi| xi * scale }
end

def gpt(token_id, pos_id, keys, values)
  tok_emb = STATE_DICT['wte'][token_id]
  pos_emb = STATE_DICT['wpe'][pos_id]
  x = tok_emb.zip(pos_emb).map { |t, p| t + p }
  x = rmsnorm(x)

  N_LAYER.times do |li|
    # Multi-head Attention block
    x_residual = x
    x = rmsnorm(x)
    q = linear(x, STATE_DICT["layer#{li}.attn_wq"])
    k = linear(x, STATE_DICT["layer#{li}.attn_wk"])
    v = linear(x, STATE_DICT["layer#{li}.attn_wv"])

    keys[li] << k
    values[li] << v

    x_attn = []
    N_HEAD.times do |h|
      hs = h * HEAD_DIM
      q_h = q[hs, HEAD_DIM]
      k_h = keys[li].map { |ki| ki[hs, HEAD_DIM] }
      v_h = values[li].map { |vi| vi[hs, HEAD_DIM] }

      attn_logits = k_h.length.times.map do |t|
        HEAD_DIM.times.map { |j| q_h[j] * k_h[t][j] }.reduce(:+) / HEAD_DIM**0.5
      end
      attn_weights = softmax(attn_logits)
      head_out = HEAD_DIM.times.map do |j|
        v_h.length.times.map { |t| attn_weights[t] * v_h[t][j] }.reduce(:+)
      end
      x_attn.concat(head_out)
    end

    x = linear(x_attn, STATE_DICT["layer#{li}.attn_wo"])
    x = x.zip(x_residual).map { |a, b| a + b }

    # MLP block
    x_residual = x
    x = rmsnorm(x)
    x = linear(x, STATE_DICT["layer#{li}.mlp_fc1"])
    x = x.map(&:relu)
    x = linear(x, STATE_DICT["layer#{li}.mlp_fc2"])
    x = x.zip(x_residual).map { |a, b| a + b }
  end

  linear(x, STATE_DICT['lm_head'])
end

# Weighted random sampling (like Python's random.choices)
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

# Training loop
num_steps = (ENV['NUM_STEPS'] || 1000).to_i
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

  loss = (1.0 / n) * losses.reduce(:+)
  loss.backward

  lr_t = learning_rate * (1.0 - step.to_f / num_steps)
  PARAMS.each_with_index do |p, i|
    m[i] = beta1 * m[i] + (1 - beta1) * p.grad
    v[i] = beta2 * v[i] + (1 - beta2) * p.grad**2
    m_hat = m[i] / (1 - beta1**(step + 1))
    v_hat = v[i] / (1 - beta2**(step + 1))
    p.data -= lr_t * m_hat / (v_hat**0.5 + eps_adam)
    p.grad = 0.0
  end

  print "\rstep #{(step + 1).to_s.rjust(4)} / #{num_steps.to_s.rjust(4)} | loss #{format('%.4f', loss.data)}"
end

# Inference
temperature = 0.5
puts "\n--- inference (new, hallucinated names) ---"
20.times do |sample_idx|
  keys = Array.new(N_LAYER) { [] }
  vals = Array.new(N_LAYER) { [] }
  token_id = BOS
  sample = []

  BLOCK_SIZE.times do |pos_id|
    logits = gpt(token_id, pos_id, keys, vals)
    probs = softmax(logits.map { |l| l / temperature })
    token_id = weighted_choice(probs.map(&:data))

    break if token_id == BOS
    sample << uchars[token_id]
  end

  puts "sample #{(sample_idx + 1).to_s.rjust(2)}: #{sample.join}"
end
