import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../data/repositories/settings_repository.dart';
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
    final hasContacts = SettingsRepository.emergencyContacts.isNotEmpty;

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
                    isActive
                        ? (hasContacts ? 'Alert Sent' : 'No Contacts Set')
                        : Strings.sosTitle,
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
                      'Your SOS will be sent in ${sosState.countdown} seconds.\nHold the button below to stop.',
                      style: const TextStyle(
                        color:    Colors.white54,
                        fontSize: 15,
                        height:   1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    _CountdownContactsRow(),
                    const SizedBox(height: 8),
                    _SOSMessagePreview(),
                    const SizedBox(height: 12),
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
                          color: (hasContacts
                                  ? const Color(0xFF34D399)
                                  : AppColors.warning)
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasContacts
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            color: hasContacts
                                ? const Color(0xFF34D399)
                                : AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              hasContacts
                                  ? 'Emergency alerts sent. Help is on the way.'
                                  : 'No emergency contacts set.\nAdd contacts in Settings to use SOS.',
                              style: const TextStyle(
                                color:    Colors.white,
                                fontSize: 14,
                                height:   1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Cancel / Close button
                  if (isCountdown)
                    _HoldToCancel(
                      onCancelled: () =>
                          ref.read(sOSProvider.notifier).cancel(),
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

// ── Contact names shown during countdown ─────────────────────────────────────

class _CountdownContactsRow extends StatelessWidget {
  const _CountdownContactsRow();

  @override
  Widget build(BuildContext context) {
    final contacts = SettingsRepository.emergencyContacts;
    if (contacts.isEmpty) {
      return const Text(
        '⚠ No emergency contacts set',
        style: TextStyle(color: AppColors.warning, fontSize: 13),
        textAlign: TextAlign.center,
      );
    }
    final names = contacts
        .map((c) => c['name']?.isNotEmpty == true ? c['name']! : c['phone'] ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final first = names.first;
    final others = names.length > 1 ? ' + ${names.length - 1} more' : '';
    return Text(
      'Calling $first$others',
      style: const TextStyle(
        color:      Color(0xFF34D399),
        fontSize:   13,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── SMS message preview during countdown ─────────────────────────────────────

class _SOSMessagePreview extends StatelessWidget {
  const _SOSMessagePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: const Text(
        'SMS: "SOS EMERGENCY! I need immediate help! Please call me right away."',
        textAlign: TextAlign.center,
        style: TextStyle(
          color:    Colors.white38,
          fontSize: 11,
          height:   1.45,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Hold-to-cancel button — prevents accidental cancellation ─────────────────

class _HoldToCancel extends StatefulWidget {
  const _HoldToCancel({required this.onCancelled});
  final VoidCallback onCancelled;

  @override
  State<_HoldToCancel> createState() => _HoldToCancelState();
}

class _HoldToCancelState extends State<_HoldToCancel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const _holdDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _holdDuration);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onCancelled();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width:  double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset:     const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Fill bar showing hold progress
              FractionallySizedBox(
                widthFactor: _ctrl.value,
                child: Container(
                  decoration: BoxDecoration(
                    color:        AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _ctrl.value > 0.05 ? 'Keep holding to cancel…' : 'Hold to Cancel',
                  style: TextStyle(
                    color:         AppColors.danger,
                    fontSize:      17,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
