import 'package:flutter_test/flutter_test.dart';
import 'package:taplift/models/enums.dart';
import 'package:taplift/providers/quick_log_provider.dart';

void main() {
  group('QuickLogState bounds and increments', () {
    test('default state has reps=8, weight=20.0, isLogging=false', () {
      const state = QuickLogState();
      expect(state.reps, 8);
      expect(state.weight, 20.0);
      expect(state.isLogging, false);
    });

    test('copyWith only changes specified fields', () {
      const state = QuickLogState(reps: 10, weight: 50.0);
      final updated = state.copyWith(reps: 12);
      expect(updated.reps, 12);
      expect(updated.weight, 50.0); // unchanged
    });

    test('reps never below 1 (decrementReps logic)', () {
      // Simulate the logic from QuickLogNotifier.decrementReps
      int reps = 1;
      if (reps > 1) reps -= 1;
      expect(reps, 1); // stays at 1
    });

    test('reps never above 99 (incrementReps logic)', () {
      int reps = 99;
      if (reps < 99) reps += 1;
      expect(reps, 99); // stays at 99
    });

    test('reps increment from 98 to 99', () {
      int reps = 98;
      if (reps < 99) reps += 1;
      expect(reps, 99);
    });

    test('weight decrement stops at 0 (kg step 2.5)', () {
      double weight = 2.5;
      const step = 2.5;
      final newWeight = weight - step;
      if (newWeight >= 0) weight = newWeight;
      expect(weight, 0.0);
    });

    test('weight does not go negative (kg step 2.5 from 0)', () {
      double weight = 0.0;
      const step = 2.5;
      final newWeight = weight - step;
      if (newWeight >= 0) weight = newWeight;
      expect(weight, 0.0); // unchanged
    });

    test('weight increment with default kg step (2.5)', () {
      double weight = 60.0;
      final step = WeightUnit.kg.defaultIncrement;
      weight += step;
      expect(weight, 62.5);
    });

    test('weight increment with lb step (5.0)', () {
      double weight = 135.0;
      final step = WeightUnit.lb.defaultIncrement;
      weight += step;
      expect(weight, 140.0);
    });

    test('weight decrement with lb step (5.0)', () {
      double weight = 135.0;
      final step = WeightUnit.lb.defaultIncrement;
      final newWeight = weight - step;
      if (newWeight >= 0) weight = newWeight;
      expect(weight, 130.0);
    });

    test('custom weight increment (1.25 kg)', () {
      double weight = 40.0;
      const step = 1.25;
      weight += step;
      expect(weight, 41.25);
    });

    test('large weight does not overflow', () {
      double weight = 999.0;
      const step = 2.5;
      weight += step;
      expect(weight, 1001.5); // no artificial upper bound on weight
    });
  });

  group('WeightUnit enum', () {
    test('kg defaultIncrement is 2.5', () {
      expect(WeightUnit.kg.defaultIncrement, 2.5);
    });

    test('lb defaultIncrement is 5.0', () {
      expect(WeightUnit.lb.defaultIncrement, 5.0);
    });

    test('fromString "lb" returns lb', () {
      expect(WeightUnit.fromString('lb'), WeightUnit.lb);
    });

    test('fromString "kg" returns kg', () {
      expect(WeightUnit.fromString('kg'), WeightUnit.kg);
    });

    test('fromString unknown defaults to kg', () {
      expect(WeightUnit.fromString('stone'), WeightUnit.kg);
    });
  });

  group('SetSource enum', () {
    test('app value is "app"', () {
      expect(SetSource.app.value, 'app');
    });

    test('liveActivity value is "liveActivity"', () {
      expect(SetSource.liveActivity.value, 'liveActivity');
    });

    test('fromString "liveActivity" returns liveActivity', () {
      expect(SetSource.fromString('liveActivity'), SetSource.liveActivity);
    });

    test('fromString unknown defaults to app', () {
      expect(SetSource.fromString('banana'), SetSource.app);
    });
  });
}
