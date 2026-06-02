import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/onboarding_step_bar.dart';

class SOSSetupScreen extends StatefulWidget {
  const SOSSetupScreen({super.key});
  @override
  State<SOSSetupScreen> createState() => _SOSSetupScreenState();
}

class _SOSSetupScreenState extends State<SOSSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contacts = <({TextEditingController name, TextEditingController phone})>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addContact();

    final saved = SettingsRepository.emergencyContacts;
    if (saved.isNotEmpty) {
      for (final c in _contacts) {
        c.name.dispose();
        c.phone.dispose();
      }
      _contacts.clear();
      for (final c in saved) {
        _contacts.add((
          name:  TextEditingController(text: c['name'] ?? ''),
          phone: TextEditingController(text: c['phone'] ?? ''),
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _contacts) {
      c.name.dispose();
      c.phone.dispose();
    }
    super.dispose();
  }

  bool get _hasUnsavedData => _contacts.any(
    (c) => c.name.text.trim().isNotEmpty || c.phone.text.trim().isNotEmpty,
  );

  void _addContact() {
    if (_contacts.length >= 3) return;
    setState(() {
      _contacts.add((
        name:  TextEditingController(),
        phone: TextEditingController(),
      ));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final contacts = _contacts
        .where((c) => c.name.text.trim().isNotEmpty && c.phone.text.trim().isNotEmpty)
        .map((c) => {'name': c.name.text.trim(), 'phone': c.phone.text.trim()})
        .toList();

    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Please add at least one emergency contact — they will be called when you press SOS.',
          ),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 4),
        ));
        setState(() => _saving = false);
      }
      return;
    }

    await SettingsRepository.setEmergencyContacts(contacts);
    await SettingsRepository.setOnboardingDone();

    if (mounted) {
      setState(() => _saving = false);
      context.go('/onboarding/family-connect');
    }
  }

  Future<bool> _onPopRequested() async {
    if (!_hasUnsavedData) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard contacts?'),
        content: const Text(
          'You have entered emergency contact details that have not been saved.\n\n'
          'Going back will lose this information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:  false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canPop = await _onPopRequested();
        if (canPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('SOS Contacts')),
        resizeToAvoidBottomInset: true,
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: OnboardingStepBar(step: 3),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    children: [
                      Text(
                        'Add up to 3 people who will be called and texted automatically when you press the SOS button.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:        AppColors.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.info.withOpacity(0.25)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.info, size: 14),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'These are your SOS emergency contacts. You can also add family members in the Family tab later — those are separate and for visibility only.',
                                style: TextStyle(
                                    color: AppColors.info,
                                    fontSize: 12,
                                    height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Expanded(
                        child: ListView.separated(
                          itemCount:        _contacts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
                          itemBuilder: (_, i) => _ContactRow(
                            index:     i + 1,
                            nameCtrl:  _contacts[i].name,
                            phoneCtrl: _contacts[i].phone,
                          ),
                        ),
                      ),
                      if (_contacts.length < 3)
                        TextButton.icon(
                          onPressed: _addContact,
                          icon:  const Icon(Icons.add),
                          label: const Text('Add another contact'),
                        ),
                      const SizedBox(height: Spacing.md),
                      AppButton(
                        label:     'Save & Continue',
                        loading:   _saving,
                        onPressed: _save,
                        minHeight: TouchTarget.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.index,
    required this.nameCtrl,
    required this.phoneCtrl,
  });

  final int                   index;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact $index', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        TextFormField(
          controller:      nameCtrl,
          decoration: const InputDecoration(
            labelText:   'Name',
            prefixIcon:  Icon(Icons.person),
          ),
          validator:       Validators.name,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: Spacing.sm),
        TextFormField(
          controller:   phoneCtrl,
          decoration: const InputDecoration(
            labelText:  'Phone Number',
            prefixIcon: Icon(Icons.phone),
          ),
          validator:    Validators.phone,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }
}
