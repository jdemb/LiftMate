# Runtime Token Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep an authenticated mobile session usable after access-token expiry by refreshing on demand, retrying one unexpected `401`, and supplying fresh credentials to SignalR reconnects.

**Architecture:** `AuthController` owns token rotation and exposes a concurrency-safe asynchronous token accessor. A shared `http.BaseClient` refreshes before protected HTTP calls and replays one request after an unexpected `401`; SignalR receives a dynamic token callback. `AuthApiClient` stays outside the wrapper so refresh calls cannot recurse.

**Tech Stack:** Flutter/Dart, `package:http`, `signalr_netcore`, `flutter_test`

---

## File map

- Create `apps/mobile/lib/auth/authenticated_http_client.dart`: session-aware HTTP transport and one-time replay policy.
- Create `apps/mobile/test/auth_controller_runtime_refresh_test.dart`: expiry, failed refresh, and concurrent refresh coverage.
- Create `apps/mobile/test/authenticated_http_client_test.dart`: preflight refresh, one-time `401` replay, body preservation, and pass-through coverage.
- Modify `apps/mobile/lib/auth/auth_controller.dart`: valid-token accessor and single-flight refresh coordination.
- Modify `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart`: dynamic token provider for reconnect.
- Modify `apps/mobile/test/shared_session_realtime_client_test.dart`: provider regression coverage.
- Modify `apps/mobile/lib/main.dart`: shared authenticated transport and SignalR provider wiring.

### Task 1: Make runtime token refresh concurrency-safe

**Files:**
- Create: `apps/mobile/test/auth_controller_runtime_refresh_test.dart`
- Modify: `apps/mobile/lib/auth/auth_controller.dart`

- [ ] **Step 1: Write the failing runtime refresh tests**

Create `apps/mobile/test/auth_controller_runtime_refresh_test.dart`:

```dart
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
      final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)));
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
      final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)));
      final controller = _controller(
        store: store,
        now: () => now,
        onRefresh: (_) async {
          refreshCalls += 1;
          if (!started.isCompleted) started.complete();
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

    test('does not refresh again when another caller already replaced rejected token', () async {
      var refreshCalls = 0;
      final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)));
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
        await controller.getValidAccessToken(rejectedAccessToken: 'old-access'),
        'new-access',
      );
      expect(
        await controller.getValidAccessToken(rejectedAccessToken: 'old-access'),
        'new-access',
      );
      expect(refreshCalls, 1);
    });

    test('clears local session when refresh fails', () async {
      var now = DateTime.utc(2026, 6, 29, 12);
      final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)));
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
        if (request.url.path == '/auth/refresh') return onRefresh(request);
        throw StateError('Unexpected request: ${request.url.path}');
      }),
      baseUrl: 'https://api.example.test',
    ),
    tokenStore: store,
    now: now,
  );
}

StoredAuthTokens _tokens({required DateTime expiresAt}) => StoredAuthTokens(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      expiresAt: expiresAt,
    );

Map<String, Object?> _sessionJson() => {
      'accessToken': 'new-access',
      'refreshToken': 'new-refresh',
      'expiresAt': DateTime.utc(2026, 6, 29, 17).toIso8601String(),
      'user': _userJson,
    };

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
  Future<void> save(StoredAuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    tokens = null;
  }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run from `apps/mobile`:

```powershell
flutter test test/auth_controller_runtime_refresh_test.dart
```

Expected: compilation fails because `AuthController.getValidAccessToken` does not exist.

- [ ] **Step 3: Implement the accessor and single-flight coordination**

In `apps/mobile/lib/auth/auth_controller.dart`, add:

```dart
Future<void>? _refreshInFlight;

Future<String?> getValidAccessToken({String? rejectedAccessToken}) async {
  final currentTokens = _tokens;
  if (currentTokens == null) return null;

  final mustRefresh = rejectedAccessToken == null
      ? _shouldRefresh(currentTokens)
      : currentTokens.accessToken == rejectedAccessToken;
  if (!mustRefresh) return currentTokens.accessToken;

  final refresh = _refreshInFlight ??=
      _refreshStoredSession(currentTokens.refreshToken);
  try {
    await refresh;
  } finally {
    if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
  }
  return _tokens?.accessToken;
}
```

In both refresh branches of `initialize()`, replace direct `_refreshStoredSession(...)` calls with:

```dart
await getValidAccessToken(rejectedAccessToken: storedTokens.accessToken);
```

Keep `_refreshStoredSession`, `_storeSession`, and `_clearSession` as the persistence and state-transition boundary.

- [ ] **Step 4: Run tests and verify GREEN**

```powershell
flutter test test/auth_controller_runtime_refresh_test.dart test/auth_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit Task 1**

```powershell
git add -- apps/mobile/lib/auth/auth_controller.dart apps/mobile/test/auth_controller_runtime_refresh_test.dart
git commit -m "mobile: coordinate runtime token refresh"
```

### Task 2: Add the authenticated HTTP transport

**Files:**
- Create: `apps/mobile/lib/auth/authenticated_http_client.dart`
- Create: `apps/mobile/test/authenticated_http_client_test.dart`

- [ ] **Step 1: Write failing transport tests**

Create `apps/mobile/test/authenticated_http_client_test.dart` with the complete test suite and local fixtures below:

```dart
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
    final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 13)));
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

  test('refreshes and retries once after an unexpected 401', () async {
    var refreshCalls = 0;
    var protectedCalls = 0;
    final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)));
    final controller = await _initializedController(
      store: store,
      now: () => DateTime.utc(2026, 6, 29, 12),
      onRefresh: (_) async {
        refreshCalls += 1;
        return http.Response(jsonEncode(_sessionJson()), 200);
      },
    );
    final seenBodies = <String>[];
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
    final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)));
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
    final store = _MemoryTokenStore(_tokens(expiresAt: DateTime.utc(2026, 6, 29, 16)));
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

    final response = await client.get(Uri.parse('https://api.example.test/health'));
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
        if (request.url.path == '/auth/refresh') return onRefresh(request);
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

StoredAuthTokens _tokens({required DateTime expiresAt}) => StoredAuthTokens(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      expiresAt: expiresAt,
    );

Map<String, Object?> _sessionJson() => {
      'accessToken': 'new-access',
      'refreshToken': 'new-refresh',
      'expiresAt': DateTime.utc(2026, 6, 29, 17).toIso8601String(),
      'user': _userJson,
    };

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
  Future<void> save(StoredAuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}
```

- [ ] **Step 2: Run the tests and verify RED**

```powershell
flutter test test/authenticated_http_client_test.dart
```

Expected: compilation fails because `AuthenticatedHttpClient` does not exist.

- [ ] **Step 3: Implement one-time replay with exact request copying**

Create `apps/mobile/lib/auth/authenticated_http_client.dart`:

```dart
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
    if (accessToken == null) return _unauthorized(request);

    final first = await _inner.send(_copy(request, bodyBytes, accessToken));
    if (first.statusCode != 401) return first;

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
```

- [ ] **Step 4: Run transport and auth tests and verify GREEN**

```powershell
flutter test test/authenticated_http_client_test.dart test/auth_controller_runtime_refresh_test.dart test/auth_api_client_test.dart test/token_store_test.dart
```

Expected: all tests pass; request count is two only for the `401` case and the POST body matches on both attempts.

- [ ] **Step 5: Commit Task 2**

```powershell
git add -- apps/mobile/lib/auth/authenticated_http_client.dart apps/mobile/test/authenticated_http_client_test.dart
git commit -m "mobile: retry authenticated requests after refresh"
```

### Task 3: Supply current tokens to SignalR reconnects

**Files:**
- Modify: `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart`
- Modify: `apps/mobile/test/shared_session_realtime_client_test.dart`

- [ ] **Step 1: Write a failing dynamic-provider test**

Add to `apps/mobile/test/shared_session_realtime_client_test.dart`:

```dart
test('hub token provider reads the current token for every handshake', () async {
  var currentToken = 'access-token-1';
  late Future<String> Function() capturedProvider;
  final client = SignalRSharedSessionRealtimeClient(
    baseUrl: 'https://api.example.test/',
    accessTokenProvider: () async => currentToken,
    hubConnectionFactory: (hubUrl, accessTokenProvider) {
      capturedProvider = accessTokenProvider;
      return _FakeHubConnectionAdapter(hubUrl, 'unused');
    },
  );

  await client.connect(accessToken: 'initial-fallback');

  expect(await capturedProvider(), 'access-token-1');
  currentToken = 'access-token-2';
  expect(await capturedProvider(), 'access-token-2');
});
```

- [ ] **Step 2: Run the test and verify RED**

```powershell
flutter test test/shared_session_realtime_client_test.dart
```

Expected: compilation fails because the constructor has no `accessTokenProvider` and `HubConnectionFactory` still accepts a string.

- [ ] **Step 3: Change the hub factory to receive a dynamic provider**

In `apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart`, add and use these exact declarations:

```dart
typedef AccessTokenProvider = Future<String> Function();

SignalRSharedSessionRealtimeClient({
  required String? baseUrl,
  AccessTokenProvider? accessTokenProvider,
  HubConnectionFactory? hubConnectionFactory,
})  : _baseUrl = _resolveBaseUrl(baseUrl),
      _accessTokenProvider = accessTokenProvider,
      _hubConnectionFactory =
          hubConnectionFactory ?? _defaultHubConnectionFactory;

final AccessTokenProvider? _accessTokenProvider;
```

In `connect`, replace the static factory argument with:

```dart
final tokenProvider = _accessTokenProvider ?? () async => accessToken;
final connection = _hubConnectionFactory(hubUrl, tokenProvider);
```

Replace the factory typedef and default function with:

```dart
typedef HubConnectionFactory = HubConnectionAdapter Function(
  String hubUrl,
  AccessTokenProvider accessTokenProvider,
);

HubConnectionAdapter _defaultHubConnectionFactory(
  String hubUrl,
  AccessTokenProvider accessTokenProvider,
) {
  final connection = HubConnectionBuilder()
      .withUrl(
        hubUrl,
        options: HttpConnectionOptions(
          accessTokenFactory: accessTokenProvider,
        ),
      )
      .withAutomaticReconnect()
      .build();
  return SignalRHubConnectionAdapter(connection);
}
```

Keep `SharedSessionRealtimeClient.connect({required String accessToken})` unchanged; the string is the fallback when no provider is injected.

- [ ] **Step 4: Adapt existing factory-based tests**

For every existing `(hubUrl, accessToken)` test lambda, capture the provider and assert its result after `connect`:

```dart
late AccessTokenProvider tokenProvider;
final client = SignalRSharedSessionRealtimeClient(
  baseUrl: 'https://api.example.test',
  hubConnectionFactory: (hubUrl, provider) {
    tokenProvider = provider;
    fakeConnection = _FakeHubConnectionAdapter(hubUrl, 'unused');
    return fakeConnection;
  },
);

await client.connect(accessToken: 'access-token');
expect(await tokenProvider(), 'access-token');
```

Retain the existing URL, start/stop, update, status, and error assertions.

- [ ] **Step 5: Run realtime and shared-session tests**

```powershell
flutter test test/shared_session_realtime_client_test.dart test/shared_session_controller_test.dart test/live_session_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit Task 3**

```powershell
git add -- apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart apps/mobile/test/shared_session_realtime_client_test.dart
git commit -m "mobile: refresh token for realtime reconnect"
```

### Task 4: Wire the authenticated transport into production

**Files:**
- Modify: `apps/mobile/lib/main.dart`
- Verify: `apps/mobile/test/authenticated_http_client_test.dart`
- Verify: `apps/mobile/test/shared_session_realtime_client_test.dart`

- [ ] **Step 1: Construct dependencies in session-safe order**

In `apps/mobile/lib/main.dart`, add:

```dart
import 'package:http/http.dart' as http;

import 'auth/authenticated_http_client.dart';
```

Replace the construction block at the start of `main()` with:

```dart
final config = await AppConfig.load();
final authApiClient = AuthApiClient(baseUrl: config.apiBaseUrl);
final authController = AuthController(
  authApiClient: authApiClient,
  tokenStore: SecureTokenStore(),
);
final authenticatedHttpClient = AuthenticatedHttpClient(
  authController: authController,
  inner: http.Client(),
);
final relationshipApiClient = RelationshipApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
final workoutSetApiClient = WorkoutSetApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
final sharedSessionApiClient = SharedSessionApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
final trainingHistoryApiClient = TrainingHistoryApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
final postWorkoutFeedbackApiClient = PostWorkoutFeedbackApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
final trainerGuidanceApiClient = TrainerGuidanceApiClient(
  httpClient: authenticatedHttpClient,
  baseUrl: config.apiBaseUrl,
);
```

Pass `authController: authController` to `MainApp`. Replace the realtime factory with:

```dart
return SignalRSharedSessionRealtimeClient(
  baseUrl: config.apiBaseUrl,
  accessTokenProvider: () async {
    final accessToken = await authController.getValidAccessToken();
    if (accessToken == null) {
      throw StateError('User is not authenticated.');
    }
    return accessToken;
  },
);
```

- [ ] **Step 2: Format changed files**

Run from `apps/mobile`:

```powershell
dart format lib/auth/auth_controller.dart lib/auth/authenticated_http_client.dart lib/shared_sessions/shared_session_realtime_client.dart lib/main.dart test/auth_controller_runtime_refresh_test.dart test/authenticated_http_client_test.dart test/shared_session_realtime_client_test.dart
```

Expected: formatter exits with code `0`.

- [ ] **Step 3: Run focused verification**

```powershell
flutter test test/auth_controller_runtime_refresh_test.dart test/authenticated_http_client_test.dart test/auth_api_client_test.dart test/auth_screen_test.dart test/shared_session_realtime_client_test.dart test/shared_session_controller_test.dart test/post_auth_relationship_screen_test.dart
```

Expected: all tests pass.

- [ ] **Step 4: Run complete mobile verification sequentially**

```powershell
flutter test
flutter analyze
```

Expected: full suite passes and analyzer reports `No issues found!`.

- [ ] **Step 5: Inspect scope without touching existing user changes**

Run from repository root:

```powershell
git status --short
git diff --check
git diff -- apps/mobile/lib/auth/auth_controller.dart apps/mobile/lib/auth/authenticated_http_client.dart apps/mobile/lib/shared_sessions/shared_session_realtime_client.dart apps/mobile/lib/main.dart apps/mobile/test/auth_controller_runtime_refresh_test.dart apps/mobile/test/authenticated_http_client_test.dart apps/mobile/test/shared_session_realtime_client_test.dart
```

Expected: implementation diff contains only the listed files. Existing changes under `.agents/` and `apps/mobile/design/` remain untouched.

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- apps/mobile/lib/main.dart
git commit -m "mobile: wire automatic session refresh"
```

- [ ] **Step 7: Record final evidence**

```powershell
git status --short
git log -5 --oneline
```

Expected: runtime-refresh files are clean, unrelated pre-existing changes remain unstaged, and all task commits are visible.
