import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:permission_handler/permission_handler.dart';

part 'security_status_provider.g.dart';

class SecurityHealth {
  final bool smsGranted;
  final bool phoneGranted;
  final bool notificationAccessGranted;
  final bool accessibilityGranted;

  SecurityHealth({
    required this.smsGranted,
    required this.phoneGranted,
    required this.notificationAccessGranted,
    required this.accessibilityGranted,
  });

  bool get isFullyProtected => 
    smsGranted && phoneGranted && notificationAccessGranted && accessibilityGranted;
}

@riverpod
class SecurityStatus extends _$SecurityStatus {
  static const _channel = MethodChannel('ai_security/status');

  @override
  FutureOr<SecurityHealth> build() async {
    return _checkAll();
  }

  Future<SecurityHealth> _checkAll() async {
    final sms = await Permission.sms.isGranted;
    final phone = await Permission.phone.isGranted;
    
    bool notif = false;
    bool access = false;
    
    try {
      notif = await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
      access = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled') ?? false;
    } catch (e) {
      debugPrint('[SecurityStatus] Permission check failed: $e');
      // Remain false — treated as "not granted" so the guardian prompts the user
    }

    return SecurityHealth(
      smsGranted: sms,
      phoneGranted: phone,
      notificationAccessGranted: notif,
      accessibilityGranted: access,
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
}
