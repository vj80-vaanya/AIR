import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/onboarding_step_bar.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _contentCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _contentCtrl,
      curve:  const Interval(0.2, 1.0, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentCtrl,
      curve:  const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated gradient background ────────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: const [
                    Color(0xFF0F0A2E),
                    Color(0xFF1E1060),
                    Color(0xFF0D1B4B),
                  ],
                  stops: [
                    0,
                    0.4 + _bgCtrl.value * 0.2,
                    1,
                  ],
                ),
              ),
            ),
          ),

          // ── Decorative orbs ────────────────────────────────────────────
          Positioned(
            top:   -60,
            right: -40,
            child: _GlowOrb(color: AppColors.primary, size: 220),
          ),
          Positioned(
            bottom: 40,
            left:   -60,
            child: _GlowOrb(color: const Color(0xFF7C3AED), size: 180),
          ),

          // ── Content ────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: Column(
                    children: [
                      const OnboardingStepBar(step: 1),
                      const Spacer(flex: 2),

                      // Shield logo
                      Container(
                        width:  120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape:    BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF4F46E5),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:      AppColors.primary.withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size:  60,
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),

                      // Title
                      Text(
                        Strings.appName,
                        style: const TextStyle(
                          color:         Colors.white,
                          fontSize:      34,
                          fontWeight:    FontWeight.w900,
                          letterSpacing: -0.8,
                          height:        1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        Strings.appTagline,
                        style: const TextStyle(
                          color:    Colors.white60,
                          fontSize: 16,
                          height:   1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: Spacing.xl),

                      // Feature pills
                      Wrap(
                        spacing:    10,
                        runSpacing: 10,
                        alignment:  WrapAlignment.center,
                        children: const [
                          _FeaturePill(
                              icon: Icons.psychology_rounded,
                              text: 'On-Device AI'),
                          _FeaturePill(
                              icon: Icons.lock_rounded,
                              text: 'Privacy First'),
                          _FeaturePill(
                              icon: Icons.flash_on_rounded,
                              text: 'Real-Time'),
                          _FeaturePill(
                              icon: Icons.people_rounded,
                              text: 'Made for India'),
                        ],
                      ),

                      const Spacer(flex: 3),

                      // CTA
                      AppButton(
                        label:     'Get Started',
                        icon:      Icons.arrow_forward_rounded,
                        onPressed: () => context.go('/onboarding/permissions'),
                        minHeight: TouchTarget.primary,
                      ),
                      const SizedBox(height: Spacing.md),
                      TextButton(
                        onPressed: () => _confirmSkip(context),
                        child: const Text(
                          'Skip setup',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSkip(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skip setup?'),
        content: const Text(
          'Without completing setup:\n\n'
          '• Emergency contacts won\'t be notified if you press SOS\n'
          '• Some permissions may not be active\n\n'
          'You can complete setup later in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip anyway'),
          ),
        ],
      ),
    );
    // Skip goes to permissions so at least basic protection can be configured,
    // not straight to dashboard with zero permissions granted.
    if (ok == true && context.mounted) context.go('/onboarding/permissions');
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});
  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.30),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

