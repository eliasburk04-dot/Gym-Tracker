import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/current_exercise_provider.dart';
import '../../providers/quick_log_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/stepper_control.dart';
import '../widgets/done_set_button.dart';

/// Bottom-docked quick log panel with stepper controls + DONE SET button.
class QuickLogPanel extends ConsumerWidget {
  const QuickLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final currentExercise = ref.watch(currentExerciseProvider);
    final quickLog = ref.watch(quickLogProvider);
    final quickLogNotifier = ref.read(quickLogProvider.notifier);
    final weightUnit = ref.watch(weightUnitProvider);

    return currentExercise.when(
      data: (exercise) {
        if (exercise == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          decoration: BoxDecoration(
            color: isDark
                ? CupertinoColors.black
                : CupertinoColors.systemGroupedBackground,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? CupertinoColors.systemGrey5.darkColor
                    : CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current exercise name
                Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 14),

                // Steppers row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StepperControl(
                      label: 'REPS',
                      value: '${quickLog.reps}',
                      onIncrement: quickLogNotifier.incrementReps,
                      onDecrement: quickLogNotifier.decrementReps,
                    ),
                    StepperControl(
                      label: 'WEIGHT (${weightUnit.label})',
                      value: quickLog.weight.toStringAsFixed(
                          quickLog.weight % 1 == 0 ? 0 : 1),
                      onIncrement: quickLogNotifier.incrementWeight,
                      onDecrement: quickLogNotifier.decrementWeight,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DONE SET button
                DoneSetButton(
                  onPressed: quickLogNotifier.logSet,
                  isLoading: quickLog.isLogging,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const CupertinoActivityIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
