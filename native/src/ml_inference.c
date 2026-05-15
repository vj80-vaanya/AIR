#include "internal.h"
#include "vocab_table.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifdef HAVE_ORT
#include "onnxruntime_c_api.h"

static const OrtApi *g_ort = NULL;

static void ort_check(OrtStatus *status, const char *where) {
    if (status) {
        fprintf(stderr, "[ML] ORT error at %s: %s\n",
                where, g_ort->GetErrorMessage(status));
        g_ort->ReleaseStatus(status);
    }
}

#define ORT_CHECK(expr) ort_check((expr), #expr)
#endif /* HAVE_ORT */

/* ── Model loading ───────────────────────────────────────────────────────── */

int ml_load_all_models(const char *dir, MLContext *ml) {
    memset(ml, 0, sizeof(*ml));
#ifdef HAVE_ORT
    g_ort = OrtGetApiBase()->GetApi(ORT_API_VERSION);
    if (!g_ort) {
        fprintf(stderr, "[ML] Failed to get ORT API\n");
        return -1;
    }

    ORT_CHECK(g_ort->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "se", &ml->env));
    if (!ml->env) return -1;

    OrtSessionOptions *opts = NULL;
    ORT_CHECK(g_ort->CreateSessionOptions(&opts));
    g_ort->SetIntraOpNumThreads(opts, 2);
    g_ort->SetSessionGraphOptimizationLevel(opts, ORT_ENABLE_BASIC);

    char path[512];
    snprintf(path, sizeof(path), "%s/text_classifier.onnx", dir);
    OrtStatus *s = g_ort->CreateSession(ml->env, path, opts, &ml->text_session);
    g_ort->ReleaseSessionOptions(opts);

    if (s) {
        fprintf(stderr, "[ML] Could not load %s: %s\n",
                path, g_ort->GetErrorMessage(s));
        g_ort->ReleaseStatus(s);
        return -1;
    }

    ml->text_version = 1;
    ml->loaded = true;
    fprintf(stderr, "[ML] Loaded: %s\n", path);
    return 0;
#else
    (void)dir;
    fprintf(stderr, "[ML] ORT not compiled in (HAVE_ORT not defined)\n");
    return -1;
#endif
}

int ml_load_model(MLContext *ml, const char *path, const char *type) {
#ifdef HAVE_ORT
    if (!g_ort || !ml->env) return -1;
    if (strcmp(type, "text") != 0) return -1;

    OrtSession *new_sess = NULL;
    OrtSessionOptions *opts = NULL;
    ORT_CHECK(g_ort->CreateSessionOptions(&opts));
    g_ort->SetIntraOpNumThreads(opts, 2);
    OrtStatus *s = g_ort->CreateSession(ml->env, path, opts, &new_sess);
    g_ort->ReleaseSessionOptions(opts);

    if (s) {
        g_ort->ReleaseStatus(s);
        return -1;
    }
    if (ml->text_session) g_ort->ReleaseSession(ml->text_session);
    ml->text_session = new_sess;
    ml->text_version++;
    return 0;
#else
    (void)ml; (void)path; (void)type;
    return -1;
#endif
}

int ml_get_version(const MLContext *ml, const char *type) {
    if (!type) return -1;
    if (strcmp(type, "text")  == 0) return ml->text_version;
    if (strcmp(type, "audio") == 0) return ml->audio_version;
    if (strcmp(type, "email") == 0) return ml->email_version;
    return -1;
}

void ml_unload_all_models(MLContext *ml) {
#ifdef HAVE_ORT
    if (g_ort) {
        if (ml->text_session) g_ort->ReleaseSession(ml->text_session);
        if (ml->env)          g_ort->ReleaseEnv(ml->env);
    }
#endif
    memset(ml, 0, sizeof(*ml));
}

/* ── Inference ───────────────────────────────────────────────────────────── */

#ifdef HAVE_ORT
static float run_text_inference(MLContext *ml,
                                const int32_t *ids, int seq_len) {
    OrtMemoryInfo *mem_info = NULL;
    ORT_CHECK(g_ort->CreateCpuMemoryInfo(
        OrtArenaAllocator, OrtMemTypeDefault, &mem_info));

    /* Build int64 input tensors (ORT ONNX model uses int64) */
    int64_t ids64[VOCAB_SEQ_LEN];
    int64_t attn64[VOCAB_SEQ_LEN];
    int64_t type64[VOCAB_SEQ_LEN];
    for (int i = 0; i < seq_len; i++) {
        ids64[i]  = (int64_t)ids[i];
        attn64[i] = (ids[i] != TOKEN_PAD) ? 1LL : 0LL;
        type64[i] = 0LL;
    }

    int64_t shape[2] = {1, (int64_t)seq_len};

    OrtValue *ort_ids  = NULL, *ort_attn = NULL, *ort_type = NULL;
    ORT_CHECK(g_ort->CreateTensorWithDataAsOrtValue(
        mem_info, ids64,  (size_t)seq_len * sizeof(int64_t),
        shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &ort_ids));
    ORT_CHECK(g_ort->CreateTensorWithDataAsOrtValue(
        mem_info, attn64, (size_t)seq_len * sizeof(int64_t),
        shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &ort_attn));
    ORT_CHECK(g_ort->CreateTensorWithDataAsOrtValue(
        mem_info, type64, (size_t)seq_len * sizeof(int64_t),
        shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &ort_type));

    g_ort->ReleaseMemoryInfo(mem_info);

    const char *in_names[]  = {"input_ids", "attention_mask", "token_type_ids"};
    const char *out_names[] = {"logits"};
    const OrtValue *inputs[3] = {ort_ids, ort_attn, ort_type};
    OrtValue *output = NULL;

    OrtStatus *s = g_ort->Run(
        ml->text_session, NULL,
        in_names,  inputs,  3,
        out_names, 1, &output);

    g_ort->ReleaseValue(ort_ids);
    g_ort->ReleaseValue(ort_attn);
    g_ort->ReleaseValue(ort_type);

    if (s) {
        g_ort->ReleaseStatus(s);
        return 0.0f;
    }

    /* logits shape [1, 2]: index 0=ham, 1=spam */
    float *logits = NULL;
    g_ort->GetTensorMutableData(output, (void **)&logits);

    float spam_score = 0.0f;
    if (logits) {
        /* softmax over 2 classes */
        float l0 = logits[0], l1 = logits[1];
        float max_l = (l0 > l1) ? l0 : l1;
        float e0 = expf(l0 - max_l), e1 = expf(l1 - max_l);
        spam_score = e1 / (e0 + e1);
    }

    g_ort->ReleaseValue(output);
    return spam_score;
}
#endif /* HAVE_ORT */

/* ── Public API ──────────────────────────────────────────────────────────── */

float ml_classify_text(MLContext *ml, const char *text, int text_len) {
    (void)text_len;
    if (!ml->loaded || !text || text[0] == '\0') return 0.0f;
#ifdef HAVE_ORT
    int32_t ids[VOCAB_SEQ_LEN];
    wordpiece_tokenize(text, ids, VOCAB_SEQ_LEN, 1 /* do_lower_case */);
    return run_text_inference(ml, ids, VOCAB_SEQ_LEN);
#else
    return 0.0f;
#endif
}

float ml_classify_email(MLContext *ml, const char *subject, const char *body) {
    if (!ml->loaded) return 0.0f;
#ifdef HAVE_ORT
    char combined[512];
    int written = 0;
    if (subject && subject[0])
        written = snprintf(combined, sizeof(combined), "%s", subject);
    if (body && body[0] && written < (int)sizeof(combined) - 8)
        snprintf(combined + written, sizeof(combined) - (size_t)written, " %s", body);
    return ml_classify_text(ml, combined, (int)strlen(combined));
#else
    (void)subject; (void)body;
    return 0.0f;
#endif
}
