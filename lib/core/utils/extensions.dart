import 'package:flutter/material.dart';
import '../constants/colors.dart';

extension IntRiskX on int {
  Color get riskColor => AppColors.riskColor(this);

  String get riskLabel {
    if (this < 20) return 'Safe';
    if (this < 40) return 'Low Risk';
    if (this < 60) return 'Medium Risk';
    if (this < 80) return 'High Risk';
    return 'Critical';
  }

  bool get shouldBlock => this >= 75;
}

extension StringX on String {
  String get initials {
    final parts = trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get maskedPhone {
    if (length < 6) return this;
    return '${substring(0, 3)}****${substring(length - 3)}';
  }
}

extension DateTimeX on DateTime {
  String get relativeTime {
    final diff = DateTime.now().difference(this);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

extension BuildContextX on BuildContext {
  ThemeData  get theme  => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme  get text   => Theme.of(this).textTheme;
  Size       get screen => MediaQuery.sizeOf(this);
  bool       get isDark => Theme.of(this).brightness == Brightness.dark;
}
