import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/session_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/caregiver_signin_screen.dart';
import 'screens/caregiver_signup_screen.dart';
import 'screens/child_join_screen.dart';
import 'screens/child_screen.dart';
import 'screens/child_settings_screen.dart';
import 'screens/child_customization_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/manage_symbols_screen.dart';
import 'screens/manage_rooms_screen.dart';
import 'screens/room_calibration_screen.dart';
import 'screens/find_child_screen.dart';
import 'screens/diary_screen.dart';
import 'theme/app_theme.dart';

/// App router — 13+ named routes with auth AND role-based redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  // Routes that require no auth
  const publicRoutes = ['/', '/onboarding', '/role-select',
      '/caregiver-signin', '/caregiver-signup', '/child-join'];

  // Routes only for caregivers
  const caregiverRoutes = ['/dashboard', '/requests', '/analytics',
      '/manage-symbols', '/manage-rooms', '/find-child', '/diary', '/caregiver-room-calibration'];

  // Routes only for children
  const childRoutes = ['/child', '/child-settings', '/child-customize', '/room-calibration'];

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.uri.path;

      if (!session.isReady) return null;

      // Public routes: always allow
      if (publicRoutes.contains(path)) return null;

      // Not logged in → role select
      if (!session.isLoggedIn) return '/role-select';

      // Role-based guard: prevent cross-role access
      if (session.isCaregiver && childRoutes.contains(path)) {
        return '/dashboard'; // Caregivers can't access child screens
      }
      if (session.isChild && caregiverRoutes.contains(path)) {
        return '/child'; // Children can't access caregiver screens
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.warning),
            const SizedBox(height: 16),
            const Text('Page Not Found',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/role-select'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/role-select', builder: (_, __) => const RoleSelectScreen()),
      GoRoute(path: '/caregiver-signin', builder: (_, __) => const CaregiverSigninScreen()),
      GoRoute(path: '/caregiver-signup', builder: (_, __) => const CaregiverSignupScreen()),
      GoRoute(path: '/child-join', builder: (_, __) => const ChildJoinScreen()),
      GoRoute(path: '/child', builder: (_, __) => const ChildScreen()),
      GoRoute(path: '/child-settings', builder: (_, __) => const ChildSettingsScreen()),
      GoRoute(path: '/child-customize', builder: (_, __) => const ChildCustomizationScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/requests', builder: (_, __) => const RequestsScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/manage-symbols', builder: (_, __) => const ManageSymbolsScreen()),
      GoRoute(path: '/manage-rooms', builder: (_, __) => const ManageRoomsScreen()),
      GoRoute(path: '/caregiver-room-calibration', builder: (_, __) => const RoomCalibrationScreen()),
      GoRoute(path: '/room-calibration', builder: (_, __) => const RoomCalibrationScreen()),
      GoRoute(path: '/find-child', builder: (_, __) => const FindChildScreen()),
      GoRoute(path: '/diary', builder: (_, __) => const DiaryScreen()),
    ],
  );
});
