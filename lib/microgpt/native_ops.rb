# frozen_string_literal: true

# Load C extension and override Ops with native implementations.
# Falls back to pure Ruby if extension is not compiled.

ext_dir = File.expand_path('../../ext/microgpt', __dir__)
$LOAD_PATH.unshift(ext_dir) unless $LOAD_PATH.include?(ext_dir)

begin
  require 'native'
rescue LoadError
  return # Pure Ruby fallback — no C extension built
end

module MicroGPT
  NATIVE = true

  module Ops
    def self.matmul(a, b)
      m, k = a.shape; _, n = b.shape
      out_data = Native.matmul_forward(a.data, b.data, m, k, n)
      return Tensor.new(out_data, [m, n]) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        a.ensure_grad; b.ensure_grad
        Native.matmul_backward(a.data, b.data, out.grad, a.grad, b.grad, m, k, n)
      }
      out = Tensor.new(out_data, [m, n], [a, b], &bk)
    end

    def self.add(a, b)
      n = a.data.size
      out_data = Native.add_forward(a.data, b.data, n)
      return Tensor.new(out_data, a.shape.dup) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        a.ensure_grad; b.ensure_grad
        Native.add_backward(out.grad, a.grad, b.grad, n)
      }
      out = Tensor.new(out_data, a.shape.dup, [a, b], &bk)
    end

    def self.embedding(table, indices)
      t = indices.length; _, c = table.shape
      out_data = Native.embedding_forward(table.data, indices, t, c)
      return Tensor.new(out_data, [t, c]) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        table.ensure_grad
        Native.embedding_backward(out.grad, indices, table.grad, t, c)
      }
      out = Tensor.new(out_data, [t, c], [table], &bk)
    end

    def self.rmsnorm(x)
      rows, cols = x.shape
      out_data, scales = Native.rmsnorm_forward(x.data, rows, cols)
      return Tensor.new(out_data, x.shape.dup) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        x.ensure_grad
        Native.rmsnorm_backward(x.data, out.grad, scales, x.grad, rows, cols)
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    def self.relu(x)
      n = x.data.size
      out_data = Native.relu_forward(x.data, n)
      return Tensor.new(out_data, x.shape.dup) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        x.ensure_grad
        Native.relu_backward(x.data, out.grad, x.grad, n)
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    def self.transpose(a)
      rows, cols = a.shape
      out_data = Native.transpose_forward(a.data, rows, cols)
      return Tensor.new(out_data, [cols, rows]) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        a.ensure_grad
        Native.transpose_backward(out.grad, a.grad, rows, cols)
      }
      out = Tensor.new(out_data, [cols, rows], [a], &bk)
    end

    def self.scale_and_causal_mask(attn, scale)
      t = attn.shape[0]
      out_data = Native.scale_mask_forward(attn.data, scale, t)
      return Tensor.new(out_data, [t, t]) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        attn.ensure_grad
        Native.scale_mask_backward(out.grad, attn.grad, scale, t)
      }
      out = Tensor.new(out_data, [t, t], [attn], &bk)
    end

    def self.softmax(x)
      rows, cols = x.shape
      out_data = Native.softmax_forward(x.data, rows, cols)
      return Tensor.new(out_data, x.shape.dup) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        x.ensure_grad
        Native.softmax_backward(out.data, out.grad, x.grad, rows, cols)
      }
      out = Tensor.new(out_data, x.shape.dup, [x], &bk)
    end

    def self.cross_entropy(logits, targets)
      t, v = logits.shape
      loss_val, probs = Native.cross_entropy_forward(logits.data, targets, t, v)
      return Tensor.new([loss_val], [1, 1]) if MicroGPT.no_grad?
      out = nil
      bk = -> {
        logits.ensure_grad
        Native.cross_entropy_backward(probs, targets, out.grad[0], logits.grad, t, v)
      }
      out = Tensor.new([loss_val], [1, 1], [logits], &bk)
    end

    # split_cols and concat_cols stay in pure Ruby — they're data
    # reshuffling, not compute-bound.
  end
end
