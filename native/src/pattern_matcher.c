#include "internal.h"
#include <string.h>
#include <strings.h>
#include <stdio.h>

typedef struct {
    const char *keyword;
    const char *category;
    int         weight;
} PatternRule;

/* Ordered by specificity — first match wins for category assignment */
static const PatternRule RULES[] = {
    /* Banking fraud */
    { "your account has been suspended",   "BANKING_FRAUD",   90 },
    { "otp",                               "BANKING_FRAUD",   30 },
    { "kyc verification",                  "BANKING_FRAUD",   80 },
    { "upi pin",                           "BANKING_FRAUD",   85 },
    { "net banking",                       "BANKING_FRAUD",   40 },
    { "debit card",                        "BANKING_FRAUD",   35 },
    /* Lottery / prize */
    { "congratulations you have won",      "LOTTERY",         95 },
    { "lucky draw",                        "LOTTERY",         85 },
    { "prize money",                       "LOTTERY",         80 },
    { "claim your reward",                 "LOTTERY",         75 },
    /* Government impersonation */
    { "income tax department",             "GOVT_IMPERSONATION", 85 },
    { "aadhaar blocked",                   "GOVT_IMPERSONATION", 90 },
    { "police complaint",                  "GOVT_IMPERSONATION", 70 },
    { "court summons",                     "GOVT_IMPERSONATION", 80 },
    /* Delivery scams */
    { "your parcel is held",               "DELIVERY_SCAM",   80 },
    { "customs duty",                      "DELIVERY_SCAM",   70 },
    /* Generic urgency */
    { "immediate action required",         "URGENCY",         60 },
    { "click here to avoid",               "URGENCY",         65 },
    { "limited time offer",                "URGENCY",         40 },
    { NULL, NULL, 0 }
};

int pattern_match_text(const char *text, char *category_out, int category_len) {
    if (!text || !category_out || category_len <= 0) return 0;

    int total_score = 0;
    const char *top_category = "UNKNOWN";
    int top_weight = 0;

    for (int i = 0; RULES[i].keyword != NULL; i++) {
        /* Case-insensitive search — strcasestr is POSIX */
        if (strcasestr(text, RULES[i].keyword) != NULL) {
            total_score += RULES[i].weight;
            if (RULES[i].weight > top_weight) {
                top_weight   = RULES[i].weight;
                top_category = RULES[i].category;
            }
        }
    }

    if (total_score > 0) {
        strncpy(category_out, top_category, (size_t)category_len - 1);
        category_out[category_len - 1] = '\0';
    }

    /* Cap at 100 */
    return total_score > 100 ? 100 : total_score;
}
