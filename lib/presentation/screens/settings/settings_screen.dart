import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/datasources/local/database_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 100),
        children: [
          _AppVersionBadge(isDark: isDark),
          const SizedBox(height: Spacing.lg),

          // ── Protection ──────────────────────────────────────────────────
          _SectionHeader('PROTECTION'),
          _SettingsCard(isDark: isDark, items: [
            _Tile(
              icon:  Icons.contacts_rounded,
              color: AppColors.danger,
              label: 'Manage SOS Contacts',
              sub:   'Edit emergency contacts who receive your SOS alerts',
              onTap: () => context.push('/onboarding/sos-setup'),
            ),
            _Tile(
              icon:  Icons.shield_rounded,
              color: AppColors.primary,
              label: 'Protection Settings',
              sub:   'Adjust auto-block thresholds',
              onTap: () => context.push('/settings/protection'),
            ),
            _Tile(
              icon:  Icons.sos_rounded,
              color: AppColors.warning,
              label: 'SOS & Fall Settings',
              sub:   'Countdown, sensitivity, fall detection',
              onTap: () => context.push('/settings/sos'),
            ),
            _Tile(
              icon:  Icons.verified_user_rounded,
              color: AppColors.info,
              label: 'Check App Permissions',
              sub:   'See which permissions are active and fix missing ones',
              onTap: () => context.go('/permission-guardian'),
            ),
          ]),
          const SizedBox(height: Spacing.lg),

          // ── Tools ───────────────────────────────────────────────────────
          _SectionHeader('TOOLS'),
          _SettingsCard(isDark: isDark, items: [
            _Tile(
              icon:  Icons.manage_search_rounded,
              color: AppColors.primary,
              label: 'Scan a Message',
              sub:   'Check any text for scam patterns',
              onTap: () => context.push('/scan'),
            ),
            _Tile(
              icon:  Icons.lock_clock_rounded,
              color: AppColors.secondary,
              label: 'OTP Manager',
              sub:   'Quick copy recent OTPs from SMS',
              onTap: () => context.push('/otp'),
            ),
            _Tile(
              icon:  Icons.phone_in_talk_rounded,
              color: AppColors.info,
              label: 'Call Log Analyser',
              sub:   'Scan recent calls for spam patterns',
              onTap: () => context.push('/spam-calls'),
            ),
            _Tile(
              icon:  Icons.cleaning_services_rounded,
              color: AppColors.warning,
              label: 'WhatsApp Cleanup',
              sub:   'Free up storage from forwarded media',
              onTap: () => context.push('/cleanup'),
            ),
          ]),
          const SizedBox(height: Spacing.lg),

          // ── Setup ───────────────────────────────────────────────────────
          _SectionHeader('SETUP'),
          _SettingsCard(isDark: isDark, items: [
            _Tile(
              icon:  Icons.restart_alt_rounded,
              color: AppColors.primary,
              label: 'Redo Initial Setup',
              sub:   'Update permissions, SOS contacts, and family',
              onTap: () async {
                // Reset onboarding flag so the router redirect allows re-entry
                await SettingsRepository.resetOnboardingDone();
                if (context.mounted) context.go('/onboarding/welcome');
              },
            ),
          ]),
          const SizedBox(height: Spacing.lg),

          // ── Help & Safety ───────────────────────────────────────────────
          _SectionHeader('HELP & SAFETY'),
          _SettingsCard(isDark: isDark, items: [
            _Tile(
              icon:  Icons.phone_in_talk_rounded,
              color: AppColors.danger,
              label: 'Cybercrime Helpline',
              sub:   'India: Call 1930 to report scams 24×7',
              onTap: () => _showCybercrimeHelp(context),
            ),
            _Tile(
              icon:  Icons.language_rounded,
              color: AppColors.info,
              label: 'Report Online',
              sub:   'File a complaint at cybercrime.gov.in',
              onTap: () => _showCybercrimeHelp(context),
            ),
          ]),
          const SizedBox(height: Spacing.lg),

          // ── Account ─────────────────────────────────────────────────────
          _SectionHeader('ACCOUNT'),
          _SettingsCard(isDark: isDark, items: [
            _Tile(
              icon:  Icons.privacy_tip_rounded,
              color: AppColors.info,
              label: Strings.privacyPolicy,
              sub:   'How we protect your data',
              onTap: () => _showPolicy(context, 'Privacy Policy', _privacyText, _privacyPolicyUrl),
            ),
            _Tile(
              icon:  Icons.article_rounded,
              color: AppColors.textSecondary,
              label: Strings.termsOfService,
              sub:   'Terms and conditions',
              onTap: () => _showPolicy(context, 'Terms of Service', _termsText, _termsUrl),
            ),
            _Tile(
              icon:           Icons.delete_forever_rounded,
              color:          AppColors.danger,
              label:          Strings.deleteAccount,
              sub:            'Permanently erase all data from this device',
              onTap:          () => _confirmDeleteAccount(context),
              isDestructive:  true,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Cybercrime helpline ───────────────────────────────────────────────────

  void _showCybercrimeHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: const Text('Report a Cybercrime'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('National Cybercrime Helpline',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:1930')),
              child: const Row(children: [
                Icon(Icons.phone_rounded, color: AppColors.danger, size: 20),
                SizedBox(width: 8),
                Text('1930',
                    style: TextStyle(
                        fontSize:   28,
                        fontWeight: FontWeight.w900,
                        color:      AppColors.danger,
                        decoration: TextDecoration.underline)),
              ]),
            ),
            const Text('Tap to call  •  Available 24×7',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Online portal:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://cybercrime.gov.in'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('cybercrime.gov.in',
                  style: TextStyle(
                      color:      AppColors.info,
                      fontSize:   15,
                      decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Report scam calls, OTP fraud, fake arrest threats, and online financial fraud.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Delete Account ────────────────────────────────────────────────────────

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All detected threats\n'
          '• Emergency contacts\n'
          '• Family members\n'
          '• All app settings\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    // 1. Clear all SharedPreferences
    await SettingsRepository.clearAll();

    // 2. Delete the SQLite database
    await DatabaseManager.deleteDatabase();

    if (!context.mounted) return;

    // 3. Send user back to onboarding
    context.go('/onboarding/welcome');
  }

  // ── Policy dialog ─────────────────────────────────────────────────────────

  Future<void> _showPolicy(BuildContext context, String title, String text, String url) async {
    // Try to open the live URL first; fall back to in-app text if unavailable
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copied')));
                },
                child: Text(url,
                    style: const TextStyle(
                        color: AppColors.info, fontSize: 12,
                        decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 12),
              Text(text),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // TODO: Replace with a real hosted URL before production.
  // Google Play requires a clickable external privacy policy URL, not in-app text.
  // Host this document at: https://aiphonesecurity.in/privacy
  static const _privacyPolicyUrl = 'https://aiphonesecurity.in/privacy';
  static const _termsUrl         = 'https://aiphonesecurity.in/terms';

  static const _privacyText =
      'Full policy: $_privacyPolicyUrl\n\n'
      'AI Phone Security processes all data on your device only. '
      'No message content, call details, or personal information is ever uploaded to any server.\n\n'
      'Permissions used:\n'
      '• Phone: Detect incoming call risk\n'
      '• SMS: Detect incoming message risk\n'
      '• Location: Emergency SOS only\n'
      '• Notifications: Background threat alerts\n\n'
      'Emergency contacts and family members are stored locally on your device in encrypted storage. '
      'You may delete all data at any time using the Delete Account option.';

  static const _termsText =
      'By using AI Phone Security, you agree:\n\n'
      '1. This app provides threat detection assistance, not a guarantee of safety.\n'
      '2. Emergency SOS requires valid contacts and working mobile service.\n'
      '3. Do not rely solely on this app in life-threatening situations — always call 112.\n'
      '4. All data is processed locally. We are not responsible for missed threats.\n'
      '5. False positives may occur. Use the "False Alarm" button to improve accuracy.\n\n'
      'For support, contact support@aiphonesecurity.in';
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w700,
            color:      AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      );
}

class _Tile {
  const _Tile({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData     icon;
  final Color        color;
  final String       label, sub;
  final VoidCallback onTap;
  final bool         isDestructive;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.isDark, required this.items});
  final bool         isDark;
  final List<_Tile>  items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset:     const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          return Column(children: [
            _SettingsTile(item: e.value, isDark: isDark),
            if (e.key < items.length - 1)
              Divider(
                height: 1,
                indent: 60,
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.item, required this.isDark});
  final _Tile item;
  final bool  isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                color:        item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize:   15,
                      color: item.isDestructive ? AppColors.danger : null,
                    ),
                  ),
                  if (item.sub.isNotEmpty)
                    Text(
                      item.sub,
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
              size:  20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppVersionBadge extends StatelessWidget {
  const _AppVersionBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (_, snap) {
        final version = snap.data?.version ?? '—';
        final build   = snap.data?.buildNumber ?? '';
        return _badge(context, version, build);
      },
    );
  }

  Widget _badge(BuildContext context, String version, String build) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withOpacity(0.30),
            blurRadius: 16,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Phone Security',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $version${build.isNotEmpty ? ' ($build)' : ''} • Active protection',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF34D399)),
                SizedBox(width: 5),
                Text('ON',
                    style: TextStyle(
                      color:         Colors.white,
                      fontSize:      11,
                      fontWeight:    FontWeight.w700,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
