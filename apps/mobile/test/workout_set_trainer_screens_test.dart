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

import 'fake_onboarding_state_store.dart';

void main() {
  group('Workout set trainer screens', () {
    testWidgets(
      'trainer opens set list and creates a set from draft exercise',
      (tester) async {
        final seen = <String>[];
        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              seen.add('${request.method} ${request.url.path}');
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(_userResponse(role: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/trainer/relationship') {
                return http.Response(jsonEncode(_relationshipJson()), 200);
              }
              if (request.url.path == '/workout-sets' &&
                  request.method == 'GET') {
                return http.Response(jsonEncode([_summaryJson()]), 200);
              }
              if (request.url.path == '/workout-sets' &&
                  request.method == 'POST') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['name'], 'Push A');
                expect(body['restSeconds'], 105);
                expect((body['rows'] as List).length, 3);
                expect(
                  (body['rows'] as List).first['exerciseType'],
                  'repsWeight',
                );
                return http.Response(
                  jsonEncode(_detailJson(name: 'Push A')),
                  201,
                );
              }

              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await tester.pumpAndSettle();
        await _tapButton(tester, 'Zestawy');

        expect(find.text('Moje zestawy'), findsOneWidget);
        expect(find.text('Trening'), findsNothing);
        expect(find.text('Push A'), findsOneWidget);
        expect(find.text('Nowy zestaw'), findsOneWidget);

        await _tapButton(tester, 'Nowy zestaw');
        expect(find.text('Kreator zestawu'), findsOneWidget);
        expect(find.text('Czas odpoczynku'), findsOneWidget);
        expect(find.text('01:30'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('builder-rest-increase')));
        await tester.pump();
        expect(find.text('01:45'), findsOneWidget);

        await _tapButton(tester, 'Dodaj ćwiczenie');
        expect(find.text('Dodaj ćwiczenie'), findsOneWidget);
        expect(find.text('Powt. + waga'), findsOneWidget);
        expect(find.text('Powtórzenia'), findsWidgets);
        expect(find.text('Powtórzenia + waga'), findsNothing);
        expect(find.text('Same powtórzenia'), findsNothing);
        expect(_textContaining('\n'), findsNothing);

        await _tapButton(tester, 'Dodaj do zestawu');
        expect(find.text('Wyciskanie sztangi'), findsOneWidget);

        await _tapButton(tester, 'Zapisz zestaw');
        await tester.pumpAndSettle();

        expect(find.text('Moje zestawy'), findsOneWidget);
        expect(
          seen.where((path) => path == 'POST /workout-sets'),
          hasLength(1),
        );
      },
    );

    testWidgets('delete menu opens dialog and cancel keeps the set', (
      tester,
    ) async {
      var deleteRequests = 0;
      await tester.pumpWidget(
        _testApp(
          httpClient: _deleteTestClient((request) async {
            deleteRequests += 1;
            return http.Response('', 204);
          }),
        ),
      );

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _openDeleteDialog(tester);

      expect(find.text('Usunąć zestaw „Push A”?'), findsOneWidget);
      await _tapButton(tester, 'Anuluj');

      expect(deleteRequests, 0);
      expect(find.text('Push A'), findsOneWidget);
    });

    testWidgets('confirmed deletion removes the card and shows success', (
      tester,
    ) async {
      var deleteRequests = 0;
      await tester.pumpWidget(
        _testApp(
          httpClient: _deleteTestClient((request) async {
            deleteRequests += 1;
            return http.Response('', 204);
          }),
        ),
      );

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _openDeleteDialog(tester);
      await _tapButton(tester, 'Usuń');

      expect(deleteRequests, 1);
      expect(find.text('Push A'), findsNothing);
      expect(find.text('Nowy zestaw'), findsOneWidget);
      expect(find.text('Zestaw „Push A” został usunięty.'), findsOneWidget);
    });

    testWidgets(
      'active session conflict keeps the card and shows dedicated message',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            httpClient: _deleteTestClient((request) async {
              return http.Response(
                jsonEncode({'error': 'Workout set has an active session.'}),
                409,
              );
            }),
          ),
        );

        await tester.pumpAndSettle();
        await _tapButton(tester, 'Zestawy');
        await _openDeleteDialog(tester);
        await _tapButton(tester, 'Usuń');

        expect(find.text('Push A'), findsOneWidget);
        expect(
          find.text('Nie można usunąć zestawu podczas aktywnej sesji.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('network failure keeps the card and shows generic message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: _deleteTestClient((request) async {
            throw http.ClientException('Network unavailable');
          }),
        ),
      );

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _openDeleteDialog(tester);
      await _tapButton(tester, 'Usuń');

      expect(find.text('Push A'), findsOneWidget);
      expect(
        find.text('Nie udało się usunąć zestawu. Spróbuj ponownie.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'trainer edits an existing set exercise through the exercise editor',
      (tester) async {
        Map<String, dynamic>? updateBody;

        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(_userResponse(role: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/trainer/relationship') {
                return http.Response(jsonEncode(_relationshipJson()), 200);
              }
              if (request.url.path == '/workout-sets' &&
                  request.method == 'GET') {
                return http.Response(
                  jsonEncode([_summaryJson(rowCount: 3)]),
                  200,
                );
              }
              if (request.url.path == '/workout-sets/set-1' &&
                  request.method == 'GET') {
                return http.Response(
                  jsonEncode(_detailJson(rows: _benchRows(), restSeconds: 120)),
                  200,
                );
              }
              if (request.url.path == '/workout-sets/set-1' &&
                  request.method == 'PUT') {
                updateBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(
                  jsonEncode(_detailJson(name: 'Push A')),
                  200,
                );
              }

              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await tester.pumpAndSettle();
        await _tapButton(tester, 'Zestawy');
        await _tapButton(tester, 'Edytuj');
        await tester.pumpAndSettle();

        expect(find.text('Bench press'), findsOneWidget);
        expect(find.text('02:00'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('builder-rest-decrease')));
        await tester.pump();
        expect(find.text('01:45'), findsOneWidget);
        expect(find.text('Seria 1'), findsNothing);

        await tester.tap(find.text('Bench press'));
        await tester.pumpAndSettle();
        expect(find.text('Edytuj ćwiczenie'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Incline press');
        await _tapButton(tester, 'Zapisz ćwiczenie');
        await _tapButton(tester, 'Zapisz zestaw');
        await tester.pumpAndSettle();

        final rows = updateBody?['rows'] as List<dynamic>;
        expect(rows, hasLength(3));
        expect(rows.first['exerciseName'], 'Incline press');
        expect(rows.map((row) => row['setIndex']), [1, 2, 3]);
        expect(updateBody?['restSeconds'], 105);
      },
    );

    testWidgets('trainer deletes an exercise from an existing set draft', (
      tester,
    ) async {
      Map<String, dynamic>? updateBody;

      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(jsonEncode(_relationshipJson()), 200);
            }
            if (request.url.path == '/workout-sets' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode([_summaryJson(exerciseCount: 2, rowCount: 4)]),
                200,
              );
            }
            if (request.url.path == '/workout-sets/set-1' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode(
                  _detailJson(rows: [..._benchRows(), ..._squatRows()]),
                ),
                200,
              );
            }
            if (request.url.path == '/workout-sets/set-1' &&
                request.method == 'PUT') {
              updateBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode(_detailJson(name: 'Push A')),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _tapButton(tester, 'Edytuj');
      await tester.pumpAndSettle();

      expect(find.text('Bench press'), findsOneWidget);
      expect(find.text('Back squat'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Bench press'), findsNothing);
      expect(find.text('Back squat'), findsOneWidget);

      await _tapButton(tester, 'Zapisz zestaw');
      await tester.pumpAndSettle();

      final rows = updateBody?['rows'] as List<dynamic>;
      expect(rows, hasLength(2));
      expect(rows.map((row) => row['exerciseName']).toSet(), {'Back squat'});
      expect(rows.map((row) => row['exerciseOrder']).toSet(), {1});
    });

    testWidgets('trainer assigns a set to multiple trainees', (tester) async {
      final seenBodies = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode(_relationshipJson(twoTrainees: true)),
                200,
              );
            }
            if (request.url.path == '/workout-sets' &&
                request.method == 'GET') {
              return http.Response(jsonEncode([_summaryJson()]), 200);
            }
            if (request.url.path == '/workout-sets/set-1' &&
                request.method == 'GET') {
              return http.Response(
                jsonEncode(_detailJson(assignments: [])),
                200,
              );
            }
            if (request.url.path == '/workout-sets/set-1/assignments') {
              seenBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
              return http.Response(jsonEncode(_detailJson()), 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zestawy');
      await _tapButton(tester, 'Przypisz');
      await tester.pumpAndSettle();

      expect(find.text('Przypisz zestaw'), findsOneWidget);
      await tester.tap(find.text('Anna Nowak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan Kowalski'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Zapisz (2)');

      expect(seenBodies.single, {
        'traineeUserIds': ['trainee-1', 'trainee-2'],
      });
    });

    testWidgets(
      'trainer can unassign the last trainee without assigning another',
      (tester) async {
        final seen = <String>[];
        var detailGets = 0;

        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              seen.add('${request.method} ${request.url.path}');
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(_userResponse(role: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/trainer/relationship') {
                return http.Response(jsonEncode(_relationshipJson()), 200);
              }
              if (request.url.path == '/workout-sets' &&
                  request.method == 'GET') {
                return http.Response(jsonEncode([_summaryJson()]), 200);
              }
              if (request.url.path == '/workout-sets/set-1' &&
                  request.method == 'GET') {
                detailGets += 1;
                return http.Response(
                  jsonEncode(
                    _detailJson(
                      assignments: detailGets == 1
                          ? [
                              {
                                'traineeUserId': 'trainee-1',
                                'traineeEmail': 'anna@example.test',
                                'traineeDisplayName': 'Anna Nowak',
                                'assignedAt': '2026-06-16T12:10:00Z',
                              },
                            ]
                          : [],
                    ),
                  ),
                  200,
                );
              }
              if (request.url.path ==
                  '/workout-sets/set-1/assignments/trainee-1') {
                return http.Response('', 204);
              }
              if (request.url.path == '/workout-sets/set-1/assignments') {
                fail('Assign should not be called with an empty trainee list');
              }

              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await tester.pumpAndSettle();
        await _tapButton(tester, 'Zestawy');
        await _tapButton(tester, 'Przypisz');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Anna Nowak'));
        await tester.pumpAndSettle();
        await _tapButton(tester, 'Zapisz (0)');

        expect(
          seen.where(
            (path) =>
                path == 'DELETE /workout-sets/set-1/assignments/trainee-1',
          ),
          hasLength(1),
        );
        expect(
          seen.where((path) => path == 'POST /workout-sets/set-1/assignments'),
          isEmpty,
        );
      },
    );

    testWidgets('trainee detail shows assigned sets without unassign action', (
      tester,
    ) async {
      AssignedWorkoutSetSummary? started;
      var openedSets = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerTraineeDetailScreen(
            trainee: const TrainerTraineeSummary(
              id: 'trainee-1',
              email: 'anna@example.test',
              displayName: 'Anna Nowak',
            ),
            assignedSets: [_assignedSummary()],
            onBack: () {},
            onLogout: () async {},
            onOpenWorkoutSets: () => openedSets = true,
            onStartSession: (set) => started = set,
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('PRZYPISANE ZESTAWY'),
        280,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('PRZYPISANE ZESTAWY'), findsOneWidget);
      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Odepnij zestaw'), findsNothing);
      expect(find.text('1 ćwiczenie · 1 serii'), findsOneWidget);

      await _tapButton(tester, 'Rozpocznij wspólny trening');
      expect(started?.id, 'set-1');

      await _tapButton(tester, 'Zestawy');
      expect(openedSets, isTrue);
    });

    testWidgets(
      'trainee detail switches to join action when session is active',
      (tester) async {
        var joined = false;

        await tester.pumpWidget(
          MaterialApp(
            home: TrainerTraineeDetailScreen(
              trainee: TrainerTraineeSummary(
                id: 'trainee-1',
                email: 'anna@example.test',
                displayName: 'Anna Nowak',
                activeSession: ActiveSharedSessionSummary(
                  sessionId: 'session-1',
                  workoutSetId: 'set-1',
                  workoutSetName: 'Push A',
                  startedByUserId: 'trainee-1',
                  startedByRole: 'trainee',
                  updatedAt: DateTime.utc(2026, 6, 17),
                ),
              ),
              assignedSets: [_assignedSummary()],
              onBack: () {},
              onLogout: () async {},
              onOpenWorkoutSets: () {},
              onJoinActiveSession: () => joined = true,
              onStartSession: (_) {},
            ),
          ),
        );

        expect(find.text('Aktywna sesja'), findsOneWidget);
        expect(find.textContaining('sesji'), findsOneWidget);
        expect(find.text('Rozpocznij wspólny trening'), findsNothing);

        await _tapButton(tester, 'Dołącz do sesji');
        expect(joined, isTrue);
      },
    );
  });
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('workout-set-menu-set-1')));
  await tester.pumpAndSettle();
  expect(find.text('Usuń zestaw'), findsOneWidget);
  await _tapButton(tester, 'Usuń zestaw');
}

Finder _textContaining(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(value) ?? false),
  );
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
      onboardingStateStore: FakeOnboardingStateStore(),
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

http.Client _deleteTestClient(
  Future<http.Response> Function(http.Request request) onDelete,
) {
  return MockClient((request) async {
    if (request.url.path == '/auth/me') {
      return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
    }
    if (request.url.path == '/trainer/relationship') {
      return http.Response(jsonEncode(_relationshipJson()), 200);
    }
    if (request.url.path == '/workout-sets' && request.method == 'GET') {
      return http.Response(jsonEncode([_summaryJson()]), 200);
    }
    if (request.url.path == '/workout-sets/set-1' &&
        request.method == 'DELETE') {
      return onDelete(request);
    }

    fail('Unexpected request: ${request.method} ${request.url}');
  });
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

Map<String, Object?> _summaryJson({int exerciseCount = 1, int rowCount = 3}) {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'exerciseCount': exerciseCount,
    'rowCount': rowCount,
    'assignedTrainees': 0,
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

AssignedWorkoutSetSummary _assignedSummary({
  int exerciseCount = 1,
  int rowCount = 1,
}) {
  return AssignedWorkoutSetSummary(
    id: 'set-1',
    name: 'Push A',
    exerciseCount: exerciseCount,
    rowCount: rowCount,
    updatedAt: DateTime.utc(2026, 6, 16, 12, 5),
  );
}

Map<String, Object?> _detailJson({
  String name = 'Push A',
  int restSeconds = 90,
  List<Map<String, Object?>>? rows,
  List<Map<String, Object?>>? assignments,
}) {
  return {
    'id': 'set-1',
    'name': name,
    'restSeconds': restSeconds,
    'rows': rows ?? _benchRows(setCount: 1),
    'assignments':
        assignments ??
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

List<Map<String, Object?>> _benchRows({int setCount = 3}) {
  return List.generate(setCount, (index) {
    return {
      'id': 'bench-${index + 1}',
      'exerciseOrder': 1,
      'setIndex': index + 1,
      'exerciseName': 'Bench press',
      'exerciseType': 'repsWeight',
      'reps': 6,
      'weight': 40.0,
      'seconds': null,
    };
  }, growable: false);
}

List<Map<String, Object?>> _squatRows() {
  return List.generate(2, (index) {
    return {
      'id': 'squat-${index + 1}',
      'exerciseOrder': 2,
      'setIndex': index + 1,
      'exerciseName': 'Back squat',
      'exerciseType': 'repsOnly',
      'reps': 8,
      'weight': null,
      'seconds': null,
    };
  }, growable: false);
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
