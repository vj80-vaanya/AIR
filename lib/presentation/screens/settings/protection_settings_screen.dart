import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../providers/security_status_provider.dart';
import '../../providers/settings_provider.dart';

class ProtectionSettingsScreen extends ConsumerWidget {
  const ProtectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s      = ref.watch(settingsProvider);
    final n      = ref.read(settingsProvider.notifier);
    final health = ref.watch(securityStatusProvider).valueOrNull;

    void saved() => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:  Text('Settings saved'),
            duration: Duration(seconds: 1),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Protection Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          // ── Block threshold ─────────────────────────────────────────────
          _ThresholdCard(threshold: s.threshold, onChanged: n.setThreshold),

          const SizedBox(height: Spacing.md),

          // ── Channel toggles ─────────────────────────────────────────────
          _ToggleTile(
            title:        'Call Protection',
            subtitle:     'Stops fake CBI, bank, and delivery scam calls from reaching you',
            icon:         Icons.phone_rounded,
            iconColor:    AppColors.info,
            value:        s.callProtect,
            permOk:       health?.phoneGranted ?? true,
            permLabel:    'Phone permission required',
            onChanged:    (v) { n.setCallProtect(v); saved(); },
          ),
          _ToggleTile(
            title:        'SMS Protection',
            subtitle:     'Catches OTP theft, fake bank alerts, and KYC fraud SMS',
            icon:         Icons.sms_rounded,
            iconColor:    AppColors.warning,
            value:        s.smsProtect,
            permOk:       health?.smsGranted ?? true,
            permLabel:    'SMS permission required',
            onChanged:    (v) { n.setSmsProtect(v); saved(); },
          ),
          _ToggleTile(
            title:        'WhatsApp Protection',
            subtitle:     'Detects fake arrest threats and investment traps sent via WhatsApp',
            icon:         Icons.message_rounded,
            iconColor:    AppColors.secondary,
            value:        s.waProtect,
            permOk:       health?.notificationAccessGranted ?? true,
            permLabel:    'Notification access required',
            onChanged:    (v) { n.setWaProtect(v); saved(); },
          ),
          _ToggleTile(
            title:        'Email Protection',
            subtitle:     'Catches phishing emails pretending to be banks or government',
            icon:         Icons.email_rounded,
            iconColor:    AppColors.primary,
            value:        s.emailProtect,
            permOk:       health?.notificationAccessGranted ?? true,
            permLabel:    'Notification access required',
            onChanged:    (v) { n.setEmailProtect(v); saved(); },
          ),
        ],
      ),
    );
  }
}

// ── Threshold card ───────────────────────────────────────────────────────────

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({
    required this.threshold,
    required this.onChanged,
  });
  final double             threshold;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = threshold >= 90
        ? 'Strict — only the most obvious scams are blocked'
        : threshold >= 75
            ? 'Balanced (recommended) — blocks clear scams, warns about suspicious ones'
            : 'Sensitive — catches more scams, but may occasionally block real messages';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                'Block threshold: ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${threshold.round()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:      AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color:    AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            Slider(
              value:     threshold,
              min:       50,
              max:       100,
              divisions: 50,
              label:     threshold.round().toString(),
              onChanged: onChanged,
            ),
            const Text(
              'Calls and messages with a risk score above this value are blocked automatically.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (threshold != 75)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onChanged(75),
                  style: TextButton.styleFrom(
                      padding:        EdgeInsets.zero,
                      foregroundColor: AppColors.info),
                  child: const Text('Reset to recommended (75)',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle tile with permission warning ──────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.permOk,
    required this.permLabel,
    required this.onChanged,
  });

  final String   title, subtitle, permLabel;
  final IconData icon;
  final Color    iconColor;
  final bool     value, permOk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          secondary: Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color:        iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title:     Text(title),
          subtitle:  Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          value:     value,
          onChanged: onChanged,
        ),
        if (!permOk)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$permLabel — go to Check App Permissions to fix this.',
                  style: const TextStyle(
                    color:    AppColors.warning,
                    fontSize: 12,
                    height:   1.4,
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
