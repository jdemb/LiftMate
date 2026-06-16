import 'package:flutter/foundation.dart';

import '../auth/auth_api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'relationship_api_client.dart';
import 'relationship_models.dart';

enum RelationshipControllerStatus {
  idle,
  loading,
  loaded,
  error,
}

class RelationshipControllerState {
  const RelationshipControllerState({
    required this.status,
    this.user,
    this.trainerSummary,
    this.traineeSummary,
    this.message,
  });

  const RelationshipControllerState.idle()
      : this(status: RelationshipControllerStatus.idle);

  const RelationshipControllerState.loading(AuthUser user)
      : this(status: RelationshipControllerStatus.loading, user: user);

  const RelationshipControllerState.loaded({
    required AuthUser user,
    TrainerRelationshipSummary? trainerSummary,
    TraineeRelationshipSummary? traineeSummary,
  }) : this(
          status: RelationshipControllerStatus.loaded,
          user: user,
          trainerSummary: trainerSummary,
          traineeSummary: traineeSummary,
        );

  const RelationshipControllerState.error({
    required AuthUser user,
    required String message,
    TrainerRelationshipSummary? trainerSummary,
    TraineeRelationshipSummary? traineeSummary,
  }) : this(
          status: RelationshipControllerStatus.error,
          user: user,
          message: message,
          trainerSummary: trainerSummary,
          traineeSummary: traineeSummary,
        );

  final RelationshipControllerStatus status;
  final AuthUser? user;
  final TrainerRelationshipSummary? trainerSummary;
  final TraineeRelationshipSummary? traineeSummary;
  final String? message;
}

class RelationshipController extends ChangeNotifier {
  RelationshipController({
    required this.relationshipApiClient,
    required this.authController,
  });

  final RelationshipApiClient relationshipApiClient;
  final AuthController authController;

  RelationshipControllerState _state = const RelationshipControllerState.idle();

  RelationshipControllerState get state => _state;

  Future<void> loadForUser(AuthUser user) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(RelationshipControllerState.loading(user));

    if (accessToken == null) {
      _setState(RelationshipControllerState.error(
        user: user,
        message: 'User is not authenticated.',
      ));
      return;
    }

    if (user.role == UserRole.trainer) {
      final result = await relationshipApiClient.getTrainerRelationship(
        accessToken: accessToken,
      );
      final summary = result.data;
      if (result.isSuccess && summary != null) {
        _setState(RelationshipControllerState.loaded(
          user: user,
          trainerSummary: summary,
        ));
        return;
      }

      _setState(RelationshipControllerState.error(
        user: user,
        message: result.message,
        trainerSummary: _state.trainerSummary,
      ));
      return;
    }

    final result = await relationshipApiClient.getTraineeRelationship(
      accessToken: accessToken,
    );
    final summary = result.data;
    if (result.isSuccess && summary != null) {
      _setState(RelationshipControllerState.loaded(
        user: user,
        traineeSummary: summary,
      ));
      return;
    }

    _setState(RelationshipControllerState.error(
      user: user,
      message: result.message,
      traineeSummary: _state.traineeSummary,
    ));
  }

  Future<AuthApiResult<AuthUser>> claimTrainerCode(String code) async {
    final previous = _state;
    final currentUser = previous.user ?? authController.state.user;
    if (currentUser == null) {
      return const AuthApiResult<AuthUser>(
        status: AuthApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
    }

    _setState(RelationshipControllerState.loading(currentUser));
    final result = await authController.claimTrainerInviteCode(code: code);
    final user = result.data ?? authController.state.user;
    if (!result.isSuccess || user == null) {
      _setState(RelationshipControllerState.error(
        user: currentUser,
        message: result.message,
        trainerSummary: previous.trainerSummary,
        traineeSummary: previous.traineeSummary,
      ));
      return result;
    }

    await loadForUser(user);
    return result;
  }

  Future<void> reload() async {
    final user = _state.user ?? authController.state.user;
    if (user == null) {
      _setState(const RelationshipControllerState.idle());
      return;
    }

    await loadForUser(user);
  }

  void _setState(RelationshipControllerState state) {
    _state = state;
    notifyListeners();
  }
}
