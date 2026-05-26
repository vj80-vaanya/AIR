import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/security_status_provider.dart';
import '../../core/constants/colors.dart';

class PermissionGuardianScreen extends ConsumerWidget {
  const PermissionGuardianScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(securityStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Guardian'),
        actions: [
          IconButton(
            onPressed: () => ref.read(securityStatusProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: statusAsync.when(
        data: (health) => _buildContent(context, ref, health),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, SecurityHealth health) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(health.isFullyProtected),
        const SizedBox(height: 30),
        _PermissionTile(
          title: 'SMS Monitoring',
          description: 'Needed to scan traditional SMS scams.',
          isGranted: health.smsGranted,
          onTap: () => ref.read(securityStatusProvider.notifier).requestSms(),
        ),
        _PermissionTile(
          title: 'Phone Protection',
          description: 'Identifies suspicious callers and robocalls.',
          isGranted: health.phoneGranted,
          onTap: () => ref.read(securityStatusProvider.notifier).requestPhone(),
        ),
        _PermissionTile(
          title: 'Notification Access',
          description: 'Essential for scanning WhatsApp, Telegram, and Signal messages.',
          isGranted: health.notificationAccessGranted,
          onTap: () => ref.read(securityStatusProvider.notifier).requestNotificationAccess(),
        ),
        _PermissionTile(
          title: 'Deep Protection',
          description: 'Accessibility service scans screen content if notifications are off.',
          isGranted: health.accessibilityGranted,
          onTap: () => ref.read(securityStatusProvider.notifier).requestAccessibility(),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isFullyProtected) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isFullyProtected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFullyProtected ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isFullyProtected ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 64,
            color: isFullyProtected ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            isFullyProtected ? 'Maximum Protection Active' : 'Protection Incomplete',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isFullyProtected 
              ? 'Your device is fully shielded from scams.' 
              : 'Enable all permissions for total security.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: onTap,
                child: const Text('Enable'),
              ),
      ),
    );
  }
}
