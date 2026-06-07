import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/api_health_client.dart';
import 'package:liftmate/api_smoke_screen.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/shared_sessions/shared_session_api_client.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/shared_sessions/shared_session_realtime_client.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows login form and API diagnostics', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent on empty startup');
          }),
        ),
      );
      await tester.pump();

      expect(find.text('Sign in'), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('API diagnostics'), findsOneWidget);
      expect(find.text('https://api.example.test/health'), findsOneWidget);
    });

    testWidgets('shows registration fields and role selector', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent before submitting');
          }),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Create account'), findsNWidgets(2));
      expect(find.text('Invitation code'), findsOneWidget);
      expect(find.text('Trainer'), findsOneWidget);
      expect(find.text('Trainee'), findsOneWidget);
    });

    testWidgets('logs in, shows current user, probe success, and logs out', (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/login') {
              return http.Response(jsonEncode(_authResponse(role: 'trainer')), 200);
            }
            if (request.url.path == '/trainer/probe') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('{"role":"trainer"}', 200);
            }
            if (request.url.path == '/shared-sessions/active') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('', 404);
            }
            if (request.url.path == '/auth/logout') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
              return http.Response('', 204);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'trainer@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('trainer@example.test'), findsOneWidget);
      expect(find.text('trainer'), findsOneWidget);
      expect(find.text('Trainer probe passed'), findsOneWidget);

      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(
        seenPaths,
        containsAll([
          '/auth/login',
          '/trainer/probe',
          '/shared-sessions/active',
          '/auth/logout',
        ]),
      );
    });

    testWidgets('shows login error without exposing password', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            return http.Response('{"message":"Invalid credentials."}', 401);
          }),
        ),
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'trainer@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.contains('Password123') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('submits registration with selected trainee role and invite code', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/register') {
              expect(jsonDecode(request.body), {
                'email': 'trainee@example.test',
                'password': 'Password123!',
                'role': 'trainee',
                'invitationCode': 'invite-123',
              });
              return http.Response(jsonEncode(_authResponse(role: 'trainee')), 201);
            }
            if (request.url.path == '/trainee/probe') {
              return http.Response('{"role":"trainee"}', 200);
            }
            if (request.url.path == '/shared-sessions/active') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('', 404);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.tap(find.text('Trainee'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'trainee@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Invitation code'), 'invite-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('trainee@example.test'), findsOneWidget);
      expect(find.text('Trainee probe passed'), findsOneWidget);
    });
  });
}

Widget _testApp({
  required http.Client httpClient,
  ApiHealthCheck? checkHealth,
}) {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: httpClient,
  );
  final sharedSessionApiClient = SharedSessionApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: httpClient,
  );

  return MaterialApp(
    home: AuthScreen(
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: _InMemoryTokenStore(),
      ),
      authApiClient: authApiClient,
      sharedSessionApiClient: sharedSessionApiClient,
      sharedSessionRealtimeClientFactory: _FakeSharedSessionRealtimeClient.new,
      healthUri: Uri.parse('https://api.example.test/health'),
      checkHealth: checkHealth ??
          () async => ApiHealthResult(
                status: ApiHealthStatus.online,
                checkedUri: Uri.parse('https://api.example.test/health'),
                message: 'API is reachable.',
                statusCode: 200,
              ),
    ),
  );
}

Map<String, Object?> _authResponse({required String role}) {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-02T12:00:00Z',
    'user': {
      'id': 'user-1',
      'email': '$role@example.test',
      'role': role,
    },
  };
}

class _InMemoryTokenStore implements TokenStore {
  StoredAuthTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> read() async => _tokens;

  @override
  Future<void> save(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}

class _FakeSharedSessionRealtimeClient implements SharedSessionRealtimeClient {
  final _updatesController = StreamController<SharedSession>.broadcast();
  final _statusController = StreamController<SharedSessionConnectionStatus>.broadcast();
  final _errorsController = StreamController<String>.broadcast();

  @override
  Stream<SharedSession> get updates => _updatesController.stream;

  @override
  Stream<SharedSessionConnectionStatus> get connectionStatus => _statusController.stream;

  @override
  Stream<String> get errors => _errorsController.stream;

  @override
  Future<void> connect({
    required String accessToken,
  }) async {}

  @override
  Future<void> joinSession({
    required String sessionId,
  }) async {}

  @override
  Future<void> disconnect() async {}
}
