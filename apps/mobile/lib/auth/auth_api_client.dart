import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

enum AuthApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  conflict,
  offline,
  error,
}

const _serviceUnavailableMessage =
    'Połączenie z usługą jest chwilowo niedostępne. Spróbuj ponownie.';
const _offlineMessage =
    'Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.';
const _timeoutMessage =
    'Serwer odpowiada zbyt długo. Spróbuj ponownie za chwilę.';
const _invalidResponseMessage =
    'Nie udało się odczytać odpowiedzi serwera. Spróbuj ponownie.';
const _requestFailedMessage =
    'Nie udało się wykonać operacji. Spróbuj ponownie.';

class AuthApiResult<T> {
  const AuthApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final AuthApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == AuthApiStatus.success;
}

class AuthApiClient {
  AuthApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 1),
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _resolveBaseUrl(baseUrl);

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;
  final Duration retryDelay;

  Future<AuthApiResult<AuthSession>> register({
    required String email,
    required String password,
    required UserRole role,
    required String displayName,
    required String registrationInviteCode,
  }) {
    return _send<AuthSession>(
      method: 'POST',
      path: '/auth/register',
      body: {
        'email': email,
        'password': password,
        'role': role.wireName,
        'displayName': displayName,
        'registrationInviteCode': registrationInviteCode,
      },
      successStatusCodes: {201},
      parse: AuthSession.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<TrainerInviteCode>> generateTrainerInviteCode({
    required String accessToken,
  }) {
    return _send<TrainerInviteCode>(
      method: 'POST',
      path: '/trainer/invite-code',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: TrainerInviteCode.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<AuthUser>> claimTrainerInviteCode({
    required String accessToken,
    required String code,
  }) {
    return _send<AuthUser>(
      method: 'POST',
      path: '/trainee/trainer-link',
      accessToken: accessToken,
      body: {
        'code': normalizeTrainerInviteCode(code),
      },
      successStatusCodes: {200},
      parse: AuthUser.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<AuthSession>> login({
    required String email,
    required String password,
  }) {
    return _send<AuthSession>(
      method: 'POST',
      path: '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      successStatusCodes: {200},
      parse: AuthSession.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
      retryTransientFailures: true,
    );
  }

  Future<AuthApiResult<AuthSession>> refresh({
    required String refreshToken,
  }) {
    return _send<AuthSession>(
      method: 'POST',
      path: '/auth/refresh',
      body: {
        'refreshToken': refreshToken,
      },
      successStatusCodes: {200},
      parse: AuthSession.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<void>> logout({
    required String accessToken,
    required String refreshToken,
  }) {
    return _send<void>(
      method: 'POST',
      path: '/auth/logout',
      accessToken: accessToken,
      body: {
        'refreshToken': refreshToken,
      },
      successStatusCodes: {200, 204},
      parse: (_) {},
      expectBody: false,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<AuthUser>> me({
    required String accessToken,
  }) {
    return _send<AuthUser>(
      method: 'GET',
      path: '/auth/me',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: AuthUser.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<RoleProbeResult>> trainerProbe({
    required String accessToken,
  }) {
    return _send<RoleProbeResult>(
      method: 'GET',
      path: '/trainer/probe',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: RoleProbeResult.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<RoleProbeResult>> traineeProbe({
    required String accessToken,
  }) {
    return _send<RoleProbeResult>(
      method: 'GET',
      path: '/trainee/probe',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: RoleProbeResult.fromJson,
      invalidJsonMessage: _invalidResponseMessage,
    );
  }

  Future<AuthApiResult<T>> _send<T>({
    required String method,
    required String path,
    required Set<int> successStatusCodes,
    required T Function(Map<String, dynamic> json) parse,
    required String invalidJsonMessage,
    bool expectBody = true,
    String? accessToken,
    Map<String, Object?>? body,
    bool retryTransientFailures = false,
  }) async {
    final uri = _uri(path);
    if (uri == null) {
      return AuthApiResult<T>(
        status: AuthApiStatus.error,
        message: _serviceUnavailableMessage,
      );
    }

    final maxAttempts = retryTransientFailures ? 2 : 1;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      final result = await _sendOnce<T>(
        method: method,
        uri: uri,
        successStatusCodes: successStatusCodes,
        parse: parse,
        invalidJsonMessage: invalidJsonMessage,
        expectBody: expectBody,
        accessToken: accessToken,
        body: body,
      );

      if (attempt == maxAttempts || !_shouldRetry(result)) {
        return result;
      }

      if (retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }

    return AuthApiResult<T>(
      status: AuthApiStatus.error,
      message: _requestFailedMessage,
    );
  }

  Future<AuthApiResult<T>> _sendOnce<T>({
    required String method,
    required Uri uri,
    required Set<int> successStatusCodes,
    required T Function(Map<String, dynamic> json) parse,
    required String invalidJsonMessage,
    required bool expectBody,
    String? accessToken,
    Map<String, Object?>? body,
  }) async {
    try {
      final request = http.Request(method, uri);
      request.headers['Content-Type'] = 'application/json';
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (!successStatusCodes.contains(response.statusCode)) {
        return _failureFromResponse<T>(response);
      }

      if (!expectBody) {
        return AuthApiResult<T>(
          status: AuthApiStatus.success,
          statusCode: response.statusCode,
          message: 'Request succeeded.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return AuthApiResult<T>(
          status: AuthApiStatus.error,
          statusCode: response.statusCode,
          message: invalidJsonMessage,
        );
      }

      return AuthApiResult<T>(
        status: AuthApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: parse(decoded),
      );
    } on TimeoutException {
      return AuthApiResult<T>(
        status: AuthApiStatus.offline,
        message: _timeoutMessage,
      );
    } on FormatException {
      return AuthApiResult<T>(
        status: AuthApiStatus.error,
        message: invalidJsonMessage,
      );
    } on http.ClientException {
      return AuthApiResult<T>(
        status: AuthApiStatus.offline,
        message: _offlineMessage,
      );
    } on Object {
      return AuthApiResult<T>(
        status: AuthApiStatus.error,
        message: _requestFailedMessage,
      );
    }
  }

  static bool _shouldRetry<T>(AuthApiResult<T> result) {
    if (result.status == AuthApiStatus.offline) {
      return true;
    }

    return result.status == AuthApiStatus.error &&
        const {500, 502, 503, 504}.contains(result.statusCode);
  }

  AuthApiResult<T> _failureFromResponse<T>(http.Response response) {
    return AuthApiResult<T>(
      status: _statusFor(response.statusCode),
      statusCode: response.statusCode,
      message: _messageFrom(response),
    );
  }

  Uri? _uri(String path) {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return null;
    }

    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final normalizedPath = path.replaceFirst(RegExp(r'^/*'), '');
    return Uri.parse('$normalizedBaseUrl/$normalizedPath');
  }

  static AuthApiStatus _statusFor(int statusCode) {
    return switch (statusCode) {
      400 => AuthApiStatus.badRequest,
      401 => AuthApiStatus.unauthorized,
      403 => AuthApiStatus.forbidden,
      409 => AuthApiStatus.conflict,
      _ => AuthApiStatus.error,
    };
  }

  static String _messageFrom(http.Response response) {
    if (response.body.trim().isEmpty) {
      return _requestFailedMessage;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error'] ?? decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return _requestFailedMessage;
    }

    return _requestFailedMessage;
  }

  static String? _resolveBaseUrl(String? explicitBaseUrl) {
    final value = explicitBaseUrl;
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }

  static String normalizeTrainerInviteCode(String code) {
    return code.trim().toUpperCase();
  }
}
