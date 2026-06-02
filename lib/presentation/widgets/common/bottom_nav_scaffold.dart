import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (label: 'Shield',   icon: Icons.shield_outlined,    active: Icons.shield,             path: '/dashboard'),
    (label: 'Alerts',   icon: Icons.notifications_none,  active: Icons.notifications,      path: '/threats'),
    (label: 'Family',   icon: Icons.people_outline,     active: Icons.people,              path: '/family'),
    (label: 'Settings', icon: Icons.tune_outlined,      active: Icons.tune,                path: '/settings'),
  ];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx    = _selectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : Colors.white)
                    .withOpacity(isDark ? 0.88 : 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark.withOpacity(0.7)
                      : AppColors.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:  Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  _tabs.length,
                  (i) => _NavItem(
                    tab:      _tabs[i],
                    selected: idx == i,
                    onTap:    () => context.go(_tabs[i].path),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final ({String label, IconData icon, IconData active, String path}) tab;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve:    Curves.easeInOut,
        padding:  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? tab.active : tab.icon,
                key:   ValueKey(selected),
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size:  22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize:   11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
