import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/security_status_provider.dart';
import 'dart:io';
import '../../widgets/dashboard/ios_safety_scanner.dart';
import '../../widgets/dashboard/protection_score_widget.dart';
import '../../widgets/dashboard/quick_actions_grid.dart';
import '../../widgets/dashboard/recent_activity_list.dart';
import '../../widgets/common/app_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(protectionStatusProvider);
    final threatsAsync = ref.watch(recentThreatsProvider);
    final securityHealthAsync = ref.watch(securityStatusProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text(Strings.appName),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined),
                onPressed: () => context.push('/permission-guardian'),
                tooltip: 'Security Health',
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.go('/threats'),
                tooltip: 'View alerts',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            sliver: SliverList.list(children: [
              /* Security Health Banner */
              securityHealthAsync.when(
                data: (health) => health.isFullyProtected 
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: _SecurityHealthBanner(onTap: () => context.push('/permission-guardian')),
                    ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              /* Protection score */
              statusAsync.when(
                data:    (s) => ProtectionScoreWidget(status: s),
                loading: () => const _ScorePlaceholder(),
                error:   (_, __) => const _ErrorCard(),
              ),
              const SizedBox(height: Spacing.md),

              if (Platform.isIOS) ...[
                const IOSSafetyScannerWidget(),
                const SizedBox(height: Spacing.md),
              ],

              /* Weekly summary */
              statusAsync.maybeWhen(
                data: (s) => AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart, color: AppColors.primary),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          '${s.threatsBlockedWeek} ${Strings.scamsBlockedWeek}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: Spacing.md),

              /* Quick actions */
              const QuickActionsGrid(),
              const SizedBox(height: Spacing.md),

              Text(Strings.recentActivity,
                   style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Spacing.sm),
              threatsAsync.when(
                data:    (t) => RecentActivityList(threats: t),
                loading: () => const CircularProgressIndicator(),
                error:   (_, __) => const _ErrorCard(),
              ),
              const SizedBox(height: Spacing.xxl),
            ]),
          ),
        ],
      ),
      /* Persistent SOS FAB */
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sos_fab',
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/sos'),
        icon: const Icon(Icons.sos),
        label: const Text('SOS'),
      ),
    );
  }
}

class _SecurityHealthBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _SecurityHealthBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Colors.orange.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Spacing.md),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Protection Incomplete',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    Text(
                      'Tap to enable vital security layers.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorePlaceholder extends StatelessWidget {
  const _ScorePlaceholder();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();
  @override
  Widget build(BuildContext context) => const AppCard(
    child: Padding(
      padding: EdgeInsets.all(Spacing.md),
      child: Text('Unable to load data. Tap to retry.'),
    ),
  );
}
