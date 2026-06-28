import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/relationships/relationship_models.dart';

void main() {
  test('weekly streak parses nullable dates and stable values', () {
    final summary = WeeklyStreakSummary.fromJson({
      'currentStreak': 4,
      'bestStreak': 7,
      'lastActiveWeekStart': '2026-06-22',
      'lastCompletedWorkoutAt': null,
      'isActiveThisWeek': true,
    });

    expect(summary.currentStreak, 4);
    expect(summary.bestStreak, 7);
    expect(summary.lastActiveWeekStart, DateTime(2026, 6, 22));
    expect(summary.lastCompletedWorkoutAt, isNull);
    expect(summary.isActiveThisWeek, isTrue);
  });

  test('weekly streak rejects invalid field types', () {
    expect(
      () => WeeklyStreakSummary.fromJson({
        'currentStreak': '4',
        'bestStreak': 7,
        'lastActiveWeekStart': null,
        'lastCompletedWorkoutAt': null,
        'isActiveThisWeek': false,
      }),
      throwsFormatException,
    );
  });

  test('trainer and trainee relationship models include weekly streak', () {
    final trainer = TrainerRelationshipSummary.fromJson({
      'inviteCode': '7F2K9D',
      'trainees': [
        {
          'id': 'trainee-1',
          'email': 'anna@example.test',
          'displayName': 'Anna Nowak',
          'weeklyStreak': _weeklyStreakJson(current: 6, best: 11),
        },
      ],
    });
    final trainee = TraineeRelationshipSummary.fromJson({
      'trainer': null,
      'weeklyStreak': _weeklyStreakJson(current: 3, best: 8),
    });

    expect(trainer.trainees.single.weeklyStreak.currentStreak, 6);
    expect(trainee.weeklyStreak.bestStreak, 8);
  });
}

Map<String, Object?> _weeklyStreakJson({
  required int current,
  required int best,
}) {
  return {
    'currentStreak': current,
    'bestStreak': best,
    'lastActiveWeekStart': '2026-06-22',
    'lastCompletedWorkoutAt': '2026-06-24T10:00:00Z',
    'isActiveThisWeek': true,
  };
}
