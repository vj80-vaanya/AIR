import 'package:flutter/services.dart';

import '../../core/engine/security_engine.dart';
import '../notifications/notification_service.dart';

class SMSMonitoringService {
  SMSMonitoringService._();
  static final SMSMonitoringService instance = SMSMonitoringService._();

  static const _channel = EventChannel('ai_security/sms_events');

  void start() {
    _channel.receiveBroadcastStream().listen(_onSMSEvent);
  }

  Future<void> _onSMSEvent(dynamic event) async {
    if (event is! Map) return;
    final sender   = event['sender']      as String? ?? '';
    final body     = event['body']        as String? ?? '';
    final hasUrl   = event['containsUrl'] as bool?   ?? false;
    final url      = event['url']         as String? ?? '';

    final result = await SecurityEngine.instance.analyzeSms(
      sender:      sender,
      body:        body,
      containsUrl: hasUrl,
      extractedUrl: url,
    );

    if (result.riskScore >= 60) {
      await NotificationService.instance.showThreatDetected(
        sender:    sender,
        category:  result.category,
        riskScore: result.riskScore,
      );
    }
  }
}
