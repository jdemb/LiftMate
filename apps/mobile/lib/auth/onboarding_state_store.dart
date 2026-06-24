import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OnboardingStateStore {
  Future<String?> readPendingTraineeUserId();
  Future<void> savePendingTraineeUserId(String userId);
  Future<void> clearPendingTraineeUserId();
}

class SecureOnboardingStateStore implements OnboardingStateStore {
  SecureOnboardingStateStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _pendingTraineeUserIdKey =
      'liftmate.onboarding.pendingTraineeUserId';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readPendingTraineeUserId() {
    return _storage.read(key: _pendingTraineeUserIdKey);
  }

  @override
  Future<void> savePendingTraineeUserId(String userId) {
    return _storage.write(key: _pendingTraineeUserIdKey, value: userId);
  }

  @override
  Future<void> clearPendingTraineeUserId() {
    return _storage.delete(key: _pendingTraineeUserIdKey);
  }
}
