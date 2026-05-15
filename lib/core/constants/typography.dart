import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const _base = TextStyle(fontFamily: 'Inter', color: Color(0xFF202124));

  static final h1 = _base.copyWith(fontSize: 32, fontWeight: FontWeight.bold);
  static final h2 = _base.copyWith(fontSize: 28, fontWeight: FontWeight.bold);
  static final h3 = _base.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
  static final h4 = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);

  static final body1 = _base.copyWith(fontSize: 16, fontWeight: FontWeight.normal);
  static final body2 = _base.copyWith(fontSize: 14, fontWeight: FontWeight.normal);

  static final caption = _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
  static final label   = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);

  /* Elderly-safe minimum 16sp, scales to 24sp */
  static final elderlyBody = _base.copyWith(fontSize: 18, fontWeight: FontWeight.normal);
  static final elderlyLabel = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
}
