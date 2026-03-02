import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';

class ExercisesEditor extends ConsumerStatefulWidget {
  final String workoutDayId;

  const ExercisesEditor({super.key, required this.workoutDayId});

  @override
  ConsumerState<ExercisesEditor> createState() => _ExercisesEditorState();
}

class _ExercisesEditorState extends ConsumerState<ExercisesEditor> {
  final _nameController = TextEditingController();
  late final Stream<List<Exercise>> _exercisesStream;

  @override
  void initState() {
    super.initState();
    _exercisesStream = ref
        .read(exerciseRepositoryProvider)
        .watchExercisesForDay(widget.workoutDayId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addExercise(int currentCount) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Exercise'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g. Bench Press',
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

              final repo = ref.read(exerciseRepositoryProvider);
              await repo.createExercise(
                  widget.workoutDayId, name, currentCount);

              _nameController.clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _editExercise(Exercise exercise) {
    _nameController.text = exercise.name;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Exercise'),
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

              final repo = ref.read(exerciseRepositoryProvider);
              await repo.updateExercise(exercise.id, name: name);

              _nameController.clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _deleteExercise(Exercise exercise) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${exercise.name}"?'),
        content: const Text('This will also delete all logged sets for this exercise.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              final repo = ref.read(exerciseRepositoryProvider);
              await repo.deleteExercise(exercise.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Exercises'),
        trailing: StreamBuilder<List<Exercise>>(
          stream: _exercisesStream,
          builder: (context, snapshot) => CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _addExercise(snapshot.data?.length ?? 0),
            child: const Icon(CupertinoIcons.add),
          ),
        ),
      ),
      child: SafeArea(
        child: StreamBuilder<List<Exercise>>(
          stream: _exercisesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final exercises = snapshot.data!;
            if (exercises.isEmpty) {
              return const Center(
                child: Text(
                  'No exercises yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              );
            }

            return ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 16),
              itemCount: exercises.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final ids = exercises.map((e) => e.id).toList();
                final id = ids.removeAt(oldIndex);
                ids.insert(newIndex, id);
                ref.read(exerciseRepositoryProvider).reorderExercises(ids);
              },
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return Container(
                  key: ValueKey(exercise.id),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: CupertinoTheme.brightnessOf(context) ==
                            Brightness.dark
                        ? CupertinoColors.systemGrey6.darkColor
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoListTile(
                    title: Text(exercise.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: () => _deleteExercise(exercise),
                          child: const Icon(
                            CupertinoIcons.delete,
                            size: 18,
                            color: CupertinoColors.destructiveRed,
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.line_horizontal_3,
                          size: 18,
                          color: CupertinoColors.systemGrey,
                        ),
                      ],
                    ),
                    onTap: () => _editExercise(exercise),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
