import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/settings_repository.dart';

part 'family_provider.g.dart';

@riverpod
class FamilyMembers extends _$FamilyMembers {
  @override
  AsyncValue<List<ContactModel>> build() {
    final stored  = SettingsRepository.familyMembers;
    final members = stored.map((m) => ContactModel.fromJson(m)).toList();
    return AsyncData(members);
  }

  Future<void> addMember(ContactModel contact) async {
    final current = state.valueOrNull ?? [];

    // Normalise phone digits for duplicate check (ignores formatting differences)
    final digits = _digitsOnly(contact.phone);
    if (digits.isNotEmpty &&
        current.any((m) => _digitsOnly(m.phone) == digits)) {
      throw Exception(
          'A contact with this phone number is already in your list.');
    }

    final updated = [...current, contact];
    // Optimistic update
    state = AsyncData(updated);
    try {
      await SettingsRepository.setFamilyMembers(
        updated.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      // Rollback so the UI doesn't show a contact that wasn't saved
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> removeMember(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((c) => c.id != id).toList();
    state = AsyncData(updated);
    try {
      await SettingsRepository.setFamilyMembers(
        updated.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }

  static String _digitsOnly(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');
}
