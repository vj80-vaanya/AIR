import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
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
      final map = event as Map;
      final package = map['package'] as String;
      final sender = map['sender'] as String;
      final body = map['body'] as String;
      final isCall = map['isCall'] as bool? ?? false;

      late final ThreatResult assessment;
      
      if (isCall) {
        // Special logic for VOIP calls
        assessment = await _engine.analyzeCall(
          phoneNumber: sender,
          callerId: 'VOIP Call via $package',
        );
      } else {
        // Analyze cross-app message
        assessment = await _engine.analyzeNotification(
          package: package,
          sender: sender,
          body: body,
        );
      }

      if (assessment.riskScore >= 70) {
        _engine.recordThreat(assessment);
        
        final threat = Threat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          channel: _mapPackageToChannel(package),
          sender: sender,
          riskScore: assessment.riskScore,
          category: assessment.category,
          reason: assessment.reason,
          timestamp: DateTime.now(),
          wasBlocked: assessment.shouldBlock,
          confidence: assessment.confidence,
          detail: body,
        );
        
        // Persist threat to SQLite for history
        final db = await DatabaseManager.database;
        await db.insert('threats', {
          'id': threat.id,
          'channel': threat.channel.name,
          'sender': threat.sender,
          'risk_score': threat.riskScore,
          'category': threat.category,
          'reason': threat.reason,
          'timestamp': threat.timestamp.toIso8601String(),
          'was_blocked': threat.wasBlocked ? 1 : 0,
          'detail': threat.detail,
        });

        print('New Threat Persisted: ${threat.category} from ${threat.sender}');

        // Collaborative Defense: Relay critical threats to family
        if (threat.riskScore >= 90) {
           _relay.relayCriticalThreat(threat, 'GUARDIAN_PUBLIC_KEY_PLACEHOLDER');
        }
      }
    });
  }

  ThreatChannel _mapPackageToChannel(String package) {
    if (package.contains('whatsapp')) return ThreatChannel.whatsapp;
    // We could add Telegram/Signal to the enum, but for now map to whatsapp or sms
    return ThreatChannel.whatsapp; 
  }

  void stop() {
    _subscription?.cancel();
  }
}
