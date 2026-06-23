import 'package:flutter/material.dart';

import '../workout_sets/workout_set_text.dart';
import 'relationship_models.dart';
import 'relationship_screen_styles.dart';

class TrainerTraineeDetailScreen extends StatelessWidget {
  const TrainerTraineeDetailScreen({
    required this.trainee,
    required this.onBack,
    required this.onLogout,
    required this.onOpenWorkoutSets,
    this.onOpenHistory,
    this.assignedSets = const [],
    this.onStartSession,
    this.onJoinActiveSession,
    this.sessionErrorMessage,
    super.key,
  });

  final TrainerTraineeSummary trainee;
  final VoidCallback onBack;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenWorkoutSets;
  final VoidCallback? onOpenHistory;
  final List<AssignedWorkoutSetSummary> assignedSets;
  final void Function(AssignedWorkoutSetSummary set)? onStartSession;
  final VoidCallback? onJoinActiveSession;
  final String? sessionErrorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Wróć',
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Podopieczny',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Wyloguj',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  RelationshipAvatar(label: trainee.displayName, size: 62),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainee.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Połączona',
                          style: TextStyle(color: lmMuted, fontSize: 13.5),
                        ),
                        if (trainee.activeSession != null) ...[
                          const SizedBox(height: 8),
                          const _ActiveStatusPill(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (trainee.activeSession != null && onJoinActiveSession != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onJoinActiveSession,
                  icon: const Icon(Icons.play_circle_rounded),
                  label: const Text('Dołącz do sesji'),
                ),
              ],
              if (sessionErrorMessage != null) ...[
                const SizedBox(height: 12),
                RelationshipCard(
                  child: Text(
                    sessionErrorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
              if (onOpenHistory != null) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'trainer-open-trainee-history',
                        ),
                        onPressed: onOpenHistory,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Historia'),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onOpenWorkoutSets,
                        child: const Text('Zmień zestaw'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              RelationshipCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RelationshipSectionLabel('Dane relacji'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'E-mail', value: trainee.email),
                    const SizedBox(height: 10),
                    const _DetailRow(label: 'Status', value: 'Aktywna relacja'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RelationshipSectionLabel('Przypisane zestawy'),
              const SizedBox(height: 12),
              if (assignedSets.isEmpty)
                const RelationshipCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brak przypisanego zestawu',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Zestawy treningowe pojawią się tutaj po przypisaniu przez trenera.',
                        style: TextStyle(color: lmMuted, height: 1.45),
                      ),
                    ],
                  ),
                )
              else
                for (final set in assignedSets)
                  _AssignedSetCard(
                    set: set,
                    onStartSession:
                        trainee.activeSession == null && onStartSession != null
                            ? () => onStartSession!(set)
                            : null,
                  ),
            ],
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
            const RelationshipBottomNavItem(
              icon: Icons.play_circle_rounded,
              label: 'Trening',
            ),
            const RelationshipBottomNavItem(
              icon: Icons.menu_rounded,
              label: 'Profil',
            ),
          ],
        ),
      ],
    );
  }
}

class _AssignedSetCard extends StatelessWidget {
  const _AssignedSetCard({
    required this.set,
    required this.onStartSession,
  });

  final AssignedWorkoutSetSummary set;
  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            set.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${exerciseCountLabel(set.exerciseCount)} · ${set.rowCount} serii',
            style: const TextStyle(color: lmMuted, fontSize: 13),
          ),
          if (onStartSession != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onStartSession,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Rozpocznij wspólny trening'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveStatusPill extends StatelessWidget {
  const _ActiveStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF21C97A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Aktywna sesja',
        style: TextStyle(
          color: Color(0xFF7EE0AD),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: lmMuted)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
