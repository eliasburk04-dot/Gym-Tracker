import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../providers/current_exercise_provider.dart';
import '../../providers/settings_provider.dart';

class ExerciseCard extends ConsumerWidget {
  final Exercise exercise;
  final bool isCurrent;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final weightUnit = ref.watch(weightUnitProvider);
    final todaySetCount = ref.watch(todaySetCountProvider(exercise.id));
    final lastPerf = ref.watch(lastPerformanceProvider(exercise.id));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? CupertinoColors.systemGrey6.darkColor
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
          border: isCurrent
              ? Border.all(
                  color: isDark
                      ? CupertinoColors.white.withValues(alpha: 0.3)
                      : CupertinoColors.black.withValues(alpha: 0.15),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            // Current indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrent
                    ? (isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black)
                    : CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),

            // Exercise info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Rep target + weight info
                  Row(
                    children: [
                      // Rep target badge
                      if (exercise.repTargetMin > 0 || exercise.repTargetMax > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            exercise.repTargetMin == exercise.repTargetMax
                                ? '${exercise.repTargetMin} reps'
                                : '${exercise.repTargetMin}–${exercise.repTargetMax}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        )
                      else if (exercise.repTargetMin == 0 && exercise.repTargetMax == 0)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Text(
                            'AMRAP',
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                      // Show target weight if set, otherwise last performance
                      exercise.targetWeight > 0
                          ? Text(
                              '· ${exercise.targetWeight.toStringAsFixed(exercise.targetWeight % 1 == 0 ? 0 : 1)} ${weightUnit.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                              ),
                            )
                          : lastPerf.when(
                              data: (set) => Text(
                                set != null
                                    ? '· ${set.reps} × ${set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)} ${weightUnit.label}'
                                    : '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                    ],
                  ),
                ],
              ),
            ),

            // Today's set count badge with target
            todaySetCount.when(
              data: (count) {
                final target = exercise.targetSets;
                final done = count >= target && target > 0;
                if (count == 0 && target <= 0) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? (isDark
                            ? CupertinoColors.systemGreen.darkColor
                                .withValues(alpha: 0.25)
                            : CupertinoColors.systemGreen
                                .withValues(alpha: 0.12))
                        : (isDark
                            ? CupertinoColors.systemGrey5.darkColor
                            : CupertinoColors.systemGrey6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    target > 0 ? '$count/$target' : '$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? CupertinoColors.systemGreen
                          : (isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
