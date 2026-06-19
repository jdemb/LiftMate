import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/workout_sets/workout_set_api_client.dart';
import 'package:liftmate/workout_sets/workout_set_models.dart';

void main() {
  group('WorkoutSetApiClient', () {
    test(
      'create, update, assign, and unassign use expected payloads and paths',
      () async {
        final seen = <String>[];
        final client = WorkoutSetApiClient(
          baseUrl: 'https://api.example.test/',
          httpClient: MockClient((request) async {
            seen.add('${request.method} ${request.url.path}');
            expect(request.headers['Authorization'], 'Bearer access-token');

            if (request.url.path == '/workout-sets' &&
                request.method == 'POST') {
              expect(jsonDecode(request.body), _savePayload('Push A'));
              return http.Response(
                jsonEncode(_detailJson(name: 'Push A')),
                201,
              );
            }
            if (request.url.path == '/workout-sets/set-1' &&
                request.method == 'PUT') {
              expect(jsonDecode(request.body), _savePayload('Push B'));
              return http.Response(
                jsonEncode(_detailJson(name: 'Push B')),
                200,
              );
            }
            if (request.url.path == '/workout-sets/set-1/assignments') {
              expect(jsonDecode(request.body), {
                'traineeUserIds': ['trainee-1', 'trainee-2'],
              });
              return http.Response(jsonEncode(_detailJson()), 200);
            }
            if (request.url.path ==
                '/workout-sets/set-1/assignments/trainee-1') {
              return http.Response('', 204);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        );

        await client.create(
          accessToken: 'access-token',
          request: _createRequest('Push A'),
        );
        await client.update(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
          request: UpdateWorkoutSetRequest(
            name: 'Push B',
            rows: _rowsRequest(),
          ),
        );
        await client.assign(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
          request: const AssignWorkoutSetRequest(
            traineeUserIds: ['trainee-1', 'trainee-2'],
          ),
        );
        final unassign = await client.unassign(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
          traineeUserId: 'trainee-1',
        );

        expect(unassign.status, WorkoutSetApiStatus.success);
        expect(seen, [
          'POST /workout-sets',
          'PUT /workout-sets/set-1',
          'POST /workout-sets/set-1/assignments',
          'DELETE /workout-sets/set-1/assignments/trainee-1',
        ]);
      },
    );

    test(
      'list and detail methods parse trainer and trainee responses',
      () async {
        final seen = <String>[];
        final client = WorkoutSetApiClient(
          baseUrl: 'https://api.example.test',
          httpClient: MockClient((request) async {
            seen.add('${request.method} ${request.url.path}');

            if (request.url.path == '/workout-sets') {
              return http.Response(jsonEncode([_summaryJson()]), 200);
            }
            if (request.url.path == '/workout-sets/set-1') {
              return http.Response(jsonEncode(_detailJson()), 200);
            }
            if (request.url.path == '/trainee/workout-sets') {
              return http.Response(jsonEncode([_traineeAssignedJson()]), 200);
            }
            if (request.url.path == '/trainee/workout-sets/set-1') {
              return http.Response(jsonEncode(_traineeAssignedJson()), 200);
            }

            fail('Unexpected request: ${request.method} ${request.url}');
          }),
        );

        final summaries = await client.listTrainerSets(
          accessToken: 'access-token',
        );
        final detail = await client.getTrainerSet(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
        );
        final traineeList = await client.listTraineeSets(
          accessToken: 'access-token',
        );
        final traineeDetail = await client.getTraineeSet(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
        );

        expect(summaries.data?.single.id, 'set-1');
        expect(
          detail.data?.rows.single.exerciseType,
          ExerciseValueType.repsWeight,
        );
        expect(traineeList.data?.single.trainerDisplayName, 'Test Trainer');
        expect(traineeDetail.data?.id, 'set-1');
        expect(seen, [
          'GET /workout-sets',
          'GET /workout-sets/set-1',
          'GET /trainee/workout-sets',
          'GET /trainee/workout-sets/set-1',
        ]);
      },
    );

    test(
      'maps forbidden, conflict, missing base URL, and invalid JSON',
      () async {
        final forbidden = WorkoutSetApiClient(
          baseUrl: 'https://api.example.test',
          httpClient: MockClient((_) async {
            return http.Response('{"error":"Forbidden."}', 403);
          }),
        );
        final conflict = WorkoutSetApiClient(
          baseUrl: 'https://api.example.test',
          httpClient: MockClient((_) async {
            return http.Response('{"error":"Already assigned."}', 409);
          }),
        );
        final missingBaseUrl = WorkoutSetApiClient(
          baseUrl: '',
          httpClient: MockClient((_) async {
            fail('HTTP should not be called without a base URL');
          }),
        );
        final invalidJson = WorkoutSetApiClient(
          baseUrl: 'https://api.example.test',
          httpClient: MockClient((_) async => http.Response('[]', 200)),
        );

        final forbiddenResult = await forbidden.getTrainerSet(
          accessToken: 'secret-token',
          workoutSetId: 'set-1',
        );
        final conflictResult = await conflict.assign(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
          request: const AssignWorkoutSetRequest(traineeUserIds: ['trainee-1']),
        );
        final missingBaseUrlResult = await missingBaseUrl.listTrainerSets(
          accessToken: 'access-token',
        );
        final invalidJsonResult = await invalidJson.getTrainerSet(
          accessToken: 'access-token',
          workoutSetId: 'set-1',
        );

        expect(forbiddenResult.status, WorkoutSetApiStatus.forbidden);
        expect(forbiddenResult.message, isNot(contains('secret-token')));
        expect(conflictResult.status, WorkoutSetApiStatus.conflict);
        expect(conflictResult.message, contains('Already assigned'));
        expect(missingBaseUrlResult.status, WorkoutSetApiStatus.error);
        expect(missingBaseUrlResult.message, contains('API_BASE_URL'));
        expect(invalidJsonResult.status, WorkoutSetApiStatus.error);
        expect(
          invalidJsonResult.message,
          contains('Invalid workout set detail'),
        );
      },
    );
  });
}

CreateWorkoutSetRequest _createRequest(String name) {
  return CreateWorkoutSetRequest(name: name, rows: _rowsRequest());
}

List<WorkoutSetRowRequest> _rowsRequest() {
  return const [
    WorkoutSetRowRequest(
      id: 'row-1',
      exerciseId: 'exercise-1',
      exerciseOrder: 1,
      setIndex: 1,
      exerciseName: 'Bench press',
      exerciseType: ExerciseValueType.repsWeight,
      reps: 6,
      weight: 40,
    ),
  ];
}

Map<String, Object?> _savePayload(String name) {
  return {
    'name': name,
    'rows': [
      {
        'id': 'row-1',
        'exerciseId': 'exercise-1',
        'exerciseOrder': 1,
        'setIndex': 1,
        'exerciseName': 'Bench press',
        'exerciseType': 'repsWeight',
        'reps': 6,
        'weight': 40.0,
        'seconds': null,
      },
    ],
  };
}

Map<String, Object?> _summaryJson() {
  return {
    'id': 'set-1',
    'name': 'Push A',
    'exerciseCount': 1,
    'rowCount': 1,
    'assignedTrainees': 2,
    'createdAt': '2026-06-16T12:00:00Z',
    'updatedAt': '2026-06-16T12:05:00Z',
  };
}

Map<String, Object?> _detailJson({String name = 'Push A'}) {
  return {
    'id': 'set-1',
    'name': name,
    'rows': [_rowJson()],
    'assignments': [
      {
        'traineeUserId': 'trainee-1',
        'traineeEmail': 'trainee@example.test',
        'traineeDisplayName': 'Test Trainee',
        'assignedAt': '2026-06-16T12:10:00Z',
      },
    ],
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
    'exerciseId': 'exercise-1',
    'exerciseOrder': 1,
    'setIndex': 1,
    'exerciseName': 'Bench press',
    'exerciseType': 'repsWeight',
    'reps': 6,
    'weight': 40.0,
    'seconds': null,
  };
}
