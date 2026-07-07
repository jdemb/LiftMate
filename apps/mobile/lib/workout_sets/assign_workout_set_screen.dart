import 'package:flutter/material.dart';

import '../relationships/relationship_models.dart';
import '../relationships/relationship_screen_styles.dart';
import '../widgets/motion/motion_reveals.dart';
import '../widgets/motion/pressable_scale.dart';
import 'workout_set_controller.dart';
import 'workout_set_models.dart';

class AssignWorkoutSetScreen extends StatefulWidget {
  const AssignWorkoutSetScreen({
    required this.controller,
    required this.workoutSet,
    required this.trainees,
    required this.onBack,
    super.key,
  });

  final WorkoutSetController controller;
  final WorkoutSetDetail workoutSet;
  final List<TrainerTraineeSummary> trainees;
  final VoidCallback onBack;

  @override
  State<AssignWorkoutSetScreen> createState() => _AssignWorkoutSetScreenState();
}

class _AssignWorkoutSetScreenState extends State<AssignWorkoutSetScreen> {
  late final Set<String> _selected = widget.workoutSet.assignments
      .map((assignment) => assignment.traineeUserId)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Column(
          children: [
            _Header(title: 'Przypisz zestaw', onBack: widget.onBack),
            Expanded(
              child: MotionStaggerScope(
                child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                children: [
                  RelationshipCard(
                    borderColor: lmBlue.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RelationshipSectionLabel('Zestaw'),
                        const SizedBox(height: 5),
                        Text(
                          widget.workoutSet.name,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.workoutSet.rows.length} serii · szablon globalny',
                          style: const TextStyle(color: lmMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const RelationshipSectionLabel('Wybierz podopiecznych'),
                  const SizedBox(height: 12),
                  if (widget.trainees.isEmpty)
                    const RelationshipCard(
                      child: Text(
                        'Brak podopiecznych do przypisania.',
                        style: TextStyle(color: lmMuted),
                      ),
                    )
                  else
                    for (final trainee in widget.trainees)
                      StaggeredReveal(
                        position: widget.trainees.indexOf(trainee),
                        child: _TraineeAssignRow(
                          trainee: trainee,
                          selected: _selected.contains(trainee.id),
                          onTap: () {
                            setState(() {
                              if (!_selected.add(trainee.id)) {
                                _selected.remove(trainee.id);
                              }
                            });
                          },
                        ),
                      ),
                  if (state.status == WorkoutSetControllerStatus.error && state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(state.message!, style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
                ),
              ),
            ),
            _BottomAction(
              label: state.status == WorkoutSetControllerStatus.saving
                  ? 'Zapisywanie...'
                  : 'Zapisz (${_selected.length})',
              onPressed: state.status == WorkoutSetControllerStatus.saving
                  ? null
                  : () async {
                      final result = await widget.controller.syncAssignments(
                        widget.workoutSet.id,
                        _selected.toList(growable: false),
                      );
                      if (result.isSuccess && mounted) {
                        widget.onBack();
                      }
                    },
            ),
          ],
        );
      },
    );
  }
}

class _TraineeAssignRow extends StatelessWidget {
  const _TraineeAssignRow({
    required this.trainee,
    required this.selected,
    required this.onTap,
  });

  final TrainerTraineeSummary trainee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(13),
            backgroundColor: selected
                ? lmBlue.withValues(alpha: 0.12)
                : lmSurface,
            side: BorderSide(
              color: selected ? lmBlue : Colors.white.withValues(alpha: 0.07),
            ),
            minimumSize: const Size.fromHeight(68),
          ),
          child: Row(
            children: [
              RelationshipAvatar(label: trainee.displayName, size: 42),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  trainee.displayName,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: lmText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? lmBlueSoft : lmMutedDark,
              ),
            ],
          ),
        ),
      ),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ],
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
      child: PressableScale(
        enabled: onPressed != null,
        child: FilledButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
