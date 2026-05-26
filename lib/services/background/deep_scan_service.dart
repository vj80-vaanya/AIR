import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';
import '../../data/datasources/local/database_manager.dart';
import 'family_safety_relay.dart';

class DeepScanService {
  static const _channel = EventChannel('ai_security/deep_scan_events');
  final SecurityEngine _engine;
  final _relay = FamilySafetyRelay();
  StreamSubscription? _subscription;

  DeepScanService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen((event) async {
      final map = event as Map;
      final package = map['package'] as String;
      final content = map['content'] as String;

      // Analyze screen content (fallback for when notifications are disabled)
      final assessment = await _engine.analyzeText(content);

      if (assessment.riskScore >= 75) {
        final threat = Threat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          channel: _mapPackageToChannel(package),
          sender: 'Screen Content ($package)',
          riskScore: assessment.riskScore,
          category: assessment.category,
          reason: 'Deep Protection: ${assessment.reason}',
          timestamp: DateTime.now(),
          wasBlocked: false, // Accessibility can't "block", but can warn
          confidence: assessment.confidence,
          detail: content,
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

        print('Deep Scan Threat Persisted: ${threat.category}');
        
        if (threat.riskScore >= 90) {
          _relay.relayCriticalThreat(threat, 'GUARDIAN_PUBLIC_KEY_PLACEHOLDER');
        }
      }
    });
  }

  ThreatChannel _mapPackageToChannel(String package) {
    if (package.contains('whatsapp')) return ThreatChannel.whatsapp;
    return ThreatChannel.whatsapp;
  }

  void stop() => _subscription?.cancel();
}
