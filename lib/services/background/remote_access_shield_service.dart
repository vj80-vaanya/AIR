import 'dart:async';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../notifications/notification_service.dart';

class RemoteAccessShieldService {
  static const _channel = EventChannel('ai_security/remote_events');
  final SecurityEngine _engine;
  StreamSubscription? _subscription;

  RemoteAccessShieldService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen((event) async {
      final map = event as Map;
      final package = map['package'] as String;

      // Remote Access app detected (AnyDesk, TeamViewer, etc.)
      if (_engine.hasRecentCriticalThreat()) {
        final threat = _engine.getMostRecentThreat();
        
        // Trigger high-priority LOCKDOWN intervention
        await NotificationService.instance.showCriticalAlert(
          title: '🚨 REMOTE ACCESS LOCKDOWN',
          body: 'DANGER: You recently received a ${threat?.category} alert. Scammers often use apps like AnyDesk to steal money. Close this app immediately!',
        );

        print('Remote Access Shield Intercepted: $package during active threat');
      }
    });
  }

  void stop() => _subscription?.cancel();
}
