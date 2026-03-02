import Foundation

/// Shared UserDefaults helper for App Group communication
/// between the main app, widget extension, and AppIntents.
struct SharedState {
    static let appGroupId = "group.com.taplift.shared"
    
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
    
    /// Decoded exercise list from JSON
    static var exercises: [[String: Any]] {
        guard let json = defaults?.string(forKey: Keys.exerciseList),
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }
    
    // MARK: - Pending Sets Queue
    
    /// Append a logged set to the pending queue for Flutter to pick up
    static func appendPendingSet(exerciseId: String, reps: Int, weight: Double) {
        var pending = pendingSets
        let set: [String: Any] = [
            "exerciseId": exerciseId,
            "reps": reps,
            "weight": weight,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "liveActivity"
        ]
        pending.append(set)
        
        if let data = try? JSONSerialization.data(withJSONObject: pending),
           let json = String(data: data, encoding: .utf8) {
            defaults?.set(json, forKey: Keys.pendingSets)
        }
    }
    
    static var pendingSets: [[String: Any]] {
        guard let json = defaults?.string(forKey: Keys.pendingSets),
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return array
    }
}
