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
  test('shared session parses rest snapshot with legacy fallback', () {
    final json = _sessionJson();

    expect(SharedSession.fromJson(json).restSeconds, 90);
    expect(
      SharedSession.fromJson({...json, 'restSeconds': 120}).restSeconds,
      120,
    );
  });

  test('completed series label follows Polish grammar', () {
    expect(completedSeriesLabel(1), '1 ukończona seria');
    expect(completedSeriesLabel(2), '2 ukończone serie');
    expect(completedSeriesLabel(5), '5 ukończonych serii');
    expect(completedSeriesLabel(12), '12 ukończonych serii');
    expect(completedSeriesLabel(22), '22 ukończone serie');
  });

  testWidgets('trainer header shows elapsed time from server session start', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 6, 20, 12);
    final authController = await _authController();
    final apiClient = _FakeSharedSessionApiClient(
      session: _session(createdAt: now.subtract(const Duration(seconds: 65))),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          traineeDisplayName: 'Anna Nowak',
          onBack: () {},
          now: () => now,
        ),
      ),
    );

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('żywo'), findsNothing);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('01:06'), findsOneWidget);
  });

  testWidgets('trainer live screen renders editable rows and sends updates', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          traineeDisplayName: 'Anna Nowak',
          onBack: () {},
        ),
      ),
    );

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('trainee@example.test'), findsNothing);
    expect(find.text('Zestaw Push A'), findsOneWidget);
    expect(find.textContaining('set-1'), findsNothing);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('40 kg'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(apiClient.updatedValue?.weight, 42.5);

    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();

    expect(apiClient.updatedValue?.reps, 7);
  });

  testWidgets('finish button closes session and notifies shell', (
    tester,
  ) async {
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
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          onBack: () {},
          onSessionClosed: () async => closed = true,
        ),
      ),
    );

    await tester.tap(find.text('Zakończ i zapisz trening'));
    await tester.pumpAndSettle();

    expect(apiClient.completed, isTrue);
    expect(closed, isTrue);
  });

  testWidgets(
    'failed completion keeps live session visible with actionable error',
    (tester) async {
      final authController = await _authController();
      final apiClient = _FakeSharedSessionApiClient(failComplete: true);
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
      var closed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: _liveTestTheme(),
          home: LiveSessionScreen(
            user: authController.state.user!,
            controller: controller,
            editable: true,
            onBack: () {},
            onSessionClosed: () async => closed = true,
          ),
        ),
      );

      await tester.tap(find.text('Zakończ i zapisz trening'));
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text('Bench press'), findsOneWidget);
      expect(find.textContaining('spróbuj ponownie'), findsOneWidget);
    },
  );

  testWidgets('editable live hierarchy is available at design phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = await _authController();
    final apiClient = _FakeSharedSessionApiClient(
      session: _multiExerciseSession(),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          onBack: () {},
        ),
      ),
    );

    expect(find.textContaining('Ćwiczenie 1 / 2'), findsOneWidget);
    expect(find.text('Bench press'), findsOneWidget);
    expect(find.text('Seria 1'), findsOneWidget);
    expect(find.text('Seria 2'), findsOneWidget);

    expect(find.byKey(const ValueKey('live-rest-footer')), findsOneWidget);
    expect(find.text('+15s'), findsOneWidget);
    expect(find.text('Zakończ i zapisz trening'), findsOneWidget);
  });

  testWidgets('successful series completion restarts configured rest timer', (
    tester,
  ) async {
    final authController = await _authController();
    final apiClient = _FakeSharedSessionApiClient(
      session: _multiExerciseSession(restSeconds: 120),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          traineeDisplayName: 'Anna Nowak',
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Oznacz serię').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('02:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:59'), findsOneWidget);

    await tester.tap(find.byTooltip('Oznacz serię').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets('failed series completion does not start rest', (tester) async {
    final authController = await _authController();
    final apiClient = _FakeSharedSessionApiClient(
      failUpdate: true,
      session: _session(restSeconds: 120),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          traineeDisplayName: 'Anna Nowak',
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Oznacz serię'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets('reverting a completed series does not start rest', (
    tester,
  ) async {
    final authController = await _authController();
    final controller = SharedSessionController(
      apiClient: _FakeSharedSessionApiClient(
        session: _session(restSeconds: 120, isDone: true),
      ),
      authController: authController,
      realtimeClientFactory: _FakeRealtimeClient.new,
    );
    addTearDown(controller.dispose);
    await controller.loadById(
      user: authController.state.user!,
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cofnij serię'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets('rest footer adds time and resets to session value', (
    tester,
  ) async {
    final authController = await _authController();
    final controller = SharedSessionController(
      apiClient: _FakeSharedSessionApiClient(
        session: _session(restSeconds: 120),
      ),
      authController: authController,
      realtimeClientFactory: _FakeRealtimeClient.new,
    );
    addTearDown(controller.dispose);
    await controller.loadById(
      user: authController.state.user!,
      sessionId: 'session-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: _liveTestTheme(),
        home: LiveSessionScreen(
          user: authController.state.user!,
          controller: controller,
          editable: true,
          onBack: () {},
        ),
      ),
    );

    await tester.tap(find.text('+15s'));
    await tester.pump();
    expect(find.text('02:15'), findsOneWidget);

    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();
    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets(
    'read-only session keeps content visible while rejoin banner retries',
    (tester) async {
      final authController = await _authController(role: 'trainee');
      final realtimeClient = _FakeRealtimeClient();
      final controller = SharedSessionController(
        apiClient: _FakeSharedSessionApiClient(),
        authController: authController,
        realtimeClientFactory: () => realtimeClient,
      );
      addTearDown(controller.dispose);
      await controller.loadById(
        user: authController.state.user!,
        sessionId: 'session-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: _liveTestTheme(),
          home: LiveSessionScreen(
            user: authController.state.user!,
            controller: controller,
            editable: false,
            trainerDisplayName: 'Test Trainer',
            onBack: () {},
          ),
        ),
      );

      realtimeClient.joinError = StateError('group unavailable');
      realtimeClient.emitStatus(SharedSessionConnectionStatus.reconnecting);
      realtimeClient.emitStatus(SharedSessionConnectionStatus.connected);
      await tester.pump();
      await tester.pump();

      expect(find.text('Bench press'), findsOneWidget);
      expect(find.text('40 kg'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('realtime-error-banner')),
        findsOneWidget,
      );

      realtimeClient.joinError = null;
      realtimeClient.emitStatus(SharedSessionConnectionStatus.reconnecting);
      realtimeClient.emitStatus(SharedSessionConnectionStatus.connected);
      await tester.pump();
      await tester.pump();

      expect(find.text('Bench press'), findsOneWidget);
      expect(find.byKey(const ValueKey('realtime-error-banner')), findsNothing);
    },
  );
}

ThemeData _liveTestTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
    ),
  );
}

Future<AuthController> _authController({String role = 'trainer'}) async {
  final authController = AuthController(
    authApiClient: AuthApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresAt': '2026-06-17T12:00:00Z',
            'user': {
              'id': '$role-1',
              'email': '$role@example.test',
              'role': role,
              'displayName': role == 'trainer'
                  ? 'Test Trainer'
                  : 'Test Trainee',
              'trainerUserId': role == 'trainee' ? 'trainer-1' : null,
            },
          }),
          200,
        );
      }),
    ),
    tokenStore: _InMemoryTokenStore(),
  );
  await authController.login(
    email: '$role@example.test',
    password: 'Password123!',
  );
  return authController;
}

SharedSession _session({
  int reps = 6,
  SharedSessionStatus status = SharedSessionStatus.active,
  DateTime? createdAt,
  int restSeconds = 90,
  bool isDone = false,
}) {
  final startedAt = createdAt ?? DateTime.utc(2026, 6, 17);
  return SharedSession(
    id: 'session-1',
    trainerUserId: 'trainer-1',
    traineeUserId: 'trainee-1',
    trainerEmail: 'trainer@example.test',
    traineeEmail: 'trainee@example.test',
    workoutSetId: 'set-1',
    workoutSetName: 'Push A',
    restSeconds: restSeconds,
    startedByUserId: 'trainer-1',
    startedByRole: SharedSessionStartRole.trainer,
    status: status,
    version: reps == 6 ? 1 : 2,
    createdAt: startedAt,
    updatedAt: startedAt,
    values: [
      SharedSessionValue(
        id: 'value-1',
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        exerciseOrder: 1,
        setIndex: 1,
        reps: reps,
        weight: 40,
        isDone: isDone,
      ),
    ],
  );
}

SharedSession _multiExerciseSession({int restSeconds = 90}) {
  final session = _session(restSeconds: restSeconds);
  return SharedSession(
    id: session.id,
    trainerUserId: session.trainerUserId,
    traineeUserId: session.traineeUserId,
    trainerEmail: session.trainerEmail,
    traineeEmail: session.traineeEmail,
    workoutSetId: session.workoutSetId,
    workoutSetName: session.workoutSetName,
    restSeconds: session.restSeconds,
    startedByUserId: session.startedByUserId,
    startedByRole: session.startedByRole,
    status: session.status,
    version: session.version,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    values: [
      session.values.single,
      const SharedSessionValue(
        id: 'value-2',
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        exerciseOrder: 1,
        setIndex: 2,
        reps: 6,
        weight: 42.5,
      ),
      const SharedSessionValue(
        id: 'value-3',
        exerciseName: 'Plank',
        exerciseType: ExerciseValueType.time,
        exerciseOrder: 2,
        setIndex: 1,
        seconds: 60,
      ),
    ],
  );
}

class _FakeSharedSessionApiClient extends SharedSessionApiClient {
  _FakeSharedSessionApiClient({
    SharedSession? session,
    this.failComplete = false,
    this.failUpdate = false,
  }) : _currentSession = session ?? _session(),
       super(baseUrl: 'https://api.example.test');

  SharedSession _currentSession;
  final bool failComplete;
  final bool failUpdate;
  UpdateSharedSessionValue? updatedValue;
  bool completed = false;

  @override
  Future<SharedSessionApiResult<SharedSession>> get({
    required String accessToken,
    required String sessionId,
  }) async {
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
    if (failUpdate) {
      return const SharedSessionApiResult(
        status: SharedSessionApiStatus.error,
        message: 'Nie udało się zsynchronizować serii.',
      );
    }
    _currentSession = _copySessionWithUpdatedValue(
      _currentSession,
      valueId,
      value,
    );
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _currentSession,
    );
  }

  @override
  Future<SharedSessionApiResult<SharedSession>> complete({
    required String accessToken,
    required String sessionId,
  }) async {
    completed = true;
    if (failComplete) {
      return const SharedSessionApiResult(
        status: SharedSessionApiStatus.error,
        message: 'Nie udało się zapisać, spróbuj ponownie.',
      );
    }
    return SharedSessionApiResult(
      status: SharedSessionApiStatus.success,
      message: 'Request succeeded.',
      data: _session(status: SharedSessionStatus.completed),
    );
  }
}

SharedSession _copySessionWithUpdatedValue(
  SharedSession session,
  String valueId,
  UpdateSharedSessionValue update,
) {
  return SharedSession(
    id: session.id,
    trainerUserId: session.trainerUserId,
    traineeUserId: session.traineeUserId,
    trainerEmail: session.trainerEmail,
    traineeEmail: session.traineeEmail,
    workoutSetId: session.workoutSetId,
    workoutSetName: session.workoutSetName,
    restSeconds: session.restSeconds,
    startedByUserId: session.startedByUserId,
    startedByRole: session.startedByRole,
    status: session.status,
    version: session.version + 1,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    values: [
      for (final value in session.values)
        value.id == valueId
            ? SharedSessionValue(
                id: value.id,
                exerciseId: value.exerciseId,
                workoutSetRowId: value.workoutSetRowId,
                exerciseName: value.exerciseName,
                exerciseType: value.exerciseType,
                exerciseOrder: value.exerciseOrder,
                setIndex: value.setIndex,
                reps: update.reps,
                weight: update.weight,
                seconds: update.seconds,
                isDone: update.isDone ?? value.isDone,
              )
            : value,
    ],
  );
}

Map<String, dynamic> _sessionJson() {
  return {
    'id': 'session-1',
    'trainerUserId': 'trainer-1',
    'traineeUserId': 'trainee-1',
    'trainerEmail': 'trainer@example.test',
    'traineeEmail': 'trainee@example.test',
    'workoutSetId': 'set-1',
    'workoutSetName': 'Push A',
    'startedByUserId': 'trainer-1',
    'startedByRole': 'trainer',
    'status': 'active',
    'version': 1,
    'createdAt': '2026-06-20T12:00:00Z',
    'updatedAt': '2026-06-20T12:00:00Z',
    'closedAt': null,
    'values': [
      {
        'id': 'value-1',
        'exerciseId': 'exercise-1',
        'workoutSetRowId': 'row-1',
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'exerciseOrder': 1,
        'setIndex': 1,
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
        'isDone': false,
        'completedAt': null,
        'updatedByUserId': null,
        'updatedAt': null,
      },
    ],
  };
}

class _FakeRealtimeClient implements SharedSessionRealtimeClient {
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController =
      StreamController<SharedSessionConnectionStatus>.broadcast();
  final _errorsController = StreamController<String>.broadcast();
  Object? joinError;

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus =>
      _statusController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> connect({required String accessToken}) async {}

  @override
  Future<void> joinSession({required String sessionId}) async {
    final error = joinError;
    if (error != null) {
      _errorsController.add('Realtime join failed: $error');
      throw error;
    }
  }

  void emitStatus(SharedSessionConnectionStatus status) {
    _statusController.add(status);
  }

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
