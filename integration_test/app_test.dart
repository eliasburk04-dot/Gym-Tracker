import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taplift/data/database/app_database.dart';
import 'package:taplift/data/repositories/exercise_repository.dart';
import 'package:taplift/data/repositories/set_repository.dart';
import 'package:taplift/data/repositories/workout_repository.dart';
import 'package:taplift/data/services/live_activity_service.dart';
import 'package:taplift/providers/auth_provider.dart';
import 'package:taplift/providers/database_provider.dart';
import 'package:taplift/routing/app_router.dart';
import 'package:taplift/utils/clock.dart';
import 'package:taplift/views/today/today_screen.dart';

// ─── Fake clock for controlling "today" ───────────────────────────────────────

class _IntegrationClock implements Clock {
  DateTime _now;
  _IntegrationClock(this._now);

  @override
  DateTime now() => _now;

  void setNow(DateTime value) => _now = value;
}

// ─── Stub LiveActivityService (no real native calls) ──────────────────────────

class _StubLiveActivityService extends LiveActivityService {
  final List<String> calls = [];

  @override
  Future<String?> startActivity({
    required String workoutDayName,
    required String exerciseName,
    required List<Map<String, dynamic>> exercises,
    required int currentExerciseIndex,
    required int reps,
    required double weight,
    required String weightUnit,
    required double weightStep,
  }) async {
    calls.add('startActivity');
    return 'fake-activity-id';
  }

  @override
  Future<bool> updateActivity({
    required String exerciseName,
    required int currentExerciseIndex,
    required int reps,
    required double weight,
    required int setNumber,
    required int totalSetsLogged,
    String repTarget = '',
    String lastSetSummary = '',
  }) async {
    calls.add('updateActivity');
    return true;
  }

  @override
  Future<bool> endActivity() async {
    calls.add('endActivity');
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> syncPendingSets() async {
    calls.add('syncPendingSets');
    return [];
  }

  @override
  Future<void> writeSharedState({
    required String currentExerciseId,
    required String currentExerciseName,
    required int reps,
    required double weight,
    required String weightUnit,
    required double weightStep,
    required List<Map<String, dynamic>> exercises,
    required int currentExerciseIndex,
    String? currentSessionId,
  }) async {
    calls.add('writeSharedState');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ExerciseRepository exerciseRepo;
  late SetRepository setRepo;
  late _IntegrationClock clock;
  late _StubLiveActivityService liveService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    exerciseRepo = ExerciseRepository(db);
    setRepo = SetRepository(db);
    clock = _IntegrationClock(DateTime(2026, 3, 2, 8, 0)); // Monday
    liveService = _StubLiveActivityService();
  });

  tearDown(() async {
    await db.close();
  });

  /// Build an app shell that bypasses auth and goes straight to TodayScreen.
  Widget buildTestApp({required String userId}) {
    final testRouter = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        workoutRepositoryProvider.overrideWithValue(workoutRepo),
        exerciseRepositoryProvider.overrideWithValue(exerciseRepo),
        setRepositoryProvider.overrideWithValue(setRepo),
        clockProvider.overrideWithValue(clock),
        liveActivityServiceProvider.overrideWithValue(liveService),
        currentUserIdProvider.overrideWithValue(userId),
        routerProvider.overrideWithValue(testRouter),
      ],
      child: CupertinoApp.router(routerConfig: testRouter),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Widget integration tests (require device/simulator)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Full workout flow', () {
    testWidgets('seed workout → view exercises on TodayScreen', (tester) async {
      const userId = 'integration-user-1';

      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('int@test.com'),
              authProvider: 'email',
            ),
          );
      await workoutRepo.seedDefaultWorkouts(userId);
      final days = await workoutRepo.getAllWorkoutDays(userId);
      final pushDay = days.firstWhere((d) => d.name == 'Push');
      await workoutRepo.setWeekdayPlan(userId, 1, pushDay.id);
      await exerciseRepo.createExercise(pushDay.id, 'Bench Press', 0);
      await exerciseRepo.createExercise(pushDay.id, 'Overhead Press', 1);

      await tester.pumpWidget(buildTestApp(userId: userId));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Workout day title
      expect(find.text('Push'), findsOneWidget);

      // Exercise names visible
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('Overhead Press'), findsWidgets);
    });

    testWidgets('rest day shows empty state when no mapping', (tester) async {
      const userId = 'integration-user-2';

      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('rest@test.com'),
              authProvider: 'email',
            ),
          );
      // No weekday mapping → rest day
      await tester.pumpWidget(buildTestApp(userId: userId));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Rest Day'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Data-layer integration tests (no widget needed)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Data layer round-trip', () {
    test('log set → query today sets → verify fields', () async {
      const userId = 'roundtrip-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('rt@test.com'),
              authProvider: 'email',
            ),
          );
      final day = await workoutRepo.createWorkoutDay(userId, 'Legs', 0);
      final ex = await exerciseRepo.createExercise(day.id, 'Squat', 0);

      await setRepo.logSet(
        exerciseId: ex.id,
        userId: userId,
        reps: 5,
        weight: 100.0,
        source: 'app',
      );

      final todaySets = await setRepo.getTodaySets(ex.id);
      expect(todaySets, hasLength(1));
      expect(todaySets.first.reps, 5);
      expect(todaySets.first.weight, 100.0);
      expect(todaySets.first.source, 'app');
    });

    test('exercise inference picks first with zero sets', () async {
      const userId = 'inference-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('inf@test.com'),
              authProvider: 'email',
            ),
          );
      final day = await workoutRepo.createWorkoutDay(userId, 'Pull', 0);
      final e1 = await exerciseRepo.createExercise(day.id, 'Rows', 0);
      final e2 = await exerciseRepo.createExercise(day.id, 'Curls', 1);

      await setRepo.logSet(
        exerciseId: e1.id,
        userId: userId,
        reps: 8,
        weight: 60.0,
      );

      final todaySetsForE2 = await setRepo.getTodaySets(e2.id);
      expect(todaySetsForE2, isEmpty);

      final exercises = await exerciseRepo.getExercisesForDay(day.id);
      Exercise? inferred;
      for (final ex in exercises) {
        final sets = await setRepo.getTodaySets(ex.id);
        if (sets.isEmpty) {
          inferred = ex;
          break;
        }
      }
      expect(inferred?.id, e2.id);
    });

    test('mark sets synced → unsynced count drops to zero', () async {
      const userId = 'sync-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('sync@test.com'),
              authProvider: 'email',
            ),
          );
      final day = await workoutRepo.createWorkoutDay(userId, 'Push', 0);
      final ex = await exerciseRepo.createExercise(day.id, 'Bench', 0);

      await setRepo.logSet(
        exerciseId: ex.id,
        userId: userId,
        reps: 10,
        weight: 80.0,
      );

      var unsynced = await setRepo.getUnsyncedSets(userId);
      expect(unsynced, hasLength(1));

      await setRepo.markSynced(unsynced.map((s) => s.id).toList());

      unsynced = await setRepo.getUnsyncedSets(userId);
      expect(unsynced, isEmpty);
    });

    test('multiple offline sets are all retrievable', () async {
      const userId = 'offline-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('off@test.com'),
              authProvider: 'email',
            ),
          );
      final day = await workoutRepo.createWorkoutDay(userId, 'Push', 0);
      final ex = await exerciseRepo.createExercise(day.id, 'Dips', 0);

      for (var i = 0; i < 3; i++) {
        await setRepo.logSet(
          exerciseId: ex.id,
          userId: userId,
          reps: 10 + i,
          weight: 0,
          source: 'app',
        );
      }

      final allSets = await setRepo.getTodaySets(ex.id);
      expect(allSets, hasLength(3));

      final unsynced = await setRepo.getUnsyncedSets(userId);
      expect(unsynced, hasLength(3));
    });

    test('seed default workouts creates PPL days', () async {
      const userId = 'seed-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('seed@test.com'),
              authProvider: 'email',
            ),
          );
      await workoutRepo.seedDefaultWorkouts(userId);
      final days = await workoutRepo.getAllWorkoutDays(userId);

      expect(days.length, greaterThanOrEqualTo(3));
      final names = days.map((d) => d.name).toSet();
      expect(names, containsAll(['Push', 'Pull', 'Legs']));
    });

    test('exercise reorder persists', () async {
      const userId = 'reorder-user';
      await db
          .into(db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: userId,
              email: const Value('reo@test.com'),
              authProvider: 'email',
            ),
          );
      final day = await workoutRepo.createWorkoutDay(userId, 'Full', 0);
      final e1 = await exerciseRepo.createExercise(day.id, 'A', 0);
      final e2 = await exerciseRepo.createExercise(day.id, 'B', 1);
      final e3 = await exerciseRepo.createExercise(day.id, 'C', 2);

      await exerciseRepo.reorderExercises([e3.id, e1.id, e2.id]);

      final exercises = await exerciseRepo.getExercisesForDay(day.id);
      expect(exercises[0].name, 'C');
      expect(exercises[1].name, 'A');
      expect(exercises[2].name, 'B');
    });
  });
}
