import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../providers/dashboard_provider.dart';
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text(Strings.appName),
            actions: [
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
              /* Protection score */
              statusAsync.when(
                data:    (s) => ProtectionScoreWidget(status: s),
                loading: () => const _ScorePlaceholder(),
                error:   (_, __) => const _ErrorCard(),
              ),
              const SizedBox(height: Spacing.md),

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
