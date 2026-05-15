import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary   = Color(0xFF1A73E8);
  static const secondary = Color(0xFF34A853);
  static const danger    = Color(0xFFEA4335);
  static const warning   = Color(0xFFFBBC04);
  static const background = Color(0xFFF8F9FA);
  static const surface   = Color(0xFFFFFFFF);

  static const textPrimary   = Color(0xFF202124);
  static const textSecondary = Color(0xFF5F6368);
  static const textDisabled  = Color(0xFF9AA0A6);

  /* Risk level colors */
  static const riskNone   = Color(0xFF34A853);
  static const riskLow    = Color(0xFF8BC34A);
  static const riskMedium = Color(0xFFFBBC04);
  static const riskHigh   = Color(0xFFFF6D00);
  static const riskCritical = Color(0xFFEA4335);

  static Color riskColor(int score) {
    if (score < 20)  return riskNone;
    if (score < 40)  return riskLow;
    if (score < 60)  return riskMedium;
    if (score < 80)  return riskHigh;
    return riskCritical;
  }
}
