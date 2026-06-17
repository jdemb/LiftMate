import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'shared_session_api_client.dart';
import 'shared_session_models.dart';
import 'shared_session_realtime_client.dart';

enum SharedSessionControllerStatus {
  idle,
  loading,
  loaded,
  saving,
  error,
}

class SharedSessionControllerState {
  const SharedSessionControllerState({
    required this.status,
    this.user,
    this.session,
    this.message,
    this.connectionStatus = SharedSessionConnectionStatus.disconnected,
  });

  const SharedSessionControllerState.idle()
      : this(status: SharedSessionControllerStatus.idle);

  final SharedSessionControllerStatus status;
  final AuthUser? user;
  final SharedSession? session;
  final String? message;
  final SharedSessionConnectionStatus connectionStatus;

  SharedSessionControllerState copyWith({
    SharedSessionControllerStatus? status,
    AuthUser? user,
    SharedSession? session,
    String? message,
    bool clearMessage = false,
    SharedSessionConnectionStatus? connectionStatus,
  }) {
    return SharedSessionControllerState(
      status: status ?? this.status,
      user: user ?? this.user,
      session: session ?? this.session,
      message: clearMessage ? null : message ?? this.message,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

class SharedSessionController extends ChangeNotifier {
  SharedSessionController({
    required this.apiClient,
    required this.authController,
    required SharedSessionRealtimeClientFactory realtimeClientFactory,
    this.onTrainerSessionInvalidated,
  }) : _realtimeClient = realtimeClientFactory() {
    _updatesSubscription = _realtimeClient.updates.listen(_handleRealtimeSession);
    _connectionSubscription =
        _realtimeClient.connectionStatus.listen(_handleConnectionStatus);
    _errorsSubscription = _realtimeClient.errors.listen(_handleRealtimeError);
  }

  final SharedSessionApiClient apiClient;
  final AuthController authController;
  final SharedSessionRealtimeClient _realtimeClient;
  final VoidCallback? onTrainerSessionInvalidated;

  late final StreamSubscription<SharedSession> _updatesSubscription;
  late final StreamSubscription<SharedSessionConnectionStatus> _connectionSubscription;
  late final StreamSubscription<String> _errorsSubscription;

  SharedSessionControllerState _state = const SharedSessionControllerState.idle();

  SharedSessionControllerState get state => _state;

  Future<void> loadActive(AuthUser user) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(SharedSessionControllerState(
      status: SharedSessionControllerStatus.loading,
      user: user,
      session: _state.session,
      connectionStatus: _state.connectionStatus,
    ));

    if (accessToken == null) {
      _setError(user, 'User is not authenticated.');
      return;
    }

    final result = await apiClient.getActive(accessToken: accessToken);
    if (result.status == SharedSessionApiStatus.notFound) {
      _setState(SharedSessionControllerState(
        status: SharedSessionControllerStatus.loaded,
        user: user,
        connectionStatus: _state.connectionStatus,
      ));
      await _connect(accessToken);
      return;
    }

    await _acceptResult(user, result, joinLoadedSession: true);
  }

  Future<void> loadById({
    required AuthUser user,
    required String sessionId,
  }) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(_state.copyWith(
      status: SharedSessionControllerStatus.loading,
      user: user,
      clearMessage: true,
    ));

    if (accessToken == null) {
      _setError(user, 'User is not authenticated.');
      return;
    }

    final result = await apiClient.get(
      accessToken: accessToken,
      sessionId: sessionId,
    );
    await _acceptResult(user, result, joinLoadedSession: true);
  }

  Future<SharedSessionApiResult<SharedSession>> startTrainerSession({
    required AuthUser user,
    required String traineeUserId,
    required String workoutSetId,
  }) {
    return _start(
      user: user,
      request: (accessToken) => apiClient.startTrainerSession(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
        traineeUserId: traineeUserId,
      ),
    );
  }

  Future<SharedSessionApiResult<SharedSession>> startTraineeSession({
    required AuthUser user,
    required String workoutSetId,
  }) {
    return _start(
      user: user,
      request: (accessToken) => apiClient.startTraineeSession(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
      ),
    );
  }

  Future<SharedSessionApiResult<SharedSession>> updateValue({
    required AuthUser user,
    required String valueId,
    required UpdateSharedSessionValue value,
  }) async {
    final session = _state.session;
    final accessToken = authController.tokens?.accessToken;
    if (session == null || accessToken == null) {
      final result = const SharedSessionApiResult<SharedSession>(
        status: SharedSessionApiStatus.unauthorized,
        message: 'Shared session is not loaded.',
      );
      _setError(user, result.message);
      return result;
    }

    _setState(_state.copyWith(status: SharedSessionControllerStatus.saving));
    final result = await apiClient.updateValue(
      accessToken: accessToken,
      sessionId: session.id,
      valueId: valueId,
      value: value,
    );
    await _acceptResult(user, result, joinLoadedSession: false);
    return result;
  }

  Future<SharedSessionApiResult<SharedSession>> toggleDone({
    required AuthUser user,
    required SharedSessionValue value,
    required bool isDone,
  }) {
    return updateValue(
      user: user,
      valueId: value.id,
      value: UpdateSharedSessionValue(
        reps: value.reps,
        weight: value.weight,
        seconds: value.seconds,
        isDone: isDone,
      ),
    );
  }

  Future<SharedSessionApiResult<SharedSession>> complete(AuthUser user) {
    return _close(user, (accessToken, sessionId) {
      return apiClient.complete(accessToken: accessToken, sessionId: sessionId);
    });
  }

  Future<SharedSessionApiResult<SharedSession>> cancel(AuthUser user) {
    return _close(user, (accessToken, sessionId) {
      return apiClient.cancel(accessToken: accessToken, sessionId: sessionId);
    });
  }

  @override
  void dispose() {
    _updatesSubscription.cancel();
    _connectionSubscription.cancel();
    _errorsSubscription.cancel();
    unawaited(_realtimeClient.disconnect());
    super.dispose();
  }

  Future<SharedSessionApiResult<SharedSession>> _start({
    required AuthUser user,
    required Future<SharedSessionApiResult<SharedSession>> Function(String accessToken)
        request,
  }) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(_state.copyWith(
      status: SharedSessionControllerStatus.loading,
      user: user,
      clearMessage: true,
    ));

    if (accessToken == null) {
      const result = SharedSessionApiResult<SharedSession>(
        status: SharedSessionApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
      _setError(user, result.message);
      return result;
    }

    final result = await request(accessToken);
    await _acceptResult(user, result, joinLoadedSession: true);
    return result;
  }

  Future<SharedSessionApiResult<SharedSession>> _close(
    AuthUser user,
    Future<SharedSessionApiResult<SharedSession>> Function(
      String accessToken,
      String sessionId,
    ) request,
  ) async {
    final session = _state.session;
    final accessToken = authController.tokens?.accessToken;
    if (session == null || accessToken == null) {
      final result = const SharedSessionApiResult<SharedSession>(
        status: SharedSessionApiStatus.unauthorized,
        message: 'Shared session is not loaded.',
      );
      _setError(user, result.message);
      return result;
    }

    _setState(_state.copyWith(status: SharedSessionControllerStatus.saving));
    final result = await request(accessToken, session.id);
    await _acceptResult(user, result, joinLoadedSession: false);
    return result;
  }

  Future<void> _acceptResult(
    AuthUser user,
    SharedSessionApiResult<SharedSession> result, {
    required bool joinLoadedSession,
  }) async {
    final session = result.data;
    if (!result.isSuccess || session == null) {
      _setError(user, result.message);
      return;
    }

    _setState(SharedSessionControllerState(
      status: SharedSessionControllerStatus.loaded,
      user: user,
      session: session,
      connectionStatus: _state.connectionStatus,
    ));

    final accessToken = authController.tokens?.accessToken;
    if (accessToken == null) {
      return;
    }

    await _connect(accessToken);
    if (joinLoadedSession && session.status == SharedSessionStatus.active) {
      await _realtimeClient.joinSession(sessionId: session.id);
    }
  }

  Future<void> _connect(String accessToken) async {
    if (_state.connectionStatus == SharedSessionConnectionStatus.connected ||
        _state.connectionStatus == SharedSessionConnectionStatus.connecting) {
      return;
    }

    try {
      await _realtimeClient.connect(accessToken: accessToken);
    } on Object {
      // Error stream already carries the concrete connection failure.
    }
  }

  Future<void> _handleConnectionStatus(SharedSessionConnectionStatus status) async {
    _setState(_state.copyWith(connectionStatus: status));
    final user = _state.user ?? authController.state.user;
    if (status == SharedSessionConnectionStatus.connected &&
        _state.session == null &&
        user != null) {
      await loadActive(user);
    }
  }

  void _handleRealtimeSession(SharedSession session) {
    _setState(_state.copyWith(
      status: SharedSessionControllerStatus.loaded,
      session: session,
      clearMessage: true,
    ));

    final user = _state.user;
    if (user?.role == UserRole.trainer) {
      onTrainerSessionInvalidated?.call();
    }
  }

  void _handleRealtimeError(String message) {
    _setState(_state.copyWith(
      status: SharedSessionControllerStatus.error,
      message: message,
    ));
  }

  void _setError(AuthUser user, String message) {
    _setState(SharedSessionControllerState(
      status: SharedSessionControllerStatus.error,
      user: user,
      session: _state.session,
      message: message,
      connectionStatus: _state.connectionStatus,
    ));
  }

  void _setState(SharedSessionControllerState state) {
    _state = state;
    notifyListeners();
  }
}
