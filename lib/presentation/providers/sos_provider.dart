import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/notifications/notification_service.dart';

part 'sos_provider.g.dart';

enum SOSState { idle, countdown, active, cancelled }

@riverpod
class SOS extends _$SOS {
  static const _sosChannel = MethodChannel('ai_security/sos');

  // Generation counter — each trigger() increments it so older loops self-abort.
  int _generation = 0;

  @override
  ({SOSState state, int countdown}) build() {
    final cd = SettingsRepository.sosCountdown;
    return (state: SOSState.idle, countdown: cd);
  }

  void trigger() {
    // Cancel any in-progress countdown before starting a new one.
    _generation++;
    final myGen = _generation;
    final cd    = SettingsRepository.sosCountdown;
    state = (state: SOSState.countdown, countdown: cd);
    _tick(cd, myGen);
  }

  void cancel() {
    _generation++; // invalidates any running loop
    final cd = SettingsRepository.sosCountdown;
    state = (state: SOSState.cancelled, countdown: cd);
  }

  void _tick(int total, int gen) async {
    for (int i = total; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      // Abort if cancelled, re-triggered, or provider disposed.
      if (_generation != gen) return;
      if (!_isAlive()) return;
      state = (state: SOSState.countdown, countdown: i - 1);
    }
    if (_generation != gen) return;
    if (!_isAlive()) return;
    state = (state: SOSState.active, countdown: 0);
    await _activateSOS();
  }

  /// Guards against writing to a disposed notifier.
  bool _isAlive() {
    try {
      // Accessing state on a disposed AutoDisposeNotifier throws StateError.
      // Use the generation as a proxy — if _generation was mutated by dispose
      // the check above already handled it; this is a belt-and-suspenders guard.
      final _ = state;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _activateSOS() async {
    await NotificationService.instance.showSOSActivated();

    final contacts = SettingsRepository.emergencyContacts;
    if (contacts.isEmpty) return;

    try {
      await _sosChannel.invokeMethod('sendSosAlerts', {
        'contacts': contacts,
        'message':  'SOS EMERGENCY! I need immediate help! Please call me right away.',
      });
    } catch (e) {
      debugPrint('[SOS] SMS failed: $e');
    }

    try {
      final firstPhone = contacts.first['phone'] ?? '';
      if (firstPhone.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        if (!_isAlive()) return;
        await _sosChannel.invokeMethod('makeEmergencyCall', {'phone': firstPhone});
      }
    } catch (e) {
      debugPrint('[SOS] Call failed: $e');
    }
  }
}
