import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/post_workout_feedback/post_workout_feedback_api_client.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';
import 'package:liftmate/training_history/training_history_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';

import 'fake_onboarding_state_store.dart';

void main() {
  group('Post-auth relationship screens', () {
    testWidgets(
      'trainer with no trainees sees invite-code empty state and CTA',
      (tester) async {
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
                  '{"inviteCode":"7F2K9D","trainees":[]}',
                  200,
                );
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
      },
    );

    testWidgets(
      'trainer copies the dashboard invite code and sees confirmation',
      (tester) async {
        MethodCall? clipboardCall;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCall = call;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

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
                  '{"inviteCode":"7F2K9D","trainees":[]}',
                  200,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.tap(
          find.byKey(const ValueKey('copy-trainer-invite-code-dashboard')),
        );
        await tester.pump();

        expect(clipboardCall?.method, 'Clipboard.setData');
        expect(clipboardCall?.arguments, {'text': '7F2K9D'});
        expect(find.text('Kod zaproszenia skopiowany.'), findsOneWidget);
      },
    );

    testWidgets(
      'dashboard copy stays disabled until an invite code is loaded',
      (tester) async {
        final relationshipCompleter = Completer<http.Response>();
        var clipboardCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCalls += 1;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

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
                return relationshipCompleter.future;
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pump();
        await tester.pump();

        final copyButton = find.byKey(
          const ValueKey('copy-trainer-invite-code-dashboard'),
        );
        expect(copyButton, findsOneWidget);
        expect(tester.widget<TextButton>(copyButton).onPressed, isNull);
        await tester.tap(copyButton);
        await tester.pump();
        expect(clipboardCalls, 0);

        relationshipCompleter.complete(
          http.Response('{"inviteCode":"7F2K9D","trainees":[]}', 200),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets('dashboard invite card fits the design phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                '{"inviteCode":"7F2K9D","trainees":[]}',
                200,
              );
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);

      expect(
        find.byKey(const ValueKey('copy-trainer-invite-code-dashboard')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('trainer with trainees sees list entries and opens detail', (
      tester,
    ) async {
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
                jsonEncode({
                  'inviteCode': '7F2K9D',
                  'trainees': [
                    {
                      'id': 'trainee-1',
                      'email': 'trainee@example.test',
                      'displayName': 'Anna Nowak',
                      'connectedAt': '2026-03-08T10:00:00Z',
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
      expect(find.text('trainee@example.test'), findsNothing);
      expect(find.text('Połączona od marca 2026'), findsOneWidget);
    });

    testWidgets('trainer history targets the selected linked trainee', (
      tester,
    ) async {
      Uri? historyRequest;
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
                jsonEncode({
                  'inviteCode': '7F2K9D',
                  'trainees': [
                    {
                      'id': 'trainee-1',
                      'email': 'trainee@example.test',
                      'displayName': 'Anna Nowak',
                      'connectedAt': '2026-03-08T10:00:00Z',
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path == '/training-history/sessions') {
              historyRequest = request.url;
              return http.Response('{"items":[],"nextCursor":null}', 200);
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.text('Anna Nowak'));
      await tester.pumpAndSettle();

      expect(find.text('Historia'), findsOneWidget);
      expect(find.text('Zmień zestaw'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('trainer-open-trainee-history')),
      );
      await tester.pumpAndSettle();

      expect(historyRequest?.queryParameters['traineeUserId'], 'trainee-1');
      expect(find.text('Brak ukończonych treningów.'), findsOneWidget);
      expect(find.byTooltip('Wróć'), findsOneWidget);

      await tester.tap(find.byTooltip('Wróć'));
      await tester.pumpAndSettle();

      expect(find.text('Podopieczny'), findsOneWidget);
      expect(find.text('Anna Nowak'), findsWidgets);
      expect(find.text('Połączona od marca 2026'), findsOneWidget);
    });

    testWidgets('trainee history opens from bottom navigation', (tester) async {
      Uri? historyRequest;
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(
                  _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                ),
                200,
              );
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response(
                jsonEncode({'trainer': _trainer('Test Trainer')}),
                200,
              );
            }
            if (request.url.path == '/trainee/workout-sets') {
              return http.Response('[]', 200);
            }
            if (request.url.path == '/shared-sessions/active') {
              return http.Response('', 404);
            }
            if (request.url.path == '/training-history/sessions') {
              historyRequest = request.url;
              return http.Response('{"items":[],"nextCursor":null}', 200);
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
          includeSharedSessionClient: true,
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.text('Historia'));
      await tester.pumpAndSettle();

      expect(historyRequest?.queryParameters['traineeUserId'], isNull);
      expect(find.text('Brak ukończonych treningów.'), findsOneWidget);
    });

    testWidgets(
      'trainer detail renders assigned sets from relationship summary',
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
        expect(find.text('2 ćwiczenia · 5 serii'), findsOneWidget);
        expect(find.text('Odepnij zestaw'), findsNothing);
        expect(
          seen.where((path) => path == 'GET /workout-sets/set-1'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'trainer opens trainee detail only after fresh relationship reload',
      (tester) async {
        var relationshipRequests = 0;
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
                relationshipRequests += 1;
                return http.Response(
                  jsonEncode(
                    _trainerRelationshipWithAssignedSet(
                      setName: relationshipRequests == 1 ? 'Push A' : 'Push B',
                      exerciseCount: relationshipRequests == 1 ? 2 : 5,
                      rowCount: relationshipRequests == 1 ? 5 : 12,
                    ),
                  ),
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

        expect(relationshipRequests, 2);
        expect(find.text('Podopieczny'), findsOneWidget);
        expect(find.text('Push B'), findsOneWidget);
        expect(find.text('5 ćwiczeń · 12 serii'), findsOneWidget);
        expect(find.text('Push A'), findsNothing);
      },
    );

    testWidgets(
      'trainer trainee row shows loading and ignores duplicate opens',
      (tester) async {
        var relationshipRequests = 0;
        final refreshCompleter = Completer<http.Response>();
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
                relationshipRequests += 1;
                if (relationshipRequests == 1) {
                  return http.Response(
                    jsonEncode(_trainerRelationshipWithAssignedSet()),
                    200,
                  );
                }
                return refreshCompleter.future;
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.tap(find.textContaining('Anna').first);
        await tester.pump();
        await tester.tap(find.textContaining('Anna').first);
        await tester.pump();

        expect(relationshipRequests, 2);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Podopieczny'), findsNothing);

        refreshCompleter.complete(
          http.Response(jsonEncode(_trainerRelationshipWithAssignedSet()), 200),
        );
        await tester.pumpAndSettle();
        expect(find.text('Podopieczny'), findsOneWidget);
      },
    );

    testWidgets(
      'trainer detail refresh failure keeps dashboard with retry error',
      (tester) async {
        var relationshipRequests = 0;
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
                relationshipRequests += 1;
                if (relationshipRequests == 1) {
                  return http.Response(
                    jsonEncode(_trainerRelationshipWithAssignedSet()),
                    200,
                  );
                }
                return http.Response(
                  '{"error":"Temporary relationship failure."}',
                  503,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.tap(find.textContaining('Anna').first);
        await tester.pumpAndSettle();

        expect(find.text('Podopieczny'), findsNothing);
        expect(find.text('Temporary relationship failure.'), findsOneWidget);
        expect(find.text('PODOPIECZNI'), findsOneWidget);
      },
    );

    testWidgets(
      'trainer detail refresh missing trainee does not open stale detail',
      (tester) async {
        var relationshipRequests = 0;
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
                relationshipRequests += 1;
                if (relationshipRequests == 1) {
                  return http.Response(
                    jsonEncode(_trainerRelationshipWithAssignedSet()),
                    200,
                  );
                }
                return http.Response(
                  jsonEncode({'inviteCode': '7F2K9D', 'trainees': []}),
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

        expect(relationshipRequests, 2);
        expect(find.text('Podopieczny'), findsNothing);
        expect(find.text('Brak podopiecznych'), findsOneWidget);
        expect(find.text('Push A'), findsNothing);
      },
    );

    testWidgets(
      'trainer starts assigned set and opens loaded editable live screen',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(_userResponse(role: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/trainer/relationship') {
                return http.Response(
                  jsonEncode(_trainerRelationshipWithAssignedSet()),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/from-workout-set') {
                expect(jsonDecode(request.body), {
                  'workoutSetId': 'set-1',
                  'traineeUserId': 'trainee-1',
                });
                return http.Response(jsonEncode(_sessionResponse()), 201);
              }

              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.tap(find.textContaining('Anna').first);
        await tester.pumpAndSettle();
        await _tapButton(tester, 'Rozpocznij wspÃ³lny trening');

        await _expectEditableLiveHierarchy(tester);
        expect(find.text('Anna'), findsOneWidget);
        expect(find.text('Zestaw Push A'), findsOneWidget);
        expect(find.text('trainee@example.test'), findsNothing);
      },
    );

    testWidgets(
      'trainer joins trainee self-start and opens loaded editable live screen',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(_userResponse(role: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/trainer/relationship') {
                return http.Response(
                  jsonEncode(
                    _trainerRelationshipWithAssignedSet(activeSession: true),
                  ),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/session-1') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainee')),
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
        await tester.tap(find.textContaining('sesji').first);
        await tester.pumpAndSettle();

        await _expectEditableLiveHierarchy(tester);
      },
    );

    testWidgets('active trainer start without values stays on trainee detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          includeSharedSessionClient: true,
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode(_trainerRelationshipWithAssignedSet()),
                200,
              );
            }
            if (request.url.path == '/shared-sessions/from-workout-set') {
              return http.Response(
                jsonEncode(_sessionResponse(includeValues: false)),
                201,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.textContaining('Anna').first);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Rozpocznij wspÃ³lny trening');

      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Trening live'), findsNothing);
      expect(
        find.text('Aktywna sesja nie zawiera żadnych serii.'),
        findsOneWidget,
      );
    });

    testWidgets('failed trainer start stays on detail instead of blank live', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          includeSharedSessionClient: true,
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode(_trainerRelationshipWithAssignedSet()),
                200,
              );
            }
            if (request.url.path == '/shared-sessions/from-workout-set') {
              return http.Response('{"error":"Session already closed."}', 409);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.tap(find.textContaining('Anna').first);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Rozpocznij wspÃ³lny trening');

      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('Bench press'), findsNothing);
    });

    testWidgets('trainer dashboard shows active session badge', (tester) async {
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

    testWidgets('trainee linked to trainer sees trainer identity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(
                  _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                ),
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

    testWidgets(
      'trainee trainer-led read-only live has back action and trainer first name',
      (tester) async {
        final seen = <String>[];
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              seen.add('${request.method} ${request.url.path}');
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('Test Trainer')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/workout-sets') {
                return http.Response(jsonEncode([_assignedSet()]), 200);
              }
              if (request.url.path == '/shared-sessions/active') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/session-1') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                  200,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.pumpAndSettle();
        await _tapButton(tester, 'aktywnego treningu');

        expect(find.text('Prowadzi trener Test'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsNothing);

        final header = tester.getRect(
          find.byKey(const ValueKey('read-only-live-header')),
        );
        final trainerStatus = tester.getRect(
          find.byKey(const ValueKey('read-only-live-trainer-status')),
        );
        expect(trainerStatus.center.dx, closeTo(header.center.dx, 0.5));

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();

        expect(find.text('DZISIEJSZY TRENING'), findsOneWidget);
        expect(find.textContaining('aktywnego treningu'), findsOneWidget);
        expect(seen.where((request) => request.contains('/complete')), isEmpty);
        expect(seen.where((request) => request.contains('/cancel')), isEmpty);
      },
    );

    testWidgets(
      'trainee read-only live updates from realtime without another session request',
      (tester) async {
        final seen = <String>[];
        final realtimeClient = _FakeRealtimeClient();
        addTearDown(realtimeClient.dispose);
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            sharedSessionRealtimeClientFactory: () => realtimeClient,
            httpClient: MockClient((request) async {
              seen.add('${request.method} ${request.url.path}');
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('Test Trainer')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/workout-sets') {
                return http.Response(jsonEncode([_assignedSet()]), 200);
              }
              if (request.url.path == '/shared-sessions/active' ||
                  request.url.path == '/shared-sessions/session-1') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                  200,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.pumpAndSettle();
        await _tapButton(tester, 'aktywnego treningu');

        expect(find.text('40 kg'), findsOneWidget);
        expect(find.text('x 6 powt.'), findsOneWidget);
        expect(find.text('0 ukończonych serii'), findsOneWidget);
        final sessionRequestCount = seen
            .where((request) => request.contains('/shared-sessions/'))
            .length;

        realtimeClient.emit(
          SharedSession.fromJson(
            _sessionResponse(
              startedByRole: 'trainer',
              version: 2,
              firstReps: 8,
              firstWeight: 47.5,
              completedValueIds: const {'value-2'},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('47.5 kg'), findsOneWidget);
        expect(find.text('x 8 powt.'), findsOneWidget);
        expect(find.text('1 ukończona seria'), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsNothing);
        expect(
          seen.where((request) => request.contains('/shared-sessions/')).length,
          sessionRequestCount,
        );
      },
    );

    testWidgets(
      'trainee trainer-led read-only live falls back to trainer email',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/workout-sets') {
                return http.Response(jsonEncode([_assignedSet()]), 200);
              }
              if (request.url.path == '/shared-sessions/active') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/session-1') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                  200,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.pumpAndSettle();
        await _tapButton(tester, 'aktywnego treningu');

        expect(
          find.text('Prowadzi trener trainer@example.test'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'trainee self-start completion opens feedback for the completed session',
      (tester) async {
        String? feedbackPath;
        Map<String, dynamic>? feedbackBody;
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('Test Trainer')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/workout-sets') {
                return http.Response(jsonEncode([_assignedSet()]), 200);
              }
              if (request.url.path == '/shared-sessions/active') {
                return http.Response('', 404);
              }
              if (request.url.path == '/shared-sessions/from-workout-set') {
                return http.Response(
                  jsonEncode(_sessionResponse(startedByRole: 'trainee')),
                  201,
                );
              }
              if (request.url.path == '/shared-sessions/session-1/complete') {
                return http.Response(
                  jsonEncode(
                    _sessionResponse(
                      startedByRole: 'trainee',
                      status: 'completed',
                      version: 2,
                    ),
                  ),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/session-1/feedback') {
                feedbackPath = request.url.path;
                feedbackBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response(
                  jsonEncode(_feedbackResponse(rating: 4)),
                  201,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.pumpAndSettle();
        await _tapButton(tester, 'Rozpocznij trening');
        await _tapButton(tester, 'Zakończ i zapisz trening');

        expect(find.text('Jak się czujesz po treningu?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('feedback-rating-4')));
        await tester.pump();
        await tester.tap(find.text('Wyślij feedback'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(feedbackPath, '/shared-sessions/session-1/feedback');
        expect(feedbackBody, {'wellbeingRating': 4, 'comment': null});
        expect(find.text('DZISIEJSZY TRENING'), findsOneWidget);
      },
    );

    testWidgets('trainee realtime completion opens one feedback prompt', (
      tester,
    ) async {
      final realtimeClient = _FakeRealtimeClient();
      addTearDown(realtimeClient.dispose);
      await tester.pumpWidget(
        _testApp(
          includeSharedSessionClient: true,
          sharedSessionRealtimeClientFactory: () => realtimeClient,
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(
                  _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                ),
                200,
              );
            }
            if (request.url.path == '/trainee/relationship') {
              return http.Response(
                jsonEncode({'trainer': _trainer('Test Trainer')}),
                200,
              );
            }
            if (request.url.path == '/trainee/workout-sets') {
              return http.Response(jsonEncode([_assignedSet()]), 200);
            }
            if (request.url.path == '/shared-sessions/active' ||
                request.url.path == '/shared-sessions/session-1') {
              return http.Response(
                jsonEncode(_sessionResponse(startedByRole: 'trainer')),
                200,
              );
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );

      await _startAuthenticated(tester);
      await tester.pumpAndSettle();
      await _tapButton(tester, 'aktywnego treningu');

      final completed = SharedSession.fromJson(
        _sessionResponse(
          startedByRole: 'trainer',
          status: 'completed',
          version: 2,
        ),
      );
      realtimeClient.emit(completed);
      await tester.pumpAndSettle();
      realtimeClient.emit(completed);
      await tester.pumpAndSettle();

      expect(find.text('Jak się czujesz po treningu?'), findsOneWidget);
    });

    testWidgets('trainer completion never opens trainee feedback form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          includeSharedSessionClient: true,
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              return http.Response(
                jsonEncode(_trainerRelationshipWithAssignedSet()),
                200,
              );
            }
            if (request.url.path == '/shared-sessions/from-workout-set') {
              return http.Response(jsonEncode(_sessionResponse()), 201);
            }
            if (request.url.path == '/shared-sessions/session-1/complete') {
              return http.Response(
                jsonEncode(_sessionResponse(status: 'completed', version: 2)),
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
      await _tapButton(tester, 'Rozpocznij wspólny trening');
      await _tapButton(tester, 'Zakończ i zapisz trening');

      expect(find.text('Jak się czujesz po treningu?'), findsNothing);
      expect(find.text('PODOPIECZNI'), findsOneWidget);
    });

    testWidgets(
      'trainee adds feedback from history and returns to refreshed detail',
      (tester) async {
        var detailRequests = 0;
        await tester.pumpWidget(
          _testApp(
            includeSharedSessionClient: true,
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-1'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('Test Trainer')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/workout-sets') {
                return http.Response('[]', 200);
              }
              if (request.url.path == '/shared-sessions/active') {
                return http.Response('', 404);
              }
              if (request.url.path == '/training-history/sessions') {
                return http.Response(
                  jsonEncode({
                    'items': [_historySessionSummary()],
                    'nextCursor': null,
                  }),
                  200,
                );
              }
              if (request.url.path == '/training-history/sessions/session-1') {
                detailRequests += 1;
                return http.Response(
                  jsonEncode(
                    _historySessionDetail(
                      feedback: detailRequests > 1
                          ? _feedbackResponse(rating: 5)
                          : null,
                    ),
                  ),
                  200,
                );
              }
              if (request.url.path == '/shared-sessions/session-1/feedback') {
                return http.Response(
                  jsonEncode(_feedbackResponse(rating: 5)),
                  201,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );

        await _startAuthenticated(tester);
        await tester.tap(find.text('Historia'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('history-session-session-1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dodaj feedback'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('feedback-rating-5')));
        await tester.pump();
        await tester.tap(find.text('Wyślij feedback'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(detailRequests, 2);
        expect(find.text('Samopoczucie: 5/5'), findsOneWidget);
        expect(find.text('Bardzo dobrze'), findsOneWidget);
      },
    );

    testWidgets('trainee unlinked sees enter-code prompt', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee')),
                200,
              );
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
      expect(
        find.byKey(const ValueKey('relationship-trainer-code-field')),
        findsOneWidget,
      );
      expect(find.text('Połącz konto'), findsOneWidget);
    });

    testWidgets('trainee submits a new code and reloads relationship state', (
      tester,
    ) async {
      var linked = false;
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/me') {
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee')),
                200,
              );
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
                jsonEncode(
                  _userResponse(role: 'trainee', trainerUserId: 'trainer-b'),
                ),
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

    testWidgets(
      'failed claim shows readable error and preserves previous state',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/me') {
                return http.Response(
                  jsonEncode(
                    _userResponse(role: 'trainee', trainerUserId: 'trainer-a'),
                  ),
                  200,
                );
              }
              if (request.url.path == '/trainee/relationship') {
                return http.Response(
                  jsonEncode({'trainer': _trainer('Trainer A')}),
                  200,
                );
              }
              if (request.url.path == '/trainee/trainer-link') {
                return http.Response(
                  '{"error":"Trainer invite code was not found."}',
                  404,
                );
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
      },
    );

    testWidgets('logout returns to unauthenticated onboarding', (tester) async {
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
                '{"inviteCode":"7F2K9D","trainees":[]}',
                200,
              );
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
  bool includeSharedSessionClient = false,
  SharedSessionRealtimeClientFactory? sharedSessionRealtimeClientFactory,
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
      onboardingStateStore: FakeOnboardingStateStore(),
      relationshipApiClient: RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      workoutSetApiClient: WorkoutSetApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      sharedSessionApiClient: includeSharedSessionClient
          ? SharedSessionApiClient(
              baseUrl: 'https://api.example.test',
              httpClient: httpClient,
            )
          : null,
      trainingHistoryApiClient: TrainingHistoryApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      postWorkoutFeedbackApiClient: PostWorkoutFeedbackApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      sharedSessionRealtimeClientFactory: includeSharedSessionClient
          ? sharedSessionRealtimeClientFactory ?? _FakeRealtimeClient.new
          : null,
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

Map<String, Object?> _trainerRelationshipWithAssignedSet({
  bool activeSession = false,
  String setName = 'Push A',
  int exerciseCount = 2,
  int rowCount = 5,
}) {
  return {
    'inviteCode': '7F2K9D',
    'trainees': [
      {
        'id': 'trainee-1',
        'email': 'trainee@example.test',
        'displayName': 'Anna Nowak',
        'connectedAt': '2026-03-08T10:00:00Z',
        if (activeSession)
          'activeSession': {
            'sessionId': 'session-1',
            'workoutSetId': 'set-1',
            'workoutSetName': 'Push A',
            'startedByUserId': 'trainee-1',
            'startedByRole': 'trainee',
            'updatedAt': '2026-06-17T12:00:00Z',
          },
        'assignedWorkoutSets': [
          {
            'id': 'set-1',
            'name': setName,
            'exerciseCount': exerciseCount,
            'rowCount': rowCount,
            'updatedAt': '2026-06-16T12:05:00Z',
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _assignedSet() {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'trainerDisplayName': 'Test Trainer',
    'assignedAt': '2026-06-16T12:10:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
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
      {
        'id': 'row-2',
        'exerciseOrder': 2,
        'setIndex': 1,
        'exerciseName': 'Plank',
        'exerciseType': 'time',
        'reps': null,
        'weight': null,
        'seconds': 60,
      },
    ],
  };
}

Future<void> _expectEditableLiveHierarchy(WidgetTester tester) async {
  expect(find.textContaining('Ćwiczenie 1 / 2'), findsOneWidget);
  expect(find.text('Bench press'), findsOneWidget);
  expect(find.text('Seria 1'), findsOneWidget);
  expect(find.text('Seria 2'), findsOneWidget);
  expect(find.byIcon(Icons.add_rounded), findsWidgets);

  expect(find.byKey(const ValueKey('live-rest-footer')), findsOneWidget);
  expect(find.text('Odpoczynek'), findsOneWidget);
  expect(find.byTooltip('Start'), findsOneWidget);
  expect(find.text('+15s'), findsOneWidget);

  await tester.scrollUntilVisible(
    find.text('Plank'),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  expect(find.text('Plank'), findsOneWidget);
  expect(find.text('Zakończ i zapisz trening'), findsOneWidget);
}

Map<String, Object?> _sessionResponse({
  String startedByRole = 'trainer',
  String status = 'active',
  bool includeValues = true,
  int version = 1,
  int firstReps = 6,
  double firstWeight = 40,
  Set<String> completedValueIds = const {},
}) {
  return {
    'id': 'session-1',
    'trainerUserId': 'trainer-1',
    'traineeUserId': 'trainee-1',
    'trainerEmail': 'trainer@example.test',
    'traineeEmail': 'trainee@example.test',
    'workoutSetId': 'set-1',
    'workoutSetName': 'Push A',
    'startedByUserId': startedByRole == 'trainer' ? 'trainer-1' : 'trainee-1',
    'startedByRole': startedByRole,
    'status': status,
    'version': version,
    'createdAt': '2026-06-17T12:00:00Z',
    'updatedAt': '2026-06-17T12:00:00Z',
    'closedAt': status == 'active' ? null : '2026-06-17T13:00:00Z',
    'values': includeValues
        ? [
            {
              'id': 'value-1',
              'exerciseName': 'Bench press',
              'exerciseType': 'repsWeight',
              'exerciseOrder': 1,
              'setIndex': 1,
              'reps': firstReps,
              'weight': firstWeight,
              'seconds': null,
              'isDone': completedValueIds.contains('value-1'),
              'completedAt': null,
              'updatedByUserId': null,
              'updatedAt': null,
            },
            {
              'id': 'value-2',
              'exerciseName': 'Bench press',
              'exerciseType': 'repsWeight',
              'exerciseOrder': 1,
              'setIndex': 2,
              'reps': 6,
              'weight': 42.5,
              'seconds': null,
              'isDone': completedValueIds.contains('value-2'),
              'completedAt': null,
              'updatedByUserId': null,
              'updatedAt': null,
            },
            {
              'id': 'value-3',
              'exerciseName': 'Plank',
              'exerciseType': 'time',
              'exerciseOrder': 2,
              'setIndex': 1,
              'reps': null,
              'weight': null,
              'seconds': 60,
              'isDone': completedValueIds.contains('value-3'),
              'completedAt': null,
              'updatedByUserId': null,
              'updatedAt': null,
            },
          ]
        : <Map<String, Object?>>[],
  };
}

Map<String, Object?> _feedbackResponse({required int rating}) {
  return {
    'sharedSessionId': 'session-1',
    'wellbeingRating': rating,
    'comment': null,
    'submittedAt': '2026-06-17T13:01:00Z',
  };
}

Map<String, Object?> _historySessionSummary() {
  return {
    'id': 'session-1',
    'workoutSetName': 'Push A',
    'startedAt': '2026-06-17T12:00:00Z',
    'completedAt': '2026-06-17T13:00:00Z',
    'durationSeconds': 3600,
    'exerciseCount': 0,
    'seriesCount': 0,
  };
}

Map<String, Object?> _historySessionDetail({Map<String, Object?>? feedback}) {
  return {
    ..._historySessionSummary(),
    'feedback': feedback == null
        ? null
        : {
            'wellbeingRating': feedback['wellbeingRating'],
            'comment': feedback['comment'],
            'submittedAt': feedback['submittedAt'],
          },
    'exercises': <Object?>[],
  };
}

class _FakeRealtimeClient implements SharedSessionRealtimeClient {
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController =
      StreamController<SharedSessionConnectionStatus>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  final joinedSessionIds = <String>[];

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus =>
      _statusController.stream;

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Future<void> connect({required String accessToken}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> joinSession({required String sessionId}) async {
    joinedSessionIds.add(sessionId);
  }

  void emit(SharedSession session) {
    _updatesController.add(session);
  }

  Future<void> dispose() async {
    await _updatesController.close();
    await _statusController.close();
    await _errorsController.close();
  }
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
