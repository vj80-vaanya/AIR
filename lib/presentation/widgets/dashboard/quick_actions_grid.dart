import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        label:    'Scan',
        sub:      'Check any message',
        icon:     Icons.manage_search_rounded,
        gradient: [AppColors.gradientStart, AppColors.gradientEnd],
        glow:     AppColors.primary,
        path:     '/scan',
      ),
      _Action(
        label:    'OTP',
        sub:      'Copy OTPs quickly',
        icon:     Icons.lock_clock_rounded,
        gradient: [AppColors.secondary, AppColors.secondaryDark],
        glow:     AppColors.secondary,
        path:     '/otp',
      ),
      _Action(
        label:    'Family',
        sub:      'Safety network',
        icon:     Icons.people_alt_rounded,
        gradient: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        glow:     const Color(0xFF8B5CF6),
        path:     '/family',
      ),
      _Action(
        label:    'Cleanup',
        sub:      'Free WhatsApp space',
        icon:     Icons.cleaning_services_rounded,
        gradient: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        glow:     AppColors.warning,
        path:     '/cleanup',
      ),
    ];

    return GridView.builder(
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        mainAxisSpacing:  Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        childAspectRatio: 1.55,
      ),
      itemCount:   actions.length,
      itemBuilder: (_, i) => _ActionCard(action: actions[i]),
    );
  }
}

class _Action {
  const _Action({
    required this.label,
    required this.sub,
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.path,
  });

  final String       label;
  final String       sub;
  final IconData     icon;
  final List<Color>  gradient;
  final Color        glow;
  final String       path;
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.action});
  final _Action action;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;

    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); context.push(a.path); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: a.gradient,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color:      a.glow.withOpacity(0.28),
                blurRadius: 14,
                offset:     const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width:  40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a.icon, color: Colors.white, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.label,
                      style: const TextStyle(
                        color:         Colors.white,
                        fontSize:      15,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      a.sub,
                      style: const TextStyle(
                        color:    Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
