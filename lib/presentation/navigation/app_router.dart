import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/constants/colors.dart';

import '../../data/repositories/settings_repository.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/onboarding/sos_setup_screen.dart';
import '../screens/onboarding/family_connect_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/threats/threat_list_screen.dart';
import '../screens/threats/threat_detail_screen.dart';
import '../screens/sos/sos_screen.dart';
import '../screens/family/family_screen.dart';
import '../screens/family/member_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/protection_settings_screen.dart';
import '../screens/settings/sos_settings_screen.dart';
import '../screens/settings/permission_guardian_screen.dart';
import '../screens/scanner/manual_scan_screen.dart';
import '../screens/cleanup/whatsapp_cleanup_screen.dart';
import '../screens/cleanup/media_browse_screen.dart';
import '../screens/cleanup/duplicate_groups_screen.dart';
import '../screens/otp/otp_manager_screen.dart';
import '../screens/calls/spam_calls_screen.dart';
import '../widgets/common/bottom_nav_scaffold.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/onboarding/welcome',
    redirect: (context, state) {
      final onboarded = SettingsRepository.onboardingDone;
      final onOnboarding = state.uri.path.startsWith('/onboarding');
      // Skip onboarding entirely if user has already completed it
      if (onboarded && onOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      /* Onboarding */
      GoRoute(path: '/onboarding/welcome',        builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/onboarding/permissions',    builder: (_, __) => const PermissionsScreen()),
      GoRoute(path: '/onboarding/sos-setup',      builder: (_, __) => const SOSSetupScreen()),
      GoRoute(path: '/onboarding/family-connect', builder: (_, __) => const FamilyConnectScreen()),

      /* Main shell */
      ShellRoute(
        builder: (context, state, child) => BottomNavScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/permission-guardian', builder: (_, __) => const PermissionGuardianScreen()),
          GoRoute(
            path: '/threats',
            builder: (_, __) => const ThreatListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ThreatDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/family',
            builder: (_, __) => const FamilyScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    MemberDetailScreen(id: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'protection', builder: (_, __) => const ProtectionSettingsScreen()),
              GoRoute(path: 'sos',        builder: (_, __) => const SOSSettingsScreen()),
            ],
          ),
        ],
      ),

      /* SOS overlay (full-screen, outside shell) */
      GoRoute(path: '/sos',     builder: (_, __) => const SOSScreen()),
      GoRoute(path: '/scan',       builder: (_, __) => const ManualScanScreen()),
      GoRoute(path: '/cleanup',    builder: (_, __) => const WhatsAppCleanupScreen()),
      GoRoute(
        path: '/cleanup/browse',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return MediaBrowseScreen(
            category:    extra['category'] as String,
            label:       extra['label']    as String,
            accentColor: extra['color']    as Color? ?? AppColors.secondary,
          );
        },
      ),
      GoRoute(
        path: '/cleanup/duplicates',
        builder: (_, __) => const DuplicateGroupsScreen(),
      ),
      GoRoute(path: '/otp',        builder: (_, __) => const OtpManagerScreen()),
      GoRoute(path: '/spam-calls', builder: (_, __) => const SpamCallsScreen()),
    ],
  );
}
