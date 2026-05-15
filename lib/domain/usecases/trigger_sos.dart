import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/errors/failure.dart';
import '../../data/datasources/local/ffi_bridge.dart';
import '../../services/notifications/notification_service.dart';

part 'trigger_sos.g.dart';

class TriggerSOSParams {
  const TriggerSOSParams({required this.contacts, required this.latitude, required this.longitude});
  final List<String> contacts;
  final double?      latitude;
  final double?      longitude;
}

class TriggerSOS {
  const TriggerSOS(this._bridge, this._notifications);
  final FFIBridge           _bridge;
  final NotificationService _notifications;

  Future<({bool success, Failure? failure})> call(TriggerSOSParams p) async {
    try {
      final rc = _bridge.bindings.se_trigger_sos(
        /* contacts ptr built in FFIBridge helper — simplified here */
        _bridge.bindings.se_get_last_error().cast(),
        p.contacts.length,
      );
      if (rc != 0) return (success: false, failure: const SOSFailure('Engine rejected SOS'));

      await _notifications.showSOSActivated();
      return (success: true, failure: null);
    } catch (e) {
      return (success: false, failure: UnexpectedFailure(e.toString()));
    }
  }
}
