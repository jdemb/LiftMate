import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';

void main() {
  group('SharedSession models', () {
    test('parses valid shared session snapshot', () {
      final session = SharedSession.fromJson(_sessionJson());

      expect(session.id, 'session-1');
      expect(session.trainerUserId, 'trainer-1');
      expect(session.traineeUserId, 'trainee-1');
      expect(session.trainerEmail, 'trainer@example.test');
      expect(session.traineeEmail, 'trainee@example.test');
      expect(session.workoutSetId, 'set-1');
      expect(session.startedByUserId, 'trainee-1');
      expect(session.startedByRole, SharedSessionStartRole.trainee);
      expect(session.isTraineeSelfStarted, isTrue);
      expect(session.status, SharedSessionStatus.active);
      expect(session.version, 3);
      expect(session.closedAt, isNull);
      expect(session.values, hasLength(1));
      expect(session.values.single.exerciseType, ExerciseValueType.repsWeight);
      expect(session.values.single.exerciseOrder, 1);
      expect(session.values.single.reps, 8);
      expect(session.values.single.weight, 42.5);
      expect(session.values.single.seconds, isNull);
      expect(session.values.single.isDone, isTrue);
      expect(session.values.single.completedAt, isNotNull);
    });

    test('rejects invalid status and exercise type', () {
      expect(
        () => SharedSession.fromJson({
          ..._sessionJson(),
          'status': 'paused',
        }),
        throwsFormatException,
      );

      expect(
        () => SharedSession.fromJson({
          ..._sessionJson(),
          'values': [
            {
              ...(_sessionJson()['values'] as List<Map<String, Object?>>).single,
              'exerciseType': 'distance',
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test('preserves nullable value fields for time values', () {
      final session = SharedSession.fromJson({
        ..._sessionJson(),
        'status': 'completed',
        'closedAt': '2026-06-03T12:05:00Z',
        'values': [
          {
            'id': 'value-2',
            'exerciseName': 'Plank',
            'exerciseType': 'time',
            'exerciseOrder': 2,
            'setIndex': 1,
            'reps': null,
            'weight': null,
            'seconds': 60,
            'isDone': false,
            'completedAt': null,
            'updatedByUserId': null,
            'updatedAt': null,
          },
        ],
      });

      expect(session.status, SharedSessionStatus.completed);
      expect(session.closedAt, DateTime.parse('2026-06-03T12:05:00Z').toUtc());
      expect(session.values.single.exerciseType, ExerciseValueType.time);
      expect(session.values.single.reps, isNull);
      expect(session.values.single.weight, isNull);
      expect(session.values.single.seconds, 60);
    });
  });
}

Map<String, Object?> _sessionJson() {
  return {
    'id': 'session-1',
    'trainerUserId': 'trainer-1',
    'traineeUserId': 'trainee-1',
    'trainerEmail': 'trainer@example.test',
    'traineeEmail': 'trainee@example.test',
    'workoutSetId': 'set-1',
    'startedByUserId': 'trainee-1',
    'startedByRole': 'trainee',
    'status': 'active',
    'version': 3,
    'createdAt': '2026-06-03T12:00:00Z',
    'updatedAt': '2026-06-03T12:01:00Z',
    'closedAt': null,
    'values': [
      {
        'id': 'value-1',
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'exerciseOrder': 1,
        'setIndex': 1,
        'reps': 8,
        'weight': 42.5,
        'seconds': null,
        'isDone': true,
        'completedAt': '2026-06-03T12:01:00Z',
        'updatedByUserId': 'trainer-1',
        'updatedAt': '2026-06-03T12:01:00Z',
      },
    ],
  };
}
