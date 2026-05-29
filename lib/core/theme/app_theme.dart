import 'package:flutter/material.dart';
import '../constants/colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final cs = ColorScheme.fromSeed(
      seedColor:  AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary:          AppColors.primary,
      secondary:        AppColors.secondary,
      error:            AppColors.danger,
      surface:          isDark ? AppColors.darkSurface : Colors.white,
      onPrimary:        Colors.white,
      onSecondary:      Colors.white,
      surfaceContainerHighest: isDark
          ? const Color(0xFF334155) // slate-700
          : const Color(0xFFF1F5F9), // slate-100
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      fontFamily: 'Inter',
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBg : AppColors.background,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.darkBg : AppColors.background,
        foregroundColor:
            isDark ? AppColors.textOnDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkCard : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.borderDark.withOpacity(0.5)
            : AppColors.border.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
          color: AppColors.textDisabled,
          fontFamily: 'Inter',
          fontSize: 15,
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
        selectedColor: AppColors.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minLeadingWidth: 0,
        iconColor:
            isDark ? AppColors.textSecondary : AppColors.textSecondary,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.border),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Slider ────────────────────────────────────────────────────────────
      sliderTheme: const SliderThemeData(
        activeTrackColor:   AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor:         AppColors.primary,
        overlayColor:       Color(0x206366F1),
      ),

      // ── Navigation Bar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
