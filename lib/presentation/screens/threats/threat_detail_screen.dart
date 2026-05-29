import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/helpers.dart';
import '../../providers/threat_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/risk_badge.dart';

class ThreatDetailScreen extends ConsumerWidget {
  const ThreatDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threatAsync = ref.watch(threatByIdProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Threat Details')),
      body: threatAsync.when(
        loading: () => const LoadingIndicator(),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (threat) {
          if (threat == null) {
            return const Center(child: Text('Threat not found.'));
          }
          return Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RiskBadge(score: threat.riskScore, size: 56),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Helpers.categoryLabel(threat.category),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'From: ${threat.sender}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                _InfoRow(label: 'Channel',  value: threat.channel.name.toUpperCase()),
                _InfoRow(label: 'Category', value: Helpers.categoryLabel(threat.category)),
                _InfoRow(label: 'Action',   value: threat.wasBlocked ? 'Blocked automatically' : 'Flagged for review'),
                _InfoRow(label: 'Time',     value: _formatTime(threat.timestamp)),
                const SizedBox(height: Spacing.md),
                Text('Reason', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: Spacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(threat.reason, style: Theme.of(context).textTheme.bodyMedium),
                ),
                if (threat.detail != null && threat.detail!.isNotEmpty) ...[
                  const SizedBox(height: Spacing.md),
                  Text('Message Content', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: Spacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      threat.detail!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon:  const Icon(Icons.thumb_down_outlined),
                        label: const Text('False Alarm'),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon:  const Icon(Icons.shield),
                        label: const Text('Confirm Scam'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
