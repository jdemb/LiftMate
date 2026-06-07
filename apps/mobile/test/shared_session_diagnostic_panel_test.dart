import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_diagnostic_panel.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('SharedSessionDiagnosticPanel', () {
    testWidgets('trainer creates a demo session by trainee email without session IDs',
        (tester) async {
      final apiClient = _FakeSharedSessionApiClient(hasActiveSession: false);
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared session diagnostics'), findsOneWidget);
      expect(find.text('Current user: trainer-1 (trainer)'), findsOneWidget);
      expect(find.text('Session ID'), findsNothing);
      expect(find.text('Join session'), findsNothing);
      expect(find.text('Trainee user ID'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Trainee email'),
        'trainee@example.test',
      );
      await tester.tap(find.text('Create demo session'));
      await tester.pumpAndSettle();

      expect(apiClient.createdForTraineeEmail, 'trainee@example.test');
      expect(realtimeClient.connectedAccessToken, 'access-token');
      expect(realtimeClient.joinedSessionIds, ['session-1']);
      expect(find.text('Status: active'), findsOneWidget);
      expect(find.text('Version: 1'), findsOneWidget);
      expect(find.textContaining('Bench press'), findsOneWidget);
    });

    testWidgets('trainee waits without manual session ID or join controls', (tester) async {
      final apiClient = _FakeSharedSessionApiClient(hasActiveSession: false);
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainee,
        ),
      );
      await tester.pumpAndSettle();

      expect(apiClient.activeRequestedCount, 1);
      expect(find.text('Waiting for trainer to start a session.'), findsWidgets);
      expect(find.text('Session ID'), findsNothing);
      expect(find.text('Join session'), findsNothing);
      expect(find.text('Trainee email'), findsNothing);
    });

    testWidgets('trainee logged in after session creation auto-loads active session',
        (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainee,
        ),
      );
      await tester.pumpAndSettle();

      expect(apiClient.activeRequestedCount, 1);
      expect(realtimeClient.connectedAccessToken, 'access-token');
      expect(realtimeClient.joinedSessionIds, ['session-1']);
      expect(find.text('Trainer: trainer@example.test'), findsOneWidget);
      expect(find.text('Trainee: trainee@example.test'), findsOneWidget);
      expect(find.text('Status: active'), findsOneWidget);
    });

    testWidgets('already logged-in trainee renders trainer-started session without refresh',
        (tester) async {
      final apiClient = _FakeSharedSessionApiClient(hasActiveSession: false);
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainee,
        ),
      );
      await tester.pumpAndSettle();

      realtimeClient.emit(_session(version: 2, reps: 10, weight: 45));
      await tester.pumpAndSettle();

      expect(find.text('Version: 2'), findsOneWidget);
      expect(find.textContaining('10 reps'), findsOneWidget);
      expect(find.textContaining('45.0 kg'), findsOneWidget);
      expect(find.text('Session update received.'), findsOneWidget);
      expect(realtimeClient.joinedSessionIds, ['session-1']);
    });

    testWidgets('updates first value through internally discovered session ID',
        (tester) async {
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainee,
        ),
      );
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
        activeSession: _session(status: SharedSessionStatus.completed),
      );
      final realtimeClient = _FakeSharedSessionRealtimeClient();

      await tester.pumpWidget(
        await _testApp(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
          role: UserRole.trainee,
        ),
      );
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
  required UserRole role,
}) async {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/login') {
        return http.Response(jsonEncode(_authResponse(role)), 200);
      }
      return http.Response('', 404);
    }),
  );
  final authController = AuthController(
    authApiClient: authApiClient,
    tokenStore: _InMemoryTokenStore(),
  );
  await authController.login(
    email: '${role.wireName}@example.test',
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

Map<String, Object?> _authResponse(UserRole role) {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-03T12:00:00Z',
    'user': {
      'id': role == UserRole.trainer ? 'trainer-1' : 'trainee-1',
      'email': '${role.wireName}@example.test',
      'role': role.wireName,
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
    trainerEmail: 'trainer@example.test',
    traineeEmail: 'trainee@example.test',
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
  _FakeSharedSessionApiClient({
    SharedSession? activeSession,
    this.hasActiveSession = true,
  })
      : _currentSession = activeSession ?? _session(),
        super(baseUrl: 'https://api.example.test');

  SharedSession _currentSession;
  bool hasActiveSession;
  String? createdForTraineeEmail;
  String? updatedSessionId;
  String? updatedValueId;
  UpdateSharedSessionValue? updatedValue;
  int activeRequestedCount = 0;

  @override
  Future<SharedSessionApiResult<SharedSession>> create({
    required String accessToken,
    required String traineeEmail,
    required List<CreateSharedSessionValue> values,
  }) async {
    createdForTraineeEmail = traineeEmail;
    hasActiveSession = true;
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> getActive({
    required String accessToken,
  }) async {
    activeRequestedCount += 1;
    if (!hasActiveSession) {
      return const SharedSessionApiResult(
        status: SharedSessionApiStatus.notFound,
        message: 'No active shared session yet.',
      );
    }

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
  final _errorsController = StreamController<String>.broadcast();
  String? connectedAccessToken;
  final joinedSessionIds = <String>[];

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> connect({
    required String accessToken,
  }) async {
    connectedAccessToken = accessToken;
    _statusController.add(SharedSessionConnectionStatus.connected);
  }

  @override
  Future<void> joinSession({
    required String sessionId,
  }) async {
    if (!joinedSessionIds.contains(sessionId)) {
      joinedSessionIds.add(sessionId);
    }
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
