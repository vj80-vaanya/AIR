#include "internal.h"
#include <string.h>
#include <stdio.h>

/* Prefixes commonly associated with Indian scam calls */
static const char *HIGH_RISK_PREFIXES[] = {
    "+92", "+880", "+60", "+66",   /* neighboring countries often spoofed */
    "00",                           /* international call with 00 dialing */
    NULL
};

static int check_prefix_risk(const char *number) {
    for (int i = 0; HIGH_RISK_PREFIXES[i] != NULL; i++) {
        if (strncmp(number, HIGH_RISK_PREFIXES[i],
                    strlen(HIGH_RISK_PREFIXES[i])) == 0) {
            return 40;
        }
    }
    return 0;
}

ThreatAssessment phone_analyzer_run(SEContext *ctx, const char *number,
                                    const char *caller_id, int64_t timestamp) {
    (void)timestamp;
    ThreatAssessment result = {0};
    result.confidence = 0.7f;
    strncpy(result.category, "UNKNOWN", sizeof(result.category) - 1);

    /* DB lookup first */
    if (db_lookup_phone(ctx->db, number, &result) == 0 && result.risk_score > 0) {
        result.confidence = 0.95f;
        return result;
    }

    int score = 0;

    /* Caller ID mismatch — display name doesn't match number pattern */
    if (caller_id && caller_id[0] != '\0') {
        if (strstr(caller_id, "Unknown") || strstr(caller_id, "Private")) {
            score += 20;
        }
    }

    score += check_prefix_risk(number);

    /* Number too short or too long for Indian standards (+91 XXXXXXXXXX) */
    size_t len = strlen(number);
    if (len < 10 || len > 14) {
        score += 25;
    }

    result.risk_score   = score > 100 ? 100 : score;
    result.should_block = result.risk_score >= 85;

    if (score >= 40) {
        strncpy(result.category, "SUSPICIOUS_CALL", sizeof(result.category) - 1);
    } else {
        strncpy(result.category, "UNVERIFIED", sizeof(result.category) - 1);
    }

    snprintf(result.reason, sizeof(result.reason),
             "Prefix risk + caller ID analysis. Score: %d", score);
    return result;
}
