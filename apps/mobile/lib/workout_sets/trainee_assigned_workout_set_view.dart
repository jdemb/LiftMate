import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import '../widgets/motion/pressable_scale.dart';
import '../shared_sessions/shared_session_models.dart';
import 'workout_set_models.dart';
import 'workout_set_text.dart';

class TraineeAssignedWorkoutSetView extends StatelessWidget {
  const TraineeAssignedWorkoutSetView({
    required this.sets,
    required this.activeSession,
    required this.onStartWorkout,
    required this.onJoinActiveWorkout,
    super.key,
  });

  final List<TraineeAssignedWorkoutSet> sets;
  final SharedSession? activeSession;
  final ValueChanged<TraineeAssignedWorkoutSet> onStartWorkout;
  final VoidCallback onJoinActiveWorkout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final set in sets)
          _AssignedSetCard(
            set: set,
            activeSession: activeSession,
            onStartWorkout: () => onStartWorkout(set),
            onJoinActiveWorkout: onJoinActiveWorkout,
          ),
      ],
    );
  }
}

class _AssignedSetCard extends StatelessWidget {
  const _AssignedSetCard({
    required this.set,
    required this.activeSession,
    required this.onStartWorkout,
    required this.onJoinActiveWorkout,
  });

  final TraineeAssignedWorkoutSet set;
  final SharedSession? activeSession;
  final VoidCallback onStartWorkout;
  final VoidCallback onJoinActiveWorkout;

  @override
  Widget build(BuildContext context) {
    final exerciseCount = set.rows.map((row) => row.exerciseOrder).toSet().length;
    final grouped = _groupRows(set.rows);

    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: lmBlue.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RelationshipSectionLabel('Dzisiejszy trening'),
          const SizedBox(height: 6),
          Text(
            set.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
              fontSize: 25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${exerciseCountLabel(exerciseCount)} · ${set.rows.length} serii · prowadzi ${set.trainerDisplayName}',
            style: const TextStyle(color: lmMuted, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          for (final entry in grouped.entries)
            _ExercisePreview(
              index: entry.key,
              rows: entry.value,
            ),
          const SizedBox(height: 16),
          PressableScale(
            child: FilledButton.icon(
              onPressed: activeSession == null
                  ? onStartWorkout
                  : onJoinActiveWorkout,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                activeSession == null
                    ? 'Rozpocznij trening'
                    : 'Dołącz do aktywnego treningu',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({
    required this.index,
    required this.rows,
  });

  final int index;
  final List<WorkoutSetRow> rows;

  @override
  Widget build(BuildContext context) {
    final first = rows.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lmSurfaceAlt,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              index.toString(),
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: lmBlueSoft,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              first.exerciseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFDFE2E7), fontSize: 13.5),
            ),
          ),
          Text(
            _params(rows),
            style: const TextStyle(color: lmMutedDark, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _params(List<WorkoutSetRow> rows) {
    final first = rows.first;
    return switch (first.exerciseType) {
      ExerciseValueType.repsWeight => '${rows.length}x ${first.reps} · ${first.weight?.toStringAsFixed(0)} kg',
      ExerciseValueType.repsOnly => '${rows.length}x ${first.reps}',
      ExerciseValueType.time => '${rows.length}x ${first.seconds}s',
    };
  }
}

Map<int, List<WorkoutSetRow>> _groupRows(List<WorkoutSetRow> rows) {
  final sorted = [...rows]..sort((a, b) {
      final order = a.exerciseOrder.compareTo(b.exerciseOrder);
      if (order != 0) {
        return order;
      }

      return a.setIndex.compareTo(b.setIndex);
    });
  final grouped = <int, List<WorkoutSetRow>>{};
  for (final row in sorted) {
    grouped.putIfAbsent(row.exerciseOrder, () => []).add(row);
  }

  return grouped;
}
