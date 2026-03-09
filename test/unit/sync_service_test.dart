import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taplift/data/services/sync_service.dart';

import '../helpers/test_db.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late TestDbContext ctx;
  late MockSecureStorage storage;
  late String exerciseId;

  setUp(() async {
    ctx = TestDbContext();
    storage = MockSecureStorage();
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    await ctx.seedUser('u1');
    final day = await ctx.workoutRepo.createWorkoutDay('u1', 'Push', 0);
    final exercise = await ctx.exerciseRepo.createExercise(day.id, 'Bench', 0);
    exerciseId = exercise.id;
  });

  tearDown(() => ctx.dispose());

  test('syncSets marks only acceptedSetIds as synced', () async {
    final s1 = await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 8,
      weight: 60.0,
    );
    final s2 = await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 10,
      weight: 62.5,
    );

    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://sync.test/sync');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final ids = (body['sets'] as List).map((e) => (e as Map)['id']).toList();
      expect(ids, containsAll([s1.id, s2.id]));

      return http.Response(
        jsonEncode({
          'success': true,
          'acceptedSetIds': [s1.id],
          'rejectedSetIds': [
            {'id': s2.id, 'reason': 'exercise_not_found'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = SyncService(ctx.setRepo, ctx.workoutRepo, storage, httpClient: client);
    await service.configure('http://sync.test');
    final ok = await service.syncSets('u1');

    expect(ok, isFalse);
    final unsynced = await ctx.setRepo.getUnsyncedSets('u1');
    expect(unsynced, hasLength(1));
    expect(unsynced.first.id, s2.id);
  });

  test('syncSets falls back to old response format', () async {
    await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 8,
      weight: 60.0,
    );
    await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 10,
      weight: 62.5,
    );

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'synced': {'sets': 2},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = SyncService(ctx.setRepo, ctx.workoutRepo, storage, httpClient: client);
    await service.configure('http://sync.test');
    final ok = await service.syncSets('u1');

    expect(ok, isTrue);
    final unsynced = await ctx.setRepo.getUnsyncedSets('u1');
    expect(unsynced, isEmpty);
  });

  test('syncSets uses default production base URL when not configured', () async {
    await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 8,
      weight: 60.0,
    );

    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://100.69.69.19:3001/sync');
      return http.Response(
        jsonEncode({
          'success': true,
          'acceptedSetIds': [],
          'rejectedSetIds': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = SyncService(ctx.setRepo, ctx.workoutRepo, storage, httpClient: client);
    final ok = await service.syncSets('u1');

    expect(ok, isTrue);
    verify(
      () => storage.write(key: 'sync_base_url', value: 'http://100.69.69.19:3001'),
    ).called(1);
  });

  test('syncSets migrates legacy vnext endpoint from 3002 to 3001', () async {
    await ctx.setRepo.logSet(
      exerciseId: exerciseId,
      userId: 'u1',
      reps: 8,
      weight: 60.0,
    );

    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'http://100.69.69.19:3002');

    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://100.69.69.19:3001/sync');
      return http.Response(
        jsonEncode({
          'success': true,
          'acceptedSetIds': [],
          'rejectedSetIds': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = SyncService(ctx.setRepo, ctx.workoutRepo, storage, httpClient: client);
    final ok = await service.syncSets('u1');

    expect(ok, isTrue);
    verify(
      () => storage.write(key: 'sync_base_url', value: 'http://100.69.69.19:3001'),
    ).called(1);
  });
}
