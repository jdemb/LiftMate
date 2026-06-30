import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/authenticated_http_client.dart';
import 'package:liftmate/auth/token_store.dart';

void main() {
  test('refreshes before sending a request with an expired token', () async {
    var now = DateTime.utc(2026, 6, 29, 12);
    final store = _MemoryTokenStore(
      _tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)),
    );
    final controller = await _initializedController(
      store: store,
      now: () => now,
      onRefresh: (_) async => http.Response(jsonEncode(_sessionJson()), 200),
    );
    now = DateTime.utc(2026, 6, 29, 14);
    final client = AuthenticatedHttpClient(
      authController: controller,
      inner: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response('{}', 200);
      }),
    );

    final response = await client.get(
      Uri.parse('https://api.example.test/protected'),
      headers: {'Authorization': 'Bearer old-access'},
    );

    expect(response.statusCode, 200);
  });

  test('refreshes and retries once with the original body after 401', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;
    final seenBodies = <String>[];
    final store = _MemoryTokenStore(
      _tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)),
    );
    final controller = await _initializedController(
      store: store,
      now: () => DateTime.utc(2026, 6, 29, 12),
      onRefresh: (_) async {
        refreshCalls += 1;
        return http.Response(jsonEncode(_sessionJson()), 200);
      },
    );
    final client = AuthenticatedHttpClient(
      authController: controller,
      inner: MockClient((request) async {
        protectedCalls += 1;
        seenBodies.add(request.body);
        if (protectedCalls == 1) {
          expect(request.headers['Authorization'], 'Bearer old-access');
          return http.Response('', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response('{}', 200);
      }),
    );
    final body = jsonEncode({'value': 7});

    final response = await client.post(
      Uri.parse('https://api.example.test/protected'),
      headers: {
        'Authorization': 'Bearer old-access',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
    expect(seenBodies, [body, body]);
  });

  test('returns a second 401 without another refresh or retry', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;
    final store = _MemoryTokenStore(
      _tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)),
    );
    final controller = await _initializedController(
      store: store,
      now: () => DateTime.utc(2026, 6, 29, 12),
      onRefresh: (_) async {
        refreshCalls += 1;
        return http.Response(jsonEncode(_sessionJson()), 200);
      },
    );
    final client = AuthenticatedHttpClient(
      authController: controller,
      inner: MockClient((_) async {
        protectedCalls += 1;
        return http.Response('', 401);
      }),
    );

    final response = await client.get(
      Uri.parse('https://api.example.test/protected'),
      headers: {'Authorization': 'Bearer old-access'},
    );

    expect(response.statusCode, 401);
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
  });

  test('does not retry when refresh fails and clears session', () async {
    var protectedCalls = 0;
    final store = _MemoryTokenStore(
      _tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)),
    );
    final controller = await _initializedController(
      store: store,
      now: () => DateTime.utc(2026, 6, 29, 12),
      onRefresh: (_) async => http.Response('', 401),
    );
    final client = AuthenticatedHttpClient(
      authController: controller,
      inner: MockClient((_) async {
        protectedCalls += 1;
        return http.Response('', 401);
      }),
    );

    final response = await client.get(
      Uri.parse('https://api.example.test/protected'),
      headers: {'Authorization': 'Bearer old-access'},
    );

    expect(response.statusCode, 401);
    expect(protectedCalls, 1);
    expect(controller.state.status, AuthControllerStatus.unauthenticated);
    expect(store.tokens, isNull);
  });

  test('passes a request without bearer token through unchanged', () async {
    final controller = AuthController(
      authApiClient: AuthApiClient(baseUrl: 'https://api.example.test'),
      tokenStore: _MemoryTokenStore(null),
    );
    await controller.initialize();
    final client = AuthenticatedHttpClient(
      authController: controller,
      inner: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('ok', 200);
      }),
    );

    final response = await client.get(
      Uri.parse('https://api.example.test/health'),
    );

    expect(response.body, 'ok');
  });
}

Future<AuthController> _initializedController({
  required _MemoryTokenStore store,
  required DateTime Function() now,
  required Future<http.Response> Function(http.Request request) onRefresh,
}) async {
  final controller = AuthController(
    authApiClient: AuthApiClient(
      httpClient: MockClient((request) {
        if (request.url.path == '/auth/me') {
          return Future.value(http.Response(jsonEncode(_userJson), 200));
        }
        if (request.url.path == '/auth/refresh') {
          return onRefresh(request);
        }
        throw StateError('Unexpected auth request: ${request.url.path}');
      }),
      baseUrl: 'https://api.example.test',
    ),
    tokenStore: store,
    now: now,
  );
  await controller.initialize();
  return controller;
}

StoredAuthTokens _tokens({required DateTime expiresAt}) {
  return StoredAuthTokens(
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
    expiresAt: expiresAt,
  );
}

Map<String, Object?> _sessionJson() {
  return {
    'accessToken': 'new-access',
    'refreshToken': 'new-refresh',
    'expiresAt': DateTime.utc(2026, 6, 29, 17).toIso8601String(),
    'user': _userJson,
  };
}

const _userJson = <String, Object?>{
  'id': 'user-1',
  'email': 'trainer@example.test',
  'displayName': 'Trainer',
  'role': 'trainer',
};

class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore(this.tokens);

  StoredAuthTokens? tokens;

  @override
  Future<StoredAuthTokens?> read() async => tokens;

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clear() async {
    tokens = null;
  }
}
