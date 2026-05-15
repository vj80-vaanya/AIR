import 'package:flutter/services.dart';
import '../../data/datasources/local/ffi_bridge.dart';
import '../notifications/notification_service.dart';

/// Listens to incoming call events via a platform channel and runs them
/// through the C engine for threat assessment.
class CallMonitoringService {
  CallMonitoringService._();
  static final CallMonitoringService instance = CallMonitoringService._();

  static const _channel = EventChannel('ai_security/call_events');

  void start() {
    _channel.receiveBroadcastStream().listen(_onCallEvent);
  }

  Future<void> _onCallEvent(dynamic event) async {
    if (event is! Map) return;
    final phone      = event['phoneNumber'] as String? ?? '';
    final callerId   = event['callerId']    as String? ?? '';
    final isKnown    = event['isKnown']     as bool?   ?? false;

    final result = FFIBridge.instance.analyzeCall(
      phoneNumber:   phone,
      callerId:      callerId,
      isKnownContact: isKnown,
    );

    final score = result['riskScore'] as int;
    if (score >= 60) {
      await NotificationService.instance.showThreatDetected(
        sender:    phone,
        category:  result['category'] as String,
        riskScore: score,
      );
    }
  }
}
