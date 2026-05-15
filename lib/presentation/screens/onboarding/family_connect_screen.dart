import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';

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
            const Spacer(),
            const Icon(Icons.people, size: 80, color: AppColors.secondary),
            const SizedBox(height: Spacing.lg),
            Text(
              'Connect with Family',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Share your protection status and location with trusted family members.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            AppButton(
              label:   'Share QR Code',
              icon:    Icons.qr_code,
              variant: AppButtonVariant.primary,
              onPressed: () {
                /* Show QR code modal */
                showModalBottomSheet(
                  context: context,
                  builder: (_) => const _QRSheet(),
                );
              },
              minHeight: TouchTarget.primary,
            ),
            const SizedBox(height: Spacing.md),
            AppButton(
              label:     'Skip for now',
              variant:   AppButtonVariant.outline,
              onPressed: () => context.go('/dashboard'),
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
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200, height: 200,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Text('QR code placeholder', textAlign: TextAlign.center),
          ),
          const SizedBox(height: Spacing.md),
          Text('Ask a family member to scan this code in their app.',
               style: Theme.of(context).textTheme.bodyMedium,
               textAlign: TextAlign.center),
          const SizedBox(height: Spacing.md),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            child: const Text('Done'),
          ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}
