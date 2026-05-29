import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../providers/settings_provider.dart';

class SOSSettingsScreen extends ConsumerWidget {
  const SOSSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('SOS & Fall Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          ListTile(
            title:    const Text('Countdown before SOS'),
            subtitle: Text('${s.sosCountdown} seconds'),
            trailing: DropdownButton<int>(
              value:    s.sosCountdown,
              items:    [3, 5, 10]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v s')))
                  .toList(),
              onChanged: (v) { if (v != null) n.setSosCountdown(v); },
            ),
          ),
          SwitchListTile(
            title:     const Text('Voice trigger'),
            subtitle:  const Text('"Help me" activates SOS'),
            value:     s.voiceTrigger,
            onChanged: (v) => n.setVoiceTrigger(v),
          ),
          const Divider(),
          SwitchListTile(
            title:     const Text('Fall Detection'),
            value:     s.fallDetection,
            onChanged: (v) => n.setFallDetection(v),
          ),
          if (s.fallDetection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensitivity: ${['', 'Low', 'Medium', 'High'][s.fallSensitivity.round()]}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Slider(
                    value:     s.fallSensitivity,
                    min:       1,
                    max:       3,
                    divisions: 2,
                    onChanged: (v) => n.setFallSensitivity(v),
                  ),
                ],
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOS test triggered — no real alert sent.'),
                  ),
                );
              },
              icon:  const Icon(Icons.play_arrow, color: AppColors.secondary),
              label: const Text(
                'Test SOS (no real alert)',
                style: TextStyle(color: AppColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
