import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';
import '../../../core/utils/extensions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final sections = [
      _Section(
        title: 'Protection',
        items: [
          _Item(
            icon:     Icons.shield_rounded,
            iconColor: AppColors.primary,
            label:    'Protection Settings',
            sub:      'Adjust auto-block thresholds',
            path:     '/settings/protection',
          ),
          _Item(
            icon:      Icons.sos_rounded,
            iconColor: AppColors.danger,
            label:    'SOS & Fall Settings',
            sub:      'Countdown, sensitivity, voice trigger',
            path:     '/settings/sos',
          ),
          _Item(
            icon:      Icons.monitor_heart_rounded,
            iconColor: AppColors.secondary,
            label:    'Fall Detection',
            sub:      'Configure sensor sensitivity',
            path:     '/settings/sos',
          ),
        ],
      ),
      _Section(
        title: 'Tools',
        items: [
          _Item(
            icon:      Icons.manage_search_rounded,
            iconColor: AppColors.primary,
            label:    'Scan a Message',
            sub:      'Check any text for scam patterns',
            path:     '/scan',
          ),
          _Item(
            icon:      Icons.lock_clock_rounded,
            iconColor: AppColors.secondary,
            label:    'OTP Manager',
            sub:      'Quick copy recent OTPs from SMS',
            path:     '/otp',
          ),
          _Item(
            icon:      Icons.phone_in_talk_rounded,
            iconColor: AppColors.info,
            label:    'Call Log Analyser',
            sub:      'Scan recent calls for spam patterns',
            path:     '/spam-calls',
          ),
          _Item(
            icon:      Icons.cleaning_services_rounded,
            iconColor: AppColors.warning,
            label:    'WhatsApp Cleanup',
            sub:      'Free up storage from forwarded media',
            path:     '/cleanup',
          ),
        ],
      ),
      _Section(
        title: 'Account',
        items: [
          _Item(
            icon:      Icons.privacy_tip_rounded,
            iconColor: AppColors.info,
            label:    Strings.privacyPolicy,
            sub:      'How we protect your data',
            path:     '',
          ),
          _Item(
            icon:      Icons.article_rounded,
            iconColor: AppColors.textSecondary,
            label:    Strings.termsOfService,
            sub:      'Terms and conditions',
            path:     '',
          ),
          _Item(
            icon:      Icons.delete_forever_rounded,
            iconColor: AppColors.danger,
            label:    Strings.deleteAccount,
            sub:      'Permanently erase all data',
            path:     '',
            isDestructive: true,
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            Spacing.md, Spacing.sm, Spacing.md, 100),
        children: [
          // ── App version chip ────────────────────────────────────────────
          _AppVersionBadge(isDark: isDark),
          const SizedBox(height: Spacing.lg),

          ...sections.map((s) => _SectionGroup(section: s, isDark: isDark)),
        ],
      ),
    );
  }
}

// ── Data ────────────────────────────────────────────────────────────────────

class _Section {
  const _Section({required this.title, required this.items});
  final String      title;
  final List<_Item> items;
}

class _Item {
  const _Item({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.path,
    this.isDestructive = false,
  });
  final IconData icon;
  final Color    iconColor;
  final String   label, sub, path;
  final bool     isDestructive;
}

// ── Widgets ─────────────────────────────────────────────────────────────────

class _AppVersionBadge extends StatelessWidget {
  const _AppVersionBadge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'AI Phone Security',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Version 1.0.0 • Active protection',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius:          4,
                  backgroundColor: Color(0xFF34D399),
                ),
                SizedBox(width: 5),
                Text(
                  'ON',
                  style: TextStyle(
                    color:         Colors.white,
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.section, required this.isDark});
  final _Section section;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            section.title.toUpperCase(),
            style: TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              color:         AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
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
                      color:  Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: section.items.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              return Column(
                children: [
                  _SettingsTile(item: item, isDark: isDark),
                  if (i < section.items.length - 1)
                    Divider(
                      height: 1,
                      indent: 60,
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.item, required this.isDark});
  final _Item item;
  final bool  isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.path.isNotEmpty ? () => context.push(item.path) : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  42,
              height: 42,
              decoration: BoxDecoration(
                color:        item.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
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
            if (item.path.isNotEmpty)
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
