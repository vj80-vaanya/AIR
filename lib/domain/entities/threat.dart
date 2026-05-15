import 'package:freezed_annotation/freezed_annotation.dart';
import '../../data/models/threat_model.dart';

part 'threat.freezed.dart';

@freezed
class Threat with _$Threat {
  const factory Threat({
    required String        id,
    required ThreatChannel channel,
    required String        sender,
    required int           riskScore,
    required String        category,
    required String        reason,
    required DateTime      timestamp,
    required bool          wasBlocked,
    @Default(0.0) double   confidence,
    String?                detail,
  }) = _Threat;
}
