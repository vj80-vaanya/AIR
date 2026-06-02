import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../notifications/notification_service.dart';

class RemoteAccessShieldService {
  static const _channel = EventChannel('ai_security/remote_events');
  final SecurityEngine _engine;
  StreamSubscription? _subscription;

  RemoteAccessShieldService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => debugPrint('[RemoteAccessShield:stream] $e'),
      cancelOnError: false,
    );
  }

  Future<void> _onEvent(dynamic event) async {
    if (event is! Map) {
      debugPrint('[RemoteAccessShield] Unexpected event type: ${event.runtimeType}');
      return;
    }

    final package = event['package'] as String? ?? '';

    if (_engine.hasRecentCriticalThreat()) {
      final threat   = _engine.getMostRecentThreat();
      final catLabel = threat?.category ?? 'security threat';

      await NotificationService.instance.showCriticalAlert(
        title: 'REMOTE ACCESS WARNING',
        body:  'DANGER: You recently received a $catLabel alert. Scammers use apps like AnyDesk to steal money. Close this app immediately!',
      );

      debugPrint('[RemoteAccessShield] Intercepted $package during active threat');
    }
  }

  void stop() => _subscription?.cancel();
}
