import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/relationships/relationship_api_client.dart';
import 'package:liftmate/relationships/relationship_controller.dart';

void main() {
  group('RelationshipController', () {
    test('loads trainer relationship summary', () async {
      final seenPaths = <String>[];
      final httpClient = MockClient((request) async {
          seenPaths.add(request.url.path);
          if (request.url.path == '/auth/login') {
            return http.Response(jsonEncode(_authResponse(role: 'trainer')), 200);
          }
          if (request.url.path == '/trainer/relationship') {
            expect(request.headers['Authorization'], 'Bearer access-token');
            return http.Response(
              jsonEncode({
                'inviteCode': '7F2K9D',
                'trainees': [
                  {
                    'id': 'trainee-1',
                    'email': 'trainee@example.test',
                    'displayName': 'Test Trainee',
                  },
                ],
              }),
              200,
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        });
      final authController = _authController(httpClient: httpClient);
      await authController.login(
        email: 'trainer@example.test',
        password: 'Password123!',
      );
      final controller = _relationshipController(authController, httpClient);

      await controller.loadForUser(authController.state.user!);

      expect(controller.state.status, RelationshipControllerStatus.loaded);
      expect(controller.state.trainerSummary?.inviteCode, '7F2K9D');
      expect(controller.state.trainerSummary?.trainees.single.id, 'trainee-1');
      expect(seenPaths, ['/auth/login', '/trainer/relationship']);
    });

    test('loads trainee linked and unlinked relationship summaries', () async {
      var linked = false;
      final httpClient = MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(jsonEncode(_authResponse(role: 'trainee')), 200);
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response(
              jsonEncode({
                'trainer': linked
                    ? {
                        'id': 'trainer-1',
                        'email': 'trainer@example.test',
                        'displayName': 'Test Trainer',
                      }
                    : null,
              }),
              200,
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        });
      final authController = _authController(httpClient: httpClient);
      await authController.login(
        email: 'trainee@example.test',
        password: 'Password123!',
      );
      final controller = _relationshipController(authController, httpClient);

      await controller.loadForUser(authController.state.user!);
      expect(controller.state.traineeSummary?.trainer, isNull);

      linked = true;
      await controller.reload();
      expect(controller.state.traineeSummary?.trainer?.id, 'trainer-1');
    });

    test('claim success uses auth controller mutation and reloads trainee relationship', () async {
      var claimed = false;
      final seenPaths = <String>[];
      final httpClient = MockClient((request) async {
          seenPaths.add(request.url.path);
          if (request.url.path == '/auth/login') {
            return http.Response(jsonEncode(_authResponse(role: 'trainee')), 200);
          }
          if (request.url.path == '/trainee/trainer-link') {
            expect(jsonDecode(request.body), {'code': '7F2K9D'});
            claimed = true;
            return http.Response(
              jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
              200,
            );
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response(
              jsonEncode({
                'trainer': claimed
                    ? {
                        'id': 'trainer-1',
                        'email': 'trainer@example.test',
                        'displayName': 'Test Trainer',
                      }
                    : null,
              }),
              200,
            );
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        });
      final authController = _authController(httpClient: httpClient);
      await authController.login(
        email: 'trainee@example.test',
        password: 'Password123!',
      );
      final controller = _relationshipController(authController, httpClient);
      await controller.loadForUser(authController.state.user!);

      final result = await controller.claimTrainerCode('  7f2k9d  ');

      expect(result.status, AuthApiStatus.success);
      expect(authController.state.user?.trainerUserId, 'trainer-1');
      expect(controller.state.status, RelationshipControllerStatus.loaded);
      expect(controller.state.traineeSummary?.trainer?.id, 'trainer-1');
      expect(seenPaths, [
        '/auth/login',
        '/trainee/relationship',
        '/trainee/trainer-link',
        '/trainee/relationship',
      ]);
    });

    test('claim failure preserves current trainee relationship state', () async {
      final httpClient = MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode(_authResponse(role: 'trainee', trainerUserId: 'trainer-a')),
              200,
            );
          }
          if (request.url.path == '/trainee/relationship') {
            return http.Response(
              jsonEncode({
                'trainer': {
                  'id': 'trainer-a',
                  'email': 'trainer-a@example.test',
                  'displayName': 'Trainer A',
                },
              }),
              200,
            );
          }
          if (request.url.path == '/trainee/trainer-link') {
            return http.Response('{"error":"Trainer invite code was not found."}', 404);
          }

          fail('Unexpected request: ${request.method} ${request.url}');
        });
      final authController = _authController(httpClient: httpClient);
      await authController.login(
        email: 'trainee@example.test',
        password: 'Password123!',
      );
      final controller = _relationshipController(authController, httpClient);
      await controller.loadForUser(authController.state.user!);

      final result = await controller.claimTrainerCode('AAAAAA');

      expect(result.status, AuthApiStatus.error);
      expect(controller.state.status, RelationshipControllerStatus.error);
      expect(controller.state.message, contains('Trainer invite code was not found'));
      expect(controller.state.traineeSummary?.trainer?.id, 'trainer-a');
    });

    test('missing token surfaces authentication error', () async {
      final httpClient = MockClient((request) async {
          fail('HTTP should not be called when token is missing');
        });
      final authController = _authController(httpClient: httpClient);
      final controller = _relationshipController(authController, httpClient);

      await controller.loadForUser(_user(role: UserRole.trainee));

      expect(controller.state.status, RelationshipControllerStatus.error);
      expect(controller.state.message, contains('not authenticated'));
    });
  });
}

AuthController _authController({required http.Client httpClient}) {
  return AuthController(
    authApiClient: AuthApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: httpClient,
    ),
    tokenStore: _InMemoryTokenStore(),
  );
}

RelationshipController _relationshipController(
  AuthController authController,
  http.Client httpClient,
) {
  return RelationshipController(
    relationshipApiClient: RelationshipApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: httpClient,
    ),
    authController: authController,
  );
}

Map<String, Object?> _authResponse({
  required String role,
  String? trainerUserId,
}) {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAt': '2026-06-02T12:00:00Z',
    'user': _userResponse(role: role, trainerUserId: trainerUserId),
  };
}

Map<String, Object?> _userResponse({
  required String role,
  String? trainerUserId,
}) {
  return {
    'id': '$role-1',
    'email': '$role@example.test',
    'role': role,
    'displayName': role == 'trainer' ? 'Test Trainer' : 'Test Trainee',
    'trainerUserId': trainerUserId,
  };
}

AuthUser _user({required UserRole role}) {
  return AuthUser(
    id: '${role.wireName}-1',
    email: '${role.wireName}@example.test',
    role: role,
    displayName: role == UserRole.trainer ? 'Test Trainer' : 'Test Trainee',
  );
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
