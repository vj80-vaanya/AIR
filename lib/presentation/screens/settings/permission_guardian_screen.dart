import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../providers/security_status_provider.dart';

class PermissionGuardianScreen extends ConsumerStatefulWidget {
  const PermissionGuardianScreen({super.key});

  @override
  ConsumerState<PermissionGuardianScreen> createState() =>
      _PermissionGuardianScreenState();
}

class _PermissionGuardianScreenState
    extends ConsumerState<PermissionGuardianScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    // Auto-refresh when user returns from Android Settings
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User came back from Settings — recheck permissions automatically
      ref.read(securityStatusProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(securityStatusProvider);
    final isDark      = context.isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protection Setup'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded),
            tooltip: 'Re-check permissions',
            onPressed: () =>
                ref.read(securityStatusProvider.notifier).refresh(),
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _PermissionCheckError(
          onRetry: () => ref.read(securityStatusProvider.notifier).refresh(),
        ),
        data:  (health) => _Body(health: health, isDark: isDark),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({required this.health, required this.isDark});
  final SecurityHealth health;
  final bool           isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(securityStatusProvider.notifier);
    final granted  = [
      health.smsGranted,
      health.phoneGranted,
      health.notificationAccessGranted,
      health.accessibilityGranted,
    ].where((v) => v).length;

    final perms = [
      _PermDef(
        icon:        Icons.sms_rounded,
        color:       AppColors.warning,
        title:       'SMS Monitoring',
        why:         'Scans incoming texts for OTP theft, banking fraud and phishing links before you read them.',
        isGranted:   health.smsGranted,
        type:        _PermType.runtime,
        onEnable:    () => notifier.requestSms(),
      ),
      _PermDef(
        icon:        Icons.phone_rounded,
        color:       AppColors.info,
        title:       'Phone / Call Access',
        why:         'Identifies robocall patterns and flags high-risk international numbers the moment your phone rings.',
        isGranted:   health.phoneGranted,
        type:        _PermType.runtime,
        onEnable:    () => notifier.requestPhone(),
      ),
      _PermDef(
        icon:        Icons.notifications_rounded,
        color:       AppColors.primary,
        title:       'Notification Access',
        why:         'Reads WhatsApp, Telegram and Signal notifications so the AI can detect scam messages in real time — without storing any content.',
        isGranted:   health.notificationAccessGranted,
        type:        _PermType.notificationListener,
        onEnable:    () => _showGuideSheet(
          context, ref,
          title:   'Enable Notification Access',
          steps:   const [
            'Tap  Open Settings  below.',
            'Find  "AI Security"  in the list.',
            'Tap the toggle next to AI Security.',
            'Tap  Allow  on the confirmation dialog.',
            'Press back twice — you\'re done!',
          ],
          onOpen: () => notifier.requestNotificationAccess(),
        ),
      ),
      _PermDef(
        icon:        Icons.accessibility_new_rounded,
        color:       const Color(0xFF8B5CF6),
        title:       'Deep Protection (Accessibility)',
        why:         'Scans on-screen text in payment and messaging apps to catch scams even when notifications are turned off for those apps.',
        isGranted:   health.accessibilityGranted,
        type:        _PermType.accessibility,
        onEnable:    () => _showGuideSheet(
          context, ref,
          title:   'Enable Deep Protection',
          steps:   const [
            'Tap  Open Settings  below.',
            'Scroll down to  "AI Security Deep Protection".',
            'Tap it, then toggle  Use AI Security  to ON.',
            'Tap  Allow  on the confirmation dialog.',
            'Press back — protection is active!',
          ],
          onOpen: () => notifier.requestAccessibility(),
        ),
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
          Spacing.md, Spacing.sm, Spacing.md, 100),
      children: [
        // ── Progress header ────────────────────────────────────────────────
        _ProgressHeader(granted: granted, total: 4, isDark: isDark),
        const SizedBox(height: Spacing.lg),

        // ── Permission tiles ───────────────────────────────────────────────
        ...perms.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child:   _PermissionCard(perm: p, isDark: isDark),
        )),

        // ── Why these permissions? collapsible ─────────────────────────────
        const SizedBox(height: Spacing.sm),
        _PrivacyNote(isDark: isDark),
      ],
    );
  }

  static void _showGuideSheet(
    BuildContext context,
    WidgetRef ref, {
    required String       title,
    required List<String> steps,
    required VoidCallback onOpen,
  }) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GuideSheet(
        title:  title,
        steps:  steps,
        onOpen: () {
          Navigator.pop(context);
          onOpen();
        },
      ),
    );
  }
}

// ── Progress Header ───────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.granted,
    required this.total,
    required this.isDark,
  });
  final int  granted, total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final allDone = granted == total;
    final pct     = granted / total;

    return Container(
      padding:    const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: allDone
            ? const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              )
            : const LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:      (allDone ? AppColors.secondary : AppColors.primary)
                .withOpacity(0.30),
            blurRadius: 18,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.verified_user_rounded
                    : Icons.security_update_warning_rounded,
                color: Colors.white,
                size:  28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  allDone ? 'Maximum Protection Active' : 'Setup Required',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$granted / $total',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize:   14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            pct,
              backgroundColor:  Colors.white.withOpacity(0.20),
              valueColor:       const AlwaysStoppedAnimation(Colors.white),
              minHeight:        6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            allDone
                ? 'Your device is fully shielded from scams.'
                : '${total - granted} permission${total - granted == 1 ? '' : 's'} still needed for full protection.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Permission Card ────────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.perm, required this.isDark});
  final _PermDef perm;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    final granted = perm.isGranted;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: granted
              ? AppColors.secondary.withOpacity(0.40)
              : isDark ? AppColors.borderDark : AppColors.border,
          width: granted ? 1.5 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color:  Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon container
                Container(
                  width:  46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: granted
                        ? AppColors.secondary.withOpacity(0.12)
                        : perm.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    granted ? Icons.check_rounded : perm.icon,
                    color:   granted ? AppColors.secondary : perm.color,
                    size:    22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perm.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _TypeBadge(type: perm.type, granted: granted),
                    ],
                  ),
                ),
                // Status / button
                if (granted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:        AppColors.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color:      AppColors.secondary,
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  _EnableButton(perm: perm),
              ],
            ),

            // Why this matters
            if (!granted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        perm.color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: perm.color, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        perm.why,
                        style: TextStyle(
                          fontSize: 14,
                          color:    isDark
                              ? Colors.white70
                              : AppColors.textSecondary,
                          height:   1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Type badge ────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.granted});
  final _PermType type;
  final bool      granted;

  @override
  Widget build(BuildContext context) {
    if (granted) return const SizedBox.shrink();

    final (label, color) = switch (type) {
      _PermType.runtime            => ('One tap', AppColors.secondary),
      _PermType.notificationListener => ('Needs system settings', AppColors.warning),
      _PermType.accessibility      => ('Needs system settings', AppColors.warning),
    };

    return Row(
      children: [
        Container(
          width:  6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:    color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Enable button ────────────────────────────────────────────────────────────

class _EnableButton extends StatelessWidget {
  const _EnableButton({required this.perm});
  final _PermDef perm;

  @override
  Widget build(BuildContext context) {
    final isSystem = perm.type != _PermType.runtime;

    return GestureDetector(
      onTap: perm.onEnable,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [perm.color, perm.color.withOpacity(0.75)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:      perm.color.withOpacity(0.28),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSystem) ...[
              const Icon(Icons.open_in_new_rounded,
                  color: Colors.white, size: 13),
              const SizedBox(width: 5),
            ],
            Text(
              isSystem ? 'How to enable' : 'Enable',
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step-by-step guide bottom sheet ──────────────────────────────────────────

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({
    required this.title,
    required this.steps,
    required this.onOpen,
  });
  final String       title;
  final List<String> steps;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        isDark ? AppColors.borderDark : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize:   19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Follow these steps in Android Settings:',
            style: TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Steps
          ...steps.asMap().entries.map((e) => _Step(
            number: e.key + 1,
            text:   e.value,
            isDark: isDark,
          )),

          const SizedBox(height: 20),

          // Open Settings button
          GestureDetector(
            onTap: onOpen,
            child: Container(
              width:  double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(0.35),
                    blurRadius: 14,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.settings_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Open Settings',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Reminder
          Center(
            child: Text(
              'Come back here after — status updates automatically.',
              style: TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.text,
    required this.isDark,
  });
  final int    number;
  final String text;
  final bool   isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  28,
            height: 28,
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.12),
              shape:        BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color:      AppColors.primary,
                fontSize:   13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  height:   1.45,
                  color:    isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy note ──────────────────────────────────────────────────────────────

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark
            ? AppColors.borderDark.withOpacity(0.4)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded,
              color: AppColors.secondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All analysis happens on your device. No message content is ever uploaded to a server. Permissions are used only for threat detection.',
              style: TextStyle(
                fontSize: 12.5,
                color:    isDark ? Colors.white70 : AppColors.textSecondary,
                height:   1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

enum _PermType { runtime, notificationListener, accessibility }

class _PermDef {
  const _PermDef({
    required this.icon,
    required this.color,
    required this.title,
    required this.why,
    required this.isGranted,
    required this.type,
    required this.onEnable,
  });

  final IconData     icon;
  final Color        color;
  final String       title;
  final String       why;
  final bool         isGranted;
  final _PermType    type;
  final VoidCallback onEnable;
}

// ── Error state ───────────────────────────────────────────────────────────────

class _PermissionCheckError extends StatelessWidget {
  const _PermissionCheckError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  72,
              height: 72,
              decoration: BoxDecoration(
                color:  AppColors.warning.withOpacity(0.12),
                shape:  BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.warning,
                size:  34,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const Text(
              'Could not check permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This can happen if the app is starting up or a system service is temporarily unavailable. Tap Retry to check again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:  AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
