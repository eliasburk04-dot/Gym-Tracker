import 'package:flutter_test/flutter_test.dart';

/// Tests for the exercise inference algorithm.
///
/// The algorithm determines which exercise the user is currently performing:
///   1. First exercise with 0 sets logged today → that one
///   2. If all have sets, pick the one with the most recent set
///   3. Fallback: first exercise in the list

class FakeExercise {
  final String id;
  final String name;
  final int sortIndex;
  FakeExercise({required this.id, required this.name, required this.sortIndex});
}

class FakeSet {
  final String exerciseId;
  final DateTime timestamp;
  FakeSet({required this.exerciseId, required this.timestamp});
}

/// Pure function that mirrors inferredCurrentExerciseProvider logic.
FakeExercise? inferCurrentExercise({
  required List<FakeExercise> exercises,
  required List<FakeSet> todaySets,
}) {
  if (exercises.isEmpty) return null;

  // Count sets per exercise
  final setCountByExercise = <String, int>{};
  for (final s in todaySets) {
    setCountByExercise[s.exerciseId] = (setCountByExercise[s.exerciseId] ?? 0) + 1;
  }

  // 1. First exercise with zero sets today
  final sorted = [...exercises]..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  for (final ex in sorted) {
    if ((setCountByExercise[ex.id] ?? 0) == 0) {
      return ex;
    }
  }

  // 2. Exercise with the most recent set
  if (todaySets.isNotEmpty) {
    final newest = todaySets.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    return exercises.where((e) => e.id == newest.exerciseId).firstOrNull ?? exercises.first;
  }

  // 3. Fallback
  return sorted.first;
}

void main() {
  final bench = FakeExercise(id: 'e1', name: 'Bench Press', sortIndex: 0);
  final ohp = FakeExercise(id: 'e2', name: 'Overhead Press', sortIndex: 1);
  final flyes = FakeExercise(id: 'e3', name: 'Flyes', sortIndex: 2);
  final exercises = [bench, ohp, flyes];

  group('inferCurrentExercise', () {
    test('empty exercise list returns null', () {
      expect(inferCurrentExercise(exercises: [], todaySets: []), isNull);
    });

    test('no sets logged → returns first exercise', () {
      final result = inferCurrentExercise(exercises: exercises, todaySets: []);
      expect(result!.id, 'e1');
    });

    test('first exercise has sets, second does not → returns second', () {
      final sets = [
        FakeSet(exerciseId: 'e1', timestamp: DateTime(2025, 1, 1, 10, 0)),
      ];
      final result = inferCurrentExercise(exercises: exercises, todaySets: sets);
      expect(result!.id, 'e2');
    });

    test('all exercises have sets → returns most recent', () {
      final sets = [
        FakeSet(exerciseId: 'e1', timestamp: DateTime(2025, 1, 1, 10, 0)),
        FakeSet(exerciseId: 'e2', timestamp: DateTime(2025, 1, 1, 10, 5)),
        FakeSet(exerciseId: 'e3', timestamp: DateTime(2025, 1, 1, 10, 2)),
      ];
      final result = inferCurrentExercise(exercises: exercises, todaySets: sets);
      expect(result!.id, 'e2'); // most recent
    });

    test('respects sort order for first-with-zero', () {
      // Flyes (sortIndex 2) has no sets, bench (0) has a set, ohp (1) has a set
      final sets = [
        FakeSet(exerciseId: 'e1', timestamp: DateTime(2025, 1, 1, 10, 0)),
        FakeSet(exerciseId: 'e2', timestamp: DateTime(2025, 1, 1, 10, 5)),
      ];
      final result = inferCurrentExercise(exercises: exercises, todaySets: sets);
      expect(result!.id, 'e3'); // flyes is first with 0 sets
    });
  });
}
