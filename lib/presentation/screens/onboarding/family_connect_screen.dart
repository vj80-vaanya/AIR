import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/onboarding_step_bar.dart';

class FamilyConnectScreen extends StatelessWidget {
  const FamilyConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Connect')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            const OnboardingStepBar(step: 4),
            const Spacer(),
            const Icon(Icons.people, size: 80, color: AppColors.secondary),
            const SizedBox(height: Spacing.lg),
            Text(
              'Connect with Family',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Share your protection status and location with trusted family members.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AppButton(
              label:   'Share QR Code',
              icon:    Icons.qr_code,
              variant: AppButtonVariant.primary,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _QRSheet(),
                );
              },
              minHeight: TouchTarget.primary,
            ),
            const SizedBox(height: Spacing.md),
            AppButton(
              label:     'Skip for now',
              variant:   AppButtonVariant.outline,
              onPressed: () async {
                // Warn if no SOS contacts were configured
                final hasContacts =
                    SettingsRepository.emergencyContacts.isNotEmpty;
                if (!hasContacts && context.mounted) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('No SOS contacts added'),
                      content: const Text(
                        'You have not added any emergency contacts.\n\n'
                        'Without them, pressing the SOS button will not '
                        'alert anyone. You can add contacts later in '
                        'Settings → Manage SOS Contacts.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Go back and add'),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Continue anyway'),
                        ),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }
                await SettingsRepository.setOnboardingDone();
                if (context.mounted) context.go('/dashboard');
              },
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

class _QRSheet extends StatelessWidget {
  const _QRSheet();

  @override
  Widget build(BuildContext context) {
    final deviceId = SettingsRepository.deviceId;
    final qrData   = 'aisecurity://connect?id=$deviceId';
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 12, Spacing.lg, Spacing.xl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width:  40,
              height: 4,
              margin:     const EdgeInsets.only(bottom: Spacing.lg),
              decoration: BoxDecoration(
                color:        isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const Text(
              'Your Family Connect Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask a family member to scan this code in their app.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.lg),

            // QR code card
            Container(
              padding:    const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data:            qrData,
                version:         QrVersions.auto,
                size:            220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color:    Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color:           Colors.black,
                ),
              ),
            ),

            const SizedBox(height: Spacing.md),

            // Copy code row
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: deviceId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device code copied')),
                );
              },
              child: Container(
                padding:    const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:        isDark
                      ? Colors.white10
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deviceId.substring(0, 16),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize:   13,
                        color:      isDark ? Colors.white60 : AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size:  14,
                      color: AppColors.textDisabled,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Spacing.lg),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await SettingsRepository.setOnboardingDone();
                  if (context.mounted) context.go('/dashboard');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding:         const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
