import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import 'add_workout_set_exercise_screen.dart';
import 'workout_set_controller.dart';
import 'workout_set_draft.dart';
import 'workout_set_models.dart';

class WorkoutSetBuilderScreen extends StatefulWidget {
  const WorkoutSetBuilderScreen({
    required this.controller,
    required this.onBack,
    this.initialDetail,
    super.key,
  });

  final WorkoutSetController controller;
  final WorkoutSetDetail? initialDetail;
  final VoidCallback onBack;

  @override
  State<WorkoutSetBuilderScreen> createState() => _WorkoutSetBuilderScreenState();
}

class _WorkoutSetBuilderScreenState extends State<WorkoutSetBuilderScreen> {
  late final TextEditingController _nameController;
  final List<WorkoutSetDraftExercise> _draft = [];
  bool _addingExercise = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDetail?.name ?? 'Push A');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_addingExercise) {
      return AddWorkoutSetExerciseScreen(
        onBack: () => setState(() => _addingExercise = false),
        onAddExercise: (exercise) {
          setState(() {
            _draft.add(exercise);
            _addingExercise = false;
          });
        },
      );
    }

    final existingRows = widget.initialDetail?.rows ?? const <WorkoutSetRow>[];
    final hasRows = _draft.isNotEmpty || existingRows.isNotEmpty;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Column(
          children: [
            _Header(title: 'Kreator zestawu', onBack: widget.onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                children: [
                  const _FieldLabel('Nazwa zestawu'),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Nazwa zestawu'),
                  ),
                  const SizedBox(height: 22),
                  RelationshipSectionLabel('Ćwiczenia · ${_draft.length + existingRows.length}'),
                  const SizedBox(height: 12),
                  if (!hasRows)
                    const RelationshipCard(
                      child: Text(
                        'Dodaj pierwsze ćwiczenie do globalnego zestawu.',
                        style: TextStyle(color: lmMuted),
                      ),
                    ),
                  for (var i = 0; i < _draft.length; i += 1)
                    _DraftExerciseCard(index: i + 1, exercise: _draft[i]),
                  if (_draft.isEmpty)
                    for (final row in existingRows)
                      _ExistingRowCard(row: row),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _addingExercise = true),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Dodaj ćwiczenie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lmBlueSoft,
                      side: BorderSide(color: lmBlue.withValues(alpha: 0.45), width: 1.5),
                      backgroundColor: lmBlue.withValues(alpha: 0.08),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  if (state.status == WorkoutSetControllerStatus.error && state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(state.message!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
            _BottomAction(
              label: state.status == WorkoutSetControllerStatus.saving ? 'Zapisywanie...' : 'Zapisz zestaw',
              onPressed: state.status == WorkoutSetControllerStatus.saving ? null : _save,
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final rows = <WorkoutSetRowRequest>[];
    for (var i = 0; i < _draft.length; i += 1) {
      rows.addAll(_draft[i].toRows(i + 1));
    }

    final initialDetail = widget.initialDetail;
    if (initialDetail == null) {
      final result = await widget.controller.createSet(
        CreateWorkoutSetRequest(name: _nameController.text.trim(), rows: rows),
      );
      if (result.isSuccess && mounted) {
        widget.onBack();
      }
      return;
    }

    final updateRows = rows.isEmpty
        ? initialDetail.rows.map((row) {
            return WorkoutSetRowRequest(
              exerciseOrder: row.exerciseOrder,
              setIndex: row.setIndex,
              exerciseName: row.exerciseName,
              exerciseType: row.exerciseType,
              reps: row.reps,
              weight: row.weight,
              seconds: row.seconds,
            );
          }).toList(growable: false)
        : rows;
    final result = await widget.controller.updateSet(
      initialDetail.id,
      UpdateWorkoutSetRequest(name: _nameController.text.trim(), rows: updateRows),
    );
    if (result.isSuccess && mounted) {
      widget.onBack();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 22, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Wróć',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, color: lmMuted, size: 30),
          ),
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: lmMuted, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DraftExerciseCard extends StatelessWidget {
  const _DraftExerciseCard({required this.index, required this.exercise});

  final int index;
  final WorkoutSetDraftExercise exercise;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IndexBox(index.toString()),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(exercise.params, style: const TextStyle(color: lmMuted, fontSize: 12.5)),
              ],
            ),
          ),
          _TypeChip(exercise.typeLabel),
        ],
      ),
    );
  }
}

class _ExistingRowCard extends StatelessWidget {
  const _ExistingRowCard({required this.row});

  final WorkoutSetRow row;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IndexBox(row.exerciseOrder.toString()),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.exerciseName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('Seria ${row.setIndex}', style: const TextStyle(color: lmMuted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexBox extends StatelessWidget {
  const _IndexBox(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: lmSurfaceAlt, borderRadius: BorderRadius.circular(9)),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontWeight: FontWeight.w700,
          color: lmBlueSoft,
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lmBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(color: lmBlueSoft, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: FilledButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
