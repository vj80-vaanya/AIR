import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../providers/family_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.familyTitle)),
      body: membersAsync.when(
        loading: () => const LoadingIndicator(),
        error:   (e, _) => EmptyState(icon: Icons.error_outline, title: e.toString()),
        data: (members) => members.isEmpty
            ? EmptyState(
                icon:        Icons.people_outline,
                title:       'No family members yet',
                body:        'Invite family members to monitor each other\'s safety.',
                action:      () => _showInviteSheet(context),
                actionLabel: 'Invite family member',
              )
            : ListView.builder(
                itemCount:   members.length,
                itemBuilder: (_, i) {
                  final m = members[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(20),
                      child: Text(m.name.substring(0, 1).toUpperCase()),
                    ),
                    title:    Text(m.name),
                    subtitle: Text(m.phone),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInviteSheet(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _InviteSheet(),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.lg, right: Spacing.lg, top: Spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invite Family Member', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          const TextField(
            decoration: InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone)),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Send Invite'),
            ),
          ),
        ],
      ),
    );
  }
}
