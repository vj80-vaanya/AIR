#include "internal.h"
#include <string.h>
#include <stdio.h>
#include <strings.h>

static const char *PHISHING_SUBJECTS[] = {
    "your account will be closed",
    "verify your information",
    "update your payment",
    "unauthorized access detected",
    "immediate action required",
    "your password has expired",
    NULL
};

static int score_subject(const char *subject) {
    int score = 0;
    for (int i = 0; PHISHING_SUBJECTS[i] != NULL; i++) {
        if (strcasestr(subject, PHISHING_SUBJECTS[i])) {
            score += 30;
        }
    }
    return score > 60 ? 60 : score;
}

/* Basic SPF/DKIM mismatch heuristic — display name vs address domain */
static int score_sender_mismatch(const char *display_name,
                                 const char *from_address) {
    if (!display_name || !from_address) return 0;

    /* If display name contains a domain-like word but the actual address
       domain differs, flag it */
    const char *known_brands[] = { "sbi", "hdfc", "icici", "paytm",
                                   "amazon", "flipkart", "google",
                                   "microsoft", "apple", NULL };
    for (int i = 0; known_brands[i] != NULL; i++) {
        bool in_name = (strcasestr(display_name, known_brands[i]) != NULL);
        bool in_addr = (strcasestr(from_address, known_brands[i]) != NULL);
        if (in_name && !in_addr) return 50;
    }
    return 0;
}

ThreatAssessment email_analyzer_run(SEContext *ctx, const EmailInfo *email) {
    ThreatAssessment result = {0};
    result.confidence = 0.75f;
    strncpy(result.category, "UNKNOWN", sizeof(result.category) - 1);

    int score = 0;

    score += score_subject(email->subject);
    score += score_sender_mismatch(email->display_name, email->from_address);

    int ml_score = 0;
    if (ctx->ml.loaded) {
        float prob = ml_classify_email(&ctx->ml, email->subject,
                                       email->body_preview);
        ml_score = (int)(prob * 100.0f);
        score = (score * 40 + ml_score * 60) / 100;
    }

    /* Suspicious attachment */
    if (email->has_attachment) {
        const char *dangerous_exts[] = { ".exe", ".bat", ".vbs", ".js",
                                          ".cmd", ".scr", NULL };
        for (int i = 0; dangerous_exts[i] != NULL; i++) {
            if (strcasestr(email->attachment_names, dangerous_exts[i])) {
                score += 40;
                break;
            }
        }
    }

    result.risk_score   = score > 100 ? 100 : score;
    result.should_block = result.risk_score >= 70;
    result.confidence   = ctx->ml.loaded ? 0.88f : 0.72f;

    if (result.risk_score >= 50) {
        strncpy(result.category, "PHISHING_EMAIL", sizeof(result.category) - 1);
    } else {
        strncpy(result.category, "LEGITIMATE", sizeof(result.category) - 1);
    }

    snprintf(result.reason, sizeof(result.reason),
             "Subject score + sender mismatch + ML. Final: %d",
             result.risk_score);
    return result;
}
