import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_api_client.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_controller.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_models.dart';

void main() {
  group('PostWorkoutFeedbackController', () {
    test('preserves entered data after submit error', () async {
      final controller = PostWorkoutFeedbackController(
        sessionId: 'session-1',
        apiClient: _FakeFeedbackApiClient(
          result: const PostWorkoutFeedbackApiResult(
            status: PostWorkoutFeedbackApiStatus.offline,
            message: 'offline',
          ),
        ),
        accessTokenProvider: () => 'token',
      );
      addTearDown(controller.dispose);

      controller.setRating(2);
      controller.setComment('Ciężko');
      await controller.submit();

      expect(controller.state.status, PostWorkoutFeedbackStatus.error);
      expect(controller.state.wellbeingRating, 2);
      expect(controller.state.comment, 'Ciężko');
      expect(controller.state.message, 'offline');
    });

    test('blocks duplicate submit while request is in flight', () async {
      final completer = CompleterPostWorkoutFeedbackApiClient();
      final controller = PostWorkoutFeedbackController(
        sessionId: 'session-1',
        apiClient: completer,
        accessTokenProvider: () => 'token',
      );
      addTearDown(controller.dispose);
      controller.setRating(5);

      final first = controller.submit();
      final second = controller.submit();
      completer.completeSuccess();
      await Future.wait([first, second]);

      expect(completer.submitCalls, 1);
      expect(controller.state.status, PostWorkoutFeedbackStatus.submitted);
      expect(controller.state.response?.sharedSessionId, 'session-1');
    });

    test(
      'successful history submit invokes saved callback for detail refresh',
      () async {
        final refreshed = <String>[];
        final controller = PostWorkoutFeedbackController(
          sessionId: 'session-1',
          apiClient: _FakeFeedbackApiClient.success(),
          accessTokenProvider: () => 'token',
          onSaved: (sessionId) async => refreshed.add(sessionId),
        );
        addTearDown(controller.dispose);
        controller.setRating(4);

        await controller.submit();

        expect(refreshed, ['session-1']);
      },
    );
  });
}

class _FakeFeedbackApiClient extends PostWorkoutFeedbackApiClient {
  _FakeFeedbackApiClient({required this.result})
    : super(baseUrl: 'https://api.example.test');

  _FakeFeedbackApiClient.success()
    : result = PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.success,
        message: 'ok',
        statusCode: 201,
        data: PostWorkoutFeedbackResponse(
          sharedSessionId: 'session-1',
          wellbeingRating: 4,
          comment: null,
          submittedAt: DateTime.utc(2026, 6, 24, 12),
        ),
      ),
      super(baseUrl: 'https://api.example.test');

  final PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse> result;

  @override
  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>> submit({
    required String accessToken,
    required String sessionId,
    required PostWorkoutFeedbackRequest request,
  }) async {
    return result;
  }
}

class CompleterPostWorkoutFeedbackApiClient
    extends PostWorkoutFeedbackApiClient {
  CompleterPostWorkoutFeedbackApiClient()
    : super(baseUrl: 'https://api.example.test');

  final _completer =
      Completer<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>>();
  int submitCalls = 0;

  void completeSuccess() {
    _completer.complete(
      PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.success,
        message: 'ok',
        statusCode: 201,
        data: PostWorkoutFeedbackResponse(
          sharedSessionId: 'session-1',
          wellbeingRating: 5,
          comment: null,
          submittedAt: DateTime.utc(2026, 6, 24, 12),
        ),
      ),
    );
  }

  @override
  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>> submit({
    required String accessToken,
    required String sessionId,
    required PostWorkoutFeedbackRequest request,
  }) {
    submitCalls += 1;
    return _completer.future;
  }
}
