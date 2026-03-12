import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/auth_service.dart';
import '../data/services/backend_auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final backendAuthServiceProvider = Provider<BackendAuthService>((ref) {
  final service = BackendAuthService();
  ref.onDispose(service.dispose);
  return service;
});

/// Streams Firebase Auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull;
});

/// Current user ID (convenience)
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});
