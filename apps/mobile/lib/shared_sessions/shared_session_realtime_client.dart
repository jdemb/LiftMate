import 'dart:async';

import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart' as signalr;
import 'package:signalr_netcore/hub_connection_builder.dart';

import 'shared_session_models.dart';

enum SharedSessionConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
}

abstract class SharedSessionRealtimeClient {
  Stream<SharedSession> get updates;

  Stream<SharedSessionConnectionStatus> get connectionStatus;

  Future<void> connect({
    required String accessToken,
    required String sessionId,
  });

  Future<void> disconnect();
}

typedef SharedSessionRealtimeClientFactory = SharedSessionRealtimeClient Function();

class SignalRSharedSessionRealtimeClient implements SharedSessionRealtimeClient {
  SignalRSharedSessionRealtimeClient({
    required String? baseUrl,
    HubConnectionFactory? hubConnectionFactory,
  })  : _baseUrl = _resolveBaseUrl(baseUrl),
        _hubConnectionFactory = hubConnectionFactory ?? _defaultHubConnectionFactory;

  final String? _baseUrl;
  final HubConnectionFactory _hubConnectionFactory;
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController = StreamController<SharedSessionConnectionStatus>.broadcast();

  HubConnectionAdapter? _connection;

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Future<void> connect({
    required String accessToken,
    required String sessionId,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      throw StateError('API_BASE_URL is not configured.');
    }

    await disconnect();
    _emitStatus(SharedSessionConnectionStatus.connecting);

    final hubUrl = '$baseUrl/hubs/shared-sessions';
    final connection = _hubConnectionFactory(hubUrl, accessToken);
    _connection = connection;
    connection.onSessionUpdated(_handleSessionUpdated);
    connection.onStatusChanged(_emitStatus);

    await connection.start();
    await connection.invoke('JoinSession', args: [sessionId]);
    _emitStatus(SharedSessionConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    if (connection == null) {
      _emitStatus(SharedSessionConnectionStatus.disconnected);
      return;
    }

    _emitStatus(SharedSessionConnectionStatus.disconnecting);
    _connection = null;
    await connection.stop();
    _emitStatus(SharedSessionConnectionStatus.disconnected);
  }

  void dispose() {
    _updatesController.close();
    _statusController.close();
  }

  void _handleSessionUpdated(Map<String, dynamic> json) {
    _updatesController.add(SharedSession.fromJson(json));
  }

  void _emitStatus(SharedSessionConnectionStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  static String? _resolveBaseUrl(String? explicitBaseUrl) {
    final value = explicitBaseUrl;
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim().replaceFirst(RegExp(r'/*$'), '');
  }
}

typedef HubConnectionFactory = HubConnectionAdapter Function(String hubUrl, String accessToken);

abstract class HubConnectionAdapter {
  Future<void> start();

  Future<void> stop();

  Future<Object?> invoke(String methodName, {List<Object>? args});

  void onSessionUpdated(void Function(Map<String, dynamic> json) handler);

  void onStatusChanged(void Function(SharedSessionConnectionStatus status) handler);
}

HubConnectionAdapter _defaultHubConnectionFactory(String hubUrl, String accessToken) {
  final connection = HubConnectionBuilder()
      .withUrl(
        hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: () async => accessToken,
        ),
      )
      .withAutomaticReconnect()
      .build();

  return SignalRHubConnectionAdapter(connection);
}

class SignalRHubConnectionAdapter implements HubConnectionAdapter {
  SignalRHubConnectionAdapter(this._connection);

  final signalr.HubConnection _connection;

  @override
  Future<void> start() async {
    await _connection.start();
  }

  @override
  Future<void> stop() {
    return _connection.stop();
  }

  @override
  Future<Object?> invoke(String methodName, {List<Object>? args}) {
    return _connection.invoke(methodName, args: args);
  }

  @override
  void onSessionUpdated(void Function(Map<String, dynamic> json) handler) {
    _connection.on('sessionUpdated', (arguments) {
      final first = arguments?.isEmpty ?? true ? null : arguments!.first;
      if (first is Map<String, dynamic>) {
        handler(first);
      }
    });
  }

  @override
  void onStatusChanged(void Function(SharedSessionConnectionStatus status) handler) {
    _connection.stateStream.listen((state) {
      handler(_mapConnectionStatus(state));
    });
  }

  static SharedSessionConnectionStatus _mapConnectionStatus(signalr.HubConnectionState state) {
    return switch (state) {
      signalr.HubConnectionState.Connected => SharedSessionConnectionStatus.connected,
      signalr.HubConnectionState.Connecting => SharedSessionConnectionStatus.connecting,
      signalr.HubConnectionState.Disconnecting => SharedSessionConnectionStatus.disconnecting,
      signalr.HubConnectionState.Reconnecting => SharedSessionConnectionStatus.reconnecting,
      signalr.HubConnectionState.Disconnected => SharedSessionConnectionStatus.disconnected,
    };
  }
}
