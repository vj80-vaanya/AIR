import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (label: 'SOS',         icon: Icons.sos,          color: AppColors.danger,  path: '/sos'),
      (label: 'Scam Check',  icon: Icons.search,        color: AppColors.primary, path: '/threats'),
      (label: 'Family',      icon: Icons.people,        color: AppColors.secondary, path: '/family'),
      (label: 'Settings',    icon: Icons.settings,      color: AppColors.textSecondary, path: '/settings'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap:     true,
      physics:        const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 2.2,
      children: actions.map((a) => _ActionTile(
        label: a.label,
        icon:  a.icon,
        color: a.color,
        onTap: () => context.go(a.path),
      )).toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.icon, required this.color, required this.onTap});
  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(Radius.card),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(Radius.card),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: Spacing.sm),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
