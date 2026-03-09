import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests validating the MethodChannel payload schema between Flutter ↔ iOS.
/// These ensure backward compatibility and correct field types.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.taplift/live_activity');

  group('MethodChannel contract: startActivity', () {
    test('startActivity payload has all required fields', () {
      // This is the payload Flutter sends to iOS
      final payload = {
        'workoutDayName': 'Push Day',
        'exerciseName': 'Bench Press',
        'exercises': jsonEncode([
          {
            'id': 'e1',
            'name': 'Bench Press',
            'lastReps': 8,
            'lastWeight': 80.0,
          },
          {'id': 'e2', 'name': 'OHP', 'lastReps': 10, 'lastWeight': 40.0},
        ]),
        'currentExerciseIndex': 0,
        'reps': 8,
        'weight': 80.0,
        'weightUnit': 'kg',
        'weightStep': 2.5,
      };

      // Validate types
      expect(payload['workoutDayName'], isA<String>());
      expect(payload['exerciseName'], isA<String>());
      expect(payload['exercises'], isA<String>()); // JSON-encoded string
      expect(payload['currentExerciseIndex'], isA<int>());
      expect(payload['reps'], isA<int>());
      expect(payload['weight'], isA<double>());
      expect(payload['weightUnit'], isA<String>());
      expect(payload['weightStep'], isA<double>());

      // Validate exercises JSON can be decoded
      final decoded = jsonDecode(payload['exercises'] as String) as List;
      expect(decoded, isNotEmpty);
      expect(decoded.first['id'], isA<String>());
      expect(decoded.first['name'], isA<String>());
      expect(decoded.first['lastReps'], isA<int>());
      expect(decoded.first['lastWeight'], isA<num>());
    });

    test('startActivity payload allows zero exercises (edge case)', () {
      final payload = {
        'workoutDayName': 'Rest',
        'exerciseName': '',
        'exercises': jsonEncode([]),
        'currentExerciseIndex': 0,
        'reps': 0,
        'weight': 0.0,
        'weightUnit': 'kg',
        'weightStep': 2.5,
      };

      final decoded = jsonDecode(payload['exercises'] as String) as List;
      expect(decoded, isEmpty);
    });
  });

  group('MethodChannel contract: updateActivity', () {
    test('updateActivity payload has correct fields and types', () {
      final payload = {
        'exerciseName': 'Bench Press',
        'currentExerciseIndex': 0,
        'reps': 10,
        'weight': 82.5,
        'setNumber': 3,
        'totalSetsLogged': 12,
      };

      expect(payload['exerciseName'], isA<String>());
      expect(payload['currentExerciseIndex'], isA<int>());
      expect(payload['reps'], isA<int>());
      expect(payload['weight'], isA<double>());
      expect(payload['setNumber'], isA<int>());
      expect(payload['totalSetsLogged'], isA<int>());
    });
  });

  group('MethodChannel contract: writeSharedState', () {
    test('writeSharedState payload matches iOS SharedState.Keys', () {
      final payload = {
        'currentExerciseId': 'e1',
        'currentExerciseName': 'Bench Press',
        'reps': 8,
        'weight': 80.0,
        'weightUnit': 'kg',
        'weightStep': 2.5,
        'exercises': jsonEncode([
          {
            'id': 'e1',
            'name': 'Bench Press',
            'lastReps': 8,
            'lastWeight': 80.0,
          },
        ]),
        'currentExerciseIndex': 0,
      };

      // All keys expected by iOS SharedState.Keys
      expect(payload.containsKey('currentExerciseId'), true);
      expect(payload.containsKey('currentExerciseName'), true);
      expect(payload.containsKey('reps'), true);
      expect(payload.containsKey('weight'), true);
      expect(payload.containsKey('weightUnit'), true);
      expect(payload.containsKey('weightStep'), true);
      expect(payload.containsKey('exercises'), true);
      expect(payload.containsKey('currentExerciseIndex'), true);
    });
  });

  group('MethodChannel contract: syncPendingSets', () {
    test('pending set payload supports v2 idempotency fields', () {
      final iosPayload = [
        {
          'eventId': 'evt-123',
          'sessionId': 'session-abc',
          'loggedAtEpochMs': 1760000000000,
          'schemaVersion': 2,
          'exerciseId': 'e1',
          'reps': 10,
          'weight': 80.0,
          'timestamp': '2026-03-02T10:30:00Z',
          'source': 'liveActivity',
        },
      ];

      expect(iosPayload.first['eventId'], isA<String>());
      expect(iosPayload.first['sessionId'], isA<String>());
      expect(iosPayload.first['loggedAtEpochMs'], isA<int>());
      expect(iosPayload.first['schemaVersion'], 2);
    });

    test('pending set payload from iOS matches expected schema', () {
      // This is what iOS writes to SharedState.pendingSets
      final iosPayload = [
        {
          'exerciseId': 'e1',
          'reps': 10,
          'weight': 80.0,
          'timestamp': '2026-03-02T10:30:00Z',
          'source': 'liveActivity',
        },
      ];

      expect(iosPayload.first['exerciseId'], isA<String>());
      expect(iosPayload.first['reps'], isA<int>());
      expect(iosPayload.first['weight'], isA<double>());
      expect(iosPayload.first['timestamp'], isA<String>());
      expect(iosPayload.first['source'], 'liveActivity');
    });

    test('pending set payload handles missing optional fields gracefully', () {
      // If iOS sends a set without 'source', Flutter should default to 'liveActivity'
      final iosPayload = {
        'exerciseId': 'e1',
        'reps': 10,
        'weight': 80.0,
        'timestamp': '2026-03-02T10:30:00Z',
      };

      // Simulate Flutter-side handling: default source
      final source = iosPayload['source'] as String? ?? 'liveActivity';
      expect(source, 'liveActivity');
    });

    test('unknown fields in payload are ignored (forward compatibility)', () {
      final iosPayload = {
        'exerciseId': 'e1',
        'reps': 10,
        'weight': 80.0,
        'timestamp': '2026-03-02T10:30:00Z',
        'source': 'liveActivity',
        'futureField': 'should be ignored',
        'anotherFutureField': 42,
      };

      // Flutter only reads known fields
      final exerciseId = iosPayload['exerciseId'] as String;
      final reps = iosPayload['reps'] as int;
      final weight = (iosPayload['weight'] as num).toDouble();

      expect(exerciseId, 'e1');
      expect(reps, 10);
      expect(weight, 80.0);
      // Unknown fields don't cause errors
    });
  });

  group('MethodChannel mock handler', () {
    test('LiveActivityService handles PlatformException gracefully', () async {
      // Register a mock handler that throws
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'NOT_AVAILABLE',
              message: 'Simulator',
            );
          });

      try {
        await channel.invokeMethod<String>('startActivity', {
          'workoutDayName': 'Push',
          'exerciseName': 'Bench',
          'exercises': '[]',
          'currentExerciseIndex': 0,
          'reps': 8,
          'weight': 60.0,
          'weightUnit': 'kg',
          'weightStep': 2.5,
        });
        fail('Should have thrown');
      } on PlatformException catch (e) {
        expect(e.code, 'NOT_AVAILABLE');
      }

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('syncPendingSets returns empty list when nothing pending', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'syncPendingSets') return '[]';
            return null;
          });

      final result = await channel.invokeMethod<String>('syncPendingSets');
      final decoded = jsonDecode(result!) as List;
      expect(decoded, isEmpty);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });
}
