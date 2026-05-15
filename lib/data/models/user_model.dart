import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String phone,
    String?         name,
    String?         avatarUrl,
    @Default(false) bool elderlyMode,
    @Default(85)    int  autoBlockThreshold,
    @Default(true)  bool fallDetectionEnabled,
    @Default(2)     int  fallSensitivity,
    @Default([])    List<String> emergencyContacts,
    @Default([])    List<String> familyMemberIds,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
