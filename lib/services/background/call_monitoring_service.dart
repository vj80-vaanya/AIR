import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../../core/engine/security_engine.dart';
import '../../core/events/threat_event_bus.dart';
import '../../data/datasources/local/database_manager.dart';
import '../notifications/notification_service.dart';

class CallMonitoringService {
  CallMonitoringService._();
  static final CallMonitoringService instance = CallMonitoringService._();

  static const _channel = EventChannel('ai_security/call_events');
  static final _rng = math.Random.secure();

  void start() {
    _channel.receiveBroadcastStream().listen(
      _onCallEvent,
      onError: (e) => _onError('call', e),
      cancelOnError: false, // keep stream alive on errors
    );
  }

  Future<void> _onCallEvent(dynamic event) async {
    if (event is! Map) return;
    final phone    = event['phoneNumber']  as String? ?? '';
    final callerId = event['callerId']     as String? ?? '';
    final isKnown  = event['isKnownContact'] as bool? ?? false;

    final result = await SecurityEngine.instance.analyzeCall(
      phoneNumber:    phone,
      callerId:       callerId,
      isKnownContact: isKnown,
    );

    if (result.riskScore >= 60) {
      try {
        final db = await DatabaseManager.database;
        await db.insert('threats', {
          'id':         '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(0xFFFFFF)}_call',
          'channel':    'call',
          'sender':     phone.isEmpty ? 'Unknown' : phone,
          'risk_score': result.riskScore,
          'category':   result.category,
          'reason':     result.reason,
          'timestamp':  DateTime.now().toIso8601String(),
          'was_blocked': result.shouldBlock ? 1 : 0,
          'detail':     callerId,
        });
      } catch (e) {
        // DB write failure must not kill the EventChannel listener
        _onError('call-db', e);
      }

      await NotificationService.instance.showThreatDetected(
        sender:    phone.isEmpty ? 'Unknown' : phone,
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
