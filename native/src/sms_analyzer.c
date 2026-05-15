#include "internal.h"
#include <string.h>
#include <stdio.h>

ThreatAssessment sms_analyzer_run(SEContext *ctx, const SMSInfo *sms) {
    ThreatAssessment result = {0};
    result.confidence = 0.5f;
    strncpy(result.category, "UNKNOWN", sizeof(result.category) - 1);

    char category[64] = {0};
    int pattern_score = pattern_match_text(sms->body, category, sizeof(category));

    int ml_score = 0;
    if (ctx->ml.loaded && sms->body[0] != '\0') {
        float ml_prob = ml_classify_text(&ctx->ml, sms->body,
                                        (int)strlen(sms->body));
        ml_score = (int)(ml_prob * 100.0f);
    }

    /* Domain reputation check for URLs */
    int url_score = 0;
    if (sms->contains_url && sms->extracted_url[0] != '\0') {
        ThreatAssessment domain_result = {0};
        if (db_lookup_domain(ctx->db, sms->extracted_url, &domain_result) == 0) {
            url_score = domain_result.risk_score;
        }
    }

    /* Weighted combination */
    int base_score;
    if (ctx->ml.loaded) {
        base_score = (pattern_score * 40 + ml_score * 45 + url_score * 15) / 100;
    } else {
        base_score = (pattern_score * 60 + url_score * 40) / 100;
    }

    result.risk_score   = base_score > 100 ? 100 : base_score;
    result.should_block = result.risk_score >= 75;
    result.confidence   = ctx->ml.loaded ? 0.85f : 0.70f;

    if (category[0] != '\0') {
        strncpy(result.category, category, sizeof(result.category) - 1);
    }

    snprintf(result.reason, sizeof(result.reason),
             "Pattern score: %d | ML score: %d | URL score: %d",
             pattern_score, ml_score, url_score);

    return result;
}
