import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// Standard themed card — border + subtle shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
  });

  final Widget        child;
  final VoidCallback? onTap;
  final EdgeInsets?   padding;
  final Color?        color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark ? AppColors.darkCard : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: _padded(child),
              )
            : _padded(child),
      ),
    );
  }

  Widget _padded(Widget w) =>
      padding != null ? Padding(padding: padding!, child: w) : w;
}

/// Frosted-glass card — works best over gradient or image backgrounds.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.opacity = 0.12,
    this.blurSigma = 14,
    this.borderColor,
  });

  final Widget        child;
  final VoidCallback? onTap;
  final EdgeInsets?   padding;
  final double?       borderRadius;
  final double        opacity;
  final double        blurSigma;
  final Color?        borderColor;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? 20.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.22),
              width: 1,
            ),
          ),
          child: onTap != null
              ? InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(r),
                  child: _padded(child),
                )
              : _padded(child),
        ),
      ),
    );
  }

  Widget _padded(Widget w) =>
      padding != null ? Padding(padding: padding!, child: w) : w;
}

/// Gradient card — vivid gradient background with optional glow.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.gradient,
    this.glowColor,
    this.borderRadius,
  });

  final Widget        child;
  final VoidCallback? onTap;
  final EdgeInsets?   padding;
  final Gradient?     gradient;
  final Color?        glowColor;
  final double?       borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? 24.0;
    final grad = gradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        );

    return Container(
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: (glowColor ?? AppColors.primary).withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(r),
                splashColor: Colors.white.withOpacity(0.1),
                child: _padded(child),
              )
            : _padded(child),
      ),
    );
  }

  Widget _padded(Widget w) =>
      padding != null ? Padding(padding: padding!, child: w) : w;
}
