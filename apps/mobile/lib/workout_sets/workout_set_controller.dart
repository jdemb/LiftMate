import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../relationships/relationship_models.dart';
import 'workout_set_api_client.dart';
import 'workout_set_models.dart';

enum WorkoutSetControllerStatus {
  idle,
  loading,
  loaded,
  saving,
  error,
}

class WorkoutSetControllerState {
  const WorkoutSetControllerState({
    required this.status,
    this.user,
    this.trainerSets = const [],
    this.selectedSet,
    this.assignableTrainees = const [],
    this.traineeAssignedSets = const [],
    this.message,
  });

  const WorkoutSetControllerState.idle()
      : this(status: WorkoutSetControllerStatus.idle);

  final WorkoutSetControllerStatus status;
  final AuthUser? user;
  final List<WorkoutSetSummary> trainerSets;
  final WorkoutSetDetail? selectedSet;
  final List<TrainerTraineeSummary> assignableTrainees;
  final List<TraineeAssignedWorkoutSet> traineeAssignedSets;
  final String? message;

  WorkoutSetControllerState copyWith({
    WorkoutSetControllerStatus? status,
    AuthUser? user,
    List<WorkoutSetSummary>? trainerSets,
    WorkoutSetDetail? selectedSet,
    List<TrainerTraineeSummary>? assignableTrainees,
    List<TraineeAssignedWorkoutSet>? traineeAssignedSets,
    String? message,
    bool clearSelectedSet = false,
    bool clearMessage = false,
  }) {
    return WorkoutSetControllerState(
      status: status ?? this.status,
      user: user ?? this.user,
      trainerSets: trainerSets ?? this.trainerSets,
      selectedSet: clearSelectedSet ? null : selectedSet ?? this.selectedSet,
      assignableTrainees: assignableTrainees ?? this.assignableTrainees,
      traineeAssignedSets: traineeAssignedSets ?? this.traineeAssignedSets,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class WorkoutSetController extends ChangeNotifier {
  WorkoutSetController({
    required this.workoutSetApiClient,
    required this.authController,
  });

  final WorkoutSetApiClient workoutSetApiClient;
  final AuthController authController;

  WorkoutSetControllerState _state = const WorkoutSetControllerState.idle();

  WorkoutSetControllerState get state => _state;

  Future<void> loadForUser(
    AuthUser user, {
    TrainerRelationshipSummary? trainerSummary,
  }) async {
    if (user.role == UserRole.trainer) {
      await loadTrainerSets(
        user,
        assignableTrainees: trainerSummary?.trainees ?? _state.assignableTrainees,
      );
      return;
    }

    await loadTraineeAssignedSets(user);
  }

  Future<void> loadTrainerSets(
    AuthUser user, {
    List<TrainerTraineeSummary> assignableTrainees = const [],
  }) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.loading,
      user: user,
      assignableTrainees: assignableTrainees,
      clearMessage: true,
    ));

    if (accessToken == null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: 'User is not authenticated.',
      ));
      return;
    }

    final result = await workoutSetApiClient.listTrainerSets(accessToken: accessToken);
    final sets = result.data;
    if (result.isSuccess && sets != null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.loaded,
        trainerSets: sets,
        clearMessage: true,
      ));
      return;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
  }

  Future<void> loadTrainerDetail(String workoutSetId) async {
    final accessToken = authController.tokens?.accessToken;
    if (accessToken == null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: 'User is not authenticated.',
      ));
      return;
    }

    _setState(_state.copyWith(status: WorkoutSetControllerStatus.loading));
    final result = await workoutSetApiClient.getTrainerSet(
      accessToken: accessToken,
      workoutSetId: workoutSetId,
    );
    final detail = result.data;
    if (result.isSuccess && detail != null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.loaded,
        selectedSet: detail,
        clearMessage: true,
      ));
      return;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> createSet(
    CreateWorkoutSetRequest request,
  ) async {
    return _saveDetail(
      (accessToken) => workoutSetApiClient.create(
        accessToken: accessToken,
        request: request,
      ),
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> updateSet(
    String workoutSetId,
    UpdateWorkoutSetRequest request,
  ) async {
    return _saveDetail(
      (accessToken) => workoutSetApiClient.update(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
        request: request,
      ),
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> assign(
    String workoutSetId,
    List<String> traineeUserIds,
  ) async {
    return _saveDetail(
      (accessToken) => workoutSetApiClient.assign(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
        request: AssignWorkoutSetRequest(traineeUserIds: traineeUserIds),
      ),
    );
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> syncAssignments(
    String workoutSetId,
    List<String> selectedTraineeIds,
  ) async {
    final accessToken = authController.tokens?.accessToken;
    if (accessToken == null) {
      const result = WorkoutSetApiResult<WorkoutSetDetail>(
        status: WorkoutSetApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: result.message,
      ));
      return result;
    }

    final currentAssignments = _state.selectedSet?.id == workoutSetId
        ? _state.selectedSet!.assignments
        : const <WorkoutSetAssignment>[];
    final currentIds = currentAssignments
        .map((assignment) => assignment.traineeUserId)
        .toSet();
    final selectedIds = selectedTraineeIds.toSet();
    final removedIds = currentIds.difference(selectedIds);
    final addedIds = selectedTraineeIds
        .where((traineeUserId) => !currentIds.contains(traineeUserId))
        .toList(growable: false);

    _setState(_state.copyWith(status: WorkoutSetControllerStatus.saving));

    for (final traineeUserId in removedIds) {
      final result = await workoutSetApiClient.unassign(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
        traineeUserId: traineeUserId,
      );
      if (!result.isSuccess) {
        _setState(_state.copyWith(
          status: WorkoutSetControllerStatus.error,
          message: result.message,
        ));
        return WorkoutSetApiResult<WorkoutSetDetail>(
          status: result.status,
          statusCode: result.statusCode,
          message: result.message,
        );
      }
    }

    if (addedIds.isNotEmpty) {
      final result = await workoutSetApiClient.assign(
        accessToken: accessToken,
        workoutSetId: workoutSetId,
        request: AssignWorkoutSetRequest(traineeUserIds: addedIds),
      );
      final detail = result.data;
      if (result.isSuccess && detail != null) {
        _setState(_state.copyWith(
          status: WorkoutSetControllerStatus.loaded,
          selectedSet: detail,
          clearMessage: true,
        ));
        return result;
      }

      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: result.message,
      ));
      return result;
    }

    final result = await workoutSetApiClient.getTrainerSet(
      accessToken: accessToken,
      workoutSetId: workoutSetId,
    );
    final detail = result.data;
    if (result.isSuccess && detail != null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.loaded,
        selectedSet: detail,
        clearMessage: true,
      ));
      return result;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
    return result;
  }

  Future<WorkoutSetApiResult<void>> unassign(
    String workoutSetId,
    String traineeUserId,
  ) async {
    final accessToken = authController.tokens?.accessToken;
    if (accessToken == null) {
      const result = WorkoutSetApiResult<void>(
        status: WorkoutSetApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: result.message,
      ));
      return result;
    }

    _setState(_state.copyWith(status: WorkoutSetControllerStatus.saving));
    final result = await workoutSetApiClient.unassign(
      accessToken: accessToken,
      workoutSetId: workoutSetId,
      traineeUserId: traineeUserId,
    );
    if (result.isSuccess) {
      await loadTrainerDetail(workoutSetId);
      return result;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
    return result;
  }

  Future<void> loadTraineeAssignedSets(AuthUser user) async {
    final accessToken = authController.tokens?.accessToken;
    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.loading,
      user: user,
      clearMessage: true,
    ));

    if (accessToken == null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: 'User is not authenticated.',
      ));
      return;
    }

    final result = await workoutSetApiClient.listTraineeSets(accessToken: accessToken);
    final sets = result.data;
    if (result.isSuccess && sets != null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.loaded,
        traineeAssignedSets: sets,
        clearMessage: true,
      ));
      return;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
  }

  Future<void> reload() async {
    final user = _state.user ?? authController.state.user;
    if (user == null) {
      _setState(const WorkoutSetControllerState.idle());
      return;
    }

    await loadForUser(user);
  }

  Future<WorkoutSetApiResult<WorkoutSetDetail>> _saveDetail(
    Future<WorkoutSetApiResult<WorkoutSetDetail>> Function(String accessToken) send,
  ) async {
    final accessToken = authController.tokens?.accessToken;
    if (accessToken == null) {
      const result = WorkoutSetApiResult<WorkoutSetDetail>(
        status: WorkoutSetApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.error,
        message: result.message,
      ));
      return result;
    }

    _setState(_state.copyWith(status: WorkoutSetControllerStatus.saving));
    final result = await send(accessToken);
    final detail = result.data;
    if (result.isSuccess && detail != null) {
      _setState(_state.copyWith(
        status: WorkoutSetControllerStatus.loaded,
        selectedSet: detail,
        clearMessage: true,
      ));
      return result;
    }

    _setState(_state.copyWith(
      status: WorkoutSetControllerStatus.error,
      message: result.message,
    ));
    return result;
  }

  void _setState(WorkoutSetControllerState state) {
    _state = state;
    notifyListeners();
  }
}
