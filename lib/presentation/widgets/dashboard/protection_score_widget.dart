import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/protection_status.dart';

class ProtectionScoreWidget extends StatefulWidget {
  const ProtectionScoreWidget({super.key, required this.status});
  final ProtectionStatus status;

  @override
  State<ProtectionScoreWidget> createState() => _ProtectionScoreWidgetState();
}

class _ProtectionScoreWidgetState extends State<ProtectionScoreWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _ringAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve:  const Interval(0.0, 0.4, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final shieldsOn = [
      s.callProtectionActive,
      s.smsProtectionActive,
      s.whatsappProtectionActive,
      s.fallDetectionActive,
    ].where((v) => v).length;

    final statusText = s.score >= 80
        ? 'Fully Protected'
        : s.score >= 50
            ? 'Partial Shield'
            : s.score > 0
                ? 'Low Protection'
                : 'Protection Off';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            stops:  [0.0, 1.0],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF6366F1).withOpacity(0.38),
              blurRadius: 28,
              offset:     const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // ── Animated score ring ───────────────────────────────────────
              AnimatedBuilder(
                animation: _ringAnim,
                builder: (_, __) => SizedBox(
                  width:  116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(116, 116),
                        painter: _RingPainter(
                          progress: _ringAnim.value * s.score / 100,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(s.score * _ringAnim.value).round()}',
                            style: const TextStyle(
                              color:         Colors.white,
                              fontSize:      34,
                              fontWeight:    FontWeight.w800,
                              height:        1,
                              letterSpacing: -1,
                            ),
                          ),
                          const Text(
                            'SCORE',
                            style: TextStyle(
                              color:         Colors.white60,
                              fontSize:      10,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // ── Info panel ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status pill — tappable when score is low
                    GestureDetector(
                      onTap: s.score < 80
                          ? () => context.push('/settings/protection')
                          : null,
                      child: _StatusPill(
                        text:     statusText,
                        green:    s.score >= 80,
                        tappable: s.score < 80,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Threats today
                    Text(
                      '${s.threatsBlockedToday}',
                      style: const TextStyle(
                        color:         Colors.white,
                        fontSize:      32,
                        fontWeight:    FontWeight.w800,
                        height:        1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      s.score == 0
                          ? 'Enable protection in Settings'
                          : 'threats blocked today',
                      style: const TextStyle(
                        color:    Colors.white60,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Shield dots
                    Row(
                      children: [
                        ...[
                          (Icons.phone,          s.callProtectionActive,        'Call'),
                          (Icons.sms,            s.smsProtectionActive,         'SMS'),
                          (Icons.message,        s.whatsappProtectionActive,    'WA'),
                          (Icons.monitor_heart,  s.fallDetectionActive,         'Fall'),
                        ].map((e) => _ShieldDot(
                          icon:   e.$1,
                          active: e.$2,
                          label:  e.$3,
                        )),
                        const SizedBox(width: 8),
                        Text(
                          '$shieldsOn/4',
                          style: const TextStyle(
                            color:      Colors.white70,
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.green, this.tappable = false});
  final String text;
  final bool   green;
  final bool   tappable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  7,
            height: 7,
            decoration: BoxDecoration(
              color: green
                  ? const Color(0xFF34D399)
                  : const Color(0xFFFBBF24),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 10),
          ],
        ],
      ),
    );
  }
}

class _ShieldDot extends StatelessWidget {
  const _ShieldDot({
    required this.icon,
    required this.active,
    required this.label,
  });
  final IconData icon;
  final bool     active;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        width:  26,
        height: 26,
        decoration: BoxDecoration(
          color:        active
              ? const Color(0xFF34D399).withOpacity(0.22)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size:  14,
          color: active
              ? const Color(0xFF34D399)
              : Colors.white30,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c      = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    const sw     = 10.0;

    // Track
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color       = Colors.white.withOpacity(0.15)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle:    math.pi * 1.5,
          colors: const [Color(0xFFA5B4FC), Color(0xFFE879F9)],
        ).createShader(rect)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
