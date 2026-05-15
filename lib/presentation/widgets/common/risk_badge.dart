import 'package:flutter/material.dart';
import '../../../core/utils/extensions.dart';

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.score, this.size = 48});
  final int    score;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        color:        score.riskColor.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: score.riskColor, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: TextStyle(
          color:      score.riskColor,
          fontWeight: FontWeight.bold,
          fontSize:   14,
        ),
      ),
    );
  }
}
