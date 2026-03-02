import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class ExercisesEditor extends ConsumerStatefulWidget {
  final String workoutDayId;

  const ExercisesEditor({super.key, required this.workoutDayId});

  @override
  ConsumerState<ExercisesEditor> createState() => _ExercisesEditorState();
}

class _ExercisesEditorState extends ConsumerState<ExercisesEditor> {
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
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
    _weightController.dispose();
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

  String _exerciseSubtitle(Exercise exercise) {
    final unit = ref.read(weightUnitProvider);
    final parts = <String>[];
    parts.add('${exercise.targetSets} sets');
    if (exercise.repTargetMin > 0 && exercise.repTargetMax > 0) {
      if (exercise.repTargetMin == exercise.repTargetMax) {
        parts.add('${exercise.repTargetMin} reps');
      } else {
        parts.add('${exercise.repTargetMin}–${exercise.repTargetMax} reps');
      }
    } else if (exercise.repTargetMin == 0 && exercise.repTargetMax == 0) {
      parts.add('AMRAP');
    }
    if (exercise.targetWeight > 0) {
      final w = exercise.targetWeight;
      final formatted = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
      parts.add('$formatted $unit');
    }
    return parts.join(' · ');
  }

  void _editExercise(Exercise exercise) {
    _nameController.text = exercise.name;
    _weightController.text = exercise.targetWeight > 0
        ? exercise.targetWeight.toStringAsFixed(
            exercise.targetWeight % 1 == 0 ? 0 : 1)
        : '';
    int targetSets = exercise.targetSets;
    int repMin = exercise.repTargetMin;
    int repMax = exercise.repTargetMax;
    bool isAmrap = repMin == 0 && repMax == 0;
    final weightUnit = ref.read(weightUnitProvider);

    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Edit Exercise'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Exercise name',
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Target Sets:  ',
                        style: TextStyle(fontSize: 14)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () {
                        if (targetSets > 1) {
                          setDialogState(() => targetSets--);
                        }
                      },
                      child: const Icon(CupertinoIcons.minus_circle,
                          size: 22),
                    ),
                    Text('$targetSets',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () {
                        if (targetSets < 20) {
                          setDialogState(() => targetSets++);
                        }
                      },
                      child: const Icon(CupertinoIcons.plus_circle,
                          size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Rep target range
                Row(
                  children: [
                    const Text('Rep Range:  ',
                        style: TextStyle(fontSize: 14)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: isAmrap ? null : () {
                        if (repMin > 1) {
                          setDialogState(() => repMin--);
                        }
                      },
                      child: const Icon(CupertinoIcons.minus_circle,
                          size: 22),
                    ),
                    Text(isAmrap ? 'AMRAP' : '$repMin–$repMax',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: isAmrap ? null : () {
                        setDialogState(() {
                          repMax++;
                          if (repMin > repMax) repMin = repMax;
                        });
                      },
                      child: const Icon(CupertinoIcons.plus_circle,
                          size: 22),
                    ),
                  ],
                ),
                if (!isAmrap) ...[
                  Row(
                    children: [
                      const Text('  Min:  ',
                          style: TextStyle(fontSize: 13,
                              color: CupertinoColors.systemGrey)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () {
                          if (repMin > 1) {
                            setDialogState(() => repMin--);
                          }
                        },
                        child: const Icon(CupertinoIcons.minus_circle,
                            size: 18),
                      ),
                      Text('$repMin',
                          style: const TextStyle(fontSize: 15)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () {
                          setDialogState(() {
                            repMin++;
                            if (repMin > repMax) repMax = repMin;
                          });
                        },
                        child: const Icon(CupertinoIcons.plus_circle,
                            size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text('Max:  ',
                          style: TextStyle(fontSize: 13,
                              color: CupertinoColors.systemGrey)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () {
                          if (repMax > repMin) {
                            setDialogState(() => repMax--);
                          }
                        },
                        child: const Icon(CupertinoIcons.minus_circle,
                            size: 18),
                      ),
                      Text('$repMax',
                          style: const TextStyle(fontSize: 15)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () {
                          setDialogState(() => repMax++);
                        },
                        child: const Icon(CupertinoIcons.plus_circle,
                            size: 18),
                      ),
                    ],
                  ),
                ],
                Row(
                  children: [
                    const Text('AMRAP:  ',
                        style: TextStyle(fontSize: 14)),
                    CupertinoSwitch(
                      value: isAmrap,
                      onChanged: (val) {
                        setDialogState(() {
                          isAmrap = val;
                          if (val) {
                            repMin = 0;
                            repMax = 0;
                          } else {
                            repMin = 8;
                            repMax = 12;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _weightController,
                  placeholder: 'Target weight (${weightUnit.label})',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () {
                _nameController.clear();
                _weightController.clear();
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
                await repo.updateTargetSets(exercise.id, targetSets);
                await repo.updateRepTarget(exercise.id, repMin, repMax);

                final weightText = _weightController.text.trim();
                final weight = double.tryParse(weightText) ?? 0.0;
                await repo.updateTargetWeight(exercise.id, weight);

                _nameController.clear();
                _weightController.clear();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
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
                    subtitle: Text(
                      _exerciseSubtitle(exercise),
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
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
