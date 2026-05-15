#include "security_engine.h"
#include "internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static SEContext g_ctx = {0};
static char      g_last_error[SE_MAX_ERROR_LEN] = {0};

static void set_error(const char *msg) {
    strncpy(g_last_error, msg, SE_MAX_ERROR_LEN - 1);
    g_last_error[SE_MAX_ERROR_LEN - 1] = '\0';
}

int se_init(const char *db_path, const char *model_path) {
    if (!db_path || !model_path) {
        set_error("db_path and model_path must not be NULL");
        return -1;
    }
    if (g_ctx.initialized) {
        return 0;
    }

    int rc = db_open(db_path, &g_ctx.db);
    if (rc != 0) {
        set_error("Failed to open scam database");
        return -1;
    }

    rc = db_create_schema(g_ctx.db);
    if (rc != 0) {
        set_error("Failed to create database schema");
        db_close(g_ctx.db);
        return -1;
    }

    rc = ml_load_all_models(model_path, &g_ctx.ml);
    if (rc != 0) {
        /* Non-fatal: pattern matching still works without ML */
        fprintf(stderr, "[SE] Warning: ML models not loaded: %s\n", model_path);
    }

    fall_detector_init(&g_ctx.fall, 2 /* Medium sensitivity */);
    g_ctx.initialized = true;
    return 0;
}

void se_cleanup(void) {
    if (!g_ctx.initialized) return;
    db_close(g_ctx.db);
    ml_unload_all_models(&g_ctx.ml);
    memset(&g_ctx, 0, sizeof(g_ctx));
}

ThreatAssessment se_analyze_call(const CallInfo *call) {
    ThreatAssessment result = {0};
    if (!call) {
        result.risk_score = 0;
        return result;
    }

    /* Known contact shortcut */
    if (call->is_known_contact) {
        result.risk_score = 0;
        result.confidence = 1.0f;
        strncpy(result.category, "SAFE", sizeof(result.category) - 1);
        strncpy(result.reason, "Known contact", sizeof(result.reason) - 1);
        return result;
    }

    result = phone_analyzer_run(&g_ctx, call->phone_number, call->caller_id,
                                call->timestamp);
    return result;
}

ThreatAssessment se_analyze_sms(const SMSInfo *sms) {
    ThreatAssessment result = {0};
    if (!sms) return result;
    return sms_analyzer_run(&g_ctx, sms);
}

ThreatAssessment se_analyze_email(const EmailInfo *email) {
    ThreatAssessment result = {0};
    if (!email) return result;
    return email_analyzer_run(&g_ctx, email);
}

ThreatAssessment se_analyze_whatsapp(const WhatsAppInfo *wa) {
    ThreatAssessment result = {0};
    if (!wa) return result;
    return whatsapp_analyzer_run(&g_ctx, wa);
}

int se_update_scam_db(const char *json_data) {
    if (!json_data || !g_ctx.initialized) return -1;
    return db_apply_update(g_ctx.db, json_data);
}

int se_get_db_version(void) {
    if (!g_ctx.initialized) return -1;
    return db_get_version(g_ctx.db);
}

int se_get_record_count(void) {
    if (!g_ctx.initialized) return -1;
    return db_get_record_count(g_ctx.db);
}

int se_load_model(const char *model_path, const char *model_type) {
    if (!model_path || !model_type || !g_ctx.initialized) return -1;
    return ml_load_model(&g_ctx.ml, model_path, model_type);
}

int se_get_model_version(const char *model_type) {
    if (!model_type || !g_ctx.initialized) return -1;
    return ml_get_version(&g_ctx.ml, model_type);
}

FallResult se_detect_fall(const SensorData *data) {
    FallResult result = {0};
    if (!data || !g_ctx.initialized) return result;
    return fall_detector_process(&g_ctx.fall, data);
}

void se_calibrate_fall_detection(int sensitivity) {
    if (!g_ctx.initialized) return;
    fall_detector_set_sensitivity(&g_ctx.fall, sensitivity);
}

int se_trigger_sos(const char **emergency_contacts, int contact_count) {
    if (!emergency_contacts || contact_count <= 0 || !g_ctx.initialized) return -1;
    if (contact_count > SE_MAX_CONTACTS) contact_count = SE_MAX_CONTACTS;
    return sos_trigger(&g_ctx.sos, emergency_contacts, contact_count);
}

int se_cancel_sos(void) {
    if (!g_ctx.initialized) return -1;
    return sos_cancel(&g_ctx.sos);
}

int se_test_sos(void) {
    if (!g_ctx.initialized) return -1;
    return sos_test(&g_ctx.sos);
}

int se_encrypt_data(const uint8_t *plaintext,  int plaintext_len,
                    uint8_t       *ciphertext, int *ciphertext_len,
                    const uint8_t *key) {
    return crypto_encrypt_aes256gcm(plaintext, plaintext_len,
                                    ciphertext, ciphertext_len, key);
}

int se_decrypt_data(const uint8_t *ciphertext, int ciphertext_len,
                    uint8_t       *plaintext,  int *plaintext_len,
                    const uint8_t *key) {
    return crypto_decrypt_aes256gcm(ciphertext, ciphertext_len,
                                    plaintext, plaintext_len, key);
}

const char *se_get_last_error(void) {
    return g_last_error;
}

int se_get_performance_stats(char *json_buffer, int buffer_size) {
    if (!json_buffer || buffer_size <= 0) return -1;
    return snprintf(json_buffer, (size_t)buffer_size,
        "{\"db_records\":%d,\"db_version\":%d,\"ml_loaded\":%s}",
        se_get_record_count(),
        se_get_db_version(),
        g_ctx.ml.loaded ? "true" : "false");
}
