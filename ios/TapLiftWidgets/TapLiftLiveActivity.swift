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
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded: Full gym tracker ──
                DynamicIslandExpandedRegion(.leading) {
                    Button(intent: PreviousExerciseIntent()) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 2)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: NextExerciseIntent()) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 28, height: 28)
                            .background(.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    let targetSets = max(context.state.targetSets, 1)
                    let setReps = context.state.setReps
                    let completed = context.state.completedSets
                    
                    VStack(spacing: 6) {
                        // ── Weight stepper row ──
                        HStack(spacing: 8) {
                            Button(intent: DecrementWeightIntent()) {
                                Image(systemName: "minus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 24, height: 24)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(formatWeight(context.state.weight)) \(context.state.weightUnit)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(minWidth: 60)
                            
                            Button(intent: IncrementWeightIntent()) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 24, height: 24)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // ── Per-set rows ──
                        ForEach(0..<targetSets, id: \.self) { i in
                            let isDone = i < completed
                            let isNext = i == completed
                            let repVal = i < setReps.count ? setReps[i] : context.state.reps
                            
                            HStack(spacing: 6) {
                                Text("S\(i + 1)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isDone ? .green : (isNext ? .white : .secondary))
                                    .frame(width: 20)
                                
                                if isDone {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        Text("\(repVal) reps")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else if isNext {
                                    HStack(spacing: 4) {
                                        Button(intent: DecrementRepsIntent()) {
                                            Image(systemName: "minus")
                                                .font(.system(size: 9, weight: .bold))
                                                .frame(width: 22, height: 22)
                                                .background(.white.opacity(0.15))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("\(repVal)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .frame(minWidth: 20)
                                        
                                        Button(intent: IncrementRepsIntent()) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 9, weight: .bold))
                                                .frame(width: 22, height: 22)
                                                .background(.white.opacity(0.15))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Spacer()
                                        
                                        Button(intent: CompleteSetIntent()) {
                                            Text("DONE")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(.white)
                                                .foregroundStyle(.black)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else {
                                    Text("\(repVal) reps")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        
                        // Last set summary
                        if !context.state.lastSetSummary.isEmpty {
                            Text("Last: \(context.state.lastSetSummary)")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 10))
                    Text(String(context.state.exerciseName.prefix(3)))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                Text("\(context.state.completedSets)/\(context.state.targetSets)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<GymActivityAttributes>
    
    var body: some View {
        VStack(spacing: 10) {
            // ── Header: Exercise name with nav arrows ──
            HStack {
                Button(intent: PreviousExerciseIntent()) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(context.attributes.workoutDayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(context.state.exerciseName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(intent: NextExerciseIntent()) {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // ── Weight row ──
            HStack(spacing: 10) {
                Button(intent: DecrementWeightIntent()) {
                    Image(systemName: "minus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Text("\(formatWeight(context.state.weight)) \(context.state.weightUnit)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(minWidth: 80)
                
                Button(intent: IncrementWeightIntent()) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // ── Set rows: one per targetSets ──
            let targetSets = max(context.state.targetSets, 1)
            let setReps = context.state.setReps
            let completed = context.state.completedSets
            
            ForEach(0..<targetSets, id: \.self) { i in
                let isDone = i < completed
                let isNext = i == completed
                let repVal = i < setReps.count ? setReps[i] : context.state.reps
                
                HStack(spacing: 8) {
                    // Set label
                    Text("S\(i + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isDone ? .green : (isNext ? .white : .secondary))
                        .frame(width: 24)
                    
                    if isDone {
                        // Completed set: show logged reps with checkmark
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("\(repVal) reps")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if isNext {
                        // Active set: rep stepper + DONE
                        HStack(spacing: 6) {
                            Button(intent: DecrementRepsIntent()) {
                                Image(systemName: "minus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 26, height: 26)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(repVal)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .frame(minWidth: 24)
                            
                            Button(intent: IncrementRepsIntent()) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .frame(width: 26, height: 26)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button(intent: CompleteSetIntent()) {
                                Text("DONE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(.white)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Future set: dimmed placeholder
                        Text("\(repVal) reps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Last set summary
            if !context.state.lastSetSummary.isEmpty {
                Text("Last: \(context.state.lastSetSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
