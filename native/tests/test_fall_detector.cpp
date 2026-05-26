#include <gtest/gtest.h>
#include "security_engine.h"
#include <cstring>

class FallDetectorTest : public ::testing::Test {
protected:
    void SetUp() override {
        se_init(":memory:", "/nonexistent");
    }
    void TearDown() override {
        se_cleanup();
    }

    SensorData make_sensor(float ax, float ay, float az,
                           float gx = 0, float gy = 0, float gz = 0) {
        SensorData d{};
        d.accel_x = ax; d.accel_y = ay; d.accel_z = az;
        d.gyro_x  = gx; d.gyro_y  = gy; d.gyro_z  = gz;
        d.timestamp = 0;
        return d;
    }
};

TEST_F(FallDetectorTest, NormalWalkingNotFall) {
    SensorData d = make_sensor(0.1f, 9.8f, 0.2f);
    FallResult r = se_detect_fall(&d);
    EXPECT_FALSE(r.fall_detected);
}

TEST_F(FallDetectorTest, FreefallThenImpactThenStill) {
    /* Phase 1: freefall (near-zero accel) */
    SensorData freefall = make_sensor(0.5f, 0.3f, 0.4f);
    se_detect_fall(&freefall);

    /* Phase 2: impact spike */
    SensorData impact = make_sensor(20.0f, 18.0f, 15.0f);
    se_detect_fall(&impact);

    /* Phase 3: still */
    SensorData still = make_sensor(0.2f, 0.1f, 0.1f);
    FallResult r = se_detect_fall(&still);
    EXPECT_TRUE(r.fall_detected);
    EXPECT_GT(r.confidence, 0.5f);
    EXPECT_GE(r.severity, 1);
}

TEST_F(FallDetectorTest, NullDataReturnsNoFall) {
    FallResult r = se_detect_fall(nullptr);
    EXPECT_FALSE(r.fall_detected);
}
