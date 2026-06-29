import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../trainer_guidance/trainer_guidance_controller.dart';
import '../trainer_guidance/trainer_guidance_models.dart';
import '../workout_sets/workout_set_text.dart';
import 'relationship_models.dart';
import 'relationship_formatters.dart';
import 'relationship_screen_styles.dart';

class TrainerTraineeDetailScreen extends StatelessWidget {
  const TrainerTraineeDetailScreen({
    required this.trainee,
    required this.onBack,
    required this.onLogout,
    required this.onOpenWorkoutSets,
    this.onOpenHistory,
    this.assignedSets = const [],
    this.guidanceController,
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
  final TrainerGuidanceController? guidanceController;
  final void Function(AssignedWorkoutSetSummary set)? onStartSession;
  final VoidCallback? onJoinActiveSession;
  final String? sessionErrorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
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
                        Text(
                          formatTraineeConnectionStatus(
                            trainee.displayName,
                            trainee.connectedAt,
                          ),
                          style: const TextStyle(
                            color: lmMuted,
                            fontSize: 13.5,
                          ),
                        ),
                        if (trainee.activeSession != null) ...[
                          const SizedBox(height: 8),
                          const _ActiveStatusPill(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _WeeklyStreakStats(summary: trainee.weeklyStreak),
                ],
              ),
              if (trainee.activeSession != null &&
                  onJoinActiveSession != null) ...[
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
                        key: const ValueKey('trainer-open-trainee-history'),
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
              if (guidanceController != null) ...[
                const SizedBox(height: 18),
                _GuidanceSection(controller: guidanceController!),
              ],
              const SizedBox(height: 20),
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
              icon: Icons.menu_rounded,
              label: 'Profil',
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyStreakStats extends StatelessWidget {
  const _WeeklyStreakStats({required this.summary});

  final WeeklyStreakSummary summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatWeeklyStreakFlame(summary.currentStreak),
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'najlepsza ${summary.bestStreak}',
            maxLines: 1,
            style: const TextStyle(color: lmMutedDark, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _GuidanceSection extends StatelessWidget {
  const _GuidanceSection({required this.controller});

  final TrainerGuidanceController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state.status == TrainerGuidanceStatus.loaded &&
            state.items.isEmpty) {
          return const SizedBox.shrink();
        }

        if (state.status == TrainerGuidanceStatus.loading ||
            state.status == TrainerGuidanceStatus.idle) {
          return const SizedBox.shrink();
        }

        if (state.status == TrainerGuidanceStatus.error) {
          if (state.message == 'API_BASE_URL is not configured.') {
            return const SizedBox.shrink();
          }
          return RelationshipCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Podpowiedzi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 10),
                Text(
                  state.message ??
                      'Nie udało się pobrać podpowiedzi, spróbuj ponownie.',
                  style: const TextStyle(color: lmMuted, height: 1.45),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.load,
                  child: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          );
        }

        final visibleItems = state.items.take(3).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Podpowiedzi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'Na podstawie 3 ostatnich treningów',
              style: TextStyle(color: lmMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final item in visibleItems)
              _GuidanceCard(
                guidance: item,
                isMarkingRead: state.markingReadId == item.id,
                onMarkAsRead: () => controller.markAsRead(item.id),
              ),
            if (state.message != null) ...[
              const SizedBox(height: 6),
              Text(
                state.message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.guidance,
    required this.isMarkingRead,
    required this.onMarkAsRead,
  });

  final TrainerGuidance guidance;
  final bool isMarkingRead;
  final VoidCallback onMarkAsRead;

  @override
  Widget build(BuildContext context) {
    final evidenceText = _evidenceText(guidance);
    final style = _GuidanceVisualStyle.forType(guidance.type);
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: style.cardColor,
      borderColor: style.borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title(guidance),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _GuidanceBadge(style: style),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isMarkingRead ? null : onMarkAsRead,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                isMarkingRead ? 'Oznaczanie...' : 'Oznacz jako przeczytaną',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(guidance.message, style: const TextStyle(height: 1.45)),
          if (evidenceText != null) ...[
            const SizedBox(height: 10),
            Text(
              evidenceText,
              style: const TextStyle(color: lmMuted, fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }

  static String _title(TrainerGuidance guidance) {
    return switch (guidance.type) {
      TrainerGuidanceType.weightStagnation => 'Stagnacja ciężaru',
      TrainerGuidanceType.lowWellbeing => 'Niższe samopoczucie',
      TrainerGuidanceType.unknown => 'Podpowiedź',
    };
  }

  static String? _evidenceText(TrainerGuidance guidance) {
    if (guidance.weightEvidence.isNotEmpty) {
      return guidance.weightEvidence
          .map((item) => '${_formatNumber(item.maxWeight)} kg')
          .join(' → ');
    }
    if (guidance.wellbeingEvidence.isNotEmpty) {
      final ratings = guidance.wellbeingEvidence
          .map((item) => item.rating.toString())
          .join(', ');
      final average = guidance.averageRating;
      if (average == null) {
        return 'Oceny: $ratings';
      }
      return 'Oceny: $ratings · średnia ${_formatNumber(average)}/5';
    }
    return null;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _GuidanceBadge extends StatelessWidget {
  const _GuidanceBadge({required this.style});

  final _GuidanceVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.badgeColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.badgeBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          style.label,
          style: TextStyle(
            color: style.badgeTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GuidanceVisualStyle {
  const _GuidanceVisualStyle({
    required this.label,
    required this.cardColor,
    required this.borderColor,
    required this.badgeColor,
    required this.badgeBorderColor,
    required this.badgeTextColor,
  });

  final String label;
  final Color cardColor;
  final Color borderColor;
  final Color badgeColor;
  final Color badgeBorderColor;
  final Color badgeTextColor;

  static _GuidanceVisualStyle forType(TrainerGuidanceType type) {
    return switch (type) {
      TrainerGuidanceType.weightStagnation => _GuidanceVisualStyle(
        label: 'stagnacja',
        cardColor: const Color(0x1A3A82F6),
        borderColor: const Color(0x473A82F6),
        badgeColor: const Color(0x263A82F6),
        badgeBorderColor: const Color(0x473A82F6),
        badgeTextColor: lmBlueSoft,
      ),
      TrainerGuidanceType.lowWellbeing => const _GuidanceVisualStyle(
        label: 'samopoczucie',
        cardColor: Color(0x14FFC107),
        borderColor: Color(0x3DFFC107),
        badgeColor: Color(0x1FFFC107),
        badgeBorderColor: Color(0x3DFFC107),
        badgeTextColor: Color(0xFFD7B36A),
      ),
      TrainerGuidanceType.unknown => _GuidanceVisualStyle(
        label: 'info',
        cardColor: lmSurface,
        borderColor: Colors.white.withValues(alpha: 0.07),
        badgeColor: lmBlue.withValues(alpha: 0.14),
        badgeBorderColor: lmBlue.withValues(alpha: 0.28),
        badgeTextColor: lmBlueSoft,
      ),
    };
  }
}

class _AssignedSetCard extends StatelessWidget {
  const _AssignedSetCard({required this.set, required this.onStartSession});

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
