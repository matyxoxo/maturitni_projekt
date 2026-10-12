import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/username_screen.dart';
import '../features/onboarding/weight_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rank/rank_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/workout/active_workout_screen.dart';
import '../features/workout/workout_screen.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<void> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

const _authLocations = ['/login', '/signup', '/reset-password'];
const _onboardingLocations = ['/onboarding', '/onboarding-weight'];

final routerProvider = Provider<GoRouter>((ref) {
  final controller = ref.read(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(controller.changes),
    redirect: (context, state) {
      final status = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      switch (status) {
        case AppAuthStatus.loading:
          return location == '/splash' ? null : '/splash';
        case AppAuthStatus.signedOut:
          return _authLocations.contains(location) ? null : '/login';
        case AppAuthStatus.needsUsername:
          return location == '/onboarding' ? null : '/onboarding';
        case AppAuthStatus.needsWeight:
          return location == '/onboarding-weight' ? null : '/onboarding-weight';
        case AppAuthStatus.ready:
          if (_authLocations.contains(location) ||
              _onboardingLocations.contains(location) ||
              location == '/splash') {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const UsernameScreen(),
      ),
      GoRoute(
        path: '/onboarding-weight',
        builder: (_, _) => const WeightScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/workout',
              builder: (_, _) => const WorkoutScreen(),
              routes: [
                GoRoute(
                  path: 'active',
                  builder: (_, _) => const ActiveWorkoutScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/rank', builder: (_, _) => const RankScreen()),
          ]),
        ],
      ),
    ],
  );
});

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AlphaLift',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
