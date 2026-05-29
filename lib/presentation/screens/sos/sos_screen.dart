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
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ringCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sOSProvider.notifier).trigger();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sOSProvider);

    ref.listen(sOSProvider, (_, next) {
      if (next.state == SOSState.cancelled) context.pop();
    });

    final isActive    = sosState.state == SOSState.active;
    final isCountdown = sosState.state == SOSState.countdown;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0015),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Ripple rings ────────────────────────────────────────────────
            AnimatedBuilder(
              animation: _ringCtrl,
              builder: (_, __) => CustomPaint(
                size: MediaQuery.sizeOf(context),
                painter: _RipplePainter(progress: _ringCtrl.value),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing SOS button
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.08)
                        .animate(CurvedAnimation(
                          parent: _pulseCtrl,
                          curve: Curves.easeInOut,
                        )),
                    child: Container(
                      width:  130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFF4D6D), Color(0xFFC9184A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:      AppColors.danger.withOpacity(0.6),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sos_rounded,
                        color: Colors.white,
                        size:  64,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    isActive ? 'Alert Sent' : Strings.sosTitle,
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      34,
                      fontWeight:    FontWeight.w900,
                      letterSpacing: -0.5,
                      height:        1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  if (isCountdown) ...[
                    Text(
                      Strings.sosCountdown,
                      style: const TextStyle(
                        color:    Colors.white54,
                        fontSize: 15,
                        height:   1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    CountdownTimer(seconds: sosState.countdown),
                  ] else if (isActive) ...[
                    Container(
                      margin:  const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF34D399), size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Contacts notified. Help is coming.',
                            style: TextStyle(
                              color:    Colors.white,
                              fontSize: 14,
                              height:   1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Cancel / Close button
                  if (isCountdown)
                    GestureDetector(
                      onTap: () =>
                          ref.read(sOSProvider.notifier).cancel(),
                      child: Container(
                        width:  double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:  Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          Strings.sosCancel,
                          style: TextStyle(
                            color:         AppColors.danger,
                            fontSize:      18,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    )
                  else if (isActive)
                    OutlinedButton.icon(
                      onPressed: () => context.pop(),
                      icon:  const Icon(Icons.close_rounded,
                          color: Colors.white54),
                      label: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white54),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.75;

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final r     = maxR * phase;
      final alpha = (1.0 - phase);

      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.danger.withOpacity(alpha * 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
