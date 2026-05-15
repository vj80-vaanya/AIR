import 'package:freezed_annotation/freezed_annotation.dart';

part 'safety_event.freezed.dart';

enum SafetyEventType { sosTriggered, sosCancelled, fallDetected, geofenceAlert, lowBattery }

@freezed
class SafetyEvent with _$SafetyEvent {
  const factory SafetyEvent({
    required String          id,
    required SafetyEventType type,
    required DateTime        timestamp,
    String?                  location,
    String?                  notes,
    @Default(false) bool     resolvedAsFlalseAlarm,
  }) = _SafetyEvent;
}
