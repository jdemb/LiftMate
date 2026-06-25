import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_api_client.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_controller.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_models.dart';

void main() {
  group('TrainerGuidanceController', () {
    test('loads guidance and markAsRead removes card locally', () async {
      final api = _FakeGuidanceApiClient([
        _guidance('guidance-1'),
        _guidance('guidance-2'),
      ]);
      final controller = TrainerGuidanceController(
        apiClient: api,
        accessTokenProvider: () => 'access-token',
        traineeUserId: 'trainee-1',
      );

      await controller.load();
      expect(controller.state.status, TrainerGuidanceStatus.loaded);
      expect(controller.state.items.map((item) => item.id), [
        'guidance-1',
        'guidance-2',
      ]);

      await controller.markAsRead('guidance-1');

      expect(api.markedAsRead, ['guidance-1']);
      expect(controller.state.items.map((item) => item.id), ['guidance-2']);
    });

    test('load and mark failures keep readable local state', () async {
      final api = _FakeGuidanceApiClient([], failList: true, failRead: true);
      final controller = TrainerGuidanceController(
        apiClient: api,
        accessTokenProvider: () => 'access-token',
        traineeUserId: 'trainee-1',
      );

      await controller.load();

      expect(controller.state.status, TrainerGuidanceStatus.error);
      expect(controller.state.message, 'Guidance unavailable.');

      api.failList = false;
      await controller.load();
      await controller.markAsRead('missing');

      expect(controller.state.status, TrainerGuidanceStatus.loaded);
      expect(controller.state.message, 'Read failed.');
    });
  });
}

class _FakeGuidanceApiClient extends TrainerGuidanceApiClient {
  _FakeGuidanceApiClient(
    this.items, {
    this.failList = false,
    this.failRead = false,
  }) : super(baseUrl: 'https://api.example.test');

  final List<TrainerGuidance> items;
  final markedAsRead = <String>[];
  bool failList;
  bool failRead;

  @override
  Future<TrainerGuidanceApiResult<TrainerGuidanceList>> list({
    required String accessToken,
    required String traineeUserId,
  }) async {
    if (failList) {
      return const TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.error,
        message: 'Guidance unavailable.',
      );
    }
    return TrainerGuidanceApiResult(
      status: TrainerGuidanceApiStatus.success,
      message: 'OK',
      data: TrainerGuidanceList(items),
    );
  }

  @override
  Future<TrainerGuidanceApiResult<void>> markAsRead({
    required String accessToken,
    required String guidanceId,
  }) async {
    if (failRead) {
      return const TrainerGuidanceApiResult(
        status: TrainerGuidanceApiStatus.error,
        message: 'Read failed.',
      );
    }
    markedAsRead.add(guidanceId);
    return const TrainerGuidanceApiResult(
      status: TrainerGuidanceApiStatus.success,
      message: 'OK',
    );
  }
}

TrainerGuidance _guidance(String id) {
  return TrainerGuidance(
    id: id,
    type: TrainerGuidanceType.weightStagnation,
    traineeUserId: 'trainee-1',
    exerciseId: 'exercise-1',
    exerciseName: 'Bench',
    message: 'Warto sprawdzić ciężar w ćwiczeniu Bench',
    weightEvidence: const [],
    wellbeingEvidence: const [],
    createdAt: DateTime.utc(2026, 6, 22),
  );
}
