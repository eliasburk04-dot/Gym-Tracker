import AppIntents
import ActivityKit

// MARK: - Reps Intents

struct IncrementRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Reps"
    static var description: IntentDescription = "Add one rep"
    
    func perform() async throws -> some IntentResult {
        var reps = SharedState.currentReps
        if reps < 99 {
            reps += 1
        }
        SharedState.currentReps = reps
        await updateLiveActivity()
        return .result()
    }
}

struct DecrementRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Reps"
    static var description: IntentDescription = "Remove one rep"
    
    func perform() async throws -> some IntentResult {
        var reps = SharedState.currentReps
        if reps > 1 {
            reps -= 1
        }
        SharedState.currentReps = reps
        await updateLiveActivity()
        return .result()
    }
}

// MARK: - Weight Intents

struct IncrementWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Weight"
    static var description: IntentDescription = "Add weight increment"
    
    func perform() async throws -> some IntentResult {
        let step = SharedState.weightStep
        SharedState.currentWeight = SharedState.currentWeight + step
        await updateLiveActivity()
        return .result()
    }
}

struct DecrementWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Weight"
    static var description: IntentDescription = "Remove weight increment"
    
    func perform() async throws -> some IntentResult {
        let step = SharedState.weightStep
        let newWeight = SharedState.currentWeight - step
        if newWeight >= 0 {
            SharedState.currentWeight = newWeight
        }
        await updateLiveActivity()
        return .result()
    }
}

// MARK: - Complete Set Intent

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Set"
    static var description: IntentDescription = "Log the current set"
    
    func perform() async throws -> some IntentResult {
        let reps = SharedState.currentReps
        let weight = SharedState.currentWeight
        
        guard let exerciseId = SharedState.currentExerciseId else {
            // Fallback: use exercise from list
            let exercises = SharedState.exercises
            let index = SharedState.currentExerciseIndex
            if index < exercises.count, let id = exercises[index]["id"] as? String {
                SharedState.appendPendingSet(exerciseId: id, reps: reps, weight: weight)
            }
            await updateLiveActivityAfterSet()
            return .result()
        }
        
        SharedState.appendPendingSet(exerciseId: exerciseId, reps: reps, weight: weight)
        await updateLiveActivityAfterSet()
        return .result()
    }
    
    private func updateLiveActivityAfterSet() async {
        // Increment set number in the live activity
        let exercises = SharedState.exercises
        let index = SharedState.currentExerciseIndex
        let exerciseName = SharedState.currentExerciseName
        let reps = SharedState.currentReps
        let weight = SharedState.currentWeight
        let unit = SharedState.weightUnit
        let pendingCount = SharedState.pendingSets.count
        let workoutDayName = SharedState.workoutDayName
        
        let state = GymActivityAttributes.ContentState(
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: unit,
            setNumber: pendingCount,
            currentExerciseIndex: index
        )
        
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<GymActivityAttributes>.activities {
            await activity.update(content)
        }
    }
}

// MARK: - Navigation Intents

struct NextExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Exercise"
    static var description: IntentDescription = "Switch to next exercise"
    
    func perform() async throws -> some IntentResult {
        let exercises = SharedState.exercises
        var index = SharedState.currentExerciseIndex
        
        if index < exercises.count - 1 {
            index += 1
        } else {
            index = 0 // Wrap around
        }
        
        SharedState.currentExerciseIndex = index
        
        // Load the new exercise's defaults
        if index < exercises.count {
            let exercise = exercises[index]
            if let name = exercise["name"] as? String {
                SharedState.defaults?.set(name, forKey: SharedState.Keys.currentExerciseName)
            }
            if let id = exercise["id"] as? String {
                SharedState.defaults?.set(id, forKey: SharedState.Keys.currentExerciseId)
            }
            if let lastReps = exercise["lastReps"] as? Int {
                SharedState.currentReps = lastReps
            }
            if let lastWeight = exercise["lastWeight"] as? Double {
                SharedState.currentWeight = lastWeight
            }
        }
        
        await updateLiveActivity()
        return .result()
    }
}

struct PreviousExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous Exercise"
    static var description: IntentDescription = "Switch to previous exercise"
    
    func perform() async throws -> some IntentResult {
        let exercises = SharedState.exercises
        var index = SharedState.currentExerciseIndex
        
        if index > 0 {
            index -= 1
        } else {
            index = max(0, exercises.count - 1) // Wrap around
        }
        
        SharedState.currentExerciseIndex = index
        
        // Load the new exercise's defaults
        if index < exercises.count {
            let exercise = exercises[index]
            if let name = exercise["name"] as? String {
                SharedState.defaults?.set(name, forKey: SharedState.Keys.currentExerciseName)
            }
            if let id = exercise["id"] as? String {
                SharedState.defaults?.set(id, forKey: SharedState.Keys.currentExerciseId)
            }
            if let lastReps = exercise["lastReps"] as? Int {
                SharedState.currentReps = lastReps
            }
            if let lastWeight = exercise["lastWeight"] as? Double {
                SharedState.currentWeight = lastWeight
            }
        }
        
        await updateLiveActivity()
        return .result()
    }
}

// MARK: - Shared Update Helper

private func updateLiveActivity() async {
    let exerciseName = SharedState.currentExerciseName
    let reps = SharedState.currentReps
    let weight = SharedState.currentWeight
    let unit = SharedState.weightUnit
    let index = SharedState.currentExerciseIndex
    let setCount = SharedState.pendingSets.count
    
    let state = GymActivityAttributes.ContentState(
        exerciseName: exerciseName,
        reps: reps,
        weight: weight,
        weightUnit: unit,
        setNumber: setCount,
        currentExerciseIndex: index
    )
    
    let content = ActivityContent(state: state, staleDate: nil)
    for activity in Activity<GymActivityAttributes>.activities {
        await activity.update(content)
    }
}
