#include <gtest/gtest.h>
#include "security_engine.h"
#include <cstring>
#include <vector>

static const uint8_t TEST_KEY[32] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
    0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
    0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F,
};

TEST(Encryption, RoundTripShortMessage) {
    const char *msg = "Hello, scam protection!";
    int pt_len = (int)strlen(msg);

    std::vector<uint8_t> ct(pt_len + 64);
    int ct_len = 0;
    ASSERT_EQ(se_encrypt_data((const uint8_t *)msg, pt_len,
                              ct.data(), &ct_len, TEST_KEY), 0);
    EXPECT_GT(ct_len, pt_len);

    std::vector<uint8_t> decrypted(pt_len + 1);
    int decrypted_len = 0;
    ASSERT_EQ(se_decrypt_data(ct.data(), ct_len,
                              decrypted.data(), &decrypted_len, TEST_KEY), 0);
    EXPECT_EQ(decrypted_len, pt_len);
    EXPECT_EQ(memcmp(decrypted.data(), msg, (size_t)pt_len), 0);
}

TEST(Encryption, TamperedCiphertextRejected) {
    const char *msg = "Sensitive OTP data";
    int pt_len = (int)strlen(msg);
    std::vector<uint8_t> ct(pt_len + 64);
    int ct_len = 0;
    ASSERT_EQ(se_encrypt_data((const uint8_t *)msg, pt_len,
                              ct.data(), &ct_len, TEST_KEY), 0);

    ct[20] ^= 0xFF; /* corrupt one byte */

    std::vector<uint8_t> out(pt_len + 1);
    int out_len = 0;
    EXPECT_NE(se_decrypt_data(ct.data(), ct_len, out.data(), &out_len, TEST_KEY), 0);
}

TEST(Encryption, NullInputsRejected) {
    uint8_t buf[64];
    int len = 0;
    EXPECT_NE(se_encrypt_data(nullptr, 10, buf, &len, TEST_KEY), 0);
    EXPECT_NE(se_encrypt_data((const uint8_t *)"x", 1, nullptr, &len, TEST_KEY), 0);
}
