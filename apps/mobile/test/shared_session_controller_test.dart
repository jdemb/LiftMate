import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_controller.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('SharedSessionController', () {
    test('self-start loads session and joins realtime group', () async {
      final authController = await _authController(role: UserRole.trainee);
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);

      final result = await controller.startTraineeSession(
        user: authController.state.user!,
        workoutSetId: 'set-1',
      );

      expect(result.status, SharedSessionApiStatus.success);
      expect(apiClient.startedTraineeWorkoutSetId, 'set-1');
      expect(controller.state.status, SharedSessionControllerStatus.loaded);
      expect(controller.state.session?.isTraineeSelfStarted, isTrue);
      expect(realtimeClient.connectedAccessToken, 'access-token');
      expect(realtimeClient.joinedSessionIds, ['session-1']);
    });

    test('loadById supports trainer-led join', () async {
      final authController = await _authController(role: UserRole.trainer);
      final apiClient = _FakeSharedSessionApiClient(
        activeSession: _session(startedByRole: SharedSessionStartRole.trainer),
      );
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);

      await controller.loadById(
        user: authController.state.user!,
        sessionId: 'session-1',
      );

      expect(apiClient.loadedSessionId, 'session-1');
      expect(controller.state.session?.isTrainerLed, isTrue);
      expect(realtimeClient.joinedSessionIds, ['session-1']);
    });

    test('loadById rejects closed sessions as not joinable', () async {
      final authController = await _authController(role: UserRole.trainer);
      final apiClient = _FakeSharedSessionApiClient(
        activeSession: _session(status: SharedSessionStatus.completed),
      );
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);

      await controller.loadById(
        user: authController.state.user!,
        sessionId: 'session-1',
      );

      expect(controller.state.status, SharedSessionControllerStatus.error);
      expect(controller.state.session, isNull);
      expect(realtimeClient.joinedSessionIds, isEmpty);
    });

    test('failed self-start leaves no loaded session', () async {
      final authController = await _authController(role: UserRole.trainee);
      final apiClient = _FakeSharedSessionApiClient(
        startTraineeResult: const SharedSessionApiResult(
          status: SharedSessionApiStatus.conflict,
          message: 'Session already exists.',
        ),
      );
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);

      final result = await controller.startTraineeSession(
        user: authController.state.user!,
        workoutSetId: 'set-1',
      );

      expect(result.status, SharedSessionApiStatus.conflict);
      expect(controller.state.status, SharedSessionControllerStatus.error);
      expect(controller.state.session, isNull);
      expect(realtimeClient.joinedSessionIds, isEmpty);
    });

    test('toggleDone sends canonical done-state mutation', () async {
      final authController = await _authController(role: UserRole.trainee);
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);
      await controller.startTraineeSession(
        user: authController.state.user!,
        workoutSetId: 'set-1',
      );

      await controller.toggleDone(
        user: authController.state.user!,
        value: controller.state.session!.values.single,
        isDone: true,
      );

      expect(apiClient.updatedValue?.isDone, isTrue);
      expect(controller.state.session?.values.single.isDone, isTrue);
    });

    test('connected realtime with empty state recovers active session', () async {
      final authController = await _authController(role: UserRole.trainee);
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);

      realtimeClient.emitStatus(SharedSessionConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(apiClient.activeRequestedCount, 1);
      expect(controller.state.session?.id, 'session-1');
    });

    test('trainer realtime session invalidates relationship data', () async {
      final authController = await _authController(role: UserRole.trainer);
      final apiClient = _FakeSharedSessionApiClient();
      final realtimeClient = _FakeSharedSessionRealtimeClient();
      var invalidations = 0;
      final controller = SharedSessionController(
        apiClient: apiClient,
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
        onTrainerSessionInvalidated: () => invalidations += 1,
      );
      addTearDown(controller.dispose);
      await controller.loadActive(authController.state.user!);

      realtimeClient.emit(_session(startedByRole: SharedSessionStartRole.trainee));
      await Future<void>.delayed(Duration.zero);

      expect(invalidations, 1);
      expect(controller.state.session?.startedByRole, SharedSessionStartRole.trainee);
    });
  });
}

Future<AuthController> _authController({required UserRole role}) async {
  final authController = AuthController(
    authApiClient: AuthApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode(_authResponse(role)), 200);
      }),
    ),
    tokenStore: _InMemoryTokenStore(),
  );
  await authController.login(
    email: '${role.wireName}@example.test',
    password: 'Password123!',
  );
  return authController;
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
      'displayName': role == UserRole.trainer ? 'Test Trainer' : 'Test Trainee',
      'trainerUserId': role == UserRole.trainee ? 'trainer-1' : null,
    },
  };
}

SharedSession _session({
  SharedSessionStartRole startedByRole = SharedSessionStartRole.trainee,
  SharedSessionStatus status = SharedSessionStatus.active,
  bool isDone = false,
}) {
  return SharedSession(
    id: 'session-1',
    trainerUserId: 'trainer-1',
    traineeUserId: 'trainee-1',
    trainerEmail: 'trainer@example.test',
    traineeEmail: 'trainee@example.test',
    workoutSetId: 'set-1',
    startedByUserId:
        startedByRole == SharedSessionStartRole.trainer ? 'trainer-1' : 'trainee-1',
    startedByRole: startedByRole,
    status: status,
    version: isDone ? 2 : 1,
    createdAt: DateTime.parse('2026-06-03T12:00:00Z').toUtc(),
    updatedAt: DateTime.parse('2026-06-03T12:00:00Z').toUtc(),
    values: [
      SharedSessionValue(
        id: 'value-1',
        exerciseOrder: 1,
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        setIndex: 1,
        reps: 6,
        weight: 40,
        isDone: isDone,
      ),
    ],
  );
}

class _FakeSharedSessionApiClient extends SharedSessionApiClient {
  _FakeSharedSessionApiClient({
    SharedSession? activeSession,
    this._startTraineeResult,
  })
      : _currentSession = activeSession ?? _session(),
        super(baseUrl: 'https://api.example.test');

  SharedSession _currentSession;
  final SharedSessionApiResult<SharedSession>? _startTraineeResult;
  int activeRequestedCount = 0;
  String? startedTraineeWorkoutSetId;
  String? loadedSessionId;
  UpdateSharedSessionValue? updatedValue;

  @override
  Future<SharedSessionApiResult<SharedSession>> getActive({
    required String accessToken,
  }) async {
    activeRequestedCount += 1;
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
    loadedSessionId = sessionId;
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> startTraineeSession({
    required String accessToken,
    required String workoutSetId,
  }) async {
    startedTraineeWorkoutSetId = workoutSetId;
    final startTraineeResult = _startTraineeResult;
    if (startTraineeResult != null) {
      return startTraineeResult;
    }

    _currentSession = _session(startedByRole: SharedSessionStartRole.trainee);
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
    updatedValue = value;
    _currentSession = _session(
      startedByRole: _currentSession.startedByRole,
      isDone: value.isDone ?? false,
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
  Future<void> connect({required String accessToken}) async {
    connectedAccessToken = accessToken;
    _statusController.add(SharedSessionConnectionStatus.connected);
  }

  @override
  Future<void> joinSession({required String sessionId}) async {
    joinedSessionIds.add(sessionId);
  }

  @override
  Future<void> disconnect() async {
    _statusController.add(SharedSessionConnectionStatus.disconnected);
  }

  void emit(SharedSession session) {
    _updatesController.add(session);
  }

  void emitStatus(SharedSessionConnectionStatus status) {
    _statusController.add(status);
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
