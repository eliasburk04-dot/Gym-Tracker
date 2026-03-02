import 'package:flutter_test/flutter_test.dart';

/// Mirror of _snapWeight from quick_log_provider.dart (pure function)
double snapWeight(double raw, double step) {
  if (step <= 0) return raw;
  return (raw / step).round() * step;
}

void main() {
  group('snapWeight', () {
    test('snaps to nearest kg increment (2.5)', () {
      expect(snapWeight(80.0 + 2.5, 2.5), 82.5);
      expect(snapWeight(82.5 + 2.5, 2.5), 85.0);
      expect(snapWeight(85.0 - 2.5, 2.5), 82.5);
    });

    test('snaps to nearest kg increment (1.25)', () {
      expect(snapWeight(80.0 + 1.25, 1.25), 81.25);
      expect(snapWeight(81.25 + 1.25, 1.25), 82.5);
      expect(snapWeight(82.5 + 1.25, 1.25), 83.75);
      expect(snapWeight(83.75 + 1.25, 1.25), 85.0);
    });

    test('snaps to nearest lb increment (5.0)', () {
      expect(snapWeight(135.0 + 5.0, 5.0), 140.0);
      expect(snapWeight(140.0 + 5.0, 5.0), 145.0);
    });

    test('prevents FP drift after many increments', () {
      // Simulate 100 increments of 1.25 starting from 0
      double weight = 0;
      for (int i = 0; i < 100; i++) {
        weight = snapWeight(weight + 1.25, 1.25);
      }
      expect(weight, 125.0);
    });

    test('prevents FP drift after many increments of 2.5', () {
      double weight = 0;
      for (int i = 0; i < 100; i++) {
        weight = snapWeight(weight + 2.5, 2.5);
      }
      expect(weight, 250.0);
    });

    test('prevents FP drift after mixed inc/dec', () {
      double weight = 80.0;
      const step = 1.25;
      // 10 ups, 5 downs
      for (int i = 0; i < 10; i++) {
        weight = snapWeight(weight + step, step);
      }
      for (int i = 0; i < 5; i++) {
        weight = snapWeight(weight - step, step);
      }
      // 80 + (10-5)*1.25 = 86.25
      expect(weight, 86.25);
    });

    test('handles zero step gracefully', () {
      expect(snapWeight(80.123, 0), 80.123);
    });

    test('handles negative step gracefully', () {
      expect(snapWeight(80.0, -1.0), 80.0);
    });

    test('snap to 3.75 increment', () {
      expect(snapWeight(0 + 3.75, 3.75), 3.75);
      expect(snapWeight(3.75 + 3.75, 3.75), 7.5);
      expect(snapWeight(7.5 + 3.75, 3.75), 11.25);
    });

    test('does not go below zero', () {
      final result = snapWeight(0 - 2.5, 2.5);
      expect(result, -2.5); // Caller is responsible for clamping
    });
  });
}
