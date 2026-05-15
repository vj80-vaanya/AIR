import 'package:flutter/material.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/helpers.dart';
import '../../../domain/entities/threat.dart';
import '../common/risk_badge.dart';

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key, required this.threats});
  final List<Threat> threats;

  @override
  Widget build(BuildContext context) {
    if (threats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              const SizedBox(height: Spacing.sm),
              Text('No threats detected recently',
                   style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics:    const NeverScrollableScrollPhysics(),
      itemCount:  threats.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _ThreatTile(threat: threats[i]),
    );
  }
}

class _ThreatTile extends StatelessWidget {
  const _ThreatTile({required this.threat});
  final Threat threat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      leading:  RiskBadge(score: threat.riskScore),
      title:    Text(threat.sender, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(Helpers.categoryLabel(threat.category),
                     style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(threat.timestamp.relativeTime,
                     style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
