import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../post_workout_feedback/post_workout_feedback_api_client.dart';
import '../post_workout_feedback/post_workout_feedback_controller.dart';
import '../post_workout_feedback/post_workout_feedback_screen.dart';
import '../shared_sessions/shared_session_api_client.dart';
import '../shared_sessions/shared_session_controller.dart';
import '../shared_sessions/live_session_screen.dart';
import '../shared_sessions/shared_session_realtime_client.dart';
import '../training_history/training_history_api_client.dart';
import '../training_history/training_history_controller.dart';
import '../training_history/training_history_flow.dart';
import '../trainer_guidance/trainer_guidance_api_client.dart';
import '../trainer_guidance/trainer_guidance_controller.dart';
import '../workout_sets/assign_workout_set_screen.dart';
import '../workout_sets/workout_set_api_client.dart';
import '../workout_sets/workout_set_builder_screen.dart';
import '../workout_sets/workout_set_controller.dart';
import '../workout_sets/workout_set_models.dart';
import '../widgets/motion/motion_reveals.dart';
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
    required this.trainingHistoryApiClient,
    required this.trainerGuidanceApiClient,
    required this.postWorkoutFeedbackApiClient,
    required this.sharedSessionRealtimeClientFactory,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final AuthController authController;
  final RelationshipApiClient relationshipApiClient;
  final WorkoutSetApiClient workoutSetApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final TrainingHistoryApiClient trainingHistoryApiClient;
  final TrainerGuidanceApiClient trainerGuidanceApiClient;
  final PostWorkoutFeedbackApiClient postWorkoutFeedbackApiClient;
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
  late final TrainingHistoryController _selfHistoryController;
  TrainingHistoryController? _trainerHistoryController;
  TrainerGuidanceController? _trainerGuidanceController;
  PostWorkoutFeedbackController? _feedbackController;
  _FeedbackOrigin? _feedbackOrigin;
  TrainerTraineeSummary? _selectedTrainee;
  String? _openingTraineeId;
  _TrainerView _trainerView = _TrainerView.dashboard;
  WorkoutSetDetail? _builderDetail;
  String? _loadedTraineeWorkoutSetsForUserId;
  String? _loadedTraineeActiveSessionForUserId;
  bool _showTraineeLive = false;
  bool _showTraineeHistory = false;
  bool _showProgressSavedAfterFeedback = false;
  bool _handlingCompletionSignal = false;

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
    _sharedSessionController.addListener(_handleSharedSessionChanged);
    _selfHistoryController = TrainingHistoryController(
      apiClient: widget.trainingHistoryApiClient,
      accessTokenProvider: () => widget.authController.tokens?.accessToken,
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
      _showTraineeHistory = false;
      _showProgressSavedAfterFeedback = false;
      _disposeFeedbackController();
      _trainerHistoryController?.dispose();
      _trainerHistoryController = null;
      _disposeTrainerGuidanceController();
      _relationshipController.loadForUser(widget.user);
    }
  }

  @override
  void dispose() {
    _relationshipController.dispose();
    _workoutSetController.dispose();
    _sharedSessionController.removeListener(_handleSharedSessionChanged);
    _sharedSessionController.dispose();
    _selfHistoryController.dispose();
    _trainerHistoryController?.dispose();
    _trainerGuidanceController?.dispose();
    _feedbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _relationshipController,
      builder: (context, _) {
        Widget show(String viewId, Widget child) {
          return MotionSwitcher(
            child: KeyedSubtree(
              key: ValueKey('relationship-view-$viewId'),
              child: child,
            ),
          );
        }

        final state = _relationshipController.state;
        if (widget.user.role == UserRole.trainer) {
          final selected = _selectedTrainee;
          if (_trainerView == _TrainerView.live) {
            return show('trainer-live', LiveSessionScreen(
              user: widget.user,
              controller: _sharedSessionController,
              editable: true,
              traineeDisplayName: selected?.displayName,
              onSessionClosed: _handleTrainerSessionClosed,
              onBack: () {
                setState(() => _trainerView = _TrainerView.dashboard);
                _relationshipController.reload();
              },
            ));
          }

          if (_trainerView == _TrainerView.history &&
              _trainerHistoryController != null) {
            return show('trainer-history', TrainingHistoryFlow(
              controller: _trainerHistoryController!,
              viewerRole: UserRole.trainer,
              showLevelOneBack: true,
              onClose: () {
                _trainerHistoryController?.dispose();
                _trainerHistoryController = null;
                setState(() => _trainerView = _TrainerView.dashboard);
              },
            ));
          }

          if (selected != null) {
            return show('trainee-${selected.id}', TrainerTraineeDetailScreen(
              trainee: selected,
              onBack: () {
                _disposeTrainerGuidanceController();
                setState(() => _selectedTrainee = null);
              },
              onLogout: widget.onLogout,
              onOpenWorkoutSets: _openWorkoutSetsFromDetail,
              onOpenHistory: () => _openTrainerHistory(selected),
              assignedSets: selected.assignedWorkoutSets,
              guidanceController: _trainerGuidanceController,
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
            ));
          }

          if (_trainerView == _TrainerView.sets) {
            return show('trainer-sets', TrainerWorkoutSetsScreen(
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
            ));
          }

          if (_trainerView == _TrainerView.builder) {
            return show('trainer-builder', WorkoutSetBuilderScreen(
              controller: _workoutSetController,
              initialDetail: _builderDetail,
              onBack: () {
                setState(() => _trainerView = _TrainerView.sets);
                _loadWorkoutSets();
              },
            ));
          }

          if (_trainerView == _TrainerView.assign) {
            final detail = _workoutSetController.state.selectedSet;
            if (detail == null) {
              return show(
                'trainer-assign-loading',
                const Center(child: CircularProgressIndicator()),
              );
            }

            return show('trainer-assign', AssignWorkoutSetScreen(
              controller: _workoutSetController,
              workoutSet: detail,
              trainees: state.trainerSummary?.trainees ?? const [],
              onBack: () {
                setState(() => _trainerView = _TrainerView.sets);
                _loadWorkoutSets();
              },
            ));
          }

          return show('trainer-dashboard', TrainerDashboardScreen(
            user: widget.user,
            state: state,
            openingTraineeId: _openingTraineeId,
            onOpenTrainee: _openTraineeDetail,
            onOpenWorkoutSets: () {
              setState(() => _trainerView = _TrainerView.sets);
              _loadWorkoutSets();
            },
            onReload: _relationshipController.reload,
            onCopyInviteCode: _copyTrainerInviteCode,
            onLogout: widget.onLogout,
          ));
        }

        final traineeTrainer = state.traineeSummary?.trainer;
        final feedbackController = _feedbackController;
        if (feedbackController != null) {
          return show('trainee-feedback', PostWorkoutFeedbackScreen(
            controller: feedbackController,
            onSaved: _handleFeedbackSaved,
            onSkipped: _handleFeedbackSkipped,
          ));
        }
        if (_showTraineeHistory) {
          return show('trainee-history', TrainingHistoryFlow(
            controller: _selfHistoryController,
            viewerRole: UserRole.trainee,
            onAddFeedback: _openFeedbackFromHistory,
            onClose: () => setState(() => _showTraineeHistory = false),
          ));
        }
        if (_showTraineeLive) {
          final session = _sharedSessionController.state.session;
          return show('trainee-live', LiveSessionScreen(
            user: widget.user,
            controller: _sharedSessionController,
            editable: session?.isTraineeSelfStarted ?? false,
            trainerDisplayName: traineeTrainer?.displayName,
            onSessionClosed: _handleTraineeSessionClosed,
            onBack: () {
              setState(() => _showTraineeLive = false);
              _relationshipController.reload();
            },
          ));
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

        return show('trainee-home', TraineeHomeScreen(
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
          onOpenHistory: _openSelfHistory,
        ));
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
        _trainerGuidanceController?.dispose();
        _trainerGuidanceController = TrainerGuidanceController(
          apiClient: widget.trainerGuidanceApiClient,
          accessTokenProvider: () => widget.authController.tokens?.accessToken,
          traineeUserId: refreshed.id,
        );
      }
    });
    _trainerGuidanceController?.load();
  }

  void _openWorkoutSetsFromDetail() {
    _disposeTrainerGuidanceController();
    setState(() {
      _selectedTrainee = null;
      _trainerView = _TrainerView.sets;
    });
    _loadWorkoutSets();
  }

  void _openSelfHistory() {
    setState(() => _showTraineeHistory = true);
    _selfHistoryController.loadInitial();
  }

  void _openFeedbackFromHistory(String sessionId) {
    _openFeedback(sessionId, _FeedbackOrigin.history);
  }

  void _openTrainerHistory(TrainerTraineeSummary trainee) {
    _trainerHistoryController?.dispose();
    final controller = TrainingHistoryController(
      apiClient: widget.trainingHistoryApiClient,
      accessTokenProvider: () => widget.authController.tokens?.accessToken,
      traineeUserId: trainee.id,
    );
    _trainerHistoryController = controller;
    setState(() => _trainerView = _TrainerView.history);
    controller.loadInitial();
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
    _consumeCompletedSessionSignal();
    _sharedSessionController.clearSession();
    await _relationshipController.reload();
    if (!mounted) {
      return;
    }

    setState(() => _showTraineeLive = false);
    if (saved) {
      if (_feedbackController == null) {
        _showProgressSavedConfirmation();
      } else {
        _showProgressSavedAfterFeedback = true;
      }
    }
  }

  void _handleSharedSessionChanged() {
    if (widget.user.role != UserRole.trainee || _handlingCompletionSignal) {
      return;
    }
    _consumeCompletedSessionSignal();
  }

  void _consumeCompletedSessionSignal() {
    _handlingCompletionSignal = true;
    final sessionId = _sharedSessionController
        .consumeCompletedSessionForFeedback();
    _handlingCompletionSignal = false;
    if (sessionId == null || _feedbackController != null || !mounted) {
      return;
    }
    _openFeedback(sessionId, _FeedbackOrigin.immediate);
  }

  void _openFeedback(String sessionId, _FeedbackOrigin origin) {
    _disposeFeedbackController();
    final historyController = origin == _FeedbackOrigin.history
        ? _selfHistoryController
        : null;
    final controller = PostWorkoutFeedbackController(
      sessionId: sessionId,
      apiClient: widget.postWorkoutFeedbackApiClient,
      accessTokenProvider: () => widget.authController.tokens?.accessToken,
      onSaved: historyController == null
          ? null
          : (_) => historyController.refreshOpenSession(),
    );
    setState(() {
      _feedbackController = controller;
      _feedbackOrigin = origin;
      if (origin == _FeedbackOrigin.immediate) {
        _showTraineeLive = false;
      }
    });
  }

  Future<void> _handleFeedbackSaved() {
    return _closeFeedback();
  }

  Future<void> _handleFeedbackSkipped() {
    return _closeFeedback();
  }

  Future<void> _closeFeedback() async {
    final origin = _feedbackOrigin;
    _disposeFeedbackController();
    if (origin == _FeedbackOrigin.immediate) {
      _sharedSessionController.clearSession();
      await _relationshipController.reload();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (origin == _FeedbackOrigin.immediate) {
        _showTraineeLive = false;
        _showTraineeHistory = false;
      } else if (origin == _FeedbackOrigin.history) {
        _showTraineeHistory = true;
      }
    });
    if (_showProgressSavedAfterFeedback) {
      _showProgressSavedAfterFeedback = false;
      _showProgressSavedConfirmation();
    }
  }

  void _disposeFeedbackController() {
    _feedbackController?.dispose();
    _feedbackController = null;
    _feedbackOrigin = null;
  }

  void _disposeTrainerGuidanceController() {
    _trainerGuidanceController?.dispose();
    _trainerGuidanceController = null;
  }

  void _showProgressSavedConfirmation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano wartości na następny trening.')),
    );
  }

  Future<void> _copyTrainerInviteCode(String code) async {
    if (code.trim().isEmpty) {
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kod zaproszenia skopiowany.')),
      );
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się skopiować kodu.')),
      );
    }
  }
}

enum _TrainerView { dashboard, sets, builder, assign, live, history }

enum _FeedbackOrigin { immediate, history }
