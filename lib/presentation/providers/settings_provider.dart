import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engine/security_engine.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/background/fall_detection_service.dart';

class AppSettings {
  final double threshold;
  final bool   callProtect;
  final bool   smsProtect;
  final bool   waProtect;
  final bool   emailProtect;
  final int    sosCountdown;
  final bool   voiceTrigger;
  final bool   fallDetection;
  final double fallSensitivity;

  const AppSettings({
    this.threshold       = 85.0,
    this.callProtect     = true,
    this.smsProtect      = true,
    this.waProtect       = true,
    this.emailProtect    = true,
    this.sosCountdown    = 5,
    this.voiceTrigger    = false,
    this.fallDetection   = true,
    this.fallSensitivity = 2.0,
  });

  AppSettings copyWith({
    double? threshold,
    bool?   callProtect,
    bool?   smsProtect,
    bool?   waProtect,
    bool?   emailProtect,
    int?    sosCountdown,
    bool?   voiceTrigger,
    bool?   fallDetection,
    double? fallSensitivity,
  }) =>
      AppSettings(
        threshold:       threshold ?? this.threshold,
        callProtect:     callProtect ?? this.callProtect,
        smsProtect:      smsProtect ?? this.smsProtect,
        waProtect:       waProtect ?? this.waProtect,
        emailProtect:    emailProtect ?? this.emailProtect,
        sosCountdown:    sosCountdown ?? this.sosCountdown,
        voiceTrigger:    voiceTrigger ?? this.voiceTrigger,
        fallDetection:   fallDetection ?? this.fallDetection,
        fallSensitivity: fallSensitivity ?? this.fallSensitivity,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
      : super(AppSettings(
          threshold:       SettingsRepository.threshold,
          callProtect:     SettingsRepository.callProtect,
          smsProtect:      SettingsRepository.smsProtect,
          waProtect:       SettingsRepository.waProtect,
          emailProtect:    SettingsRepository.emailProtect,
          sosCountdown:    SettingsRepository.sosCountdown,
          voiceTrigger:    SettingsRepository.voiceTrigger,
          fallDetection:   SettingsRepository.fallDetection,
          fallSensitivity: SettingsRepository.fallSensitivity,
        ));

  Future<void> setThreshold(double v) async {
    state = state.copyWith(threshold: v);
    await SettingsRepository.setThreshold(v);
    SecurityEngine.instance.setBlockThreshold(v);
  }

  Future<void> setCallProtect(bool v) async {
    state = state.copyWith(callProtect: v);
    await SettingsRepository.setCallProtect(v);
  }

  Future<void> setSmsProtect(bool v) async {
    state = state.copyWith(smsProtect: v);
    await SettingsRepository.setSmsProtect(v);
  }

  Future<void> setWaProtect(bool v) async {
    state = state.copyWith(waProtect: v);
    await SettingsRepository.setWaProtect(v);
  }

  Future<void> setEmailProtect(bool v) async {
    state = state.copyWith(emailProtect: v);
    await SettingsRepository.setEmailProtect(v);
  }

  Future<void> setSosCountdown(int v) async {
    state = state.copyWith(sosCountdown: v);
    await SettingsRepository.setSosCountdown(v);
  }

  Future<void> setVoiceTrigger(bool v) async {
    state = state.copyWith(voiceTrigger: v);
    await SettingsRepository.setVoiceTrigger(v);
  }

  Future<void> setFallDetection(bool v) async {
    state = state.copyWith(fallDetection: v);
    await SettingsRepository.setFallDetection(v);
    // Start or stop the live sensor subscription immediately.
    if (v) {
      FallDetectionService.instance.restart();
    } else {
      FallDetectionService.instance.stop();
    }
  }

  Future<void> setFallSensitivity(double v) async {
    state = state.copyWith(fallSensitivity: v);
    await SettingsRepository.setFallSensitivity(v);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
