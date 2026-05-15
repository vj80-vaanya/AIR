import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../providers/sos_provider.dart';
import '../../widgets/sos/countdown_timer.dart';

class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({super.key});

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sOSProvider.notifier).trigger();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sOSProvider);

    ref.listen(sOSProvider, (_, next) {
      if (next.state == SOSState.cancelled) {
        context.pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.danger,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.08),
                  child: const Icon(Icons.sos, size: 96, color: Colors.white),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Text(
                Strings.sosTitle,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.md),
              if (sosState.state == SOSState.countdown) ...[
                Text(
                  Strings.sosCountdown,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: Spacing.md),
                CountdownTimer(seconds: sosState.countdown),
              ] else ...[
                Text(
                  'Alert sent. Help is on the way.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Spacing.xxl),
              if (sosState.state == SOSState.countdown)
                SizedBox(
                  width: double.infinity,
                  height: TouchTarget.primary,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => ref.read(sOSProvider.notifier).cancel(),
                    child: const Text(Strings.sosCancel,
                                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
