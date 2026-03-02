import 'dart:convert';
import 'package:flutter/services.dart';

/// Bridge between Flutter and native iOS Live Activity via MethodChannel
class LiveActivityService {
  static const _channel = MethodChannel('com.taplift/live_activity');

  /// Start a Live Activity for today's workout
  Future<String?> startActivity({
    required String workoutDayName,
    required String exerciseName,
    required List<Map<String, dynamic>> exercises,
    required int currentExerciseIndex,
    required int reps,
    required double weight,
    required String weightUnit,
    required double weightStep,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('startActivity', {
        'workoutDayName': workoutDayName,
        'exerciseName': exerciseName,
        'exercises': jsonEncode(exercises),
        'currentExerciseIndex': currentExerciseIndex,
        'reps': reps,
        'weight': weight,
        'weightUnit': weightUnit,
        'weightStep': weightStep,
      });
      return result;
    } on PlatformException {
      // Live Activity not supported (simulator, etc.)
      return null;
    }
  }

  /// Update the running Live Activity
  Future<bool> updateActivity({
    required String exerciseName,
    required int currentExerciseIndex,
    required int reps,
    required double weight,
    required int setNumber,
    required int totalSetsLogged,
    String repTarget = '',
    String lastSetSummary = '',
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateActivity', {
        'exerciseName': exerciseName,
        'currentExerciseIndex': currentExerciseIndex,
        'reps': reps,
        'weight': weight,
        'setNumber': setNumber,
        'totalSetsLogged': totalSetsLogged,
        'repTarget': repTarget,
        'lastSetSummary': lastSetSummary,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// End the running Live Activity
  Future<bool> endActivity() async {
    try {
      final result = await _channel.invokeMethod<bool>('endActivity');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get pending sets logged from Live Activity buttons
  /// Returns list of set data maps, then clears the queue on native side
  Future<List<Map<String, dynamic>>> syncPendingSets() async {
    try {
      final result = await _channel.invokeMethod<String>('syncPendingSets');
      if (result == null || result.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(result);
      return decoded.cast<Map<String, dynamic>>();
    } on PlatformException {
      return [];
    }
  }

  /// Get the App Group container path (for shared SQLite if needed)
  Future<String?> getAppGroupPath() async {
    try {
      return await _channel.invokeMethod<String>('getAppGroupPath');
    } on PlatformException {
      return null;
    }
  }

  /// Write current workout state to shared UserDefaults for the widget extension
  Future<void> writeSharedState({
    required String currentExerciseId,
    required String currentExerciseName,
    required int reps,
    required double weight,
    required String weightUnit,
    required double weightStep,
    required List<Map<String, dynamic>> exercises,
    required int currentExerciseIndex,
  }) async {
    try {
      await _channel.invokeMethod('writeSharedState', {
        'currentExerciseId': currentExerciseId,
        'currentExerciseName': currentExerciseName,
        'reps': reps,
        'weight': weight,
        'weightUnit': weightUnit,
        'weightStep': weightStep,
        'exercises': jsonEncode(exercises),
        'currentExerciseIndex': currentExerciseIndex,
      });
    } on PlatformException {
      // Silently fail on non-iOS platforms
    }
  }
}
