#ifndef SE_INTERNAL_H
#define SE_INTERNAL_H

#include "security_engine.h"
#include <stdbool.h>
#include <stdint.h>

/* Forward-declared opaque types */
typedef struct sqlite3           sqlite3;
typedef struct OrtEnv            OrtEnv;
typedef struct OrtSession        OrtSession;
typedef struct OrtSessionOptions OrtSessionOptions;

/* ─── ML context ─────────────────────────────────────────────────────────── */
typedef struct {
    bool        loaded;
    OrtEnv     *env;
    OrtSession *text_session;
    int         text_version;
    int         audio_version;
    int         email_version;
} MLContext;

/* ─── Fall detector context ──────────────────────────────────────────────── */
#define FALL_WINDOW 50   /* sensor samples in sliding window */
typedef struct {
    int        sensitivity;
    SensorData window[FALL_WINDOW];
    int        window_head;
    float      baseline_accel_magnitude;
    bool       calibrated;
} FallContext;

/* ─── SOS context ────────────────────────────────────────────────────────── */
typedef struct {
    bool active;
    bool test_mode;
} SOSContext;

/* ─── Engine context ─────────────────────────────────────────────────────── */
typedef struct {
    bool        initialized;
    sqlite3    *db;
    MLContext   ml;
    FallContext fall;
    SOSContext  sos;
} SEContext;

/* ─── DB functions ───────────────────────────────────────────────────────── */
int  db_open(const char *path, sqlite3 **db);
void db_close(sqlite3 *db);
int  db_create_schema(sqlite3 *db);
int  db_apply_update(sqlite3 *db, const char *json_data);
int  db_get_version(sqlite3 *db);
int  db_get_record_count(sqlite3 *db);
int  db_lookup_phone(sqlite3 *db, const char *phone, ThreatAssessment *out);
int  db_lookup_domain(sqlite3 *db, const char *domain, ThreatAssessment *out);

/* ─── ML functions ───────────────────────────────────────────────────────── */
int ml_load_all_models(const char *dir, MLContext *ml);
int ml_load_model(MLContext *ml, const char *path, const char *type);
int ml_get_version(const MLContext *ml, const char *type);
void ml_unload_all_models(MLContext *ml);
float ml_classify_text(MLContext *ml, const char *text, int text_len);
float ml_classify_email(MLContext *ml, const char *subject, const char *body);

/* ─── Analyzer functions ─────────────────────────────────────────────────── */
ThreatAssessment phone_analyzer_run(SEContext *ctx, const char *number,
                                    const char *caller_id, int64_t timestamp);
ThreatAssessment sms_analyzer_run(SEContext *ctx, const SMSInfo *sms);
ThreatAssessment email_analyzer_run(SEContext *ctx, const EmailInfo *email);
ThreatAssessment whatsapp_analyzer_run(SEContext *ctx, const WhatsAppInfo *wa);

/* ─── Pattern matcher ────────────────────────────────────────────────────── */
int pattern_match_text(const char *text, char *category_out, int category_len);

/* ─── Fall detector ──────────────────────────────────────────────────────── */
void       fall_detector_init(FallContext *ctx, int sensitivity);
void       fall_detector_set_sensitivity(FallContext *ctx, int sensitivity);
FallResult fall_detector_process(FallContext *ctx, const SensorData *data);

/* ─── SOS ────────────────────────────────────────────────────────────────── */
int sos_trigger(SOSContext *ctx, const char **contacts, int count);
int sos_cancel(SOSContext *ctx);
int sos_test(SOSContext *ctx);

/* ─── Crypto ─────────────────────────────────────────────────────────────── */
int crypto_encrypt_aes256gcm(const uint8_t *pt, int pt_len,
                             uint8_t *ct, int *ct_len,
                             const uint8_t *key);
int crypto_decrypt_aes256gcm(const uint8_t *ct, int ct_len,
                             uint8_t *pt, int *pt_len,
                             const uint8_t *key);

#endif /* SE_INTERNAL_H */
