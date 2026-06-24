import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'shared_session_api_client.dart';
import 'shared_session_models.dart';
import 'shared_session_realtime_client.dart';

enum SharedSessionControllerStatus { idle, loading, loaded, saving, error }

enum SharedSessionCompletionOutcome { savedForNextSession }

class SharedSessionControllerState {
  const SharedSessionControllerState({
    required this.status,
    this.user,
    this.session,
    this.message,
    this.completionOutcome,
    this.completedSessionIdForFeedback,
    this.connectionStatus = SharedSessionConnectionStatus.disconnected,
  });

  const SharedSessionControllerState.idle()
    : this(status: SharedSessionControllerStatus.idle);

  final SharedSessionControllerStatus status;
  final AuthUser? user;
  final SharedSession? session;
  final String? message;
  final SharedSessionCompletionOutcome? completionOutcome;
  final String? completedSessionIdForFeedback;
  final SharedSessionConnectionStatus connectionStatus;

  SharedSessionControllerState copyWith({
    SharedSessionControllerStatus? status,
    AuthUser? user,
    SharedSession? session,
    String? message,
    SharedSessionCompletionOutcome? completionOutcome,
    String? completedSessionIdForFeedback,
    bool clearMessage = false,
    bool clearSession = false,
    bool clearCompletionOutcome = false,
    bool clearCompletedSessionIdForFeedback = false,
    SharedSessionConnectionStatus? connectionStatus,
  }) {
    return SharedSessionControllerState(
      status: status ?? this.status,
      user: user ?? this.user,
      session: clearSession ? null : session ?? this.session,
      message: clearMessage ? null : message ?? this.message,
      completionOutcome: clearCompletionOutcome
          ? null
          : completionOutcome ?? this.completionOutcome,
      completedSessionIdForFeedback: clearCompletedSessionIdForFeedback
          ? null
          : completedSessionIdForFeedback ?? this.completedSessionIdForFeedback,
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
    _updatesSubscription = _realtimeClient.updates.listen(
      _handleRealtimeSession,
    );
    _connectionSubscription = _realtimeClient.connectionStatus.listen(
      _handleConnectionStatus,
    );
    _errorsSubscription = _realtimeClient.errors.listen(_handleRealtimeError);
  }

  final SharedSessionApiClient apiClient;
  final AuthController authController;
  final SharedSessionRealtimeClient _realtimeClient;
  final VoidCallback? onTrainerSessionInvalidated;

  late final StreamSubscription<SharedSession> _updatesSubscription;
  late final StreamSubscription<SharedSessionConnectionStatus>
  _connectionSubscription;
  late final StreamSubscription<String> _errorsSubscription;

  SharedSessionControllerState _state =
      const SharedSessionControllerState.idle();
  bool _wasReconnecting = false;
  String? _lastKnownActiveSessionId;
  final Set<String> _feedbackCompletionSessionIds = <String>{};

  SharedSessionControllerState get state => _state;

  bool get hasRenderableActiveSession {
    final session = _state.session;
    return session?.status == SharedSessionStatus.active &&
        session!.values.isNotEmpty;
  }

  String? consumeCompletedSessionForFeedback() {
    final sessionId = _state.completedSessionIdForFeedback;
    if (sessionId == null) {
      return null;
    }

    _feedbackCompletionSessionIds.add(sessionId);
    _setState(_state.copyWith(clearCompletedSessionIdForFeedback: true));
    return sessionId;
  }

  Future<void> loadActive(AuthUser user) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(
      SharedSessionControllerState(
        status: SharedSessionControllerStatus.loading,
        user: user,
        session: _state.session,
        completedSessionIdForFeedback: _state.completedSessionIdForFeedback,
        connectionStatus: _state.connectionStatus,
      ),
    );

    if (accessToken == null) {
      _setError(user, 'User is not authenticated.');
      return;
    }

    final result = await apiClient.getActive(accessToken: accessToken);
    if (result.status == SharedSessionApiStatus.notFound) {
      _setState(
        SharedSessionControllerState(
          status: SharedSessionControllerStatus.loaded,
          user: user,
          completedSessionIdForFeedback: _state.completedSessionIdForFeedback,
          connectionStatus: _state.connectionStatus,
        ),
      );
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
    _setState(
      _state.copyWith(
        status: SharedSessionControllerStatus.loading,
        user: user,
        clearMessage: true,
        clearSession: true,
      ),
    );

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

  Future<SharedSessionApiResult<SharedSession>> complete(AuthUser user) async {
    final result = await _close(user, (accessToken, sessionId) {
      return apiClient.complete(accessToken: accessToken, sessionId: sessionId);
    });
    if (result.isSuccess) {
      _setState(
        _state.copyWith(
          completionOutcome: SharedSessionCompletionOutcome.savedForNextSession,
        ),
      );
    }
    return result;
  }

  Future<SharedSessionApiResult<SharedSession>> cancel(AuthUser user) async {
    final result = await _close(user, (accessToken, sessionId) {
      return apiClient.cancel(accessToken: accessToken, sessionId: sessionId);
    });
    if (result.isSuccess) {
      _setState(_state.copyWith(clearCompletionOutcome: true));
    }
    return result;
  }

  void clearSession() {
    _setState(
      SharedSessionControllerState(
        status: SharedSessionControllerStatus.loaded,
        user: _state.user,
        completionOutcome: _state.completionOutcome,
        completedSessionIdForFeedback: _state.completedSessionIdForFeedback,
        connectionStatus: _state.connectionStatus,
      ),
    );
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
    required Future<SharedSessionApiResult<SharedSession>> Function(
      String accessToken,
    )
    request,
  }) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(
      _state.copyWith(
        status: SharedSessionControllerStatus.loading,
        user: user,
        clearMessage: true,
        clearSession: true,
        clearCompletionOutcome: true,
      ),
    );

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
    )
    request,
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
    final previousSession = _state.session;
    if (!result.isSuccess || session == null) {
      _setError(user, result.message);
      return;
    }

    if (joinLoadedSession && session.status != SharedSessionStatus.active) {
      _setState(
        SharedSessionControllerState(
          status: SharedSessionControllerStatus.error,
          user: user,
          message: 'Shared session is not active.',
          connectionStatus: _state.connectionStatus,
        ),
      );
      return;
    }

    if (joinLoadedSession && session.values.isEmpty) {
      _setState(
        SharedSessionControllerState(
          status: SharedSessionControllerStatus.error,
          user: user,
          message: 'Aktywna sesja nie zawiera żadnych serii.',
          connectionStatus: _state.connectionStatus,
        ),
      );
      return;
    }

    _setState(
      SharedSessionControllerState(
        status: SharedSessionControllerStatus.loaded,
        user: user,
        session: session,
        completionOutcome: _state.completionOutcome,
        completedSessionIdForFeedback: _completedSessionIdForFeedback(
          previousSession,
          session,
        ),
        connectionStatus: _state.connectionStatus,
      ),
    );
    _rememberActiveSession(session);

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

  Future<void> _handleConnectionStatus(
    SharedSessionConnectionStatus status,
  ) async {
    _setState(_state.copyWith(connectionStatus: status));
    if (status == SharedSessionConnectionStatus.reconnecting) {
      _wasReconnecting = true;
      return;
    }

    final user = _state.user ?? authController.state.user;
    if (status != SharedSessionConnectionStatus.connected || user == null) {
      return;
    }

    final returnedFromReconnect = _wasReconnecting;
    _wasReconnecting = false;

    try {
      final session = _state.session;
      if (returnedFromReconnect && _lastKnownActiveSessionId != null) {
        if (session?.status == SharedSessionStatus.active) {
          await _realtimeClient.joinSession(sessionId: session!.id);
        }

        final accessToken = authController.tokens?.accessToken;
        if (accessToken != null) {
          final result = await apiClient.get(
            accessToken: accessToken,
            sessionId: _lastKnownActiveSessionId!,
          );
          await _acceptResult(user, result, joinLoadedSession: false);
        } else {
          _setState(
            _state.copyWith(
              status: SharedSessionControllerStatus.loaded,
              clearMessage: true,
            ),
          );
        }
        return;
      }

      if (returnedFromReconnect &&
          session?.status == SharedSessionStatus.active) {
        await _realtimeClient.joinSession(sessionId: session!.id);
        _setState(
          _state.copyWith(
            status: SharedSessionControllerStatus.loaded,
            clearMessage: true,
          ),
        );
        return;
      }

      if (session == null) {
        await loadActive(user);
      }
    } on Object catch (error) {
      _handleRealtimeError('Realtime join failed: $error');
    }
  }

  void _handleRealtimeSession(SharedSession session) {
    final currentSession = _state.session;
    if (currentSession != null) {
      if (session.id != currentSession.id) {
        if (_state.user?.role == UserRole.trainer) {
          onTrainerSessionInvalidated?.call();
        }
        return;
      }

      if (session.version < currentSession.version) {
        return;
      }
    }

    _setState(
      _state.copyWith(
        status: SharedSessionControllerStatus.loaded,
        session: session,
        completedSessionIdForFeedback: _completedSessionIdForFeedback(
          currentSession,
          session,
        ),
        clearMessage: true,
      ),
    );
    _rememberActiveSession(session);

    final user = _state.user;
    if (user?.role == UserRole.trainer) {
      onTrainerSessionInvalidated?.call();
    }
  }

  void _handleRealtimeError(String message) {
    _setState(
      _state.copyWith(
        status: SharedSessionControllerStatus.error,
        message: message,
      ),
    );
  }

  void _setError(AuthUser user, String message) {
    _setState(
      SharedSessionControllerState(
        status: SharedSessionControllerStatus.error,
        user: user,
        session: _state.session,
        message: message,
        completionOutcome: _state.completionOutcome,
        completedSessionIdForFeedback: _state.completedSessionIdForFeedback,
        connectionStatus: _state.connectionStatus,
      ),
    );
  }

  String? _completedSessionIdForFeedback(
    SharedSession? previousSession,
    SharedSession nextSession,
  ) {
    final pendingSessionId = _state.completedSessionIdForFeedback;
    if (pendingSessionId != null) {
      return pendingSessionId;
    }

    final completedSameSession =
        previousSession?.id == nextSession.id &&
        previousSession?.status == SharedSessionStatus.active &&
        nextSession.status == SharedSessionStatus.completed;
    if (!completedSameSession ||
        _feedbackCompletionSessionIds.contains(nextSession.id)) {
      return null;
    }

    return nextSession.id;
  }

  void _rememberActiveSession(SharedSession session) {
    if (session.status == SharedSessionStatus.active) {
      _lastKnownActiveSessionId = session.id;
    }
  }

  void _setState(SharedSessionControllerState state) {
    _state = state;
    notifyListeners();
  }
}
