import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'shared_session_models.dart';

enum SharedSessionApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  offline,
  error,
}

class SharedSessionApiResult<T> {
  const SharedSessionApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final SharedSessionApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == SharedSessionApiStatus.success;
}

class SharedSessionApiClient {
  SharedSessionApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _resolveBaseUrl(baseUrl);

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<SharedSessionApiResult<SharedSession>> create({
    required String accessToken,
    required String traineeEmail,
    required List<CreateSharedSessionValue> values,
  }) {
    return _send<SharedSession>(
      method: 'POST',
      path: '/shared-sessions',
      accessToken: accessToken,
      body: {
        'traineeEmail': traineeEmail,
        'values': values.map((value) => value.toJson()).toList(growable: false),
      },
      successStatusCodes: {201},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<SharedSession>> getActive({
    required String accessToken,
  }) {
    return _send<SharedSession>(
      method: 'GET',
      path: '/shared-sessions/active',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<SharedSession>> get({
    required String accessToken,
    required String sessionId,
  }) {
    return _send<SharedSession>(
      method: 'GET',
      path: '/shared-sessions/$sessionId',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<SharedSession>> updateValue({
    required String accessToken,
    required String sessionId,
    required String valueId,
    required UpdateSharedSessionValue value,
  }) {
    return _send<SharedSession>(
      method: 'PATCH',
      path: '/shared-sessions/$sessionId/values/$valueId',
      accessToken: accessToken,
      body: value.toJson(),
      successStatusCodes: {200},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<SharedSession>> complete({
    required String accessToken,
    required String sessionId,
  }) {
    return _send<SharedSession>(
      method: 'POST',
      path: '/shared-sessions/$sessionId/complete',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<SharedSession>> cancel({
    required String accessToken,
    required String sessionId,
  }) {
    return _send<SharedSession>(
      method: 'POST',
      path: '/shared-sessions/$sessionId/cancel',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: SharedSession.fromJson,
      invalidJsonMessage: 'Invalid shared session response JSON.',
    );
  }

  Future<SharedSessionApiResult<T>> _send<T>({
    required String method,
    required String path,
    required String accessToken,
    required Set<int> successStatusCodes,
    required T Function(Map<String, dynamic> json) parse,
    required String invalidJsonMessage,
    Map<String, Object?>? body,
  }) async {
    final uri = _uri(path);
    if (uri == null) {
      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.error,
        message: 'API_BASE_URL is not configured.',
      );
    }

    try {
      final request = http.Request(method, uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $accessToken';
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (!successStatusCodes.contains(response.statusCode)) {
        return _failureFromResponse<T>(response);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return SharedSessionApiResult<T>(
          status: SharedSessionApiStatus.error,
          statusCode: response.statusCode,
          message: invalidJsonMessage,
        );
      }

      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: parse(decoded),
      );
    } on TimeoutException {
      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.offline,
        message: 'Shared session request timed out.',
      );
    } on FormatException {
      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.error,
        message: invalidJsonMessage,
      );
    } on http.ClientException catch (error) {
      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return SharedSessionApiResult<T>(
        status: SharedSessionApiStatus.error,
        message: error.toString(),
      );
    }
  }

  SharedSessionApiResult<T> _failureFromResponse<T>(http.Response response) {
    return SharedSessionApiResult<T>(
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

  static SharedSessionApiStatus _statusFor(int statusCode) {
    return switch (statusCode) {
      400 => SharedSessionApiStatus.badRequest,
      401 => SharedSessionApiStatus.unauthorized,
      403 => SharedSessionApiStatus.forbidden,
      404 => SharedSessionApiStatus.notFound,
      409 => SharedSessionApiStatus.conflict,
      _ => SharedSessionApiStatus.error,
    };
  }

  static String _messageFrom(http.Response response) {
    if (response.body.trim().isEmpty) {
      return 'API returned HTTP ${response.statusCode}.';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return 'API returned HTTP ${response.statusCode}.';
    }

    return 'API returned HTTP ${response.statusCode}.';
  }

  static String? _resolveBaseUrl(String? explicitBaseUrl) {
    final value = explicitBaseUrl;
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }
}
