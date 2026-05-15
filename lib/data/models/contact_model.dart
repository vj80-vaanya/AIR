import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact_model.freezed.dart';
part 'contact_model.g.dart';

@freezed
class ContactModel with _$ContactModel {
  const factory ContactModel({
    required String  id,
    required String  name,
    required String  phone,
    String?          avatarUrl,
    @Default(false) bool isEmergencyContact,
    @Default(false) bool isFamilyMember,
  }) = _ContactModel;

  factory ContactModel.fromJson(Map<String, dynamic> json) =>
      _$ContactModelFromJson(json);
}
