import ActivityKit
import Foundation

/// ActivityKit attributes for the gym tracking Live Activity
struct GymActivityAttributes: ActivityAttributes {
    /// Static attributes (don't change during the activity)
    let workoutDayName: String
    
    /// Dynamic state that updates during the workout
    struct ContentState: Codable, Hashable {
        let exerciseName: String
        let reps: Int
        let weight: Double
        let weightUnit: String
        let setNumber: Int
        let currentExerciseIndex: Int
        let repTarget: String // e.g. "8–12" or "AMRAP" or ""
        let lastSetSummary: String // e.g. "10×80 kg" or ""
    }
}
