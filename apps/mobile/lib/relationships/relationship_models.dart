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
      throw const FormatException('Invalid trainer relationship response body.');
    }

    return TrainerRelationshipSummary(
      inviteCode: inviteCode,
      trainees: trainees
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException('Invalid trainee summary response body.');
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
    this.activeSession,
  });

  final String id;
  final String email;
  final String displayName;
  final ActiveSharedSessionSummary? activeSession;

  factory TrainerTraineeSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final displayName = json['displayName'];
    final activeSession = json['activeSession'];

    if (id is! String ||
        email is! String ||
        displayName is! String ||
        (activeSession != null && activeSession is! Map<String, dynamic>)) {
      throw const FormatException('Invalid trainee summary response body.');
    }

    return TrainerTraineeSummary(
      id: id,
      email: email,
      displayName: displayName,
      activeSession:
          activeSession == null ? null : ActiveSharedSessionSummary.fromJson(activeSession),
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
      throw const FormatException('Invalid active session summary response body.');
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
  });

  final TraineeTrainerSummary? trainer;

  factory TraineeRelationshipSummary.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainer'];
    if (trainer == null) {
      return const TraineeRelationshipSummary(trainer: null);
    }

    if (trainer is! Map<String, dynamic>) {
      throw const FormatException('Invalid trainee relationship response body.');
    }

    return TraineeRelationshipSummary(
      trainer: TraineeTrainerSummary.fromJson(trainer),
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
