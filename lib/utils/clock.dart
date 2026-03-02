import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple Clock interface to allow injecting a fake time for testing.
abstract class Clock {
  DateTime now();
}

/// The default production implementation using real system time.
class SystemClock implements Clock {
  const SystemClock();
  
  @override
  DateTime now() => DateTime.now();
}

/// A provider that supplies the current Clock implementation.
/// Override this in tests to supply a FakeClock.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
