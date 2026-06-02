import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Static-singleton settings store backed by SharedPreferences.
/// Call [init] once in main() before using any getter or setter.
class SettingsRepository {
  static const _kThreshold        = 'prot_threshold';
  static const _kCallProtect      = 'prot_call';
  static const _kSmsProtect       = 'prot_sms';
  static const _kWaProtect        = 'prot_wa';
  static const _kEmailProtect     = 'prot_email';
  static const _kSosCountdown     = 'sos_countdown';
  static const _kVoiceTrigger     = 'sos_voice';
  static const _kFallDetection    = 'sos_fall';
  static const _kFallSensitivity  = 'sos_fall_sens';
  static const _kOnboardingDone    = 'onboarding_done';
  static const _kEmergencyContacts = 'emergency_contacts';
  static const _kFamilyMembers     = 'family_members';
  static const _kDeviceId           = 'device_id';
  static const _kQuietHoursEnabled  = 'quiet_hours_on';
  static const _kQuietHoursStart    = 'quiet_hours_start';
  static const _kQuietHoursEnd      = 'quiet_hours_end';
  static const _kFirstRunDone       = 'first_run_done';

  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  // ── Protection ────────────────────────────────────────────────────────────
  static double get threshold      => _p.getDouble(_kThreshold) ?? 75.0;
  static bool   get callProtect    => _p.getBool(_kCallProtect) ?? true;
  static bool   get smsProtect     => _p.getBool(_kSmsProtect) ?? true;
  static bool   get waProtect      => _p.getBool(_kWaProtect) ?? true;
  static bool   get emailProtect   => _p.getBool(_kEmailProtect) ?? true;

  static Future<void> setThreshold(double v)  async => _p.setDouble(_kThreshold, v);
  static Future<void> setCallProtect(bool v)  async => _p.setBool(_kCallProtect, v);
  static Future<void> setSmsProtect(bool v)   async => _p.setBool(_kSmsProtect, v);
  static Future<void> setWaProtect(bool v)    async => _p.setBool(_kWaProtect, v);
  static Future<void> setEmailProtect(bool v) async => _p.setBool(_kEmailProtect, v);

  // ── SOS / Fall ────────────────────────────────────────────────────────────
  static int    get sosCountdown    => _p.getInt(_kSosCountdown) ?? 5;
  static bool   get voiceTrigger    => _p.getBool(_kVoiceTrigger) ?? false;
  static bool   get fallDetection   => _p.getBool(_kFallDetection) ?? true;
  static double get fallSensitivity => _p.getDouble(_kFallSensitivity) ?? 2.0;

  static Future<void> setSosCountdown(int v)       async => _p.setInt(_kSosCountdown, v);
  static Future<void> setVoiceTrigger(bool v)      async => _p.setBool(_kVoiceTrigger, v);
  static Future<void> setFallDetection(bool v)     async => _p.setBool(_kFallDetection, v);
  static Future<void> setFallSensitivity(double v) async => _p.setDouble(_kFallSensitivity, v);

  // ── Onboarding ────────────────────────────────────────────────────────────
  static bool get onboardingDone => _p.getBool(_kOnboardingDone) ?? false;
  static Future<void> setOnboardingDone()   async => _p.setBool(_kOnboardingDone, true);
  static Future<void> resetOnboardingDone() async => _p.remove(_kOnboardingDone);

  // ── Emergency contacts  [{name, phone}] ──────────────────────────────────
  static List<Map<String, String>> get emergencyContacts {
    final raw = _p.getString(_kEmergencyContacts);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setEmergencyContacts(List<Map<String, String>> c) async =>
      _p.setString(_kEmergencyContacts, jsonEncode(c));

  // ── Device identity (for family QR code) ─────────────────────────────────
  static String get deviceId {
    final stored = _p.getString(_kDeviceId);
    if (stored != null && stored.isNotEmpty) return stored;
    final rng   = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    final id    = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    _p.setString(_kDeviceId, id);
    return id;
  }

  // ── Family members (ContactModel JSON) ───────────────────────────────────
  static List<Map<String, dynamic>> get familyMembers {
    final raw = _p.getString(_kFamilyMembers);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setFamilyMembers(List<Map<String, dynamic>> m) async =>
      _p.setString(_kFamilyMembers, jsonEncode(m));

  static Future<void> clearAll() async => _p.clear();

  // ── Quiet hours (silence threat notifications during sleep) ───────────────
  static bool get quietHoursEnabled => _p.getBool(_kQuietHoursEnabled) ?? false;
  static int  get quietHoursStart   => _p.getInt(_kQuietHoursStart)   ?? 22;  // 10 PM
  static int  get quietHoursEnd     => _p.getInt(_kQuietHoursEnd)     ?? 7;   // 7 AM

  static Future<void> setQuietHoursEnabled(bool v) async => _p.setBool(_kQuietHoursEnabled, v);
  static Future<void> setQuietHoursStart(int h)   async => _p.setInt(_kQuietHoursStart, h);
  static Future<void> setQuietHoursEnd(int h)     async => _p.setInt(_kQuietHoursEnd, h);

  static bool isInQuietHours() {
    if (!quietHoursEnabled) return false;
    final now   = DateTime.now().hour;
    final start = quietHoursStart;
    final end   = quietHoursEnd;
    if (start <= end) return now >= start && now < end;
    return now >= start || now < end; // overnight window e.g. 22–7
  }

  // ── First-run onboarding tour ─────────────────────────────────────────────
  static bool get firstRunDone => _p.getBool(_kFirstRunDone) ?? false;
  static Future<void> setFirstRunDone() async => _p.setBool(_kFirstRunDone, true);
}
