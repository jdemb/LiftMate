import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/auth/onboarding_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingStateStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('stores only the pending trainee user id', () async {
      final store = SecureOnboardingStateStore();

      await store.savePendingTraineeUserId('trainee-1');

      expect(await store.readPendingTraineeUserId(), 'trainee-1');
    });

    test('overwrites the pending trainee user id', () async {
      final store = SecureOnboardingStateStore();

      await store.savePendingTraineeUserId('trainee-1');
      await store.savePendingTraineeUserId('trainee-2');

      expect(await store.readPendingTraineeUserId(), 'trainee-2');
    });

    test('clears the pending trainee user id', () async {
      final store = SecureOnboardingStateStore();
      await store.savePendingTraineeUserId('trainee-1');

      await store.clearPendingTraineeUserId();

      expect(await store.readPendingTraineeUserId(), isNull);
    });
  });
}
