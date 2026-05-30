import 'package:flutter/material.dart';
import '../../../core/utils/extensions.dart';

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.score, this.size = 48});

  final int    score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = score.riskColor;

    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [color.withOpacity(0.85), color],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:  color.withOpacity(0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: TextStyle(
          color:      Colors.white,
          fontWeight: FontWeight.w800,
          fontSize:   size * 0.28,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Compact pill badge for inline use (e.g. list subtitles).
class RiskPill extends StatelessWidget {
  const RiskPill({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score.riskColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(
        score.riskLabel,
        style: TextStyle(
          color:      color,
          fontSize:   11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
