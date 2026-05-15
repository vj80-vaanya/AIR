import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _loading = false;

  final _permissions = [
    (
      icon: Icons.phone,
      label: 'Phone Calls',
      reason: 'Detect and analyze incoming calls for scams.',
      permissions: [Permission.phone],
    ),
    (
      icon: Icons.sms,
      label: 'SMS',
      reason: 'Scan incoming messages for fraudulent content.',
      permissions: [Permission.sms],
    ),
    (
      icon: Icons.location_on,
      label: 'Location',
      reason: 'Share your location during SOS emergencies.',
      permissions: [Permission.location],
    ),
    (
      icon: Icons.notifications,
      label: 'Notifications',
      reason: 'Alert you instantly when threats are detected.',
      permissions: [Permission.notification],
    ),
  ];

  Future<void> _requestAll() async {
    setState(() => _loading = true);
    for (final p in _permissions) {
      for (final perm in p.permissions) {
        await perm.request();
      }
    }
    setState(() => _loading = false);
    if (mounted) context.go('/onboarding/sos-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: _permissions.map((p) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(20),
                    child: Icon(p.icon, color: AppColors.primary),
                  ),
                  title:    Text(p.label),
                  subtitle: Text(p.reason),
                )).toList(),
              ),
            ),
            AppButton(
              label:     'Grant All Permissions',
              icon:      Icons.check,
              loading:   _loading,
              onPressed: _requestAll,
              variant:   AppButtonVariant.primary,
              minHeight: TouchTarget.primary,
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}
