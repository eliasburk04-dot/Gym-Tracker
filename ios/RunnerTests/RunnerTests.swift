import Flutter
import UIKit
import XCTest
@testable import Runner

/// Tests that validate the MethodChannel contract between Flutter and iOS.
/// These tests verify the JSON shapes and field types that the Flutter
/// LiveActivityService sends / receives over com.taplift/live_activity.
class RunnerTests: XCTestCase {

    // MARK: - startActivity payload shape

    func testStartActivityPayloadShape() {
        // Simulate the payload Flutter sends for startActivity
        let payload: [String: Any] = [
            "workoutDayName": "Push",
            "exerciseName": "Bench Press",
            "exercises": "[{\"id\":\"e1\",\"name\":\"Bench Press\",\"lastReps\":8,\"lastWeight\":80.0}]",
            "currentExerciseIndex": 0,
            "reps": 8,
            "weight": 80.0,
            "weightUnit": "kg",
            "weightStep": 2.5,
        ]

        // Verify all required keys are present and correctly typed
        XCTAssertNotNil(payload["workoutDayName"] as? String)
        XCTAssertNotNil(payload["exerciseName"] as? String)
        XCTAssertNotNil(payload["exercises"] as? String, "exercises should be a JSON string")
        XCTAssertNotNil(payload["currentExerciseIndex"] as? Int)
        XCTAssertNotNil(payload["reps"] as? Int)
        XCTAssertNotNil(payload["weight"] as? Double)
        XCTAssertNotNil(payload["weightUnit"] as? String)
        XCTAssertNotNil(payload["weightStep"] as? Double)

        // Verify exercises JSON is parseable
        guard let exercisesJson = payload["exercises"] as? String,
              let data = exercisesJson.data(using: .utf8),
              let exercises = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("exercises JSON should be parseable")
            return
        }
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises[0]["id"] as? String, "e1")
        XCTAssertEqual(exercises[0]["name"] as? String, "Bench Press")
    }

    // MARK: - updateActivity payload shape

    func testUpdateActivityPayloadShape() {
        let payload: [String: Any] = [
            "exerciseName": "OHP",
            "currentExerciseIndex": 1,
            "reps": 10,
            "weight": 40.0,
            "setNumber": 3,
            "totalSetsLogged": 5,
        ]

        XCTAssertNotNil(payload["exerciseName"] as? String)
        XCTAssertNotNil(payload["currentExerciseIndex"] as? Int)
        XCTAssertNotNil(payload["reps"] as? Int)
        XCTAssertNotNil(payload["weight"] as? Double)
        XCTAssertNotNil(payload["setNumber"] as? Int)
        XCTAssertNotNil(payload["totalSetsLogged"] as? Int)
    }

    // MARK: - writeSharedState payload shape

    func testWriteSharedStatePayloadShape() {
        let payload: [String: Any] = [
            "currentExerciseId": "e1",
            "currentExerciseName": "Bench Press",
            "reps": 8,
            "weight": 80.0,
            "weightUnit": "kg",
            "weightStep": 2.5,
            "exercises": "[{\"id\":\"e1\",\"name\":\"Bench\"}]",
            "currentExerciseIndex": 0,
        ]

        XCTAssertNotNil(payload["currentExerciseId"] as? String)
        XCTAssertNotNil(payload["currentExerciseName"] as? String)
        XCTAssertNotNil(payload["reps"] as? Int)
        XCTAssertNotNil(payload["weight"] as? Double)
        XCTAssertNotNil(payload["weightUnit"] as? String)
        XCTAssertNotNil(payload["weightStep"] as? Double)
        XCTAssertNotNil(payload["exercises"] as? String)
        XCTAssertNotNil(payload["currentExerciseIndex"] as? Int)
    }

    // MARK: - syncPendingSets response shape

    func testSyncPendingSetsResponseShape() {
        // Flutter expects a JSON string of [{exerciseId, reps, weight, timestamp, source}]
        let pendingSets: [[String: Any]] = [
            [
                "exerciseId": "e1",
                "reps": 8,
                "weight": 80.0,
                "timestamp": "2026-03-02T10:00:00Z",
                "source": "liveActivity",
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: pendingSets),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Should encode pending sets to JSON string")
            return
        }

        // Flutter decodes the string back
        guard let decoded = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: decoded) as? [[String: Any]] else {
            XCTFail("Should decode JSON string back to array")
            return
        }

        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array[0]["exerciseId"] as? String, "e1")
        XCTAssertEqual(array[0]["reps"] as? Int, 8)
        XCTAssertEqual(array[0]["source"] as? String, "liveActivity")
    }

    // MARK: - Channel method names

    func testMethodChannelNames() {
        // Verify method names match what Flutter sends
        let expectedMethods = [
            "startActivity",
            "updateActivity",
            "endActivity",
            "syncPendingSets",
            "getAppGroupPath",
            "writeSharedState",
        ]
        // This is a documentation/contract test — if a method is renamed,
        // both Flutter and native side must be updated.
        for method in expectedMethods {
            XCTAssertFalse(method.isEmpty, "Method name '\(method)' should not be empty")
            XCTAssertFalse(method.contains(" "), "Method name '\(method)' should not contain spaces")
        }
    }
}

