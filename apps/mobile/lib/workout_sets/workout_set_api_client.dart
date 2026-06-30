import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'workout_set_models.dart';

enum WorkoutSetApiStatus {
  success,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  offline,
  error,
}

class WorkoutSetApiResult<T> {
  const WorkoutSetApiResult({
    required this.status,
    required this.message,
    this.data,
    this.statusCode,
  });

  final WorkoutSetApiStatus status;
  final String message;
  final T? data;
  final int? statusCode;

  bool get isSuccess => status == WorkoutSetApiStatus.success;
}

class WorkoutSetApiClient {
  WorkoutSetApiClient({
    http.Client? httpClient,
    String? baseUrl,
    this.timeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = _resolveBaseUrl(baseUrl);

  final http.Client _httpClient;
  final String? _baseUrl;
  final Duration timeout;

  Future<WorkoutSetApiResult<List<WorkoutSetSummary>>> listTrainerSets({
    required String accessToken,
  }) {
    return _send<List<WorkoutSetSummary>>(
      method: 'GET',
      path: '/workout-sets',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: (decoded) => _parseList(
        decoded,
        WorkoutSetSummary.fromJson,
        'Invalid workout set list response JSON.',
      ),
      invalidJsonMessage: 'Invalid workout set list response JSON.',
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> create({
    required String accessToken,
    required CreateWorkoutSetRequest request,
  }) {
    return _send<WorkoutSetDetail>(
      method: 'POST',
      path: '/workout-sets',
      accessToken: accessToken,
      body: request.toJson(),
      successStatusCodes: {201},
      parse: (decoded) => _parseMap(decoded, WorkoutSetDetail.fromJson),
      invalidJsonMessage: 'Invalid workout set detail response JSON.',
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> getTrainerSet({
    required String accessToken,
    required String workoutSetId,
  }) {
    return _send<WorkoutSetDetail>(
      method: 'GET',
      path: '/workout-sets/$workoutSetId',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: (decoded) => _parseMap(decoded, WorkoutSetDetail.fromJson),
      invalidJsonMessage: 'Invalid workout set detail response JSON.',
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> update({
    required String accessToken,
    required String workoutSetId,
    required UpdateWorkoutSetRequest request,
  }) {
    return _send<WorkoutSetDetail>(
      method: 'PUT',
      path: '/workout-sets/$workoutSetId',
      accessToken: accessToken,
      body: request.toJson(),
      successStatusCodes: {200},
      parse: (decoded) => _parseMap(decoded, WorkoutSetDetail.fromJson),
      invalidJsonMessage: 'Invalid workout set detail response JSON.',
    );
  }

  Future<WorkoutSetApiResult<void>> delete({
    required String accessToken,
    required String workoutSetId,
  }) {
    return _send<void>(
      method: 'DELETE',
      path: '/workout-sets/$workoutSetId',
      accessToken: accessToken,
      successStatusCodes: {204},
      parse: (_) {},
      invalidJsonMessage: 'Invalid workout set delete response JSON.',
      expectBody: false,
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> assign({
    required String accessToken,
    required String workoutSetId,
    required AssignWorkoutSetRequest request,
  }) {
    return _send<WorkoutSetDetail>(
      method: 'POST',
      path: '/workout-sets/$workoutSetId/assignments',
      accessToken: accessToken,
      body: request.toJson(),
      successStatusCodes: {200},
      parse: (decoded) => _parseMap(decoded, WorkoutSetDetail.fromJson),
      invalidJsonMessage: 'Invalid workout set detail response JSON.',
    );
  }

  Future<WorkoutSetApiResult<void>> unassign({
    required String accessToken,
    required String workoutSetId,
    required String traineeUserId,
  }) {
    return _send<void>(
      method: 'DELETE',
      path: '/workout-sets/$workoutSetId/assignments/$traineeUserId',
      accessToken: accessToken,
      successStatusCodes: {204},
      parse: (_) {},
      invalidJsonMessage: 'Invalid workout set unassign response JSON.',
      expectBody: false,
    );
  }

  Future<WorkoutSetApiResult<List<TraineeAssignedWorkoutSet>>> listTraineeSets({
    required String accessToken,
  }) {
    return _send<List<TraineeAssignedWorkoutSet>>(
      method: 'GET',
      path: '/trainee/workout-sets',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: (decoded) => _parseList(
        decoded,
        TraineeAssignedWorkoutSet.fromJson,
        'Invalid trainee workout set list response JSON.',
      ),
      invalidJsonMessage: 'Invalid trainee workout set list response JSON.',
    );
  }

  Future<WorkoutSetApiResult<TraineeAssignedWorkoutSet>> getTraineeSet({
    required String accessToken,
    required String workoutSetId,
  }) {
    return _send<TraineeAssignedWorkoutSet>(
      method: 'GET',
      path: '/trainee/workout-sets/$workoutSetId',
      accessToken: accessToken,
      successStatusCodes: {200},
      parse: (decoded) => _parseMap(decoded, TraineeAssignedWorkoutSet.fromJson),
      invalidJsonMessage: 'Invalid trainee workout set response JSON.',
    );
  }

  Future<WorkoutSetApiResult<T>> _send<T>({
    required String method,
    required String path,
    required String accessToken,
    required Set<int> successStatusCodes,
    required T Function(Object? decoded) parse,
    required String invalidJsonMessage,
    Map<String, Object?>? body,
    bool expectBody = true,
  }) async {
    final uri = _uri(path);
    if (uri == null) {
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.error,
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

      final data = expectBody ? parse(jsonDecode(response.body)) : parse(null);
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.success,
        statusCode: response.statusCode,
        message: 'Request succeeded.',
        data: data,
      );
    } on TimeoutException {
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.offline,
        message: 'Workout set request timed out.',
      );
    } on FormatException {
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.error,
        message: invalidJsonMessage,
      );
    } on http.ClientException catch (error) {
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.offline,
        message: error.message,
      );
    } on Object catch (error) {
      return WorkoutSetApiResult<T>(
        status: WorkoutSetApiStatus.error,
        message: error.toString(),
      );
    }
  }

  WorkoutSetApiResult<T> _failureFromResponse<T>(http.Response response) {
    return WorkoutSetApiResult<T>(
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

  static WorkoutSetApiStatus _statusFor(int statusCode) {
    return switch (statusCode) {
      400 => WorkoutSetApiStatus.badRequest,
      401 => WorkoutSetApiStatus.unauthorized,
      403 => WorkoutSetApiStatus.forbidden,
      404 => WorkoutSetApiStatus.notFound,
      409 => WorkoutSetApiStatus.conflict,
      _ => WorkoutSetApiStatus.error,
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

T _parseMap<T>(Object? decoded, T Function(Map<String, dynamic> json) parse) {
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid workout set response body.');
  }

  return parse(decoded);
}

List<T> _parseList<T>(
  Object? decoded,
  T Function(Map<String, dynamic> json) parse,
  String message,
) {
  if (decoded is! List) {
    throw FormatException(message);
  }

  return decoded.map((value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException(message);
    }

    return parse(value);
  }).toList(growable: false);
}
