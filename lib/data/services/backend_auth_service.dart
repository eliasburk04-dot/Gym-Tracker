import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthServerProfile {
  const AuthServerProfile({
    required this.id,
    required this.authProvider,
    this.email,
    this.displayName,
    this.weightUnit,
    this.weightIncrement,
    this.createdAt,
  });

  final String id;
  final String authProvider;
  final String? email;
  final String? displayName;
  final String? weightUnit;
  final double? weightIncrement;
  final DateTime? createdAt;

  factory AuthServerProfile.fromJson(Map<String, dynamic> json) {
    return AuthServerProfile(
      id: json['id'] as String,
      authProvider: json['authProvider'] as String? ?? 'unknown',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      weightUnit: json['weightUnit'] as String?,
      weightIncrement: (json['weightIncrement'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class BackendAuthService {
  BackendAuthService({FlutterSecureStorage? storage, http.Client? httpClient})
    : _storage = storage ?? const FlutterSecureStorage(),
      _httpClient = httpClient ?? http.Client();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'SYNC_BASE_URL',
    defaultValue: 'http://100.69.69.19:3001',
  );

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;
  String? _baseUrl;

  Future<void> configure(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    _baseUrl = normalized;
    await _storage.write(key: 'sync_base_url', value: normalized);
  }

  Future<String> getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl!;

    final stored = await _storage.read(key: 'sync_base_url');
    _baseUrl = _normalizeBaseUrl(stored ?? _defaultBaseUrl);
    return _baseUrl!;
  }

  Future<AuthServerProfile> verifyToken(String firebaseToken) async {
    final baseUrl = await getBaseUrl();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/auth/verify-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $firebaseToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response from auth server');
    }

    return AuthServerProfile.fromJson(decoded);
  }

  void dispose() {
    _httpClient.close();
  }

  String _normalizeBaseUrl(String input) {
    return input.trim().replaceAll(RegExp(r'/+$'), '');
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      // Fall through to default error message.
    }

    return 'Auth server verification failed';
  }
}
