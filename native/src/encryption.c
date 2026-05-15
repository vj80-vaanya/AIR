#include "internal.h"
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <string.h>

#define AES256GCM_KEY_LEN  32
#define AES256GCM_IV_LEN   12
#define AES256GCM_TAG_LEN  16

/* Layout: [ IV (12) | TAG (16) | ciphertext ] */

int crypto_encrypt_aes256gcm(const uint8_t *pt, int pt_len,
                             uint8_t *ct, int *ct_len,
                             const uint8_t *key) {
    if (!pt || !ct || !ct_len || !key || pt_len <= 0) return -1;

    uint8_t iv[AES256GCM_IV_LEN];
    if (RAND_bytes(iv, AES256GCM_IV_LEN) != 1) return -1;

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return -1;

    int ok = 1;
    int out_len = 0;
    uint8_t *out = ct + AES256GCM_IV_LEN + AES256GCM_TAG_LEN;

    ok &= EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL) == 1;
    ok &= EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv) == 1;
    ok &= EVP_EncryptUpdate(ctx, out, &out_len, pt, pt_len) == 1;

    int final_len = 0;
    ok &= EVP_EncryptFinal_ex(ctx, out + out_len, &final_len) == 1;
    ok &= EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG,
                               AES256GCM_TAG_LEN, ct + AES256GCM_IV_LEN) == 1;

    EVP_CIPHER_CTX_free(ctx);
    if (!ok) return -1;

    memcpy(ct, iv, AES256GCM_IV_LEN);
    *ct_len = AES256GCM_IV_LEN + AES256GCM_TAG_LEN + out_len + final_len;
    return 0;
}

int crypto_decrypt_aes256gcm(const uint8_t *ct, int ct_len,
                             uint8_t *pt, int *pt_len,
                             const uint8_t *key) {
    if (!ct || !pt || !pt_len || !key) return -1;
    int min_len = AES256GCM_IV_LEN + AES256GCM_TAG_LEN + 1;
    if (ct_len < min_len) return -1;

    const uint8_t *iv  = ct;
    uint8_t tag[AES256GCM_TAG_LEN];
    memcpy(tag, ct + AES256GCM_IV_LEN, AES256GCM_TAG_LEN);
    const uint8_t *data = ct + AES256GCM_IV_LEN + AES256GCM_TAG_LEN;
    int data_len = ct_len - AES256GCM_IV_LEN - AES256GCM_TAG_LEN;

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) return -1;

    int ok = 1;
    int out_len = 0;

    ok &= EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL) == 1;
    ok &= EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv) == 1;
    ok &= EVP_DecryptUpdate(ctx, pt, &out_len, data, data_len) == 1;
    ok &= EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG,
                               AES256GCM_TAG_LEN, tag) == 1;

    int final_len = 0;
    int auth_ok = EVP_DecryptFinal_ex(ctx, pt + out_len, &final_len);
    EVP_CIPHER_CTX_free(ctx);

    if (!ok || auth_ok != 1) return -1;
    *pt_len = out_len + final_len;
    return 0;
}
