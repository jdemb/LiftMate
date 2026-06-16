import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';

void main() {
  group('RelationshipApiClient', () {
    test('trainer relationship sends bearer token and parses trainees', () async {
      final client = RelationshipApiClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.example.test/trainer/relationship');
          expect(request.headers['Authorization'], 'Bearer access-token');

          return http.Response(
            jsonEncode({
              'inviteCode': '7F2K9D',
              'trainees': [
                {
                  'id': 'trainee-1',
                  'email': 'trainee@example.test',
                  'displayName': 'Test Trainee',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.getTrainerRelationship(
        accessToken: 'access-token',
      );

      expect(result.status, RelationshipApiStatus.success);
      expect(result.data?.inviteCode, '7F2K9D');
      expect(result.data?.trainees.single.displayName, 'Test Trainee');
    });

    test('trainee relationship parses null trainer', () async {
      final client = RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/trainee/relationship');
          return http.Response('{"trainer":null}', 200);
        }),
      );

      final result = await client.getTraineeRelationship(
        accessToken: 'access-token',
      );

      expect(result.status, RelationshipApiStatus.success);
      expect(result.data?.trainer, isNull);
    });

    test('trainee relationship parses trainer identity', () async {
      final client = RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'trainer': {
                'id': 'trainer-1',
                'email': 'trainer@example.test',
                'displayName': 'Test Trainer',
              },
            }),
            200,
          );
        }),
      );

      final result = await client.getTraineeRelationship(
        accessToken: 'access-token',
      );

      expect(result.status, RelationshipApiStatus.success);
      expect(result.data?.trainer?.id, 'trainer-1');
      expect(result.data?.trainer?.displayName, 'Test Trainer');
    });

    test('maps authorization failures without parsing body as success', () async {
      final seenStatuses = <int>[401, 403];
      final client = RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          final status = seenStatuses.removeAt(0);
          return http.Response('{"error":"No access."}', status);
        }),
      );

      final unauthorized = await client.getTrainerRelationship(
        accessToken: 'access-token',
      );
      final forbidden = await client.getTraineeRelationship(
        accessToken: 'access-token',
      );

      expect(unauthorized.status, RelationshipApiStatus.unauthorized);
      expect(unauthorized.message, 'No access.');
      expect(forbidden.status, RelationshipApiStatus.forbidden);
      expect(forbidden.message, 'No access.');
    });

    test('returns error for invalid relationship JSON', () async {
      final client = RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('{"inviteCode":7,"trainees":[]}', 200);
        }),
      );

      final result = await client.getTrainerRelationship(
        accessToken: 'access-token',
      );

      expect(result.status, RelationshipApiStatus.error);
      expect(result.message, contains('Invalid trainer relationship response JSON'));
    });
  });
}
