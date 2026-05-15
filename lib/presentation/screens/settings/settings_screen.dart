import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        title: 'Protection',
        items: [
          (icon: Icons.security,  label: 'Protection Settings', path: '/settings/protection'),
          (icon: Icons.sos,       label: 'SOS Settings',        path: '/settings/sos'),
          (icon: Icons.monitor_heart, label: 'Fall Detection',  path: '/settings/sos'),
        ],
      ),
      (
        title: 'Account',
        items: [
          (icon: Icons.privacy_tip, label: Strings.privacyPolicy,  path: ''),
          (icon: Icons.article,     label: Strings.termsOfService,  path: ''),
          (icon: Icons.delete_forever, label: Strings.deleteAccount, path: ''),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settingsTitle)),
      body: ListView(
        children: sections.map((s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.xs),
              child: Text(s.title,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          )),
            ),
            ...s.items.map((item) => ListTile(
              leading:  Icon(item.icon),
              title:    Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap:    item.path.isNotEmpty ? () => context.push(item.path) : null,
            )),
            const Divider(),
          ],
        )).toList(),
      ),
    );
  }
}
