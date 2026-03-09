import Foundation

/// Shared UserDefaults helper for App Group communication
/// between the main app, widget extension, and AppIntents.
struct SharedState {
    static let appGroupId = "group.com.eliasburk.taplift.shared"
    private static let pendingSetsQueue = DispatchQueue(label: "com.taplift.pendingSets.queue")
    
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    struct Keys {
        static let workoutDayName = "workoutDayName"
        static let currentExerciseId = "currentExerciseId"
        static let currentExerciseName = "currentExerciseName"
        static let currentExerciseIndex = "currentExerciseIndex"
        static let exerciseList = "exerciseList" // JSON string of [{id, name, lastReps, lastWeight}]
        static let currentReps = "currentReps"
        static let currentWeight = "currentWeight"
        static let weightUnit = "weightUnit"
        static let weightStep = "weightStep"
        static let pendingSets = "pendingSets" // JSON array of logged sets from Live Activity
        static let activityId = "activityId"
        static let currentSessionId = "currentSessionId"
        static let lastCompleteSetAtMs = "lastCompleteSetAtMs"
        static let lastBackTapAtMs = "lastBackTapAtMs"
        static let setReps = "setReps" // JSON array of per-set rep counts
        static let completedSetsCount = "completedSetsCount"
    }
    
    // MARK: - Convenience accessors
    
    static var currentReps: Int {
        get { defaults?.integer(forKey: Keys.currentReps) ?? 8 }
        set { defaults?.set(newValue, forKey: Keys.currentReps) }
    }
    
    static var currentWeight: Double {
        get { defaults?.double(forKey: Keys.currentWeight) ?? 20.0 }
        set { defaults?.set(newValue, forKey: Keys.currentWeight) }
    }
    
    static var weightStep: Double {
        defaults?.double(forKey: Keys.weightStep) ?? 2.5
    }
    
    static var weightUnit: String {
        defaults?.string(forKey: Keys.weightUnit) ?? "kg"
    }
    
    static var currentExerciseName: String {
        defaults?.string(forKey: Keys.currentExerciseName) ?? "Exercise"
    }
    
    static var currentExerciseId: String? {
        defaults?.string(forKey: Keys.currentExerciseId)
    }
    
    static var currentExerciseIndex: Int {
        get { defaults?.integer(forKey: Keys.currentExerciseIndex) ?? 0 }
        set { defaults?.set(newValue, forKey: Keys.currentExerciseIndex) }
    }
    
    static var workoutDayName: String {
        defaults?.string(forKey: Keys.workoutDayName) ?? "Workout"
    }

    static var currentSessionId: String {
        get {
            if let id = defaults?.string(forKey: Keys.currentSessionId), !id.isEmpty {
                return id
            }
            let generated = UUID().uuidString
            defaults?.set(generated, forKey: Keys.currentSessionId)
            return generated
        }
        set { defaults?.set(newValue, forKey: Keys.currentSessionId) }
    }

    static var lastCompleteSetAtMs: Int64 {
        get { Int64(defaults?.object(forKey: Keys.lastCompleteSetAtMs) as? Int ?? 0) }
        set { defaults?.set(Int(newValue), forKey: Keys.lastCompleteSetAtMs) }
    }

    static var lastBackTapAtMs: Int64 {
        get { Int64(defaults?.object(forKey: Keys.lastBackTapAtMs) as? Int ?? 0) }
        set { defaults?.set(Int(newValue), forKey: Keys.lastBackTapAtMs) }
    }

    /// Per-set rep counts array. Length should == targetSets of the current exercise.
    static var setReps: [Int] {
        get {
            guard let json = defaults?.string(forKey: Keys.setReps),
                  let data = json.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Int]
            else { return [] }
            return array
        }
        set {
            if let data = try? JSONSerialization.data(withJSONObject: newValue),
               let json = String(data: data, encoding: .utf8) {
                defaults?.set(json, forKey: Keys.setReps)
            }
        }
    }

    /// How many sets have been completed for the current exercise in this session.
    static var completedSetsCount: Int {
        get { defaults?.integer(forKey: Keys.completedSetsCount) ?? 0 }
        set { defaults?.set(newValue, forKey: Keys.completedSetsCount) }
    }

    /// Get targetSets for the current exercise from the exercise list.
    static var currentTargetSets: Int {
        let exercises = self.exercises
        let index = currentExerciseIndex
        guard index < exercises.count else { return 3 }
        return exercises[index]["targetSets"] as? Int ?? 3
    }

    /// Ensure setReps array has the right length for the current exercise.
    /// If switching exercise or first load, re-initialize with default reps.
    static func ensureSetRepsInitialized() {
        let target = currentTargetSets
        var reps = setReps
        if reps.count != target {
            let defaultRep = currentReps
            reps = Array(repeating: defaultRep, count: target)
            setReps = reps
        }
    }
    
    /// Decoded exercise list from JSON
    static var exercises: [[String: Any]] {
        guard let json = defaults?.string(forKey: Keys.exerciseList),
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }
    
    // MARK: - Pending Sets Queue

    private static func decodePendingSetsNoLock() -> [[String: Any]] {
        guard let json = defaults?.string(forKey: Keys.pendingSets),
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }
    
    /// Append a logged set to the pending queue for Flutter to pick up
    static func appendPendingSet(
        exerciseId: String,
        reps: Int,
        weight: Double,
        sessionId: String? = nil
    ) {
        pendingSetsQueue.sync {
            var pending = decodePendingSetsNoLock()
            let now = Date()
            let loggedAtEpochMs = Int64(now.timeIntervalSince1970 * 1000)
            let set: [String: Any] = [
                "eventId": UUID().uuidString,
                "sessionId": sessionId ?? currentSessionId,
                "loggedAtEpochMs": loggedAtEpochMs,
                "schemaVersion": 2,
                "exerciseId": exerciseId,
                "reps": reps,
                "weight": weight,
                "timestamp": ISO8601DateFormatter().string(from: now), // legacy compatibility
                "source": "liveActivity"
            ]
            pending.append(set)
            
            if let data = try? JSONSerialization.data(withJSONObject: pending),
               let json = String(data: data, encoding: .utf8) {
                defaults?.set(json, forKey: Keys.pendingSets)
            }
        }
    }

    static func drainPendingSetsJson() -> String {
        pendingSetsQueue.sync {
            let json = defaults?.string(forKey: Keys.pendingSets) ?? "[]"
            defaults?.removeObject(forKey: Keys.pendingSets)
            return json
        }
    }
    
    static var pendingSets: [[String: Any]] {
        pendingSetsQueue.sync {
            decodePendingSetsNoLock()
        }
    }
}
