import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import 'relationship_controller.dart';
import 'relationship_models.dart';
import 'relationship_screen_styles.dart';

class TrainerDashboardScreen extends StatelessWidget {
  const TrainerDashboardScreen({
    required this.user,
    required this.state,
    required this.onOpenTrainee,
    required this.onReload,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final RelationshipControllerState state;
  final ValueChanged<TrainerTraineeSummary> onOpenTrainee;
  final Future<void> Function() onReload;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final summary = state.trainerSummary;
    final trainees = summary?.trainees ?? const <TrainerTraineeSummary>[];

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
                    const Expanded(
                      child: _CounterCard(
                        value: '0',
                        label: 'aktywnych sesji',
                        accent: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InviteCodeCard(code: summary?.inviteCode, isLoading: state.status == RelationshipControllerStatus.loading),
                const SizedBox(height: 24),
                const RelationshipSectionLabel('Podopieczni'),
                const SizedBox(height: 12),
                if (state.status == RelationshipControllerStatus.loading && summary == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.status == RelationshipControllerStatus.error && summary == null)
                  _ErrorState(message: state.message ?? 'Nie udało się pobrać relacji.')
                else if (trainees.isEmpty)
                  const _TrainerEmptyState()
                else
                  ...trainees.map(
                    (trainee) => _TraineeListItem(
                      trainee: trainee,
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
            const RelationshipBottomNavItem(
              icon: Icons.fitness_center_rounded,
              label: 'Zestawy',
            ),
            const RelationshipBottomNavItem(
              icon: Icons.play_circle_rounded,
              label: 'Trening',
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
  const _TrainerHeader({
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
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: lmText,
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
  });

  final String? code;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      borderColor: lmBlue.withValues(alpha: 0.25),
      child: Row(
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading && code == null ? 'Ładowanie kodu' : (code ?? 'Niedostępny'),
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
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Zaproś podopiecznego'),
          ),
        ],
      ),
    );
  }
}

class _TraineeListItem extends StatelessWidget {
  const _TraineeListItem({
    required this.trainee,
    required this.onTap,
  });

  final TrainerTraineeSummary trainee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: lmMutedDark),
              ],
            ),
          ),
        ),
      ),
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
