# frozen_string_literal: true

# Tensor autograd engine for MicroGPT — pure Ruby, no dependencies
# Supports: matmul, add, embedding, rmsnorm, relu, softmax, transpose,
#           causal masking, cross-entropy loss, column split/concat
# Based on the original tensor.rb, wrapped in MicroGPT module with no_grad support.

module MicroGPT
  # Thread-safe no_grad context for inference (skips backward closure creation)
  def self.no_grad
    Thread.current[:microgpt_no_grad] = true
    yield
  ensure
    Thread.current[:microgpt_no_grad] = false
  end

  def self.no_grad?
    Thread.current[:microgpt_no_grad] || false
  end

  class Tensor
    attr_accessor :data, :grad
    attr_reader :shape, :_children, :_backward

    def initialize(data, shape, children = [], &backward)
      @data = data
      @shape = shape
      @grad = nil
      @_children = children
      @_backward = backward
    end

    def ensure_grad
      @grad ||= Array.new(@data.size, 0.0)
    end

    def zero_grad!
      @grad&.fill(0.0)
    end

    def backward
      topo = []
      visited = {}
      stack = [self]
      until stack.empty?
        v = stack.last
        vid = v.object_id
        if visited.key?(vid)
          stack.pop
          if visited[vid] == :seen
            visited[vid] = :done
            topo << v
          end
        else
          visited[vid] = :seen
          v._children.each { |c| stack.push(c) unless visited.key?(c.object_id) }
        end
      end
      ensure_grad
      @grad.fill(0.0)
      @grad[0] = 1.0
      topo.reverse_each { |t| t._backward&.call }
    end
  end

  module Ops
    # Matrix multiply: (M,K) @ (K,N) -> (M,N)
    def self.matmul(a, b)
      m, k = a.shape
      _, n = b.shape
      out_data = Array.new(m * n, 0.0)
      i = 0
      while i < m
        ik = i * k; in_ = i * n
        j = 0
        while j < n
          s = 0.0; p = 0
          while p < k
            s += a.data[ik + p] * b.data[p * n + j]
            p += 1
          end
          out_data[in_ + j] = s
          j += 1
        end
        i += 1
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, [m, n])
      end
      out = nil
      bk = -> {
        a.ensure_grad; b.ensure_grad
        i = 0
        while i < m
          ik = i * k; in_ = i * n
          p = 0
          while p < k
            aip = a.data[ik + p]; da = 0.0; pn = p * n
            j = 0
            while j < n
              d = out.grad[in_ + j]
              da += d * b.data[pn + j]
              b.grad[pn + j] += aip * d
              j += 1
            end
            a.grad[ik + p] += da
            p += 1
          end
          i += 1
        end
      }
      out = Tensor.new(out_data, [m, n], [a, b], &bk)
    end

    # Element-wise add, same shape
    def self.add(a, b)
      n = a.data.size
      out_data = Array.new(n)
      i = 0; while i < n; out_data[i] = a.data[i] + b.data[i]; i += 1; end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, a.shape.dup)
      end
      out = nil
      bk = -> {
        a.ensure_grad; b.ensure_grad
        i = 0
        while i < n; a.grad[i] += out.grad[i]; b.grad[i] += out.grad[i]; i += 1; end
      }
      out = Tensor.new(out_data, a.shape.dup, [a, b], &bk)
    end

    # Lookup rows from embedding table
    def self.embedding(table, indices)
      t = indices.length; _, c = table.shape
      out_data = Array.new(t * c)
      i = 0
      while i < t
        src = indices[i] * c; dst = i * c
        j = 0; while j < c; out_data[dst + j] = table.data[src + j]; j += 1; end
        i += 1
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, [t, c])
      end
      out = nil
      bk = -> {
        table.ensure_grad
        i = 0
        while i < t
          src = indices[i] * c; dst = i * c
          j = 0; while j < c; table.grad[src + j] += out.grad[dst + j]; j += 1; end
          i += 1
        end
      }
      out = Tensor.new(out_data, [t, c], [table], &bk)
    end

    # RMS normalization per row
    def self.rmsnorm(x)
      rows, cols = x.shape
      out_data = Array.new(rows * cols)
      scales = Array.new(rows)
      rows.times do |i|
        off = i * cols; ms = 0.0
        j = 0; while j < cols; ms += x.data[off + j] ** 2; j += 1; end
        ms = ms / cols + 1e-5
        s = 1.0 / Math.sqrt(ms); scales[i] = s
        j = 0; while j < cols; out_data[off + j] = x.data[off + j] * s; j += 1; end
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, x.shape.dup)
      end
      out = nil
      bk = -> {
        x.ensure_grad
        rows.times do |i|
          off = i * cols; s = scales[i]; dot = 0.0
          j = 0; while j < cols; dot += out.grad[off + j] * x.data[off + j]; j += 1; end
          c = s * s * s / cols
          j = 0
          while j < cols
            x.grad[off + j] += s * out.grad[off + j] - x.data[off + j] * c * dot
            j += 1
          end
        end
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    def self.relu(x)
      n = x.data.size
      out_data = Array.new(n)
      i = 0; while i < n; out_data[i] = x.data[i] > 0 ? x.data[i] : 0.0; i += 1; end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, x.shape.dup)
      end
      out = nil
      bk = -> {
        x.ensure_grad
        i = 0; while i < n; x.grad[i] += out.grad[i] if x.data[i] > 0; i += 1; end
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    # Transpose (rows, cols) -> (cols, rows)
    def self.transpose(a)
      rows, cols = a.shape
      out_data = Array.new(rows * cols)
      i = 0
      while i < rows
        j = 0
        while j < cols; out_data[j * rows + i] = a.data[i * cols + j]; j += 1; end
        i += 1
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, [cols, rows])
      end
      out = nil
      bk = -> {
        a.ensure_grad
        i = 0
        while i < cols
          j = 0
          while j < rows; a.grad[j * cols + i] += out.grad[i * rows + j]; j += 1; end
          i += 1
        end
      }
      out = Tensor.new(out_data, [cols, rows], [a], &bk)
    end

    # Scale attention scores and apply causal mask
    def self.scale_and_causal_mask(attn, scale)
      t = attn.shape[0]
      out_data = Array.new(t * t)
      i = 0
      while i < t
        j = 0
        while j < t
          idx = i * t + j
          out_data[idx] = j <= i ? attn.data[idx] * scale : -1e9
          j += 1
        end
        i += 1
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, [t, t])
      end
      out = nil
      bk = -> {
        attn.ensure_grad
        i = 0
        while i < t
          j = 0
          while j <= i; attn.grad[i * t + j] += out.grad[i * t + j] * scale; j += 1; end
          i += 1
        end
      }
      out = Tensor.new(out_data, [t, t], [attn], &bk)
    end

    # Row-wise softmax
    def self.softmax(x)
      rows, cols = x.shape
      out_data = Array.new(rows * cols)
      rows.times do |i|
        off = i * cols; max_val = -Float::INFINITY
        j = 0; while j < cols; v = x.data[off + j]; max_val = v if v > max_val; j += 1; end
        sum = 0.0
        j = 0
        while j < cols; e = Math.exp(x.data[off + j] - max_val); out_data[off + j] = e; sum += e; j += 1; end
        inv = 1.0 / sum
        j = 0; while j < cols; out_data[off + j] *= inv; j += 1; end
      end
      if MicroGPT.no_grad?
        return Tensor.new(out_data, x.shape.dup)
      end
      out = nil
      bk = -> {
        x.ensure_grad
        rows.times do |i|
          off = i * cols; dot = 0.0
          j = 0; while j < cols; dot += out.grad[off + j] * out_data[off + j]; j += 1; end
          j = 0
          while j < cols; x.grad[off + j] += out_data[off + j] * (out.grad[off + j] - dot); j += 1; end
        end
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    # Fused cross-entropy: softmax + negative log-likelihood
    def self.cross_entropy(logits, targets)
      t, v = logits.shape
      probs = Array.new(t * v)
      loss = 0.0
      t.times do |i|
        off = i * v; max_val = -Float::INFINITY
        j = 0; while j < v; val = logits.data[off + j]; max_val = val if val > max_val; j += 1; end
        sum = 0.0
        j = 0
        while j < v; e = Math.exp(logits.data[off + j] - max_val); probs[off + j] = e; sum += e; j += 1; end
        inv = 1.0 / sum
        j = 0; while j < v; probs[off + j] *= inv; j += 1; end
        loss += -Math.log(probs[off + targets[i]] + 1e-10)
      end
      loss /= t
      if MicroGPT.no_grad?
        return Tensor.new([loss], [1, 1])
      end
      out = nil
      bk = -> {
        logits.ensure_grad
        s = out.grad[0] / t
        t.times do |i|
          off = i * v
          j = 0
          while j < v
            logits.grad[off + j] += (probs[off + j] - (j == targets[i] ? 1.0 : 0.0)) * s
            j += 1
          end
        end
      }
      out = Tensor.new([loss], [1, 1], [logits], &bk)
    end

    # Split (T, C) into n_splits tensors of (T, C/n_splits) by columns
    def self.split_cols(a, n_splits)
      t, c = a.shape; hd = c / n_splits
      n_splits.times.map do |h|
        h_off = h * hd
        data = Array.new(t * hd)
        i = 0
        while i < t
          j = 0
          while j < hd; data[i * hd + j] = a.data[i * c + h_off + j]; j += 1; end
          i += 1
        end
        if MicroGPT.no_grad?
          Tensor.new(data, [t, hd])
        else
          out = nil
          bk = -> {
            a.ensure_grad
            i = 0
            while i < t
              j = 0
              while j < hd; a.grad[i * c + h_off + j] += out.grad[i * hd + j]; j += 1; end
              i += 1
            end
          }
          out = Tensor.new(data, [t, hd], [a], &bk)
        end
      end
    end

    # Concatenate tensors along columns: list of (T, hd) -> (T, total_cols)
    def self.concat_cols(tensors)
      t = tensors[0].shape[0]
      parts = tensors.map { |x| x.shape[1] }
      total_c = parts.sum
      data = Array.new(t * total_c)
      offsets = [0]; parts.each { |p| offsets << offsets.last + p }
      i = 0
      while i < t
        tensors.each_with_index do |tensor, h|
          hd = parts[h]; ho = offsets[h]
          j = 0
          while j < hd; data[i * total_c + ho + j] = tensor.data[i * hd + j]; j += 1; end
        end
        i += 1
      end
      if MicroGPT.no_grad?
        return Tensor.new(data, [t, total_c])
      end
      out = nil
      bk = -> {
        tensors.each_with_index do |tensor, h|
          tensor.ensure_grad; hd = parts[h]; ho = offsets[h]
          i = 0
          while i < t
            j = 0
            while j < hd; tensor.grad[i * hd + j] += out.grad[i * total_c + ho + j]; j += 1; end
            i += 1
          end
        end
      }
      out = Tensor.new(data, [t, total_c], tensors, &bk)
    end
  end
end
