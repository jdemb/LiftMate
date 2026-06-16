import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../workout_sets/assign_workout_set_screen.dart';
import '../workout_sets/workout_set_api_client.dart';
import '../workout_sets/workout_set_builder_screen.dart';
import '../workout_sets/workout_set_controller.dart';
import '../workout_sets/workout_set_models.dart';
import '../workout_sets/trainer_workout_sets_screen.dart';
import 'relationship_api_client.dart';
import 'relationship_controller.dart';
import 'relationship_models.dart';
import 'trainee_home_screen.dart';
import 'trainer_dashboard_screen.dart';
import 'trainer_trainee_detail_screen.dart';

class AuthenticatedRelationshipShell extends StatefulWidget {
  const AuthenticatedRelationshipShell({
    required this.user,
    required this.authController,
    required this.relationshipApiClient,
    required this.workoutSetApiClient,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final AuthController authController;
  final RelationshipApiClient relationshipApiClient;
  final WorkoutSetApiClient workoutSetApiClient;
  final Future<void> Function() onLogout;

  @override
  State<AuthenticatedRelationshipShell> createState() =>
      _AuthenticatedRelationshipShellState();
}

class _AuthenticatedRelationshipShellState
    extends State<AuthenticatedRelationshipShell> {
  late final RelationshipController _relationshipController;
  late final WorkoutSetController _workoutSetController;
  TrainerTraineeSummary? _selectedTrainee;
  _TrainerView _trainerView = _TrainerView.dashboard;
  WorkoutSetDetail? _builderDetail;
  String? _loadedTraineeWorkoutSetsForUserId;

  @override
  void initState() {
    super.initState();
    _relationshipController = RelationshipController(
      relationshipApiClient: widget.relationshipApiClient,
      authController: widget.authController,
    );
    _workoutSetController = WorkoutSetController(
      workoutSetApiClient: widget.workoutSetApiClient,
      authController: widget.authController,
    );
    _relationshipController.loadForUser(widget.user);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedRelationshipShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.trainerUserId != widget.user.trainerUserId) {
      _selectedTrainee = null;
      _trainerView = _TrainerView.dashboard;
      _builderDetail = null;
      _loadedTraineeWorkoutSetsForUserId = null;
      _relationshipController.loadForUser(widget.user);
    }
  }

  @override
  void dispose() {
    _relationshipController.dispose();
    _workoutSetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _relationshipController,
      builder: (context, _) {
        final state = _relationshipController.state;
        if (widget.user.role == UserRole.trainer) {
          final selected = _selectedTrainee;
          if (selected != null) {
            final assignedSets = _assignedSetsFor(selected.id);
            return TrainerTraineeDetailScreen(
              trainee: selected,
              onBack: () => setState(() => _selectedTrainee = null),
              onLogout: widget.onLogout,
              assignedSets: assignedSets,
              onUnassign: (set) => _workoutSetController.unassign(set.id, selected.id),
            );
          }

          if (_trainerView == _TrainerView.sets) {
            return TrainerWorkoutSetsScreen(
              controller: _workoutSetController,
              onReload: _loadWorkoutSets,
              onOpenDashboard: () => setState(() => _trainerView = _TrainerView.dashboard),
              onCreateSet: () => setState(() {
                _builderDetail = null;
                _trainerView = _TrainerView.builder;
              }),
              onEditSet: _openBuilder,
              onAssignSet: _openAssign,
              onLogout: widget.onLogout,
            );
          }

          if (_trainerView == _TrainerView.builder) {
            return WorkoutSetBuilderScreen(
              controller: _workoutSetController,
              initialDetail: _builderDetail,
              onBack: () {
                setState(() => _trainerView = _TrainerView.sets);
                _loadWorkoutSets();
              },
            );
          }

          if (_trainerView == _TrainerView.assign) {
            final detail = _workoutSetController.state.selectedSet;
            if (detail == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return AssignWorkoutSetScreen(
              controller: _workoutSetController,
              workoutSet: detail,
              trainees: state.trainerSummary?.trainees ?? const [],
              onBack: () {
                setState(() => _trainerView = _TrainerView.sets);
                _loadWorkoutSets();
              },
            );
          }

          return TrainerDashboardScreen(
            user: widget.user,
            state: state,
            onOpenTrainee: (trainee) {
              setState(() => _selectedTrainee = trainee);
            },
            onOpenWorkoutSets: () {
              setState(() => _trainerView = _TrainerView.sets);
              _loadWorkoutSets();
            },
            onReload: _relationshipController.reload,
            onLogout: widget.onLogout,
          );
        }

        final traineeTrainer = state.traineeSummary?.trainer;
        if (traineeTrainer != null &&
            _loadedTraineeWorkoutSetsForUserId != widget.user.id) {
          _loadedTraineeWorkoutSetsForUserId = widget.user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _workoutSetController.loadForUser(widget.user);
            }
          });
        }

        return TraineeHomeScreen(
          user: widget.user,
          state: state,
          onClaimCode: _relationshipController.claimTrainerCode,
          onReload: _relationshipController.reload,
          onLogout: widget.onLogout,
          workoutSetController: traineeTrainer == null ? null : _workoutSetController,
        );
      },
    );
  }

  Future<void> _loadWorkoutSets() {
    return _workoutSetController.loadForUser(
      widget.user,
      trainerSummary: _relationshipController.state.trainerSummary,
    );
  }

  Future<void> _openBuilder(WorkoutSetSummary summary) async {
    await _workoutSetController.loadTrainerDetail(summary.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _builderDetail = _workoutSetController.state.selectedSet;
      _trainerView = _TrainerView.builder;
    });
  }

  Future<void> _openAssign(WorkoutSetSummary summary) async {
    await _workoutSetController.loadTrainerDetail(summary.id);
    if (!mounted) {
      return;
    }

    setState(() => _trainerView = _TrainerView.assign);
  }

  List<WorkoutSetDetail> _assignedSetsFor(String traineeUserId) {
    final selectedSet = _workoutSetController.state.selectedSet;
    if (selectedSet == null) {
      return const [];
    }

    final isAssigned = selectedSet.assignments.any(
      (assignment) => assignment.traineeUserId == traineeUserId,
    );
    return isAssigned ? [selectedSet] : const [];
  }
}

enum _TrainerView {
  dashboard,
  sets,
  builder,
  assign,
}
