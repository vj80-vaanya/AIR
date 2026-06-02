import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// Step progress bar shown at the top of every onboarding screen.
class OnboardingStepBar extends StatelessWidget {
  const OnboardingStepBar({super.key, required this.step});
  final int step; // 1-based, total = 4

  static const _total  = 4;
  static const _labels = ['Start', 'Permissions', 'SOS Contacts', 'Family'];

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final activeColor   = isLight ? AppColors.primary          : Colors.white.withOpacity(0.80);
    final inactiveColor = isLight ? AppColors.primary.withOpacity(0.30) : Colors.white.withOpacity(0.20);
    final labelColor    = isLight ? AppColors.textSecondary    : Colors.white54;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        children: [
          Text(
            'Step $step of $_total — ${_labels[step - 1]}',
            style: TextStyle(
              color:      labelColor,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_total, (i) {
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < _total - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color:        i < step ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
