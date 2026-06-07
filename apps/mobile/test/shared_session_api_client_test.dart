import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';

void main() {
  group('SharedSessionApiClient', () {
    test('create sends trainee email with bearer token and parses session', () async {
      final client = SharedSessionApiClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/shared-sessions');
          expect(request.headers['Authorization'], 'Bearer access-token');
          expect(jsonDecode(request.body), {
            'traineeEmail': 'trainee@example.test',
            'values': [
              {
                'exerciseName': 'Bench press',
                'exerciseType': 'repsWeight',
                'setIndex': 1,
                'reps': 6,
                'weight': 40.0,
                'seconds': null,
              },
            ],
          });

          return http.Response(jsonEncode(_sessionJson()), 201);
        }),
      );

      final result = await client.create(
        accessToken: 'access-token',
        traineeEmail: 'trainee@example.test',
        values: const [
          CreateSharedSessionValue(
            exerciseName: 'Bench press',
            exerciseType: ExerciseValueType.repsWeight,
            setIndex: 1,
            reps: 6,
            weight: 40,
          ),
        ],
      );

      expect(result.status, SharedSessionApiStatus.success);
      expect(result.data?.id, 'session-1');
    });

    test('getActive, get, update, complete, and cancel use expected paths', () async {
      final seen = <String>[];
      final client = SharedSessionApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          expect(request.headers['Authorization'], 'Bearer access-token');

          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {
              'reps': 8,
              'weight': 42.5,
              'seconds': null,
            });
          }

          return http.Response(jsonEncode(_sessionJson()), 200);
        }),
      );

      await client.getActive(accessToken: 'access-token');
      await client.get(accessToken: 'access-token', sessionId: 'session-1');
      await client.updateValue(
        accessToken: 'access-token',
        sessionId: 'session-1',
        valueId: 'value-1',
        value: const UpdateSharedSessionValue(reps: 8, weight: 42.5),
      );
      await client.complete(accessToken: 'access-token', sessionId: 'session-1');
      await client.cancel(accessToken: 'access-token', sessionId: 'session-1');

      expect(seen, [
        'GET /shared-sessions/active',
        'GET /shared-sessions/session-1',
        'PATCH /shared-sessions/session-1/values/value-1',
        'POST /shared-sessions/session-1/complete',
        'POST /shared-sessions/session-1/cancel',
      ]);
    });

    test('maps conflict response without leaking bearer token', () async {
      final client = SharedSessionApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('{"error":"Shared session is not active."}', 409);
        }),
      );

      final result = await client.updateValue(
        accessToken: 'secret-access-token',
        sessionId: 'session-1',
        valueId: 'value-1',
        value: const UpdateSharedSessionValue(reps: 8, weight: 42.5),
      );

      expect(result.status, SharedSessionApiStatus.conflict);
      expect(result.message, contains('not active'));
      expect(result.message, isNot(contains('secret-access-token')));
    });

    test('returns error when API base URL is missing', () async {
      final client = SharedSessionApiClient(
        baseUrl: '',
        httpClient: MockClient((request) async {
          fail('HTTP client should not be called without a base URL');
        }),
      );

      final result = await client.get(
        accessToken: 'access-token',
        sessionId: 'session-1',
      );

      expect(result.status, SharedSessionApiStatus.error);
      expect(result.message, contains('API_BASE_URL'));
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
    'status': 'active',
    'version': 1,
    'createdAt': '2026-06-03T12:00:00Z',
    'updatedAt': '2026-06-03T12:00:00Z',
    'closedAt': null,
    'values': [
      {
        'id': 'value-1',
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'setIndex': 1,
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
        'updatedByUserId': null,
        'updatedAt': null,
      },
    ],
  };
}
