import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/engine/security_engine.dart';
import 'services/notifications/notification_service.dart';
import 'services/background/notification_monitoring_service.dart';
import 'services/background/deep_scan_service.dart';
import 'services/background/transaction_shield_service.dart';
import 'services/background/remote_access_shield_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  // Boot security engine in background — app launches immediately
  SecurityEngine.instance.init().then((_) {
    NotificationMonitoringService(SecurityEngine.instance).start();
    DeepScanService(SecurityEngine.instance).start();
    TransactionShieldService(SecurityEngine.instance).start();
    RemoteAccessShieldService(SecurityEngine.instance).start();
  });

  runApp(const ProviderScope(child: AISecurityApp()));
}
