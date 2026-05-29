import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';

enum AppButtonVariant { primary, secondary, danger, outline, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant    = AppButtonVariant.primary,
    this.loading    = false,
    this.minHeight  = TouchTarget.primary,
    this.expanded   = true,
  });

  final String           label;
  final VoidCallback?    onPressed;
  final IconData?        icon;
  final AppButtonVariant variant;
  final bool             loading;
  final double           minHeight;
  final bool             expanded;

  @override
  Widget build(BuildContext context) {
    Widget btn;

    switch (variant) {
      case AppButtonVariant.primary:
        btn = _GradientButton(
          label:     label,
          icon:      icon,
          loading:   loading,
          onPressed: onPressed,
          minHeight: minHeight,
          colors: const [AppColors.gradientStart, AppColors.gradientEnd],
          glowColor: AppColors.primary,
        );

      case AppButtonVariant.secondary:
        btn = _GradientButton(
          label:     label,
          icon:      icon,
          loading:   loading,
          onPressed: onPressed,
          minHeight: minHeight,
          colors: const [AppColors.secondary, AppColors.secondaryDark],
          glowColor: AppColors.secondary,
        );

      case AppButtonVariant.danger:
        btn = _GradientButton(
          label:     label,
          icon:      icon,
          loading:   loading,
          onPressed: onPressed,
          minHeight: minHeight,
          colors: [AppColors.danger, const Color(0xFFE11D48)],
          glowColor: AppColors.danger,
        );

      case AppButtonVariant.outline:
        btn = SizedBox(
          height: minHeight,
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPressed,
            icon:  icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
            label: loading
                ? const _Spinner(color: AppColors.primary)
                : Text(label),
          ),
        );

      case AppButtonVariant.ghost:
        btn = SizedBox(
          height: minHeight,
          child: TextButton.icon(
            onPressed: loading ? null : onPressed,
            icon:  icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
            label: Text(label),
          ),
        );
    }

    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    required this.minHeight,
    required this.colors,
    required this.glowColor,
    this.icon,
  });

  final String        label;
  final bool          loading;
  final VoidCallback? onPressed;
  final double        minHeight;
  final List<Color>   colors;
  final Color         glowColor;
  final IconData?     icon;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return AnimatedOpacity(
      opacity:  disabled ? 0.65 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: minHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color:  glowColor.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap:        disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor:  Colors.white.withOpacity(0.15),
            child: Center(
              child: loading
                  ? const _Spinner(color: Colors.white)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color:         Colors.white,
                            fontWeight:    FontWeight.w700,
                            fontSize:      16,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width:  20,
        height: 20,
        child:  CircularProgressIndicator(color: color, strokeWidth: 2.5),
      );
}
