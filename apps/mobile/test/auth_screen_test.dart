import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows design welcome screen without technical diagnostics',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent on empty startup');
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LiftMate'), findsOneWidget);
      expect(_radialGradientDecoratedBox(), findsOneWidget);
      expect(find.text('Trenuj bez myślenia\no liczbach.'), findsOneWidget);
      expect(
        find.text('Trener ustawia plan, Ty widzisz co robić, ile podnieść i kiedy poprawiasz wynik.'),
        findsNothing,
      );
      expect(find.text('Załóż konto'), findsOneWidget);
      expect(find.text('Mam już konto'), findsOneWidget);
      expect(find.text('Kod dostępu'), findsNothing);
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('API diagnostics'), findsNothing);
      expect(find.text('Trainer probe passed'), findsNothing);
      expect(find.text('Shared session diagnostics'), findsNothing);
    });

    testWidgets('role selection uses design cards and opens trainee signup',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            fail('No auth request should be sent before submitting');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Załóż konto');

      expect(find.text('Jak korzystasz\nz LiftMate?'), findsOneWidget);
      expect(find.text('Jestem podopiecznym'), findsOneWidget);
      expect(find.text('Jestem trenerem'), findsOneWidget);

      await tester.tap(find.text('Jestem podopiecznym'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Dalej');

      expect(find.text('Załóż konto'), findsOneWidget);
      expect(find.text('Podopieczny'), findsOneWidget);
      expect(find.text('Imię i nazwisko'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Hasło'), findsOneWidget);
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('Kod trenera'), findsNothing);
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
            if (request.url.path == '/trainer/relationship') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('{"inviteCode":"7F2K9D","trainees":[]}', 200);
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

      await _tapButton(tester, 'Mam już konto');
      await tester.enterText(find.byKey(const ValueKey('field-E-mail')), 'trainer@example.test');
      await tester.enterText(find.byKey(const ValueKey('field-Hasło')), 'Password123!');
      await _tapButton(tester, 'Zaloguj');

      expect(find.text('Cześć,'), findsOneWidget);
      expect(find.text('Test Trainer'), findsOneWidget);
      expect(find.text('Twój kod zaproszenia'), findsOneWidget);
      expect(find.text('Zaproś podopiecznego'), findsOneWidget);
      expect(find.text('Tymczasowy panel'), findsNothing);
      expect(_radialGradientDecoratedBox(), findsNothing);

      await _tapButton(tester, 'Wyloguj');

      expect(find.text('Załóż konto'), findsOneWidget);
      expect(seenPaths, ['/auth/login', '/trainer/relationship', '/auth/logout']);
    });

    testWidgets('trainee signup opens trainer-code pairing without access-code gate',
        (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);
            if (request.url.path == '/auth/register') {
              expect(jsonDecode(request.body), {
                'email': 'trainee@example.test',
                'password': 'Password123!',
                'role': 'trainee',
                'displayName': 'Test Trainee',
              });
              return http.Response(jsonEncode(_authResponse(role: 'trainee')), 201);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
      await _fillSignupForm(tester, displayName: 'Test Trainee', email: 'trainee@example.test');

      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('Kod trenera'), findsNothing);

      await _tapButton(tester, 'Utwórz konto');

      expect(find.text('Połącz się\nz trenerem'), findsOneWidget);
      expect(find.text('Kod dostępu'), findsNothing);
      expect(find.text('Kod trenera'), findsNothing);
      expect(find.byKey(const ValueKey('field-Kod trenera')), findsOneWidget);
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(seenPaths, ['/auth/register']);
    });

    testWidgets('trainer signup displays generated invite code on separate design screen',
        (tester) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/register') {
              expect(jsonDecode(request.body), {
                'email': 'trainer@example.test',
                'password': 'Password123!',
                'role': 'trainer',
                'displayName': 'Test Trainer',
              });
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

      await _openSignup(tester, roleLabel: 'Jestem trenerem');
      await _fillSignupForm(tester, displayName: 'Test Trainer', email: 'trainer@example.test');
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('Twój kod zaproszenia'), findsNothing);

      await _tapButton(tester, 'Utwórz konto');

      expect(find.text('Zaproś\npodopiecznego'), findsOneWidget);
      expect(find.text('Kod dostępu'), findsNothing);
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('Twój kod zaproszenia'), findsOneWidget);
      expect(find.text('7F2K9D'), findsOneWidget);
      expect(find.text('⧉ Kopiuj kod'), findsOneWidget);
      expect(find.text('Przejdź do pulpitu'), findsOneWidget);
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
            if (request.url.path == '/trainee/relationship') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response(
                jsonEncode({
                  'trainer': {
                    'id': 'trainer-1',
                    'email': 'trainer@example.test',
                    'displayName': 'Test Trainer',
                  },
                }),
                200,
              );
            }
            if (request.url.path == '/trainee/workout-sets') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response('[]', 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
      await _fillSignupForm(tester, displayName: 'Test Trainee', email: 'trainee@example.test');
      await _tapButton(tester, 'Utwórz konto');

      await tester.enterText(find.byKey(const ValueKey('field-Kod trenera')), '  7f2k9d  ');
      await _tapButton(tester, 'Połącz konto');

      expect(find.text('Cześć,'), findsOneWidget);
      expect(find.text('Test Trainee'), findsOneWidget);
      expect(find.text('TWÓJ TRENER'), findsOneWidget);
      expect(find.text('Test Trainer'), findsOneWidget);
      expect(seenPaths, [
        '/auth/register',
        '/trainee/trainer-link',
        '/trainee/relationship',
        '/trainee/workout-sets',
      ]);
    });

    testWidgets('shows API error without exposing password',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            return http.Response('{"message":"Registration failed."}', 400);
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem trenerem');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainer',
        email: 'trainer@example.test',
        password: 'SuperSecret123!',
      );
      await _tapButton(tester, 'Utwórz konto');

      expect(find.text('Registration failed.'), findsOneWidget);
      expect(_textContaining('SuperSecret123'), findsNothing);
      expect(find.text('Kod dostępu'), findsNothing);
      expect(find.text('Kod rejestracji'), findsNothing);
    });
  });
}

Future<void> _openSignup(
  WidgetTester tester, {
  required String roleLabel,
}) async {
  await _tapButton(tester, 'Załóż konto');
  await tester.tap(find.text(roleLabel));
  await tester.pumpAndSettle();
  await _tapButton(tester, 'Dalej');
}

Future<void> _fillSignupForm(
  WidgetTester tester, {
  required String displayName,
  required String email,
  String password = 'Password123!',
}) async {
  await tester.enterText(find.byKey(const ValueKey('field-Imię i nazwisko')), displayName);
  await tester.enterText(find.byKey(const ValueKey('field-E-mail')), email);
  await tester.enterText(find.byKey(const ValueKey('field-Hasło')), password);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _textContaining(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(value) ?? false),
  );
}

Finder _radialGradientDecoratedBox() {
  return find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) {
      return false;
    }

    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.gradient is RadialGradient;
  });
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
      relationshipApiClient: RelationshipApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
      ),
      workoutSetApiClient: WorkoutSetApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: httpClient,
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
