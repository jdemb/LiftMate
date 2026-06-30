import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_screen.dart';
import 'package:liftmate/auth/onboarding_state_store.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows design welcome screen without technical diagnostics', (
      tester,
    ) async {
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
        find.text(
          'Trener ustawia plan, Ty widzisz co robić, ile podnieść i kiedy poprawiasz wynik.',
        ),
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

    testWidgets('role selection uses design cards and opens trainee signup', (
      tester,
    ) async {
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
      expect(find.text('Kod beta'), findsOneWidget);
      expect(find.text('Kod rejestracji'), findsNothing);
      expect(find.text('Kod trenera'), findsNothing);
    });

    testWidgets(
      'password visibility toggles independently in login and signup',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              fail('No auth request should be sent');
            }),
          ),
        );
        await tester.pumpAndSettle();

        await _tapButton(tester, 'Mam już konto');
        expect(_passwordObscured(tester), isTrue);

        await tester.tap(find.byKey(const ValueKey('toggle-password-login')));
        await tester.pump();
        expect(_passwordObscured(tester), isFalse);
        expect(find.text('Ukryj'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        await _openSignup(tester, roleLabel: 'Jestem podopiecznym');

        expect(_passwordObscured(tester), isTrue);

        await tester.tap(find.byKey(const ValueKey('toggle-password-signup')));
        await tester.pump();
        expect(_passwordObscured(tester), isFalse);
      },
    );

    testWidgets('signup requires beta code before sending request', (
      tester,
    ) async {
      var requestCount = 0;
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            requestCount += 1;
            return http.Response('{}', 500);
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem trenerem');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainer',
        email: 'trainer@example.test',
        betaCode: null,
      );
      await _tapButton(tester, 'Utwórz konto');

      expect(find.text('To pole jest wymagane.'), findsOneWidget);
      expect(requestCount, 0);
    });

    testWidgets('logs in and logs out from temporary user panel', (
      tester,
    ) async {
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
              return http.Response(
                jsonEncode(_authResponse(role: 'trainer')),
                200,
              );
            }
            if (request.url.path == '/trainer/relationship') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              return http.Response(
                '{"inviteCode":"7F2K9D","trainees":[]}',
                200,
              );
            }
            if (request.url.path == '/auth/logout') {
              expect(request.headers['Authorization'], 'Bearer access-token');
              expect(jsonDecode(request.body), {
                'refreshToken': 'refresh-token',
              });
              return http.Response('', 204);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Mam już konto');
      await tester.enterText(
        find.byKey(const ValueKey('field-E-mail')),
        'trainer@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('field-Hasło')),
        'Password123!',
      );
      await _tapButton(tester, 'Zaloguj');

      expect(find.text('Cześć,'), findsOneWidget);
      expect(find.text('Test Trainer'), findsOneWidget);
      expect(find.text('Twój kod zaproszenia'), findsOneWidget);
      expect(find.text('Zaproś podopiecznego'), findsOneWidget);
      expect(find.text('Tymczasowy panel'), findsNothing);
      expect(_radialGradientDecoratedBox(), findsNothing);

      await _tapButton(tester, 'Wyloguj');

      expect(find.text('Załóż konto'), findsOneWidget);
      expect(seenPaths, [
        '/auth/login',
        '/trainer/relationship',
        '/auth/logout',
      ]);
    });

    testWidgets(
      'trainee signup opens trainer-code pairing without access-code gate',
      (tester) async {
        final seenPaths = <String>[];
        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              seenPaths.add(request.url.path);
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pumpAndSettle();

        await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainee',
          email: 'trainee@example.test',
        );

        expect(find.text('Kod beta'), findsOneWidget);
        expect(find.text('Kod rejestracji'), findsNothing);
        expect(find.text('Kod trenera'), findsNothing);

        await _tapButton(tester, 'Utwórz konto');

        expect(find.text('Połącz się\nz trenerem'), findsOneWidget);
        expect(find.text('Kod dostępu'), findsNothing);
        expect(find.text('Kod trenera'), findsNothing);
        expect(find.byKey(const ValueKey('field-Kod trenera')), findsOneWidget);
        expect(find.text('Kod rejestracji'), findsNothing);
        expect(seenPaths, isEmpty);
      },
    );

    testWidgets(
      'trainer signup displays generated invite code on separate design screen',
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
                  'registrationInviteCode': '  Beta-Code  ',
                });
                return http.Response(
                  jsonEncode(_authResponse(role: 'trainer')),
                  201,
                );
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
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainer',
          email: 'trainer@example.test',
        );
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
      },
    );

    testWidgets(
      'trainer copies the exact generated invite code and sees confirmation',
      (tester) async {
        MethodCall? clipboardCall;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCall = call;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/register') {
                return http.Response(
                  jsonEncode(_authResponse(role: 'trainer')),
                  201,
                );
              }
              if (request.url.path == '/trainer/invite-code') {
                return http.Response('{"code":"7F2K9D"}', 200);
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pumpAndSettle();
        await _openSignup(tester, roleLabel: 'Jestem trenerem');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainer',
          email: 'trainer@example.test',
        );
        await _tapButton(tester, 'Utwórz konto');

        await tester.tap(
          find.byKey(const ValueKey('copy-trainer-invite-code-onboarding')),
        );
        await tester.pump();

        expect(clipboardCall?.method, 'Clipboard.setData');
        expect(clipboardCall?.arguments, {'text': '7F2K9D'});
        expect(find.text('Kod zaproszenia skopiowany.'), findsOneWidget);
      },
    );

    testWidgets(
      'trainer cannot copy an invite-code placeholder while loading',
      (tester) async {
        final inviteCodeCompleter = Completer<http.Response>();
        var clipboardCalls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                clipboardCalls += 1;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/register') {
                return http.Response(
                  jsonEncode(_authResponse(role: 'trainer')),
                  201,
                );
              }
              if (request.url.path == '/trainer/invite-code') {
                return inviteCodeCompleter.future;
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pumpAndSettle();
        await _openSignup(tester, roleLabel: 'Jestem trenerem');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainer',
          email: 'trainer@example.test',
        );

        await tester.tap(find.text('Utwórz konto'));
        await tester.pump();
        await tester.pump();

        final copyButton = find.byKey(
          const ValueKey('copy-trainer-invite-code-onboarding'),
        );
        expect(copyButton, findsOneWidget);
        expect(tester.widget<TextButton>(copyButton).onPressed, isNull);

        await tester.tap(copyButton);
        await tester.pump();
        expect(clipboardCalls, 0);

        inviteCodeCompleter.complete(http.Response('{"code":"7F2K9D"}', 200));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('trainer sees an error when copying the invite code fails', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'clipboard-unavailable');
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/register') {
              return http.Response(
                jsonEncode(_authResponse(role: 'trainer')),
                201,
              );
            }
            if (request.url.path == '/trainer/invite-code') {
              return http.Response('{"code":"7F2K9D"}', 200);
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();
      await _openSignup(tester, roleLabel: 'Jestem trenerem');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainer',
        email: 'trainer@example.test',
      );
      await _tapButton(tester, 'Utwórz konto');

      await tester.tap(
        find.byKey(const ValueKey('copy-trainer-invite-code-onboarding')),
      );
      await tester.pump();

      expect(find.text('Nie udało się skopiować kodu.'), findsOneWidget);
      expect(find.text('Kod zaproszenia skopiowany.'), findsNothing);
    });

    testWidgets('trainee signup claims trainer invite code before continuing', (
      tester,
    ) async {
      final seenPaths = <String>[];
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            seenPaths.add(request.url.path);

            if (request.url.path == '/auth/register/trainee') {
              expect(jsonDecode(request.body), {
                'email': 'trainee@example.test',
                'password': 'Password123!',
                'displayName': 'Test Trainee',
                'registrationInviteCode': '  Beta-Code  ',
                'trainerInviteCode': '7F2K9D',
              });
              return http.Response(
                jsonEncode(_authResponse(role: 'trainee')),
                201,
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
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainee',
        email: 'trainee@example.test',
      );
      await _tapButton(tester, 'Utwórz konto');

      await tester.enterText(
        find.byKey(const ValueKey('field-Kod trenera')),
        '  7f2k9d  ',
      );
      await _tapButton(tester, 'Połącz konto');

      expect(find.text('Cześć,'), findsOneWidget);
      expect(find.text('Test Trainee'), findsOneWidget);
      expect(find.text('TWÓJ TRENER'), findsOneWidget);
      expect(find.text('Test Trainer'), findsOneWidget);
      expect(seenPaths, [
        '/auth/register/trainee',
        '/trainee/relationship',
        '/trainee/workout-sets',
      ]);
    });

    testWidgets(
      'trainer code paste filters, uppercases, limits and submits once',
      (tester) async {
        final registerCompleter = Completer<http.Response>();
        var registerCount = 0;
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              if (request.url.path == '/auth/register/trainee') {
                registerCount += 1;
                expect(jsonDecode(request.body), {
                  'email': 'trainee@example.test',
                  'password': 'Password123!',
                  'displayName': 'Test Trainee',
                  'registrationInviteCode': '  Beta-Code  ',
                  'trainerInviteCode': '7F2K9D',
                });
                return registerCompleter.future;
              }
              if (request.url.path == '/trainee/relationship') {
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
                return http.Response('[]', 200);
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pumpAndSettle();

        await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainee',
          email: 'trainee@example.test',
        );
        await _tapButton(tester, 'Utwórz konto');

        final codeField = find.byKey(const ValueKey('field-Kod trenera'));
        expect(
          find.ancestor(
            of: codeField,
            matching: find.byKey(
              const ValueKey('trainer-code-input-editor-opacity'),
            ),
          ),
          findsOneWidget,
        );
        await tester.enterText(codeField, '  7f-2k9dXYZ  ');
        await tester.pump();

        expect(
          tester.widget<TextFormField>(codeField).controller?.text,
          '7F2K9D',
        );
        expect(find.text('Znaleziono kod trenera'), findsNothing);
        expect(tester.takeException(), isNull);

        final connect = find.text('Połącz konto');
        await tester.ensureVisible(connect);
        await tester.tap(connect);
        await tester.tap(connect);
        await tester.pump();
        expect(registerCount, 1);

        registerCompleter.complete(
          http.Response(jsonEncode(_authResponse(role: 'trainee')), 201),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'trainee pairing back button returns to signup before account creation',
      (tester) async {
        final seenPaths = <String>[];
        await tester.pumpWidget(
          _testApp(
            httpClient: MockClient((request) async {
              seenPaths.add(request.url.path);
              if (request.url.path == '/auth/register') {
                return http.Response(
                  jsonEncode(_authResponse(role: 'trainee')),
                  201,
                );
              }
              fail('Unexpected request: ${request.method} ${request.url}');
            }),
          ),
        );
        await tester.pumpAndSettle();

        await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainee',
          email: 'trainee@example.test',
        );
        await _tapButton(tester, 'Utwórz konto');

        expect(find.text('Połącz się\nz trenerem'), findsOneWidget);
        expect(find.text('Cześć,'), findsNothing);
        expect(seenPaths, isEmpty);

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();

        expect(find.text('Załóż konto'), findsOneWidget);
        expect(find.text('Test Trainee'), findsOneWidget);
        expect(find.text('Połącz się\nz trenerem'), findsNothing);
        expect(seenPaths, isEmpty);
      },
    );

    testWidgets(
      'pending trainee pairing before account creation is not persisted',
      (tester) async {
        final tokenStore = _InMemoryTokenStore();
        final onboardingStore = _InMemoryOnboardingStateStore();
        final seenPaths = <String>[];
        final httpClient = MockClient((request) async {
          seenPaths.add(request.url.path);
          fail('Unexpected request: ${request.method} ${request.url}');
        });

        await tester.pumpWidget(
          _testApp(
            httpClient: httpClient,
            tokenStore: tokenStore,
            onboardingStateStore: onboardingStore,
          ),
        );
        await tester.pumpAndSettle();
        await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
        await _fillSignupForm(
          tester,
          displayName: 'Test Trainee',
          email: 'trainee@example.test',
        );
        await _tapButton(tester, 'Utwórz konto');
        expect(await onboardingStore.readPendingTraineeUserId(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          _testApp(
            httpClient: httpClient,
            tokenStore: tokenStore,
            onboardingStateStore: onboardingStore,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Załóż konto'), findsOneWidget);
        expect(find.text('Połącz się\nz trenerem'), findsNothing);
        expect(find.text('Cześć,'), findsNothing);
        expect(seenPaths, isEmpty);
      },
    );

    testWidgets('failed trainer code is shown as friendly Polish message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/register/trainee') {
              return http.Response.bytes(
                utf8.encode(
                  jsonEncode({
                    'error':
                        'Nie znaleziono trenera dla podanego kodu. Sprawdź kod i spróbuj ponownie.',
                  }),
                ),
                404,
                headers: const {
                  'content-type': 'application/json; charset=utf-8',
                },
              );
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem podopiecznym');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainee',
        email: 'trainee@example.test',
      );
      await _tapButton(tester, 'Utwórz konto');
      await tester.enterText(
        find.byKey(const ValueKey('field-Kod trenera')),
        '7F2K9D',
      );
      await _tapButton(tester, 'Połącz konto');

      expect(
        find.text(
          'Nie znaleziono trenera dla podanego kodu. Sprawdź kod i spróbuj ponownie.',
        ),
        findsOneWidget,
      );
      expect(find.text('Trainer invite code was not found.'), findsNothing);
      expect(find.text('Połącz się\nz trenerem'), findsOneWidget);
    });

    testWidgets('registration submit is single flight', (tester) async {
      final registerCompleter = Completer<http.Response>();
      var registerCount = 0;
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/register') {
              registerCount += 1;
              return registerCompleter.future;
            }
            if (request.url.path == '/trainer/invite-code') {
              return http.Response('{"code":"7F2K9D"}', 200);
            }
            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        ),
      );
      await tester.pumpAndSettle();

      await _openSignup(tester, roleLabel: 'Jestem trenerem');
      await _fillSignupForm(
        tester,
        displayName: 'Test Trainer',
        email: 'trainer@example.test',
      );

      final submit = find.text('Utwórz konto');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(registerCount, 1);

      registerCompleter.complete(
        http.Response(jsonEncode(_authResponse(role: 'trainer')), 201),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('shows API error without exposing password', (tester) async {
      await tester.pumpWidget(
        _testApp(
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'Kod beta jest niepoprawny.'}),
              400,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
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

      expect(find.text('Kod beta jest niepoprawny.'), findsOneWidget);
      expect(_textContaining('SuperSecret123'), findsNothing);
      expect(_textContaining('Beta-Code'), findsNothing);
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
  String? betaCode = '  Beta-Code  ',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('field-Imię i nazwisko')),
    displayName,
  );
  await tester.enterText(find.byKey(const ValueKey('field-E-mail')), email);
  await tester.enterText(find.byKey(const ValueKey('field-Hasło')), password);
  if (betaCode != null) {
    await tester.enterText(
      find.byKey(const ValueKey('field-Kod beta')),
      betaCode,
    );
  }
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

bool _passwordObscured(WidgetTester tester) {
  final field = find.byKey(const ValueKey('field-Hasło'));
  final editableText = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editableText).obscureText;
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
  TokenStore? tokenStore,
  OnboardingStateStore? onboardingStateStore,
}) {
  final authApiClient = AuthApiClient(
    baseUrl: 'https://api.example.test',
    httpClient: httpClient,
  );

  return MaterialApp(
    home: AuthScreen(
      authController: AuthController(
        authApiClient: authApiClient,
        tokenStore: tokenStore ?? _InMemoryTokenStore(),
      ),
      onboardingStateStore:
          onboardingStateStore ?? _InMemoryOnboardingStateStore(),
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
    'expiresAt': '2099-06-02T12:00:00Z',
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

class _InMemoryOnboardingStateStore implements OnboardingStateStore {
  String? _pendingTraineeUserId;

  @override
  Future<void> clearPendingTraineeUserId() async {
    _pendingTraineeUserId = null;
  }

  @override
  Future<String?> readPendingTraineeUserId() async => _pendingTraineeUserId;

  @override
  Future<void> savePendingTraineeUserId(String userId) async {
    _pendingTraineeUserId = userId;
  }
}
