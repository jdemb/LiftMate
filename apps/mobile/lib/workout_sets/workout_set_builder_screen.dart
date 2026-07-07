import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import '../widgets/motion/pressable_scale.dart';
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
  late final List<WorkoutSetDraftExercise> _draft;
  late int _restSeconds;
  bool _showingExerciseEditor = false;
  String? _editingDraftId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDetail?.name ?? 'Push A');
    _draft = _draftFromDetail(widget.initialDetail);
    _restSeconds = widget.initialDetail?.restSeconds ?? 90;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingExerciseEditor) {
      return AddWorkoutSetExerciseScreen(
        initialExercise: _editingExercise,
        onBack: _closeExerciseEditor,
        onAddExercise: _saveDraftExercise,
      );
    }

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
                  const SizedBox(height: 18),
                  const _FieldLabel('Czas odpoczynku'),
                  _RestSecondsField(
                    seconds: _restSeconds,
                    onDecrease: () => _changeRestSeconds(-15),
                    onIncrease: () => _changeRestSeconds(15),
                  ),
                  const SizedBox(height: 22),
                  RelationshipSectionLabel('Ćwiczenia · ${_draft.length}'),
                  const SizedBox(height: 12),
                  if (_draft.isEmpty)
                    const RelationshipCard(
                      child: Text(
                        'Dodaj pierwsze ćwiczenie do globalnego zestawu.',
                        style: TextStyle(color: lmMuted),
                      ),
                    ),
                  for (var i = 0; i < _draft.length; i += 1)
                    _DraftExerciseCard(
                      index: i + 1,
                      exercise: _draft[i],
                      onTap: () => _openExerciseEditor(_draft[i].draftId),
                      onDelete: () => _deleteDraftExercise(_draft[i].draftId),
                    ),
                  const SizedBox(height: 4),
                  PressableScale(
                    child: OutlinedButton.icon(
                    key: const ValueKey('builder-add-exercise'),
                    onPressed: () => _openExerciseEditor(null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Dodaj ćwiczenie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lmBlueSoft,
                      side: BorderSide(color: lmBlue.withValues(alpha: 0.45), width: 1.5),
                      backgroundColor: lmBlue.withValues(alpha: 0.08),
                      minimumSize: const Size.fromHeight(52),
                    ),
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
              key: const ValueKey('builder-save'),
              label: state.status == WorkoutSetControllerStatus.saving ? 'Zapisywanie...' : 'Zapisz zestaw',
              onPressed: state.status == WorkoutSetControllerStatus.saving ? null : _save,
            ),
          ],
        );
      },
    );
  }

  WorkoutSetDraftExercise? get _editingExercise {
    final draftId = _editingDraftId;
    if (draftId == null) {
      return null;
    }

    for (final exercise in _draft) {
      if (exercise.draftId == draftId) {
        return exercise;
      }
    }

    return null;
  }

  void _openExerciseEditor(String? draftId) {
    setState(() {
      _editingDraftId = draftId;
      _showingExerciseEditor = true;
    });
  }

  void _closeExerciseEditor() {
    setState(() {
      _editingDraftId = null;
      _showingExerciseEditor = false;
    });
  }

  void _saveDraftExercise(WorkoutSetDraftExercise exercise) {
    setState(() {
      final index = _draft.indexWhere((draft) => draft.draftId == exercise.draftId);
      if (index == -1) {
        _draft.add(exercise);
      } else {
        _draft[index] = exercise;
      }
      _editingDraftId = null;
      _showingExerciseEditor = false;
    });
  }

  void _deleteDraftExercise(String draftId) {
    setState(() {
      _draft.removeWhere((exercise) => exercise.draftId == draftId);
    });
  }

  void _changeRestSeconds(int delta) {
    setState(() {
      _restSeconds = (_restSeconds + delta).clamp(15, 600);
    });
  }

  Future<void> _save() async {
    final rows = <WorkoutSetRowRequest>[];
    for (var i = 0; i < _draft.length; i += 1) {
      rows.addAll(_draft[i].toRows(i + 1));
    }

    final initialDetail = widget.initialDetail;
    if (initialDetail == null) {
      final result = await widget.controller.createSet(
        CreateWorkoutSetRequest(
          name: _nameController.text.trim(),
          rows: rows,
          restSeconds: _restSeconds,
        ),
      );
      if (result.isSuccess && mounted) {
        widget.onBack();
      }
      return;
    }

    final result = await widget.controller.updateSet(
      initialDetail.id,
      UpdateWorkoutSetRequest(
        name: _nameController.text.trim(),
        rows: rows,
        restSeconds: _restSeconds,
      ),
    );
    if (result.isSuccess && mounted) {
      widget.onBack();
    }
  }
}

List<WorkoutSetDraftExercise> _draftFromDetail(WorkoutSetDetail? detail) {
  final rows = detail?.rows ?? const <WorkoutSetRow>[];
  if (rows.isEmpty) {
    return <WorkoutSetDraftExercise>[];
  }

  final grouped = <int, List<WorkoutSetRow>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.exerciseOrder, () => <WorkoutSetRow>[]).add(row);
  }

  final orders = grouped.keys.toList()..sort();
  return [
    for (final order in orders)
      WorkoutSetDraftExercise.fromRows(order, grouped[order]!),
  ];
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
          PressableScale(
            child: IconButton(
            tooltip: 'Wróć',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, color: lmMuted, size: 30),
            ),
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

class _RestSecondsField extends StatelessWidget {
  const _RestSecondsField({
    required this.seconds,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int seconds;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          PressableScale(
            enabled: seconds > 15,
            child: IconButton.outlined(
            key: const ValueKey('builder-rest-decrease'),
            onPressed: seconds <= 15 ? null : onDecrease,
            icon: const Icon(Icons.remove_rounded),
            ),
          ),
          Expanded(
            child: Text(
              formatRestSeconds(seconds),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PressableScale(
            enabled: seconds < 600,
            child: IconButton.filled(
            key: const ValueKey('builder-rest-increase'),
            onPressed: seconds >= 600 ? null : onIncrease,
            icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

String formatRestSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainder.toString().padLeft(2, '0')}';
}

class _DraftExerciseCard extends StatelessWidget {
  const _DraftExerciseCard({
    required this.index,
    required this.exercise,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final WorkoutSetDraftExercise exercise;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Usuń ćwiczenie',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: lmMuted,
                ),
              ],
            ),
          ),
        ),
      ),
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
  const _BottomAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

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
      child: PressableScale(
        enabled: onPressed != null,
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
