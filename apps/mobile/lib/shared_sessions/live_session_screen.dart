import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../relationships/relationship_screen_styles.dart';
import 'shared_session_controller.dart';
import 'shared_session_models.dart';

class LiveSessionScreen extends StatelessWidget {
  const LiveSessionScreen({
    required this.user,
    required this.controller,
    required this.editable,
    required this.onBack,
    super.key,
  });

  final AuthUser user;
  final SharedSessionController controller;
  final bool editable;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final session = state.session;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'WrÃ³Ä‡',
                        onPressed: onBack,
                        icon: const Icon(Icons.chevron_left_rounded, size: 30),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Trening live',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                      const Spacer(),
                      const _LiveBadge(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (state.status == SharedSessionControllerStatus.loading &&
                      session == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 42),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (session == null)
                    RelationshipCard(
                      child: Text(
                        state.message ?? 'Nie zaÅ‚adowano aktywnej sesji.',
                        style: const TextStyle(color: lmMuted),
                      ),
                    )
                  else ...[
                    if (!editable)
                      _ReadOnlyLivePanel(session: session)
                    else ...[
                      _SessionHeader(session: session, editable: editable),
                      const SizedBox(height: 18),
                      for (final group in _groupValues(session.values))
                        _ExerciseGroup(
                          user: user,
                          controller: controller,
                          group: group,
                          editable: editable,
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => controller.cancel(user),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Anuluj'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => controller.complete(user),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('ZakoÅ„cz'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReadOnlyLivePanel extends StatelessWidget {
  const _ReadOnlyLivePanel({required this.session});

  final SharedSession session;

  @override
  Widget build(BuildContext context) {
    final current = session.values.first;
    final completed = session.values.where((value) => value.isDone).length;
    return RelationshipCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Aktualne Ä‡wiczenie',
            style: TextStyle(color: lmMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            current.exerciseName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            _SetRow._valueLabel(current),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: lmBlueSoft,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$completed/${session.values.length} serii wykonanych',
            style: const TextStyle(color: lmMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'WartoÅ›ci aktualizujÄ… siÄ™ na Å¼ywo - nic nie musisz wpisywaÄ‡.',
            textAlign: TextAlign.center,
            style: TextStyle(color: lmMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.editable,
  });

  final SharedSession session;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final completed = session.values.where((value) => value.isDone).length;
    return RelationshipCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editable ? 'Tryb edycji' : 'PodglÄ…d treningu',
            style: const TextStyle(color: lmBlueSoft, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${session.values.map((value) => value.exerciseOrder).toSet().length} Ä‡wiczeÅ„ Â· $completed/${session.values.length} serii',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseGroup extends StatelessWidget {
  const _ExerciseGroup({
    required this.user,
    required this.controller,
    required this.group,
    required this.editable,
  });

  final AuthUser user;
  final SharedSessionController controller;
  final _ExerciseValueGroup group;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.exerciseName,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final value in group.values)
            _SetRow(
              user: user,
              controller: controller,
              value: value,
              editable: editable,
            ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.user,
    required this.controller,
    required this.value,
    required this.editable,
  });

  final AuthUser user;
  final SharedSessionController controller;
  final SharedSessionValue value;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              'S${value.setIndex}',
              style: const TextStyle(color: lmMuted, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(_valueLabel(value))),
          IconButton(
            tooltip: value.isDone ? 'Cofnij seriÄ™' : 'Oznacz seriÄ™',
            onPressed: editable
                ? () => controller.toggleDone(
                      user: user,
                      value: value,
                      isDone: !value.isDone,
                    )
                : null,
            icon: Icon(
              value.isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: value.isDone ? const Color(0xFF21C97A) : lmMuted,
            ),
          ),
          if (editable) ...[
            IconButton(
              tooltip: 'Zmniejsz',
              onPressed: () => _nudge(controller, user, value, -1),
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton(
              tooltip: 'ZwiÄ™ksz',
              onPressed: () => _nudge(controller, user, value, 1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }

  static String _valueLabel(SharedSessionValue value) {
    return switch (value.exerciseType) {
      ExerciseValueType.repsWeight =>
        '${value.reps ?? 0} powt. Â· ${value.weight ?? 0} kg',
      ExerciseValueType.repsOnly => '${value.reps ?? 0} powt.',
      ExerciseValueType.time => '${value.seconds ?? 0} s',
    };
  }

  static void _nudge(
    SharedSessionController controller,
    AuthUser user,
    SharedSessionValue value,
    int delta,
  ) {
    final update = switch (value.exerciseType) {
      ExerciseValueType.repsWeight => UpdateSharedSessionValue(
          reps: (value.reps ?? 0) + delta,
          weight: value.weight,
          isDone: value.isDone,
        ),
      ExerciseValueType.repsOnly => UpdateSharedSessionValue(
          reps: (value.reps ?? 0) + delta,
          isDone: value.isDone,
        ),
      ExerciseValueType.time => UpdateSharedSessionValue(
          seconds: (value.seconds ?? 0) + (delta * 5),
          isDone: value.isDone,
        ),
    };
    controller.updateValue(user: user, valueId: value.id, value: update);
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF21C97A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Color(0xFF7EE0AD),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ExerciseValueGroup {
  const _ExerciseValueGroup({
    required this.exerciseName,
    required this.values,
  });

  final String exerciseName;
  final List<SharedSessionValue> values;
}

List<_ExerciseValueGroup> _groupValues(List<SharedSessionValue> values) {
  final groups = <String, List<SharedSessionValue>>{};
  for (final value in values) {
    groups.putIfAbsent('${value.exerciseOrder}:${value.exerciseName}', () => []);
    groups['${value.exerciseOrder}:${value.exerciseName}']!.add(value);
  }

  return groups.entries.map((entry) {
    final groupValues = [...entry.value]..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    return _ExerciseValueGroup(
      exerciseName: groupValues.first.exerciseName,
      values: groupValues,
    );
  }).toList(growable: false);
}
