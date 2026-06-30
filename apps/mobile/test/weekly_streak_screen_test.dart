import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/auth/auth_api_client.dart';
import 'package:liftmate/auth/auth_models.dart';
import 'package:liftmate/relationships/relationship_controller.dart';
import 'package:liftmate/relationships/relationship_models.dart';
import 'package:liftmate/relationships/trainee_home_screen.dart';
import 'package:liftmate/relationships/trainer_dashboard_screen.dart';
import 'package:liftmate/relationships/trainer_trainee_detail_screen.dart';

void main() {
  testWidgets('trainee home shows current, best and neutral zero prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TraineeHomeScreen(
            user: _user(UserRole.trainee),
            state: RelationshipControllerState.loaded(
              user: _user(UserRole.trainee),
              traineeSummary: const TraineeRelationshipSummary(
                trainer: TraineeTrainerSummary(
                  id: 'trainer-1',
                  email: 'trainer@example.test',
                  displayName: 'Marek Kowalski',
                ),
                weeklyStreak: WeeklyStreakSummary(
                  currentStreak: 0,
                  bestStreak: 6,
                  lastActiveWeekStart: null,
                  lastCompletedWorkoutAt: null,
                  isActiveThisWeek: false,
                ),
              ),
            ),
            onClaimCode: (_) async => const AuthApiResult<AuthUser>(
              status: AuthApiStatus.success,
              message: 'ok',
            ),
            onReload: () async {},
            onLogout: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Twoja seria'), findsOneWidget);
    expect(find.text('0 tygodni'), findsOneWidget);
    expect(find.text('Najlepsza seria: 6 tygodni'), findsOneWidget);
    expect(
      find.text('Zacznij od jednego treningu w tym tygodniu'),
      findsOneWidget,
    );
  });

  testWidgets('trainer list shows last workout and flame below it', (
    tester,
  ) async {
    final user = _user(UserRole.trainer);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerDashboardScreen(
            user: user,
            state: RelationshipControllerState.loaded(
              user: user,
              trainerSummary: TrainerRelationshipSummary(
                inviteCode: '7F2K9D',
                trainees: [
                  TrainerTraineeSummary(
                    id: 'trainee-1',
                    email: 'anna@example.test',
                    displayName: 'Anna Nowak',
                    weeklyStreak: WeeklyStreakSummary(
                      currentStreak: 6,
                      bestStreak: 11,
                      lastActiveWeekStart: DateTime.now(),
                      lastCompletedWorkoutAt: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      isActiveThisWeek: true,
                    ),
                  ),
                ],
              ),
            ),
            onOpenTrainee: (_) {},
            onOpenWorkoutSets: () {},
            onCopyInviteCode: (_) async {},
            onReload: () async {},
            onLogout: () async {},
          ),
        ),
      ),
    );

    expect(find.text('wczoraj'), findsOneWidget);
    expect(find.text('ostatnio wczoraj'), findsNothing);
    expect(find.text('Trening'), findsNothing);
    expect(find.text('🔥 6'), findsOneWidget);
    final lastWorkoutTop = tester.getTopLeft(find.text('wczoraj')).dy;
    final flameTop = tester.getTopLeft(find.text('🔥 6')).dy;
    expect(flameTop, greaterThan(lastWorkoutTop));
  });

  testWidgets('trainer detail shows current and best streak before guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerTraineeDetailScreen(
            trainee: const TrainerTraineeSummary(
              id: 'trainee-1',
              email: 'anna@example.test',
              displayName: 'Anna Nowak',
              weeklyStreak: WeeklyStreakSummary(
                currentStreak: 6,
                bestStreak: 11,
                lastActiveWeekStart: null,
                lastCompletedWorkoutAt: null,
                isActiveThisWeek: false,
              ),
            ),
            onBack: () {},
            onLogout: () async {},
            onOpenWorkoutSets: () {},
            onOpenHistory: () {},
          ),
        ),
      ),
    );

    expect(find.text('🔥 6'), findsOneWidget);
    expect(find.text('seria'), findsNothing);
    expect(find.text('najlepsza 11'), findsOneWidget);
    expect(find.text('Trening'), findsNothing);
    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Zmień zestaw'), findsOneWidget);
  });
}

AuthUser _user(UserRole role) {
  return AuthUser(
    id: '${role.wireName}-1',
    email: '${role.wireName}@example.test',
    role: role,
    displayName: role == UserRole.trainer ? 'Marek' : 'Anna',
  );
}
