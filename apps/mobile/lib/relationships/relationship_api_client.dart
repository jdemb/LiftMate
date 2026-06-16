import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'relationship_models.dart';

enum RelationshipApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  offline,
  error,
}

class RelationshipApiResult<T> {
  const RelationshipApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final RelationshipApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == RelationshipApiStatus.success;
}

class RelationshipApiClient {
  RelationshipApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _resolveBaseUrl(baseUrl);

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<RelationshipApiResult<TrainerRelationshipSummary>> getTrainerRelationship({
    required String accessToken,
  }) {
    return _send<TrainerRelationshipSummary>(
      path: '/trainer/relationship',
      accessToken: accessToken,
      parse: TrainerRelationshipSummary.fromJson,
      invalidJsonMessage: 'Invalid trainer relationship response JSON.',
    );
  }

  Future<RelationshipApiResult<TraineeRelationshipSummary>> getTraineeRelationship({
    required String accessToken,
  }) {
    return _send<TraineeRelationshipSummary>(
      path: '/trainee/relationship',
      accessToken: accessToken,
      parse: TraineeRelationshipSummary.fromJson,
      invalidJsonMessage: 'Invalid trainee relationship response JSON.',
    );
  }

  Future<RelationshipApiResult<T>> _send<T>({
    required String path,
    required String accessToken,
    required T Function(Map<String, dynamic> json) parse,
    required String invalidJsonMessage,
  }) async {
    final uri = _uri(path);
    if (uri == null) {
      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.error,
        message: 'API_BASE_URL is not configured.',
      );
    }

    try {
      final request = http.Request('GET', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $accessToken';

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        return _failureFromResponse<T>(response);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return RelationshipApiResult<T>(
          status: RelationshipApiStatus.error,
          statusCode: response.statusCode,
          message: invalidJsonMessage,
        );
      }

      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: parse(decoded),
      );
    } on TimeoutException {
      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.offline,
        message: 'Relationship request timed out.',
      );
    } on FormatException {
      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.error,
        message: invalidJsonMessage,
      );
    } on http.ClientException catch (error) {
      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return RelationshipApiResult<T>(
        status: RelationshipApiStatus.error,
        message: error.toString(),
      );
    }
  }

  RelationshipApiResult<T> _failureFromResponse<T>(http.Response response) {
    return RelationshipApiResult<T>(
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

  static RelationshipApiStatus _statusFor(int statusCode) {
    return switch (statusCode) {
      400 => RelationshipApiStatus.badRequest,
      401 => RelationshipApiStatus.unauthorized,
      403 => RelationshipApiStatus.forbidden,
      404 => RelationshipApiStatus.notFound,
      409 => RelationshipApiStatus.conflict,
      _ => RelationshipApiStatus.error,
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
