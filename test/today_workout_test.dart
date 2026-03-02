import 'package:flutter_test/flutter_test.dart';

/// Tests for weekday → workout resolution logic.
///
/// Since the provider depends on the database, we test the *mapping logic*
/// directly: given a weekday int (1=Mon…7=Sun) and a list of WeekdayPlan
/// rows, we should pick the correct WorkoutDay (or null for rest).

// Minimal data classes to avoid importing Drift-generated code in unit tests.
class FakeWeekdayPlan {
  final int weekday;
  final String? workoutDayId;
  FakeWeekdayPlan({required this.weekday, this.workoutDayId});
}

class FakeWorkoutDay {
  final String id;
  final String name;
  FakeWorkoutDay({required this.id, required this.name});
}

/// Pure function that mirrors todayWorkoutProvider logic.
FakeWorkoutDay? resolveWorkout({
  required int weekday,
  required List<FakeWeekdayPlan> plans,
  required List<FakeWorkoutDay> days,
}) {
  final plan = plans.where((p) => p.weekday == weekday).firstOrNull;
  if (plan == null || plan.workoutDayId == null) return null;
  return days.where((d) => d.id == plan.workoutDayId).firstOrNull;
}

void main() {
  final push = FakeWorkoutDay(id: 'd1', name: 'Push');
  final pull = FakeWorkoutDay(id: 'd2', name: 'Pull');
  final legs = FakeWorkoutDay(id: 'd3', name: 'Legs');
  final days = [push, pull, legs];

  final plans = [
    FakeWeekdayPlan(weekday: 1, workoutDayId: 'd1'), // Mon → Push
    FakeWeekdayPlan(weekday: 2, workoutDayId: 'd2'), // Tue → Pull
    FakeWeekdayPlan(weekday: 3, workoutDayId: 'd3'), // Wed → Legs
    FakeWeekdayPlan(weekday: 4, workoutDayId: 'd1'), // Thu → Push
    FakeWeekdayPlan(weekday: 5, workoutDayId: 'd2'), // Fri → Pull
    FakeWeekdayPlan(weekday: 6, workoutDayId: 'd3'), // Sat → Legs
    FakeWeekdayPlan(weekday: 7, workoutDayId: null),  // Sun → Rest
  ];

  group('resolveWorkout', () {
    test('Monday resolves to Push', () {
      final result = resolveWorkout(weekday: 1, plans: plans, days: days);
      expect(result, isNotNull);
      expect(result!.name, 'Push');
    });

    test('Tuesday resolves to Pull', () {
      final result = resolveWorkout(weekday: 2, plans: plans, days: days);
      expect(result, isNotNull);
      expect(result!.name, 'Pull');
    });

    test('Wednesday resolves to Legs', () {
      final result = resolveWorkout(weekday: 3, plans: plans, days: days);
      expect(result, isNotNull);
      expect(result!.name, 'Legs');
    });

    test('Sunday is rest day (null)', () {
      final result = resolveWorkout(weekday: 7, plans: plans, days: days);
      expect(result, isNull);
    });

    test('Missing plan for weekday returns null', () {
      final partial = plans.where((p) => p.weekday != 4).toList();
      final result = resolveWorkout(weekday: 4, plans: partial, days: days);
      expect(result, isNull);
    });

    test('Plan with invalid workoutDayId returns null', () {
      final bad = [FakeWeekdayPlan(weekday: 1, workoutDayId: 'nonexistent')];
      final result = resolveWorkout(weekday: 1, plans: bad, days: days);
      expect(result, isNull);
    });
  });
}
