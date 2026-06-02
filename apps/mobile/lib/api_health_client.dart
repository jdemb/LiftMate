import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum ApiHealthStatus {
  online,
  offline,
  error,
}

class ApiHealthResult {
  const ApiHealthResult({
    required this.status,
    required this.checkedUri,
    required this.message,
    this.statusCode,
  });

  final ApiHealthStatus status;
  final Uri? checkedUri;
  final String message;
  final int? statusCode;

  bool get isOnline => status == ApiHealthStatus.online;
}

class ApiHealthClient {
  ApiHealthClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 3),
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _resolveBaseUrl(baseUrl);

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Uri? get healthUri {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return null;
    }

    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/*$'), '')}/health');
  }

  Future<ApiHealthResult> check() async {
    final uri = healthUri;
    if (uri == null) {
      return ApiHealthResult(
        status: ApiHealthStatus.error,
        checkedUri: null,
        message: 'API_BASE_URL is not configured.',
      );
    }

    try {
      final response = await _httpClient.get(uri).timeout(timeout);

      if (response.statusCode != 200) {
        return ApiHealthResult(
          status: ApiHealthStatus.offline,
          checkedUri: uri,
          statusCode: response.statusCode,
          message: 'API returned HTTP ${response.statusCode}.',
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return ApiHealthResult(
          status: ApiHealthStatus.error,
          checkedUri: uri,
          statusCode: response.statusCode,
          message: 'Invalid health response body.',
        );
      }

      final status = body['status'];
      if (status == 'ok') {
        return ApiHealthResult(
          status: ApiHealthStatus.online,
          checkedUri: uri,
          statusCode: response.statusCode,
          message: 'API is reachable.',
        );
      }

      return ApiHealthResult(
        status: ApiHealthStatus.offline,
        checkedUri: uri,
        statusCode: response.statusCode,
        message: 'API health status is $status.',
      );
    } on TimeoutException {
      return ApiHealthResult(
        status: ApiHealthStatus.error,
        checkedUri: uri,
        message: 'API health check timed out.',
      );
    } on FormatException {
      return ApiHealthResult(
        status: ApiHealthStatus.error,
        checkedUri: uri,
        message: 'Invalid health response JSON.',
      );
    } on http.ClientException catch (error) {
      return ApiHealthResult(
        status: ApiHealthStatus.error,
        checkedUri: uri,
        message: error.message,
      );
    } on Object catch (error) {
      return ApiHealthResult(
        status: ApiHealthStatus.error,
        checkedUri: uri,
        message: error.toString(),
      );
    }
  }

  static String? _resolveBaseUrl(String? explicitBaseUrl) {
    final value = explicitBaseUrl;
    if (value == null) {
      return null;
    }

    if (value.trim().isEmpty) {
      return null;
    }

    return value.trim();
  }
}
