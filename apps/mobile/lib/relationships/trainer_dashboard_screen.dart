import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'relationship_controller.dart';
import 'relationship_formatters.dart';
import 'relationship_models.dart';
import 'relationship_screen_styles.dart';
import '../widgets/motion/pressable_scale.dart';

class TrainerDashboardScreen extends StatelessWidget {
  const TrainerDashboardScreen({
    required this.user,
    required this.state,
    required this.onOpenTrainee,
    required this.onOpenWorkoutSets,
    required this.onCopyInviteCode,
    required this.onReload,
    required this.onLogout,
    this.openingTraineeId,
    super.key,
  });

  final AuthUser user;
  final RelationshipControllerState state;
  final ValueChanged<TrainerTraineeSummary> onOpenTrainee;
  final VoidCallback onOpenWorkoutSets;
  final Future<void> Function(String code) onCopyInviteCode;
  final Future<void> Function() onReload;
  final Future<void> Function() onLogout;
  final String? openingTraineeId;

  @override
  Widget build(BuildContext context) {
    final summary = state.trainerSummary;
    final trainees = summary?.trainees ?? const <TrainerTraineeSummary>[];
    final activeCount = trainees
        .where((trainee) => trainee.activeSession != null)
        .length;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onReload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              children: [
                _TrainerHeader(user: user, onLogout: onLogout),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _CounterCard(
                        value: trainees.length.toString(),
                        label: 'podopiecznych',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CounterCard(
                        value: activeCount.toString(),
                        label: 'aktywnych sesji',
                        accent: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InviteCodeCard(
                  code: summary?.inviteCode,
                  isLoading:
                      state.status == RelationshipControllerStatus.loading,
                  onCopy: onCopyInviteCode,
                ),
                const SizedBox(height: 24),
                const RelationshipSectionLabel('Podopieczni'),
                const SizedBox(height: 12),
                if (state.status == RelationshipControllerStatus.loading &&
                    summary == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.status == RelationshipControllerStatus.error &&
                    summary == null)
                  _ErrorState(
                    message: state.message ?? 'Nie udało się pobrać relacji.',
                  )
                else if (state.status == RelationshipControllerStatus.error)
                  _ErrorState(
                    message: state.message ?? 'Nie udało się pobrać relacji.',
                  )
                else if (trainees.isEmpty)
                  const _TrainerEmptyState()
                else
                  ...trainees.map(
                    (trainee) => _TraineeListItem(
                      trainee: trainee,
                      isOpening: openingTraineeId == trainee.id,
                      isDisabled: openingTraineeId != null,
                      onTap: () => onOpenTrainee(trainee),
                    ),
                  ),
              ],
            ),
          ),
        ),
        RelationshipBottomNav(
          items: [
            const RelationshipBottomNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Pulpit',
              active: true,
            ),
            RelationshipBottomNavItem(
              icon: Icons.fitness_center_rounded,
              label: 'Zestawy',
              onTap: onOpenWorkoutSets,
            ),
            RelationshipBottomNavItem(
              icon: Icons.logout_rounded,
              label: 'Wyloguj',
              onTap: onLogout,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrainerHeader extends StatelessWidget {
  const _TrainerHeader({required this.user, required this.onLogout});

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
              const Text(
                'Cześć,',
                style: TextStyle(color: lmMuted, fontSize: 14),
              ),
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: lmText,
                ),
              ),
            ],
          ),
        ),
        PressableScale(
          child: IconButton(
            tooltip: 'Wyloguj',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ),
        RelationshipAvatar(label: user.displayName),
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: accent ? lmBlue : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: lmMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.isLoading,
    required this.onCopy,
  });

  final String? code;
  final bool isLoading;
  final Future<void> Function(String code) onCopy;

  @override
  Widget build(BuildContext context) {
    final canCopy = code != null && code!.trim().isNotEmpty;

    return RelationshipCard(
      borderColor: lmBlue.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: lmBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: lmBlueSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Twój kod zaproszenia',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading && code == null
                          ? 'Ładowanie kodu'
                          : (code ?? 'Niedostępny'),
                      style: const TextStyle(color: lmBlueSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                code ?? '------',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PressableScale(
              enabled: canCopy,
              child: Tooltip(
                message: 'Kopiuj kod zaproszenia',
                child: TextButton.icon(
                key: const ValueKey('copy-trainer-invite-code-dashboard'),
                onPressed: canCopy ? () => onCopy(code!) : null,
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Kopiuj kod'),
                style: TextButton.styleFrom(
                  foregroundColor: lmBlueSoft,
                  backgroundColor: lmBlue.withValues(alpha: 0.16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerEmptyState extends StatelessWidget {
  const _TrainerEmptyState();

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Brak podopiecznych',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Udostępnij kod zaproszenia, żeby połączyć pierwszą osobę z kontem trenera.',
            style: TextStyle(color: lmMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          PressableScale(
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Zaproś podopiecznego'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraineeListItem extends StatelessWidget {
  const _TraineeListItem({
    required this.trainee,
    required this.isOpening,
    required this.isDisabled,
    required this.onTap,
  });

  final TrainerTraineeSummary trainee;
  final bool isOpening;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        enabled: !isDisabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isDisabled ? null : onTap,
            child: RelationshipCard(
            child: Row(
              children: [
                RelationshipAvatar(label: trainee.displayName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainee.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trainee.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: lmMuted, fontSize: 12.5),
                      ),
                      if (trainee.activeSession != null) ...[
                        const SizedBox(height: 7),
                        const _ActiveSessionBadge(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trainee.weeklyStreak.lastCompletedWorkoutAt == null
                            ? 'nie zaczął'
                            : formatLastWorkout(
                                trainee.weeklyStreak.lastCompletedWorkoutAt,
                              ),
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: lmMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatWeeklyStreakFlame(
                          trainee.weeklyStreak.currentStreak,
                        ),
                        style: const TextStyle(
                          color: lmMutedDark,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (isOpening)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: lmMutedDark),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionBadge extends StatelessWidget {
  const _ActiveSessionBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFF21C97A),
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 8, height: 8),
        ),
        SizedBox(width: 7),
        Text(
          'Aktywna sesja',
          style: TextStyle(
            color: Color(0xFF7EE0AD),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
