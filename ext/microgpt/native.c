#include "ruby.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

#ifdef HAVE_ACCELERATE
#include <Accelerate/Accelerate.h>
#endif

/*
 * Native C accelerator for MicroGPT tensor operations.
 * All functions operate on flat Ruby Arrays of Floats.
 * Forward functions return new arrays; backward functions modify grad arrays in-place.
 * On macOS, uses Apple Accelerate (BLAS/AMX) for hardware-accelerated matmul.
 */

/* ======================== Helpers ======================== */

static double* ary_to_dbls(VALUE ary, long n) {
    double *buf = ALLOC_N(double, n);
    for (long i = 0; i < n; i++) buf[i] = NUM2DBL(rb_ary_entry(ary, i));
    return buf;
}

static VALUE dbls_to_ary(const double *buf, long n) {
    VALUE ary = rb_ary_new_capa(n);
    for (long i = 0; i < n; i++) rb_ary_push(ary, DBL2NUM(buf[i]));
    return ary;
}

static void write_dbls(VALUE ary, const double *buf, long n) {
    for (long i = 0; i < n; i++) rb_ary_store(ary, i, DBL2NUM(buf[i]));
}

/* ======================== Matmul ======================== */

/* matmul_forward(a, b, m, k, n) -> out
 * Computes C = A @ B where A is (m,k), B is (k,n), C is (m,n) */
static VALUE natv_matmul_fwd(VALUE self, VALUE ra, VALUE rb, VALUE rm, VALUE rk, VALUE rn) {
    long m = NUM2LONG(rm), k = NUM2LONG(rk), n = NUM2LONG(rn);
    double *a = ary_to_dbls(ra, m * k);
    double *b = ary_to_dbls(rb, k * n);
    double *out = ALLOC_N(double, m * n);

#ifdef HAVE_ACCELERATE
    /* Apple AMX/NEON hardware-accelerated BLAS */
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                (int)m, (int)n, (int)k, 1.0, a, (int)k, b, (int)n, 0.0, out, (int)n);
#else
    memset(out, 0, m * n * sizeof(double));
    for (long i = 0; i < m; i++) {
        long ik = i * k, in_ = i * n;
        for (long p = 0; p < k; p++) {
            double aip = a[ik + p];
            long pn = p * n;
            for (long j = 0; j < n; j++) {
                out[in_ + j] += aip * b[pn + j];
            }
        }
    }
#endif

    VALUE result = dbls_to_ary(out, m * n);
    xfree(a); xfree(b); xfree(out);
    return result;
}

/* matmul_backward(a, b, dout, da, db, m, k, n) -> nil
 * dA += dOut @ B^T,  dB += A^T @ dOut */
static VALUE natv_matmul_bwd(VALUE self, VALUE ra, VALUE rb, VALUE rdout,
                              VALUE rda, VALUE rdb, VALUE rm, VALUE rk, VALUE rn) {
    long m = NUM2LONG(rm), k = NUM2LONG(rk), n = NUM2LONG(rn);
    double *a = ary_to_dbls(ra, m * k);
    double *b = ary_to_dbls(rb, k * n);
    double *dout = ary_to_dbls(rdout, m * n);
    double *da = ary_to_dbls(rda, m * k);
    double *db = ary_to_dbls(rdb, k * n);

#ifdef HAVE_ACCELERATE
    /* dA += dOut @ B^T : (m,n) @ (n,k) -> (m,k) */
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasTrans,
                (int)m, (int)k, (int)n, 1.0, dout, (int)n, b, (int)n, 1.0, da, (int)k);
    /* dB += A^T @ dOut : (k,m) @ (m,n) -> (k,n) */
    cblas_dgemm(CblasRowMajor, CblasTrans, CblasNoTrans,
                (int)k, (int)n, (int)m, 1.0, a, (int)k, dout, (int)n, 1.0, db, (int)n);
#else
    for (long i = 0; i < m; i++) {
        long ik = i * k, in_ = i * n;
        for (long p = 0; p < k; p++) {
            double aip = a[ik + p];
            double da_acc = 0.0;
            long pn = p * n;
            for (long j = 0; j < n; j++) {
                double d = dout[in_ + j];
                da_acc += d * b[pn + j];
                db[pn + j] += aip * d;
            }
            da[ik + p] += da_acc;
        }
    }
#endif

    write_dbls(rda, da, m * k);
    write_dbls(rdb, db, k * n);
    xfree(a); xfree(b); xfree(dout); xfree(da); xfree(db);
    return Qnil;
}

/* ======================== Add ======================== */

/* add_forward(a, b, n) -> out */
static VALUE natv_add_fwd(VALUE self, VALUE ra, VALUE rb, VALUE rn) {
    long n = NUM2LONG(rn);
    double *a = ary_to_dbls(ra, n);
    double *b = ary_to_dbls(rb, n);
    double *out = ALLOC_N(double, n);
    for (long i = 0; i < n; i++) out[i] = a[i] + b[i];
    VALUE result = dbls_to_ary(out, n);
    xfree(a); xfree(b); xfree(out);
    return result;
}

/* add_backward(dout, da, db, n) -> nil */
static VALUE natv_add_bwd(VALUE self, VALUE rdout, VALUE rda, VALUE rdb, VALUE rn) {
    long n = NUM2LONG(rn);
    double *dout = ary_to_dbls(rdout, n);
    double *da = ary_to_dbls(rda, n);
    double *db = ary_to_dbls(rdb, n);
    for (long i = 0; i < n; i++) { da[i] += dout[i]; db[i] += dout[i]; }
    write_dbls(rda, da, n);
    write_dbls(rdb, db, n);
    xfree(dout); xfree(da); xfree(db);
    return Qnil;
}

/* ======================== Embedding ======================== */

/* embedding_forward(table, indices_ary, t, c) -> out */
static VALUE natv_emb_fwd(VALUE self, VALUE rtable, VALUE rindices, VALUE rt, VALUE rc) {
    long t = NUM2LONG(rt), c = NUM2LONG(rc);
    long table_sz = NUM2LONG(rb_funcall(rtable, rb_intern("size"), 0));
    double *table = ary_to_dbls(rtable, table_sz);
    double *out = ALLOC_N(double, t * c);

    for (long i = 0; i < t; i++) {
        long idx = NUM2LONG(rb_ary_entry(rindices, i));
        long src = idx * c, dst = i * c;
        memcpy(out + dst, table + src, c * sizeof(double));
    }

    VALUE result = dbls_to_ary(out, t * c);
    xfree(table); xfree(out);
    return result;
}

/* embedding_backward(dout, indices_ary, dtable, t, c) -> nil */
static VALUE natv_emb_bwd(VALUE self, VALUE rdout, VALUE rindices, VALUE rdtable, VALUE rt, VALUE rc) {
    long t = NUM2LONG(rt), c = NUM2LONG(rc);
    long table_sz = NUM2LONG(rb_funcall(rdtable, rb_intern("size"), 0));
    double *dout = ary_to_dbls(rdout, t * c);
    double *dt = ary_to_dbls(rdtable, table_sz);

    for (long i = 0; i < t; i++) {
        long idx = NUM2LONG(rb_ary_entry(rindices, i));
        long src = idx * c, dst = i * c;
        for (long j = 0; j < c; j++) dt[src + j] += dout[dst + j];
    }

    write_dbls(rdtable, dt, table_sz);
    xfree(dout); xfree(dt);
    return Qnil;
}

/* ======================== RMSNorm ======================== */

/* rmsnorm_forward(x, rows, cols) -> [out, scales] */
static VALUE natv_rmsnorm_fwd(VALUE self, VALUE rx, VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *x = ary_to_dbls(rx, rows * cols);
    double *out = ALLOC_N(double, rows * cols);
    double *scales = ALLOC_N(double, rows);

    for (long i = 0; i < rows; i++) {
        long off = i * cols;
        double ms = 0.0;
        for (long j = 0; j < cols; j++) ms += x[off + j] * x[off + j];
        ms = ms / cols + 1e-5;
        double s = 1.0 / sqrt(ms);
        scales[i] = s;
        for (long j = 0; j < cols; j++) out[off + j] = x[off + j] * s;
    }

    VALUE result = rb_ary_new3(2, dbls_to_ary(out, rows * cols), dbls_to_ary(scales, rows));
    xfree(x); xfree(out); xfree(scales);
    return result;
}

/* rmsnorm_backward(x, dout, scales, dx, rows, cols) -> nil */
static VALUE natv_rmsnorm_bwd(VALUE self, VALUE rx, VALUE rdout, VALUE rscales,
                               VALUE rdx, VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *x = ary_to_dbls(rx, rows * cols);
    double *dout = ary_to_dbls(rdout, rows * cols);
    double *scales = ary_to_dbls(rscales, rows);
    double *dx = ary_to_dbls(rdx, rows * cols);

    for (long i = 0; i < rows; i++) {
        long off = i * cols;
        double s = scales[i], dot = 0.0;
        for (long j = 0; j < cols; j++) dot += dout[off + j] * x[off + j];
        double c = s * s * s / cols;
        for (long j = 0; j < cols; j++)
            dx[off + j] += s * dout[off + j] - x[off + j] * c * dot;
    }

    write_dbls(rdx, dx, rows * cols);
    xfree(x); xfree(dout); xfree(scales); xfree(dx);
    return Qnil;
}

/* ======================== ReLU ======================== */

/* relu_forward(x, n) -> out */
static VALUE natv_relu_fwd(VALUE self, VALUE rx, VALUE rn) {
    long n = NUM2LONG(rn);
    double *x = ary_to_dbls(rx, n);
    double *out = ALLOC_N(double, n);
    for (long i = 0; i < n; i++) out[i] = x[i] > 0.0 ? x[i] : 0.0;
    VALUE result = dbls_to_ary(out, n);
    xfree(x); xfree(out);
    return result;
}

/* relu_backward(x, dout, dx, n) -> nil */
static VALUE natv_relu_bwd(VALUE self, VALUE rx, VALUE rdout, VALUE rdx, VALUE rn) {
    long n = NUM2LONG(rn);
    double *x = ary_to_dbls(rx, n);
    double *dout = ary_to_dbls(rdout, n);
    double *dx = ary_to_dbls(rdx, n);
    for (long i = 0; i < n; i++) if (x[i] > 0.0) dx[i] += dout[i];
    write_dbls(rdx, dx, n);
    xfree(x); xfree(dout); xfree(dx);
    return Qnil;
}

/* ======================== Transpose ======================== */

/* transpose_forward(a, rows, cols) -> out */
static VALUE natv_transpose_fwd(VALUE self, VALUE ra, VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *a = ary_to_dbls(ra, rows * cols);
    double *out = ALLOC_N(double, rows * cols);
    for (long i = 0; i < rows; i++)
        for (long j = 0; j < cols; j++)
            out[j * rows + i] = a[i * cols + j];
    VALUE result = dbls_to_ary(out, rows * cols);
    xfree(a); xfree(out);
    return result;
}

/* transpose_backward(dout, da, rows, cols) -> nil */
static VALUE natv_transpose_bwd(VALUE self, VALUE rdout, VALUE rda, VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *dout = ary_to_dbls(rdout, cols * rows);
    double *da = ary_to_dbls(rda, rows * cols);
    for (long i = 0; i < cols; i++)
        for (long j = 0; j < rows; j++)
            da[j * cols + i] += dout[i * rows + j];
    write_dbls(rda, da, rows * cols);
    xfree(dout); xfree(da);
    return Qnil;
}

/* ======================== Scale + Causal Mask ======================== */

/* scale_mask_forward(attn, scale, t) -> out */
static VALUE natv_scale_mask_fwd(VALUE self, VALUE rattn, VALUE rscale, VALUE rt) {
    long t = NUM2LONG(rt);
    double scale = NUM2DBL(rscale);
    double *attn = ary_to_dbls(rattn, t * t);
    double *out = ALLOC_N(double, t * t);
    for (long i = 0; i < t; i++)
        for (long j = 0; j < t; j++) {
            long idx = i * t + j;
            out[idx] = j <= i ? attn[idx] * scale : -1e9;
        }
    VALUE result = dbls_to_ary(out, t * t);
    xfree(attn); xfree(out);
    return result;
}

/* scale_mask_backward(dout, dattn, scale, t) -> nil */
static VALUE natv_scale_mask_bwd(VALUE self, VALUE rdout, VALUE rdattn, VALUE rscale, VALUE rt) {
    long t = NUM2LONG(rt);
    double scale = NUM2DBL(rscale);
    double *dout = ary_to_dbls(rdout, t * t);
    double *dattn = ary_to_dbls(rdattn, t * t);
    for (long i = 0; i < t; i++)
        for (long j = 0; j <= i; j++)
            dattn[i * t + j] += dout[i * t + j] * scale;
    write_dbls(rdattn, dattn, t * t);
    xfree(dout); xfree(dattn);
    return Qnil;
}

/* ======================== Softmax ======================== */

/* softmax_forward(x, rows, cols) -> out */
static VALUE natv_softmax_fwd(VALUE self, VALUE rx, VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *x = ary_to_dbls(rx, rows * cols);
    double *out = ALLOC_N(double, rows * cols);

    for (long i = 0; i < rows; i++) {
        long off = i * cols;
        double max_val = -1e30;
        for (long j = 0; j < cols; j++) if (x[off + j] > max_val) max_val = x[off + j];
        double sum = 0.0;
        for (long j = 0; j < cols; j++) { double e = exp(x[off + j] - max_val); out[off + j] = e; sum += e; }
        double inv = 1.0 / sum;
        for (long j = 0; j < cols; j++) out[off + j] *= inv;
    }

    VALUE result = dbls_to_ary(out, rows * cols);
    xfree(x); xfree(out);
    return result;
}

/* softmax_backward(out_data, dout, dx, rows, cols) -> nil */
static VALUE natv_softmax_bwd(VALUE self, VALUE rout_data, VALUE rdout, VALUE rdx,
                               VALUE rrows, VALUE rcols) {
    long rows = NUM2LONG(rrows), cols = NUM2LONG(rcols);
    double *out_data = ary_to_dbls(rout_data, rows * cols);
    double *dout = ary_to_dbls(rdout, rows * cols);
    double *dx = ary_to_dbls(rdx, rows * cols);

    for (long i = 0; i < rows; i++) {
        long off = i * cols;
        double dot = 0.0;
        for (long j = 0; j < cols; j++) dot += dout[off + j] * out_data[off + j];
        for (long j = 0; j < cols; j++)
            dx[off + j] += out_data[off + j] * (dout[off + j] - dot);
    }

    write_dbls(rdx, dx, rows * cols);
    xfree(out_data); xfree(dout); xfree(dx);
    return Qnil;
}

/* ======================== Cross-Entropy ======================== */

/* cross_entropy_forward(logits, targets, t, v) -> [loss, probs] */
static VALUE natv_ce_fwd(VALUE self, VALUE rlogits, VALUE rtargets, VALUE rt, VALUE rv) {
    long t = NUM2LONG(rt), v = NUM2LONG(rv);
    double *logits = ary_to_dbls(rlogits, t * v);
    double *probs = ALLOC_N(double, t * v);
    double loss = 0.0;

    for (long i = 0; i < t; i++) {
        long off = i * v;
        long target = NUM2LONG(rb_ary_entry(rtargets, i));
        double max_val = -1e30;
        for (long j = 0; j < v; j++) if (logits[off + j] > max_val) max_val = logits[off + j];
        double sum = 0.0;
        for (long j = 0; j < v; j++) { double e = exp(logits[off + j] - max_val); probs[off + j] = e; sum += e; }
        double inv = 1.0 / sum;
        for (long j = 0; j < v; j++) probs[off + j] *= inv;
        loss += -log(probs[off + target] + 1e-10);
    }
    loss /= t;

    VALUE result = rb_ary_new3(2, DBL2NUM(loss), dbls_to_ary(probs, t * v));
    xfree(logits); xfree(probs);
    return result;
}

/* cross_entropy_backward(probs, targets, dout0, dlogits, t, v) -> nil */
static VALUE natv_ce_bwd(VALUE self, VALUE rprobs, VALUE rtargets, VALUE rdout0,
                          VALUE rdlogits, VALUE rt, VALUE rv) {
    long t = NUM2LONG(rt), v = NUM2LONG(rv);
    double *probs = ary_to_dbls(rprobs, t * v);
    double dout0 = NUM2DBL(rdout0);
    double *dlogits = ary_to_dbls(rdlogits, t * v);
    double s = dout0 / t;

    for (long i = 0; i < t; i++) {
        long off = i * v;
        long target = NUM2LONG(rb_ary_entry(rtargets, i));
        for (long j = 0; j < v; j++)
            dlogits[off + j] += (probs[off + j] - (j == target ? 1.0 : 0.0)) * s;
    }

    write_dbls(rdlogits, dlogits, t * v);
    xfree(probs); xfree(dlogits);
    return Qnil;
}

/* ======================== BPE Encode ======================== */

/* bpe_encode(text_bytes_ary, merges_flat_ary, num_merges) -> token_ids_ary
 * Applies BPE merges sequentially to a byte array. Merges are provided as
 * a flat array [a0, b0, a1, b1, ...]. Returns the encoded token IDs.
 * This is 50-100x faster than the pure Ruby implementation. */
static VALUE natv_bpe_encode(VALUE self, VALUE rbytes, VALUE rmerges, VALUE rnum_merges) {
    long text_len = RARRAY_LEN(rbytes);
    long num_merges = NUM2LONG(rnum_merges);

    /* Convert text bytes to int array */
    int *tokens = ALLOC_N(int, text_len);
    for (long i = 0; i < text_len; i++) tokens[i] = NUM2INT(rb_ary_entry(rbytes, i));

    int *buf = ALLOC_N(int, text_len);
    long len = text_len;

    /* Apply each merge in priority order */
    for (long m = 0; m < num_merges; m++) {
        int a = NUM2INT(rb_ary_entry(rmerges, m * 2));
        int b = NUM2INT(rb_ary_entry(rmerges, m * 2 + 1));
        int new_id = 256 + (int)m;
        long new_len = 0;

        for (long j = 0; j < len; j++) {
            if (j < len - 1 && tokens[j] == a && tokens[j + 1] == b) {
                buf[new_len++] = new_id;
                j++; /* skip next */
            } else {
                buf[new_len++] = tokens[j];
            }
        }

        /* Swap buffers */
        int *tmp = tokens; tokens = buf; buf = tmp;
        len = new_len;
    }

    VALUE result = rb_ary_new_capa(len);
    for (long i = 0; i < len; i++) rb_ary_push(result, INT2NUM(tokens[i]));

    xfree(tokens); xfree(buf);
    return result;
}

/* ================================================================== */
/* ================ FUSED TRAINING KERNEL ========================== */
/* ================================================================== */
/*
 * Fused GPT training kernel: entire forward pass, backward pass, and
 * Adam optimizer update in a single C function call. Eliminates all
 * Ruby<->C array conversion overhead during training.
 *
 * Architecture (matching lib/microgpt/model.rb):
 *   embed: tok_emb + pos_emb -> rmsnorm
 *   N transformer layers:
 *     rmsnorm -> Q,K,V linear -> multi-head causal attention -> wo -> residual
 *     rmsnorm -> fc1 -> relu -> fc2 -> residual
 *   matmul with lm_head -> cross-entropy loss
 *
 * Parameter layout (flat contiguous array, matches param_tensors order):
 *   wte:     vocab_size * n_embd
 *   wpe:     block_size * n_embd
 *   lm_head: n_embd * vocab_size
 *   Per layer (n_layer times):
 *     wq:  n_embd * n_embd
 *     wk:  n_embd * n_embd
 *     wv:  n_embd * n_embd
 *     wo:  n_embd * n_embd
 *     fc1: n_embd * (4*n_embd)
 *     fc2: (4*n_embd) * n_embd
 */

/* ---- Internal matmul helper: C = alpha*A@B + beta*C ---- */
static void fused_matmul(const double *A, const double *B, double *C,
                         int M, int K, int N, double alpha, double beta) {
#ifdef HAVE_ACCELERATE
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                M, N, K, alpha, A, K, B, N, beta, C, N);
#else
    if (beta == 0.0) {
        memset(C, 0, (size_t)M * N * sizeof(double));
    } else if (beta != 1.0) {
        for (int i = 0; i < M * N; i++) C[i] *= beta;
    }
    for (int i = 0; i < M; i++) {
        int ik = i * K, in_ = i * N;
        for (int p = 0; p < K; p++) {
            double aip = alpha * A[ik + p];
            int pn = p * N;
            for (int j = 0; j < N; j++)
                C[in_ + j] += aip * B[pn + j];
        }
    }
#endif
}

/* ---- matmul backward: dA += alpha*dOut@B^T, dB += alpha*A^T@dOut ---- */
static void fused_matmul_bwd(const double *A, const double *B, const double *dOut,
                              double *dA, double *dB, int M, int K, int N) {
#ifdef HAVE_ACCELERATE
    /* dA += dOut @ B^T : (M,N)@(N,K) -> (M,K) */
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasTrans,
                M, K, N, 1.0, dOut, N, B, N, 1.0, dA, K);
    /* dB += A^T @ dOut : (K,M)@(M,N) -> (K,N) */
    cblas_dgemm(CblasRowMajor, CblasTrans, CblasNoTrans,
                K, N, M, 1.0, A, K, dOut, N, 1.0, dB, N);
#else
    for (int i = 0; i < M; i++) {
        int ik = i * K, in_ = i * N;
        for (int p = 0; p < K; p++) {
            double aip = A[ik + p];
            double da_acc = 0.0;
            int pn = p * N;
            for (int j = 0; j < N; j++) {
                double d = dOut[in_ + j];
                da_acc += d * B[pn + j];
                dB[pn + j] += aip * d;
            }
            dA[ik + p] += da_acc;
        }
    }
#endif
}

/* ---- RMSNorm forward: out = x * (1/rms), saves x_input and scales ---- */
static void fused_rmsnorm_fwd(const double *x, double *out, double *scales, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        int off = i * cols;
        double ms = 0.0;
        for (int j = 0; j < cols; j++) ms += x[off + j] * x[off + j];
        ms = ms / cols + 1e-5;
        double s = 1.0 / sqrt(ms);
        scales[i] = s;
        for (int j = 0; j < cols; j++) out[off + j] = x[off + j] * s;
    }
}

/* ---- RMSNorm backward: dx += d(rmsnorm)/dx ---- */
static void fused_rmsnorm_bwd(const double *x_in, const double *dout, const double *scales,
                               double *dx, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        int off = i * cols;
        double s = scales[i], dot = 0.0;
        for (int j = 0; j < cols; j++) dot += dout[off + j] * x_in[off + j];
        double c = s * s * s / cols;
        for (int j = 0; j < cols; j++)
            dx[off + j] += s * dout[off + j] - x_in[off + j] * c * dot;
    }
}

/* ---- Softmax forward (row-wise): numerically stable ---- */
static void fused_softmax_fwd(const double *x, double *out, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        int off = i * cols;
        double max_val = -1e30;
        for (int j = 0; j < cols; j++)
            if (x[off + j] > max_val) max_val = x[off + j];
        double sum = 0.0;
        for (int j = 0; j < cols; j++) {
            double e = exp(x[off + j] - max_val);
            out[off + j] = e;
            sum += e;
        }
        double inv = 1.0 / sum;
        for (int j = 0; j < cols; j++) out[off + j] *= inv;
    }
}

/* ---- Softmax backward: dx += softmax_out * (dout - dot(dout, softmax_out)) ---- */
static void fused_softmax_bwd(const double *sm_out, const double *dout,
                               double *dx, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        int off = i * cols;
        double dot = 0.0;
        for (int j = 0; j < cols; j++) dot += dout[off + j] * sm_out[off + j];
        for (int j = 0; j < cols; j++)
            dx[off + j] += sm_out[off + j] * (dout[off + j] - dot);
    }
}

/* ================================================================== */
/* ================ GPTModel struct ================================ */
/* ================================================================== */

/* Per-layer offset indices (into the params/grads arrays) */
typedef struct {
    int wq, wk, wv, wo, fc1, fc2;
} LayerOffsets;

typedef struct {
    /* Architecture */
    int n_embd, n_layer, n_head, head_dim, block_size, vocab_size;
    int n_params;

    /* Optimizer hyperparameters */
    double lr, beta1, beta2, eps;
    int step;

    /* Parameters (contiguous) and their gradients */
    double *params;
    double *grads;

    /* Adam state */
    double *adam_m;
    double *adam_v;

    /* Parameter layout offsets */
    int wte_offset, wpe_offset, lm_head_offset;
    LayerOffsets *layer_offsets;

    /*
     * Activation workspace — pre-allocated for max sequence length.
     * Layout per forward pass (T = actual sequence length):
     *
     * Per forward call, we store activations needed for backward:
     *   embed_sum:       T*C          (tok_emb + pos_emb, input to first rmsnorm)
     *   embed_scales:    T            (rmsnorm scales for embedding)
     *   embed_normed:    T*C          (rmsnorm output = x after embed)
     *
     *   Per layer:
     *     x_in:          T*C          (input to layer = residual for attention)
     *     ln1_input:     T*C          (copy of x_in, input to rmsnorm1)
     *     ln1_scales:    T            (rmsnorm1 scales)
     *     ln1_out:       T*C          (rmsnorm1 output)
     *     q, k, v:       T*C each    (projections)
     *     attn_scores:   n_head*T*T   (after scale+mask, before softmax)
     *     attn_probs:    n_head*T*T   (softmax output)
     *     head_outs:     T*C          (concatenated head outputs = n_head * T * hd)
     *     attn_out:      T*C          (after wo projection)
     *     x_after_attn:  T*C          (after first residual add)
     *     ln2_input:     T*C          (copy of x_after_attn for residual)
     *     ln2_scales:    T            (rmsnorm2 scales)
     *     ln2_out:       T*C          (rmsnorm2 output)
     *     fc1_pre_relu:  T*4C         (matmul output before relu)
     *     fc1_out:       T*4C         (after relu)
     *     fc2_out:       T*C          (after fc2)
     *     x_out:         T*C          (after second residual add = layer output)
     *
     *   logits:          T*V          (final matmul output)
     *   probs:           T*V          (softmax for cross-entropy)
     */
    double *acts;
    int acts_size;

    /* Gradient workspace (same structure, reused) */
    double *dacts;
    int dacts_size;

    /* Input/target token storage */
    int *input_tokens;
    int *target_tokens;
    int max_seq_len;  /* = block_size */

} GPTModel;

/* Compute total parameter count */
static int compute_n_params(int n_embd, int n_layer, int vocab_size, int block_size) {
    int C = n_embd, V = vocab_size, B = block_size;
    int n = V * C + B * C + C * V;  /* wte + wpe + lm_head */
    /* Per layer: wq(C*C) + wk(C*C) + wv(C*C) + wo(C*C) + fc1(C*4C) + fc2(4C*C) */
    n += n_layer * (4 * C * C + C * 4 * C + 4 * C * C);
    return n;
}

/* Compute activation workspace size for given sequence length */
static int compute_acts_size(int T, int C, int V, int n_head, int n_layer) {
    int hd = C / n_head;
    (void)hd;

    /* Embedding phase */
    int sz = T * C;         /* embed_sum */
    sz += T;                /* embed_scales */
    sz += T * C;            /* embed_normed */

    /* Per layer */
    int per_layer = 0;
    per_layer += T * C;         /* ln1_input (copy for backward) */
    per_layer += T;             /* ln1_scales */
    per_layer += T * C;         /* ln1_out */
    per_layer += T * C;         /* q */
    per_layer += T * C;         /* k */
    per_layer += T * C;         /* v */
    per_layer += n_head * T * T; /* attn_scores (after scale+mask) */
    per_layer += n_head * T * T; /* attn_probs (softmax output) */
    per_layer += T * C;         /* head_outs (concat) */
    per_layer += T * C;         /* attn_out (after wo) */
    per_layer += T * C;         /* x_after_attn */
    per_layer += T * C;         /* ln2_input */
    per_layer += T;             /* ln2_scales */
    per_layer += T * C;         /* ln2_out */
    per_layer += T * 4 * C;    /* fc1_pre_relu */
    per_layer += T * 4 * C;    /* fc1_out (after relu) */
    per_layer += T * C;         /* fc2_out */
    /* x_out overlaps with next layer's input, no extra storage needed */

    sz += n_layer * per_layer;

    /* Final */
    sz += T * V;                /* logits */
    sz += T * V;                /* probs (softmax for cross-entropy) */

    return sz;
}

/* Compute gradient workspace size (same dimensions as acts for the parts we need) */
static int compute_dacts_size(int T, int C, int V, int n_head, int n_layer) {
    /* We need gradient buffers for intermediates during backward.
     * Main buffers needed per backward step:
     *   dx: T*C  (flowing gradient, reused)
     *   dlogits: T*V
     *   d_tmp1, d_tmp2: various sizes for intermediary gradients
     *
     * We'll allocate generously and use pointer offsets.
     */
    int per_layer = 0;
    per_layer += T * C;         /* d_ln1_out */
    per_layer += T * C;         /* d_q */
    per_layer += T * C;         /* d_k */
    per_layer += T * C;         /* d_v */
    per_layer += n_head * T * T; /* d_attn_scores */
    per_layer += T * C;         /* d_head_outs (d_concat) */
    per_layer += T * C;         /* d_attn_out */
    per_layer += T * C;         /* d_ln2_out */
    per_layer += T * 4 * C;    /* d_fc1_out */
    per_layer += T * 4 * C;    /* d_fc1_pre_relu */
    per_layer += T * C;         /* d_fc2_out */

    int sz = T * V;             /* d_logits */
    sz += T * C;                /* dx (main flowing gradient) */
    sz += T * C;                /* dx_residual (temp) */
    sz += n_layer * per_layer;

    return sz;
}

/* Initialize parameter offsets */
static void init_offsets(GPTModel *m) {
    int C = m->n_embd, V = m->vocab_size, B = m->block_size;

    m->wte_offset = 0;
    m->wpe_offset = V * C;
    m->lm_head_offset = V * C + B * C;

    int off = m->lm_head_offset + C * V;

    m->layer_offsets = ALLOC_N(LayerOffsets, m->n_layer);
    for (int l = 0; l < m->n_layer; l++) {
        m->layer_offsets[l].wq  = off; off += C * C;
        m->layer_offsets[l].wk  = off; off += C * C;
        m->layer_offsets[l].wv  = off; off += C * C;
        m->layer_offsets[l].wo  = off; off += C * C;
        m->layer_offsets[l].fc1 = off; off += C * 4 * C;
        m->layer_offsets[l].fc2 = off; off += 4 * C * C;
    }
}

/* ---- TypedData GC support ---- */

static void gpt_model_free(void *ptr) {
    GPTModel *m = (GPTModel *)ptr;
    if (m->params) xfree(m->params);
    if (m->grads) xfree(m->grads);
    if (m->adam_m) xfree(m->adam_m);
    if (m->adam_v) xfree(m->adam_v);
    if (m->acts) xfree(m->acts);
    if (m->dacts) xfree(m->dacts);
    if (m->layer_offsets) xfree(m->layer_offsets);
    if (m->input_tokens) xfree(m->input_tokens);
    if (m->target_tokens) xfree(m->target_tokens);
    xfree(m);
}

static size_t gpt_model_memsize(const void *ptr) {
    const GPTModel *m = (const GPTModel *)ptr;
    size_t sz = sizeof(GPTModel);
    sz += (size_t)m->n_params * sizeof(double) * 4;  /* params + grads + adam_m + adam_v */
    sz += (size_t)m->acts_size * sizeof(double);
    sz += (size_t)m->dacts_size * sizeof(double);
    sz += (size_t)m->n_layer * sizeof(LayerOffsets);
    sz += (size_t)m->max_seq_len * 2 * sizeof(int);
    return sz;
}

static const rb_data_type_t gpt_model_type = {
    .wrap_struct_name = "GPTModel",
    .function = {
        .dmark = NULL,
        .dfree = gpt_model_free,
        .dsize = gpt_model_memsize,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

/* ================================================================== */
/* ================ Ruby API Functions ============================= */
/* ================================================================== */

/* fused_init(n_embd, n_layer, n_head, block_size, vocab_size, lr) -> handle */
static VALUE fused_init(VALUE self, VALUE rn_embd, VALUE rn_layer, VALUE rn_head,
                        VALUE rblock_size, VALUE rvocab_size, VALUE rlr) {
    int n_embd = NUM2INT(rn_embd);
    int n_layer = NUM2INT(rn_layer);
    int n_head = NUM2INT(rn_head);
    int block_size = NUM2INT(rblock_size);
    int vocab_size = NUM2INT(rvocab_size);
    double lr = NUM2DBL(rlr);

    GPTModel *m = ALLOC(GPTModel);
    memset(m, 0, sizeof(GPTModel));

    m->n_embd = n_embd;
    m->n_layer = n_layer;
    m->n_head = n_head;
    m->head_dim = n_embd / n_head;
    m->block_size = block_size;
    m->vocab_size = vocab_size;
    m->lr = lr;
    m->beta1 = 0.9;
    m->beta2 = 0.99;
    m->eps = 1e-8;
    m->step = 0;
    m->max_seq_len = block_size;

    m->n_params = compute_n_params(n_embd, n_layer, vocab_size, block_size);

    /* Allocate parameter arrays */
    m->params = ALLOC_N(double, m->n_params);
    m->grads  = ALLOC_N(double, m->n_params);
    m->adam_m = ALLOC_N(double, m->n_params);
    m->adam_v = ALLOC_N(double, m->n_params);
    memset(m->params, 0, (size_t)m->n_params * sizeof(double));
    memset(m->grads,  0, (size_t)m->n_params * sizeof(double));
    memset(m->adam_m, 0, (size_t)m->n_params * sizeof(double));
    memset(m->adam_v, 0, (size_t)m->n_params * sizeof(double));

    /* Allocate activation and gradient workspaces for max sequence length */
    int T = block_size;
    m->acts_size = compute_acts_size(T, n_embd, vocab_size, n_head, n_layer);
    m->dacts_size = compute_dacts_size(T, n_embd, vocab_size, n_head, n_layer);
    m->acts  = ALLOC_N(double, m->acts_size);
    m->dacts = ALLOC_N(double, m->dacts_size);

    /* Token buffers */
    m->input_tokens  = ALLOC_N(int, block_size);
    m->target_tokens = ALLOC_N(int, block_size);

    init_offsets(m);

    return TypedData_Wrap_Struct(rb_cObject, &gpt_model_type, m);
}

/* fused_load_params(handle, flat_params_array) -> nil */
static VALUE fused_load_params(VALUE self, VALUE handle, VALUE rparams) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);

    long len = RARRAY_LEN(rparams);
    if (len != m->n_params)
        rb_raise(rb_eArgError, "Expected %d params, got %ld", m->n_params, len);

    for (long i = 0; i < len; i++)
        m->params[i] = NUM2DBL(rb_ary_entry(rparams, i));

    return Qnil;
}

/* fused_get_params(handle) -> flat_params_array */
static VALUE fused_get_params(VALUE self, VALUE handle) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);
    return dbls_to_ary(m->params, m->n_params);
}

/* ================================================================== */
/* ================ Forward Pass =================================== */
/* ================================================================== */

/*
 * Run the complete forward pass. Returns loss (or -1 if targets is NULL for inference).
 * Stores all activations needed for backward pass.
 *
 * acts layout (pointers set during forward):
 *   Offsets computed dynamically based on T.
 */
static double fused_forward_pass(GPTModel *m, int T, int *input, int *targets) {
    int C = m->n_embd, V = m->vocab_size, H = m->n_head, hd = m->head_dim;
    double *params = m->params;
    double *acts = m->acts;

    /* ---- Activation pointer layout ---- */
    int aoff = 0;
    double *embed_sum    = acts + aoff; aoff += T * C;
    double *embed_scales = acts + aoff; aoff += T;
    double *embed_normed = acts + aoff; aoff += T * C;

    /* Per-layer activation offsets (computed but stored as base offsets) */
    int layer_acts_base = aoff;
    int per_layer_acts =
        T * C +       /* ln1_input */
        T +           /* ln1_scales */
        T * C +       /* ln1_out */
        T * C +       /* q */
        T * C +       /* k */
        T * C +       /* v */
        H * T * T +   /* attn_scores */
        H * T * T +   /* attn_probs */
        T * C +       /* head_outs */
        T * C +       /* attn_out */
        T * C +       /* x_after_attn */
        T * C +       /* ln2_input */
        T +           /* ln2_scales */
        T * C +       /* ln2_out */
        T * 4 * C +   /* fc1_pre_relu */
        T * 4 * C +   /* fc1_out */
        T * C;        /* fc2_out */

    int logits_offset = layer_acts_base + m->n_layer * per_layer_acts;
    double *logits = acts + logits_offset;
    double *probs  = acts + logits_offset + T * V;

    /* ---- 1. Embedding ---- */
    double *wte = params + m->wte_offset;
    double *wpe = params + m->wpe_offset;

    /* tok_emb + pos_emb -> embed_sum */
    for (int i = 0; i < T; i++) {
        int tok_off = input[i] * C;
        int pos_off = i * C;
        int dst = i * C;
        for (int j = 0; j < C; j++)
            embed_sum[dst + j] = wte[tok_off + j] + wpe[pos_off + j];
    }

    /* rmsnorm(embed_sum) -> embed_normed */
    fused_rmsnorm_fwd(embed_sum, embed_normed, embed_scales, T, C);

    /* x now points to embed_normed */
    double *x = embed_normed;

    /* ---- 2. Transformer layers ---- */
    for (int l = 0; l < m->n_layer; l++) {
        int la = layer_acts_base + l * per_layer_acts;
        int off_in_layer = 0;

        double *ln1_input   = acts + la + off_in_layer; off_in_layer += T * C;
        double *ln1_scales  = acts + la + off_in_layer; off_in_layer += T;
        double *ln1_out     = acts + la + off_in_layer; off_in_layer += T * C;
        double *q           = acts + la + off_in_layer; off_in_layer += T * C;
        double *k           = acts + la + off_in_layer; off_in_layer += T * C;
        double *v           = acts + la + off_in_layer; off_in_layer += T * C;
        double *attn_scores = acts + la + off_in_layer; off_in_layer += H * T * T;
        double *attn_probs  = acts + la + off_in_layer; off_in_layer += H * T * T;
        double *head_outs   = acts + la + off_in_layer; off_in_layer += T * C;
        double *attn_out    = acts + la + off_in_layer; off_in_layer += T * C;
        double *x_after_attn= acts + la + off_in_layer; off_in_layer += T * C;
        double *ln2_input   = acts + la + off_in_layer; off_in_layer += T * C;
        double *ln2_scales  = acts + la + off_in_layer; off_in_layer += T;
        double *ln2_out     = acts + la + off_in_layer; off_in_layer += T * C;
        double *fc1_pre     = acts + la + off_in_layer; off_in_layer += T * 4 * C;
        double *fc1_out     = acts + la + off_in_layer; off_in_layer += T * 4 * C;
        double *fc2_out     = acts + la + off_in_layer; off_in_layer += T * C;
        (void)off_in_layer;

        LayerOffsets *lo = &m->layer_offsets[l];
        double *wq  = params + lo->wq;
        double *wk  = params + lo->wk;
        double *wv  = params + lo->wv;
        double *wo  = params + lo->wo;
        double *fc1 = params + lo->fc1;
        double *fc2 = params + lo->fc2;

        /* Save input for residual backward */
        memcpy(ln1_input, x, (size_t)T * C * sizeof(double));

        /* RMSNorm 1 */
        fused_rmsnorm_fwd(x, ln1_out, ln1_scales, T, C);

        /* Q, K, V projections: (T,C) @ (C,C) -> (T,C) */
        fused_matmul(ln1_out, wq, q, T, C, C, 1.0, 0.0);
        fused_matmul(ln1_out, wk, k, T, C, C, 1.0, 0.0);
        fused_matmul(ln1_out, wv, v, T, C, C, 1.0, 0.0);

        /* Multi-head attention */
        double inv_sqrt_hd = 1.0 / sqrt((double)hd);

        for (int h = 0; h < H; h++) {
            /* q_h, k_h, v_h are stored interleaved in the (T, C) arrays:
             * For head h, column range [h*hd, (h+1)*hd) in the T*C array.
             * We need to handle the split-heads layout.
             *
             * The Ruby code does split_cols which extracts contiguous sub-columns.
             * q[i, h*hd..(h+1)*hd-1] for row i.
             *
             * For scores = q_h @ k_h^T where q_h is (T, hd) and k_h^T is (hd, T):
             * scores[i][j] = sum_d q[i, h*hd+d] * k[j, h*hd+d]
             */
            double *scores_h = attn_scores + h * T * T;
            double *probs_h  = attn_probs + h * T * T;

            /* Compute scores: Q_h @ K_h^T with scale and causal mask */
            for (int i = 0; i < T; i++) {
                for (int j = 0; j < T; j++) {
                    if (j <= i) {
                        double dot = 0.0;
                        for (int d = 0; d < hd; d++)
                            dot += q[i * C + h * hd + d] * k[j * C + h * hd + d];
                        scores_h[i * T + j] = dot * inv_sqrt_hd;
                    } else {
                        scores_h[i * T + j] = -1e9;
                    }
                }
            }

            /* Softmax over scores (each row) */
            fused_softmax_fwd(scores_h, probs_h, T, T);

            /* head_out = attn_probs @ V_h: (T,T) @ (T,hd) -> (T,hd)
             * But V_h columns are at v[i, h*hd..h*hd+hd-1]
             * head_outs columns are at head_outs[i, h*hd..h*hd+hd-1] */
            for (int i = 0; i < T; i++) {
                for (int d = 0; d < hd; d++) {
                    double sum = 0.0;
                    for (int j = 0; j < T; j++)
                        sum += probs_h[i * T + j] * v[j * C + h * hd + d];
                    head_outs[i * C + h * hd + d] = sum;
                }
            }
        }

        /* attn_out = concat(head_outs) @ wo: (T,C) @ (C,C) -> (T,C) */
        fused_matmul(head_outs, wo, attn_out, T, C, C, 1.0, 0.0);

        /* Residual add: x_after_attn = attn_out + ln1_input */
        for (int i = 0; i < T * C; i++)
            x_after_attn[i] = attn_out[i] + ln1_input[i];

        /* Save for second residual */
        memcpy(ln2_input, x_after_attn, (size_t)T * C * sizeof(double));

        /* RMSNorm 2 */
        fused_rmsnorm_fwd(x_after_attn, ln2_out, ln2_scales, T, C);

        /* MLP: fc1 -> relu -> fc2 */
        fused_matmul(ln2_out, fc1, fc1_pre, T, C, 4 * C, 1.0, 0.0);

        /* ReLU */
        for (int i = 0; i < T * 4 * C; i++)
            fc1_out[i] = fc1_pre[i] > 0.0 ? fc1_pre[i] : 0.0;

        /* fc2 */
        fused_matmul(fc1_out, fc2, fc2_out, T, 4 * C, C, 1.0, 0.0);

        /* Second residual: x_out = fc2_out + ln2_input */
        /* For next layer, x points to where we store the result.
         * For the last layer, we need x to be accessible.
         * We store the result in fc2_out (reusing) — actually, let's use a
         * separate area. The x_out is conceptually "the output of this layer"
         * and becomes the input to the next layer.
         *
         * We'll write it back into ln1_input of the next layer,
         * or if this is the last layer, we need it for logits.
         * Simplest: overwrite fc2_out with the residual sum, and point x there. */
        for (int i = 0; i < T * C; i++)
            fc2_out[i] += ln2_input[i];

        x = fc2_out;  /* This is the output of this layer */
    }

    /* ---- 3. Final logits ---- */
    double *lm_head = params + m->lm_head_offset;
    fused_matmul(x, lm_head, logits, T, C, V, 1.0, 0.0);

    /* ---- 4. Cross-entropy loss (if targets provided) ---- */
    if (targets == NULL) return -1.0;

    double loss = 0.0;
    for (int i = 0; i < T; i++) {
        int off = i * V;
        int target = targets[i];
        double max_val = -1e30;
        for (int j = 0; j < V; j++)
            if (logits[off + j] > max_val) max_val = logits[off + j];
        double sum = 0.0;
        for (int j = 0; j < V; j++) {
            double e = exp(logits[off + j] - max_val);
            probs[off + j] = e;
            sum += e;
        }
        double inv = 1.0 / sum;
        for (int j = 0; j < V; j++) probs[off + j] *= inv;
        loss += -log(probs[off + target] + 1e-10);
    }
    loss /= T;

    return loss;
}

/* ================================================================== */
/* ================ Backward Pass ================================== */
/* ================================================================== */

static void fused_backward_pass(GPTModel *m, int T, int *input, int *targets) {
    int C = m->n_embd, V = m->vocab_size, H = m->n_head, hd = m->head_dim;
    double *params = m->params;
    double *grads = m->grads;
    double *acts = m->acts;

    /* Zero all gradients */
    memset(grads, 0, (size_t)m->n_params * sizeof(double));

    /* ---- Recompute activation pointers (same layout as forward) ---- */
    int aoff = 0;
    double *embed_sum    = acts + aoff; aoff += T * C;
    double *embed_scales = acts + aoff; aoff += T;
    double *embed_normed = acts + aoff; aoff += T * C;

    int layer_acts_base = aoff;
    int per_layer_acts =
        T * C + T + T * C + T * C + T * C + T * C +
        H * T * T + H * T * T + T * C + T * C + T * C +
        T * C + T + T * C + T * 4 * C + T * 4 * C + T * C;

    int logits_offset = layer_acts_base + m->n_layer * per_layer_acts;
    /* logits pointer not needed here — we only need probs for CE backward */
    double *probs  = acts + logits_offset + T * V;

    /* ---- Allocate gradient workspace ---- */
    /* dx: the flowing gradient through the network, shape (T, C) */
    double *dx = ALLOC_N(double, T * C);
    double *d_logits = ALLOC_N(double, T * V);

    /* ---- 1. Cross-entropy backward: dlogits = (probs - one_hot) / T ---- */
    /* dout/dloss = 1.0 (initial gradient) */
    double s = 1.0 / T;
    for (int i = 0; i < T; i++) {
        int off = i * V;
        int target = targets[i];
        for (int j = 0; j < V; j++)
            d_logits[off + j] = (probs[off + j] - (j == target ? 1.0 : 0.0)) * s;
    }

    /* ---- 2. lm_head backward: logits = x @ lm_head ---- */
    /* Find x (output of last transformer layer) */
    double *x_final;
    if (m->n_layer > 0) {
        int last_la = layer_acts_base + (m->n_layer - 1) * per_layer_acts;
        /* fc2_out is the last activation in the layer (which was modified to include residual) */
        int fc2_off_in_layer = T*C + T + T*C + T*C + T*C + T*C + H*T*T + H*T*T + T*C + T*C + T*C + T*C + T + T*C + T*4*C + T*4*C;
        x_final = acts + last_la + fc2_off_in_layer;
    } else {
        x_final = embed_normed;
    }

    double *lm_head = params + m->lm_head_offset;
    double *d_lm_head = grads + m->lm_head_offset;

    /* dx = d_logits @ lm_head^T, d_lm_head += x_final^T @ d_logits */
    memset(dx, 0, (size_t)T * C * sizeof(double));
    fused_matmul_bwd(x_final, lm_head, d_logits, dx, d_lm_head, T, C, V);

    xfree(d_logits);

    /* ---- 3. Transformer layers backward (reverse order) ---- */
    /* Temporary buffers for per-layer backward */
    double *d_ln_out    = ALLOC_N(double, T * C);
    double *d_q         = ALLOC_N(double, T * C);
    double *d_k         = ALLOC_N(double, T * C);
    double *d_v         = ALLOC_N(double, T * C);
    double *d_scores    = ALLOC_N(double, T * T);  /* per-head */
    double *d_head_outs = ALLOC_N(double, T * C);
    double *d_attn_out  = ALLOC_N(double, T * C);
    double *d_ln2_out   = ALLOC_N(double, T * C);
    double *d_fc1_out   = ALLOC_N(double, T * 4 * C);
    double *d_fc1_pre   = ALLOC_N(double, T * 4 * C);
    double *d_fc2_out   = ALLOC_N(double, T * C);
    double *d_x_res     = ALLOC_N(double, T * C);

    for (int l = m->n_layer - 1; l >= 0; l--) {
        int la = layer_acts_base + l * per_layer_acts;
        int off_in_layer = 0;

        double *ln1_input   = acts + la + off_in_layer; off_in_layer += T * C;
        double *ln1_scales  = acts + la + off_in_layer; off_in_layer += T;
        double *ln1_out     = acts + la + off_in_layer; off_in_layer += T * C;
        double *q           = acts + la + off_in_layer; off_in_layer += T * C;
        double *k           = acts + la + off_in_layer; off_in_layer += T * C;
        double *v           = acts + la + off_in_layer; off_in_layer += T * C;
        double *attn_scores = acts + la + off_in_layer; off_in_layer += H * T * T;
        double *attn_probs  = acts + la + off_in_layer; off_in_layer += H * T * T;
        double *head_outs   = acts + la + off_in_layer; off_in_layer += T * C;
        double *attn_out    = acts + la + off_in_layer; off_in_layer += T * C;
        /* x_after_attn not needed separately in backward (same as ln2_input) */
        off_in_layer += T * C;
        double *ln2_input   = acts + la + off_in_layer; off_in_layer += T * C;
        double *ln2_scales  = acts + la + off_in_layer; off_in_layer += T;
        double *ln2_out     = acts + la + off_in_layer; off_in_layer += T * C;
        double *fc1_pre     = acts + la + off_in_layer; off_in_layer += T * 4 * C;
        double *fc1_out     = acts + la + off_in_layer; off_in_layer += T * 4 * C;
        /* fc2_out not needed as variable — its data was modified in-place during forward */
        off_in_layer += T * C;
        (void)off_in_layer;
        (void)attn_scores; /* We use attn_probs, not raw scores, for backward */
        (void)attn_out;    /* Used in forward for reference */

        LayerOffsets *lo = &m->layer_offsets[l];
        double *wq  = params + lo->wq;
        double *wk  = params + lo->wk;
        double *wv  = params + lo->wv;
        double *wo  = params + lo->wo;
        double *fc1 = params + lo->fc1;
        double *fc2 = params + lo->fc2;
        double *d_wq  = grads + lo->wq;
        double *d_wk  = grads + lo->wk;
        double *d_wv  = grads + lo->wv;
        double *d_wo  = grads + lo->wo;
        double *d_fc1 = grads + lo->fc1;
        double *d_fc2 = grads + lo->fc2;

        /* dx is the incoming gradient (from logits backward or next layer) */

        /* ---- Second residual backward ---- */
        /* x_out = fc2_out_orig + ln2_input, but we modified fc2_out in place
         * dx flows to both d_fc2_out and d_ln2_input (residual).
         * d_fc2_out = dx, d_x_res = dx */
        memcpy(d_fc2_out, dx, (size_t)T * C * sizeof(double));
        memcpy(d_x_res, dx, (size_t)T * C * sizeof(double));

        /* ---- fc2 backward: fc2_out = fc1_out @ fc2 ---- */
        memset(d_fc1_out, 0, (size_t)T * 4 * C * sizeof(double));
        fused_matmul_bwd(fc1_out, fc2, d_fc2_out, d_fc1_out, d_fc2, T, 4 * C, C);

        /* ---- ReLU backward ---- */
        for (int i = 0; i < T * 4 * C; i++)
            d_fc1_pre[i] = fc1_pre[i] > 0.0 ? d_fc1_out[i] : 0.0;

        /* ---- fc1 backward: fc1_pre = ln2_out @ fc1 ---- */
        memset(d_ln2_out, 0, (size_t)T * C * sizeof(double));
        fused_matmul_bwd(ln2_out, fc1, d_fc1_pre, d_ln2_out, d_fc1, T, C, 4 * C);

        /* ---- RMSNorm 2 backward ---- */
        /* d_ln2_out -> d_x_after_attn (accumulated into d_x_res) */
        fused_rmsnorm_bwd(ln2_input, d_ln2_out, ln2_scales, d_x_res, T, C);

        /* Now d_x_res holds the gradient flowing to x_after_attn = attn_out + ln1_input */
        /* ---- First residual backward ---- */
        /* d_attn_out = d_x_res, and also d_ln1_input += d_x_res */
        memcpy(d_attn_out, d_x_res, (size_t)T * C * sizeof(double));

        /* ---- wo backward: attn_out = head_outs_concat @ wo ---- */
        memset(d_head_outs, 0, (size_t)T * C * sizeof(double));
        fused_matmul_bwd(head_outs, wo, d_attn_out, d_head_outs, d_wo, T, C, C);

        /* ---- Multi-head attention backward ---- */
        memset(d_q, 0, (size_t)T * C * sizeof(double));
        memset(d_k, 0, (size_t)T * C * sizeof(double));
        memset(d_v, 0, (size_t)T * C * sizeof(double));

        double inv_sqrt_hd = 1.0 / sqrt((double)hd);

        for (int h = 0; h < H; h++) {
            double *probs_h = attn_probs + h * T * T;

            /* ---- head_out = attn_probs @ v_h backward ---- */
            /* d_head_outs columns [h*hd, (h+1)*hd) */
            /* d_probs_h[i][j] += sum_d d_head_outs[i, h*hd+d] * v[j, h*hd+d] */
            /* d_v[j, h*hd+d] += sum_i probs_h[i][j] * d_head_outs[i, h*hd+d] */

            /* First compute d_scores via d_probs -> softmax_bwd -> d_scores */
            /* But we need d_probs first */

            /* d_probs_h (T,T) and d_v_h accumulated into d_v */
            memset(d_scores, 0, (size_t)T * T * sizeof(double));

            /* Backward of: head_out[i,d] = sum_j probs_h[i,j] * v[j, h*hd+d] */
            for (int i = 0; i < T; i++) {
                for (int j = 0; j < T; j++) {
                    double dp = 0.0;
                    for (int d = 0; d < hd; d++) {
                        double dho = d_head_outs[i * C + h * hd + d];
                        dp += dho * v[j * C + h * hd + d];
                        d_v[j * C + h * hd + d] += probs_h[i * T + j] * dho;
                    }
                    d_scores[i * T + j] = dp;
                }
            }

            /* Softmax backward: d_scores -> d_attn_raw_scores */
            /* d_scores currently holds d(L)/d(probs_h), we need d(L)/d(scores_h) */
            /* softmax_bwd: dx[i,j] += sm_out[i,j] * (dout[i,j] - dot)
             * where dot = sum_k dout[i,k] * sm_out[i,k] */
            /* We reuse d_scores as both input and output here.
             * Need a temp for the softmax backward. */
            {
                double *d_raw = ALLOC_N(double, T * T);
                memset(d_raw, 0, (size_t)T * T * sizeof(double));
                fused_softmax_bwd(probs_h, d_scores, d_raw, T, T);

                /* Scale+mask backward: d_raw has gradient w.r.t. scaled+masked scores.
                 * scale_mask: out[i,j] = j<=i ? raw[i,j]*scale : -1e9
                 * backward: d_raw_pre[i,j] = j<=i ? d_raw[i,j]*scale : 0
                 *
                 * But raw scores = Q_h @ K_h^T (unscaled), and scale_mask applies scale.
                 * Actually in our forward, we fused the scale into the dot product directly.
                 * scores_h[i,j] = dot * inv_sqrt_hd (for j<=i) or -1e9.
                 * So d_dot[i,j] = d_raw[i,j] * inv_sqrt_hd (for j<=i), 0 otherwise.
                 *
                 * Then: dot = sum_d q[i,h*hd+d]*k[j,h*hd+d]
                 * d_q[i,h*hd+d] += sum_j d_dot[i,j]*k[j,h*hd+d]
                 * d_k[j,h*hd+d] += sum_i d_dot[i,j]*q[i,h*hd+d]
                 */
                for (int i = 0; i < T; i++) {
                    for (int j = 0; j <= i; j++) {
                        double dd = d_raw[i * T + j] * inv_sqrt_hd;
                        for (int d = 0; d < hd; d++) {
                            d_q[i * C + h * hd + d] += dd * k[j * C + h * hd + d];
                            d_k[j * C + h * hd + d] += dd * q[i * C + h * hd + d];
                        }
                    }
                }

                xfree(d_raw);
            }
        }

        /* ---- Q, K, V projection backward ---- */
        /* q = ln1_out @ wq, etc. */
        memset(d_ln_out, 0, (size_t)T * C * sizeof(double));
        fused_matmul_bwd(ln1_out, wq, d_q, d_ln_out, d_wq, T, C, C);
        fused_matmul_bwd(ln1_out, wk, d_k, d_ln_out, d_wk, T, C, C);
        fused_matmul_bwd(ln1_out, wv, d_v, d_ln_out, d_wv, T, C, C);

        /* ---- RMSNorm 1 backward: d_ln_out -> dx for this layer input ---- */
        /* dx needs to accumulate: residual gradient + rmsnorm gradient */
        /* d_x_res already has the residual gradient from the first residual add */
        fused_rmsnorm_bwd(ln1_input, d_ln_out, ln1_scales, d_x_res, T, C);

        /* dx for next iteration = d_x_res (which now has both paths) */
        memcpy(dx, d_x_res, (size_t)T * C * sizeof(double));
    }

    /* ---- 4. Embedding backward ---- */
    /* dx flows into rmsnorm backward for embedding */
    double *d_embed_sum = ALLOC_N(double, T * C);
    memset(d_embed_sum, 0, (size_t)T * C * sizeof(double));
    fused_rmsnorm_bwd(embed_sum, dx, embed_scales, d_embed_sum, T, C);

    /* d_embed_sum flows to both wte and wpe (add backward: gradient passes through) */
    double *d_wte = grads + m->wte_offset;
    double *d_wpe = grads + m->wpe_offset;

    for (int i = 0; i < T; i++) {
        int tok_off = input[i] * C;
        int pos_off = i * C;
        int src = i * C;
        for (int j = 0; j < C; j++) {
            d_wte[tok_off + j] += d_embed_sum[src + j];
            d_wpe[pos_off + j] += d_embed_sum[src + j];
        }
    }

    xfree(d_embed_sum);
    xfree(dx);
    xfree(d_ln_out);
    xfree(d_q);
    xfree(d_k);
    xfree(d_v);
    xfree(d_scores);
    xfree(d_head_outs);
    xfree(d_attn_out);
    xfree(d_ln2_out);
    xfree(d_fc1_out);
    xfree(d_fc1_pre);
    xfree(d_fc2_out);
    xfree(d_x_res);
}

/* ================================================================== */
/* ================ Adam Optimizer ================================= */
/* ================================================================== */

static void fused_adam_update(GPTModel *m) {
    m->step++;
    double bc1 = 1.0 / (1.0 - pow(m->beta1, m->step));
    double bc2 = 1.0 / (1.0 - pow(m->beta2, m->step));
    double ob1 = 1.0 - m->beta1;
    double ob2 = 1.0 - m->beta2;

    double *params = m->params;
    double *grads  = m->grads;
    double *am     = m->adam_m;
    double *av     = m->adam_v;
    double lr = m->lr, eps = m->eps, b1 = m->beta1, b2 = m->beta2;

    for (int i = 0; i < m->n_params; i++) {
        double g = grads[i];
        am[i] = b1 * am[i] + ob1 * g;
        av[i] = b2 * av[i] + ob2 * g * g;
        params[i] -= lr * (am[i] * bc1) / (sqrt(av[i] * bc2) + eps);
    }
}

/* ================================================================== */
/* ================ Ruby API: Train Step =========================== */
/* ================================================================== */

/* fused_train_step(handle, input_tokens, target_tokens) -> loss (Float) */
static VALUE fused_train_step_rb(VALUE self, VALUE handle, VALUE rinput, VALUE rtargets) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);

    long T = RARRAY_LEN(rinput);
    if (T > m->block_size)
        rb_raise(rb_eArgError, "Sequence length %ld exceeds block_size %d", T, m->block_size);
    if (RARRAY_LEN(rtargets) != T)
        rb_raise(rb_eArgError, "Input and target lengths must match");

    /* Convert tokens */
    for (long i = 0; i < T; i++) {
        m->input_tokens[i]  = NUM2INT(rb_ary_entry(rinput, i));
        m->target_tokens[i] = NUM2INT(rb_ary_entry(rtargets, i));
    }

    /* Recompute activation workspace if T changed (always fits, just recalc pointers) */
    /* Forward pass */
    double loss = fused_forward_pass(m, (int)T, m->input_tokens, m->target_tokens);

    /* Backward pass */
    fused_backward_pass(m, (int)T, m->input_tokens, m->target_tokens);

    /* Adam update */
    fused_adam_update(m);

    return DBL2NUM(loss);
}

/* ================================================================== */
/* ================ Ruby API: Forward (inference) ================== */
/* ================================================================== */

/* fused_forward(handle, input_tokens) -> logits_array (last position only) */
static VALUE fused_forward_rb(VALUE self, VALUE handle, VALUE rinput) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);

    long T = RARRAY_LEN(rinput);
    if (T > m->block_size)
        rb_raise(rb_eArgError, "Sequence length %ld exceeds block_size %d", T, m->block_size);

    for (long i = 0; i < T; i++)
        m->input_tokens[i] = NUM2INT(rb_ary_entry(rinput, i));

    fused_forward_pass(m, (int)T, m->input_tokens, NULL);

    /* Extract logits for last position */
    int C = m->n_embd, V = m->vocab_size, H = m->n_head;
    int per_layer_acts =
        (int)T * C + (int)T + (int)T * C + (int)T * C + (int)T * C + (int)T * C +
        H * (int)T * (int)T + H * (int)T * (int)T + (int)T * C + (int)T * C + (int)T * C +
        (int)T * C + (int)T + (int)T * C + (int)T * 4 * C + (int)T * 4 * C + (int)T * C;

    int layer_acts_base = (int)T * C + (int)T + (int)T * C;
    int logits_offset = layer_acts_base + m->n_layer * per_layer_acts;
    double *logits = m->acts + logits_offset;

    /* Return logits for last position: logits[(T-1)*V .. T*V-1] */
    double *last_logits = logits + (T - 1) * V;
    return dbls_to_ary(last_logits, V);
}

/* ================================================================== */
/* ================ Ruby API: Step count =========================== */
/* ================================================================== */

/* fused_step(handle) -> Integer */
static VALUE fused_step_rb(VALUE self, VALUE handle) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);
    return INT2NUM(m->step);
}

/* ================================================================== */
/* ================ Ruby API: Free ================================= */
/* ================================================================== */

/* fused_free(handle) -> nil */
static VALUE fused_free_rb(VALUE self, VALUE handle) {
    /* TypedData GC will handle the actual free via gpt_model_free.
     * But we can eagerly release the heavy allocations. */
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);

    if (m->params) { xfree(m->params); m->params = NULL; }
    if (m->grads)  { xfree(m->grads);  m->grads  = NULL; }
    if (m->adam_m) { xfree(m->adam_m); m->adam_m = NULL; }
    if (m->adam_v) { xfree(m->adam_v); m->adam_v = NULL; }
    if (m->acts)   { xfree(m->acts);   m->acts   = NULL; }
    if (m->dacts)  { xfree(m->dacts);  m->dacts  = NULL; }

    return Qnil;
}

/* ================================================================== */
/* ================ Ruby API: Adam state import/export ============= */
/* ================================================================== */

/* fused_get_adam_state(handle) -> [m_array, v_array] */
static VALUE fused_get_adam_state_rb(VALUE self, VALUE handle) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);
    VALUE m_ary = dbls_to_ary(m->adam_m, m->n_params);
    VALUE v_ary = dbls_to_ary(m->adam_v, m->n_params);
    return rb_ary_new3(2, m_ary, v_ary);
}

/* fused_set_adam_state(handle, m_array, v_array) -> nil */
static VALUE fused_set_adam_state_rb(VALUE self, VALUE handle, VALUE rm, VALUE rv) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);
    for (long i = 0; i < m->n_params; i++) {
        m->adam_m[i] = NUM2DBL(rb_ary_entry(rm, i));
        m->adam_v[i] = NUM2DBL(rb_ary_entry(rv, i));
    }
    return Qnil;
}

/* fused_set_step(handle, step) -> nil */
static VALUE fused_set_step_rb(VALUE self, VALUE handle, VALUE rstep) {
    GPTModel *m;
    TypedData_Get_Struct(handle, GPTModel, &gpt_model_type, m);
    m->step = NUM2INT(rstep);
    return Qnil;
}

/* ======================== Init ======================== */

void Init_native(void) {
    VALUE mMicroGPT = rb_define_module("MicroGPT");
    VALUE mNative = rb_define_module_under(mMicroGPT, "Native");

    rb_define_module_function(mNative, "matmul_forward", natv_matmul_fwd, 5);
    rb_define_module_function(mNative, "matmul_backward", natv_matmul_bwd, 8);
    rb_define_module_function(mNative, "add_forward", natv_add_fwd, 3);
    rb_define_module_function(mNative, "add_backward", natv_add_bwd, 4);
    rb_define_module_function(mNative, "embedding_forward", natv_emb_fwd, 4);
    rb_define_module_function(mNative, "embedding_backward", natv_emb_bwd, 5);
    rb_define_module_function(mNative, "rmsnorm_forward", natv_rmsnorm_fwd, 3);
    rb_define_module_function(mNative, "rmsnorm_backward", natv_rmsnorm_bwd, 6);
    rb_define_module_function(mNative, "relu_forward", natv_relu_fwd, 2);
    rb_define_module_function(mNative, "relu_backward", natv_relu_bwd, 4);
    rb_define_module_function(mNative, "transpose_forward", natv_transpose_fwd, 3);
    rb_define_module_function(mNative, "transpose_backward", natv_transpose_bwd, 4);
    rb_define_module_function(mNative, "scale_mask_forward", natv_scale_mask_fwd, 3);
    rb_define_module_function(mNative, "scale_mask_backward", natv_scale_mask_bwd, 4);
    rb_define_module_function(mNative, "softmax_forward", natv_softmax_fwd, 3);
    rb_define_module_function(mNative, "softmax_backward", natv_softmax_bwd, 5);
    rb_define_module_function(mNative, "cross_entropy_forward", natv_ce_fwd, 4);
    rb_define_module_function(mNative, "cross_entropy_backward", natv_ce_bwd, 6);
    rb_define_module_function(mNative, "bpe_encode", natv_bpe_encode, 3);

    /* Fused training kernel */
    VALUE mFused = rb_define_module_under(mMicroGPT, "FusedKernel");
    rb_define_module_function(mFused, "init", fused_init, 6);
    rb_define_module_function(mFused, "load_params", fused_load_params, 2);
    rb_define_module_function(mFused, "get_params", fused_get_params, 1);
    rb_define_module_function(mFused, "train_step", fused_train_step_rb, 3);
    rb_define_module_function(mFused, "forward", fused_forward_rb, 2);
    rb_define_module_function(mFused, "step", fused_step_rb, 1);
    rb_define_module_function(mFused, "set_step", fused_set_step_rb, 2);
    rb_define_module_function(mFused, "get_adam_state", fused_get_adam_state_rb, 1);
    rb_define_module_function(mFused, "set_adam_state", fused_set_adam_state_rb, 3);
    rb_define_module_function(mFused, "free", fused_free_rb, 1);
}
