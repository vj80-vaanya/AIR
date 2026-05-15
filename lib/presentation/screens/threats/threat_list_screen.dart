import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../data/models/threat_model.dart';
import '../../providers/threat_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/risk_badge.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/extensions.dart';

class ThreatListScreen extends ConsumerWidget {
  const ThreatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final threatsAsync    = ref.watch(filteredThreatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.alertsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _ChannelFilterBar(selected: selectedChannel),
        ),
      ),
      body: threatsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading alerts…'),
        error:   (e, _) => EmptyState(
          icon:  Icons.error_outline,
          title: 'Could not load alerts',
          body:  e.toString(),
        ),
        data: (threats) => threats.isEmpty
            ? const EmptyState(
                icon:  Icons.shield_outlined,
                title: 'No threats detected',
                body:  'You are protected. Any threats will appear here.',
              )
            : ListView.separated(
                itemCount:       threats.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final t = threats[i];
                  return ListTile(
                    leading:  RiskBadge(score: t.riskScore),
                    title:    Text(t.sender),
                    subtitle: Text(Helpers.categoryLabel(t.category)),
                    trailing: Text(t.timestamp.relativeTime,
                                   style: Theme.of(context).textTheme.bodySmall),
                    onTap:    () => context.push('/threats/${t.id}'),
                  );
                },
              ),
      ),
    );
  }
}

class _ChannelFilterBar extends ConsumerWidget {
  const _ChannelFilterBar({required this.selected});
  final ThreatChannel? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = [
      (label: Strings.allAlerts,   value: null as ThreatChannel?),
      (label: Strings.callAlerts,  value: ThreatChannel.call),
      (label: Strings.smsAlerts,   value: ThreatChannel.sms),
      (label: Strings.waAlerts,    value: ThreatChannel.whatsapp),
      (label: Strings.emailAlerts, value: ThreatChannel.email),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      child: Row(
        children: tabs.map((t) {
          final isSelected = t.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: FilterChip(
              label:    Text(t.label),
              selected: isSelected,
              onSelected: (_) => ref.read(selectedChannelProvider.notifier).select(t.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}
