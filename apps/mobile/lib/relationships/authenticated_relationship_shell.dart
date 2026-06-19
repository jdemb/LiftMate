import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../shared_sessions/shared_session_api_client.dart';
import '../shared_sessions/shared_session_controller.dart';
import '../shared_sessions/live_session_screen.dart';
import '../shared_sessions/shared_session_realtime_client.dart';
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
    required this.sharedSessionApiClient,
    required this.sharedSessionRealtimeClientFactory,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final AuthController authController;
  final RelationshipApiClient relationshipApiClient;
  final WorkoutSetApiClient workoutSetApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final SharedSessionRealtimeClientFactory sharedSessionRealtimeClientFactory;
  final Future<void> Function() onLogout;

  @override
  State<AuthenticatedRelationshipShell> createState() =>
      _AuthenticatedRelationshipShellState();
}

class _AuthenticatedRelationshipShellState
    extends State<AuthenticatedRelationshipShell> {
  late final RelationshipController _relationshipController;
  late final WorkoutSetController _workoutSetController;
  late final SharedSessionController _sharedSessionController;
  TrainerTraineeSummary? _selectedTrainee;
  String? _openingTraineeId;
  _TrainerView _trainerView = _TrainerView.dashboard;
  WorkoutSetDetail? _builderDetail;
  String? _loadedTraineeWorkoutSetsForUserId;
  String? _loadedTraineeActiveSessionForUserId;
  bool _showTraineeLive = false;

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
    _sharedSessionController = SharedSessionController(
      apiClient: widget.sharedSessionApiClient,
      authController: widget.authController,
      realtimeClientFactory: widget.sharedSessionRealtimeClientFactory,
      onTrainerSessionInvalidated: _relationshipController.reload,
    );
    _relationshipController.loadForUser(widget.user);
  }

  @override
  void didUpdateWidget(covariant AuthenticatedRelationshipShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.trainerUserId != widget.user.trainerUserId) {
      _selectedTrainee = null;
      _openingTraineeId = null;
      _trainerView = _TrainerView.dashboard;
      _builderDetail = null;
      _loadedTraineeWorkoutSetsForUserId = null;
      _loadedTraineeActiveSessionForUserId = null;
      _showTraineeLive = false;
      _relationshipController.loadForUser(widget.user);
    }
  }

  @override
  void dispose() {
    _relationshipController.dispose();
    _workoutSetController.dispose();
    _sharedSessionController.dispose();
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
          if (_trainerView == _TrainerView.live) {
            return LiveSessionScreen(
              user: widget.user,
              controller: _sharedSessionController,
              editable: true,
              onSessionClosed: _handleTrainerSessionClosed,
              onBack: () {
                setState(() => _trainerView = _TrainerView.dashboard);
                _relationshipController.reload();
              },
            );
          }

          if (selected != null) {
            return TrainerTraineeDetailScreen(
              trainee: selected,
              onBack: () => setState(() => _selectedTrainee = null),
              onLogout: widget.onLogout,
              onOpenWorkoutSets: _openWorkoutSetsFromDetail,
              assignedSets: selected.assignedWorkoutSets,
              onStartSession: (set) => _startTrainerSession(selected, set),
              onJoinActiveSession: selected.activeSession == null
                  ? null
                  : () =>
                        _joinTrainerSession(selected.activeSession!.sessionId),
              sessionErrorMessage:
                  _sharedSessionController.state.status ==
                      SharedSessionControllerStatus.error
                  ? _sharedSessionController.state.message
                  : null,
            );
          }

          if (_trainerView == _TrainerView.sets) {
            return TrainerWorkoutSetsScreen(
              controller: _workoutSetController,
              onReload: _loadWorkoutSets,
              onOpenDashboard: () =>
                  setState(() => _trainerView = _TrainerView.dashboard),
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
            openingTraineeId: _openingTraineeId,
            onOpenTrainee: _openTraineeDetail,
            onOpenWorkoutSets: () {
              setState(() => _trainerView = _TrainerView.sets);
              _loadWorkoutSets();
            },
            onReload: _relationshipController.reload,
            onLogout: widget.onLogout,
          );
        }

        final traineeTrainer = state.traineeSummary?.trainer;
        if (_showTraineeLive) {
          final session = _sharedSessionController.state.session;
          return LiveSessionScreen(
            user: widget.user,
            controller: _sharedSessionController,
            editable: session?.isTraineeSelfStarted ?? false,
            trainerDisplayName: traineeTrainer?.displayName,
            onSessionClosed: _handleTraineeSessionClosed,
            onBack: () {
              setState(() => _showTraineeLive = false);
              _relationshipController.reload();
            },
          );
        }

        if (traineeTrainer != null &&
            _loadedTraineeWorkoutSetsForUserId != widget.user.id) {
          _loadedTraineeWorkoutSetsForUserId = widget.user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _workoutSetController.loadForUser(widget.user);
            }
          });
        }
        if (traineeTrainer != null &&
            _loadedTraineeActiveSessionForUserId != widget.user.id) {
          _loadedTraineeActiveSessionForUserId = widget.user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _sharedSessionController.loadActive(widget.user);
            }
          });
        }

        return TraineeHomeScreen(
          user: widget.user,
          state: state,
          onClaimCode: _relationshipController.claimTrainerCode,
          onReload: _relationshipController.reload,
          onLogout: widget.onLogout,
          workoutSetController: traineeTrainer == null
              ? null
              : _workoutSetController,
          sharedSessionController: traineeTrainer == null
              ? null
              : _sharedSessionController,
          onStartWorkout: _startTraineeSession,
          onJoinActiveWorkout: _joinTraineeActiveSession,
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

  Future<void> _openTraineeDetail(TrainerTraineeSummary trainee) async {
    if (_openingTraineeId != null) {
      return;
    }

    setState(() => _openingTraineeId = trainee.id);
    await _relationshipController.reload();
    if (!mounted) {
      return;
    }

    if (_relationshipController.state.status !=
        RelationshipControllerStatus.loaded) {
      setState(() => _openingTraineeId = null);
      return;
    }

    final refreshedTrainees =
        _relationshipController.state.trainerSummary?.trainees ??
        const <TrainerTraineeSummary>[];
    TrainerTraineeSummary? refreshed;
    for (final candidate in refreshedTrainees) {
      if (candidate.id == trainee.id) {
        refreshed = candidate;
        break;
      }
    }

    setState(() {
      _openingTraineeId = null;
      if (refreshed != null) {
        _selectedTrainee = refreshed;
      }
    });
  }

  void _openWorkoutSetsFromDetail() {
    setState(() {
      _selectedTrainee = null;
      _trainerView = _TrainerView.sets;
    });
    _loadWorkoutSets();
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

  Future<void> _startTrainerSession(
    TrainerTraineeSummary trainee,
    AssignedWorkoutSetSummary set,
  ) async {
    await _sharedSessionController.startTrainerSession(
      user: widget.user,
      traineeUserId: trainee.id,
      workoutSetId: set.id,
    );
    if (!mounted) {
      return;
    }
    if (_hasActiveLoadedSession) {
      setState(() => _trainerView = _TrainerView.live);
    } else {
      setState(() {});
    }
  }

  Future<void> _joinTrainerSession(String sessionId) async {
    await _sharedSessionController.loadById(
      user: widget.user,
      sessionId: sessionId,
    );
    if (!mounted) {
      return;
    }
    if (_hasActiveLoadedSession) {
      setState(() => _trainerView = _TrainerView.live);
    } else {
      setState(() {});
    }
  }

  Future<void> _startTraineeSession(TraineeAssignedWorkoutSet set) async {
    await _sharedSessionController.startTraineeSession(
      user: widget.user,
      workoutSetId: set.id,
    );
    if (!mounted) {
      return;
    }
    if (_hasActiveLoadedSession) {
      setState(() => _showTraineeLive = true);
    } else {
      setState(() {});
    }
  }

  Future<void> _joinTraineeActiveSession() async {
    final activeSession = _sharedSessionController.state.session;
    if (activeSession == null) {
      await _sharedSessionController.loadActive(widget.user);
    } else {
      await _sharedSessionController.loadById(
        user: widget.user,
        sessionId: activeSession.id,
      );
    }
    if (!mounted) {
      return;
    }
    if (_hasActiveLoadedSession) {
      setState(() => _showTraineeLive = true);
    } else {
      setState(() {});
    }
  }

  bool get _hasActiveLoadedSession {
    return _sharedSessionController.hasRenderableActiveSession;
  }

  Future<void> _handleTrainerSessionClosed() async {
    final saved =
        _sharedSessionController.state.completionOutcome ==
        SharedSessionCompletionOutcome.savedForNextSession;
    _sharedSessionController.clearSession();
    await _relationshipController.reload();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTrainee = null;
      _trainerView = _TrainerView.dashboard;
    });
    if (saved) {
      _showProgressSavedConfirmation();
    }
  }

  Future<void> _handleTraineeSessionClosed() async {
    final saved =
        _sharedSessionController.state.completionOutcome ==
        SharedSessionCompletionOutcome.savedForNextSession;
    _sharedSessionController.clearSession();
    await _relationshipController.reload();
    if (!mounted) {
      return;
    }

    setState(() => _showTraineeLive = false);
    if (saved) {
      _showProgressSavedConfirmation();
    }
  }

  void _showProgressSavedConfirmation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano wartości na następny trening.')),
    );
  }
}

enum _TrainerView { dashboard, sets, builder, assign, live }
