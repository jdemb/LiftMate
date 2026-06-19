import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/training_history/training_history_api_client.dart';

void main() {
  test(
    'client sends encoded cursor and trainee target for list and progress',
    () async {
      final seen = <Uri>[];
      final client = TrainingHistoryApiClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          seen.add(request.url);
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.url.path.endsWith('/sessions')) {
            return http.Response(
              jsonEncode({'items': [], 'nextCursor': null}),
              200,
            );
          }
          if (request.url.path.contains('/sessions/')) {
            return http.Response(jsonEncode(_detailJson()), 200);
          }
          return http.Response(jsonEncode(_progressJson()), 200);
        }),
      );

      await client.list(
        accessToken: 'token',
        traineeUserId: 'trainee +1',
        cursor: 'cursor /2',
      );
      await client.detail(accessToken: 'token', sessionId: 'session-1');
      await client.progress(
        accessToken: 'token',
        exerciseId: 'exercise-1',
        traineeUserId: 'trainee +1',
      );

      expect(seen[0].queryParameters, {
        'traineeUserId': 'trainee +1',
        'cursor': 'cursor /2',
      });
      expect(seen[1].queryParameters, isEmpty);
      expect(seen[2].queryParameters, {'traineeUserId': 'trainee +1'});
    },
  );
}

Map<String, Object?> _detailJson() => {
  'id': 'session-1',
  'workoutSetName': 'Plan',
  'startedAt': '2026-06-18T10:00:00Z',
  'completedAt': '2026-06-18T11:00:00Z',
  'durationSeconds': 3600,
  'exerciseCount': 0,
  'seriesCount': 0,
  'exercises': <Object?>[],
};

Map<String, Object?> _progressJson() => {
  'exerciseId': 'exercise-1',
  'exerciseName': 'Bench',
  'exerciseType': 'repsWeight',
  'unit': 'kg',
  'startValue': 40,
  'currentValue': 40,
  'overallDelta': 0,
  'points': <Object?>[],
};
