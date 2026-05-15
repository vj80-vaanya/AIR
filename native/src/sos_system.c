#include "internal.h"
#include <stdio.h>
#include <string.h>

int sos_trigger(SOSContext *ctx, const char **contacts, int count) {
    if (ctx->active) return -1; /* already active */
    ctx->active = true;
    fprintf(stderr, "[SOS] Triggered. Contacting %d emergency contacts.\n", count);
    for (int i = 0; i < count; i++) {
        fprintf(stderr, "[SOS]  -> %s\n", contacts[i]);
    }
    /* Platform-side (Dart via FFI callback) handles actual dialing and SMS */
    return 0;
}

int sos_cancel(SOSContext *ctx) {
    if (!ctx->active) return -1;
    ctx->active    = false;
    ctx->test_mode = false;
    fprintf(stderr, "[SOS] Cancelled.\n");
    return 0;
}

int sos_test(SOSContext *ctx) {
    ctx->test_mode = true;
    fprintf(stderr, "[SOS] Test mode triggered.\n");
    return 0;
}
