import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_models.dart';

void main() {
  group('TrainerGuidance models', () {
    test('parse weight stagnation guidance with session evidence', () {
      final guidance = TrainerGuidance.fromJson({
        'id': 'guidance-1',
        'type': 'weight_stagnation',
        'traineeUserId': 'trainee-1',
        'exerciseId': 'exercise-1',
        'exerciseName': 'Wyciskanie sztangi',
        'message': 'Warto sprawdzić ciężar w ćwiczeniu Wyciskanie sztangi',
        'evidence': {
          'sessions': [
            {
              'sessionId': 'session-1',
              'closedAt': '2026-06-20T12:00:00Z',
              'maxWeight': 40,
            },
            {
              'sessionId': 'session-2',
              'closedAt': '2026-06-21T12:00:00Z',
              'maxWeight': 45,
            },
            {
              'sessionId': 'session-3',
              'closedAt': '2026-06-22T12:00:00Z',
              'maxWeight': 40,
            },
          ],
        },
        'createdAt': '2026-06-22T12:05:00Z',
      });

      expect(guidance.id, 'guidance-1');
      expect(guidance.type, TrainerGuidanceType.weightStagnation);
      expect(guidance.exerciseName, 'Wyciskanie sztangi');
      expect(guidance.weightEvidence.map((item) => item.maxWeight), [
        40.0,
        45.0,
        40.0,
      ]);
      expect(guidance.wellbeingEvidence, isEmpty);
    });

    test('parse low wellbeing guidance with average and ratings', () {
      final guidance = TrainerGuidance.fromJson({
        'id': 'guidance-2',
        'type': 'low_wellbeing',
        'traineeUserId': 'trainee-1',
        'exerciseId': null,
        'exerciseName': null,
        'message':
            'Średnia ocena samopoczucia z ostatnich treningów wynosi 3.0/5',
        'evidence': {
          'averageRating': 3,
          'sessions': [
            {
              'sessionId': 'session-1',
              'closedAt': '2026-06-20T12:00:00Z',
              'rating': 3,
            },
            {
              'sessionId': 'session-2',
              'closedAt': '2026-06-21T12:00:00Z',
              'rating': 2,
            },
            {
              'sessionId': 'session-3',
              'closedAt': '2026-06-22T12:00:00Z',
              'rating': 4,
            },
          ],
        },
        'createdAt': '2026-06-22T12:05:00Z',
      });

      expect(guidance.type, TrainerGuidanceType.lowWellbeing);
      expect(guidance.averageRating, 3.0);
      expect(guidance.wellbeingEvidence.map((item) => item.rating), [3, 2, 4]);
      expect(guidance.weightEvidence, isEmpty);
    });
  });
}
