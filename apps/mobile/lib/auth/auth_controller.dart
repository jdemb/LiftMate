import 'package:flutter/foundation.dart';

import 'auth_api_client.dart';
import 'auth_models.dart';
import 'token_store.dart';

enum AuthControllerStatus {
  loading,
  unauthenticated,
  authenticated,
  error,
}

class AuthControllerState {
  const AuthControllerState({
    required this.status,
    this.user,
    this.message,
  });

  const AuthControllerState.loading() : this(status: AuthControllerStatus.loading);

  const AuthControllerState.unauthenticated()
      : this(status: AuthControllerStatus.unauthenticated);

  const AuthControllerState.authenticated(AuthUser user)
      : this(status: AuthControllerStatus.authenticated, user: user);

  const AuthControllerState.error(String message)
      : this(status: AuthControllerStatus.error, message: message);

  final AuthControllerStatus status;
  final AuthUser? user;
  final String? message;
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.authApiClient,
    required this.tokenStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AuthApiClient authApiClient;
  final TokenStore tokenStore;
  final DateTime Function() _now;

  AuthControllerState _state = const AuthControllerState.loading();
  StoredAuthTokens? _tokens;

  AuthControllerState get state => _state;
  StoredAuthTokens? get tokens => _tokens;

  Future<void> initialize() async {
    _setState(const AuthControllerState.loading());

    final storedTokens = await tokenStore.read();
    if (storedTokens == null) {
      _tokens = null;
      _setState(const AuthControllerState.unauthenticated());
      return;
    }

    _tokens = storedTokens;

    if (_shouldRefresh(storedTokens)) {
      await _refreshStoredSession(storedTokens.refreshToken);
      return;
    }

    final meResult = await authApiClient.me(accessToken: storedTokens.accessToken);
    if (meResult.isSuccess && meResult.data != null) {
      _setState(AuthControllerState.authenticated(meResult.data!));
      return;
    }

    if (meResult.status == AuthApiStatus.unauthorized) {
      await _refreshStoredSession(storedTokens.refreshToken);
      return;
    }

    _setState(AuthControllerState.error(meResult.message));
  }

  Future<AuthApiResult<AuthSession>> register({
    required String email,
    required String password,
    required UserRole role,
    required String displayName,
  }) async {
    _setState(const AuthControllerState.loading());

    final result = await authApiClient.register(
      email: email,
      password: password,
      role: role,
      displayName: displayName,
    );
    await _storeSessionOrShowError(result);

    return result;
  }

  Future<AuthApiResult<TrainerInviteCode>> generateTrainerInviteCode() async {
    final accessToken = _tokens?.accessToken;
    if (accessToken == null) {
      return const AuthApiResult<TrainerInviteCode>(
        status: AuthApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
    }

    return authApiClient.generateTrainerInviteCode(accessToken: accessToken);
  }

  Future<AuthApiResult<AuthUser>> claimTrainerInviteCode({
    required String code,
  }) async {
    final accessToken = _tokens?.accessToken;
    if (accessToken == null) {
      return const AuthApiResult<AuthUser>(
        status: AuthApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
    }

    final result = await authApiClient.claimTrainerInviteCode(
      accessToken: accessToken,
      code: code,
    );

    final user = result.data;
    if (result.isSuccess && user != null) {
      _setState(AuthControllerState.authenticated(user));
    } else if (!result.isSuccess) {
      _setState(AuthControllerState.error(result.message));
    }

    return result;
  }

  Future<AuthApiResult<AuthSession>> login({
    required String email,
    required String password,
  }) async {
    _setState(const AuthControllerState.loading());

    final result = await authApiClient.login(
      email: email,
      password: password,
    );
    await _storeSessionOrShowError(result);

    return result;
  }

  Future<void> logout() async {
    final currentTokens = _tokens;
    _setState(const AuthControllerState.loading());

    if (currentTokens != null) {
      await authApiClient.logout(
        accessToken: currentTokens.accessToken,
        refreshToken: currentTokens.refreshToken,
      );
    }

    await _clearSession();
  }

  Future<void> _refreshStoredSession(String refreshToken) async {
    final result = await authApiClient.refresh(refreshToken: refreshToken);
    if (result.isSuccess && result.data != null) {
      await _storeSession(result.data!);
      return;
    }

    await _clearSession();
  }

  Future<void> _storeSessionOrShowError(AuthApiResult<AuthSession> result) async {
    final session = result.data;
    if (!result.isSuccess || session == null) {
      _tokens = null;
      _setState(AuthControllerState.error(result.message));
      return;
    }

    await _storeSession(session);
  }

  Future<void> _storeSession(AuthSession session) async {
    final tokens = StoredAuthTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );

    await tokenStore.save(tokens);
    _tokens = tokens;
    _setState(AuthControllerState.authenticated(session.user));
  }

  Future<void> _clearSession() async {
    await tokenStore.clear();
    _tokens = null;
    _setState(const AuthControllerState.unauthenticated());
  }

  bool _shouldRefresh(StoredAuthTokens tokens) {
    final refreshAt = tokens.expiresAt.subtract(const Duration(minutes: 1));
    return !refreshAt.isAfter(_now().toUtc());
  }

  void _setState(AuthControllerState state) {
    _state = state;
    notifyListeners();
  }
}
