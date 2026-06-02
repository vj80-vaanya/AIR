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

  // Apply persisted block threshold so engine behaviour matches user setting.
  SecurityEngine.instance.setBlockThreshold(SettingsRepository.threshold);

  // Start call/SMS monitoring immediately — pattern analysis works before ML loads.
  // This closes the ~5-10s window where calls arrived before the engine was ready.
  CallMonitoringService.instance.start();
  SMSMonitoringService.instance.start();

  // Load ML model in background; remaining services require the engine to be warm.
  SecurityEngine.instance.init().then((_) async {
    NotificationMonitoringService(SecurityEngine.instance).start();
    DeepScanService(SecurityEngine.instance).start();
    TransactionShieldService(SecurityEngine.instance).start();
    RemoteAccessShieldService(SecurityEngine.instance).start();

    if (SettingsRepository.fallDetection) {
      FallDetectionService.instance.start();
    }

    await WeeklyReportService.instance.maybeShow();
  });

  runApp(const ProviderScope(child: AISecurityApp()));
}
