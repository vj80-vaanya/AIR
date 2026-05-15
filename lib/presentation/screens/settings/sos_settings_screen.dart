import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';

class SOSSettingsScreen extends StatefulWidget {
  const SOSSettingsScreen({super.key});
  @override
  State<SOSSettingsScreen> createState() => _SOSSettingsScreenState();
}

class _SOSSettingsScreenState extends State<SOSSettingsScreen> {
  int    _countdown     = 5;
  bool   _voiceTrigger  = false;
  bool   _fallDetection = true;
  double _fallSensitivity = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS & Fall Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          ListTile(
            title:    const Text('Countdown before SOS'),
            subtitle: Text('$_countdown seconds'),
            trailing: DropdownButton<int>(
              value:   _countdown,
              items:   [3, 5, 10].map((v) => DropdownMenuItem(value: v, child: Text('$v s'))).toList(),
              onChanged: (v) => setState(() => _countdown = v!),
            ),
          ),
          SwitchListTile(
            title:    const Text('Voice trigger'),
            subtitle: const Text('"Help me" activates SOS'),
            value:    _voiceTrigger,
            onChanged: (v) => setState(() => _voiceTrigger = v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Fall Detection'),
            value: _fallDetection,
            onChanged: (v) => setState(() => _fallDetection = v),
          ),
          if (_fallDetection) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sensitivity: ${['', 'Low', 'Medium', 'High'][_fallSensitivity.round()]}',
                       style: Theme.of(context).textTheme.bodyMedium),
                  Slider(
                    value:     _fallSensitivity,
                    min:       1,
                    max:       3,
                    divisions: 2,
                    onChanged: (v) => setState(() => _fallSensitivity = v),
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
                  const SnackBar(content: Text('SOS test triggered — no real alert sent.')),
                );
              },
              icon:  const Icon(Icons.play_arrow, color: AppColors.secondary),
              label: const Text('Test SOS (no real alert)', style: TextStyle(color: AppColors.secondary)),
            ),
          ),
        ],
      ),
    );
  }
}
