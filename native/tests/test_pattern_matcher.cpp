#include <gtest/gtest.h>
#include "security_engine.h"
#include <cstring>

/* pattern_match_text is internal — expose via a thin test shim */
extern "C" int pattern_match_text(const char *text, char *cat, int cat_len);

TEST(PatternMatcher, BankingFraudDetected) {
    char cat[64] = {};
    int score = pattern_match_text("Your account has been suspended. Enter OTP to unlock.", cat, sizeof(cat));
    EXPECT_GT(score, 50);
    EXPECT_STREQ(cat, "BANKING_FRAUD");
}

TEST(PatternMatcher, LotteryScamDetected) {
    char cat[64] = {};
    int score = pattern_match_text("Congratulations you have won Rs 50 lakh in lucky draw!", cat, sizeof(cat));
    EXPECT_GT(score, 70);
    EXPECT_STREQ(cat, "LOTTERY");
}

TEST(PatternMatcher, LegitimateMessageLowScore) {
    char cat[64] = {};
    int score = pattern_match_text("Your order has been delivered. Thank you for shopping.", cat, sizeof(cat));
    EXPECT_LT(score, 30);
}

TEST(PatternMatcher, NullInputSafe) {
    char cat[64] = {};
    int score = pattern_match_text(nullptr, cat, sizeof(cat));
    EXPECT_EQ(score, 0);
}
