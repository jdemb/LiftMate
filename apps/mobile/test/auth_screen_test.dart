import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/token_store.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows welcome screen without technical diagnostics', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent on empty startup');
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LiftMate'), findsOneWidget);
      expect(find.text('Załóż konto'), findsOneWidget);
      expect(find.text('Mam już konto'), findsOneWidget);
      expect(find.text('API diagnostics'), findsNothing);
      expect(find.text('Trainer probe passed'), findsNothing);
      expect(find.text('Shared session diagnostics'), findsNothing);
    });

    testWidgets('role selection opens signup with selected trainee role', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent before submitting');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Załóż konto'));
      await tester.pumpAndSettle();

      expect(find.text('Wybierz rolę'), findsOneWidget);
      expect(find.text('Trener'), findsOneWidget);
      expect(find.text('Podopieczny'), findsOneWidget);

      await tester.tap(find.text('Podopieczny'));
      await tester.pumpAndSettle();
      await _tapFilledButton(tester, 'Dalej');

      expect(find.text('Nowe konto'), findsOneWidget);
      expect(find.text('Rola: Podopieczny'), findsOneWidget);
      expect(find.text('Imię i nazwisko'), findsOneWidget);
      expect(find.text('Kod rejestracji'), findsOneWidget);
    });

    testWidgets('logs in and logs out from temporary user panel', (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/login') {
              expect(jsonDecode(request.body), {
                'email': 'trainer@example.test',
                'password': 'Password123!',
              });
              return http.Response(jsonEncode(_authResponse(role: 'trainer')), 200);
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mam już konto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'trainer@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Hasło'), 'Password123!');
      await _tapFilledButton(tester, 'Zaloguj');
      await tester.pumpAndSettle();

      expect(find.text('Witaj, Test Trainer'), findsOneWidget);
      expect(find.text('trainer@example.test'), findsOneWidget);
      expect(find.text('Rola: Trener'), findsOneWidget);

      await tester.tap(find.text('Wyloguj'));
      await tester.pumpAndSettle();

      expect(find.text('Załóż konto'), findsOneWidget);
      expect(seenPaths, ['/auth/login', '/auth/logout']);
    });

    testWidgets('submits signup with display name and registration invite code',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/register') {
              expect(jsonDecode(request.body), {
                'email': 'trainee@example.test',
                'password': 'Password123!',
                'role': 'trainee',
                'displayName': 'Test Trainee',
                'invitationCode': 'invite-123',
              });
              return http.Response(jsonEncode(_authResponse(role: 'trainee')), 201);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Podopieczny');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Imię i nazwisko'),
        'Test Trainee',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'trainee@example.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Hasło'), 'Password123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Kod rejestracji'), 'invite-123');
      await _tapFilledButton(tester, 'Kontynuuj');
      await tester.pumpAndSettle();

      expect(find.text('Połącz z trenerem'), findsOneWidget);
      expect(find.text('Kod trenera'), findsOneWidget);
    });

    testWidgets('trainer signup generates invite code and continues', (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/register') {
              expect(jsonDecode(request.body)['role'], 'trainer');
              return http.Response(jsonEncode(_authResponse(role: 'trainer')), 201);
            }
            if (request.url.path == '/trainer/invite-code') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('{"code":"7F2K9D"}', 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Trener');
      await _fillSignupForm(tester, displayName: 'Test Trainer', email: 'trainer@example.test');
      await _tapFilledButton(tester, 'Kontynuuj');
      await tester.pumpAndSettle();

      expect(find.text('Kod dla podopiecznego'), findsOneWidget);
      await _tapFilledButton(tester, 'Wygeneruj kod');
      await tester.pumpAndSettle();

      expect(find.text('7F2K9D'), findsOneWidget);
      await _tapFilledButton(tester, 'Przejdź dalej');
      await tester.pumpAndSettle();

      expect(find.text('Witaj, Test Trainer'), findsOneWidget);
      expect(seenPaths, ['/auth/register', '/trainer/invite-code']);
    });

    testWidgets('trainee signup claims trainer invite code before continuing',
        (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/register') {
              return http.Response(jsonEncode(_authResponse(role: 'trainee')), 201);
            }
            if (request.url.path == '/trainee/trainer-link') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              expect(jsonDecode(request.body), {'code': '7F2K9D'});
              return http.Response(
                jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
                200,
              );
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Podopieczny');
      await _fillSignupForm(tester, displayName: 'Test Trainee', email: 'trainee@example.test');
      await _tapFilledButton(tester, 'Kontynuuj');
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Kod trenera'), '  7f2k9d  ');
      await _tapFilledButton(tester, 'Połącz konto');
      await tester.pumpAndSettle();

      expect(find.text('Witaj, Test Trainee'), findsOneWidget);
      expect(find.text('Trener: trainer-1'), findsOneWidget);
      expect(seenPaths, ['/auth/register', '/trainee/trainer-link']);
    });

    testWidgets('shows API error without exposing password or registration code',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            return http.Response('{"message":"Invitation code is invalid."}', 400);
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Trener');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainer',
        email: 'trainer@example.test',
        password: 'SuperSecret123!',
        invitationCode: 'secret-invite',
      );
      await _tapFilledButton(tester, 'Kontynuuj');
      await tester.pumpAndSettle();

      expect(find.text('Invitation code is invalid.'), findsOneWidget);
      expect(_textContaining('SuperSecret123'), findsNothing);
      expect(_textContaining('secret-invite'), findsNothing);
    });
  });
}

Future<void> _openSignup(
  WidgetTester tester, {
  required String roleLabel,
}) async {
  await tester.tap(find.text('Załóż konto'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(roleLabel));
  await tester.pumpAndSettle();
  await _tapFilledButton(tester, 'Dalej');
}

Future<void> _fillSignupForm(
  WidgetTester tester, {
  required String displayName,
  required String email,
  String password = 'Password123!',
  String invitationCode = 'invite-123',
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Imię i nazwisko'), displayName);
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Hasło'), password);
  await tester.enterText(find.widgetWithText(TextFormField, 'Kod rejestracji'), invitationCode);
}

Future<void> _tapFilledButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _textContaining(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(value) ?? false),
  );
}

Widget _testApp({
  required http.Client httpClient,
}) {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: httpClient,
  );

  return MaterialApp(
    home: AuthScreen(
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: _InMemoryTokenStore(),
      ),
    ),
  );
}

Map<String, Object?> _authResponse({required String role}) {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-02T12:00:00Z',
    'user': _userResponse(role: role),
  };
}

Map<String, Object?> _userResponse({
  required String role,
  String? trainerUserId,
}) {
  return {
    'id': 'user-1',
    'email': '$role@example.test',
    'role': role,
    'displayName': role == 'trainer' ? 'Test Trainer' : 'Test Trainee',
    'trainerUserId': trainerUserId,
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
