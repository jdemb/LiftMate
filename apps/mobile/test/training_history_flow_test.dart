import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/training_history/training_history_api_client.dart';
import 'package:liftmate/training_history/training_history_controller.dart';
import 'package:liftmate/training_history/training_history_flow.dart';

void main() {
  testWidgets('renders paged history and drills through all three levels', (
    tester,
  ) async {
    final requests = <Uri>[];
    final controller = _controller(
      MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/training-history/sessions' &&
            request.url.queryParameters['cursor'] == null) {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': 'next-page',
          });
        }
        if (request.url.path == '/training-history/sessions' &&
            request.url.queryParameters['cursor'] == 'next-page') {
          return _jsonResponse({
            'items': [_sessionSummary('session-2', 'Leg Day')],
            'nextCursor': null,
          });
        }
        if (request.url.path == '/training-history/sessions/session-1') {
          return _jsonResponse(_sessionDetail());
        }
        if (request.url.path == '/training-history/exercises/exercise-1') {
          return _jsonResponse(_progress());
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('Historia treningów'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('1 godz. 5 min'), findsOneWidget);
    expect(find.text('2 ćwiczenia'), findsOneWidget);
    expect(find.text('5 serii'), findsOneWidget);

    await tester.tap(find.text('Załaduj więcej'));
    await tester.pumpAndSettle();
    expect(find.text('Leg Day'), findsOneWidget);
    expect(
      requests.where((uri) => uri.queryParameters['cursor'] == 'next-page'),
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey('history-session-session-1')));
    await tester.pumpAndSettle();
    expect(
      controller.state.detail,
      isNotNull,
      reason: '${controller.state.message}; requests: $requests',
    );
    expect(find.text('60×8'), findsOneWidget);
    expect(find.text('60×7'), findsOneWidget);
    expect(find.text('postęp ›'), findsOneWidget);
    expect(find.text('progres ›'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('history-exercise-exercise-1')));
    await tester.pumpAndSettle();
    expect(find.text('Postęp ćwiczenia'), findsOneWidget);
    expect(find.textContaining('Progres'), findsNothing);
    expect(find.text('Wyciskanie sztangi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-progress-chart')),
      findsOneWidget,
    );
    expect(find.text('+2,5 kg'), findsWidgets);
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('PR'), findsNothing);

    await tester.tap(find.byTooltip('Wróć'));
    await tester.pumpAndSettle();
    expect(find.text('60×8'), findsOneWidget);
    await tester.tap(find.byTooltip('Wróć'));
    await tester.pumpAndSettle();
    expect(find.text('Leg Day'), findsOneWidget);
  });

  testWidgets('keeps loaded sessions when pagination fails and retries', (
    tester,
  ) async {
    var pageAttempts = 0;
    final controller = _controller(
      MockClient((request) async {
        if (request.url.queryParameters['cursor'] == null) {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': 'next-page',
          });
        }
        pageAttempts += 1;
        if (pageAttempts == 1) {
          return http.Response(
            '{"error":"Historia chwilowo niedostępna."}',
            503,
          );
        }
        return _jsonResponse({
          'items': [_sessionSummary('session-2', 'Leg Day')],
          'nextCursor': null,
        });
      }),
    );

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Załaduj więcej'));
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-pagination-error')),
      findsOneWidget,
    );

    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
  });

  testWidgets('progress chart fits a narrow phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller(
      MockClient((request) async {
        if (request.url.path == '/training-history/sessions') {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': null,
          });
        }
        if (request.url.path.endsWith('session-1')) {
          return _jsonResponse(_sessionDetail());
        }
        return _jsonResponse(_progress());
      }),
    );

    await tester.pumpWidget(_app(controller, disableAnimations: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-session-session-1')));
    await tester.pumpAndSettle();
    expect(
      controller.state.detail,
      isNotNull,
      reason: controller.state.message,
    );
    await tester.tap(find.byKey(const ValueKey('history-exercise-exercise-1')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('history-progress-chart')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ScaleTransition>(
            find.descendant(
              of: find.byKey(const ValueKey('history-progress-chart')),
              matching: find.byType(ScaleTransition),
            ),
          )
          .every((transition) => transition.scale.value == 1),
      isTrue,
    );
  });

  testWidgets('trainer history level one exposes close action', (tester) async {
    var closed = false;
    final controller = _controller(
      MockClient((request) async {
        return _jsonResponse({'items': [], 'nextCursor': null});
      }),
    );

    await tester.pumpWidget(
      _app(controller, showLevelOneBack: true, onClose: () => closed = true),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Wróć'), findsOneWidget);
    await tester.tap(find.byTooltip('Wróć'));
    expect(closed, isTrue);
  });

  testWidgets('trainee without feedback can add it for the open session', (
    tester,
  ) async {
    String? requestedSessionId;
    final controller = _controller(
      MockClient((request) async {
        if (request.url.path == '/training-history/sessions') {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': null,
          });
        }
        return _jsonResponse({..._sessionDetail(), 'feedback': null});
      }),
    );

    await tester.pumpWidget(
      _app(
        controller,
        viewerRole: UserRole.trainee,
        onAddFeedback: (sessionId) => requestedSessionId = sessionId,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-session-session-1')));
    await tester.pumpAndSettle();

    expect(find.text('Feedback podopiecznego'), findsOneWidget);
    expect(find.text('Dodaj feedback'), findsOneWidget);
    await tester.tap(find.text('Dodaj feedback'));
    expect(requestedSessionId, 'session-1');
  });

  testWidgets('trainer without feedback sees read-only empty state', (
    tester,
  ) async {
    final controller = _controller(
      MockClient((request) async {
        if (request.url.path == '/training-history/sessions') {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': null,
          });
        }
        return _jsonResponse({..._sessionDetail(), 'feedback': null});
      }),
    );

    await tester.pumpWidget(_app(controller, viewerRole: UserRole.trainer));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-session-session-1')));
    await tester.pumpAndSettle();

    expect(find.text('Feedback podopiecznego'), findsOneWidget);
    expect(find.text('Brak feedbacku'), findsOneWidget);
    expect(find.text('Dodaj feedback'), findsNothing);
  });

  testWidgets('saved feedback is rendered read-only before exercises', (
    tester,
  ) async {
    final controller = _controller(
      MockClient((request) async {
        if (request.url.path == '/training-history/sessions') {
          return _jsonResponse({
            'items': [_sessionSummary('session-1', 'Push A')],
            'nextCursor': null,
          });
        }
        return _jsonResponse({
          ..._sessionDetail(),
          'feedback': {
            'wellbeingRating': 4,
            'comment': 'Dobry trening',
            'submittedAt': '2026-06-17T11:06:00Z',
          },
        });
      }),
    );

    await tester.pumpWidget(_app(controller, viewerRole: UserRole.trainer));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-session-session-1')));
    await tester.pumpAndSettle();

    expect(find.text('Samopoczucie: 4/5'), findsOneWidget);
    expect(find.text('Dobrze'), findsOneWidget);
    expect(find.text('Dobry trening'), findsOneWidget);
    expect(find.text('Dodaj feedback'), findsNothing);

    final feedbackTop = tester.getTopLeft(
      find.byKey(const ValueKey('history-feedback-card')),
    );
    final exerciseTop = tester.getTopLeft(
      find.byKey(const ValueKey('history-exercise-exercise-1')),
    );
    expect(feedbackTop.dy, lessThan(exerciseTop.dy));
  });
}

TrainingHistoryController _controller(http.Client client) {
  return TrainingHistoryController(
    apiClient: TrainingHistoryApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: client,
    ),
    accessTokenProvider: () => 'access-token',
  );
}

Widget _app(
  TrainingHistoryController controller, {
  UserRole viewerRole = UserRole.trainee,
  ValueChanged<String>? onAddFeedback,
  bool showLevelOneBack = false,
  VoidCallback? onClose,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: TrainingHistoryFlow(
          controller: controller,
          viewerRole: viewerRole,
          onAddFeedback: onAddFeedback,
          onClose: onClose ?? () {},
          showLevelOneBack: showLevelOneBack,
        ),
      ),
    ),
  );
}

Map<String, Object?> _sessionSummary(String id, String name) {
  return {
    'id': id,
    'workoutSetName': name,
    'startedAt': '2026-06-17T10:00:00Z',
    'completedAt': '2026-06-17T11:05:00Z',
    'durationSeconds': 3900,
    'exerciseCount': 2,
    'seriesCount': 5,
  };
}

Map<String, Object?> _sessionDetail() {
  return {
    ..._sessionSummary('session-1', 'Push A'),
    'exercises': [
      {
        'exerciseId': 'exercise-1',
        'exerciseName': 'Wyciskanie sztangi',
        'exerciseType': 'repsWeight',
        'exerciseOrder': 1,
        'maximumValue': 60,
        'series': [
          {'setIndex': 1, 'reps': 8, 'weight': 60, 'seconds': null},
          {'setIndex': 2, 'reps': 7, 'weight': 60, 'seconds': null},
        ],
      },
      {
        'exerciseId': null,
        'exerciseName': 'Starsze ćwiczenie',
        'exerciseType': 'time',
        'exerciseOrder': 2,
        'maximumValue': 45,
        'series': [
          {'setIndex': 1, 'reps': null, 'weight': null, 'seconds': 45},
        ],
      },
    ],
  };
}

Map<String, Object?> _progress() {
  return {
    'exerciseId': 'exercise-1',
    'exerciseName': 'Wyciskanie sztangi',
    'exerciseType': 'repsWeight',
    'unit': 'kg',
    'startValue': 55,
    'currentValue': 60,
    'overallDelta': 5,
    'points': [
      {
        'sessionId': 'session-0',
        'completedAt': '2026-06-01T11:00:00Z',
        'value': 55,
        'delta': null,
      },
      {
        'sessionId': 'session-1',
        'completedAt': '2026-06-17T11:05:00Z',
        'value': 57.5,
        'delta': 2.5,
      },
      {
        'sessionId': 'session-2',
        'completedAt': '2026-06-18T11:05:00Z',
        'value': 60,
        'delta': 2.5,
      },
    ],
  };
}

http.Response _jsonResponse(Object body, [int statusCode = 200]) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
