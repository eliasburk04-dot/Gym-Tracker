import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';
import '../repositories/set_repository.dart';

/// Syncs local data with the Pi backend when online
class SyncService {
  final AppDatabase _db;
  final SetRepository _setRepo;
  final FlutterSecureStorage _storage;
  String? _baseUrl;

  SyncService(this._db, this._setRepo, this._storage);

  Future<String?> get _authToken => _storage.read(key: 'auth_token');

  Future<void> configure(String baseUrl) async {
    _baseUrl = baseUrl;
    await _storage.write(key: 'sync_base_url', value: baseUrl);
  }

  Future<String?> _getBaseUrl() async {
    _baseUrl ??= await _storage.read(key: 'sync_base_url');
    return _baseUrl;
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
    if (baseUrl == null) return false;

    try {
      final unsyncedSets = await _setRepo.getUnsyncedSets(userId);
      if (unsyncedSets.isEmpty) return true;

      final body = jsonEncode({
        'sets': unsyncedSets
            .map((s) => {
                  'id': s.id,
                  'exerciseId': s.exerciseId,
                  'userId': s.userId,
                  'reps': s.reps,
                  'weight': s.weight,
                  'source': s.source,
                  'timestamp': s.timestamp.toIso8601String(),
                })
            .toList(),
      });

      final response = await http.post(
        Uri.parse('$baseUrl/sync'),
        headers: await _headers(),
        body: body,
      );

      if (response.statusCode == 200) {
        await _setRepo.markSynced(unsyncedSets.map((s) => s.id).toList());
        return true;
      }
      return false;
    } catch (_) {
      return false; // Offline — that's fine
    }
  }

  /// Verify token with backend (also creates user if new)
  Future<bool> verifyToken(String firebaseToken) async {
    final baseUrl = await _getBaseUrl();
    if (baseUrl == null) return false;

    try {
      final response = await http.post(
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
}
