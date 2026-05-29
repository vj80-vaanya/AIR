import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/engine/security_engine.dart';
import 'data/repositories/settings_repository.dart';
import 'services/notifications/notification_service.dart';
import 'services/background/call_monitoring_service.dart';
import 'services/background/sms_monitoring_service.dart';
import 'services/background/notification_monitoring_service.dart';
import 'services/background/deep_scan_service.dart';
import 'services/background/transaction_shield_service.dart';
import 'services/background/remote_access_shield_service.dart';
import 'services/background/fall_detection_service.dart';
import 'services/reports/weekly_report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Settings must initialise before any SettingsRepository access
  await SettingsRepository.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:        Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  // Boot security engine — app launches immediately
  SecurityEngine.instance.init().then((_) async {
    CallMonitoringService.instance.start();
    SMSMonitoringService.instance.start();
    NotificationMonitoringService(SecurityEngine.instance).start();
    DeepScanService(SecurityEngine.instance).start();
    TransactionShieldService(SecurityEngine.instance).start();
    RemoteAccessShieldService(SecurityEngine.instance).start();

    if (SettingsRepository.fallDetection) {
      FallDetectionService.instance.start();
    }

    // Weekly safety report (fires on Sunday or after 7-day gap)
    await WeeklyReportService.instance.maybeShow();
  });

  runApp(const ProviderScope(child: AISecurityApp()));
}
