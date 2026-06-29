import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/token_store.dart';

void main() {
  group('AuthController runtime refresh', () {
    test('refreshes an expired access token before returning it', () async {
      var now = DateTime.utc(2026, 6, 29, 12);
      var refreshCalls = 0;
      final store = _MemoryTokenStore(
        _tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)),
      );
      final controller = _controller(
        store: store,
        now: () => now,
        onRefresh: (request) async {
          refreshCalls += 1;
          expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});
          return http.Response(jsonEncode(_sessionJson()), 200);
        },
      );
      await controller.initialize();
      now = DateTime.utc(2026, 6, 29, 14);

      expect(await controller.getValidAccessToken(), 'new-access');
      expect(refreshCalls, 1);
      expect(store.tokens?.refreshToken, 'new-refresh');
      expect(controller.state.status, AuthControllerStatus.authenticated);
    });

    test('shares one refresh across concurrent callers', () async {
      var now = DateTime.utc(2026, 6, 29, 12);
      final started = Completer<void>();
      final release = Completer<void>();
      var refreshCalls = 0;
      final store = _MemoryTokenStore(
        _tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)),
      );
      final controller = _controller(
        store: store,
        now: () => now,
        onRefresh: (_) async {
          refreshCalls += 1;
          if (!started.isCompleted) {
            started.complete();
          }
          await release.future;
          return http.Response(jsonEncode(_sessionJson()), 200);
        },
      );
      await controller.initialize();
      now = DateTime.utc(2026, 6, 29, 14);

      final first = controller.getValidAccessToken();
      final second = controller.getValidAccessToken();
      await started.future;
      release.complete();

      expect(await Future.wait([first, second]), ['new-access', 'new-access']);
      expect(refreshCalls, 1);
    });

    test(
      'does not refresh when another caller already replaced rejected token',
      () async {
        var refreshCalls = 0;
        final store = _MemoryTokenStore(
          _tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)),
        );
        final controller = _controller(
          store: store,
          now: () => DateTime.utc(2026, 6, 29, 12),
          onRefresh: (_) async {
            refreshCalls += 1;
            return http.Response(jsonEncode(_sessionJson()), 200);
          },
        );
        await controller.initialize();

        expect(
          await controller.getValidAccessToken(
            rejectedAccessToken: 'old-access',
          ),
          'new-access',
        );
        expect(
          await controller.getValidAccessToken(
            rejectedAccessToken: 'old-access',
          ),
          'new-access',
        );
        expect(refreshCalls, 1);
      },
    );

    test('clears local session when refresh fails', () async {
      var now = DateTime.utc(2026, 6, 29, 12);
      final store = _MemoryTokenStore(
        _tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)),
      );
      final controller = _controller(
        store: store,
        now: () => now,
        onRefresh: (_) async => http.Response('', 401),
      );
      await controller.initialize();
      now = DateTime.utc(2026, 6, 29, 14);

      expect(await controller.getValidAccessToken(), isNull);
      expect(store.tokens, isNull);
      expect(store.clearCalls, 1);
      expect(controller.tokens, isNull);
      expect(controller.state.status, AuthControllerStatus.unauthenticated);
    });
  });
}

AuthController _controller({
  required _MemoryTokenStore store,
  required DateTime Function() now,
  required Future<http.Response> Function(http.Request request) onRefresh,
}) {
  return AuthController(
    authApiClient: AuthApiClient(
      httpClient: MockClient((request) {
        if (request.url.path == '/auth/me') {
          return Future.value(http.Response(jsonEncode(_userJson), 200));
        }
        if (request.url.path == '/auth/refresh') {
          return onRefresh(request);
        }
        throw StateError('Unexpected request: ${request.url.path}');
      }),
      baseUrl: 'https://api.example.test',
    ),
    tokenStore: store,
    now: now,
  );
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
  var clearCalls = 0;

  @override
  Future<StoredAuthTokens?> read() async => tokens;

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    tokens = null;
  }
}
