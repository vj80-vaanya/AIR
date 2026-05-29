import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/spacing.dart';
import '../../providers/settings_provider.dart';

class ProtectionSettingsScreen extends ConsumerWidget {
  const ProtectionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Protection Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-block threshold: ${s.threshold.round()}',
                       style: Theme.of(context).textTheme.titleMedium),
                  const Text('Calls/SMS above this risk score are blocked automatically.'),
                  Slider(
                    value:     s.threshold,
                    min:       50,
                    max:       100,
                    divisions: 50,
                    label:     s.threshold.round().toString(),
                    onChanged: (v) => n.setThreshold(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          SwitchListTile(
            title:     const Text('Call Protection'),
            value:     s.callProtect,
            onChanged: (v) => n.setCallProtect(v),
          ),
          SwitchListTile(
            title:     const Text('SMS Protection'),
            value:     s.smsProtect,
            onChanged: (v) => n.setSmsProtect(v),
          ),
          SwitchListTile(
            title:     const Text('WhatsApp Protection'),
            value:     s.waProtect,
            onChanged: (v) => n.setWaProtect(v),
          ),
          SwitchListTile(
            title:     const Text('Email Protection'),
            value:     s.emailProtect,
            onChanged: (v) => n.setEmailProtect(v),
          ),
        ],
      ),
    );
  }
}
