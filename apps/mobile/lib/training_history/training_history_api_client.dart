import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'training_history_models.dart';

enum TrainingHistoryApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  offline,
  error,
}

class TrainingHistoryApiResult<T> {
  const TrainingHistoryApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final TrainingHistoryApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == TrainingHistoryApiStatus.success;
}

class TrainingHistoryApiClient {
  TrainingHistoryApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl?.trim().isEmpty ?? true ? null : baseUrl!.trim();

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<TrainingHistoryApiResult<TrainingHistoryPage>> list({
    required String accessToken,
    String? traineeUserId,
    String? cursor,
  }) {
    final query = <String, String>{};
    if (traineeUserId != null) {
      query['traineeUserId'] = traineeUserId;
    }
    if (cursor != null) {
      query['cursor'] = cursor;
    }
    return _get(
      path: '/training-history/sessions',
      accessToken: accessToken,
      query: query,
      parser: TrainingHistoryPage.fromJson,
    );
  }

  Future<TrainingHistoryApiResult<TrainingHistorySession>> detail({
    required String accessToken,
    required String sessionId,
  }) {
    return _get(
      path: '/training-history/sessions/$sessionId',
      accessToken: accessToken,
      parser: TrainingHistorySession.fromJson,
    );
  }

  Future<TrainingHistoryApiResult<ExerciseProgress>> progress({
    required String accessToken,
    required String exerciseId,
    String? traineeUserId,
  }) {
    final query = <String, String>{};
    if (traineeUserId != null) {
      query['traineeUserId'] = traineeUserId;
    }
    return _get(
      path: '/training-history/exercises/$exerciseId',
      accessToken: accessToken,
      query: query,
      parser: ExerciseProgress.fromJson,
    );
  }

  Future<TrainingHistoryApiResult<T>> _get<T>({
    required String path,
    required String accessToken,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String> query = const {},
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return const TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.error,
        message: 'API_BASE_URL is not configured.',
      );
    }

    final normalized = baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final uri = Uri.parse(
      '$normalized$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _httpClient
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        return TrainingHistoryApiResult(
          status: _status(response.statusCode),
          statusCode: response.statusCode,
          message: _message(response),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.success,
        statusCode: 200,
        message: 'Request succeeded.',
        data: parser(decoded),
      );
    } on TimeoutException {
      return const TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.offline,
        message: 'History request timed out.',
      );
    } on FormatException {
      return const TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.error,
        message: 'Invalid training history response JSON.',
      );
    } on http.ClientException catch (error) {
      return TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.error,
        message: error.toString(),
      );
    }
  }

  static TrainingHistoryApiStatus _status(int code) => switch (code) {
    400 => TrainingHistoryApiStatus.badRequest,
    401 => TrainingHistoryApiStatus.unauthorized,
    403 => TrainingHistoryApiStatus.forbidden,
    404 => TrainingHistoryApiStatus.notFound,
    _ => TrainingHistoryApiStatus.error,
  };

  static String _message(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['error'] ?? decoded['message'];
        if (value is String) return value;
      }
    } on FormatException {
      // Fall through to generic status.
    }
    return 'API returned HTTP ${response.statusCode}.';
  }
}
