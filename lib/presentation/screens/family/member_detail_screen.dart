import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Details')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: Spacing.md),
            Text('Member $id', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Chip(
              label: const Text('Safe at home'),
              avatar: const Icon(Icons.home, size: 16),
              backgroundColor: AppColors.secondary.withAlpha(30),
            ),
            const SizedBox(height: Spacing.lg),
            _StatCard(label: 'Threats blocked this week', value: '3'),
            const SizedBox(height: Spacing.sm),
            _StatCard(label: 'Last SOS', value: 'Never'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title:    Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
