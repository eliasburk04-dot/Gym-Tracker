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
                      ? CupertinoColors.white.withOpacity(0.3)
                      : CupertinoColors.black.withOpacity(0.15),
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
                  lastPerf.when(
                    data: (set) => Text(
                      set != null
                          ? '${set.reps} × ${set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)} ${weightUnit.label}'
                          : 'No previous data',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Today's set count badge
            todaySetCount.when(
              data: (count) => count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? CupertinoColors.systemGrey5.darkColor
                            : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
