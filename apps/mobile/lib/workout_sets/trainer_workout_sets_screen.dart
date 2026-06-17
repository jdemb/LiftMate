import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import 'workout_set_controller.dart';
import 'workout_set_models.dart';
import 'workout_set_text.dart';

class TrainerWorkoutSetsScreen extends StatelessWidget {
  const TrainerWorkoutSetsScreen({
    required this.controller,
    required this.onReload,
    required this.onOpenDashboard,
    required this.onCreateSet,
    required this.onEditSet,
    required this.onAssignSet,
    required this.onLogout,
    super.key,
  });

  final WorkoutSetController controller;
  final Future<void> Function() onReload;
  final VoidCallback onOpenDashboard;
  final VoidCallback onCreateSet;
  final ValueChanged<WorkoutSetSummary> onEditSet;
  final ValueChanged<WorkoutSetSummary> onAssignSet;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final sets = state.trainerSets;

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: onReload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                  children: [
                    const Text(
                      'Moje zestawy',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Szablony globalne - przypisz je dowolnemu podopiecznemu',
                      style: TextStyle(color: lmMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),
                    if (state.status == WorkoutSetControllerStatus.loading && sets.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (state.status == WorkoutSetControllerStatus.error && sets.isEmpty)
                      RelationshipCard(
                        child: Text(
                          state.message ?? 'Nie udało się pobrać zestawów.',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else ...[
                      for (final set in sets)
                        _WorkoutSetCard(
                          set: set,
                          onEdit: () => onEditSet(set),
                          onAssign: () => onAssignSet(set),
                        ),
                      _NewSetButton(onPressed: onCreateSet),
                    ],
                  ],
                ),
              ),
            ),
            RelationshipBottomNav(
              items: [
                RelationshipBottomNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Pulpit',
                  onTap: onOpenDashboard,
                ),
                const RelationshipBottomNavItem(
                  icon: Icons.fitness_center_rounded,
                  label: 'Zestawy',
                  active: true,
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
      },
    );
  }
}

class _WorkoutSetCard extends StatelessWidget {
  const _WorkoutSetCard({
    required this.set,
    required this.onEdit,
    required this.onAssign,
  });

  final WorkoutSetSummary set;
  final VoidCallback onEdit;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  set.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 17.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: lmBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'globalny',
                  style: TextStyle(
                    color: lmBlueSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${exerciseCountLabel(set.exerciseCount)} · ${set.rowCount} serii',
            style: const TextStyle(color: lmMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            'Przypisany: ${set.assignedTrainees} podopiecznych',
            style: const TextStyle(color: lmMutedDark, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edytuj'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Przypisz'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewSetButton extends StatelessWidget {
  const _NewSetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nowy zestaw'),
      style: OutlinedButton.styleFrom(
        foregroundColor: lmBlueSoft,
        side: BorderSide(color: lmBlue.withValues(alpha: 0.45), width: 1.5),
        backgroundColor: lmBlue.withValues(alpha: 0.08),
        minimumSize: const Size.fromHeight(54),
      ),
    );
  }
}
