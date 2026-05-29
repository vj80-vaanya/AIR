import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../widgets/common/app_button.dart';

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

    // Pre-fill from any existing saved contacts
    final saved = SettingsRepository.emergencyContacts;
    if (saved.isNotEmpty) {
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

    await SettingsRepository.setEmergencyContacts(contacts);
    await SettingsRepository.setOnboardingDone();

    if (mounted) {
      setState(() => _saving = false);
      context.go('/onboarding/family-connect');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Contacts')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            children: [
              Text(
                'Add up to 3 people who will be called automatically during an SOS.',
                style: Theme.of(context).textTheme.bodyMedium,
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
