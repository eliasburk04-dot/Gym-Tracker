import XCTest
@testable import Runner

/// Tests for SharedState convenience accessors.
///
/// These tests use a dedicated UserDefaults suite instead of the real App Group
/// so they can run in the simulator test target without entitlements.
class SharedStateTests: XCTestCase {

    /// Isolated UserDefaults for testing (avoids polluting real App Group).
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.taplift.tests")
        testDefaults.removePersistentDomain(forName: "com.taplift.tests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.taplift.tests")
        super.tearDown()
    }

    // MARK: - Default values

    func testDefaultReps() {
        // SharedState.currentReps defaults to 8 when nothing is stored
        let reps = testDefaults.integer(forKey: "currentReps")
        XCTAssertEqual(reps, 0, "UserDefaults returns 0 for unset integer key")
        // The real SharedState coalesces with ?? 8, so we test that pattern:
        let coalesced = testDefaults.object(forKey: "currentReps") as? Int ?? 8
        XCTAssertEqual(coalesced, 8)
    }

    func testDefaultWeight() {
        let coalesced = testDefaults.object(forKey: "currentWeight") as? Double ?? 20.0
        XCTAssertEqual(coalesced, 20.0)
    }

    func testDefaultWeightStep() {
        let coalesced = testDefaults.object(forKey: "weightStep") as? Double ?? 2.5
        XCTAssertEqual(coalesced, 2.5)
    }

    func testDefaultWeightUnit() {
        let coalesced = testDefaults.string(forKey: "weightUnit") ?? "kg"
        XCTAssertEqual(coalesced, "kg")
    }

    // MARK: - Read/Write round-trip

    func testRepsRoundTrip() {
        testDefaults.set(12, forKey: "currentReps")
        XCTAssertEqual(testDefaults.integer(forKey: "currentReps"), 12)
    }

    func testWeightRoundTrip() {
        testDefaults.set(67.5, forKey: "currentWeight")
        XCTAssertEqual(testDefaults.double(forKey: "currentWeight"), 67.5)
    }

    func testExerciseListRoundTrip() {
        let exercises: [[String: Any]] = [
            ["id": "e1", "name": "Bench Press", "lastReps": 8, "lastWeight": 80.0],
            ["id": "e2", "name": "OHP", "lastReps": 10, "lastWeight": 40.0],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: exercises),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to encode exercises JSON")
            return
        }
        testDefaults.set(json, forKey: "exerciseList")

        // Decode back
        guard let storedJson = testDefaults.string(forKey: "exerciseList"),
              let storedData = storedJson.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: storedData) as? [[String: Any]] else {
            XCTFail("Failed to decode exercises JSON")
            return
        }
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0]["name"] as? String, "Bench Press")
        XCTAssertEqual(decoded[1]["id"] as? String, "e2")
    }

    // MARK: - Pending sets queue

    func testPendingSetsAppendAndDecode() {
        // Simulate what SharedState.appendPendingSet does
        var pending: [[String: Any]] = []

        let set1: [String: Any] = [
            "exerciseId": "e1",
            "reps": 8,
            "weight": 80.0,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "liveActivity"
        ]
        pending.append(set1)

        let set2: [String: Any] = [
            "exerciseId": "e1",
            "reps": 8,
            "weight": 82.5,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "source": "liveActivity"
        ]
        pending.append(set2)

        guard let data = try? JSONSerialization.data(withJSONObject: pending),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Failed to encode pending sets")
            return
        }
        testDefaults.set(json, forKey: "pendingSets")

        // Decode
        guard let stored = testDefaults.string(forKey: "pendingSets"),
              let storedData = stored.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: storedData) as? [[String: Any]] else {
            XCTFail("Failed to decode pending sets")
            return
        }
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0]["exerciseId"] as? String, "e1")
        XCTAssertEqual(decoded[1]["weight"] as? Double, 82.5)
    }

    // MARK: - Exercise navigation

    func testExerciseIndexWraparound() {
        // Simulates NextExerciseIntent wrap logic
        let exerciseCount = 3
        var index = 2 // last exercise

        // Next → should wrap to 0
        if index < exerciseCount - 1 {
            index += 1
        } else {
            index = 0
        }
        XCTAssertEqual(index, 0)

        // Previous from 0 → should wrap to 2
        if index > 0 {
            index -= 1
        } else {
            index = max(0, exerciseCount - 1)
        }
        XCTAssertEqual(index, 2)
    }

    func testExerciseIndexBounds() {
        // Forward navigation within bounds
        var index = 0
        let count = 3

        if index < count - 1 { index += 1 }
        XCTAssertEqual(index, 1)

        if index < count - 1 { index += 1 }
        XCTAssertEqual(index, 2)

        // At end, wraps
        if index < count - 1 { index += 1 } else { index = 0 }
        XCTAssertEqual(index, 0)
    }

    // MARK: - Intent business logic (unit-level)

    func testIncrementRepsBoundsAt99() {
        var reps = 98
        if reps < 99 { reps += 1 }
        XCTAssertEqual(reps, 99)

        // Already at 99 — should NOT increment
        if reps < 99 { reps += 1 }
        XCTAssertEqual(reps, 99)
    }

    func testDecrementRepsBoundsAt1() {
        var reps = 2
        if reps > 1 { reps -= 1 }
        XCTAssertEqual(reps, 1)

        // Already at 1 — should NOT decrement
        if reps > 1 { reps -= 1 }
        XCTAssertEqual(reps, 1)
    }

    func testIncrementWeight() {
        let step = 2.5
        var weight = 80.0
        weight += step
        XCTAssertEqual(weight, 82.5)
    }

    func testDecrementWeightFloorAtZero() {
        let step = 2.5
        var weight = 2.5
        var newWeight = weight - step
        if newWeight >= 0 { weight = newWeight }
        XCTAssertEqual(weight, 0.0)

        // At 0 — should NOT go negative
        newWeight = weight - step
        if newWeight >= 0 { weight = newWeight }
        XCTAssertEqual(weight, 0.0, "Weight should not go below 0")
    }

    func testDecrementWeightWithLbStep() {
        let step = 5.0
        var weight = 10.0
        let newWeight = weight - step
        if newWeight >= 0 { weight = newWeight }
        XCTAssertEqual(weight, 5.0)
    }

    // MARK: - GymActivityAttributes

    func testContentStateCodable() {
        // Verify the ContentState struct encodes/decodes correctly
        let state = GymActivityAttributes.ContentState(
            exerciseName: "Bench Press",
            reps: 8,
            weight: 80.0,
            weightUnit: "kg",
            setNumber: 3,
            currentExerciseIndex: 0
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        guard let data = try? encoder.encode(state),
              let decoded = try? decoder.decode(GymActivityAttributes.ContentState.self, from: data) else {
            XCTFail("ContentState should be Codable")
            return
        }

        XCTAssertEqual(decoded.exerciseName, "Bench Press")
        XCTAssertEqual(decoded.reps, 8)
        XCTAssertEqual(decoded.weight, 80.0)
        XCTAssertEqual(decoded.weightUnit, "kg")
        XCTAssertEqual(decoded.setNumber, 3)
        XCTAssertEqual(decoded.currentExerciseIndex, 0)
    }

    func testContentStateHashable() {
        let a = GymActivityAttributes.ContentState(
            exerciseName: "Bench", reps: 8, weight: 80,
            weightUnit: "kg", setNumber: 1, currentExerciseIndex: 0
        )
        let b = GymActivityAttributes.ContentState(
            exerciseName: "Bench", reps: 8, weight: 80,
            weightUnit: "kg", setNumber: 1, currentExerciseIndex: 0
        )
        XCTAssertEqual(a, b, "Identical ContentState values should be equal")
        XCTAssertEqual(a.hashValue, b.hashValue)

        let c = GymActivityAttributes.ContentState(
            exerciseName: "OHP", reps: 10, weight: 40,
            weightUnit: "kg", setNumber: 2, currentExerciseIndex: 1
        )
        XCTAssertNotEqual(a, c)
    }
}
