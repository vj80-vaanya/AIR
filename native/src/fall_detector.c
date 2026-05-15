#include "internal.h"
#include <math.h>
#include <string.h>

#define FALL_FREEFALL_THRESH  3.0f   /* m/s² — near-zero accel magnitude */
#define FALL_IMPACT_THRESH   25.0f   /* m/s² — sudden spike after freefall */
#define FALL_STILL_THRESH     2.0f   /* m/s² — post-impact stillness */

static float accel_magnitude(float x, float y, float z) {
    return sqrtf(x * x + y * y + z * z);
}

void fall_detector_init(FallContext *ctx, int sensitivity) {
    memset(ctx, 0, sizeof(*ctx));
    ctx->sensitivity = sensitivity;
    ctx->baseline_accel_magnitude = 9.81f;
}

void fall_detector_set_sensitivity(FallContext *ctx, int sensitivity) {
    if (sensitivity < 1) sensitivity = 1;
    if (sensitivity > 3) sensitivity = 3;
    ctx->sensitivity = sensitivity;
}

FallResult fall_detector_process(FallContext *ctx, const SensorData *data) {
    FallResult result = {false, 0.0f, 0};

    float mag = accel_magnitude(data->accel_x, data->accel_y, data->accel_z);

    /* Store in sliding window */
    ctx->window[ctx->window_head % FALL_WINDOW] = *data;
    ctx->window_head++;

    if (ctx->window_head < 3) return result;

    /* Simple 3-phase fall detection: freefall → impact → stillness */
    int idx = ctx->window_head;
    SensorData *prev2 = &ctx->window[(idx - 3) % FALL_WINDOW];
    SensorData *prev1 = &ctx->window[(idx - 2) % FALL_WINDOW];
    SensorData *curr  = &ctx->window[(idx - 1) % FALL_WINDOW];

    float mag2 = accel_magnitude(prev2->accel_x, prev2->accel_y, prev2->accel_z);
    float mag1 = accel_magnitude(prev1->accel_x, prev1->accel_y, prev1->accel_z);
    float mag0 = accel_magnitude(curr->accel_x,  curr->accel_y,  curr->accel_z);

    float freefall_thresh = FALL_FREEFALL_THRESH * (4 - ctx->sensitivity);
    float impact_thresh   = FALL_IMPACT_THRESH   / (float)ctx->sensitivity;

    bool freefall = (mag2 < freefall_thresh);
    bool impact   = (mag1 > impact_thresh);
    bool still    = (mag0 < FALL_STILL_THRESH);

    if (freefall && impact && still) {
        result.fall_detected = true;
        result.confidence    = 0.85f;
        result.severity      = (mag1 > 40.0f) ? 4 : (mag1 > 30.0f) ? 3 : 2;
    }

    return result;
}
