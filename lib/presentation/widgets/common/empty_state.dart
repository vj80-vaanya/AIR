import 'package:flutter/material.dart';
import '../../../core/constants/spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.actionLabel,
  });
  final IconData     icon;
  final String       title;
  final String?      body;
  final VoidCallback? action;
  final String?      actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: Spacing.md),
            Text(title,
                 style: Theme.of(context).textTheme.titleLarge,
                 textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(body!,
                   style: Theme.of(context).textTheme.bodyMedium,
                   textAlign: TextAlign.center),
            ],
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: Spacing.lg),
              FilledButton(onPressed: action, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
