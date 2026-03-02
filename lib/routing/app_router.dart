import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../views/onboarding/sign_in_screen.dart';
import '../views/onboarding/setup_workout_screen.dart';
import '../views/today/today_screen.dart';
import '../views/settings/settings_screen.dart';
import '../views/settings/workout_days_editor.dart';
import '../views/settings/exercises_editor.dart';
import '../views/settings/weekday_mapping_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/today',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn =
          authState.whenOrNull(data: (user) => user != null) ?? false;
      final isSignInRoute = state.matchedLocation == '/signin';

      if (!isLoggedIn && !isSignInRoute) return '/signin';
      if (isLoggedIn && isSignInRoute) return '/today';
      return null;
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupWorkoutScreen(),
      ),
      GoRoute(
        path: '/today',
        builder: (context, state) => const TodayScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/workout-days',
        builder: (context, state) => const WorkoutDaysEditor(),
      ),
      GoRoute(
        path: '/settings/exercises/:dayId',
        builder: (context, state) => ExercisesEditor(
          workoutDayId: state.pathParameters['dayId']!,
        ),
      ),
      GoRoute(
        path: '/settings/weekday-mapping',
        builder: (context, state) => const WeekdayMappingScreen(),
      ),
    ],
  );
});
