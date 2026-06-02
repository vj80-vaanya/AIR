import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/engine/security_engine.dart';
import '../notifications/notification_service.dart';

class TransactionShieldService {
  static const _channel = EventChannel('ai_security/payment_events');
  final SecurityEngine _engine;
  StreamSubscription? _subscription;

  TransactionShieldService(this._engine);

  void start() {
    _subscription = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => debugPrint('[TransactionShield:stream] $e'),
      cancelOnError: false,
    );
  }

  Future<void> _onEvent(dynamic event) async {
    if (event is! Map) {
      debugPrint('[TransactionShield] Unexpected event type: ${event.runtimeType}');
      return;
    }

    final package = event['package'] as String? ?? '';

    if (_engine.hasRecentCriticalThreat()) {
      final threat    = _engine.getMostRecentThreat();
      final catLabel  = threat?.category ?? 'security threat';

      await NotificationService.instance.showCriticalAlert(
        title: 'TRANSACTION SHIELD ACTIVE',
        body:  'You recently received a $catLabel alert. Are you being pressured to send money? Most "Digital Arrests" end with a fake payment request.',
      );

      debugPrint('[TransactionShield] Intercepted $package during active threat');
    }
  }

  void stop() => _subscription?.cancel();
}
