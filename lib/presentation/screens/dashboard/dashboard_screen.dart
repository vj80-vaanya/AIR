import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/security_status_provider.dart';
import '../../widgets/dashboard/ios_safety_scanner.dart';
import '../../widgets/dashboard/protection_score_widget.dart';
import '../../widgets/dashboard/quick_actions_grid.dart';
import '../../widgets/dashboard/recent_activity_list.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer?  _debounce;
  Timer?  _quietTimer;   // refreshes quiet-hours banner every minute
  bool    _showTour = false;

  @override
  void initState() {
    super.initState();
    if (!SettingsRepository.firstRunDone) {
      _showTour = true;
    }
    // Refresh quiet-hours banner once per minute so it appears/disappears live
    _quietTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quietTimer?.cancel();
    super.dispose();
  }

  void _onNewThreat() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      ref.invalidate(protectionStatusProvider);
      ref.invalidate(recentThreatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debounced auto-refresh — prevents rebuild storms from rapid threats
    ref.listen(newThreatStreamProvider, (_, __) => _onNewThreat());

    final statusAsync  = ref.watch(protectionStatusProvider);
    final threatsAsync = ref.watch(recentThreatsProvider);
    final healthAsync  = ref.watch(securityStatusProvider);
    final isDark       = context.isDark;

    // Tour is dismissed manually by the user — no auto-dismiss

    return Scaffold(
      body: RefreshIndicator(
        color:         AppColors.primary,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        onRefresh: () async {
          ref.invalidate(protectionStatusProvider);
          ref.invalidate(recentThreatsProvider);
          ref.read(securityStatusProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              floating:           true,
              snap:               true,
              backgroundColor:    isDark ? AppColors.darkBg : AppColors.background,
              surfaceTintColor:   Colors.transparent,
              title: Row(
                children: [
                  Container(
                    width:  34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.gradientStart, AppColors.gradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size:  20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    Strings.appName,
                    style: TextStyle(
                      fontWeight:    FontWeight.w800,
                      fontSize:      20,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              actions: [
                healthAsync.maybeWhen(
                  data: (h) => !h.isFullyProtected
                      ? _AnimatedWarningBadge(
                          onTap: () => context.push('/permission-guardian'))
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.go('/threats'),
                  tooltip: 'View alerts',
                ),
                const SizedBox(width: 4),
              ],
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Spacing.md, Spacing.sm, Spacing.md,
                // Extra bottom padding for floating nav
                100,
              ),
              sliver: SliverList.list(
                children: [
                  // ── Protection Score Hero ─────────────────────────────────
                  statusAsync.when(
                    data:    (s) => ProtectionScoreWidget(status: s),
                    loading: () => const _HeroSkeleton(),
                    error:   (_, __) => const _ErrorCard(),
                  ),
                  const SizedBox(height: Spacing.md),

                  // ── Weekly stat pill ──────────────────────────────────────
                  statusAsync.maybeWhen(
                    data: (s) => _WeeklyStatRow(
                      today: s.threatsBlockedToday,
                      week:  s.threatsBlockedWeek,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: Spacing.md),

                  // ── Quiet hours active banner ────────────────────────────
                  if (SettingsRepository.isInQuietHours()) ...[
                    _QuietHoursBanner(),
                    const SizedBox(height: Spacing.sm),
                  ],

                  // ── First-run guidance banner ───────────────────────────
                  if (_showTour) ...[
                    _TourBanner(onDismiss: () {
                      setState(() => _showTour = false);
                      SettingsRepository.setFirstRunDone();
                    }),
                    const SizedBox(height: Spacing.md),
                  ],

                  if (Platform.isIOS) ...[
                    const IOSSafetyScannerWidget(),
                    const SizedBox(height: Spacing.md),
                  ],

                  // ── Quick Actions ─────────────────────────────────────────
                  _SectionHeader(
                    title: 'Quick Actions',
                    action: TextButton(
                      onPressed: () => context.go('/threats'),
                      child: const Text('All alerts',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  const QuickActionsGrid(),
                  const SizedBox(height: Spacing.md),

                  // ── Recent Activity ───────────────────────────────────────
                  _SectionHeader(
                    title: 'Recent Activity',
                    action: TextButton(
                      onPressed: () => context.go('/threats'),
                      child: const Text('See all',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  threatsAsync.when(
                    data:    (t) => RecentActivityList(threats: t),
                    loading: () => const _ListSkeleton(),
                    error:   (_, __) => const _ErrorCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── SOS FAB ─────────────────────────────────────────────────────────
      floatingActionButton: _SosFab(),
    );
  }
}

// ── Quiet hours active banner ─────────────────────────────────────────────────

class _QuietHoursBanner extends StatelessWidget {
  const _QuietHoursBanner();

  @override
  Widget build(BuildContext context) {
    final end = SettingsRepository.quietHoursEnd;
    final h   = end == 0 ? 12 : (end > 12 ? end - 12 : end);
    final amPm = end >= 12 ? 'PM' : 'AM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.30)),
      ),
      child: Row(children: [
        const Icon(Icons.nightlight_rounded, color: AppColors.primary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Quiet hours active — scam alerts silenced until $h:00 $amPm. SOS always works.',
            style: const TextStyle(
              color:    AppColors.primary,
              fontSize: 12,
              height:   1.4,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── First-run tour banner ─────────────────────────────────────────────────────

class _TourBanner extends StatelessWidget {
  const _TourBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  static const _tips = [
    (icon: Icons.shield_rounded,           text: 'Your Protection Score shows how safe you are right now.'),
    (icon: Icons.sos_rounded,              text: 'Tap SOS below to instantly alert your family in an emergency.'),
    (icon: Icons.manage_search_rounded,    text: 'Use Scan to check any suspicious message you receive.'),
    (icon: Icons.notifications_rounded,    text: 'Any scam calls or messages will appear in Alerts automatically.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFF1E3A5F).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tips_and_updates_rounded,
                color: AppColors.info, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Welcome — here\'s how the app works:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 18),
            ),
          ]),
          const SizedBox(height: 12),
          ..._tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(t.icon, color: AppColors.info, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.text,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height:   1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onDismiss,
            child: const Text(
              'Got it — dismiss',
              style: TextStyle(
                color:      AppColors.info,
                fontSize:   12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String  title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize:      17,
            fontWeight:    FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _WeeklyStatRow extends StatelessWidget {
  const _WeeklyStatRow({required this.today, required this.week});
  final int today, week;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Row(
      children: [
        Expanded(
            child: _StatPill(
                label: 'Today',
                value: '$today',
                icon:  Icons.today_rounded,
                color: AppColors.primary,
                isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatPill(
                label: 'This week',
                value: '$week',
                icon:  Icons.date_range_rounded,
                color: AppColors.secondary,
                isDark: isDark)),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });
  final String   label, value;
  final IconData icon;
  final Color    color;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize:      20,
                  fontWeight:    FontWeight.w800,
                  color:         color,
                  letterSpacing: -0.5,
                  height:        1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color:    AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedWarningBadge extends StatefulWidget {
  const _AnimatedWarningBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AnimatedWarningBadge> createState() => _AnimatedWarningBadgeState();
}

class _AnimatedWarningBadgeState extends State<_AnimatedWarningBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600), // slower = fewer GPU frames
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: 0.6 + _ctrl.value * 0.4,
          child: IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            onPressed: widget.onTap,
            tooltip:   'Protection incomplete',
          ),
        ),
      ),
    );
  }
}

class _SosFab extends StatefulWidget {
  @override
  State<_SosFab> createState() => _SosFabState();
}

class _SosFabState extends State<_SosFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SosConfirmSheet(onConfirm: () => context.push('/sos')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
      scale: _pulse,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color:      AppColors.danger.withOpacity(0.45),
              blurRadius: 18,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color:        Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            onTap:        () => _onTap(context),
            borderRadius: BorderRadius.circular(30),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sos_rounded, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color:         Colors.white,
                      fontSize:      18,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));  // closes RepaintBoundary
  }
}

class _SosConfirmSheet extends StatelessWidget {
  const _SosConfirmSheet({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF1A0008),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color:        Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                    colors: [Color(0xFFFF4D6D), Color(0xFFC9184A)]),
                shape:     BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.danger.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.sos_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Send SOS Alert?',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _ContactList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                icon:  const Icon(Icons.sos_rounded),
                label: const Text('Send SOS Now',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding:         const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side:    const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:   RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white60, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contact list widget for SOS confirmation ──────────────────────────────────

class _ContactList extends StatelessWidget {
  const _ContactList();

  @override
  Widget build(BuildContext context) {
    final contacts = SettingsRepository.emergencyContacts;

    if (contacts.isEmpty) {
      return Column(
        children: [
          const Text(
            'No emergency contacts added yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/onboarding/sos-setup'),
            icon:  const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Add Emergency Contacts Now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side:            const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Will alert:',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        ...contacts.asMap().entries.map((e) {
          final name  = e.value['name'] ?? '';
          final phone = e.value['phone'] ?? '';
          final isFirst = e.key == 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(
                isFirst ? Icons.phone_rounded : Icons.sms_rounded,
                color: isFirst ? const Color(0xFF34D399) : Colors.white54,
                size:  14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name.isNotEmpty ? '$name ($phone)' : phone,
                  style: TextStyle(
                    color:      isFirst ? Colors.white : Colors.white70,
                    fontSize:   13,
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (isFirst)
                const Text(
                  'call',
                  style: TextStyle(
                    color:      Color(0xFF34D399),
                    fontSize:   11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
          );
        }),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 170,
        decoration: BoxDecoration(
          color:        AppColors.borderDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          3,
          (i) => Container(
            height: 68,
            margin:      const EdgeInsets.only(bottom: 1),
            color: AppColors.border.withOpacity(0.4),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color:        AppColors.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
        child: Row(
          children: const [
            Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            SizedBox(width: 10),
            Text('Unable to load data — pull to retry.'),
          ],
        ),
      );
}
