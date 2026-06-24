import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_models.dart';

void main() {
  group('post-workout feedback models', () {
    test('request serializes rating and trimmed nullable comment', () {
      expect(
        const PostWorkoutFeedbackRequest(
          wellbeingRating: 4,
          comment: '  Mocny trening  ',
        ).toJson(),
        {'wellbeingRating': 4, 'comment': 'Mocny trening'},
      );
      expect(
        const PostWorkoutFeedbackRequest(
          wellbeingRating: 3,
          comment: '   ',
        ).toJson(),
        {'wellbeingRating': 3, 'comment': null},
      );
    });

    test('request rejects invalid rating and too long comment', () {
      expect(
        () => const PostWorkoutFeedbackRequest(wellbeingRating: 0).toJson(),
        throwsFormatException,
      );
      expect(
        () => PostWorkoutFeedbackRequest(
          wellbeingRating: 6,
          comment: 'x' * 1001,
        ).toJson(),
        throwsFormatException,
      );
    });

    test('response parses session id, rating, comment, and submitted time', () {
      final response = PostWorkoutFeedbackResponse.fromJson({
        'sharedSessionId': 'session-1',
        'wellbeingRating': 5,
        'comment': null,
        'submittedAt': '2026-06-24T12:00:00Z',
      });

      expect(response.sharedSessionId, 'session-1');
      expect(response.wellbeingRating, 5);
      expect(response.comment, isNull);
      expect(response.submittedAt, DateTime.parse('2026-06-24T12:00:00Z'));
    });

    test('response rejects invalid fields', () {
      expect(
        () => PostWorkoutFeedbackResponse.fromJson({
          'sharedSessionId': 'session-1',
          'wellbeingRating': 7,
          'comment': null,
          'submittedAt': '2026-06-24T12:00:00Z',
        }),
        throwsFormatException,
      );
      expect(
        () => PostWorkoutFeedbackResponse.fromJson({
          'sharedSessionId': 'session-1',
          'wellbeingRating': 5,
          'comment': 123,
          'submittedAt': '2026-06-24T12:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });
}
