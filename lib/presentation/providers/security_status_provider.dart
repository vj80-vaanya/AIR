import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:permission_handler/permission_handler.dart';

part 'security_status_provider.g.dart';

class SecurityHealth {
  final bool smsGranted;
  final bool phoneGranted;
  final bool callLogGranted;
  final bool notificationAccessGranted;
  final bool accessibilityGranted;

  SecurityHealth({
    required this.smsGranted,
    required this.phoneGranted,
    required this.callLogGranted,
    required this.notificationAccessGranted,
    required this.accessibilityGranted,
  });

  bool get isFullyProtected =>
      smsGranted && phoneGranted && callLogGranted &&
      notificationAccessGranted && accessibilityGranted;
}

@riverpod
class SecurityStatus extends _$SecurityStatus {
  static const _channel = MethodChannel('ai_security/status');

  @override
  FutureOr<SecurityHealth> build() async {
    return _checkAll();
  }

  Future<SecurityHealth> _checkAll() async {
    final sms     = await Permission.sms.isGranted;
    final phone   = await Permission.phone.isGranted;
    // READ_CALL_LOG is in the phone permission group; treat as granted if phone is
    final callLog = phone || await Permission.contacts.isGranted;

    bool notif  = false;
    bool access = false;

    try {
      notif  = await _channel.invokeMethod<bool>('isNotificationListenerEnabled')  ?? false;
      access = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled') ?? false;
    } catch (e) {
      debugPrint('[SecurityStatus] Permission check failed: $e');
    }

    return SecurityHealth(
      smsGranted:                   sms,
      phoneGranted:                 phone,
      callLogGranted:               callLog,
      notificationAccessGranted:    notif,
      accessibilityGranted:         access,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _checkAll());
  }

  Future<void> requestNotificationAccess() async {
    await _channel.invokeMethod('openNotificationListenerSettings');
  }

  Future<void> requestAccessibility() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  Future<void> requestSms() async {
    await Permission.sms.request();
    await refresh();
  }

  Future<void> requestPhone() async {
    await Permission.phone.request();
    await refresh();
  }

  Future<void> requestCallLog() async {
    // READ_CALL_LOG is bundled with phone on most Android versions;
    // request phone + contacts to cover all cases
    await [Permission.phone, Permission.contacts].request();
    await refresh();
  }
}
