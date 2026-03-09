import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../repositories/set_repository.dart';
import '../repositories/workout_repository.dart';

/// Syncs local data with the Pi backend when online
class SyncService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'SYNC_BASE_URL',
    defaultValue: 'http://100.69.69.19:3001',
  );
  static const String _legacyVnextBaseUrl = 'http://100.69.69.19:3002';

  final SetRepository _setRepo;
  final WorkoutRepository _workoutRepo;
  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  String? _baseUrl;

  SyncService(
    this._setRepo,
    this._workoutRepo,
    this._storage, {
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<String?> get _authToken => _storage.read(key: 'auth_token');

  Future<void> configure(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    _baseUrl = normalized;
    await _storage.write(key: 'sync_base_url', value: normalized);
  }

  Future<String> _getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl!;

    final stored = await _storage.read(key: 'sync_base_url');
    final migrated = _migrateLegacyBaseUrl(stored);
    final fallback = _normalizeBaseUrl(_defaultBaseUrl);
    _baseUrl = migrated ?? fallback;

    if (stored != _baseUrl) {
      await _storage.write(key: 'sync_base_url', value: _baseUrl!);
    }

    return _baseUrl!;
  }

  Future<String> ensureConfigured() => _getBaseUrl();

  String _normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  String? _migrateLegacyBaseUrl(String? input) {
    if (input == null || input.trim().isEmpty) return null;

    final normalized = _normalizeBaseUrl(input);
    if (normalized == _legacyVnextBaseUrl) {
      return _normalizeBaseUrl(_defaultBaseUrl);
    }
    if (normalized.endsWith(':3002')) {
      return normalized.replaceFirst(RegExp(r':3002$'), ':3001');
    }
    return normalized;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sync unsynced sets to backend
  Future<bool> syncSets(String userId) async {
    final baseUrl = await _getBaseUrl();

    try {
      final unsyncedSets = await _setRepo.getUnsyncedSets(userId);
      if (unsyncedSets.isEmpty) return true;

      final body = jsonEncode({
        'sets': unsyncedSets
            .map(
              (s) => {
                'id': s.id,
                'exerciseId': s.exerciseId,
                'userId': s.userId,
                'setNumber': s.setNumber,
                'reps': s.reps,
                'weight': s.weight,
                'rir': s.rir,
                'source': s.source,
                'externalEventId': s.externalEventId,
                'originSessionId': s.originSessionId,
                'timestamp': s.timestamp.toIso8601String(),
              },
            )
            .toList(),
      });

      final response = await _httpClient.post(
        Uri.parse('$baseUrl/sync'),
        headers: await _headers(),
        body: body,
      );

      if (response.statusCode == 200) {
        final accepted = _extractAcceptedSetIds(response.body);
        if (accepted == null) {
          // Backward-compatible fallback for old servers.
          await _setRepo.markSynced(unsyncedSets.map((s) => s.id).toList());
          return true;
        }

        if (accepted.isNotEmpty) {
          await _setRepo.markSynced(accepted);
        }
        final rejected = _extractRejectedSetIds(response.body);
        return rejected.isEmpty;
      }
      if (response.statusCode == 409) {
        // Partial conflict payloads should still contain accepted ids.
        final accepted = _extractAcceptedSetIds(response.body) ?? const [];
        if (accepted.isNotEmpty) {
          await _setRepo.markSynced(accepted);
          return true;
        }
        return false;
      }
      return false;
    } catch (_) {
      return false; // Offline — that's fine
    }
  }

  List<String>? _extractAcceptedSetIds(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    final acceptedRaw = decoded['acceptedSetIds'];
    if (acceptedRaw is! List) return null;
    return acceptedRaw.map((e) => e.toString()).toList();
  }

  List<String> _extractRejectedSetIds(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];

    final rejectedRaw = decoded['rejectedSetIds'];
    if (rejectedRaw is! List) return const [];
    return rejectedRaw
        .whereType<Map>()
        .map((entry) => entry['id']?.toString())
        .whereType<String>()
        .toList();
  }

  /// Verify token with backend (also creates user if new)
  Future<bool> verifyToken(String firebaseToken) async {
    final baseUrl = await _getBaseUrl();

    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/verify-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseToken',
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pull workout days, exercises and weekday plans from server into local DB.
  /// Uses last-write-wins by updatedAt. Safe to call multiple times (idempotent).
  /// Returns true if data was successfully fetched, false if offline/error.
  Future<bool> pullFromServer(String userId) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _headers();

    try {
      // ── 1. Fetch workout days (includes exercises) ──
      final daysResp = await _httpClient.get(
        Uri.parse('$baseUrl/workout-days'),
        headers: headers,
      );
      if (daysResp.statusCode != 200) return false;

      final daysJson = jsonDecode(daysResp.body) as List<dynamic>;

      for (final dayRaw in daysJson) {
        final day = dayRaw as Map<String, dynamic>;
        final dayId = day['id'] as String;
        final dayName = day['name'] as String;
        final sortIndex = (day['sortIndex'] as num?)?.toInt() ?? 0;
        final updatedAt = day['updatedAt'] != null
            ? DateTime.tryParse(day['updatedAt'] as String)
            : null;

        await _workoutRepo.upsertWorkoutDayFromServer(
          id: dayId,
          userId: userId,
          name: dayName,
          sortIndex: sortIndex,
          updatedAt: updatedAt,
        );

        final exercises = day['exercises'] as List<dynamic>? ?? [];
        for (final exRaw in exercises) {
          final ex = exRaw as Map<String, dynamic>;
          await _workoutRepo.upsertExerciseFromServer(
            id: ex['id'] as String,
            workoutDayId: dayId,
            name: ex['name'] as String,
            sortIndex: (ex['sortIndex'] as num?)?.toInt() ?? 0,
            lastSelectedReps: (ex['lastSelectedReps'] as num?)?.toInt() ?? 8,
            lastSelectedWeight: (ex['lastSelectedWeight'] as num?)?.toDouble() ?? 0.0,
            targetSets: (ex['targetSets'] as num?)?.toInt() ?? 3,
            targetWeight: (ex['targetWeight'] as num?)?.toDouble() ?? 0.0,
            repTargetMin: (ex['repTargetMin'] as num?)?.toInt() ?? 8,
            repTargetMax: (ex['repTargetMax'] as num?)?.toInt() ?? 12,
            updatedAt: ex['updatedAt'] != null
                ? DateTime.tryParse(ex['updatedAt'] as String)
                : null,
          );
        }
      }

      // ── 2. Fetch weekday plans ──
      final plansResp = await _httpClient.get(
        Uri.parse('$baseUrl/weekday-plans'),
        headers: headers,
      );
      if (plansResp.statusCode == 200) {
        final plansJson = jsonDecode(plansResp.body) as List<dynamic>;
        for (final planRaw in plansJson) {
          final plan = planRaw as Map<String, dynamic>;
          final weekday = (plan['weekday'] as num).toInt();
          final workoutDayId = plan['workoutDayId'] as String?;
          await _workoutRepo.setWeekdayPlan(userId, weekday, workoutDayId);
        }
      }

      return true;
    } catch (_) {
      return false; // Offline — silently fail
    }
  }
}
