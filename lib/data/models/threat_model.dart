import 'package:freezed_annotation/freezed_annotation.dart';

part 'threat_model.freezed.dart';
part 'threat_model.g.dart';

enum ThreatChannel { call, sms, whatsapp, email }

@freezed
class ThreatModel with _$ThreatModel {
  const factory ThreatModel({
    required String          id,
    required ThreatChannel   channel,
    required String          sender,
    required int             riskScore,
    required String          category,
    required String          reason,
    required DateTime        timestamp,
    required bool            wasBlocked,
    @Default(0.0) double     confidence,
    String?                  detail,
  }) = _ThreatModel;

  factory ThreatModel.fromJson(Map<String, dynamic> json) =>
      _$ThreatModelFromJson(json);
}
