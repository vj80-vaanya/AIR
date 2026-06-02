import 'dart:async';
import 'dart:math' as math;
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
  static final _rng = math.Random.secure();
  final SecurityEngine _engine;
  final _relay = FamilySafetyRelay();
  StreamSubscription? _subscription;

  NotificationMonitoringService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => debugPrint('[NMS:stream] $e'),
      cancelOnError: false,
    );
  }

  Future<void> _onEvent(dynamic event) async {
    // Guard against unexpected event shape from native side
    if (event is! Map) {
      debugPrint('[NMS] Unexpected event type: ${event.runtimeType}');
      return;
    }

    final package = event['package'] as String? ?? '';
    final sender  = event['sender']  as String? ?? '';
    final body    = event['body']    as String? ?? '';
    final isCall  = event['isCall']  as bool?   ?? false;

    if (package.isEmpty && sender.isEmpty && body.isEmpty) return;

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

    // Use the same minimum recording threshold as call/SMS services (60)
    if (assessment.riskScore >= 60) {
      _engine.recordThreat(assessment);

      final threat = Threat(
        id:         '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(0xFFFFFF)}_notif',
        channel:    _resolveChannel(package),
        sender:     sender,
        riskScore:  assessment.riskScore,
        category:   assessment.category,
        reason:     assessment.reason,
        timestamp:  DateTime.now(),
        wasBlocked: assessment.shouldBlock,
        confidence: assessment.confidence,
        detail:     body,
      );

      try {
        final db = await DatabaseManager.database;
        await db.insert('threats', {
          'id':          threat.id,
          'channel':     threat.channel.name,
          'sender':      threat.sender,
          'risk_score':  threat.riskScore,
          'category':    threat.category,
          'reason':      threat.reason,
          'timestamp':   threat.timestamp.toIso8601String(),
          'was_blocked': threat.wasBlocked ? 1 : 0,
          'detail':      threat.detail,
        });
      } catch (e) {
        debugPrint('[NMS:db-write] $e');
      }

      debugPrint('[NMS] ${threat.category} from ${threat.sender}');
      ThreatEventBus.instance.emit();

      // SMS family members on critical threats
      if (threat.riskScore >= 90) {
        await _relay.relayCriticalThreat(threat);
      }
    }
  }

  ThreatChannel _resolveChannel(String package) {
    if (package.contains('whatsapp'))  return ThreatChannel.whatsapp;
    if (package.contains('telegram'))  return ThreatChannel.telegram;
    if (package.contains('instagram')) return ThreatChannel.instagram;
    if (package.contains('securesms')) return ThreatChannel.other;
    if (package.contains('orca'))      return ThreatChannel.other;
    return ThreatChannel.other;
  }

  void stop() => _subscription?.cancel();
}
