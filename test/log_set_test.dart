import 'package:flutter_test/flutter_test.dart';

/// Tests for set logging logic.
///
/// When a set is logged, the exercise's lastSelectedReps and
/// lastSelectedWeight must be updated to match the logged values.

class FakeMutableExercise {
  final String id;
  String name;
  int lastSelectedReps;
  double lastSelectedWeight;

  FakeMutableExercise({
    required this.id,
    required this.name,
    required this.lastSelectedReps,
    required this.lastSelectedWeight,
  });
}

class FakeLoggedSet {
  final String id;
  final String exerciseId;
  final int reps;
  final double weight;
  final DateTime timestamp;

  FakeLoggedSet({
    required this.id,
    required this.exerciseId,
    required this.reps,
    required this.weight,
    required this.timestamp,
  });
}

/// Simulates the log-set side effect of updating lastSelected on the exercise.
class FakeSetLogger {
  final List<FakeLoggedSet> sets = [];
  final Map<String, FakeMutableExercise> exercises;

  FakeSetLogger(List<FakeMutableExercise> exList)
      : exercises = {for (final e in exList) e.id: e};

  FakeLoggedSet logSet({
    required String exerciseId,
    required int reps,
    required double weight,
  }) {
    final logged = FakeLoggedSet(
      id: 'set_${sets.length + 1}',
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      timestamp: DateTime.now(),
    );
    sets.add(logged);

    // Side effect: update exercise lastSelected
    final exercise = exercises[exerciseId];
    if (exercise != null) {
      exercise.lastSelectedReps = reps;
      exercise.lastSelectedWeight = weight;
    }

    return logged;
  }
}

void main() {
  group('logSet', () {
    late FakeSetLogger logger;
    late FakeMutableExercise bench;

    setUp(() {
      bench = FakeMutableExercise(
        id: 'e1',
        name: 'Bench Press',
        lastSelectedReps: 8,
        lastSelectedWeight: 60.0,
      );
      logger = FakeSetLogger([bench]);
    });

    test('creates a set with correct values', () {
      final s = logger.logSet(exerciseId: 'e1', reps: 10, weight: 65.0);
      expect(s.exerciseId, 'e1');
      expect(s.reps, 10);
      expect(s.weight, 65.0);
    });

    test('updates exercise lastSelectedReps', () {
      logger.logSet(exerciseId: 'e1', reps: 12, weight: 60.0);
      expect(bench.lastSelectedReps, 12);
    });

    test('updates exercise lastSelectedWeight', () {
      logger.logSet(exerciseId: 'e1', reps: 8, weight: 70.0);
      expect(bench.lastSelectedWeight, 70.0);
    });

    test('multiple sets accumulate', () {
      logger.logSet(exerciseId: 'e1', reps: 8, weight: 60.0);
      logger.logSet(exerciseId: 'e1', reps: 8, weight: 60.0);
      logger.logSet(exerciseId: 'e1', reps: 6, weight: 62.5);
      expect(logger.sets.length, 3);
      expect(bench.lastSelectedReps, 6);
      expect(bench.lastSelectedWeight, 62.5);
    });

    test('last logged values stick on exercise', () {
      logger.logSet(exerciseId: 'e1', reps: 10, weight: 55.0);
      logger.logSet(exerciseId: 'e1', reps: 8, weight: 60.0);
      // The exercise should reflect the LAST log
      expect(bench.lastSelectedReps, 8);
      expect(bench.lastSelectedWeight, 60.0);
    });
  });
}
