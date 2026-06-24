import 'package:liftmate/auth/onboarding_state_store.dart';

class FakeOnboardingStateStore implements OnboardingStateStore {
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
