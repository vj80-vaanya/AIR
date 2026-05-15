import 'package:flutter/material.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/helpers.dart';
import '../../widgets/common/risk_badge.dart';

class ThreatDetailScreen extends StatelessWidget {
  const ThreatDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    /* In production load threat by id from repository */
    return Scaffold(
      appBar: AppBar(title: const Text('Threat Details')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RiskBadge(score: 92, size: 64),
            const SizedBox(height: Spacing.md),
            Text('Threat ID: $id', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.lg),
            _InfoRow(label: 'Category', value: Helpers.categoryLabel('BANKING_FRAUD')),
            _InfoRow(label: 'Reason',   value: 'Matched banking fraud keyword + OTP mention'),
            _InfoRow(label: 'Action',   value: 'Blocked automatically'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { /* report false positive */ },
                    icon:  const Icon(Icons.thumb_down_outlined),
                    label: const Text('False Alarm'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () { /* confirm scam */ },
                    icon:  const Icon(Icons.shield),
                    label: const Text('Confirm Scam'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
