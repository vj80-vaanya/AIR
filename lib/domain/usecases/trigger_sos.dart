import '../../core/errors/failure.dart';
import '../../services/notifications/notification_service.dart';

part 'trigger_sos.g.dart';

class TriggerSOSParams {
  const TriggerSOSParams(
      {required this.contacts, this.latitude, this.longitude});
  final List<String> contacts;
  final double? latitude;
  final double? longitude;
}

// SOS triggering is handled via sos_provider.dart.
// This use-case is a stub kept for future backend integration.
class TriggerSOS {
  const TriggerSOS(this._notifications);
  final NotificationService _notifications;

  Future<({bool success, Failure? failure})> call(
      TriggerSOSParams p) async {
    try {
      await _notifications.showSOSActivated();
      return (success: true, failure: null);
    } catch (e) {
      return (success: false, failure: UnexpectedFailure(e.toString()));
    }
  }
}
