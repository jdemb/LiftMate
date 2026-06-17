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
  group('Post-auth relationship screens', () {
    testWidgets('trainer with no trainees sees invite-code empty state and CTA',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response('{"inviteCode":"7F2K9D","trainees":[]}', 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);

      expect(find.text('Twój kod zaproszenia'), findsOneWidget);
      expect(find.text('7F2K9D'), findsWidgets);
      expect(find.text('Brak podopiecznych'), findsOneWidget);
      expect(find.text('Zaproś podopiecznego'), findsOneWidget);
    });

    testWidgets('trainer with trainees sees list entries and opens detail',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode({
                  'inviteCode': '7F2K9D',
                  'trainees': [
                    {
                      'id': 'trainee-1',
                      'email': 'trainee@example.test',
                      'displayName': 'Anna Nowak',
                    },
                  ],
                }),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.text('Anna Nowak'));
      await tester.pumpAndSettle();

      expect(find.text('Podopieczny'), findsOneWidget);
      expect(find.text('Anna Nowak'), findsWidgets);
      expect(find.text('trainee@example.test'), findsOneWidget);
      expect(find.text('Aktywna relacja'), findsOneWidget);
    });

    testWidgets('trainer detail renders assigned sets from relationship summary',
        (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seen.add('${request.method} ${request.url.path}');
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode({
                  'inviteCode': '7F2K9D',
                  'trainees': [
                    {
                      'id': 'trainee-1',
                      'email': 'trainee@example.test',
                      'displayName': 'Anna Nowak',
                      'assignedWorkoutSets': [
                        {
                          'id': 'set-1',
                          'name': 'Push A',
                          'exerciseCount': 2,
                          'rowCount': 5,
                          'updatedAt': '2026-06-16T12:05:00Z',
                        },
                      ],
                    },
                  ],
                }),
                200,
              );
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.textContaining('Anna').first);
      await tester.pumpAndSettle();

      expect(find.text('Push A'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
      expect(find.text('Odepnij zestaw'), findsNothing);
      expect(seen.where((path) => path == 'GET /workout-sets/set-1'), isEmpty);
    });

    testWidgets('trainer dashboard shows active session badge', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode({
                  'inviteCode': '7F2K9D',
                  'trainees': [
                    {
                      'id': 'trainee-1',
                      'email': 'trainee@example.test',
                      'displayName': 'Anna Nowak',
                      'activeSession': {
                        'sessionId': 'session-1',
                        'workoutSetId': 'set-1',
                        'workoutSetName': 'Push A',
                        'startedByUserId': 'trainee-1',
                        'startedByRole': 'trainee',
                        'updatedAt': '2026-06-17T12:00:00Z',
                      },
                    },
                  ],
                }),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);

      expect(find.text('1'), findsWidgets);
      expect(find.text('Aktywna sesja'), findsOneWidget);
      await tester.tap(find.text('Anna Nowak'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sesji'), findsOneWidget);
    });

    testWidgets('trainee linked to trainer sees trainer identity',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
                200,
              );
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response(
                jsonEncode({'trainer': _trainer('Test Trainer')}),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);

      expect(find.text('TWÓJ TRENER'), findsOneWidget);
      expect(find.text('Test Trainer'), findsOneWidget);
      expect(find.text('trainer@example.test'), findsOneWidget);
    });

    testWidgets('trainee unlinked sees enter-code prompt', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainee')), 200);
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response('{"trainer":null}', 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);

      expect(find.text('Połącz się z trenerem'), findsOneWidget);
      expect(find.byKey(const ValueKey('relationship-trainer-code-field')), findsOneWidget);
      expect(find.text('Połącz konto'), findsOneWidget);
    });

    testWidgets('trainee submits a new code and reloads relationship state',
        (tester) async {
      var linked = false;
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainee')), 200);
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response(
                jsonEncode({'trainer': linked ? _trainer('Trainer B') : null}),
                200,
              );
            }
            if (request.url.path == '/trainee/trainer-link') {
              expect(jsonDecode(request.body), {'code': '7F2K9D'});
              linked = true;
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-b')),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.enterText(
        find.byKey(const ValueKey('relationship-trainer-code-field')),
        '7f2k9d',
      );
      await _tapButton(tester, 'Połącz konto');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Trainer B'), findsOneWidget);
    });

    testWidgets('failed claim shows readable error and preserves previous state',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-a')),
                200,
              );
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response(jsonEncode({'trainer': _trainer('Trainer A')}), 200);
            }
            if (request.url.path == '/trainee/trainer-link') {
              return http.Response('{"error":"Trainer invite code was not found."}', 404);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.enterText(
        find.byKey(const ValueKey('relationship-trainer-code-field')),
        'AAAAAA',
      );
      await _tapButton(tester, 'Połącz z nowym trenerem');

      expect(find.text('Trainer A'), findsOneWidget);
      expect(find.text('Trainer invite code was not found.'), findsOneWidget);
    });

    testWidgets('logout returns to unauthenticated onboarding', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response('{"inviteCode":"7F2K9D","trainees":[]}', 200);
            }
            if (request.url.path == '/auth/logout') {
              return http.Response('', 204);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await _tapButton(tester, 'Wyloguj');

      expect(find.text('LiftMate'), findsOneWidget);
      expect(find.textContaining('konto'), findsWidgets);
    });
  });
}

Future<void> _startAuthenticated(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  var finder = find.text(label);
  if (finder.evaluate().isEmpty && label.contains(' ')) {
    finder = find.textContaining(label.split(' ').first);
  }
  final buttonFinder = find.ancestor(
    of: finder,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is FilledButton ||
          widget is OutlinedButton ||
          widget is TextButton ||
          widget is ElevatedButton,
    ),
  );
  final target = buttonFinder.evaluate().isEmpty ? finder : buttonFinder.first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Widget _testApp({
  required http.Client httpClient,
}) {
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

Map<String, Object?> _trainer(String displayName) {
  return {
    'id': 'trainer-1',
    'email': 'trainer@example.test',
    'displayName': displayName,
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
