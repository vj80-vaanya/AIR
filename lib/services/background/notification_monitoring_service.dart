import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../../core/events/threat_event_bus.dart';
import 'family_safety_relay.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';
import '../../data/datasources/local/database_manager.dart';

class NotificationMonitoringService {
  static const _channel = EventChannel('ai_security/notification_events');
  final SecurityEngine _engine;
  final _relay = FamilySafetyRelay();
  StreamSubscription? _subscription;

  NotificationMonitoringService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen((event) async {
      final map     = event as Map;
      final package = map['package'] as String;
      final sender  = map['sender']  as String;
      final body    = map['body']    as String;
      final isCall  = map['isCall']  as bool? ?? false;

      final assessment = isCall
          ? await _engine.analyzeCall(
              phoneNumber: sender,
              callerId:    'VoIP via $package',
            )
          : await _engine.analyzeNotification(
              package: package,
              sender:  sender,
              body:    body,
            );

      if (assessment.riskScore >= 70) {
        _engine.recordThreat(assessment);

        final threat = Threat(
          id:         DateTime.now().millisecondsSinceEpoch.toString(),
          channel:    _channel_(package),
          sender:     sender,
          riskScore:  assessment.riskScore,
          category:   assessment.category,
          reason:     assessment.reason,
          timestamp:  DateTime.now(),
          wasBlocked: assessment.shouldBlock,
          confidence: assessment.confidence,
          detail:     body,
        );

        final db = await DatabaseManager.database;
        await db.insert('threats', {
          'id':         threat.id,
          'channel':    threat.channel.name,
          'sender':     threat.sender,
          'risk_score': threat.riskScore,
          'category':   threat.category,
          'reason':     threat.reason,
          'timestamp':  threat.timestamp.toIso8601String(),
          'was_blocked': threat.wasBlocked ? 1 : 0,
          'detail':     threat.detail,
        });

        debugPrint('[NMS] ${threat.category} from ${threat.sender}');

        // Real-time dashboard refresh
        ThreatEventBus.instance.emit();

        // SMS family members on critical threats
        if (threat.riskScore >= 90) {
          _relay.relayCriticalThreat(threat);
        }
      }
    });
  }

  ThreatChannel _channel_(String package) {
    if (package.contains('whatsapp'))  return ThreatChannel.whatsapp;
    if (package.contains('telegram'))  return ThreatChannel.telegram;
    if (package.contains('instagram')) return ThreatChannel.instagram;
    if (package.contains('securesms')) return ThreatChannel.other; // Signal
    if (package.contains('orca'))      return ThreatChannel.other; // Messenger
    return ThreatChannel.other;
  }

  void stop() => _subscription?.cancel();
}
