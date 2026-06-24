import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_api_client.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_models.dart';

void main() {
  group('PostWorkoutFeedbackApiClient', () {
    test(
      'sends path, bearer token, body and parses created response',
      () async {
        final client = PostWorkoutFeedbackApiClient(
          baseUrl: 'https://api.example.test/',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://api.example.test/shared-sessions/session-1/feedback',
            );
            expect(request.headers['Authorization'], 'Bearer access-token');
            expect(jsonDecode(request.body), {
              'wellbeingRating': 4,
              'comment': 'Mocny trening',
            });
            return http.Response(jsonEncode(_responseJson()), 201);
          }),
        );

        final result = await client.submit(
          accessToken: 'access-token',
          sessionId: 'session-1',
          request: const PostWorkoutFeedbackRequest(
            wellbeingRating: 4,
            comment: ' Mocny trening ',
          ),
        );

        expect(result.status, PostWorkoutFeedbackApiStatus.success);
        expect(result.statusCode, 201);
        expect(result.data?.sharedSessionId, 'session-1');
      },
    );

    test('maps replay and expected failure statuses', () async {
      final responses = <int>[200, 400, 404, 409];
      final client = PostWorkoutFeedbackApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          final status = responses.removeAt(0);
          if (status == 200) {
            return http.Response(jsonEncode(_responseJson()), status);
          }
          return http.Response('{"error":"status $status"}', status);
        }),
      );

      final replay = await client.submit(
        accessToken: 'access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );
      final badRequest = await client.submit(
        accessToken: 'access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );
      final notFound = await client.submit(
        accessToken: 'access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );
      final conflict = await client.submit(
        accessToken: 'access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );

      expect(replay.status, PostWorkoutFeedbackApiStatus.success);
      expect(badRequest.status, PostWorkoutFeedbackApiStatus.badRequest);
      expect(notFound.status, PostWorkoutFeedbackApiStatus.notFound);
      expect(conflict.status, PostWorkoutFeedbackApiStatus.conflict);
    });

    test('maps offline without leaking bearer token', () async {
      final client = PostWorkoutFeedbackApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          throw http.ClientException('network down', request.url);
        }),
      );

      final result = await client.submit(
        accessToken: 'secret-access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );

      expect(result.status, PostWorkoutFeedbackApiStatus.offline);
      expect(result.message, isNot(contains('secret-access-token')));
    });

    test('maps timeout as offline', () async {
      final client = PostWorkoutFeedbackApiClient(
        baseUrl: 'https://api.example.test',
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(jsonEncode(_responseJson()), 201);
        }),
      );

      final result = await client.submit(
        accessToken: 'access-token',
        sessionId: 'session-1',
        request: const PostWorkoutFeedbackRequest(wellbeingRating: 4),
      );

      expect(result.status, PostWorkoutFeedbackApiStatus.offline);
    });
  });
}

Map<String, Object?> _responseJson() => {
  'sharedSessionId': 'session-1',
  'wellbeingRating': 4,
  'comment': 'Mocny trening',
  'submittedAt': '2026-06-24T12:00:00Z',
};
