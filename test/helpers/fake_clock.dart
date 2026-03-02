import 'package:taplift/utils/clock.dart';

/// A deterministic clock for testing. Set [dateTime] to control what `now()` returns.
class FakeClock implements Clock {
  DateTime dateTime;

  FakeClock(this.dateTime);

  @override
  DateTime now() => dateTime;

  /// Advance by [duration] and return the new time.
  DateTime advance(Duration duration) {
    dateTime = dateTime.add(duration);
    return dateTime;
  }
}
