import 'package:freezed_annotation/freezed_annotation.dart';

part 'protection_status.freezed.dart';

@freezed
class ProtectionStatus with _$ProtectionStatus {
  const factory ProtectionStatus({
    required int     score,           /* 0–100 */
    required int     threatsBlockedToday,
    required int     threatsBlockedWeek,
    required bool    callProtectionActive,
    required bool    smsProtectionActive,
    required bool    whatsappProtectionActive,
    required bool    emailProtectionActive,
    required bool    fallDetectionActive,
    required DateTime lastUpdated,
  }) = _ProtectionStatus;

  factory ProtectionStatus.initial() => ProtectionStatus(
    score: 100,
    threatsBlockedToday: 0,
    threatsBlockedWeek:  0,
    callProtectionActive:      true,
    smsProtectionActive:       true,
    whatsappProtectionActive:  true,
    emailProtectionActive:     true,
    fallDetectionActive:       true,
    lastUpdated: DateTime.now(),
  );
}
