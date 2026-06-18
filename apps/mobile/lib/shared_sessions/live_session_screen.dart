import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../relationships/relationship_screen_styles.dart';
import 'shared_session_controller.dart';
import 'shared_session_models.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    required this.user,
    required this.controller,
    required this.editable,
    required this.onBack,
    this.trainerDisplayName,
    this.onSessionClosed,
    super.key,
  });

  final AuthUser user;
  final SharedSessionController controller;
  final bool editable;
  final VoidCallback onBack;
  final String? trainerDisplayName;
  final Future<void> Function()? onSessionClosed;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  static const _restTotal = 90;

  int _currentExerciseIndex = 0;
  int _restRemaining = _restTotal;
  Timer? _restTimer;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final session = state.session;

        if (state.status == SharedSessionControllerStatus.loading &&
            session == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (session == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            children: [
              _LiveTopBar(
                title: 'Trening live',
                subtitle: null,
                onBack: widget.onBack,
              ),
              const SizedBox(height: 18),
              RelationshipCard(
                child: Text(
                  state.message ?? 'Nie załadowano aktywnej sesji.',
                  style: const TextStyle(color: lmMuted),
                ),
              ),
            ],
          );
        }

        final groups = _groupValues(session.values);
        if (groups.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            children: [
              _LiveTopBar(
                title: 'Trening live',
                subtitle: _sessionSubtitle(session),
                onBack: widget.onBack,
              ),
              const SizedBox(height: 18),
              const RelationshipCard(
                child: Text(
                  'Sesja nie ma żadnych serii.',
                  style: TextStyle(color: lmMuted),
                ),
              ),
            ],
          );
        }

        final currentIndex = _currentExerciseIndex.clamp(0, groups.length - 1);
        final currentGroup = groups[currentIndex];

        if (!widget.editable) {
          return _ReadOnlyLiveView(
            session: session,
            trainerDisplayName: widget.trainerDisplayName,
            group: currentGroup,
            exerciseIndex: currentIndex,
            exerciseTotal: groups.length,
            restRemaining: _restRemaining,
            onBack: widget.onBack,
          );
        }

        return Column(
          children: [
            _LiveTopBar(
              title: session.traineeEmail,
              subtitle: _sessionSubtitle(session),
              onBack: widget.onBack,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                children: [
                  Text(
                    'Ćwiczenie ${currentIndex + 1} / ${groups.length}',
                    style: const TextStyle(
                      color: lmBlueSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentGroup.exerciseName,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final value in currentGroup.values)
                    _EditableSetCard(
                      user: widget.user,
                      controller: widget.controller,
                      value: value,
                    ),
                  const SizedBox(height: 6),
                  _RestTimerCard(
                    remaining: _restRemaining,
                    total: _restTotal,
                    onStart: _startRest,
                    onPause: _pauseRest,
                    onAdd: _addRest,
                    onReset: _resetRest,
                  ),
                  const SizedBox(height: 14),
                  _NextExerciseCard(
                    name: currentIndex + 1 < groups.length
                        ? groups[currentIndex + 1].exerciseName
                        : 'Koniec treningu',
                    onNext: currentIndex + 1 < groups.length
                        ? () => setState(() => _currentExerciseIndex = currentIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: FilledButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Zakończ i zapisz trening'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF21C97A).withValues(alpha: 0.16),
                  foregroundColor: const Color(0xFF7EE0AD),
                  side: BorderSide(
                    color: const Color(0xFF21C97A).withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finishSession() async {
    final result = await widget.controller.complete(widget.user);
    if (!mounted || !result.isSuccess) {
      return;
    }

    await widget.onSessionClosed?.call();
  }

  void _startRest() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restRemaining <= 1) {
        timer.cancel();
        setState(() => _restRemaining = 0);
        return;
      }
      setState(() => _restRemaining -= 1);
    });
  }

  void _pauseRest() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  void _addRest() {
    setState(() => _restRemaining += 15);
  }

  void _resetRest() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() => _restRemaining = _restTotal);
  }
}

class _LiveTopBar extends StatelessWidget {
  const _LiveTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Wróć',
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: lmMutedDark, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const _LiveBadge(),
        ],
      ),
    );
  }
}

class _ReadOnlyLiveView extends StatelessWidget {
  const _ReadOnlyLiveView({
    required this.session,
    required this.trainerDisplayName,
    required this.group,
    required this.exerciseIndex,
    required this.exerciseTotal,
    required this.restRemaining,
    required this.onBack,
  });

  final SharedSession session;
  final String? trainerDisplayName;
  final _ExerciseValueGroup group;
  final int exerciseIndex;
  final int exerciseTotal;
  final int restRemaining;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final current = _firstOpenValue(group.values);
    final completed = session.values.where((value) => value.isDone).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 0.9,
          colors: [Color(0x292F6FD6), Color(0xFF0A0C10)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: SizedBox(
              key: const ValueKey('read-only-live-header'),
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Wróć',
                          onPressed: onBack,
                          icon: const Icon(Icons.chevron_left_rounded, size: 30),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 112,
                        ),
                        child: Row(
                          key: const ValueKey(
                            'read-only-live-trainer-status',
                          ),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF4D4D),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                _readOnlySessionLabel(
                                  session,
                                  trainerDisplayName,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFF8D8D),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ćwiczenie ${exerciseIndex + 1} / $exerciseTotal',
                    style: const TextStyle(
                      color: lmBlueSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    group.exerciseName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Seria ${current.setIndex} / ${group.values.length}',
                    style: const TextStyle(color: lmMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _primaryValueLabel(current),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 70,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _secondaryValueLabel(current),
                    style: const TextStyle(
                      color: Color(0xFFC2C7CE),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      'Ukończone serie: $completed',
                      style: const TextStyle(
                        color: Color(0xFF7EE0AD),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ReadOnlyRestFooter(restRemaining: restRemaining),
        ],
      ),
    );
  }
}

class _EditableSetCard extends StatelessWidget {
  const _EditableSetCard({
    required this.user,
    required this.controller,
    required this.value,
  });

  final AuthUser user;
  final SharedSessionController controller;
  final SharedSessionValue value;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderColor: value.isDone
          ? const Color(0xFF21C97A).withValues(alpha: 0.32)
          : Colors.white.withValues(alpha: 0.07),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seria ${value.setIndex}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC2C7CE),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 40,
                child: IconButton(
                  tooltip: value.isDone ? 'Cofnij serię' : 'Oznacz serię',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () => controller.toggleDone(
                    user: user,
                    value: value,
                    isDone: !value.isDone,
                  ),
                  icon: Icon(
                    value.isDone
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: value.isDone ? const Color(0xFF21C97A) : lmMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (value.exerciseType == ExerciseValueType.repsWeight)
            Row(
              children: [
                Expanded(
                  child: _ValueStepper(
                    label: 'Ciężar',
                    value: '${_formatNumber(value.weight ?? 0)} kg',
                    onDecrease: () => _nudgeWeight(-2.5),
                    onIncrease: () => _nudgeWeight(2.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ValueStepper(
                    label: 'Powt.',
                    value: '${value.reps ?? 0}',
                    onDecrease: () => _nudgeReps(-1),
                    onIncrease: () => _nudgeReps(1),
                  ),
                ),
              ],
            )
          else if (value.exerciseType == ExerciseValueType.repsOnly)
            _ValueStepper(
              label: 'Powtórzenia',
              value: '${value.reps ?? 0}',
              onDecrease: () => _nudgeReps(-1),
              onIncrease: () => _nudgeReps(1),
            )
          else
            _ValueStepper(
              label: 'Czas',
              value: '${value.seconds ?? 0} s',
              onDecrease: () => _nudgeSeconds(-5),
              onIncrease: () => _nudgeSeconds(5),
            ),
        ],
      ),
    );
  }

  void _nudgeReps(int delta) {
    controller.updateValue(
      user: user,
      valueId: value.id,
      value: UpdateSharedSessionValue(
        reps: ((value.reps ?? 0) + delta).clamp(0, 999),
        weight: value.weight,
        seconds: value.seconds,
        isDone: value.isDone,
      ),
    );
  }

  void _nudgeWeight(double delta) {
    controller.updateValue(
      user: user,
      valueId: value.id,
      value: UpdateSharedSessionValue(
        reps: value.reps,
        weight: ((value.weight ?? 0) + delta).clamp(0, 9999).toDouble(),
        seconds: value.seconds,
        isDone: value.isDone,
      ),
    );
  }

  void _nudgeSeconds(int delta) {
    controller.updateValue(
      user: user,
      valueId: value.id,
      value: UpdateSharedSessionValue(
        reps: value.reps,
        weight: value.weight,
        seconds: ((value.seconds ?? 0) + delta).clamp(0, 9999),
        isDone: value.isDone,
      ),
    );
  }
}

class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.label,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: lmMutedDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _RoundStepButton(icon: Icons.remove_rounded, onTap: onDecrease),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _RoundStepButton(
              icon: Icons.add_rounded,
              onTap: onIncrease,
              highlighted: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filled(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: highlighted ? lmBlue : const Color(0xFF22262E),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}

class _RestTimerCard extends StatelessWidget {
  const _RestTimerCard({
    required this.remaining,
    required this.total,
    required this.onStart,
    required this.onPause,
    required this.onAdd,
    required this.onReset,
  });

  final int remaining;
  final int total;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    return RelationshipCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'ODPOCZYNEK',
                style: TextStyle(
                  color: lmMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(remaining),
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: lmBlue,
              backgroundColor: const Color(0xFF22262E),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Start'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton(
                  onPressed: onPause,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Pauza'),
                ),
              ),
              const SizedBox(width: 9),
              OutlinedButton(
                onPressed: onAdd,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(58, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('+15s'),
              ),
              const SizedBox(width: 9),
              SizedBox.square(
                dimension: 44,
                child: IconButton.outlined(
                  tooltip: 'Reset',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextExerciseCard extends StatelessWidget {
  const _NextExerciseCard({
    required this.name,
    required this.onNext,
  });

  final String name;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NASTĘPNE',
                  style: TextStyle(
                    color: lmMutedDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onNext,
            child: const Text('Dalej'),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRestFooter extends StatelessWidget {
  const _ReadOnlyRestFooter({required this.restRemaining});

  final int restRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1015),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Odpoczynek',
                style: TextStyle(
                  color: lmMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(restRemaining),
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: restRemaining / _LiveSessionScreenState._restTotal,
              minHeight: 5,
              color: lmBlue,
              backgroundColor: const Color(0xFF22262E),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Wartości aktualizują się na żywo - nic nie musisz wpisywać.',
            textAlign: TextAlign.center,
            style: TextStyle(color: lmMutedDark, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4D).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'żywo',
        style: TextStyle(
          color: Color(0xFFFF8D8D),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

List<_ExerciseValueGroup> _groupValues(List<SharedSessionValue> values) {
  final sorted = [...values]..sort((a, b) {
      final order = a.exerciseOrder.compareTo(b.exerciseOrder);
      if (order != 0) {
        return order;
      }
      return a.setIndex.compareTo(b.setIndex);
    });

  final groups = <_ExerciseValueGroup>[];
  for (final value in sorted) {
    if (groups.isEmpty || groups.last.exerciseOrder != value.exerciseOrder) {
      groups.add(_ExerciseValueGroup(
        exerciseOrder: value.exerciseOrder,
        exerciseName: value.exerciseName,
        values: [value],
      ));
    } else {
      groups.last.values.add(value);
    }
  }

  return groups;
}

SharedSessionValue _firstOpenValue(List<SharedSessionValue> values) {
  return values.firstWhere((value) => !value.isDone, orElse: () => values.last);
}

String _sessionSubtitle(SharedSession session) {
  return session.workoutSetId == null ? 'Aktywny trening' : 'Zestaw ${session.workoutSetId}';
}

String _readOnlySessionLabel(
  SharedSession session,
  String? trainerDisplayName,
) {
  if (!session.isTrainerLed) {
    return 'Trening własny';
  }

  final trimmedName = trainerDisplayName?.trim();
  final trainerLabel = trimmedName == null || trimmedName.isEmpty
      ? session.trainerEmail
      : trimmedName.split(RegExp(r'\s+')).first;

  return 'Prowadzi trener $trainerLabel';
}

String _primaryValueLabel(SharedSessionValue value) {
  return switch (value.exerciseType) {
    ExerciseValueType.repsWeight => '${_formatNumber(value.weight ?? 0)} kg',
    ExerciseValueType.repsOnly => '${value.reps ?? 0}',
    ExerciseValueType.time => '${value.seconds ?? 0} s',
  };
}

String _secondaryValueLabel(SharedSessionValue value) {
  return switch (value.exerciseType) {
    ExerciseValueType.repsWeight => 'x ${value.reps ?? 0} powt.',
    ExerciseValueType.repsOnly => 'powtórzeń',
    ExerciseValueType.time => 'utrzymaj',
  };
}

String _formatNumber(num value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _ExerciseValueGroup {
  _ExerciseValueGroup({
    required this.exerciseOrder,
    required this.exerciseName,
    required this.values,
  });

  final int exerciseOrder;
  final String exerciseName;
  final List<SharedSessionValue> values;
}
