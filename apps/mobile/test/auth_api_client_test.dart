import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_models.dart';

void main() {
  group('AuthApiClient', () {
    test('uses a 30 second default timeout for Azure cold starts', () {
      final client = AuthApiClient(baseUrl: 'https://api.example.test');

      expect(client.timeout, const Duration(seconds: 30));
    });

    test('register posts design signup fields and parses auth session', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/auth/register');
          expect(request.headers['Content-Type'], contains('application/json'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'email': 'trainer@example.test',
            'password': 'Password123!',
            'role': 'trainer',
            'displayName': 'Test Trainer',
            'registrationInviteCode': '  Beta-Code  ',
          });

          return http.Response(
            jsonEncode(_authResponse(role: 'trainer')),
            201,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );

      final result = await client.register(
        email: 'trainer@example.test',
        password: 'Password123!',
        role: UserRole.trainer,
        displayName: 'Test Trainer',
        registrationInviteCode: '  Beta-Code  ',
      );

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.accessToken, 'access-token');
      expect(result.data?.refreshToken, 'refresh-token');
      expect(result.data?.user.role, UserRole.trainer);
      expect(result.data?.user.displayName, 'Test Trainer');
      expect(result.data?.user.trainerUserId, isNull);
    });

    test('trainer invite code request sends bearer token and parses code', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/trainer/invite-code');
          expect(request.headers['Authorization'], 'Bearer access-token');

          return http.Response('{"code":"7F2K9D"}', 200);
        }),
      );

      final result = await client.generateTrainerInviteCode(
        accessToken: 'access-token',
      );

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.code, '7F2K9D');
    });

    test('claim trainer invite code normalizes input and parses linked user', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/trainee/trainer-link');
          expect(request.headers['Authorization'], 'Bearer access-token');
          expect(jsonDecode(request.body), {'code': '7F2K9D'});

          return http.Response(
            jsonEncode({
              'id': 'trainee-1',
              'email': 'trainee@example.test',
              'role': 'trainee',
              'displayName': 'Test Trainee',
              'trainerUserId': 'trainer-1',
            }),
            200,
          );
        }),
      );

      final result = await client.claimTrainerInviteCode(
        accessToken: 'access-token',
        code: '  7f2k9d  ',
      );

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.trainerUserId, 'trainer-1');
      expect(result.data?.displayName, 'Test Trainee');
    });

    test('login posts credentials and parses trainee session', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/auth/login');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {
            'email': 'trainee@example.test',
            'password': 'Password123!',
          });

          return http.Response(jsonEncode(_authResponse(role: 'trainee')), 200);
        }),
      );

      final result = await client.login(
        email: 'trainee@example.test',
        password: 'Password123!',
      );

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.user.role, UserRole.trainee);
    });

    test('login retries once after a timeout and returns the successful response', () async {
      var attempts = 0;
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        timeout: const Duration(milliseconds: 1),
        retryDelay: Duration.zero,
        httpClient: MockClient((request) async {
          attempts += 1;
          if (attempts == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }

          return http.Response(jsonEncode(_authResponse(role: 'trainee')), 200);
        }),
      );

      final result = await client.login(
        email: 'trainee@example.test',
        password: 'Password123!',
      );

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.user.role, UserRole.trainee);
      expect(attempts, 2);
    });

    test('refresh posts refresh token and parses replacement session', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/auth/refresh');
          expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});

          return http.Response(jsonEncode(_authResponse()), 200);
        }),
      );

      final result = await client.refresh(refreshToken: 'old-refresh');

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.refreshToken, 'refresh-token');
    });

    test('me sends bearer token and parses current user', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.example.test/auth/me');
          expect(request.headers['Authorization'], 'Bearer access-token');

          return http.Response(
            jsonEncode({
              'id': 'user-1',
              'email': 'trainer@example.test',
              'role': 'trainer',
              'displayName': 'Test Trainer',
              'trainerUserId': null,
            }),
            200,
          );
        }),
      );

      final result = await client.me(accessToken: 'access-token');

      expect(result.status, AuthApiStatus.success);
      expect(result.data?.email, 'trainer@example.test');
      expect(result.data?.role, UserRole.trainer);
    });

    test('role probes send bearer token and parse role payloads', () async {
      final seen = <String>[];
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer access-token');
          seen.add(request.url.path);

          final role = request.url.path.contains('trainer') ? 'trainer' : 'trainee';
          return http.Response(jsonEncode({'role': role}), 200);
        }),
      );

      final trainer = await client.trainerProbe(accessToken: 'access-token');
      final trainee = await client.traineeProbe(accessToken: 'access-token');

      expect(seen, ['/trainer/probe', '/trainee/probe']);
      expect(trainer.data?.role, UserRole.trainer);
      expect(trainee.data?.role, UserRole.trainee);
    });

    test('logout sends bearer token and refresh token body', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.example.test/auth/logout');
          expect(request.headers['Authorization'], 'Bearer access-token');
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});

          return http.Response('', 204);
        }),
      );

      final result = await client.logout(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

      expect(result.status, AuthApiStatus.success);
    });

    test('classifies non-success HTTP status without exposing request secrets', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('{"error":"Kod beta jest niepoprawny."}', 400);
        }),
      );

      final result = await client.register(
        email: 'trainer@example.test',
        password: 'Password123!',
        role: UserRole.trainer,
        displayName: 'Test Trainer',
        registrationInviteCode: 'Beta-Code',
      );

      expect(result.status, AuthApiStatus.badRequest);
      expect(result.statusCode, 400);
      expect(result.message, 'Kod beta jest niepoprawny.');
      expect(result.message, isNot(contains('Password123')));
      expect(result.message, isNot(contains('Beta-Code')));
    });

    test('preserves friendly registration unavailable message for 503', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'error':
                    'Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później.',
              }),
            ),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await client.register(
        email: 'trainer@example.test',
        password: 'Password123!',
        role: UserRole.trainer,
        displayName: 'Test Trainer',
        registrationInviteCode: 'Beta-Code',
      );

      expect(result.status, AuthApiStatus.error);
      expect(
        result.message,
        'Rejestracja jest chwilowo niedostępna. Spróbuj ponownie później.',
      );
      expect(result.statusCode, 503);
    });

    test('returns error for invalid JSON response', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('not json', 200);
        }),
      );

      final result = await client.login(
        email: 'trainer@example.test',
        password: 'Password123!',
      );

      expect(result.status, AuthApiStatus.error);
      expect(
        result.message,
        'Nie udało się odczytać odpowiedzi serwera. Spróbuj ponownie.',
      );
    });

    test('returns error when API base URL is not configured', () async {
      final client = AuthApiClient(
        baseUrl: '',
        httpClient: MockClient((request) async {
          fail('HTTP client should not be called without a base URL');
        }),
      );

      final result = await client.login(
        email: 'trainer@example.test',
        password: 'Password123!',
      );

      expect(result.status, AuthApiStatus.error);
      expect(
        result.message,
        'Połączenie z usługą jest chwilowo niedostępne. Spróbuj ponownie.',
      );
    });

    test('replaces client exception details with friendly offline message', () async {
      final client = AuthApiClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          throw http.ClientException(
            'SocketException: secret-host.internal registrationInviteCode=Beta-Code',
          );
        }),
      );

      final result = await client.register(
        email: 'trainer@example.test',
        password: 'Password123!',
        role: UserRole.trainer,
        displayName: 'Test Trainer',
        registrationInviteCode: 'Beta-Code',
      );

      expect(result.status, AuthApiStatus.offline);
      expect(
        result.message,
        'Brak połączenia z serwerem. Sprawdź internet i spróbuj ponownie.',
      );
      expect(result.message, isNot(contains('secret-host')));
      expect(result.message, isNot(contains('Beta-Code')));
    });
  });
}

Map<String, Object?> _authResponse({String role = 'trainer'}) {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-02T12:00:00Z',
      'user': {
        'id': 'user-1',
        'email': '$role@example.test',
        'role': role,
        'displayName': role == 'trainer' ? 'Test Trainer' : 'Test Trainee',
        'trainerUserId': role == 'trainee' ? 'trainer-1' : null,
      },
    };
  }
