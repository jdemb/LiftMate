import 'dart:async';

import 'package:http/http.dart' as http;

import 'auth_controller.dart';

class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    required AuthController authController,
    required http.Client inner,
  })  : _authController = authController,
        _inner = inner;

  final AuthController _authController;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final authorization = request.headers['Authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      return _inner.send(request);
    }
    if (request is! http.Request) {
      throw UnsupportedError(
        'AuthenticatedHttpClient only replays http.Request instances.',
      );
    }

    final bodyBytes = request.bodyBytes;
    final accessToken = await _authController.getValidAccessToken();
    if (accessToken == null) {
      return _unauthorized(request);
    }

    final first = await _inner.send(_copy(request, bodyBytes, accessToken));
    if (first.statusCode != 401) {
      return first;
    }

    await first.stream.drain<void>();
    final refreshed = await _authController.getValidAccessToken(
      rejectedAccessToken: accessToken,
    );
    if (refreshed == null || refreshed == accessToken) {
      return _unauthorized(request);
    }

    return _inner.send(_copy(request, bodyBytes, refreshed));
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  static http.Request _copy(
    http.Request source,
    List<int> bodyBytes,
    String accessToken,
  ) {
    return http.Request(source.method, source.url)
      ..followRedirects = source.followRedirects
      ..maxRedirects = source.maxRedirects
      ..persistentConnection = source.persistentConnection
      ..headers.addAll(source.headers)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..bodyBytes = bodyBytes;
  }

  static http.StreamedResponse _unauthorized(http.BaseRequest request) {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      401,
      request: request,
      reasonPhrase: 'Unauthorized',
    );
  }
}
