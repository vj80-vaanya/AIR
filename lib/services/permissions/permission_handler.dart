import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  static Future<bool> requestMinimum() async {
    final results = await [
      Permission.phone,
      Permission.sms,
      Permission.notification,
    ].request();
    return results.values.every((s) => s.isGranted);
  }

  static Future<bool> requestSOS() async {
    final results = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
    ].request();
    return results.values.every((s) => s.isGranted);
  }

  static Future<bool> isGranted(Permission p) => p.isGranted;

  static Future<void> openAppSettings() => openAppSettings();
}
