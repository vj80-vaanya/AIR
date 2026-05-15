import 'package:flutter/services.dart';

import '../../core/engine/security_engine.dart';
import '../notifications/notification_service.dart';

class CallMonitoringService {
  CallMonitoringService._();
  static final CallMonitoringService instance = CallMonitoringService._();

  static const _channel = EventChannel('ai_security/call_events');

  void start() {
    _channel.receiveBroadcastStream().listen(_onCallEvent);
  }

  Future<void> _onCallEvent(dynamic event) async {
    if (event is! Map) return;
    final phone    = event['phoneNumber'] as String? ?? '';
    final callerId = event['callerId']    as String? ?? '';
    final isKnown  = event['isKnownContact'] as bool? ?? false;

    final result = await SecurityEngine.instance.analyzeCall(
      phoneNumber:   phone,
      callerId:      callerId,
      isKnownContact: isKnown,
    );

    if (result.riskScore >= 60) {
      await NotificationService.instance.showThreatDetected(
        sender:    phone,
        category:  result.category,
        riskScore: result.riskScore,
      );
    }
  }
}
