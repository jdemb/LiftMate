import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/training_history/training_history_api_client.dart';
import 'package:liftmate/training_history/training_history_controller.dart';
import 'package:liftmate/training_history/training_history_models.dart';

void main() {
  test(
    'controller retains list through pagination, nested navigation, and back',
    () async {
      final api = _FakeHistoryApiClient();
      final controller = TrainingHistoryController(
        apiClient: api,
        accessTokenProvider: () => 'token',
        traineeUserId: 'trainee-1',
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      await controller.loadMore();
      await controller.openSession('session-1');
      await controller.openProgress('exercise-1');

      expect(controller.state.items.map((item) => item.id), [
        'session-1',
        'session-2',
      ]);
      expect(controller.state.detail?.id, 'session-1');
      expect(controller.state.progress?.exerciseId, 'exercise-1');

      controller.backFromProgress();
      expect(controller.state.progress, isNull);
      expect(controller.state.detail, isNotNull);
      controller.backFromDetail();
      expect(controller.state.detail, isNull);
      expect(controller.state.items, hasLength(2));
    },
  );

  test(
    'pagination failure preserves loaded sessions and retry appends once',
    () async {
      final api = _FakeHistoryApiClient(failNextPageOnce: true);
      final controller = TrainingHistoryController(
        apiClient: api,
        accessTokenProvider: () => 'token',
      );
      addTearDown(controller.dispose);

      await controller.loadInitial();
      await Future.wait([controller.loadMore(), controller.loadMore()]);

      expect(controller.state.items, hasLength(1));
      expect(controller.state.paginationError, isNotNull);
      expect(api.secondPageCalls, 1);

      await controller.retry();

      expect(controller.state.items, hasLength(2));
      expect(controller.state.paginationError, isNull);
    },
  );

  test('initial failure and empty result are explicit and retryable', () async {
    final api = _FakeHistoryApiClient(
      failInitialOnce: true,
      emptyAfterRetry: true,
    );
    final controller = TrainingHistoryController(
      apiClient: api,
      accessTokenProvider: () => 'token',
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(controller.state.status, TrainingHistoryStatus.error);

    await controller.retry();
    expect(controller.state.status, TrainingHistoryStatus.loaded);
    expect(controller.state.items, isEmpty);
  });
}

class _FakeHistoryApiClient extends TrainingHistoryApiClient {
  _FakeHistoryApiClient({
    this.failInitialOnce = false,
    this.failNextPageOnce = false,
    this.emptyAfterRetry = false,
  }) : super(baseUrl: 'https://api.example.test');

  final bool failInitialOnce;
  final bool failNextPageOnce;
  final bool emptyAfterRetry;
  int initialCalls = 0;
  int secondPageCalls = 0;

  @override
  Future<TrainingHistoryApiResult<TrainingHistoryPage>> list({
    required String accessToken,
    String? traineeUserId,
    String? cursor,
  }) async {
    if (cursor == null) {
      initialCalls += 1;
      if (failInitialOnce && initialCalls == 1) {
        return const TrainingHistoryApiResult(
          status: TrainingHistoryApiStatus.error,
          message: 'initial failed',
        );
      }
      return TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.success,
        message: 'ok',
        data: TrainingHistoryPage(
          items: emptyAfterRetry ? const [] : [_summary('session-1')],
          nextCursor: emptyAfterRetry ? null : 'next',
        ),
      );
    }

    secondPageCalls += 1;
    if (failNextPageOnce && secondPageCalls == 1) {
      return const TrainingHistoryApiResult(
        status: TrainingHistoryApiStatus.error,
        message: 'page failed',
      );
    }
    return TrainingHistoryApiResult(
      status: TrainingHistoryApiStatus.success,
      message: 'ok',
      data: TrainingHistoryPage(items: [_summary('session-2')]),
    );
  }

  @override
  Future<TrainingHistoryApiResult<TrainingHistorySession>> detail({
    required String accessToken,
    required String sessionId,
  }) async {
    return TrainingHistoryApiResult(
      status: TrainingHistoryApiStatus.success,
      message: 'ok',
      data: TrainingHistorySession(
        id: sessionId,
        workoutSetName: 'Plan',
        startedAt: DateTime.utc(2026, 6, 18),
        completedAt: DateTime.utc(2026, 6, 18, 1),
        durationSeconds: 3600,
        exerciseCount: 0,
        seriesCount: 0,
        exercises: const [],
      ),
    );
  }

  @override
  Future<TrainingHistoryApiResult<ExerciseProgress>> progress({
    required String accessToken,
    required String exerciseId,
    String? traineeUserId,
  }) async {
    return TrainingHistoryApiResult(
      status: TrainingHistoryApiStatus.success,
      message: 'ok',
      data: ExerciseProgress(
        exerciseId: exerciseId,
        exerciseName: 'Bench',
        type: ExerciseValueType.repsWeight,
        unit: 'kg',
        startValue: 40,
        currentValue: 45,
        overallDelta: 5,
        points: const [],
      ),
    );
  }
}

TrainingHistorySessionSummary _summary(String id) {
  return TrainingHistorySessionSummary(
    id: id,
    workoutSetName: 'Plan',
    startedAt: DateTime.utc(2026, 6, 18),
    completedAt: DateTime.utc(2026, 6, 18, 1),
    durationSeconds: 3600,
    exerciseCount: 1,
    seriesCount: 2,
  );
}
