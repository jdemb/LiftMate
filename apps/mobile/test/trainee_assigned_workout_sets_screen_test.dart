import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';

void main() {
  group('Trainee assigned workout sets screen', () {
    testWidgets('linked trainee sees assigned sets and ordered row preview', (tester) async {
      await tester.pumpWidget(_testApp(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/me') {
            return http.Response(
              jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
              200,
            );
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response(jsonEncode({'trainer': _trainer()}), 200);
          }
          if (request.url.path == '/trainee/workout-sets') {
            return http.Response(jsonEncode([_assignedSet('Push A'), _assignedSet('Leg Day')]), 200);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      ));

      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Leg Day'), findsOneWidget);
      expect(find.text('Bench press'), findsNWidgets(2));
      expect(find.text('Plank'), findsNWidgets(2));
      expect(find.text('Rozpocznij trening w S-03'), findsNWidgets(2));
    });

    testWidgets('unlinked trainee still sees trainer-code prompt', (tester) async {
      var workoutSetsCalled = false;
      await tester.pumpWidget(_testApp(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/me') {
            return http.Response(jsonEncode(_userResponse(role: 'trainee')), 200);
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response('{"trainer":null}', 200);
          }
          if (request.url.path == '/trainee/workout-sets') {
            workoutSetsCalled = true;
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Połącz się z trenerem'), findsOneWidget);
      expect(find.byKey(const ValueKey('relationship-trainer-code-field')), findsOneWidget);
      expect(workoutSetsCalled, isFalse);
    });

    testWidgets('assigned-set API failure keeps readable error state', (tester) async {
      await tester.pumpWidget(_testApp(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/me') {
            return http.Response(
              jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
              200,
            );
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response(jsonEncode({'trainer': _trainer()}), 200);
          }
          if (request.url.path == '/trainee/workout-sets') {
            return http.Response('{"error":"Assigned sets unavailable."}', 500);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      ));

      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Assigned sets unavailable.'), findsOneWidget);
    });
  });
}

Widget _testApp({required http.Client httpClient}) {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: httpClient,
  );

  return MaterialApp(
    home: AuthScreen(
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: _InMemoryTokenStore(
          StoredAuthTokens(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            expiresAt: DateTime.utc(2030),
          ),
        ),
      ),
      relationshipApiClient: RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      workoutSetApiClient: WorkoutSetApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
    ),
  );
}

Map<String, Object?> _userResponse({
  required String role,
  String? trainerUserId,
}) {
  return {
    'id': '$role-1',
    'email': '$role@example.test',
    'role': role,
    'displayName': role == 'trainer' ? 'Test Trainer' : 'Test Trainee',
    'trainerUserId': trainerUserId,
  };
}

Map<String, Object?> _trainer() {
  return {
    'id': 'trainer-1',
    'email': 'trainer@example.test',
    'displayName': 'Test Trainer',
  };
}

Map<String, Object?> _assignedSet(String name) {
  return {
    'id': name == 'Push A' ? 'set-1' : 'set-2',
    'name': name,
    'trainerDisplayName': 'Test Trainer',
    'assignedAt': '2026-06-16T12:10:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
    'rows': [
      {
        'id': '$name-row-2',
        'exerciseOrder': 2,
        'setIndex': 1,
        'exerciseName': 'Plank',
        'exerciseType': 'time',
        'reps': null,
        'weight': null,
        'seconds': 60,
      },
      {
        'id': '$name-row-1',
        'exerciseOrder': 1,
        'setIndex': 1,
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
      },
    ],
  };
}

class _InMemoryTokenStore implements TokenStore {
  _InMemoryTokenStore([this._tokens]);

  StoredAuthTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}
