import AppIntents

/// Registers intents with the Shortcuts app
struct TapLiftShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start \(.applicationName) workout",
                "Start workout in \(.applicationName)",
                "Track workout with \(.applicationName)",
                "Begin \(.applicationName) session"
            ],
            shortTitle: "Start Workout",
            systemImageName: "dumbbell.fill"
        )
        
        AppShortcut(
            intent: EndWorkoutIntent(),
            phrases: [
                "End \(.applicationName) workout",
                "Stop \(.applicationName) workout",
                "Finish \(.applicationName) session"
            ],
            shortTitle: "End Workout",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
