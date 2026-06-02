import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/helpers.dart';
import '../../providers/threat_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/risk_badge.dart';

class ThreatDetailScreen extends ConsumerStatefulWidget {
  const ThreatDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ThreatDetailScreen> createState() => _ThreatDetailScreenState();
}

class _ThreatDetailScreenState extends ConsumerState<ThreatDetailScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final threatAsync = ref.watch(threatByIdProvider(widget.id));
    final isDark      = context.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF8FAFC),
      body: threatAsync.when(
        loading: () => const LoadingIndicator(),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (threat) {
          if (threat == null) {
            return const Center(child: Text('Threat not found.'));
          }

          final color      = threat.riskScore.riskColor;
          final riskLabel  = threat.riskScore >= 80
              ? 'High Risk'
              : threat.riskScore >= 50
                  ? 'Medium Risk'
                  : 'Low Risk';

          return CustomScrollView(
            slivers: [
              // ── Gradient header ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned:         true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.85),
                          color,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            RiskBadge(score: threat.riskScore, size: 64),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:        Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      riskLabel.toUpperCase(),
                                      style: const TextStyle(
                                        color:         Colors.white,
                                        fontSize:      10,
                                        fontWeight:    FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    Helpers.categoryLabel(threat.category),
                                    style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   20,
                                      fontWeight: FontWeight.w800,
                                      height:     1.1,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    threat.sender.isEmpty
                                        ? 'Unknown sender'
                                        : 'From: ${threat.sender}',
                                    style: TextStyle(
                                      color:    Colors.white.withOpacity(0.80),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                sliver: SliverList.list(children: [
                  // Status row
                  _InfoCard(isDark: isDark, children: [
                    _InfoRow(
                      icon:  Icons.router_rounded,
                      label: 'Channel',
                      value: threat.channel.name.toUpperCase(),
                      color: color,
                    ),
                    _InfoRow(
                      icon:  threat.wasBlocked
                          ? Icons.block_rounded
                          : Icons.flag_rounded,
                      label: 'Action',
                      value: threat.wasBlocked
                          ? _blockedDescription(threat.channel.name)
                          : 'Flagged — message was delivered but marked suspicious',
                      color: threat.wasBlocked
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                    _InfoRow(
                      icon:  Icons.access_time_rounded,
                      label: 'Time',
                      value: _formatTime(threat.timestamp),
                      color: AppColors.textSecondary,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Reason
                  _LabeledSection(
                    label: 'Why this was flagged',
                    icon:  Icons.psychology_rounded,
                    isDark: isDark,
                    child: Text(
                      Helpers.reasonPlain(threat.reason),
                      style: TextStyle(
                        fontSize: 14,
                        height:   1.55,
                        color:    isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                  ),

                  // Message content
                  if (threat.detail != null &&
                      threat.detail!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LabeledSection(
                      label:  'Message content',
                      icon:   Icons.chat_bubble_outline_rounded,
                      isDark: isDark,
                      child: Text(
                        threat.detail!,
                        style: TextStyle(
                          fontSize: 13,
                          height:   1.55,
                          color:    isDark ? Colors.white60 : AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // What to do now — shown for ALL categories
                  const SizedBox(height: 12),
                  _LabeledSection(
                    label:  'What to do now',
                    icon:   Icons.lightbulb_rounded,
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Helpers.categoryAdvice(threat.category),
                          style: TextStyle(
                            fontSize: 14,
                            height:   1.6,
                            color:    _adviceColor(isDark, threat.category),
                          ),
                        ),
                        if (threat.category != 'SAFE' &&
                            threat.category != 'LEGITIMATE') ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showCybercrimeHelp(context),
                            icon:  const Icon(Icons.phone_in_talk_rounded, size: 16),
                            label: const Text('Report to Cybercrime Helpline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.info,
                              side: BorderSide(
                                  color: AppColors.info.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Feedback prompt
                  Text(
                    'Help us improve — was the app correct?',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your feedback is processed on-device and is never sent to us.',
                    style: TextStyle(
                      fontSize: 11,
                      color:    isDark ? Colors.white38 : AppColors.textDisabled,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : () => _submitFeedback(
                            context, ref, 'false_alarm',
                            'Marked as false alarm — thank you!',
                            AppColors.secondary,
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.secondary))
                              : const Icon(Icons.thumb_up_outlined, size: 18),
                          label: const Text('False Alarm'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: BorderSide(
                                color: AppColors.secondary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : () => _submitFeedback(
                            context, ref, 'confirmed',
                            'Confirmed as scam — helps protect others!',
                            AppColors.danger,
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.shield_rounded, size: 18),
                          label: const Text('Confirm Scam'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _adviceColor(bool isDark, String category) {
    if (category == 'SAFE' || category == 'LEGITIMATE') {
      return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    }
    return isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
  }

  void _showCybercrimeHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: const Text('Report to Cybercrime Helpline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'India National Cybercrime Helpline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:1930')),
              child: const Row(children: [
                Icon(Icons.phone_rounded, color: AppColors.danger, size: 20),
                SizedBox(width: 8),
                Text('1930  (tap to call)',
                    style: TextStyle(
                        fontSize:   22,
                        fontWeight: FontWeight.w900,
                        color:      AppColors.danger,
                        decoration: TextDecoration.underline)),
              ]),
            ),
            const SizedBox(height: 4),
            const Text('Available 24×7. Report scam calls, OTP fraud, WhatsApp fraud, and fake arrest threats.'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(
                  Uri.parse('https://cybercrime.gov.in'),
                  mode: LaunchMode.externalApplication),
              child: const Text('cybercrime.gov.in',
                  style: TextStyle(
                      color:      AppColors.info,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(
    BuildContext context,
    WidgetRef ref,
    String feedback,
    String message,
    Color color,
  ) async {
    setState(() => _submitting = true);
    try {
      await markThreatFeedback(widget.id, feedback);
      ref.invalidate(filteredThreatsProvider);
      ref.invalidate(recentThreatsProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: color,
        duration:        const Duration(seconds: 3),
      ));
      Navigator.of(context).pop();
    }
  }

  static String _blockedDescription(String channel) {
    return switch (channel.toLowerCase()) {
      'call'     => 'Blocked — your phone did not ring',
      'sms'      => 'Blocked — message was not delivered to you',
      'whatsapp' => 'Blocked — WhatsApp notification was suppressed',
      _          => 'Blocked automatically — did not reach you',
    };
  }

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.isDark, required this.children});
  final bool         isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset:     const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          return Column(children: [
            e.value,
            if (e.key < children.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String   label, value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:        color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color:      AppColors.textSecondary,
            fontSize:   12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize:   13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

class _LabeledSection extends StatelessWidget {
  const _LabeledSection({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.child,
  });
  final String label;
  final IconData icon;
  final bool   isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
