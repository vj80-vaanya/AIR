import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../../core/engine/security_engine.dart';
import '../../core/events/threat_event_bus.dart';
import '../../data/datasources/local/database_manager.dart';
import '../notifications/notification_service.dart';

class SMSMonitoringService {
  SMSMonitoringService._();
  static final SMSMonitoringService instance = SMSMonitoringService._();

  static const _channel = EventChannel('ai_security/sms_events');
  static final _rng = math.Random.secure();

  void start() {
    _channel.receiveBroadcastStream().listen(
      _onSMSEvent,
      onError: (e) => _onError('sms', e),
      cancelOnError: false, // keep stream alive on errors
    );
  }

  Future<void> _onSMSEvent(dynamic event) async {
    if (event is! Map) return;
    final sender = event['sender']      as String? ?? '';
    final body   = event['body']        as String? ?? '';
    final hasUrl = event['containsUrl'] as bool?   ?? false;
    final url    = event['url']         as String? ?? '';

    final result = await SecurityEngine.instance.analyzeSms(
      sender:       sender,
      body:         body,
      containsUrl:  hasUrl,
      extractedUrl: url,
    );

    if (result.riskScore >= 60) {
      try {
        final db = await DatabaseManager.database;
        await db.insert('threats', {
          'id':         '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(0xFFFFFF)}_sms',
          'channel':    'sms',
          'sender':     sender.isEmpty ? 'Unknown' : sender,
          'risk_score': result.riskScore,
          'category':   result.category,
          'reason':     result.reason,
          'timestamp':  DateTime.now().toIso8601String(),
          'was_blocked': result.shouldBlock ? 1 : 0,
          'detail':     body,
        });
      } catch (e) {
        _onError('sms-db', e);
      }

      await NotificationService.instance.showThreatDetected(
        sender:    sender.isEmpty ? 'Unknown' : sender,
        category:  result.category,
        riskScore: result.riskScore,
      );

      SecurityEngine.instance.recordThreat(result);
      ThreatEventBus.instance.emit();
    }
  }

  void _onError(String tag, dynamic e) {
    // Log but never rethrow — keeps the stream alive.
  }
}
