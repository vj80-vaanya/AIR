import 'package:flutter/material.dart';
import '../../../core/constants/spacing.dart';

enum AppButtonVariant { primary, secondary, danger, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.minHeight = TouchTarget.min,
  });

  final String           label;
  final VoidCallback?    onPressed;
  final AppButtonVariant variant;
  final IconData?        icon;
  final bool             loading;
  final double           minHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = loading
        ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18),
                const SizedBox(width: Spacing.sm),
                Text(label),
              ])
            : Text(label);

    final style = switch (variant) {
      AppButtonVariant.primary   => ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
      AppButtonVariant.secondary => ElevatedButton.styleFrom(backgroundColor: cs.secondary, foregroundColor: cs.onSecondary),
      AppButtonVariant.danger    => ElevatedButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
      AppButtonVariant.outline   => ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary),
        ),
    };

    return SizedBox(
      width: double.infinity,
      height: minHeight,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: style,
        child: child,
      ),
    );
  }
}
