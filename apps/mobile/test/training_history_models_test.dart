import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/training_history/training_history_models.dart';

void main() {
  test('models parse list, detail, and progress responses', () {
    final page = TrainingHistoryPage.fromJson(_pageJson());
    final detail = TrainingHistorySession.fromJson(_detailJson());
    final progress = ExerciseProgress.fromJson(_progressJson());

    expect(page.items.single.workoutSetName, 'Plan A');
    expect(page.nextCursor, 'cursor-2');
    expect(detail.exercises.single.type, ExerciseValueType.repsWeight);
    expect(detail.exercises.single.series, hasLength(2));
    expect(detail.feedback?.wellbeingRating, 4);
    expect(detail.feedback?.comment, 'Ciężko, ale dobrze');
    expect(progress.points.last.delta, 5);
    expect(progress.currentValue, 45);
  });

  test('detail accepts missing feedback and explicit null feedback', () {
    final withoutKey = Map<String, Object?>.from(_detailJson())
      ..remove('feedback');
    final withNull = {..._detailJson(), 'feedback': null};

    expect(TrainingHistorySession.fromJson(withoutKey).feedback, isNull);
    expect(TrainingHistorySession.fromJson(withNull).feedback, isNull);
  });

  test('models reject missing and type-invalid fields', () {
    expect(
      () => TrainingHistoryPage.fromJson({..._pageJson(), 'items': 'invalid'}),
      throwsFormatException,
    );
    expect(
      () => TrainingHistorySession.fromJson({
        ..._detailJson(),
        'exercises': [
          {
            ...(_detailJson()['exercises'] as List).single
                as Map<String, Object?>,
            'exerciseType': 'distance',
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () =>
          ExerciseProgress.fromJson({..._progressJson(), 'currentValue': null}),
      throwsFormatException,
    );
    expect(
      () => TrainingHistorySession.fromJson({
        ..._detailJson(),
        'feedback': {
          'wellbeingRating': 6,
          'comment': null,
          'submittedAt': '2026-06-18T11:01:00Z',
        },
      }),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _pageJson() => {
  'items': [
    {
      'id': 'session-1',
      'workoutSetName': 'Plan A',
      'startedAt': '2026-06-18T10:00:00Z',
      'completedAt': '2026-06-18T10:45:00Z',
      'durationSeconds': 2700,
      'exerciseCount': 1,
      'seriesCount': 2,
    },
  ],
  'nextCursor': 'cursor-2',
};

Map<String, Object?> _detailJson() => {
  'id': 'session-1',
  'workoutSetName': 'Plan A',
  'startedAt': '2026-06-18T10:00:00Z',
  'completedAt': '2026-06-18T10:45:00Z',
  'durationSeconds': 2700,
  'exerciseCount': 1,
  'seriesCount': 2,
  'feedback': {
    'wellbeingRating': 4,
    'comment': 'Ciężko, ale dobrze',
    'submittedAt': '2026-06-18T10:46:00Z',
  },
  'exercises': [
    {
      'exerciseId': 'exercise-1',
      'exerciseName': 'Bench press',
      'exerciseType': 'repsWeight',
      'exerciseOrder': 1,
      'maximumValue': 45.0,
      'series': [
        {'setIndex': 1, 'reps': 8, 'weight': 40.0, 'seconds': null},
        {'setIndex': 2, 'reps': 8, 'weight': 45.0, 'seconds': null},
      ],
    },
  ],
};

Map<String, Object?> _progressJson() => {
  'exerciseId': 'exercise-1',
  'exerciseName': 'Bench press',
  'exerciseType': 'repsWeight',
  'unit': 'kg',
  'startValue': 40.0,
  'currentValue': 45.0,
  'overallDelta': 5.0,
  'points': [
    {
      'sessionId': 'session-1',
      'completedAt': '2026-06-17T10:45:00Z',
      'value': 40.0,
      'delta': null,
    },
    {
      'sessionId': 'session-2',
      'completedAt': '2026-06-18T10:45:00Z',
      'value': 45.0,
      'delta': 5.0,
    },
  ],
};
