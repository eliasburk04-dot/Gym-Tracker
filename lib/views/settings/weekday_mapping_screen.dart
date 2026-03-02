import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/today_workout_provider.dart';

class WeekdayMappingScreen extends ConsumerWidget {
  const WeekdayMappingScreen({super.key});

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutDays = ref.watch(allWorkoutDaysProvider);
    final weekdayPlans = ref.watch(weekdayPlansProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Weekday Schedule'),
      ),
      child: SafeArea(
        child: workoutDays.when(
          data: (days) => weekdayPlans.when(
            data: (plans) => _buildList(context, ref, days, plans),
            loading: () =>
                const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<WorkoutDay> days,
    List<WeekdayPlan> plans,
  ) {
    return CupertinoListSection.insetGrouped(
      children: List.generate(7, (index) {
        final weekday = index + 1;
        final plan = plans.where((p) => p.weekday == weekday).firstOrNull;
        final assignedDay = plan?.workoutDayId != null
            ? days.where((d) => d.id == plan!.workoutDayId).firstOrNull
            : null;

        return CupertinoListTile(
          title: Text(_weekdayNames[index]),
          additionalInfo: Text(
            assignedDay?.name ?? 'Rest',
            style: TextStyle(
              color: assignedDay != null
                  ? null
                  : CupertinoColors.systemGrey,
            ),
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: () =>
              _showDayPicker(context, ref, weekday, days, plan?.workoutDayId),
        );
      }),
    );
  }

  void _showDayPicker(
    BuildContext context,
    WidgetRef ref,
    int weekday,
    List<WorkoutDay> days,
    String? currentDayId,
  ) {
    final actions = <CupertinoActionSheetAction>[
      // Rest option
      CupertinoActionSheetAction(
        onPressed: () {
          final userId = ref.read(currentUserIdProvider);
          if (userId != null) {
            ref.read(workoutRepositoryProvider).setWeekdayPlan(
                  userId,
                  weekday,
                  null,
                );
          }
          Navigator.pop(context);
        },
        child: Text(
          'Rest',
          style: TextStyle(
            fontWeight:
                currentDayId == null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      // Workout day options
      ...days.map(
        (day) => CupertinoActionSheetAction(
          onPressed: () {
            final userId = ref.read(currentUserIdProvider);
            if (userId != null) {
              ref.read(workoutRepositoryProvider).setWeekdayPlan(
                    userId,
                    weekday,
                    day.id,
                  );
            }
            Navigator.pop(context);
          },
          child: Text(
            day.name,
            style: TextStyle(
              fontWeight:
                  day.id == currentDayId ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    ];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(_weekdayNames[weekday - 1]),
        message: const Text('Select workout for this day'),
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
