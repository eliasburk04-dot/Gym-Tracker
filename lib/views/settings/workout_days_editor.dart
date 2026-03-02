import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/today_workout_provider.dart';

class WorkoutDaysEditor extends ConsumerStatefulWidget {
  const WorkoutDaysEditor({super.key});

  @override
  ConsumerState<WorkoutDaysEditor> createState() => _WorkoutDaysEditorState();
}

class _WorkoutDaysEditorState extends ConsumerState<WorkoutDaysEditor> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addWorkoutDay() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Workout Day'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g. Push A, Upper, Cardio',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              _nameController.clear();
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Add'),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;

              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;

              final repo = ref.read(workoutRepositoryProvider);
              final existing = await repo.getAllWorkoutDays(userId);
              await repo.createWorkoutDay(userId, name, existing.length);

              _nameController.clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _editWorkoutDay(String id, String currentName) {
    _nameController.text = currentName;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Workout Day'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _nameController,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              _nameController.clear();
              Navigator.pop(ctx);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;

              final repo = ref.read(workoutRepositoryProvider);
              await repo.updateWorkoutDay(id, name);

              _nameController.clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _deleteWorkoutDay(String id, String name) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
            'This will also delete all exercises in this workout day.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              final repo = ref.read(workoutRepositoryProvider);
              await repo.deleteWorkoutDay(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutDays = ref.watch(allWorkoutDaysProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Workout Days'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addWorkoutDay,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: workoutDays.when(
          data: (days) {
            if (days.isEmpty) {
              return const Center(
                child: Text(
                  'No workout days yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              );
            }

            return CupertinoListSection.insetGrouped(
              children: days
                  .map(
                    (day) => CupertinoListTile(
                      title: Text(day.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            onPressed: () =>
                                context.push('/settings/exercises/${day.id}'),
                            child: const Text(
                              'Exercises',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          const CupertinoListTileChevron(),
                        ],
                      ),
                      onTap: () => _editWorkoutDay(day.id, day.name),
                      additionalInfo: GestureDetector(
                        onTap: () => _deleteWorkoutDay(day.id, day.name),
                        child: const Icon(
                          CupertinoIcons.delete,
                          size: 18,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
