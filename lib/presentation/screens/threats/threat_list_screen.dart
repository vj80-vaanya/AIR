import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/threat_model.dart';
import '../../../domain/entities/threat.dart';
import '../../providers/threat_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/risk_badge.dart';

class ThreatListScreen extends ConsumerWidget {
  const ThreatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final threatsAsync    = ref.watch(filteredThreatsProvider);
    final isDark          = context.isDark;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            floating:    true,
            snap:        true,
            title:       const Text(Strings.alertsTitle),
            bottom:      PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _ChannelFilterBar(selected: selectedChannel),
            ),
          ),
        ],
        body: threatsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading alerts…'),
          error:   (e, _) => EmptyState(
            icon:  Icons.error_outline,
            title: 'Could not load alerts',
            body:  e.toString(),
          ),
          data: (threats) => threats.isEmpty
              ? _EmptyAlerts(isDark: isDark, channel: selectedChannel)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(filteredThreatsProvider),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        Spacing.md, Spacing.sm, Spacing.md, 100),
                    itemCount:   threats.length,
                    itemBuilder: (_, i) => _ThreatListItem(
                      threat:  threats[i],
                      isFirst: i == 0,
                      isLast:  i == threats.length - 1,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts({required this.isDark, required this.channel});
  final bool           isDark;
  final ThreatChannel? channel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.secondary.withOpacity(0.30),
                    blurRadius: 20,
                    offset:     const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size:  40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              channel == null ? 'You\'re Protected' : 'No ${_channelName(channel!)} threats',
              style: const TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              channel == null
                  ? 'No suspicious calls or messages detected. Any scam attempts will appear here as soon as they arrive.'
                  : 'No suspicious ${_channelName(channel!).toLowerCase()} detected yet. '
                    'Threats from this channel will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 14,
                height:   1.5,
              ),
            ),
            if (channel == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:        AppColors.secondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Active monitoring — calls, SMS & WhatsApp',
                      style: TextStyle(
                        color:      AppColors.secondary,
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _channelName(ThreatChannel c) => switch (c) {
  ThreatChannel.call      => 'Call',
  ThreatChannel.sms       => 'SMS',
  ThreatChannel.whatsapp  => 'WhatsApp',
  ThreatChannel.email     => 'Email',
  ThreatChannel.telegram  => 'Telegram',
  ThreatChannel.instagram => 'Instagram',
  _                       => 'Message',
};

class _ThreatListItem extends StatelessWidget {
  const _ThreatListItem({
    required this.threat,
    required this.isFirst,
    required this.isLast,
  });
  final Threat threat;
  final bool   isFirst, isLast;

  @override
  Widget build(BuildContext context) {
    final t      = threat;
    final isDark = context.isDark;
    final color  = t.riskScore.riskColor;

    BorderRadius radius = BorderRadius.zero;
    if (isFirst && isLast) {
      radius = BorderRadius.circular(20);
    } else if (isFirst) {
      radius = BorderRadius.vertical(top: Radius.circular(20));
    } else if (isLast) {
      radius = BorderRadius.vertical(bottom: Radius.circular(20));
    }

    return Material(
      color:        isDark ? AppColors.darkCard : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap:        () => context.push('/threats/${t.id}'),
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: !isLast
                  ? BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.border)
                  : BorderSide.none,
              left: BorderSide(color: color, width: 3),
            ),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              RiskBadge(score: t.riskScore, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.sender.isEmpty ? 'Unknown Sender' : t.sender,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Helpers.categoryLabel(t.category),
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.timestamp.relativeTime,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color:        t.wasBlocked
                          ? AppColors.danger.withOpacity(0.10)
                          : AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.wasBlocked ? '🚫 Stopped' : '⚠️ Check This',
                      style: TextStyle(
                        color:      t.wasBlocked
                            ? AppColors.danger
                            : AppColors.warning,
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textDisabled, size: 18),
            ],
          ),
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
    final isDark = context.isDark;
    final tabs   = [
      (label: Strings.allAlerts,   value: null as ThreatChannel?),
      (label: Strings.callAlerts,  value: ThreatChannel.call),
      (label: Strings.smsAlerts,   value: ThreatChannel.sms),
      (label: Strings.waAlerts,    value: ThreatChannel.whatsapp),
      (label: Strings.emailAlerts, value: ThreatChannel.email),
    ];

    return Container(
      height:  52,
      color:   isDark ? AppColors.darkBg : AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tabs.map((t) {
          final sel = t.value == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      )
                    : null,
                color: sel
                    ? null
                    : isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: sel
                    ? null
                    : Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color:  AppColors.primary.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: GestureDetector(
                onTap: () =>
                    ref.read(selectedChannelProvider.notifier).select(t.value),
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
