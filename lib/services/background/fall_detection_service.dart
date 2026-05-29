import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/repositories/settings_repository.dart';
import '../notifications/notification_service.dart';

/// 3-phase fall detector: freefall window → impact spike → confirm.
class FallDetectionService {
  FallDetectionService._();
  static final FallDetectionService instance = FallDetectionService._();

  StreamSubscription<AccelerometerEvent>? _accelSub;

  // State machine
  bool      _inFreefall    = false;
  DateTime? _freefallStart;
  bool      _cooldown      = false;

  void start() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen(_onAccel);
  }

  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _inFreefall = false;
    _freefallStart = null;
  }

  void restart() {
    stop();
    start();
  }

  void _onAccel(AccelerometerEvent e) {
    // Skip if fall detection is toggled off at runtime
    if (!SettingsRepository.fallDetection) return;

    final mag = _magnitude(e.x, e.y, e.z);
    final sensitivity = SettingsRepository.fallSensitivity; // 1.0 – 3.0

    // Phase 1 — Freefall: magnitude well below gravity (9.8 m/s²)
    // Threshold: 3 m/s² at low sensitivity, 5 m/s² at high sensitivity
    final freefallThreshold = 3.0 + sensitivity;   // 4–6 m/s²
    // Phase 2 — Impact: sharp spike above normal movement
    // Threshold: 24 m/s² at low sensitivity, 20 m/s² at high sensitivity
    final impactThreshold   = 26.0 - (sensitivity * 2.0); // 22–20 m/s²

    final now = DateTime.now();

    if (!_inFreefall && mag < freefallThreshold) {
      _inFreefall    = true;
      _freefallStart = now;
      return;
    }

    if (_inFreefall) {
      final elapsed = now.difference(_freefallStart!).inMilliseconds;

      if (elapsed > 1500) {
        // Too long — reset, likely a false positive (sitting down slowly, etc.)
        _inFreefall = false;
        _freefallStart = null;
        return;
      }

      if (mag > impactThreshold) {
        _inFreefall = false;
        _freefallStart = null;
        _triggerFall();
      }
    }
  }

  void _triggerFall() {
    if (_cooldown) return;
    _cooldown = true;
    NotificationService.instance.showFallDetected();
    // 60-second cooldown to prevent repeated false triggers
    Future.delayed(const Duration(seconds: 60), () => _cooldown = false);
  }

  static double _magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}
