import AppIntents
import ActivityKit

/// App Intent exposed to Shortcuts — triggered by Back Tap.
/// Starts or updates the Live Activity for today's workout.
struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start TapLift Workout"
    static var description: IntentDescription = "Start tracking your workout with a Live Activity"
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Read workout state from shared UserDefaults
        let exercises = SharedState.exercises
        let workoutDayName = SharedState.workoutDayName
        
        guard !exercises.isEmpty else {
            return .result(dialog: "No workout configured. Open TapLift to set up your workout.")
        }
        
        // Check if there's already a running activity — update it
        if !Activity<GymActivityAttributes>.activities.isEmpty {
            await updateExistingActivity()
            return .result(dialog: "Workout updated: \(SharedState.currentExerciseName)")
        }
        
        // Start a new Live Activity
        let index = SharedState.currentExerciseIndex
        let exerciseName = SharedState.currentExerciseName
        let reps = SharedState.currentReps
        let weight = SharedState.currentWeight
        let unit = SharedState.weightUnit
        
        let attributes = GymActivityAttributes(
            workoutDayName: workoutDayName
        )
        let state = GymActivityAttributes.ContentState(
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: unit,
            setNumber: 0,
            currentExerciseIndex: index,
            repTarget: "",
            lastSetSummary: ""
        )
        
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity<GymActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            SharedState.defaults?.set(activity.id, forKey: SharedState.Keys.activityId)
            return .result(dialog: "Workout started: \(workoutDayName)")
        } catch {
            return .result(dialog: "Could not start workout: \(error.localizedDescription)")
        }
    }
    
    private func updateExistingActivity() async {
        let state = GymActivityAttributes.ContentState(
            exerciseName: SharedState.currentExerciseName,
            reps: SharedState.currentReps,
            weight: SharedState.currentWeight,
            weightUnit: SharedState.weightUnit,
            setNumber: SharedState.pendingSets.count,
            currentExerciseIndex: SharedState.currentExerciseIndex,
            repTarget: "",
            lastSetSummary: ""
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
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        for activity in Activity<GymActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result(dialog: "Workout ended. Great session!")
    }
}
