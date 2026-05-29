import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../widgets/common/app_button.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});
  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {

  // Track individual grant status
  final Map<String, bool> _granted = {
    'phone': false,
    'sms':   false,
    'loc':   false,
    'notif': false,
  };

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  Future<void> _checkAll() async {
    final phone = await Permission.phone.isGranted;
    final sms   = await Permission.sms.isGranted;
    final loc   = await Permission.location.isGranted;
    final notif = await Permission.notification.isGranted;
    if (mounted) {
      setState(() {
        _granted['phone'] = phone;
        _granted['sms']   = sms;
        _granted['loc']   = loc;
        _granted['notif'] = notif;
      });
    }
  }

  Future<void> _request(String key, Permission p) async {
    final status = await p.request();
    if (mounted) {
      setState(() => _granted[key] = status.isGranted);
    }
  }

  Future<void> _grantAll() async {
    if (_loading) return; // prevent concurrent calls
    if (mounted) setState(() => _loading = true);
    await [
      Permission.phone,
      Permission.sms,
      Permission.location,
      Permission.notification,
    ].request();
    await _checkAll(); // already has mounted guard
    if (!mounted) return;
    setState(() => _loading = false);
    if (_allGranted) context.go('/onboarding/sos-setup');
  }

  bool get _allGranted => _granted.values.every((v) => v);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final grantedCount = _granted.values.where((v) => v).length;

    final perms = [
      _Perm(
        key:        'phone',
        icon:       Icons.phone_rounded,
        color:      AppColors.info,
        label:      'Phone Access',
        reason:     'Detects robocalls and flags suspicious caller IDs the moment your phone rings.',
        permission: Permission.phone,
      ),
      _Perm(
        key:        'sms',
        icon:       Icons.sms_rounded,
        color:      AppColors.warning,
        label:      'SMS Access',
        reason:     'Scans incoming texts for OTP theft and phishing links before you open them.',
        permission: Permission.sms,
      ),
      _Perm(
        key:        'loc',
        icon:       Icons.location_on_rounded,
        color:      AppColors.secondary,
        label:      'Location',
        reason:     'Sends your location to emergency contacts during an SOS alert.',
        permission: Permission.location,
      ),
      _Perm(
        key:        'notif',
        icon:       Icons.notifications_rounded,
        color:      AppColors.primary,
        label:      'Notifications',
        reason:     'Delivers instant threat alerts even when the app is in the background.',
        permission: Permission.notification,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          children: [
            // Progress bar
            _ProgressBar(
                granted: grantedCount, total: 4, isDark: isDark),
            const SizedBox(height: Spacing.md),

            // List
            Expanded(
              child: ListView(
                children: perms.map((p) {
                  final isGranted = _granted[p.key] ?? false;
                  return _PermRow(
                    perm:      p,
                    isGranted: isGranted,
                    isDark:    isDark,
                    onTap: isGranted
                        ? null
                        : () => _request(p.key, p.permission),
                  );
                }).toList(),
              ),
            ),

            // Bottom button
            AppButton(
              label:     _allGranted ? 'Continue' : 'Grant All & Continue',
              icon:      _allGranted
                  ? Icons.arrow_forward_rounded
                  : Icons.security_rounded,
              loading:   _loading,
              onPressed: _grantAll,
              minHeight: TouchTarget.primary,
            ),
            const SizedBox(height: Spacing.md),

            // Skip link
            TextButton(
              onPressed: () => context.go('/onboarding/sos-setup'),
              child: Text(
                'Skip for now (reduced protection)',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar header ───────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.granted,
    required this.total,
    required this.isDark,
  });
  final int  granted, total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final done = granted == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        done
            ? AppColors.secondary.withOpacity(0.10)
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? AppColors.secondary.withOpacity(0.30)
              : AppColors.primary.withOpacity(0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color:   done ? AppColors.secondary : AppColors.primary,
            size:    20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done
                  ? 'All permissions granted — you\'re ready!'
                  : '$granted of $total permissions granted',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize:   13,
                color:      done ? AppColors.secondary : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single permission row ─────────────────────────────────────────────────────

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.perm,
    required this.isGranted,
    required this.isDark,
    required this.onTap,
  });
  final _Perm         perm;
  final bool          isGranted;
  final bool          isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppColors.secondary.withOpacity(0.35)
              : isDark ? AppColors.borderDark : AppColors.border,
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width:  44,
                height: 44,
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppColors.secondary.withOpacity(0.12)
                      : perm.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGranted ? Icons.check_rounded : perm.icon,
                  color: isGranted ? AppColors.secondary : perm.color,
                  size:  20,
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perm.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize:   15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      perm.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color:    AppColors.textSecondary,
                        height:   1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Granted',
                    style: TextStyle(
                      color:      AppColors.secondary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        perm.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                        color: perm.color.withOpacity(0.30)),
                  ),
                  child: Text(
                    'Tap to grant',
                    style: TextStyle(
                      color:      perm.color,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
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

// ── Data ──────────────────────────────────────────────────────────────────────

class _Perm {
  const _Perm({
    required this.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.reason,
    required this.permission,
  });
  final String     key;
  final IconData   icon;
  final Color      color;
  final String     label;
  final String     reason;
  final Permission permission;
}
