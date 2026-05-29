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
    _subscription = _channel.receiveBroadcastStream().listen((event) async {
      final map = event as Map;
      final package = map['package'] as String;

      // Payment app detected (GPay, PhonePe, etc.)
      if (_engine.hasRecentCriticalThreat()) {
        final threat = _engine.getMostRecentThreat();
        
        // Trigger high-priority intervention
        await NotificationService.instance.showCriticalAlert(
          title: '⚠️ TRANSACTION SHIELD ACTIVE',
          body: 'You recently received a scam alert: ${threat?.category}. Are you being pressured to send money? Most "Digital Arrests" end with a fake payment request.',
        );

        debugPrint('Transaction Shield Intercepted: $package during active threat');
      }
    });
  }

  void stop() => _subscription?.cancel();
}
