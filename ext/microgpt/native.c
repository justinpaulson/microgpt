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
}
