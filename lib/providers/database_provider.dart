import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database/app_database.dart';
import '../data/repositories/workout_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/set_repository.dart';
import '../data/services/auth_service.dart';
import '../data/services/live_activity_service.dart';
import '../data/services/sync_service.dart';

// ── Core singletons ──

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final liveActivityServiceProvider = Provider<LiveActivityService>((ref) {
  return LiveActivityService();
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// ── Repositories ──

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(databaseProvider));
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(databaseProvider));
});

final setRepositoryProvider = Provider<SetRepository>((ref) {
  return SetRepository(ref.watch(databaseProvider));
});

// ── Sync ──

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(setRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
    ref.watch(secureStorageProvider),
  );
});
