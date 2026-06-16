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
import 'package:liftmate/relationships/relationship_models.dart';
import 'package:liftmate/relationships/trainer_trainee_detail_screen.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_models.dart';

void main() {
  group('Workout set trainer screens', () {
    testWidgets('trainer opens set list and creates a set from draft exercise', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(_testApp(
        httpClient: MockClient((request) async {
          seen.add('${request.method} ${request.url.path}');
          if (request.url.path == '/auth/me') {
            return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
          }
          if (request.url.path == '/trainer/relationship') {
            return http.Response(jsonEncode(_relationshipJson()), 200);
          }
          if (request.url.path == '/workout-sets' && request.method == 'GET') {
            return http.Response(jsonEncode([_summaryJson()]), 200);
          }
          if (request.url.path == '/workout-sets' && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['name'], 'Push A');
            expect((body['rows'] as List).length, 3);
            expect((body['rows'] as List).first['exerciseType'], 'repsWeight');
            return http.Response(jsonEncode(_detailJson(name: 'Push A')), 201);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      ));

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');

      expect(find.text('Moje zestawy'), findsOneWidget);
      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Nowy zestaw'), findsOneWidget);

      await _tapButton(tester, 'Nowy zestaw');
      expect(find.text('Kreator zestawu'), findsOneWidget);

      await _tapButton(tester, 'Dodaj ćwiczenie');
      expect(find.text('Dodaj ćwiczenie'), findsOneWidget);

      await _tapButton(tester, 'Dodaj do zestawu');
      expect(find.text('Wyciskanie sztangi'), findsOneWidget);

      await _tapButton(tester, 'Zapisz zestaw');
      await tester.pumpAndSettle();

      expect(find.text('Moje zestawy'), findsOneWidget);
      expect(seen.where((path) => path == 'POST /workout-sets'), hasLength(1));
    });

    testWidgets('trainer assigns a set to multiple trainees', (tester) async {
      final seenBodies = <Map<String, dynamic>>[];
      await tester.pumpWidget(_testApp(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/me') {
            return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
          }
          if (request.url.path == '/trainer/relationship') {
            return http.Response(jsonEncode(_relationshipJson(twoTrainees: true)), 200);
          }
          if (request.url.path == '/workout-sets' && request.method == 'GET') {
            return http.Response(jsonEncode([_summaryJson()]), 200);
          }
          if (request.url.path == '/workout-sets/set-1' && request.method == 'GET') {
            return http.Response(jsonEncode(_detailJson(assignments: [])), 200);
          }
          if (request.url.path == '/workout-sets/set-1/assignments') {
            seenBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(jsonEncode(_detailJson()), 200);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      ));

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _tapButton(tester, 'Przypisz');
      await tester.pumpAndSettle();

      expect(find.text('Przypisz zestaw'), findsOneWidget);
      await tester.tap(find.text('Anna Nowak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Kowalski'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Przypisz (2)');

      expect(seenBodies.single, {
        'traineeUserIds': ['trainee-1', 'trainee-2'],
      });
    });

    testWidgets('trainee detail shows assigned sets and unassign action', (tester) async {
      WorkoutSetDetail? unassigned;

      await tester.pumpWidget(MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: const TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
          ),
          assignedSets: [WorkoutSetDetail.fromJson(_detailJson())],
          onBack: () {},
          onLogout: () async {},
          onUnassign: (set) => unassigned = set,
        ),
      ));

      await tester.scrollUntilVisible(
        find.text('PRZYPISANE ZESTAWY'),
        280,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('PRZYPISANE ZESTAWY'), findsOneWidget);
      expect(find.text('Push A'), findsOneWidget);
      await _tapButton(tester, 'Odepnij zestaw');

      expect(unassigned?.id, 'set-1');
    });
  });
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
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

Map<String, Object?> _userResponse({required String role}) {
  return {
    'id': '$role-1',
    'email': '$role@example.test',
    'role': role,
    'displayName': role == 'trainer' ? 'Test Trainer' : 'Test Trainee',
    'trainerUserId': null,
  };
}

Map<String, Object?> _relationshipJson({bool twoTrainees = false}) {
  return {
    'inviteCode': '7F2K9D',
    'trainees': [
      {
        'id': 'trainee-1',
        'email': 'anna@example.test',
        'displayName': 'Anna Nowak',
      },
      if (twoTrainees)
        {
          'id': 'trainee-2',
          'email': 'jan@example.test',
          'displayName': 'Jan Kowalski',
        },
    ],
  };
}

Map<String, Object?> _summaryJson() {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'exerciseCount': 1,
    'rowCount': 3,
    'assignedTrainees': 0,
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

Map<String, Object?> _detailJson({
  String name = 'Push A',
  List<Map<String, Object?>>? assignments,
}) {
  return {
    'id': 'set-1',
    'name': name,
    'rows': [
      {
        'id': 'row-1',
        'exerciseOrder': 1,
        'setIndex': 1,
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
      },
    ],
    'assignments': assignments ??
        [
          {
            'traineeUserId': 'trainee-1',
            'traineeEmail': 'anna@example.test',
            'traineeDisplayName': 'Anna Nowak',
            'assignedAt': '2026-06-16T12:10:00Z',
          },
        ],
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
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
