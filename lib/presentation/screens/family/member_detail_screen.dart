import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../providers/family_provider.dart';
import '../../widgets/common/loading_indicator.dart';

class MemberDetailScreen extends ConsumerWidget {
  const MemberDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider);
    final isDark       = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text('Family Member')),
      body: membersAsync.when(
        loading: () => const LoadingIndicator(),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          final member = members.where((m) => m.id == id).firstOrNull;
          if (member == null) {
            return const Center(child: Text('Member not found.'));
          }

          final initials = member.name.initials;

          return ListView(
            padding: EdgeInsets.fromLTRB(
                Spacing.md, Spacing.sm, Spacing.md, 100),
            children: [
              // ── Avatar card ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:  AppColors.primary.withOpacity(0.30),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width:  72,
                      height: 72,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.22),
                        shape:        BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.phone,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:        Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width:  7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color:  Color(0xFF34D399),
                                    shape:  BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Safe',
                                  style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Spacing.md),

              // ── Role tags ──────────────────────────────────────────────
              Row(
                children: [
                  if (member.isEmergencyContact)
                    _Tag(
                      label: 'Emergency Contact',
                      icon:  Icons.sos_rounded,
                      color: AppColors.danger,
                    ),
                  if (member.isFamilyMember)
                    _Tag(
                      label: 'Family Member',
                      icon:  Icons.people_rounded,
                      color: AppColors.secondary,
                    ),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // ── Info tiles ──────────────────────────────────────────────
              _InfoTile(
                icon:   Icons.phone_rounded,
                color:  AppColors.info,
                label:  'Phone number',
                value:  member.phone,
                isDark: isDark,
              ),
              const SizedBox(height: Spacing.sm),
              _InfoTile(
                icon:   Icons.shield_rounded,
                color:  AppColors.secondary,
                label:  'Protection status',
                value:  'Monitoring active',
                isDark: isDark,
              ),
              const SizedBox(height: Spacing.sm),
              _InfoTile(
                icon:   Icons.notifications_rounded,
                color:  AppColors.primary,
                label:  'Critical alerts',
                value:  'Will receive SOS alerts from you',
                isDark: isDark,
              ),

              const SizedBox(height: Spacing.lg),

              // ── Actions ────────────────────────────────────────────────
              _ActionButton(
                label: 'Remove from family',
                icon:  Icons.person_remove_rounded,
                color: AppColors.danger,
                onTap: () => _confirmRemove(context, ref, member.id),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, String memberId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Remove member?'),
        content: const Text(
          'They will no longer receive SOS alerts from you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:    FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(familyMembersProvider.notifier).removeMember(memberId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, required this.color});
  final String   label;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.isDark,
  });
  final IconData icon;
  final Color    color;
  final String   label, value;
  final bool     isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:  38,
            height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontWeight: FontWeight.w700,
                fontSize:   14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
