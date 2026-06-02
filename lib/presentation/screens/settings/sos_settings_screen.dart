import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../services/background/fall_detection_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sos_provider.dart';

class SOSSettingsScreen extends ConsumerStatefulWidget {
  const SOSSettingsScreen({super.key});

  @override
  ConsumerState<SOSSettingsScreen> createState() => _SOSSettingsScreenState();
}

class _SOSSettingsScreenState extends ConsumerState<SOSSettingsScreen> {
  // Quiet hours local state (reads directly from repository for immediate feedback)
  late bool _quietEnabled;
  late int  _quietStart;
  late int  _quietEnd;

  @override
  void initState() {
    super.initState();
    _quietEnabled = SettingsRepository.quietHoursEnabled;
    _quietStart   = SettingsRepository.quietHoursStart;
    _quietEnd     = SettingsRepository.quietHoursEnd;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('SOS & Fall Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          // ── SOS countdown ───────────────────────────────────────────────
          _sectionLabel('SOS'),
          ListTile(
            title:    const Text('Countdown before SOS'),
            subtitle: Text('${s.sosCountdown} seconds before alert is sent'),
            trailing: DropdownButton<int>(
              value:    s.sosCountdown,
              items:    [3, 5, 10]
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text('$v seconds'),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) n.setSosCountdown(v); },
            ),
          ),

          const Divider(),

          // ── Fall detection ──────────────────────────────────────────────
          _sectionLabel('Fall Detection'),
          SwitchListTile(
            title:     const Text('Fall Detection'),
            subtitle:  const Text('Automatically triggers SOS if a fall is detected'),
            value:     s.fallDetection,
            onChanged: (v) => n.setFallDetection(v),
          ),
          if (s.fallDetection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensitivity: ${_sensitivityLabel(s.fallSensitivity)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Text(
                    'Low = only hard falls  •  High = more sensitive (may trigger if you drop your phone)',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                  ),
                  Slider(
                    value:     s.fallSensitivity.clamp(1.0, 3.0),
                    min:       1,
                    max:       3,
                    divisions: 2,
                    onChanged: (v) => n.setFallSensitivity(v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _testFallDetection(context),
                      icon:  const Icon(Icons.accessibility_new_rounded, size: 16),
                      label: const Text('Test fall detection'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(),

          // ── Quiet hours ─────────────────────────────────────────────────
          _sectionLabel('Quiet Hours'),
          SwitchListTile(
            title:     const Text('Quiet hours'),
            subtitle:  const Text(
                'Silence scam alerts during sleep. SOS always works.'),
            value:     _quietEnabled,
            onChanged: (v) async {
              setState(() => _quietEnabled = v);
              await SettingsRepository.setQuietHoursEnabled(v);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(v
                        ? 'Quiet hours on — scam alerts silenced at night'
                        : 'Quiet hours off'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          if (_quietEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: 4),
              child: Row(children: [
                const Text('From', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                _TimePickerButton(
                  hour:      _quietStart,
                  onChanged: (h) async {
                    setState(() => _quietStart = h);
                    await SettingsRepository.setQuietHoursStart(h);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('to', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                _TimePickerButton(
                  hour:      _quietEnd,
                  onChanged: (h) async {
                    setState(() => _quietEnd = h);
                    await SettingsRepository.setQuietHoursEnd(h);
                  },
                ),
                const Spacer(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, 12),
              child: Text(
                'Scam alerts will be silent from ${_fmtHour(_quietStart)} to ${_fmtHour(_quietEnd)}. SOS always works.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
          ],

          const Divider(),

          // ── Test SOS ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _runTestSOS(context, ref),
                  icon:  const Icon(Icons.send_rounded),
                  label: const Text('Send Test SOS to Contacts'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sends a "[TEST]" message to your emergency contacts so they know the app is working.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize:      11,
            fontWeight:    FontWeight.w700,
            color:         AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      );

  static String _sensitivityLabel(double v) {
    return switch (v.round()) {
      1 => 'Low',
      2 => 'Medium',
      3 => 'High',
      _ => 'Medium',
    };
  }

  static String _fmtHour(int h) {
    if (h == 0)  return '12:00 AM';
    if (h < 12)  return '$h:00 AM';
    if (h == 12) return '12:00 PM';
    return '${h - 12}:00 PM';
  }

  Future<void> _testFallDetection(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Test Fall Detection'),
        content: const Text(
          'This will immediately trigger a test fall alert.\n\n'
          'You will see a "Fall detected" notification on your phone.\n\n'
          'No SOS will be sent to your contacts during this test.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Test'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FallDetectionService.instance.simulateFall();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent — check your notification bar'),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _runTestSOS(BuildContext context, WidgetRef ref) async {
    final contacts = SettingsRepository.emergencyContacts;
    if (contacts.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No emergency contacts'),
          content: const Text(
            'Add at least one emergency contact first.\n\n'
            'Go back and tap "SOS Contacts" to add them.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final names = contacts.map((c) => c['name'] ?? c['phone'] ?? '').join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send test SOS?'),
        content: Text(
          'This will send a [TEST] message to:\n\n$names\n\n'
          'They will receive a text saying this is only a test.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Test'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(sOSProvider.notifier).testAlert();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Test message sent to $names')),
          ]),
          backgroundColor: AppColors.secondary,
          duration:        const Duration(seconds: 4),
        ),
      );
    }
  }
}

// ── Time picker button ────────────────────────────────────────────────────────

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({required this.hour, required this.onChanged});
  final int                hour;
  final ValueChanged<int>  onChanged;

  static String _label(int h) {
    if (h == 0)  return '12:00 AM';
    if (h < 12)  return '$h:00 AM';
    if (h == 12) return '12:00 PM';
    return '${h - 12}:00 PM';
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
          helpText:    'Select time',
        );
        if (picked != null) onChanged(picked.hour);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(_label(hour),
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
