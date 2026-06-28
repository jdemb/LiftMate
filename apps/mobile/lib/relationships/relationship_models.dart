class TrainerRelationshipSummary {
  const TrainerRelationshipSummary({
    required this.inviteCode,
    required this.trainees,
  });

  final String inviteCode;
  final List<TrainerTraineeSummary> trainees;

  factory TrainerRelationshipSummary.fromJson(Map<String, dynamic> json) {
    final inviteCode = json['inviteCode'];
    final trainees = json['trainees'];

    if (inviteCode is! String || trainees is! List) {
      throw const FormatException(
        'Invalid trainer relationship response body.',
      );
    }

    return TrainerRelationshipSummary(
      inviteCode: inviteCode,
      trainees: trainees
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException(
                'Invalid trainee summary response body.',
              );
            }

            return TrainerTraineeSummary.fromJson(value);
          })
          .toList(growable: false),
    );
  }
}

class TrainerTraineeSummary {
  const TrainerTraineeSummary({
    required this.id,
    required this.email,
    required this.displayName,
    this.assignedWorkoutSets = const <AssignedWorkoutSetSummary>[],
    this.activeSession,
    this.weeklyStreak = WeeklyStreakSummary.zero,
  });

  final String id;
  final String email;
  final String displayName;
  final List<AssignedWorkoutSetSummary> assignedWorkoutSets;
  final ActiveSharedSessionSummary? activeSession;
  final WeeklyStreakSummary weeklyStreak;

  factory TrainerTraineeSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final displayName = json['displayName'];
    final activeSession = json['activeSession'];
    final assignedWorkoutSets = json['assignedWorkoutSets'];
    final weeklyStreak = json['weeklyStreak'];

    if (id is! String ||
        email is! String ||
        displayName is! String ||
        (activeSession != null && activeSession is! Map<String, dynamic>) ||
        (assignedWorkoutSets != null && assignedWorkoutSets is! List) ||
        (weeklyStreak != null && weeklyStreak is! Map<String, dynamic>)) {
      throw const FormatException('Invalid trainee summary response body.');
    }

    return TrainerTraineeSummary(
      id: id,
      email: email,
      displayName: displayName,
      assignedWorkoutSets: assignedWorkoutSets == null
          ? const <AssignedWorkoutSetSummary>[]
          : assignedWorkoutSets
                .map<AssignedWorkoutSetSummary>((value) {
                  if (value is! Map<String, dynamic>) {
                    throw const FormatException(
                      'Invalid assigned workout set summary response body.',
                    );
                  }

                  return AssignedWorkoutSetSummary.fromJson(value);
                })
                .toList(growable: false),
      activeSession: activeSession == null
          ? null
          : ActiveSharedSessionSummary.fromJson(activeSession),
      weeklyStreak: weeklyStreak == null
          ? WeeklyStreakSummary.zero
          : WeeklyStreakSummary.fromJson(weeklyStreak),
    );
  }
}

class AssignedWorkoutSetSummary {
  const AssignedWorkoutSetSummary({
    required this.id,
    required this.name,
    required this.exerciseCount,
    required this.rowCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int exerciseCount;
  final int rowCount;
  final DateTime updatedAt;

  factory AssignedWorkoutSetSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final exerciseCount = json['exerciseCount'];
    final rowCount = json['rowCount'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        name is! String ||
        exerciseCount is! int ||
        rowCount is! int ||
        updatedAt is! String) {
      throw const FormatException(
        'Invalid assigned workout set summary response body.',
      );
    }

    return AssignedWorkoutSetSummary(
      id: id,
      name: name,
      exerciseCount: exerciseCount,
      rowCount: rowCount,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class ActiveSharedSessionSummary {
  const ActiveSharedSessionSummary({
    required this.sessionId,
    required this.startedByUserId,
    required this.startedByRole,
    required this.updatedAt,
    this.workoutSetId,
    this.workoutSetName,
  });

  final String sessionId;
  final String? workoutSetId;
  final String? workoutSetName;
  final String startedByUserId;
  final String startedByRole;
  final DateTime updatedAt;

  factory ActiveSharedSessionSummary.fromJson(Map<String, dynamic> json) {
    final sessionId = json['sessionId'];
    final workoutSetId = json['workoutSetId'];
    final workoutSetName = json['workoutSetName'];
    final startedByUserId = json['startedByUserId'];
    final startedByRole = json['startedByRole'];
    final updatedAt = json['updatedAt'];

    if (sessionId is! String ||
        (workoutSetId != null && workoutSetId is! String) ||
        (workoutSetName != null && workoutSetName is! String) ||
        startedByUserId is! String ||
        startedByRole is! String ||
        updatedAt is! String) {
      throw const FormatException(
        'Invalid active session summary response body.',
      );
    }

    return ActiveSharedSessionSummary(
      sessionId: sessionId,
      workoutSetId: workoutSetId,
      workoutSetName: workoutSetName,
      startedByUserId: startedByUserId,
      startedByRole: startedByRole,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class TraineeRelationshipSummary {
  const TraineeRelationshipSummary({
    required this.trainer,
    this.weeklyStreak = WeeklyStreakSummary.zero,
  });

  final TraineeTrainerSummary? trainer;
  final WeeklyStreakSummary weeklyStreak;

  factory TraineeRelationshipSummary.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainer'];
    final weeklyStreak = json['weeklyStreak'];
    if (weeklyStreak != null && weeklyStreak is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid trainee relationship response body.',
      );
    }
    final parsedWeeklyStreak = weeklyStreak == null
        ? WeeklyStreakSummary.zero
        : WeeklyStreakSummary.fromJson(weeklyStreak);
    if (trainer == null) {
      return TraineeRelationshipSummary(
        trainer: null,
        weeklyStreak: parsedWeeklyStreak,
      );
    }

    if (trainer is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid trainee relationship response body.',
      );
    }

    return TraineeRelationshipSummary(
      trainer: TraineeTrainerSummary.fromJson(trainer),
      weeklyStreak: parsedWeeklyStreak,
    );
  }
}

class WeeklyStreakSummary {
  const WeeklyStreakSummary({
    required this.currentStreak,
    required this.bestStreak,
    required this.lastActiveWeekStart,
    required this.lastCompletedWorkoutAt,
    required this.isActiveThisWeek,
  });

  static const zero = WeeklyStreakSummary(
    currentStreak: 0,
    bestStreak: 0,
    lastActiveWeekStart: null,
    lastCompletedWorkoutAt: null,
    isActiveThisWeek: false,
  );

  final int currentStreak;
  final int bestStreak;
  final DateTime? lastActiveWeekStart;
  final DateTime? lastCompletedWorkoutAt;
  final bool isActiveThisWeek;

  factory WeeklyStreakSummary.fromJson(Map<String, dynamic> json) {
    final currentStreak = json['currentStreak'];
    final bestStreak = json['bestStreak'];
    final lastActiveWeekStart = json['lastActiveWeekStart'];
    final lastCompletedWorkoutAt = json['lastCompletedWorkoutAt'];
    final isActiveThisWeek = json['isActiveThisWeek'];

    if (currentStreak is! int ||
        currentStreak < 0 ||
        bestStreak is! int ||
        bestStreak < 0 ||
        (lastActiveWeekStart != null && lastActiveWeekStart is! String) ||
        (lastCompletedWorkoutAt != null && lastCompletedWorkoutAt is! String) ||
        isActiveThisWeek is! bool) {
      throw const FormatException('Invalid weekly streak response body.');
    }

    return WeeklyStreakSummary(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastActiveWeekStart: lastActiveWeekStart == null
          ? null
          : DateTime.parse(lastActiveWeekStart),
      lastCompletedWorkoutAt: lastCompletedWorkoutAt == null
          ? null
          : DateTime.parse(lastCompletedWorkoutAt).toUtc(),
      isActiveThisWeek: isActiveThisWeek,
    );
  }
}

class TraineeTrainerSummary {
  const TraineeTrainerSummary({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  factory TraineeTrainerSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final displayName = json['displayName'];

    if (id is! String || email is! String || displayName is! String) {
      throw const FormatException('Invalid trainer summary response body.');
    }

    return TraineeTrainerSummary(
      id: id,
      email: email,
      displayName: displayName,
    );
  }
}
