import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import '../shared_sessions/shared_session_models.dart';
import '../widgets/motion/pressable_scale.dart';
import 'workout_set_draft.dart';

class AddWorkoutSetExerciseScreen extends StatefulWidget {
  const AddWorkoutSetExerciseScreen({
    required this.onBack,
    required this.onAddExercise,
    this.initialExercise,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<WorkoutSetDraftExercise> onAddExercise;
  final WorkoutSetDraftExercise? initialExercise;

  @override
  State<AddWorkoutSetExerciseScreen> createState() =>
      _AddWorkoutSetExerciseScreenState();
}

class _AddWorkoutSetExerciseScreenState
    extends State<AddWorkoutSetExerciseScreen> {
  late final TextEditingController _nameController;
  late ExerciseValueType _type;
  late int _sets;
  late int _reps;
  late int _seconds;
  late double _weight;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExercise;
    _nameController = TextEditingController(
      text: initial?.name ?? 'Wyciskanie sztangi',
    );
    _type = initial?.exerciseType ?? ExerciseValueType.repsWeight;
    _sets = initial?.sets ?? 3;
    _reps = initial?.reps ?? 8;
    _seconds = initial?.seconds ?? 45;
    _weight = initial?.weight ?? 40;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeight = _type == ExerciseValueType.repsWeight;
    final isReps = _type == ExerciseValueType.repsOnly;
    final isTime = _type == ExerciseValueType.time;
    final isEditing = widget.initialExercise != null;

    return Column(
      children: [
        _Header(
          title: isEditing ? 'Edytuj ćwiczenie' : 'Dodaj ćwiczenie',
          onBack: widget.onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            children: [
              const _FieldLabel('Nazwa ćwiczenia'),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Nazwa ćwiczenia'),
              ),
              const SizedBox(height: 22),
              const _FieldLabel('Typ ćwiczenia'),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Powt. + waga',
                      active: isWeight,
                      onTap: () =>
                          setState(() => _type = ExerciseValueType.repsWeight),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _TypeButton(
                      label: 'Powtórzenia',
                      active: isReps,
                      onTap: () =>
                          setState(() => _type = ExerciseValueType.repsOnly),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _TypeButton(
                      label: 'Czas',
                      active: isTime,
                      onTap: () =>
                          setState(() => _type = ExerciseValueType.time),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _FieldLabel('Parametry domyślne'),
              _StepperRow(
                label: 'Serie',
                value: _sets.toString(),
                onDec: () =>
                    setState(() => _sets = (_sets - 1).clamp(1, 9).toInt()),
                onInc: () =>
                    setState(() => _sets = (_sets + 1).clamp(1, 9).toInt()),
              ),
              if (isWeight || isReps)
                _StepperRow(
                  label: 'Powtórzenia',
                  value: _reps.toString(),
                  onDec: () =>
                      setState(() => _reps = (_reps - 1).clamp(1, 99).toInt()),
                  onInc: () =>
                      setState(() => _reps = (_reps + 1).clamp(1, 99).toInt()),
                ),
              if (isWeight)
                _StepperRow(
                  label: 'Ciężar',
                  suffix: 'kg',
                  value: _weight.toStringAsFixed(0),
                  onDec: () => setState(
                    () => _weight = (_weight - 2.5).clamp(0, 500).toDouble(),
                  ),
                  onInc: () => setState(
                    () => _weight = (_weight + 2.5).clamp(0, 500).toDouble(),
                  ),
                ),
              if (isTime)
                _StepperRow(
                  label: 'Czas',
                  suffix: 'sek.',
                  value: _seconds.toString(),
                  onDec: () => setState(
                    () => _seconds = (_seconds - 5).clamp(5, 600).toInt(),
                  ),
                  onInc: () => setState(
                    () => _seconds = (_seconds + 5).clamp(5, 600).toInt(),
                  ),
                ),
            ],
          ),
        ),
        _BottomAction(
          key: ValueKey(isEditing ? 'exercise-save' : 'exercise-add'),
          label: isEditing ? 'Zapisz ćwiczenie' : 'Dodaj do zestawu',
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) {
              return;
            }

            final draftId =
                widget.initialExercise?.draftId ??
                WorkoutSetDraftExercise.create(
                  name: name,
                  exerciseType: _type,
                  sets: _sets,
                  reps: isTime ? null : _reps,
                  weight: isWeight ? _weight : null,
                  seconds: isTime ? _seconds : null,
                ).draftId;

            final initial = widget.initialExercise;
            final preservesIdentity =
                initial != null && initial.exerciseType == _type;
            widget.onAddExercise(
              WorkoutSetDraftExercise(
                draftId: draftId,
                name: name,
                exerciseType: _type,
                sets: _sets,
                exerciseId: preservesIdentity ? initial.exerciseId : null,
                rowIds: preservesIdentity ? initial.rowIds : const [],
                reps: isTime ? null : _reps,
                weight: isWeight ? _weight : null,
                seconds: isTime ? _seconds : null,
              ),
            );
          },
        ),
      ],
    );
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
          PressableScale(
            child: IconButton(
            tooltip: 'Wróć',
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: lmMuted,
              size: 30,
            ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
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
        style: const TextStyle(
          color: lmMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        foregroundColor: active ? Colors.white : lmMuted,
        backgroundColor: active ? lmBlue.withValues(alpha: 0.18) : lmSurface,
        side: BorderSide(
          color: active ? lmBlue : Colors.white.withValues(alpha: 0.08),
        ),
      ),
        child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDec,
    required this.onInc,
    this.suffix,
  });

  final String label;
  final String value;
  final String? suffix;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (suffix != null)
                    TextSpan(
                      text: ' ($suffix)',
                      style: const TextStyle(
                        color: lmMutedDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          _SmallStepButton(icon: Icons.remove_rounded, onPressed: onDec),
          SizedBox(
            width: 54,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          _SmallStepButton(
            icon: Icons.add_rounded,
            onPressed: onInc,
            primary: true,
          ),
        ],
      ),
    );
  }
}

class _SmallStepButton extends StatelessWidget {
  const _SmallStepButton({
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: IconButton.filled(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: primary ? lmBlue : lmSurfaceAlt,
          fixedSize: const Size(38, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        icon: Icon(icon),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: PressableScale(
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
