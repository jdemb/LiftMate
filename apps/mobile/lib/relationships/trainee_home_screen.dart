import 'package:flutter/material.dart';

import '../auth/auth_api_client.dart';
import '../auth/auth_models.dart';
import '../workout_sets/trainee_assigned_workout_set_view.dart';
import '../workout_sets/workout_set_controller.dart';
import 'relationship_controller.dart';
import 'relationship_screen_styles.dart';

class TraineeHomeScreen extends StatefulWidget {
  const TraineeHomeScreen({
    required this.user,
    required this.state,
    required this.onClaimCode,
    required this.onReload,
    required this.onLogout,
    this.workoutSetController,
    super.key,
  });

  final AuthUser user;
  final RelationshipControllerState state;
  final Future<AuthApiResult<AuthUser>> Function(String code) onClaimCode;
  final Future<void> Function() onReload;
  final Future<void> Function() onLogout;
  final WorkoutSetController? workoutSetController;

  @override
  State<TraineeHomeScreen> createState() => _TraineeHomeScreenState();
}

class _TraineeHomeScreenState extends State<TraineeHomeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainer = widget.state.traineeSummary?.trainer;
    final isLoading = widget.state.status == RelationshipControllerStatus.loading;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onReload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              children: [
                _TraineeHeader(user: widget.user, onLogout: widget.onLogout),
                const SizedBox(height: 22),
                if (isLoading && widget.state.traineeSummary == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (trainer == null)
                  _UnlinkedTrainerCard(
                    controller: _codeController,
                    errorMessage: widget.state.status == RelationshipControllerStatus.error
                        ? widget.state.message
                        : null,
                    isLoading: isLoading,
                    onSubmit: _submit,
                  )
                else
                  _LinkedTrainerCard(
                    trainerName: trainer.displayName,
                    trainerEmail: trainer.email,
                    controller: _codeController,
                    errorMessage: widget.state.status == RelationshipControllerStatus.error
                        ? widget.state.message
                        : null,
                    isLoading: isLoading,
                    onSubmit: _submit,
                    workoutSetController: widget.workoutSetController,
                  ),
              ],
            ),
          ),
        ),
        RelationshipBottomNav(
          items: [
            const RelationshipBottomNavItem(
              icon: Icons.today_rounded,
              label: 'Dziś',
              active: true,
            ),
            const RelationshipBottomNavItem(
              icon: Icons.history_rounded,
              label: 'Historia',
            ),
            RelationshipBottomNavItem(
              icon: Icons.logout_rounded,
              label: 'Wyloguj',
              onTap: widget.onLogout,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final code = _codeController.text;
    final result = await widget.onClaimCode(code);
    if (result.isSuccess && mounted) {
      _codeController.clear();
    }
  }
}

class _TraineeHeader extends StatelessWidget {
  const _TraineeHeader({
    required this.user,
    required this.onLogout,
  });

  final AuthUser user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cześć,', style: TextStyle(color: lmMuted, fontSize: 14)),
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Wyloguj',
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
        ),
        RelationshipAvatar(label: user.displayName),
      ],
    );
  }
}

class _LinkedTrainerCard extends StatelessWidget {
  const _LinkedTrainerCard({
    required this.trainerName,
    required this.trainerEmail,
    required this.controller,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
    required this.workoutSetController,
  });

  final String trainerName;
  final String trainerEmail;
  final TextEditingController controller;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSubmit;
  final WorkoutSetController? workoutSetController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RelationshipCard(
          borderColor: lmBlue.withValues(alpha: 0.25),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RelationshipSectionLabel('Twój trener'),
              const SizedBox(height: 14),
              Row(
                children: [
                  RelationshipAvatar(label: trainerName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trainerEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: lmMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _AssignedSetsSection(controller: workoutSetController),
        const SizedBox(height: 22),
        _TrainerCodeForm(
          controller: controller,
          title: 'Zmień trenera',
          buttonLabel: 'Połącz z nowym trenerem',
          errorMessage: errorMessage,
          isLoading: isLoading,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _AssignedSetsSection extends StatelessWidget {
  const _AssignedSetsSection({required this.controller});

  final WorkoutSetController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const _NoAssignedSetCard();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state.status == WorkoutSetControllerStatus.loading &&
            state.traineeAssignedSets.isEmpty) {
          return const RelationshipCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.status == WorkoutSetControllerStatus.error &&
            state.traineeAssignedSets.isEmpty) {
          return RelationshipCard(
            child: Text(
              state.message ?? 'Nie udało się pobrać przypisanych zestawów.',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        if (state.traineeAssignedSets.isEmpty) {
          return const _NoAssignedSetCard();
        }

        return TraineeAssignedWorkoutSetView(sets: state.traineeAssignedSets);
      },
    );
  }
}

class _NoAssignedSetCard extends StatelessWidget {
  const _NoAssignedSetCard();

  @override
  Widget build(BuildContext context) {
    return const RelationshipCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RelationshipSectionLabel('Dzisiejszy trening'),
          SizedBox(height: 10),
          Text(
            'Plan treningowy nie jest jeszcze przypisany',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Gdy trener przypisze zestaw, zobaczysz tutaj ćwiczenia i parametry.',
            style: TextStyle(color: lmMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _UnlinkedTrainerCard extends StatelessWidget {
  const _UnlinkedTrainerCard({
    required this.controller,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _TrainerCodeForm(
      controller: controller,
      title: 'Połącz się z trenerem',
      subtitle: 'Wpisz kod, który otrzymasz od swojego trenera.',
      buttonLabel: 'Połącz konto',
      errorMessage: errorMessage,
      isLoading: isLoading,
      onSubmit: onSubmit,
    );
  }
}

class _TrainerCodeForm extends StatelessWidget {
  const _TrainerCodeForm({
    required this.controller,
    required this.title,
    required this.buttonLabel,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
    this.subtitle,
  });

  final TextEditingController controller;
  final String title;
  final String? subtitle;
  final String buttonLabel;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(color: lmMuted, height: 1.45)),
          ],
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('relationship-trainer-code-field'),
            controller: controller,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Kod trenera',
              counterText: '',
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
