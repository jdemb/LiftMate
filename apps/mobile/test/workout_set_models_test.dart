import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/workout_sets/workout_set_draft.dart';
import 'package:liftmate/workout_sets/workout_set_models.dart';

void main() {
  group('Workout set models', () {
    test('parse detail orders and exercise type wire names strictly', () {
      final detail = WorkoutSetDetail.fromJson(_detailJson());

      expect(detail.id, 'set-1');
      expect(detail.restSeconds, 90);
      expect(detail.rows.first.exerciseId, 'exercise-1');
      expect(detail.rows.map((row) => row.exerciseType), [
        ExerciseValueType.repsWeight,
        ExerciseValueType.repsOnly,
        ExerciseValueType.time,
      ]);
      expect(detail.assignments.single.traineeDisplayName, 'Anna Nowak');
      expect(detail.updatedAt, DateTime.parse('2026-06-16T12:05:00Z').toUtc());
    });

    test('rejects invalid exercise type', () {
      final json = _detailJson();
      final rows = json['rows']! as List<Map<String, Object?>>;
      rows[0] = {...rows[0], 'exerciseType': 'distance'};

      expect(
        () => WorkoutSetDetail.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('request JSON uses shared exercise type wire names', () {
      const row = WorkoutSetRowRequest(
        id: 'row-1',
        exerciseId: 'exercise-1',
        exerciseOrder: 1,
        setIndex: 1,
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        reps: 6,
        weight: 40,
      );
      const request = CreateWorkoutSetRequest(
        name: 'Push A',
        restSeconds: 120,
        rows: [row],
      );

      expect(ExerciseValueType.repsWeight.wireName, 'repsWeight');
      expect(ExerciseValueType.repsOnly.wireName, 'repsOnly');
      expect(ExerciseValueType.time.wireName, 'time');
      expect(request.toJson(), {
        'name': 'Push A',
        'restSeconds': 120,
        'rows': [
          {
            'id': 'row-1',
            'exerciseId': 'exercise-1',
            'exerciseOrder': 1,
            'setIndex': 1,
            'exerciseName': 'Bench press',
            'exerciseType': 'repsWeight',
            'reps': 6,
            'weight': 40.0,
            'seconds': null,
          },
        ],
      });
    });

    test('parses trainee assigned workout set response', () {
      final assigned = TraineeAssignedWorkoutSet.fromJson(
        _traineeAssignedJson(),
      );

      expect(assigned.id, 'set-1');
      expect(assigned.restSeconds, 90);
      expect(assigned.trainerDisplayName, 'Test Trainer');
      expect(assigned.rows.map((row) => row.exerciseName), [
        'Bench press',
        'Pull up',
        'Plank',
      ]);
    });

    test(
      'existing draft preserves exercise and row identifiers while added series omits row id',
      () {
        final rows = _rowsJson()
            .take(1)
            .map(WorkoutSetRow.fromJson)
            .toList(growable: false);
        final draft = WorkoutSetDraftExercise.fromRows(1, rows);
        final expanded = WorkoutSetDraftExercise(
          draftId: draft.draftId,
          exerciseId: draft.exerciseId,
          rowIds: draft.rowIds,
          name: draft.name,
          exerciseType: draft.exerciseType,
          sets: 2,
          reps: draft.reps,
          weight: draft.weight,
        );

        final requests = expanded.toRows(1);

        expect(requests[0].id, 'row-1');
        expect(requests[0].exerciseId, 'exercise-1');
        expect(requests[1].id, isNull);
        expect(requests[1].exerciseId, 'exercise-1');
      },
    );

    test('parses configured rest time and falls back to 90 seconds', () {
      expect(
        WorkoutSetDetail.fromJson({
          ..._detailJson(),
          'restSeconds': 75,
        }).restSeconds,
        75,
      );
      expect(
        TraineeAssignedWorkoutSet.fromJson({
          ..._traineeAssignedJson(),
          'restSeconds': 105,
        }).restSeconds,
        105,
      );
    });
  });
}

Map<String, Object?> _detailJson() {
  return {
    'id': 'set-1',
    'name': 'Full body A',
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
    'rows': _rowsJson(),
    'assignments': [
      {
        'traineeUserId': 'trainee-1',
        'traineeEmail': 'anna@example.test',
        'traineeDisplayName': 'Anna Nowak',
        'assignedAt': '2026-06-16T12:10:00Z',
      },
    ],
  };
}

Map<String, Object?> _traineeAssignedJson() {
  return {
    'id': 'set-1',
    'name': 'Full body A',
    'trainerDisplayName': 'Test Trainer',
    'rows': _rowsJson(),
    'assignedAt': '2026-06-16T12:10:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

List<Map<String, Object?>> _rowsJson() {
  return [
    {
      'id': 'row-1',
      'exerciseId': 'exercise-1',
      'exerciseOrder': 1,
      'setIndex': 1,
      'exerciseName': 'Bench press',
      'exerciseType': 'repsWeight',
      'reps': 6,
      'weight': 40.0,
      'seconds': null,
    },
    {
      'id': 'row-2',
      'exerciseId': 'exercise-2',
      'exerciseOrder': 2,
      'setIndex': 1,
      'exerciseName': 'Pull up',
      'exerciseType': 'repsOnly',
      'reps': 8,
      'weight': null,
      'seconds': null,
    },
    {
      'id': 'row-3',
      'exerciseId': 'exercise-3',
      'exerciseOrder': 3,
      'setIndex': 1,
      'exerciseName': 'Plank',
      'exerciseType': 'time',
      'reps': null,
      'weight': null,
      'seconds': 60,
    },
  ];
}
