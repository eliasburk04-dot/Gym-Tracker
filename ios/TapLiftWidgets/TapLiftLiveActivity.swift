import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

/// The main Live Activity widget definition
struct TapLiftLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymActivityAttributes.self) { context in
            // LOCK SCREEN presentation — full interactive controls
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions (shown on long-press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.workoutDayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if !context.state.repTarget.isEmpty {
                            Text(context.state.repTarget)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Set \(context.state.setNumber + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(context.state.reps) × \(formatWeight(context.state.weight))")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.trailing, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        // Reps stepper (compact for DI)
                        HStack(spacing: 8) {
                            Button(intent: DecrementRepsIntent()) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(context.state.reps)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(minWidth: 28)
                            
                            Button(intent: IncrementRepsIntent()) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        // DONE button
                        Button(intent: CompleteSetIntent()) {
                            Text("DONE")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.white)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading (small pill — left side)
                Text(String(context.state.exerciseName.prefix(4)))
                    .font(.caption)
                    .fontWeight(.semibold)
            } compactTrailing: {
                // Compact trailing (small pill — right side)
                Text("S\(context.state.setNumber + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
            } minimal: {
                // Minimal (only icon when other activities present)
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Lock Screen View (Full Interactive Controls)

struct LockScreenView: View {
    let context: ActivityViewContext<GymActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.workoutDayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(context.state.exerciseName)
                            .font(.title3)
                            .fontWeight(.bold)
                        if !context.state.repTarget.isEmpty {
                            Text(context.state.repTarget)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Set \(context.state.setNumber + 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    if !context.state.lastSetSummary.isEmpty {
                        Text(context.state.lastSetSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Stepper controls row
            HStack(spacing: 16) {
                // Reps stepper
                VStack(spacing: 4) {
                    Text("REPS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(intent: DecrementRepsIntent()) {
                            Image(systemName: "minus")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(context.state.reps)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(minWidth: 36)
                        
                        Button(intent: IncrementRepsIntent()) {
                            Image(systemName: "plus")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Weight stepper
                VStack(spacing: 4) {
                    Text("WEIGHT (\(context.state.weightUnit.uppercased()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button(intent: DecrementWeightIntent()) {
                            Image(systemName: "minus")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text(formatWeight(context.state.weight))
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(minWidth: 48)
                        
                        Button(intent: IncrementWeightIntent()) {
                            Image(systemName: "plus")
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Bottom row: Nav + DONE
            HStack(spacing: 12) {
                // Previous exercise
                Button(intent: PreviousExerciseIntent()) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 40)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                // DONE SET button
                Button(intent: CompleteSetIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("DONE SET")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                // Next exercise
                Button(intent: NextExerciseIntent()) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 36, height: 40)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}
