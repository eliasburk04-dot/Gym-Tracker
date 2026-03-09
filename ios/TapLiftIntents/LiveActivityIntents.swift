import AppIntents
import ActivityKit

// MARK: - Reps Intents (modify reps for the NEXT set to log)

struct IncrementRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Reps"
    static var description: IntentDescription = "Add one rep"
    
    func perform() async throws -> some IntentResult {
        var reps = SharedState.currentReps
        if reps < 99 { reps += 1 }
        SharedState.currentReps = reps
        // Also update the next-set slot in setReps
        updateNextSetSlotReps(reps)
        await refreshLiveActivity()
        return .result()
    }
}

struct DecrementRepsIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Reps"
    static var description: IntentDescription = "Remove one rep"
    
    func perform() async throws -> some IntentResult {
        var reps = SharedState.currentReps
        if reps > 1 { reps -= 1 }
        SharedState.currentReps = reps
        updateNextSetSlotReps(reps)
        await refreshLiveActivity()
        return .result()
    }
}

// MARK: - Weight Intents

struct IncrementWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Weight"
    static var description: IntentDescription = "Add weight increment"
    
    func perform() async throws -> some IntentResult {
        let step = SharedState.weightStep
        SharedState.currentWeight = snapWeight(SharedState.currentWeight + step, step: step)
        await refreshLiveActivity()
        return .result()
    }
}

struct DecrementWeightIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Weight"
    static var description: IntentDescription = "Remove weight increment"
    
    func perform() async throws -> some IntentResult {
        let step = SharedState.weightStep
        let snapped = snapWeight(SharedState.currentWeight - step, step: step)
        if snapped >= 0 { SharedState.currentWeight = snapped }
        await refreshLiveActivity()
        return .result()
    }
}

// MARK: - Complete Set Intent

struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Set"
    static var description: IntentDescription = "Log the current set"
    
    func perform() async throws -> some IntentResult {
        // 700ms cooldown
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if nowMs - SharedState.lastCompleteSetAtMs < 700 {
            return .result()
        }
        SharedState.lastCompleteSetAtMs = nowMs

        let reps = SharedState.currentReps
        let weight = SharedState.currentWeight
        let sessionId = SharedState.currentSessionId
        
        let exerciseId: String
        if let eid = SharedState.currentExerciseId {
            exerciseId = eid
        } else {
            let exercises = SharedState.exercises
            let index = SharedState.currentExerciseIndex
            guard index < exercises.count, let id = exercises[index]["id"] as? String else {
                return .result()
            }
            exerciseId = id
        }
        
        SharedState.appendPendingSet(
            exerciseId: exerciseId,
            reps: reps,
            weight: weight,
            sessionId: sessionId
        )
        
        // Mark this set slot as completed
        var completed = SharedState.completedSetsCount
        let target = SharedState.currentTargetSets
        
        // Lock in the reps for the just-completed set slot
        var sr = SharedState.setReps
        if completed < sr.count {
            sr[completed] = reps
            SharedState.setReps = sr
        }
        
        completed += 1
        SharedState.completedSetsCount = completed
        
        // Build last set summary
        let unit = SharedState.weightUnit
        let wFmt = weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))" : String(format: "%.1f", weight)
        let lastSetSummary = "\(reps)×\(wFmt) \(unit)"
        
        let state = buildContentState(lastSetSummary: lastSetSummary)
        let content = ActivityContent(state: state, staleDate: nil)
        for activity in Activity<GymActivityAttributes>.activities {
            await activity.update(content)
        }
        return .result()
    }
}

// MARK: - Navigation Intents

struct NextExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next Exercise"
    static var description: IntentDescription = "Switch to next exercise"
    
    func perform() async throws -> some IntentResult {
        switchExercise(direction: 1)
        await refreshLiveActivity()
        return .result()
    }
}

struct PreviousExerciseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous Exercise"
    static var description: IntentDescription = "Switch to previous exercise"
    
    func perform() async throws -> some IntentResult {
        switchExercise(direction: -1)
        await refreshLiveActivity()
        return .result()
    }
}

// MARK: - Shared Helpers

/// Snap weight to nearest multiple of step (FP drift prevention)
private func snapWeight(_ raw: Double, step: Double) -> Double {
    guard step > 0 else { return raw }
    return (raw / step).rounded() * step
}

/// Update the rep value for the next set slot that hasn't been completed yet
private func updateNextSetSlotReps(_ reps: Int) {
    let completed = SharedState.completedSetsCount
    var sr = SharedState.setReps
    // Update all remaining (uncompleted) set slots to the new reps value
    for i in completed..<sr.count {
        sr[i] = reps
    }
    SharedState.setReps = sr
}

/// Switch exercise in the given direction (+1 = next, -1 = previous)
private func switchExercise(direction: Int) {
    let exercises = SharedState.exercises
    guard !exercises.isEmpty else { return }
    var index = SharedState.currentExerciseIndex
    
    index += direction
    if index >= exercises.count { index = 0 }
    if index < 0 { index = exercises.count - 1 }
    
    SharedState.currentExerciseIndex = index
    SharedState.completedSetsCount = 0 // Reset for new exercise
    
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
    
    // Re-initialize setReps for the new exercise
    SharedState.ensureSetRepsInitialized()
    // Force re-init since target may have changed
    let target = SharedState.currentTargetSets
    let defaultRep = SharedState.currentReps
    SharedState.setReps = Array(repeating: defaultRep, count: target)
}

/// Build a ContentState from current SharedState
private func buildContentState(lastSetSummary: String = "") -> GymActivityAttributes.ContentState {
    let targetSets = SharedState.currentTargetSets
    var sr = SharedState.setReps
    // Ensure length matches
    if sr.count != targetSets {
        sr = Array(repeating: SharedState.currentReps, count: targetSets)
        SharedState.setReps = sr
    }
    
    return GymActivityAttributes.ContentState(
        exerciseName: SharedState.currentExerciseName,
        reps: SharedState.currentReps,
        weight: SharedState.currentWeight,
        weightUnit: SharedState.weightUnit,
        setNumber: SharedState.completedSetsCount,
        currentExerciseIndex: SharedState.currentExerciseIndex,
        repTarget: "",
        lastSetSummary: lastSetSummary,
        targetSets: targetSets,
        setReps: sr,
        completedSets: SharedState.completedSetsCount
    )
}

private func refreshLiveActivity() async {
    let state = buildContentState()
    let content = ActivityContent(state: state, staleDate: nil)
    for activity in Activity<GymActivityAttributes>.activities {
        await activity.update(content)
    }
}
