import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'trainer_guidance_models.dart';

enum TrainerGuidanceApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  offline,
  error,
}

class TrainerGuidanceApiResult<T> {
  const TrainerGuidanceApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final TrainerGuidanceApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == TrainerGuidanceApiStatus.success;
}

class TrainerGuidanceApiClient {
  TrainerGuidanceApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl?.trim().isEmpty ?? true ? null : baseUrl!.trim();

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<TrainerGuidanceApiResult<TrainerGuidanceList>> list({
    required String accessToken,
    required String traineeUserId,
  }) {
    return _send(
      method: _HttpMethod.get,
      path: '/trainer-guidance',
      accessToken: accessToken,
      query: {'traineeUserId': traineeUserId},
      parser: TrainerGuidanceList.fromJson,
    );
  }

  Future<TrainerGuidanceApiResult<void>> markAsRead({
    required String accessToken,
    required String guidanceId,
  }) {
    return _send(
      method: _HttpMethod.post,
      path: '/trainer-guidance/$guidanceId/read',
      accessToken: accessToken,
    );
  }

  Future<TrainerGuidanceApiResult<T>> _send<T>({
    required _HttpMethod method,
    required String path,
    required String accessToken,
    Map<String, String> query = const {},
    T Function(Map<String, dynamic>)? parser,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return const TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.error,
        message: 'API_BASE_URL is not configured.',
      );
    }

    final normalized = baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final uri = Uri.parse(
      '$normalized$path',
    ).replace(queryParameters: query.isEmpty ? null : query);
    try {
      final headers = {'Authorization': 'Bearer $accessToken'};
      final response = switch (method) {
        _HttpMethod.get =>
          await _httpClient.get(uri, headers: headers).timeout(timeout),
        _HttpMethod.post =>
          await _httpClient.post(uri, headers: headers).timeout(timeout),
      };

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TrainerGuidanceApiResult(
          status: _status(response.statusCode),
          statusCode: response.statusCode,
          message: _message(response),
        );
      }

      if (parser == null) {
        return TrainerGuidanceApiResult(
          status: TrainerGuidanceApiStatus.success,
          statusCode: response.statusCode,
          message: 'Request succeeded.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: parser(decoded),
      );
    } on TimeoutException {
      return const TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.offline,
        message: 'Trainer guidance request timed out.',
      );
    } on FormatException {
      return const TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.error,
        message: 'Invalid trainer guidance response JSON.',
      );
    } on http.ClientException catch (error) {
      return TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.error,
        message: error.toString(),
      );
    }
  }

  static TrainerGuidanceApiStatus _status(int code) => switch (code) {
    400 => TrainerGuidanceApiStatus.badRequest,
    401 => TrainerGuidanceApiStatus.unauthorized,
    403 => TrainerGuidanceApiStatus.forbidden,
    404 => TrainerGuidanceApiStatus.notFound,
    _ => TrainerGuidanceApiStatus.error,
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

enum _HttpMethod { get, post }
