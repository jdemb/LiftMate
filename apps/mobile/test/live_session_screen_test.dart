import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/shared_sessions/live_session_screen.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_controller.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  testWidgets('trainer live screen renders editable rows and sends updates',
      (tester) async {
    final authController = await _authController();
    final apiClient = _FakeSharedSessionApiClient();
    final controller = SharedSessionController(
      apiClient: apiClient,
      authController: authController,
      realtimeClientFactory: _FakeRealtimeClient.new,
    );
    addTearDown(controller.dispose);
    await controller.loadById(
      user: authController.state.user!,
      sessionId: 'session-1',
    );

    await tester.pumpWidget(MaterialApp(
      home: LiveSessionScreen(
        user: authController.state.user!,
        controller: controller,
        editable: true,
        onBack: () {},
      ),
    ));

    expect(find.text('Trening live'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('6 powt. Â· 40.0 kg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(apiClient.updatedValue?.reps, 7);
  });
}

Future<AuthController> _authController() async {
  final authController = AuthController(
    authApiClient: AuthApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({
          'accessToken': 'access-token',
          'refreshToken': 'refresh-token',
          'expiresAt': '2026-06-17T12:00:00Z',
          'user': {
            'id': 'trainer-1',
            'email': 'trainer@example.test',
            'role': 'trainer',
            'displayName': 'Test Trainer',
            'trainerUserId': null,
          },
        }), 200);
      }),
    ),
    tokenStore: _InMemoryTokenStore(),
  );
  await authController.login(
    email: 'trainer@example.test',
    password: 'Password123!',
  );
  return authController;
}

SharedSession _session({int reps = 6}) {
  return SharedSession(
    id: 'session-1',
    trainerUserId: 'trainer-1',
    traineeUserId: 'trainee-1',
    trainerEmail: 'trainer@example.test',
    traineeEmail: 'trainee@example.test',
    workoutSetId: 'set-1',
    startedByUserId: 'trainer-1',
    startedByRole: SharedSessionStartRole.trainer,
    status: SharedSessionStatus.active,
    version: reps == 6 ? 1 : 2,
    createdAt: DateTime.utc(2026, 6, 17),
    updatedAt: DateTime.utc(2026, 6, 17),
    values: [
      SharedSessionValue(
        id: 'value-1',
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        exerciseOrder: 1,
        setIndex: 1,
        reps: reps,
        weight: 40,
      ),
    ],
  );
}

class _FakeSharedSessionApiClient extends SharedSessionApiClient {
  _FakeSharedSessionApiClient() : super(baseUrl: 'https://api.example.test');

  UpdateSharedSessionValue? updatedValue;

  @override
  Future<SharedSessionApiResult<SharedSession>> get({
    required String accessToken,
    required String sessionId,
  }) async {
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _session(),
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> updateValue({
    required String accessToken,
    required String sessionId,
    required String valueId,
    required UpdateSharedSessionValue value,
  }) async {
    updatedValue = value;
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _session(reps: value.reps ?? 6),
    );
  }
}

class _FakeRealtimeClient implements SharedSessionRealtimeClient {
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController = StreamController<SharedSessionConnectionStatus>.broadcast();
  final _errorsController = StreamController<String>.broadcast();

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> connect({required String accessToken}) async {}

  @override
  Future<void> joinSession({required String sessionId}) async {}

  @override
  Future<void> disconnect() async {}
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
