import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../../core/events/threat_event_bus.dart';
import 'family_safety_relay.dart';
import '../../domain/entities/threat.dart';
import '../../data/models/threat_model.dart';
import '../../data/datasources/local/database_manager.dart';

class DeepScanService {
  static const _channel = EventChannel('ai_security/deep_scan_events');
  final SecurityEngine _engine;
  final _relay = FamilySafetyRelay();
  StreamSubscription? _subscription;

  DeepScanService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen((event) async {
      final map     = event as Map;
      final package = map['package'] as String;
      final content = map['content'] as String;

      final assessment = await _engine.analyzeText(content);

      if (assessment.riskScore >= 75) {
        final threat = Threat(
          id:         DateTime.now().millisecondsSinceEpoch.toString(),
          channel:    _channel_(package),
          sender:     'Screen ($package)',
          riskScore:  assessment.riskScore,
          category:   assessment.category,
          reason:     'Deep scan: ${assessment.reason}',
          timestamp:  DateTime.now(),
          wasBlocked: false,
          confidence: assessment.confidence,
          detail:     content,
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
          'was_blocked': 0,
          'detail':     threat.detail,
        });

        debugPrint('[DSS] ${threat.category}');

        // Real-time dashboard refresh
        ThreatEventBus.instance.emit();

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
    return ThreatChannel.other;
  }

  void stop() => _subscription?.cancel();
}
