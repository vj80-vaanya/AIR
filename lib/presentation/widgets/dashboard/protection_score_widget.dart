import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../domain/entities/protection_status.dart';

class ProtectionScoreWidget extends StatelessWidget {
  const ProtectionScoreWidget({super.key, required this.status});
  final ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(100 - status.score);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value:           status.score / 100,
                    strokeWidth:     10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:      AlwaysStoppedAnimation(color),
                    strokeCap:       StrokeCap.round,
                  ),
                  Text(
                    '${status.score}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Protection Score',
                       style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    status.score >= 80
                        ? 'You are well protected'
                        : status.score >= 50
                            ? 'Some risks detected'
                            : 'High risk — review alerts',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    '${status.threatsBlockedToday} threats blocked today',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
