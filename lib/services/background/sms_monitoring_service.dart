import 'package:flutter/services.dart';
import '../../data/datasources/local/ffi_bridge.dart';
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
    final sender  = event['sender']  as String? ?? '';
    final body    = event['body']    as String? ?? '';
    final hasUrl  = event['hasUrl']  as bool?   ?? false;
    final url     = event['url']     as String? ?? '';

    final result = FFIBridge.instance.analyzeSms(
      sender:       sender,
      body:         body,
      containsUrl:  hasUrl,
      extractedUrl: url,
    );

    final score = result['riskScore'] as int;
    if (score >= 60) {
      await NotificationService.instance.showThreatDetected(
        sender:    sender,
        category:  result['category'] as String,
        riskScore: score,
      );
    }
  }
}
