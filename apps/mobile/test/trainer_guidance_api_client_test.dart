import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_api_client.dart';

void main() {
  group('TrainerGuidanceApiClient', () {
    test('lists guidance for trainee and marks guidance as read', () async {
      final seen = <String>[];
      final client = TrainerGuidanceApiClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url}');
          expect(request.headers['Authorization'], 'Bearer access-token');
          if (request.method == 'GET' &&
              request.url.path == '/trainer-guidance') {
            expect(request.url.queryParameters['traineeUserId'], 'trainee-1');
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'items': [_guidanceJson()],
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/trainer-guidance/guidance-1/read') {
            return http.Response('', 200);
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );

      final list = await client.list(
        accessToken: 'access-token',
        traineeUserId: 'trainee-1',
      );
      final read = await client.markAsRead(
        accessToken: 'access-token',
        guidanceId: 'guidance-1',
      );

      expect(list.isSuccess, isTrue);
      expect(list.data?.items.single.id, 'guidance-1');
      expect(read.isSuccess, isTrue);
      expect(seen, hasLength(2));
    });

    test('maps API and JSON failures to readable errors', () async {
      final forbidden = TrainerGuidanceApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((_) async {
          return http.Response('{"error":"Forbidden."}', 403);
        }),
      );
      final invalidJson = TrainerGuidanceApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      );

      final forbiddenResult = await forbidden.list(
        accessToken: 'token',
        traineeUserId: 'trainee-1',
      );
      final invalidJsonResult = await invalidJson.list(
        accessToken: 'token',
        traineeUserId: 'trainee-1',
      );

      expect(forbiddenResult.status, TrainerGuidanceApiStatus.forbidden);
      expect(forbiddenResult.message, 'Forbidden.');
      expect(invalidJsonResult.status, TrainerGuidanceApiStatus.error);
      expect(
        invalidJsonResult.message,
        'Invalid trainer guidance response JSON.',
      );
    });
  });
}

Map<String, Object?> _guidanceJson() {
  return {
    'id': 'guidance-1',
    'type': 'weight_stagnation',
    'traineeUserId': 'trainee-1',
    'exerciseId': 'exercise-1',
    'exerciseName': 'Bench',
    'message': 'Warto sprawdzić ciężar w ćwiczeniu Bench',
    'evidence': {'sessions': []},
    'createdAt': '2026-06-22T12:05:00Z',
  };
}
