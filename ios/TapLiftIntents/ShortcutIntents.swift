import AppIntents
import ActivityKit

/// App Intent exposed to Shortcuts — triggered by Back Tap.
/// Starts or updates the Live Activity for today's workout.
/// Returns plain IntentResult (no dialog) so the Live Activity is the only UI.
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start TapLift Workout"
    static var description: IntentDescription = "Start tracking your workout with a Live Activity"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        // Back-tap cooldown (1200ms)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if nowMs - SharedState.lastBackTapAtMs < 1200 {
            return .result()
        }
        SharedState.lastBackTapAtMs = nowMs

        // Read workout state from shared UserDefaults
        let exercises = SharedState.exercises
        guard !exercises.isEmpty else {
            return .result()
        }
        
        // If a Live Activity is already running — just update it
        if !Activity<GymActivityAttributes>.activities.isEmpty {
            SharedState.ensureSetRepsInitialized()
            await updateExistingActivity()
            return .result()
        }
        
        // Start a new Live Activity
        SharedState.currentSessionId = UUID().uuidString
        SharedState.completedSetsCount = 0
        SharedState.ensureSetRepsInitialized()
        
        let workoutDayName = SharedState.workoutDayName
        let index = SharedState.currentExerciseIndex
        let exerciseName = SharedState.currentExerciseName
        let reps = SharedState.currentReps
        let weight = SharedState.currentWeight
        let unit = SharedState.weightUnit
        let targetSets = SharedState.currentTargetSets
        let setReps = SharedState.setReps
        
        let attributes = GymActivityAttributes(workoutDayName: workoutDayName)
        let state = GymActivityAttributes.ContentState(
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: unit,
            setNumber: 0,
            currentExerciseIndex: index,
            repTarget: "",
            lastSetSummary: "",
            targetSets: targetSets,
            setReps: setReps,
            completedSets: 0
        )
        
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity<GymActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            SharedState.defaults?.set(activity.id, forKey: SharedState.Keys.activityId)
        } catch {
            // Live Activity failed to start — nothing to show
        }
        return .result()
    }
    
    private func updateExistingActivity() async {
        let targetSets = SharedState.currentTargetSets
        let setReps = SharedState.setReps
        let completed = SharedState.completedSetsCount
        
        let state = GymActivityAttributes.ContentState(
            exerciseName: SharedState.currentExerciseName,
            reps: SharedState.currentReps,
            weight: SharedState.currentWeight,
            weightUnit: SharedState.weightUnit,
            setNumber: completed,
            currentExerciseIndex: SharedState.currentExerciseIndex,
            repTarget: "",
            lastSetSummary: "",
            targetSets: targetSets,
            setReps: setReps,
            completedSets: completed
        )
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<GymActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}

/// End the workout Live Activity
struct EndWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "End TapLift Workout"
    static var description: IntentDescription = "End the current workout tracking"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        for activity in Activity<GymActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
