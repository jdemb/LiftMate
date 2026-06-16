import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../workout_sets/workout_set_api_client.dart';
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
  TrainerTraineeSummary? _selectedTrainee;

  @override
  void initState() {
    super.initState();
    _relationshipController = RelationshipController(
      relationshipApiClient: widget.relationshipApiClient,
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
      _relationshipController.loadForUser(widget.user);
    }
  }

  @override
  void dispose() {
    _relationshipController.dispose();
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
            return TrainerTraineeDetailScreen(
              trainee: selected,
              onBack: () => setState(() => _selectedTrainee = null),
              onLogout: widget.onLogout,
            );
          }

          return TrainerDashboardScreen(
            user: widget.user,
            state: state,
            onOpenTrainee: (trainee) {
              setState(() => _selectedTrainee = trainee);
            },
            onReload: _relationshipController.reload,
            onLogout: widget.onLogout,
          );
        }

        return TraineeHomeScreen(
          user: widget.user,
          state: state,
          onClaimCode: _relationshipController.claimTrainerCode,
          onReload: _relationshipController.reload,
          onLogout: widget.onLogout,
        );
      },
    );
  }
}
