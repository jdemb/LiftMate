import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/relationships/relationship_models.dart';
import 'package:liftmate/relationships/trainer_trainee_detail_screen.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_controller.dart';
import 'package:liftmate/trainer_guidance/trainer_guidance_models.dart';

void main() {
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
