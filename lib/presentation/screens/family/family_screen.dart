import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/contact_model.dart';
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
            ? Column(
                children: [
                  _SosWarningBanner(),
                  Expanded(
                    child: EmptyState(
                      icon:        Icons.people_outline,
                      title:       'No family members yet',
                      body:        'Add family members so they receive an SOS alert and your location if you ever press the emergency button.',
                      action:      () => _showAddSheet(context),
                      actionLabel: 'Add family member',
                    ),
                  ),
                ],
              )
            : Column(
              children: [
                _SosWarningBanner(),
                Expanded(child: ListView.builder(
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
                    trailing: IconButton(
                      icon:      const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () =>
                          ref.read(familyMembersProvider.notifier).removeMember(m.id),
                    ),
                  );
                },
              )),
              ],
            )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddMemberSheet(),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet();
  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtr  = TextEditingController();
  final _phoneCtr = TextEditingController();
  bool _saving    = false;

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final contact = ContactModel(
      id:             DateTime.now().millisecondsSinceEpoch.toString(),
      name:           _nameCtr.text.trim(),
      phone:          _phoneCtr.text.trim(),
      isFamilyMember: true,
    );

    try {
      await ref.read(familyMembersProvider.notifier).addMember(contact);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${contact.name} added to your family'),
          backgroundColor: AppColors.secondary,
          duration:        const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left:   Spacing.lg,
        right:  Spacing.lg,
        top:    Spacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Family Member',
                 style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller:      _nameCtr,
              decoration: const InputDecoration(
                labelText:  'Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator:       Validators.name,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller:   _phoneCtr,
              decoration: const InputDecoration(
                labelText:  'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              validator:    Validators.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            color: AppColors.warning, size: 16),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'To receive SOS alerts, contacts must also be added in Settings → SOS & Fall Settings.',
            style: TextStyle(
                color: AppColors.warning, fontSize: 12, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
