import Flutter
import UIKit
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private var liveActivityChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        liveActivityChannel = FlutterMethodChannel(
            name: "com.taplift/live_activity",
            binaryMessenger: controller.binaryMessenger
        )
        
        liveActivityChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startActivity":
            startLiveActivity(call: call, result: result)
        case "updateActivity":
            updateLiveActivity(call: call, result: result)
        case "endActivity":
            endLiveActivity(result: result)
        case "syncPendingSets":
            syncPendingSets(result: result)
        case "getAppGroupPath":
            getAppGroupPath(result: result)
        case "writeSharedState":
            writeSharedState(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(FlutterError(code: "UNAVAILABLE", message: "Live Activities require iOS 16.2+", details: nil))
            return
        }
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            result(FlutterError(code: "DISABLED", message: "Live Activities are disabled", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let workoutDayName = args["workoutDayName"] as? String,
              let exerciseName = args["exerciseName"] as? String,
              let exercisesJson = args["exercises"] as? String,
              let currentExerciseIndex = args["currentExerciseIndex"] as? Int,
              let reps = args["reps"] as? Int,
              let weight = args["weight"] as? Double,
              let weightUnit = args["weightUnit"] as? String,
              let weightStep = args["weightStep"] as? Double
        else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
            return
        }
        
        // Write to shared UserDefaults for widget extension
        let defaults = SharedState.defaults
        defaults?.set(workoutDayName, forKey: SharedState.Keys.workoutDayName)
        defaults?.set(exerciseName, forKey: SharedState.Keys.currentExerciseName)
        defaults?.set(exercisesJson, forKey: SharedState.Keys.exerciseList)
        defaults?.set(currentExerciseIndex, forKey: SharedState.Keys.currentExerciseIndex)
        defaults?.set(reps, forKey: SharedState.Keys.currentReps)
        defaults?.set(weight, forKey: SharedState.Keys.currentWeight)
        defaults?.set(weightUnit, forKey: SharedState.Keys.weightUnit)
        defaults?.set(weightStep, forKey: SharedState.Keys.weightStep)
        
        // End existing activities
        if #available(iOS 16.2, *) {
            for activity in Activity<GymActivityAttributes>.activities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        
        // Start new Live Activity
        let attributes = GymActivityAttributes(
            workoutDayName: workoutDayName
        )
        let state = GymActivityAttributes.ContentState(
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: weightUnit,
            setNumber: 0,
            currentExerciseIndex: currentExerciseIndex
        )
        
        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity<GymActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            defaults?.set(activity.id, forKey: SharedState.Keys.activityId)
            result(activity.id)
        } catch {
            result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
        }
    }
    
    private func updateLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(false)
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let exerciseName = args["exerciseName"] as? String,
              let currentExerciseIndex = args["currentExerciseIndex"] as? Int,
              let reps = args["reps"] as? Int,
              let weight = args["weight"] as? Double,
              let setNumber = args["setNumber"] as? Int,
              let totalSetsLogged = args["totalSetsLogged"] as? Int
        else {
            result(false)
            return
        }
        
        let defaults = SharedState.defaults
        defaults?.set(exerciseName, forKey: SharedState.Keys.currentExerciseName)
        defaults?.set(currentExerciseIndex, forKey: SharedState.Keys.currentExerciseIndex)
        defaults?.set(reps, forKey: SharedState.Keys.currentReps)
        defaults?.set(weight, forKey: SharedState.Keys.currentWeight)
        
        let state = GymActivityAttributes.ContentState(
            exerciseName: exerciseName,
            reps: reps,
            weight: weight,
            weightUnit: defaults?.string(forKey: SharedState.Keys.weightUnit) ?? "kg",
            setNumber: setNumber,
            currentExerciseIndex: currentExerciseIndex
        )
        
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            for activity in Activity<GymActivityAttributes>.activities {
                await activity.update(content)
            }
            result(true)
        }
    }
    
    private func endLiveActivity(result: @escaping FlutterResult) {
        guard #available(iOS 16.2, *) else {
            result(false)
            return
        }
        
        Task {
            for activity in Activity<GymActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            result(true)
        }
    }
    
    private func syncPendingSets(result: @escaping FlutterResult) {
        let defaults = SharedState.defaults
        if let pendingJson = defaults?.string(forKey: SharedState.Keys.pendingSets) {
            // Clear after reading
            defaults?.removeObject(forKey: SharedState.Keys.pendingSets)
            result(pendingJson)
        } else {
            result("[]")
        }
    }
    
    private func getAppGroupPath(result: @escaping FlutterResult) {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedState.appGroupId
        ) {
            result(containerURL.path)
        } else {
            result(nil)
        }
    }
    
    private func writeSharedState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }
        
        let defaults = SharedState.defaults
        
        if let v = args["currentExerciseId"] as? String {
            defaults?.set(v, forKey: SharedState.Keys.currentExerciseId)
        }
        if let v = args["currentExerciseName"] as? String {
            defaults?.set(v, forKey: SharedState.Keys.currentExerciseName)
        }
        if let v = args["reps"] as? Int {
            defaults?.set(v, forKey: SharedState.Keys.currentReps)
        }
        if let v = args["weight"] as? Double {
            defaults?.set(v, forKey: SharedState.Keys.currentWeight)
        }
        if let v = args["weightUnit"] as? String {
            defaults?.set(v, forKey: SharedState.Keys.weightUnit)
        }
        if let v = args["weightStep"] as? Double {
            defaults?.set(v, forKey: SharedState.Keys.weightStep)
        }
        if let v = args["exercises"] as? String {
            defaults?.set(v, forKey: SharedState.Keys.exerciseList)
        }
        if let v = args["currentExerciseIndex"] as? Int {
            defaults?.set(v, forKey: SharedState.Keys.currentExerciseIndex)
        }
        
        result(true)
    }
}
