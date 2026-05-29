import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/extensions.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/security_status_provider.dart';
// newThreatStreamProvider is exported from dashboard_provider.dart
import '../../widgets/dashboard/ios_safety_scanner.dart';
import '../../widgets/dashboard/protection_score_widget.dart';
import '../../widgets/dashboard/quick_actions_grid.dart';
import '../../widgets/dashboard/recent_activity_list.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-refresh dashboard whenever a new threat is stored in the background
    ref.listen(newThreatStreamProvider, (_, __) {
      ref.invalidate(protectionStatusProvider);
      ref.invalidate(recentThreatsProvider);
    });

    final statusAsync  = ref.watch(protectionStatusProvider);
    final threatsAsync = ref.watch(recentThreatsProvider);
    final healthAsync  = ref.watch(securityStatusProvider);
    final isDark       = context.isDark;

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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.6 + _ctrl.value * 0.4,
        child: IconButton(
          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          onPressed: widget.onTap,
          tooltip:   'Protection incomplete',
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
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
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
            onTap:        () => context.push('/sos'),
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
