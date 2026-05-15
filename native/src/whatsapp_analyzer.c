#include "internal.h"
#include <string.h>
#include <stdio.h>

ThreatAssessment whatsapp_analyzer_run(SEContext *ctx, const WhatsAppInfo *wa) {
    ThreatAssessment result = {0};
    result.confidence = 0.65f;
    strncpy(result.category, "UNKNOWN", sizeof(result.category) - 1);

    int score = 0;

    /* High message frequency is a spam indicator */
    if (wa->message_frequency_24h > 50)  score += 30;
    else if (wa->message_frequency_24h > 20) score += 15;

    /* URL domain reputation */
    if (wa->contains_url && wa->url_domain[0] != '\0') {
        ThreatAssessment domain_result = {0};
        if (db_lookup_domain(ctx->db, wa->url_domain, &domain_result) == 0) {
            score += domain_result.risk_score / 2;
        }
    }

    /* Non-business account sending many messages */
    if (!wa->is_business_account && wa->message_frequency_24h > 30) {
        score += 25;
    }

    result.risk_score   = score > 100 ? 100 : score;
    result.should_block = result.risk_score >= 70;

    if (result.risk_score >= 40) {
        strncpy(result.category, "WHATSAPP_SPAM", sizeof(result.category) - 1);
    } else {
        strncpy(result.category, "SAFE", sizeof(result.category) - 1);
    }

    snprintf(result.reason, sizeof(result.reason),
             "Message frequency: %d/24h | URL score included",
             wa->message_frequency_24h);
    return result;
}
