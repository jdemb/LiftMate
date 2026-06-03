import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('SignalRSharedSessionRealtimeClient', () {
    test('connect starts connection, joins session, and exposes updates', () async {
      late _FakeHubConnectionAdapter fakeConnection;
      final client = SignalRSharedSessionRealtimeClient(
        baseUrl: 'https://api.example.test/',
        hubConnectionFactory: (hubUrl, accessToken) {
          fakeConnection = _FakeHubConnectionAdapter(hubUrl, accessToken);
          return fakeConnection;
        },
      );

      final statuses = <SharedSessionConnectionStatus>[];
      final updates = <SharedSession>[];
      final statusSubscription = client.connectionStatus.listen(statuses.add);
      final updateSubscription = client.updates.listen(updates.add);

      await client.connect(accessToken: 'access-token', sessionId: 'session-1');
      fakeConnection.emitSessionUpdated(_sessionJson());
      await Future<void>.delayed(Duration.zero);

      expect(fakeConnection.hubUrl, 'https://api.example.test/hubs/shared-sessions');
      expect(fakeConnection.accessToken, 'access-token');
      expect(fakeConnection.started, isTrue);
      expect(fakeConnection.invocations, hasLength(1));
      expect(fakeConnection.invocations.single.$1, 'JoinSession');
      expect(fakeConnection.invocations.single.$2, ['session-1']);
      expect(statuses, containsAllInOrder([
        SharedSessionConnectionStatus.connecting,
        SharedSessionConnectionStatus.connected,
      ]));
      expect(updates.single.id, 'session-1');

      await updateSubscription.cancel();
      await statusSubscription.cancel();
    });

    test('disconnect stops active connection', () async {
      late _FakeHubConnectionAdapter fakeConnection;
      final client = SignalRSharedSessionRealtimeClient(
        baseUrl: 'https://api.example.test',
        hubConnectionFactory: (hubUrl, accessToken) {
          fakeConnection = _FakeHubConnectionAdapter(hubUrl, accessToken);
          return fakeConnection;
        },
      );

      await client.connect(accessToken: 'access-token', sessionId: 'session-1');
      await client.disconnect();

      expect(fakeConnection.stopped, isTrue);
    });

    test('throws when API base URL is missing', () async {
      final client = SignalRSharedSessionRealtimeClient(baseUrl: '');

      await expectLater(
        client.connect(accessToken: 'access-token', sessionId: 'session-1'),
        throwsStateError,
      );
    });
  });
}

class _FakeHubConnectionAdapter implements HubConnectionAdapter {
  _FakeHubConnectionAdapter(this.hubUrl, this.accessToken);

  final String hubUrl;
  final String accessToken;
  final invocations = <(String, List<Object>?)>[];
  void Function(Map<String, dynamic> json)? _sessionUpdatedHandler;
  void Function(SharedSessionConnectionStatus status)? _statusHandler;
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async {
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
    return null;
  }

  @override
  void onSessionUpdated(void Function(Map<String, dynamic> json) handler) {
    _sessionUpdatedHandler = handler;
  }

  @override
  void onStatusChanged(void Function(SharedSessionConnectionStatus status) handler) {
    _statusHandler = handler;
  }

  void emitSessionUpdated(Map<String, dynamic> json) {
    _sessionUpdatedHandler?.call(json);
  }
}

Map<String, dynamic> _sessionJson() {
  return {
    'id': 'session-1',
    'trainerUserId': 'trainer-1',
    'traineeUserId': 'trainee-1',
    'status': 'active',
    'version': 1,
    'createdAt': '2026-06-03T12:00:00Z',
    'updatedAt': '2026-06-03T12:00:00Z',
    'closedAt': null,
    'values': [
      {
        'id': 'value-1',
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'setIndex': 1,
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
        'updatedByUserId': null,
        'updatedAt': null,
      },
    ],
  };
}
