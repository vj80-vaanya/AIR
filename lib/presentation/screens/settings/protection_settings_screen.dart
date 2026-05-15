import 'package:flutter/material.dart';
import '../../../core/constants/spacing.dart';

class ProtectionSettingsScreen extends StatefulWidget {
  const ProtectionSettingsScreen({super.key});
  @override
  State<ProtectionSettingsScreen> createState() => _ProtectionSettingsScreenState();
}

class _ProtectionSettingsScreenState extends State<ProtectionSettingsScreen> {
  double _threshold     = 85;
  bool   _callProtect   = true;
  bool   _smsProtect    = true;
  bool   _waProtect     = true;
  bool   _emailProtect  = true;

  @override
  Widget build(BuildContext context) {
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
                  Text('Auto-block threshold: ${_threshold.round()}',
                       style: Theme.of(context).textTheme.titleMedium),
                  const Text('Calls/SMS above this risk score are blocked automatically.'),
                  Slider(
                    value:    _threshold,
                    min:      50,
                    max:      100,
                    divisions: 50,
                    label:    _threshold.round().toString(),
                    onChanged: (v) => setState(() => _threshold = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          _ToggleTile(label: 'Call Protection',     value: _callProtect,  onChanged: (v) => setState(() => _callProtect = v)),
          _ToggleTile(label: 'SMS Protection',      value: _smsProtect,   onChanged: (v) => setState(() => _smsProtect = v)),
          _ToggleTile(label: 'WhatsApp Protection', value: _waProtect,    onChanged: (v) => setState(() => _waProtect = v)),
          _ToggleTile(label: 'Email Protection',    value: _emailProtect, onChanged: (v) => setState(() => _emailProtect = v)),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool   value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title:    Text(label),
    value:    value,
    onChanged: onChanged,
  );
}
