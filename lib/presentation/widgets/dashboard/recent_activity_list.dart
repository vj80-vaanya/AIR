import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
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
      return _EmptyState();
    }

    final shown = threats.take(5).toList();

    return Column(
      children: shown
          .asMap()
          .entries
          .map((e) => _ThreatCard(threat: e.value, index: e.key))
          .toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width:  60,
            height: 60,
            decoration: BoxDecoration(
              color:        AppColors.secondary.withOpacity(0.12),
              shape:        BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.secondary,
              size:  30,
            ),
          ),
          const SizedBox(height: Spacing.md),
          const Text(
            'All Clear',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize:   16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No threats detected recently.',
            style: TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreatCard extends StatelessWidget {
  const _ThreatCard({required this.threat, required this.index});
  final Threat threat;
  final int    index;

  @override
  Widget build(BuildContext context) {
    final isDark   = context.isDark;
    final color    = threat.riskScore.riskColor;
    final isFirst  = index == 0;
    final isLast   = index == 4;

    BorderRadius radius = BorderRadius.zero;
    if (isFirst && isLast) {
      radius = BorderRadius.circular(20);
    } else if (isFirst) {
      radius = const BorderRadius.vertical(top: Radius.circular(20));
    } else if (isLast) {
      radius = const BorderRadius.vertical(bottom: Radius.circular(20));
    }

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap:        () => context.push('/threats/${threat.id}'),
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: index < 4
                  ? BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                      width: 1,
                    )
                  : BorderSide.none,
              left: BorderSide(color: color, width: 3),
            ),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              RiskBadge(score: threat.riskScore, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      threat.sender.isEmpty ? 'Unknown' : threat.sender,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize:   14,
                        letterSpacing: -0.1,
                      ),
                      maxLines:  1,
                      overflow:  TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _ChannelChip(channel: threat.channel),
                        const SizedBox(width: 6),
                        Text(
                          Helpers.categoryLabel(threat.category),
                          style: TextStyle(
                            color:    AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    threat.timestamp.relativeTime,
                    style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (threat.wasBlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        AppColors.danger.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BLOCKED',
                        style: TextStyle(
                          color:         AppColors.danger,
                          fontSize:      9,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
                size:  18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.channel});
  final ThreatChannel channel;

  static const _map = {
    ThreatChannel.call:      (icon: Icons.phone_rounded,       color: AppColors.info),
    ThreatChannel.sms:       (icon: Icons.sms_rounded,         color: AppColors.warning),
    ThreatChannel.whatsapp:  (icon: Icons.message_rounded,     color: AppColors.secondary),
    ThreatChannel.telegram:  (icon: Icons.send_rounded,        color: AppColors.info),
    ThreatChannel.instagram: (icon: Icons.camera_alt_rounded,  color: Color(0xFFE1306C)),
    ThreatChannel.email:     (icon: Icons.email_rounded,       color: AppColors.primary),
    ThreatChannel.other:     (icon: Icons.notifications_rounded, color: AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final meta = _map[channel] ??
        (icon: Icons.notifications_rounded, color: AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        meta.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(meta.icon, size: 11, color: meta.color),
    );
  }
}
