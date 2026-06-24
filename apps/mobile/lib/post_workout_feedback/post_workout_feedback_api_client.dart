import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'post_workout_feedback_models.dart';

enum PostWorkoutFeedbackApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  offline,
  error,
}

class PostWorkoutFeedbackApiResult<T> {
  const PostWorkoutFeedbackApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final PostWorkoutFeedbackApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == PostWorkoutFeedbackApiStatus.success;
}

class PostWorkoutFeedbackApiClient {
  PostWorkoutFeedbackApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl?.trim().isEmpty ?? true ? null : baseUrl!.trim();

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>> submit({
    required String accessToken,
    required String sessionId,
    required PostWorkoutFeedbackRequest request,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      return const PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.error,
        message: 'API_BASE_URL is not configured.',
      );
    }

    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final uri = Uri.parse(
      '$normalizedBaseUrl/shared-sessions/$sessionId/feedback',
    );

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return PostWorkoutFeedbackApiResult(
          status: _statusFor(response.statusCode),
          statusCode: response.statusCode,
          message: _messageFrom(response),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      return PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: PostWorkoutFeedbackResponse.fromJson(decoded),
      );
    } on TimeoutException {
      return const PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.offline,
        message: 'Feedback request timed out.',
      );
    } on FormatException {
      return const PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.error,
        message: 'Invalid post-workout feedback response JSON.',
      );
    } on http.ClientException catch (error) {
      return PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return PostWorkoutFeedbackApiResult(
        status: PostWorkoutFeedbackApiStatus.error,
        message: error.toString(),
      );
    }
  }

  static PostWorkoutFeedbackApiStatus _statusFor(int statusCode) {
    return switch (statusCode) {
      400 => PostWorkoutFeedbackApiStatus.badRequest,
      401 => PostWorkoutFeedbackApiStatus.unauthorized,
      403 => PostWorkoutFeedbackApiStatus.forbidden,
      404 => PostWorkoutFeedbackApiStatus.notFound,
      409 => PostWorkoutFeedbackApiStatus.conflict,
      _ => PostWorkoutFeedbackApiStatus.error,
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
}
