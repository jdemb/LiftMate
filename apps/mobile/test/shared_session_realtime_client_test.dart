import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('SignalRSharedSessionRealtimeClient', () {
    test(
      'connect starts connection, joins session, and exposes start/update payloads',
      () async {
        late _FakeHubConnectionAdapter fakeConnection;
        late AccessTokenProvider tokenProvider;
        final client = SignalRSharedSessionRealtimeClient(
          baseUrl: 'https://api.example.test/',
          hubConnectionFactory: (hubUrl, provider) {
            tokenProvider = provider;
            fakeConnection = _FakeHubConnectionAdapter(hubUrl, 'unused');
            return fakeConnection;
          },
        );

        final statuses = <SharedSessionConnectionStatus>[];
        final updates = <SharedSession>[];
        final statusSubscription = client.connectionStatus.listen(statuses.add);
        final updateSubscription = client.updates.listen(updates.add);

        await client.connect(accessToken: 'access-token');
        await client.joinSession(sessionId: 'session-1');
        fakeConnection.emitSessionStarted(_sessionJson(version: 1));
        fakeConnection.emitSessionUpdated(_sessionJson());
        await Future<void>.delayed(Duration.zero);

        expect(
          fakeConnection.hubUrl,
          'https://api.example.test/hubs/shared-sessions',
        );
        expect(await tokenProvider(), 'access-token');
        expect(fakeConnection.started, isTrue);
        expect(fakeConnection.invocations, hasLength(1));
        expect(fakeConnection.invocations.single.$1, 'JoinSession');
        expect(fakeConnection.invocations.single.$2, ['session-1']);
        expect(
          statuses,
          containsAllInOrder([
            SharedSessionConnectionStatus.connecting,
            SharedSessionConnectionStatus.connected,
          ]),
        );
        expect(updates, hasLength(2));
        expect(updates.first.version, 1);
        expect(updates.last.version, 2);

        await updateSubscription.cancel();
        await statusSubscription.cancel();
      },
    );

    test('disconnect stops active connection', () async {
      late _FakeHubConnectionAdapter fakeConnection;
      final client = SignalRSharedSessionRealtimeClient(
        baseUrl: 'https://api.example.test',
        hubConnectionFactory: (hubUrl, _) {
          fakeConnection = _FakeHubConnectionAdapter(hubUrl, 'unused');
          return fakeConnection;
        },
      );

      await client.connect(accessToken: 'access-token');
      await client.disconnect();

      expect(fakeConnection.stopped, isTrue);
    });

    test('throws when API base URL is missing', () async {
      final client = SignalRSharedSessionRealtimeClient(baseUrl: '');

      await expectLater(
        client.connect(accessToken: 'access-token'),
        throwsStateError,
      );
    });

    test(
      'surfaces join failures instead of silently collapsing to disconnected',
      () async {
        late _FakeHubConnectionAdapter fakeConnection;
        final client = SignalRSharedSessionRealtimeClient(
          baseUrl: 'https://api.example.test',
          hubConnectionFactory: (hubUrl, _) {
            fakeConnection = _FakeHubConnectionAdapter(
              hubUrl,
              'unused',
              joinError: StateError('join denied'),
            );
            return fakeConnection;
          },
        );

        final errors = <String>[];
        final statuses = <SharedSessionConnectionStatus>[];
        final errorSubscription = client.errors.listen(errors.add);
        final statusSubscription = client.connectionStatus.listen(statuses.add);

        await client.connect(accessToken: 'access-token');
        await expectLater(
          client.joinSession(sessionId: 'session-1'),
          throwsStateError,
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors.single, contains('Realtime join failed'));
        expect(errors.single, contains('join denied'));
        expect(statuses, contains(SharedSessionConnectionStatus.connected));
        expect(fakeConnection.invocations.single.$1, 'JoinSession');

        await errorSubscription.cancel();
        await statusSubscription.cancel();
      },
    );

    test('surfaces start failures before reporting disconnected', () async {
      final client = SignalRSharedSessionRealtimeClient(
        baseUrl: 'https://api.example.test',
        hubConnectionFactory: (hubUrl, _) {
          return _FakeHubConnectionAdapter(
            hubUrl,
            'unused',
            startError: StateError('host lookup failed'),
          );
        },
      );

      final errors = <String>[];
      final statuses = <SharedSessionConnectionStatus>[];
      final errorSubscription = client.errors.listen(errors.add);
      final statusSubscription = client.connectionStatus.listen(statuses.add);

      await expectLater(
        client.connect(accessToken: 'access-token'),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, contains('Realtime connection failed'));
      expect(errors.single, contains('host lookup failed'));
      expect(
        statuses,
        containsAllInOrder([
          SharedSessionConnectionStatus.connecting,
          SharedSessionConnectionStatus.disconnected,
        ]),
      );

      await errorSubscription.cancel();
      await statusSubscription.cancel();
    });

    test(
      'hub token provider reads the current token for every handshake',
      () async {
        var currentToken = 'access-token-1';
        late Future<String> Function() capturedProvider;
        final client = SignalRSharedSessionRealtimeClient(
          baseUrl: 'https://api.example.test/',
          accessTokenProvider: () async => currentToken,
          hubConnectionFactory: (hubUrl, accessTokenProvider) {
            capturedProvider = accessTokenProvider;
            return _FakeHubConnectionAdapter(hubUrl, 'unused');
          },
        );

        await client.connect(accessToken: 'initial-fallback');

        expect(await capturedProvider(), 'access-token-1');
        currentToken = 'access-token-2';
        expect(await capturedProvider(), 'access-token-2');
      },
    );
  });
}

class _FakeHubConnectionAdapter implements HubConnectionAdapter {
  _FakeHubConnectionAdapter(
    this.hubUrl,
    this.accessToken, {
    this.startError,
    this.joinError,
  });

  final String hubUrl;
  final String accessToken;
  final Object? startError;
  final Object? joinError;
  final invocations = <(String, List<Object>?)>[];
  void Function(Map<String, dynamic> json)? _sessionUpdatedHandler;
  void Function(Map<String, dynamic> json)? _sessionStartedHandler;
  void Function(SharedSessionConnectionStatus status)? _statusHandler;
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    started = true;
    _statusHandler?.call(SharedSessionConnectionStatus.connected);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object>? args}) async {
    invocations.add((methodName, args));
    final error = joinError;
    if (error != null) {
      throw error;
    }
    return null;
  }

  @override
  void onSessionUpdated(void Function(Map<String, dynamic> json) handler) {
    _sessionUpdatedHandler = handler;
  }

  @override
  void onSessionStarted(void Function(Map<String, dynamic> json) handler) {
    _sessionStartedHandler = handler;
  }

  @override
  void onStatusChanged(
    void Function(SharedSessionConnectionStatus status) handler,
  ) {
    _statusHandler = handler;
  }

  void emitSessionStarted(Map<String, dynamic> json) {
    _sessionStartedHandler?.call(json);
  }

  void emitSessionUpdated(Map<String, dynamic> json) {
    _sessionUpdatedHandler?.call(json);
  }
}

Map<String, dynamic> _sessionJson({int version = 2}) {
  return {
    'id': 'session-1',
    'trainerUserId': 'trainer-1',
    'traineeUserId': 'trainee-1',
    'trainerEmail': 'trainer@example.test',
    'traineeEmail': 'trainee@example.test',
    'workoutSetId': 'set-1',
    'startedByUserId': 'trainer-1',
    'startedByRole': 'trainer',
    'status': 'active',
    'version': version,
    'createdAt': '2026-06-03T12:00:00Z',
    'updatedAt': '2026-06-03T12:00:00Z',
    'closedAt': null,
    'values': [
      {
        'id': 'value-1',
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
