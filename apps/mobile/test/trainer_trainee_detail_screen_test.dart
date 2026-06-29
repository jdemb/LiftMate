import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/relationships/relationship_models.dart';
import 'package:liftmate/relationships/trainer_trainee_detail_screen.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_controller.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_models.dart';

void main() {
  testWidgets('shows connection status and omits redundant relationship data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
            connectedAt: DateTime(2026, 3, 8),
          ),
          assignedSets: const [],
          onBack: () {},
          onLogout: () async {},
          onOpenWorkoutSets: () {},
          onOpenHistory: () {},
        ),
      ),
    );

    expect(find.text('Połączona od marca 2026'), findsOneWidget);
    expect(find.text('Dane relacji'), findsNothing);
    expect(find.text('E-mail'), findsNothing);
    expect(find.text('Aktywna relacja'), findsNothing);
    expect(find.text('PRZYPISANE ZESTAWY'), findsOneWidget);
    expect(find.text('Historia'), findsOneWidget);
  });

  testWidgets('trainee detail does not flash guidance loading panel', (
    tester,
  ) async {
    final controller = TrainerGuidanceController.seeded(
      traineeUserId: 'trainee-1',
      status: TrainerGuidanceStatus.loading,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: const TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
          ),
          guidanceController: controller,
          assignedSets: const [],
          onBack: () {},
          onLogout: () async {},
          onOpenWorkoutSets: () {},
          onOpenHistory: () {},
        ),
      ),
    );

    expect(find.text('Podpowiedzi'), findsNothing);
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Zmień zestaw'), findsOneWidget);
  });

  testWidgets('trainee detail shows guidance cards and mark-as-read action', (
    tester,
  ) async {
    final controller = TrainerGuidanceController.seeded(
      traineeUserId: 'trainee-1',
      items: [
        TrainerGuidance(
          id: 'guidance-1',
          type: TrainerGuidanceType.weightStagnation,
          traineeUserId: 'trainee-1',
          exerciseId: 'exercise-1',
          exerciseName: 'Wyciskanie sztangi',
          message: 'Warto sprawdzić ciężar w ćwiczeniu Wyciskanie sztangi',
          weightEvidence: const [
            WeightGuidanceEvidence(sessionId: 's1', maxWeight: 40),
            WeightGuidanceEvidence(sessionId: 's2', maxWeight: 45),
            WeightGuidanceEvidence(sessionId: 's3', maxWeight: 40),
          ],
          wellbeingEvidence: const [],
          createdAt: DateTime.utc(2026, 6, 22),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: const TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
          ),
          guidanceController: controller,
          assignedSets: const [],
          onBack: () {},
          onLogout: () async {},
          onOpenWorkoutSets: () {},
        ),
      ),
    );

    expect(find.text('Podpowiedzi'), findsOneWidget);
    expect(find.text('Na podstawie 3 ostatnich treningów'), findsOneWidget);
    expect(find.textContaining('Wyciskanie sztangi'), findsOneWidget);
    expect(find.textContaining('40 kg → 45 kg → 40 kg'), findsOneWidget);

    await tester.tap(find.text('Oznacz jako przeczytaną'));
    await tester.pump();

    expect(controller.state.items, isEmpty);
  });

  testWidgets('guidance cards use design labels and tinted backgrounds', (
    tester,
  ) async {
    final controller = TrainerGuidanceController.seeded(
      traineeUserId: 'trainee-1',
      items: [
        TrainerGuidance(
          id: 'guidance-1',
          type: TrainerGuidanceType.weightStagnation,
          traineeUserId: 'trainee-1',
          exerciseId: 'exercise-1',
          exerciseName: 'Wyciskanie sztangi',
          message: 'Warto sprawdzić ciężar w ćwiczeniu Wyciskanie sztangi',
          weightEvidence: const [
            WeightGuidanceEvidence(sessionId: 's1', maxWeight: 40),
            WeightGuidanceEvidence(sessionId: 's2', maxWeight: 40),
            WeightGuidanceEvidence(sessionId: 's3', maxWeight: 40),
          ],
          wellbeingEvidence: const [],
          createdAt: DateTime.utc(2026, 6, 22),
        ),
        TrainerGuidance(
          id: 'guidance-2',
          type: TrainerGuidanceType.lowWellbeing,
          traineeUserId: 'trainee-1',
          exerciseId: null,
          exerciseName: null,
          message: 'Ostatnie oceny samopoczucia są niższe niż zwykle.',
          averageRating: 2.7,
          weightEvidence: const [],
          wellbeingEvidence: const [
            WellbeingGuidanceEvidence(sessionId: 's1', rating: 2),
            WellbeingGuidanceEvidence(sessionId: 's2', rating: 3),
            WellbeingGuidanceEvidence(sessionId: 's3', rating: 3),
          ],
          createdAt: DateTime.utc(2026, 6, 22),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: const TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
          ),
          guidanceController: controller,
          assignedSets: const [],
          onBack: () {},
          onLogout: () async {},
          onOpenWorkoutSets: () {},
          onOpenHistory: () {},
        ),
      ),
    );

    expect(find.text('stagnacja'), findsOneWidget);
    expect(find.text('samopoczucie'), findsOneWidget);
    expect(find.text('ciężar'), findsNothing);
    expect(find.text('feedback'), findsNothing);
    expect(
      _hasAncestorContainerColor(
        tester,
        find.text('Stagnacja ciężaru'),
        const Color(0x1A3A82F6),
      ),
      isTrue,
    );
    expect(
      _hasAncestorContainerColor(
        tester,
        find.text('Niższe samopoczucie'),
        const Color(0x14FFC107),
      ),
      isTrue,
    );
  });

  testWidgets('guidance error does not hide history and workout actions', (
    tester,
  ) async {
    final controller = TrainerGuidanceController.seeded(
      traineeUserId: 'trainee-1',
      status: TrainerGuidanceStatus.error,
      message: 'Nie udało się pobrać podpowiedzi, spróbuj ponownie.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerTraineeDetailScreen(
          trainee: const TrainerTraineeSummary(
            id: 'trainee-1',
            email: 'anna@example.test',
            displayName: 'Anna Nowak',
          ),
          guidanceController: controller,
          assignedSets: const [],
          onBack: () {},
          onLogout: () async {},
          onOpenWorkoutSets: () {},
          onOpenHistory: () {},
        ),
      ),
    );

    expect(
      find.text('Nie udało się pobrać podpowiedzi, spróbuj ponownie.'),
      findsOneWidget,
    );
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Zmień zestaw'), findsOneWidget);
  });
}

bool _hasAncestorContainerColor(
  WidgetTester tester,
  Finder finder,
  Color color,
) {
  final containers = find
      .ancestor(
        of: finder,
        matching: find.byWidgetPredicate((widget) => widget is Container),
      )
      .evaluate()
      .map((element) => element.widget)
      .whereType<Container>();

  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color == color) {
      return true;
    }
  }
  return false;
}
