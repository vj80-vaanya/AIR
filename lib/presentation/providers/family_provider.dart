import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/settings_repository.dart';

part 'family_provider.g.dart';

@riverpod
class FamilyMembers extends _$FamilyMembers {
  @override
  AsyncValue<List<ContactModel>> build() {
    final stored = SettingsRepository.familyMembers;
    final members = stored.map((m) => ContactModel.fromJson(m)).toList();
    return AsyncData(members);
  }

  Future<void> addMember(ContactModel contact) async {
    final current = state.valueOrNull ?? [];
    final updated = [...current, contact];
    state = AsyncData(updated);
    await SettingsRepository.setFamilyMembers(
      updated.map((m) => m.toJson()).toList(),
    );
  }

  Future<void> removeMember(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((c) => c.id != id).toList();
    state = AsyncData(updated);
    await SettingsRepository.setFamilyMembers(
      updated.map((m) => m.toJson()).toList(),
    );
  }
}
