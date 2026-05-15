import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/colors.dart';

class BottomNavScaffold extends StatelessWidget {
  const BottomNavScaffold({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (label: 'Home',     icon: Icons.shield_outlined,   active: Icons.shield,          path: '/dashboard'),
    (label: 'Alerts',   icon: Icons.notifications_none, active: Icons.notifications,  path: '/threats'),
    (label: 'Family',   icon: Icons.people_outline,    active: Icons.people,          path: '/family'),
    (label: 'Settings', icon: Icons.settings_outlined, active: Icons.settings,        path: '/settings'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((t) => NavigationDestination(
          icon:          Icon(t.icon),
          selectedIcon:  Icon(t.active, color: AppColors.primary),
          label:         t.label,
        )).toList(),
      ),
    );
  }
}
