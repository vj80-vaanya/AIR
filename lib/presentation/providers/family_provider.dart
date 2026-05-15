import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/contact_model.dart';

part 'family_provider.g.dart';

@riverpod
class FamilyMembers extends _$FamilyMembers {
  @override
  AsyncValue<List<ContactModel>> build() => const AsyncData([]);

  Future<void> addMember(ContactModel contact) async {
    state = const AsyncLoading();
    /* In production: call backend API to invite member */
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, contact]);
  }

  Future<void> removeMember(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }
}
