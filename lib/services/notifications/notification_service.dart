import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelThreat = AndroidNotificationDetails(
    'threats',
    'Threat Alerts',
    channelDescription: 'Alerts for detected scams',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channelSOS = AndroidNotificationDetails(
    'sos',
    'SOS Alerts',
    channelDescription: 'Emergency SOS notifications',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
  );

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
  }

  Future<void> showThreatDetected({
    required String sender,
    required String category,
    required int    riskScore,
  }) async {
    await _plugin.show(
      riskScore,
      'Threat detected from $sender',
      '$category — risk score $riskScore',
      const NotificationDetails(android: _channelThreat),
    );
  }

  Future<void> showSOSActivated() async {
    await _plugin.show(
      9999,
      'SOS Alert Sent',
      'Your emergency contacts have been notified.',
      const NotificationDetails(android: _channelSOS),
    );
  }

  Future<void> showFallDetected() async {
    await _plugin.show(
      9998,
      'Fall detected',
      'Are you okay? Your contacts will be alerted if you don\'t respond.',
      const NotificationDetails(android: _channelSOS),
    );
  }

  Future<void> showCriticalAlert({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      9997,
      title,
      body,
      const NotificationDetails(android: _channelSOS),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
