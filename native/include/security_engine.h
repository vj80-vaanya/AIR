#ifndef SECURITY_ENGINE_H
#define SECURITY_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SE_VERSION "1.0.0"
#define SE_MAX_CONTACTS 10
#define SE_MAX_ERROR_LEN 512

/* ─── Initialization ─────────────────────────────────────────────────────── */

int  se_init(const char *db_path, const char *model_path);
void se_cleanup(void);

/* ─── Threat Assessment ──────────────────────────────────────────────────── */

typedef struct {
    int   risk_score;       /* 0–100 */
    char  category[64];     /* "BANKING_FRAUD", "LOTTERY", "KYC", etc. */
    char  reason[256];      /* Human-readable explanation */
    bool  should_block;
    float confidence;       /* 0.0–1.0 */
} ThreatAssessment;

/* ─── Phone Call Analysis ────────────────────────────────────────────────── */

typedef struct {
    char    phone_number[32];
    char    caller_id[128];
    int64_t timestamp;
    bool    is_known_contact;
} CallInfo;

ThreatAssessment se_analyze_call(const CallInfo *call);

/* ─── SMS Analysis ───────────────────────────────────────────────────────── */

typedef struct {
    char sender[32];
    char body[4096];
    bool contains_url;
    char extracted_url[2048];
} SMSInfo;

ThreatAssessment se_analyze_sms(const SMSInfo *sms);

/* ─── Email Analysis ─────────────────────────────────────────────────────── */

typedef struct {
    char from_address[256];
    char display_name[128];
    char subject[512];
    char body_preview[2048];
    bool has_attachment;
    char attachment_names[1024];
} EmailInfo;

ThreatAssessment se_analyze_email(const EmailInfo *email);

/* ─── WhatsApp Analysis (metadata only) ──────────────────────────────────── */

typedef struct {
    char sender_phone[32];
    bool is_business_account;
    int  message_frequency_24h;
    bool contains_url;
    char url_domain[256];
} WhatsAppInfo;

ThreatAssessment se_analyze_whatsapp(const WhatsAppInfo *wa);

/* ─── Scam Database Management ───────────────────────────────────────────── */

int se_update_scam_db(const char *json_data);
int se_get_db_version(void);
int se_get_record_count(void);

/* ─── ML Model Management ────────────────────────────────────────────────── */

int se_load_model(const char *model_path, const char *model_type);
int se_get_model_version(const char *model_type);

/* ─── Fall Detection ─────────────────────────────────────────────────────── */

typedef struct {
    float   accel_x, accel_y, accel_z;
    float   gyro_x,  gyro_y,  gyro_z;
    int64_t timestamp;
} SensorData;

typedef struct {
    bool  fall_detected;
    float confidence;
    int   severity;    /* 1–5 */
} FallResult;

FallResult se_detect_fall(const SensorData *data);
void       se_calibrate_fall_detection(int sensitivity);  /* 1=Low, 2=Medium, 3=High */

/* ─── SOS System ─────────────────────────────────────────────────────────── */

int se_trigger_sos(const char **emergency_contacts, int contact_count);
int se_cancel_sos(void);
int se_test_sos(void);

/* ─── Encryption ─────────────────────────────────────────────────────────── */

int se_encrypt_data(const uint8_t *plaintext,  int plaintext_len,
                    uint8_t       *ciphertext, int *ciphertext_len,
                    const uint8_t *key);

int se_decrypt_data(const uint8_t *ciphertext, int ciphertext_len,
                    uint8_t       *plaintext,  int *plaintext_len,
                    const uint8_t *key);

/* ─── Utility ────────────────────────────────────────────────────────────── */

const char *se_get_last_error(void);
int         se_get_performance_stats(char *json_buffer, int buffer_size);

#ifdef __cplusplus
}
#endif

#endif /* SECURITY_ENGINE_H */
