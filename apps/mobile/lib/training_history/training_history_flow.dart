import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../relationships/relationship_screen_styles.dart';
import '../shared_sessions/shared_session_models.dart';
import '../widgets/motion/pressable_scale.dart';
import 'training_history_controller.dart';
import 'training_history_formatters.dart';
import 'training_history_models.dart';

class TrainingHistoryFlow extends StatefulWidget {
  const TrainingHistoryFlow({
    required this.controller,
    required this.viewerRole,
    required this.onClose,
    this.onAddFeedback,
    this.showLevelOneBack = false,
    super.key,
  });

  final TrainingHistoryController controller;
  final UserRole viewerRole;
  final VoidCallback onClose;
  final ValueChanged<String>? onAddFeedback;
  final bool showLevelOneBack;

  @override
  State<TrainingHistoryFlow> createState() => _TrainingHistoryFlowState();
}

class _TrainingHistoryFlowState extends State<TrainingHistoryFlow> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.state.status == TrainingHistoryStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.loadInitial();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final progress = state.progress;
        final detail = state.detail;
        if (progress != null) {
          return _ProgressLevel(
            progress: progress,
            loading: state.isLoadingNested,
            message: state.message,
            onBack: widget.controller.backFromProgress,
          );
        }
        if (detail != null) {
          return _DetailLevel(
            session: detail,
            loading: state.isLoadingNested,
            message: state.message,
            onBack: widget.controller.backFromDetail,
            onOpenProgress: widget.controller.openProgress,
            viewerRole: widget.viewerRole,
            onAddFeedback: widget.onAddFeedback,
          );
        }
        return _ListLevel(
          state: state,
          onClose: widget.onClose,
          onRetry: widget.controller.retry,
          onLoadMore: widget.controller.loadMore,
          onOpenSession: widget.controller.openSession,
          showBack: widget.showLevelOneBack,
        );
      },
    );
  }
}

class _ListLevel extends StatelessWidget {
  const _ListLevel({
    required this.state,
    required this.onClose,
    required this.onRetry,
    required this.onLoadMore,
    required this.onOpenSession,
    required this.showBack,
  });

  final TrainingHistoryState state;
  final VoidCallback onClose;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onOpenSession;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final initialLoading =
        state.status == TrainingHistoryStatus.loading && state.items.isEmpty;
    final initialError =
        state.status == TrainingHistoryStatus.error && state.items.isEmpty;

    return Column(
      children: [
        if (showBack)
          _HistoryHeader(title: 'Historia treningów', onBack: onClose),
        Expanded(
          child: initialLoading
              ? const Center(child: CircularProgressIndicator())
              : initialError
              ? _RetryState(
                  message: state.message ?? 'Nie udało się pobrać historii.',
                  onRetry: onRetry,
                )
              : state.items.isEmpty
              ? const _EmptyHistory()
              : ListView(
                  key: const ValueKey('training-history-list'),
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                  children: [
                    if (!showBack) ...[
                      const Text(
                        'Historia treningów',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      '${state.items.length} ukończonych sesji',
                      style: const TextStyle(color: lmMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 18),
                    for (final session in state.items)
                      _SessionCard(
                        session: session,
                        onTap: () => onOpenSession(session.id),
                      ),
                    if (state.paginationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        state.paginationError!,
                        key: const ValueKey('history-pagination-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      PressableScale(
                        child: TextButton(
                        onPressed: onRetry,
                        child: const Text('Spróbuj ponownie'),
                        ),
                      ),
                    ] else if (state.nextCursor != null) ...[
                      const SizedBox(height: 6),
                      Center(
                        child: state.isLoadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              )
                            : PressableScale(
                                child: OutlinedButton(
                                onPressed: onLoadMore,
                                child: const Text('Załaduj więcej'),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
        ),
        RelationshipBottomNav(
          items: [
            RelationshipBottomNavItem(
              icon: Icons.today_rounded,
              label: 'Dziś',
              onTap: onClose,
            ),
            const RelationshipBottomNavItem(
              icon: Icons.history_rounded,
              label: 'Historia',
              active: true,
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final TrainingHistorySessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = session.completedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        child: Material(
        color: lmSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: InkWell(
          key: ValueKey('history-session-${session.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: lmSurfaceAlt,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            formatHistoryDate(
                              date,
                            ).split(' ').elementAt(1).toUpperCase(),
                            style: const TextStyle(
                              color: lmMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.workoutSetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            formatHistoryDate(date),
                            style: const TextStyle(
                              color: lmMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: lmMutedDark),
                  ],
                ),
                const SizedBox(height: 13),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _MetricText(
                        formatHistoryDuration(session.durationSeconds),
                      ),
                    ),
                    Expanded(
                      child: _MetricText(
                        formatExerciseCount(session.exerciseCount),
                      ),
                    ),
                    Expanded(
                      child: _MetricText(
                        formatSeriesCount(session.seriesCount),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DetailLevel extends StatelessWidget {
  const _DetailLevel({
    required this.session,
    required this.loading,
    required this.message,
    required this.onBack,
    required this.onOpenProgress,
    required this.viewerRole,
    required this.onAddFeedback,
  });

  final TrainingHistorySession session;
  final bool loading;
  final String? message;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenProgress;
  final UserRole viewerRole;
  final ValueChanged<String>? onAddFeedback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _HistoryHeader(
              title: session.workoutSetName,
              subtitle: formatHistoryDate(session.completedAt),
              onBack: onBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: formatHistoryDuration(session.durationSeconds),
                          label: 'czas',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          value: '${session.exerciseCount}',
                          label: 'ćwiczeń',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          value: '${session.seriesCount}',
                          label: 'serii',
                        ),
                      ),
                    ],
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      message!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _HistoryFeedbackCard(
                    session: session,
                    viewerRole: viewerRole,
                    onAddFeedback: onAddFeedback,
                  ),
                  const SizedBox(height: 12),
                  for (final exercise in session.exercises)
                    _ExerciseCard(
                      exercise: exercise,
                      onTap: exercise.exerciseId == null
                          ? null
                          : () => onOpenProgress(exercise.exerciseId!),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (loading) const _NestedLoading(),
      ],
    );
  }
}

class _HistoryFeedbackCard extends StatelessWidget {
  const _HistoryFeedbackCard({
    required this.session,
    required this.viewerRole,
    required this.onAddFeedback,
  });

  final TrainingHistorySession session;
  final UserRole viewerRole;
  final ValueChanged<String>? onAddFeedback;

  @override
  Widget build(BuildContext context) {
    final feedback = session.feedback;
    return RelationshipCard(
      key: const ValueKey('history-feedback-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Feedback podopiecznego',
            style: TextStyle(
              color: lmMutedDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (feedback != null) ...[
            Text(
              'Samopoczucie: ${feedback.wellbeingRating}/5',
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _historyRatingLabel(feedback.wellbeingRating),
              style: const TextStyle(
                color: lmBlueSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              feedback.comment?.trim().isNotEmpty == true
                  ? feedback.comment!.trim()
                  : 'Bez komentarza',
              style: const TextStyle(color: lmMuted, height: 1.4),
            ),
          ] else if (viewerRole == UserRole.trainee && onAddFeedback != null)
            PressableScale(
              child: OutlinedButton(
              onPressed: () => onAddFeedback!(session.id),
              child: const Text('Dodaj feedback'),
              ),
            )
          else
            const Text('Brak feedbacku', style: TextStyle(color: lmMuted)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: lmMutedDark, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise, required this.onTap});

  final TrainingHistoryExercise exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        enabled: onTap != null,
        child: Material(
        color: lmSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: InkWell(
          key: exercise.exerciseId == null
              ? null
              : ValueKey('history-exercise-${exercise.exerciseId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (onTap != null)
                      const Text(
                        'postęp ›',
                        style: TextStyle(
                          color: lmBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${formatSeriesCount(exercise.series.length)} · najlepsza '
                  '${formatHistoryValue(exercise.maximumValue, exercise.type)}',
                  style: const TextStyle(color: lmMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final series in exercise.series)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: lmSurfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formatHistorySeries(series, exercise.type),
                          style: const TextStyle(
                            color: Color(0xFFC2C7CE),
                            fontFamily: 'Space Grotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _ProgressLevel extends StatelessWidget {
  const _ProgressLevel({
    required this.progress,
    required this.loading,
    required this.message,
    required this.onBack,
  });

  final ExerciseProgress progress;
  final bool loading;
  final String? message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final points = progress.points.length > 7
        ? progress.points.sublist(progress.points.length - 7)
        : progress.points;
    return Stack(
      children: [
        Column(
          children: [
            _HistoryHeader(title: 'Postęp ćwiczenia', onBack: onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                children: [
                  Text(
                    progress.exerciseName,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        formatHistoryValue(
                          progress.currentValue,
                          progress.type,
                        ),
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatSignedDelta(progress.overallDelta, progress.unit),
                        style: TextStyle(
                          color: _deltaColor(progress.overallDelta),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Start ${formatHistoryValue(progress.startValue, progress.type)}'
                    ' → dziś ${formatHistoryValue(progress.currentValue, progress.type)}',
                    style: const TextStyle(color: lmMuted, fontSize: 12.5),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 20),
                  RelationshipCard(
                    child: SizedBox(
                      key: const ValueKey('history-progress-chart'),
                      height: 168,
                      child: _ProgressChart(
                        points: points,
                        unit: progress.unit,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const RelationshipSectionLabel('Ostatnie wartości'),
                  const SizedBox(height: 11),
                  for (final point in progress.points.reversed)
                    _ProgressRow(point: point, progress: progress),
                ],
              ),
            ),
          ],
        ),
        if (loading) const _NestedLoading(),
      ],
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.points, required this.unit});

  final List<ExerciseProgressPoint> points;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('Brak danych do wykresu.'));
    }
    final maxValue = points.map((point) => point.value).reduce(math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < points.length; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    child: Text(
                      formatHistoryValue(points[index].value, _typeFor(unit)),
                      style: TextStyle(
                        color: index == points.length - 1
                            ? lmBlueSoft
                            : lmMutedDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: math.max(
                      16,
                      100 * (points[index].value / math.max(maxValue, 1)),
                    ),
                    decoration: BoxDecoration(
                      color: index == points.length - 1
                          ? lmBlue
                          : const Color(0xFF2C333D),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    child: Text(
                      formatHistoryShortDate(points[index].completedAt),
                      style: const TextStyle(color: lmMutedDark, fontSize: 9.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  ExerciseValueType _typeFor(String unit) => switch (unit) {
    'kg' => ExerciseValueType.repsWeight,
    's' => ExerciseValueType.time,
    _ => ExerciseValueType.repsOnly,
  };
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.point, required this.progress});

  final ExerciseProgressPoint point;
  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatHistoryDate(point.completedAt),
              style: const TextStyle(color: Color(0xFFC2C7CE), fontSize: 13),
            ),
          ),
          Text(
            formatHistoryValue(point.value, progress.type),
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 58,
            child: Text(
              point.delta == null
                  ? '—'
                  : formatSignedDelta(point.delta!, progress.unit),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: point.delta == null
                    ? lmMutedDark
                    : _deltaColor(point.delta!),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 8),
      child: Row(
        children: [
          PressableScale(
            child: IconButton(
            tooltip: 'Wróć',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: lmMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_toggle_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            PressableScale(
              child: FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 44, color: lmMuted),
            SizedBox(height: 12),
            Text(
              'Brak ukończonych treningów.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 5),
            Text(
              'Historia pojawi się po zakończeniu i zapisaniu treningu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: lmMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NestedLoading extends StatelessWidget {
  const _NestedLoading();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x66000000),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Color _deltaColor(num value) {
  if (value > 0) return lmGreen;
  if (value < 0) return const Color(0xFFEF6B6B);
  return lmMutedDark;
}

String _historyRatingLabel(int rating) {
  return switch (rating) {
    1 => 'Bardzo źle',
    2 => 'Źle',
    3 => 'W porządku',
    4 => 'Dobrze',
    5 => 'Bardzo dobrze',
    _ => '',
  };
}
