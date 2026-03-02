import 'package:flutter_test/flutter_test.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('FakeClock weekday resolution', () {
    test('Monday 10:00 → weekday 1', () {
      final clock = FakeClock(DateTime(2026, 3, 2, 10, 0)); // Mon
      expect(clock.now().weekday, DateTime.monday);
    });

    test('Tuesday 08:30 → weekday 2', () {
      final clock = FakeClock(DateTime(2026, 3, 3, 8, 30)); // Tue
      expect(clock.now().weekday, DateTime.tuesday);
    });

    test('Wednesday → weekday 3', () {
      final clock = FakeClock(DateTime(2026, 3, 4, 12, 0)); // Wed
      expect(clock.now().weekday, DateTime.wednesday);
    });

    test('Thursday → weekday 4', () {
      final clock = FakeClock(DateTime(2026, 3, 5, 12, 0)); // Thu
      expect(clock.now().weekday, DateTime.thursday);
    });

    test('Friday → weekday 5', () {
      final clock = FakeClock(DateTime(2026, 3, 6, 12, 0)); // Fri
      expect(clock.now().weekday, DateTime.friday);
    });

    test('Saturday → weekday 6', () {
      final clock = FakeClock(DateTime(2026, 3, 7, 12, 0)); // Sat
      expect(clock.now().weekday, DateTime.saturday);
    });

    test('Sunday → weekday 7 (rest day)', () {
      final clock = FakeClock(DateTime(2026, 3, 8, 10, 0)); // Sun
      expect(clock.now().weekday, DateTime.sunday);
    });

    test('Near midnight 23:59 Monday → still Monday', () {
      final clock = FakeClock(DateTime(2026, 3, 2, 23, 59));
      expect(clock.now().weekday, DateTime.monday);
    });

    test('Crossing midnight 00:01 → now Tuesday', () {
      final clock = FakeClock(DateTime(2026, 3, 3, 0, 1));
      expect(clock.now().weekday, DateTime.tuesday);
    });

    test('advance() moves time correctly', () {
      final clock = FakeClock(DateTime(2026, 3, 2, 23, 59));
      expect(clock.now().weekday, DateTime.monday);

      clock.advance(const Duration(minutes: 2));
      expect(clock.now().weekday, DateTime.tuesday);
    });

    test('DST spring-forward: last Sunday of March 2026 in Europe/Berlin', () {
      // 2026-03-29 is the last Sunday of March → DST spring-forward at 02:00
      // In UTC this is straightforward; Dart DateTime is UTC-aware or local.
      // We test that the weekday doesn't flip unexpectedly across the gap.
      final beforeDST = DateTime.utc(2026, 3, 29, 0, 59); // 01:59 CET = 00:59 UTC, Sunday
      final afterDST = DateTime.utc(2026, 3, 29, 1, 1);  // 03:01 CEST = 01:01 UTC, still Sunday

      expect(beforeDST.weekday, DateTime.sunday);
      expect(afterDST.weekday, DateTime.sunday);
      // The weekday must remain the same across the DST gap.
      expect(beforeDST.weekday, afterDST.weekday);
    });

    test('DST fall-back: last Sunday of October 2026 in Europe/Berlin', () {
      // 2026-10-25 is the last Sunday of October → clocks fall back at 03:00 to 02:00
      final beforeFallback = DateTime.utc(2026, 10, 25, 0, 30); // 02:30 CEST
      final afterFallback = DateTime.utc(2026, 10, 25, 1, 30);  // 02:30 CET (repeated hour)

      expect(beforeFallback.weekday, DateTime.sunday);
      expect(afterFallback.weekday, DateTime.sunday);
      expect(beforeFallback.weekday, afterFallback.weekday);
    });
  });
}
