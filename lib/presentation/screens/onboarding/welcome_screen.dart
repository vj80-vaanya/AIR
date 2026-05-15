import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../widgets/common/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color:        AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(Icons.security, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: Spacing.xl),
              Text(
                Strings.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                Strings.appTagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label:     'Get Started',
                icon:      Icons.arrow_forward,
                onPressed: () => context.go('/onboarding/permissions'),
              ),
              const SizedBox(height: Spacing.md),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: Text(
                  'I already have an account',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
