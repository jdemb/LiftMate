import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_diagnostic_panel.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('SharedSessionDiagnosticPanel', () {
    testWidgets('shows authenticated user and creates trainer demo session', (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(apiClient: apiClient, realtimeClient: realtimeClient),
      );

      expect(find.text('Shared session diagnostics'), findsOneWidget);
      expect(find.text('Current user: trainer-1 (trainer)'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Trainee user ID'), 'trainee-1');
      await tester.tap(find.text('Create demo session'));
      await tester.pumpAndSettle();

      expect(apiClient.createdForTraineeUserId, 'trainee-1');
      expect(realtimeClient.connectedSessionId, 'session-1');
      expect(find.text('Status: active'), findsOneWidget);
      expect(find.text('Version: 1'), findsOneWidget);
      expect(find.textContaining('Bench press'), findsOneWidget);
    });

    testWidgets('joins an existing session by id', (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(apiClient: apiClient, realtimeClient: realtimeClient),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Session ID'), 'session-1');
      await tester.tap(find.text('Join session'));
      await tester.pumpAndSettle();

      expect(apiClient.requestedSessionId, 'session-1');
      expect(realtimeClient.connectedSessionId, 'session-1');
      expect(find.text('Status: active'), findsOneWidget);
    });

    testWidgets('renders incoming realtime update without real SignalR', (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(apiClient: apiClient, realtimeClient: realtimeClient),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Session ID'), 'session-1');
      await tester.tap(find.text('Join session'));
      await tester.pumpAndSettle();

      realtimeClient.emit(_session(version: 2, reps: 10, weight: 45));
      await tester.pumpAndSettle();

      expect(find.text('Version: 2'), findsOneWidget);
      expect(find.textContaining('10 reps'), findsOneWidget);
      expect(find.textContaining('45.0 kg'), findsOneWidget);
      expect(find.text('Session update received.'), findsOneWidget);
    });

    testWidgets('updates first value through API client', (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(apiClient: apiClient, realtimeClient: realtimeClient),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Session ID'), 'session-1');
      await tester.tap(find.text('Join session'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Reps'), '9');
      await tester.enterText(find.widgetWithText(TextField, 'Weight'), '43.5');
      await tester.ensureVisible(find.text('Update first value'));
      await tester.tap(find.text('Update first value'));
      await tester.pumpAndSettle();

      expect(apiClient.updatedSessionId, 'session-1');
      expect(apiClient.updatedValueId, 'value-1');
      expect(apiClient.updatedValue?.reps, 9);
      expect(apiClient.updatedValue?.weight, 43.5);
    });

    testWidgets('disables edits after completed session', (tester) async {
      final apiClient = _FakeSharedSessionApiClient(
        initialSession: _session(status: SharedSessionStatus.completed),
      );
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(apiClient: apiClient, realtimeClient: realtimeClient),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Session ID'), 'session-1');
      await tester.tap(find.text('Join session'));
      await tester.pumpAndSettle();

      final updateButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update first value'),
      );
      expect(updateButton.onPressed, isNull);
    });
  });
}

Future<Widget> _testApp({
  required _FakeSharedSessionApiClient apiClient,
  required _FakeSharedSessionRealtimeClient realtimeClient,
}) async {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode(_authResponse()), 200);
      }
      return http.Response('', 404);
    }),
  );
  final authController = AuthController(
    authApiClient: authApiClient,
    tokenStore: _InMemoryTokenStore(),
  );
  await authController.login(
    email: 'trainer@example.test',
    password: 'Password123!',
  );

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SharedSessionDiagnosticPanel(
          authController: authController,
          user: authController.state.user!,
          sharedSessionApiClient: apiClient,
          realtimeClientFactory: () => realtimeClient,
        ),
      ),
    ),
  );
}

Map<String, Object?> _authResponse() {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-03T12:00:00Z',
    'user': {
      'id': 'trainer-1',
      'email': 'trainer@example.test',
      'role': 'trainer',
    },
  };
}

SharedSession _session({
  SharedSessionStatus status = SharedSessionStatus.active,
  int version = 1,
  int reps = 6,
  double weight = 40,
}) {
  return SharedSession(
    id: 'session-1',
    trainerUserId: 'trainer-1',
    traineeUserId: 'trainee-1',
    status: status,
    version: version,
    createdAt: DateTime.parse('2026-06-03T12:00:00Z').toUtc(),
    updatedAt: DateTime.parse('2026-06-03T12:00:00Z').toUtc(),
    closedAt: status == SharedSessionStatus.active
        ? null
        : DateTime.parse('2026-06-03T12:05:00Z').toUtc(),
    values: [
      SharedSessionValue(
        id: 'value-1',
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        setIndex: 1,
        reps: reps,
        weight: weight,
      ),
    ],
  );
}

class _FakeSharedSessionApiClient extends SharedSessionApiClient {
  _FakeSharedSessionApiClient({SharedSession? initialSession})
      : _currentSession = initialSession ?? _session(),
        super(baseUrl: 'https://api.example.test');

  SharedSession _currentSession;
  String? createdForTraineeUserId;
  String? requestedSessionId;
  String? updatedSessionId;
  String? updatedValueId;
  UpdateSharedSessionValue? updatedValue;

  @override
  Future<SharedSessionApiResult<SharedSession>> create({
    required String accessToken,
    required String traineeUserId,
    required List<CreateSharedSessionValue> values,
  }) async {
    createdForTraineeUserId = traineeUserId;
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> get({
    required String accessToken,
    required String sessionId,
  }) async {
    requestedSessionId = sessionId;
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> updateValue({
    required String accessToken,
    required String sessionId,
    required String valueId,
    required UpdateSharedSessionValue value,
  }) async {
    updatedSessionId = sessionId;
    updatedValueId = valueId;
    updatedValue = value;
    _currentSession = _session(
      version: _currentSession.version + 1,
      reps: value.reps ?? 0,
      weight: value.weight ?? 0,
    );
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }
}

class _FakeSharedSessionRealtimeClient implements SharedSessionRealtimeClient {
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController = StreamController<SharedSessionConnectionStatus>.broadcast();
  String? connectedAccessToken;
  String? connectedSessionId;

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Future<void> connect({
    required String accessToken,
    required String sessionId,
  }) async {
    connectedAccessToken = accessToken;
    connectedSessionId = sessionId;
    _statusController.add(SharedSessionConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _statusController.add(SharedSessionConnectionStatus.disconnected);
  }

  void emit(SharedSession session) {
    _updatesController.add(session);
  }
}

class _InMemoryTokenStore implements TokenStore {
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
