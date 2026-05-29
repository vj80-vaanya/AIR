import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary: Indigo ────────────────────────────────────────────────────────
  static const primary      = Color(0xFF6366F1); // indigo-500
  static const primaryDark  = Color(0xFF4F46E5); // indigo-600
  static const primaryLight = Color(0xFF818CF8); // indigo-400

  // ── Secondary: Emerald ────────────────────────────────────────────────────
  static const secondary     = Color(0xFF10B981); // emerald-500
  static const secondaryDark = Color(0xFF059669); // emerald-600

  // ── Status ─────────────────────────────────────────────────────────────────
  static const danger  = Color(0xFFF43F5E); // rose-500
  static const warning = Color(0xFFF59E0B); // amber-500
  static const info    = Color(0xFF3B82F6); // blue-500
  static const success = Color(0xFF10B981); // emerald-500

  // ── Light Backgrounds ─────────────────────────────────────────────────────
  static const background = Color(0xFFF8FAFC); // slate-50
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFE2E8F0); // slate-200

  // ── Dark Backgrounds ──────────────────────────────────────────────────────
  static const darkBg      = Color(0xFF0F172A); // slate-900
  static const darkSurface = Color(0xFF1E293B); // slate-800
  static const darkCard    = Color(0xFF1E293B); // slate-800
  static const borderDark  = Color(0xFF334155); // slate-700

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0F172A); // slate-900
  static const textSecondary = Color(0xFF64748B); // slate-500
  static const textDisabled  = Color(0xFF94A3B8); // slate-400
  static const textOnDark    = Color(0xFFF1F5F9); // slate-100

  // ── Gradient ──────────────────────────────────────────────────────────────
  static const gradientStart = Color(0xFF6366F1); // indigo-500
  static const gradientEnd   = Color(0xFF8B5CF6); // violet-500
  static const gradientSafe  = Color(0xFF10B981); // emerald-500
  static const gradientSos   = Color(0xFFF43F5E); // rose-500

  // ── Risk Colors (Tailwind-inspired) ───────────────────────────────────────
  static const riskNone     = Color(0xFF10B981); // emerald-500
  static const riskLow      = Color(0xFF84CC16); // lime-500
  static const riskMedium   = Color(0xFFF59E0B); // amber-500
  static const riskHigh     = Color(0xFFF97316); // orange-500
  static const riskCritical = Color(0xFFF43F5E); // rose-500

  static Color riskColor(int score) {
    if (score < 20) return riskNone;
    if (score < 40) return riskLow;
    if (score < 60) return riskMedium;
    if (score < 80) return riskHigh;
    return riskCritical;
  }
}
