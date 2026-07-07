import 'package:flutter/material.dart';

import '../relationships/relationship_screen_styles.dart';
import '../widgets/motion/motion_reveals.dart';
import '../widgets/motion/pressable_scale.dart';
import 'workout_set_api_client.dart';
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

  Future<void> _deleteSet(
    BuildContext context,
    WorkoutSetSummary workoutSet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Usunąć zestaw „${workoutSet.name}”?'),
        content: const Text(
          'Zestaw zniknie z listy i nie będzie można przypisać go ponownie.',
        ),
        actions: [
          PressableScale(
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Anuluj'),
            ),
          ),
          PressableScale(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD94A4A),
              ),
              child: const Text('Usuń'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await controller.deleteSet(workoutSet.id);
    if (!context.mounted) {
      return;
    }

    final message = switch (result.status) {
      WorkoutSetApiStatus.success =>
        'Zestaw „${workoutSet.name}” został usunięty.',
      WorkoutSetApiStatus.conflict =>
        'Nie można usunąć zestawu podczas aktywnej sesji.',
      _ => 'Nie udało się usunąć zestawu. Spróbuj ponownie.',
    };
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
                child: MotionStaggerScope(
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
                    if (state.status == WorkoutSetControllerStatus.loading &&
                        sets.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (state.status == WorkoutSetControllerStatus.error &&
                        sets.isEmpty)
                      RelationshipCard(
                        child: Text(
                          state.message ?? 'Nie udało się pobrać zestawów.',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else ...[
                      for (final set in sets)
                        StaggeredReveal(
                          position: sets.indexOf(set),
                          child: _WorkoutSetCard(
                            set: set,
                            onEdit: () => onEditSet(set),
                            onAssign: () => onAssignSet(set),
                            onDelete: () => _deleteSet(context, set),
                            isDeleting: state.deletingSetId == set.id,
                          ),
                        ),
                      _NewSetButton(onPressed: onCreateSet),
                    ],
                  ],
                ),
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
    required this.onDelete,
    required this.isDeleting,
  });

  final WorkoutSetSummary set;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onDelete;
  final bool isDeleting;

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
              const SizedBox(width: 6),
              if (isDeleting)
                const SizedBox.square(
                  dimension: 30,
                  child: Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PressableScale(
                  child: PopupMenuButton<_WorkoutSetAction>(
                    key: ValueKey('workout-set-menu-${set.id}'),
                    tooltip: 'Więcej',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert_rounded),
                    iconSize: 20,
                    color: const Color(0xFF22262E),
                    position: PopupMenuPosition.under,
                    constraints: const BoxConstraints(minWidth: 168),
                    onSelected: (_) => onDelete(),
                    itemBuilder: (context) => const [
                      PopupMenuItem<_WorkoutSetAction>(
                        value: _WorkoutSetAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Color(0xFFFF8D8D),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Usuń zestaw',
                              style: TextStyle(
                                color: Color(0xFFFF8D8D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                child: PressableScale(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edytuj'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  child: FilledButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('Przypisz'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _WorkoutSetAction { delete }

class _NewSetButton extends StatelessWidget {
  const _NewSetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nowy zestaw'),
        style: OutlinedButton.styleFrom(
          foregroundColor: lmBlueSoft,
          side: BorderSide(color: lmBlue.withValues(alpha: 0.45), width: 1.5),
          backgroundColor: lmBlue.withValues(alpha: 0.08),
          minimumSize: const Size.fromHeight(54),
        ),
      ),
    );
  }
}
