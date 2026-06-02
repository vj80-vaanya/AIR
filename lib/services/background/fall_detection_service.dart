import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/repositories/settings_repository.dart';
import '../notifications/notification_service.dart';

/// 3-phase fall detector: freefall window → impact spike → SOS in 15 s.
///
/// When a fall is detected:
/// 1. Shows a high-priority "Fall detected" notification
/// 2. Waits 15 seconds (user can tap notification to cancel)
/// 3. Automatically sends SOS to emergency contacts via the native channel
class FallDetectionService {
  FallDetectionService._();
  static final FallDetectionService instance = FallDetectionService._();

  static const _sosChannel = MethodChannel('ai_security/sos');

  StreamSubscription<AccelerometerEvent>? _accelSub;

  // State machine
  bool      _inFreefall     = false;
  DateTime? _freefallStart;
  bool      _cooldown       = false;
  bool      _sosPending     = false;  // true while waiting to send SOS

  /// Call this to cancel an in-progress fall SOS (e.g. user taps "I'm OK").
  void cancelPendingSOS() {
    _sosPending = false;
    debugPrint('[FallDetection] SOS cancelled by user');
  }

  void start() {
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen(_onAccel);
  }

  void stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _inFreefall = false;
    _freefallStart = null;
    _sosPending = false;
  }

  void restart() {
    stop();
    start();
  }

  void _onAccel(AccelerometerEvent e) {
    if (!SettingsRepository.fallDetection) return;

    final mag         = _magnitude(e.x, e.y, e.z);
    final sensitivity = SettingsRepository.fallSensitivity; // 1.0–3.0

    final freefallThreshold = 3.0 + sensitivity;      // 4–6 m/s²
    final impactThreshold   = 26.0 - (sensitivity * 2.0); // 24–20 m/s²

    final now = DateTime.now();

    if (!_inFreefall && mag < freefallThreshold) {
      _inFreefall    = true;
      _freefallStart = now;
      return;
    }

    if (_inFreefall) {
      final elapsed = now.difference(_freefallStart!).inMilliseconds;
      if (elapsed > 1500) {
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

  Future<void> _triggerFall() async {
    if (_cooldown) return;
    _cooldown  = true;
    _sosPending = true;

    // Step 1: Show the "fall detected" notification immediately
    await NotificationService.instance.showFallDetected();
    debugPrint('[FallDetection] Fall detected — SOS in 15 seconds unless cancelled');

    // Step 2: Wait 15 seconds so the user can cancel if it was a false alarm
    await Future.delayed(const Duration(seconds: 15));

    // Step 3: Send SOS if not cancelled
    if (_sosPending) {
      _sosPending = false;
      await _dispatchFallSOS();
    }

    // Cooldown: prevent another SOS trigger for 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      _cooldown = false;
    });
  }

  Future<void> _dispatchFallSOS() async {
    final contacts = SettingsRepository.emergencyContacts;
    if (contacts.isEmpty) {
      await NotificationService.instance.showCriticalAlert(
        title: 'Fall SOS — No contacts',
        body:  'A fall was detected but no emergency contacts are configured.',
      );
      return;
    }

    debugPrint('[FallDetection] Dispatching SOS to ${contacts.length} contacts');
    try {
      await _sosChannel.invokeMethod('sendSosAlerts', {
        'contacts': contacts,
        'message':
            'FALL ALERT: I may have fallen and need urgent help. '
            'Please call me or come check immediately.',
      });
    } catch (e) {
      debugPrint('[FallDetection] SOS send failed: $e');
      await NotificationService.instance.showCriticalAlert(
        title: 'Fall SOS — Send failed',
        body:  'Could not send fall alert. Please call your family directly.',
      );
      return;
    }

    // Also attempt emergency call to first contact
    try {
      final firstPhone = contacts.first['phone'] ?? '';
      if (firstPhone.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        await _sosChannel.invokeMethod('makeEmergencyCall', {'phone': firstPhone});
      }
    } catch (e) {
      debugPrint('[FallDetection] Emergency call failed: $e');
    }

    await NotificationService.instance.showCriticalAlert(
      title: 'Fall SOS sent',
      body:  'Emergency contacts have been alerted about your fall.',
    );
  }

  static double _magnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);
}
