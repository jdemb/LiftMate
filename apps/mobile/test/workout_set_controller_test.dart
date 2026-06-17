import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_controller.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/auth/token_store.dart';
import 'package:liftmate/relationships/relationship_models.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_controller.dart';
import 'package:liftmate/workout_sets/workout_set_models.dart';

void main() {
  group('WorkoutSetController', () {
    test('loads trainer sets with assignable trainees and saves selected detail', () async {
      final seen = <String>[];
      final httpClient = MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.url.path == '/auth/me') {
          return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
        }
        if (request.url.path == '/workout-sets' && request.method == 'GET') {
          return http.Response(jsonEncode([_summaryJson()]), 200);
        }
        if (request.url.path == '/workout-sets' && request.method == 'POST') {
          return http.Response(jsonEncode(_detailJson(name: 'Push A')), 201);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final authController = await _authController(httpClient);
      final controller = _controller(authController, httpClient);

      await controller.loadForUser(
        authController.state.user!,
        trainerSummary: const TrainerRelationshipSummary(
          inviteCode: '7F2K9D',
          trainees: [
            TrainerTraineeSummary(
              id: 'trainee-1',
              email: 'trainee@example.test',
              displayName: 'Test Trainee',
            ),
          ],
        ),
      );
      final result = await controller.createSet(_createRequest('Push A'));

      expect(controller.state.status, WorkoutSetControllerStatus.loaded);
      expect(controller.state.trainerSets.single.id, 'set-1');
      expect(controller.state.assignableTrainees.single.id, 'trainee-1');
      expect(result.status, WorkoutSetApiStatus.success);
      expect(controller.state.selectedSet?.name, 'Push A');
      expect(seen, ['GET /auth/me', 'GET /workout-sets', 'POST /workout-sets']);
    });

    test('loads trainee assigned sets', () async {
      final httpClient = MockClient((request) async {
        if (request.url.path == '/auth/me') {
          return http.Response(
            jsonEncode(_userResponse(role: 'trainee', trainerUserId: 'trainer-1')),
            200,
          );
        }
        if (request.url.path == '/trainee/workout-sets') {
          return http.Response(jsonEncode([_traineeAssignedJson()]), 200);
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final authController = await _authController(httpClient);
      final controller = _controller(authController, httpClient);

      await controller.loadForUser(authController.state.user!);

      expect(controller.state.status, WorkoutSetControllerStatus.loaded);
      expect(controller.state.traineeAssignedSets.single.id, 'set-1');
      expect(controller.state.traineeAssignedSets.single.rows.single.exerciseName, 'Bench press');
    });

    test('syncAssignments can unassign all trainees without empty assign request', () async {
      final seen = <String>[];
      var detailGets = 0;
      final httpClient = MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        if (request.url.path == '/auth/me') {
          return http.Response(jsonEncode(_userResponse(role: 'trainer')), 200);
        }
        if (request.url.path == '/workout-sets/set-1' && request.method == 'GET') {
          detailGets += 1;
          return http.Response(
            jsonEncode(_detailJson(
              assignments: detailGets == 1
                  ? [
                      {
                        'traineeUserId': 'trainee-1',
                        'traineeEmail': 'trainee@example.test',
                        'traineeDisplayName': 'Test Trainee',
                        'assignedAt': '2026-06-16T12:10:00Z',
                      },
                    ]
                  : [],
            )),
            200,
          );
        }
        if (request.url.path == '/workout-sets/set-1/assignments/trainee-1') {
          return http.Response('', 204);
        }
        if (request.url.path == '/workout-sets/set-1/assignments') {
          fail('Assign should not be called with an empty trainee list');
        }

        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final authController = await _authController(httpClient);
      final controller = _controller(authController, httpClient);

      await controller.loadTrainerDetail('set-1');
      final result = await controller.syncAssignments('set-1', const []);

      expect(result.status, WorkoutSetApiStatus.success);
      expect(controller.state.selectedSet?.assignments, isEmpty);
      expect(seen, [
        'GET /auth/me',
        'GET /workout-sets/set-1',
        'DELETE /workout-sets/set-1/assignments/trainee-1',
        'GET /workout-sets/set-1',
      ]);
    });

    test('missing token returns authentication error without HTTP request', () async {
      final authController = AuthController(
        authApiClient: AuthApiClient(
          baseUrl: 'https://api.example.test',
          httpClient: MockClient((request) async {
            fail('HTTP should not be called without token');
          }),
        ),
        tokenStore: _InMemoryTokenStore(),
      );
      final controller = _controller(
        authController,
        MockClient((request) async {
          fail('Workout set HTTP should not be called without token');
        }),
      );

      await controller.loadForUser(_user(role: UserRole.trainer));

      expect(controller.state.status, WorkoutSetControllerStatus.error);
      expect(controller.state.message, contains('not authenticated'));
    });
  });
}

Future<AuthController> _authController(http.Client httpClient) async {
  final controller = AuthController(
    authApiClient: AuthApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: httpClient,
    ),
    tokenStore: _InMemoryTokenStore(
      StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2030),
      ),
    ),
  );

  await controller.initialize();
  return controller;
}

WorkoutSetController _controller(AuthController authController, http.Client httpClient) {
  return WorkoutSetController(
    workoutSetApiClient: WorkoutSetApiClient(
      baseUrl: 'https://api.example.test',
      httpClient: httpClient,
    ),
    authController: authController,
  );
}

AuthUser _user({required UserRole role}) {
  return AuthUser(
    id: '${role.wireName}-1',
    email: '${role.wireName}@example.test',
    role: role,
    displayName: role == UserRole.trainer ? 'Test Trainer' : 'Test Trainee',
  );
}

CreateWorkoutSetRequest _createRequest(String name) {
  return CreateWorkoutSetRequest(
    name: name,
    rows: const [
      WorkoutSetRowRequest(
        exerciseOrder: 1,
        setIndex: 1,
        exerciseName: 'Bench press',
        exerciseType: ExerciseValueType.repsWeight,
        reps: 6,
        weight: 40,
      ),
    ],
  );
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

Map<String, Object?> _summaryJson() {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'exerciseCount': 1,
    'rowCount': 1,
    'assignedTrainees': 0,
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

Map<String, Object?> _detailJson({
  String name = 'Push A',
  List<Map<String, Object?>>? assignments,
}) {
  return {
    'id': 'set-1',
    'name': name,
    'rows': [_rowJson()],
    'assignments': assignments ?? [],
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

Map<String, Object?> _traineeAssignedJson() {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'trainerDisplayName': 'Test Trainer',
    'rows': [_rowJson()],
    'assignedAt': '2026-06-16T12:10:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

Map<String, Object?> _rowJson() {
  return {
    'id': 'row-1',
    'exerciseOrder': 1,
    'setIndex': 1,
    'exerciseName': 'Bench press',
    'exerciseType': 'repsWeight',
    'reps': 6,
    'weight': 40.0,
    'seconds': null,
  };
}

class _InMemoryTokenStore implements TokenStore {
  _InMemoryTokenStore([this._tokens]);

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
