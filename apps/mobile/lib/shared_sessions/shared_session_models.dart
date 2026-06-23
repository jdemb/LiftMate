enum SharedSessionStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const SharedSessionStatus(this.wireName);

  final String wireName;

  static SharedSessionStatus? tryParse(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final status in SharedSessionStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }

    return null;
  }
}

enum ExerciseValueType {
  repsWeight('repsWeight'),
  repsOnly('repsOnly'),
  time('time');

  const ExerciseValueType(this.wireName);

  final String wireName;

  static ExerciseValueType? tryParse(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final type in ExerciseValueType.values) {
      if (type.wireName == value) {
        return type;
      }
    }

    return null;
  }
}

enum SharedSessionStartRole {
  trainer('trainer'),
  trainee('trainee');

  const SharedSessionStartRole(this.wireName);

  final String wireName;

  static SharedSessionStartRole? tryParse(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final role in SharedSessionStartRole.values) {
      if (role.wireName == value) {
        return role;
      }
    }

    return null;
  }
}

class SharedSession {
  const SharedSession({
    required this.id,
    required this.trainerUserId,
    required this.traineeUserId,
    required this.trainerEmail,
    required this.traineeEmail,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.values,
    this.closedAt,
    this.workoutSetId,
    this.workoutSetName = 'Trening',
    this.restSeconds = 90,
    this.startedByUserId = '',
    this.startedByRole = SharedSessionStartRole.trainer,
  });

  final String id;
  final String trainerUserId;
  final String traineeUserId;
  final String trainerEmail;
  final String traineeEmail;
  final String? workoutSetId;
  final String workoutSetName;
  final int restSeconds;
  final String startedByUserId;
  final SharedSessionStartRole startedByRole;
  final SharedSessionStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final List<SharedSessionValue> values;

  bool get isTrainerLed => startedByRole == SharedSessionStartRole.trainer;

  bool get isTraineeSelfStarted =>
      startedByRole == SharedSessionStartRole.trainee;

  factory SharedSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final trainerUserId = json['trainerUserId'];
    final traineeUserId = json['traineeUserId'];
    final trainerEmail = json['trainerEmail'];
    final traineeEmail = json['traineeEmail'];
    final workoutSetId = json['workoutSetId'];
    final workoutSetName = json['workoutSetName'] ?? 'Trening';
    final restSeconds = json['restSeconds'] ?? 90;
    final startedByUserId = json['startedByUserId'];
    final startedByRole = SharedSessionStartRole.tryParse(
      json['startedByRole'],
    );
    final status = SharedSessionStatus.tryParse(json['status']);
    final version = json['version'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final closedAt = json['closedAt'];
    final values = json['values'];

    if (id is! String ||
        trainerUserId is! String ||
        traineeUserId is! String ||
        trainerEmail is! String ||
        traineeEmail is! String ||
        (workoutSetId != null && workoutSetId is! String) ||
        workoutSetName is! String ||
        restSeconds is! int ||
        startedByUserId is! String ||
        startedByRole == null ||
        status == null ||
        version is! int ||
        createdAt is! String ||
        updatedAt is! String ||
        (closedAt != null && closedAt is! String) ||
        values is! List) {
      throw const FormatException('Invalid shared session response body.');
    }

    return SharedSession(
      id: id,
      trainerUserId: trainerUserId,
      traineeUserId: traineeUserId,
      trainerEmail: trainerEmail,
      traineeEmail: traineeEmail,
      workoutSetId: workoutSetId,
      workoutSetName: workoutSetName,
      restSeconds: restSeconds,
      startedByUserId: startedByUserId,
      startedByRole: startedByRole,
      status: status,
      version: version,
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      closedAt: closedAt == null ? null : DateTime.parse(closedAt).toUtc(),
      values: values
          .map((value) {
            if (value is! Map<String, dynamic>) {
              throw const FormatException('Invalid shared session value body.');
            }
            return SharedSessionValue.fromJson(value);
          })
          .toList(growable: false),
    );
  }
}

class SharedSessionValue {
  const SharedSessionValue({
    required this.id,
    this.exerciseId,
    this.workoutSetRowId,
    required this.exerciseName,
    required this.exerciseType,
    required this.setIndex,
    this.exerciseOrder = 1,
    this.reps,
    this.weight,
    this.seconds,
    this.isDone = false,
    this.completedAt,
    this.updatedByUserId,
    this.updatedAt,
  });

  final String id;
  final String? exerciseId;
  final String? workoutSetRowId;
  final String exerciseName;
  final ExerciseValueType exerciseType;
  final int exerciseOrder;
  final int setIndex;
  final int? reps;
  final double? weight;
  final int? seconds;
  final bool isDone;
  final DateTime? completedAt;
  final String? updatedByUserId;
  final DateTime? updatedAt;

  factory SharedSessionValue.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final exerciseId = json['exerciseId'];
    final workoutSetRowId = json['workoutSetRowId'];
    final exerciseName = json['exerciseName'];
    final exerciseType = ExerciseValueType.tryParse(json['exerciseType']);
    final exerciseOrder = json['exerciseOrder'];
    final setIndex = json['setIndex'];
    final reps = json['reps'];
    final weight = json['weight'];
    final seconds = json['seconds'];
    final isDone = json['isDone'];
    final completedAt = json['completedAt'];
    final updatedByUserId = json['updatedByUserId'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        (exerciseId != null && exerciseId is! String) ||
        (workoutSetRowId != null && workoutSetRowId is! String) ||
        exerciseName is! String ||
        exerciseType == null ||
        exerciseOrder is! int ||
        setIndex is! int ||
        (reps != null && reps is! int) ||
        (weight != null && weight is! num) ||
        (seconds != null && seconds is! int) ||
        isDone is! bool ||
        (completedAt != null && completedAt is! String) ||
        (updatedByUserId != null && updatedByUserId is! String) ||
        (updatedAt != null && updatedAt is! String)) {
      throw const FormatException(
        'Invalid shared session value response body.',
      );
    }

    return SharedSessionValue(
      id: id,
      exerciseId: exerciseId,
      workoutSetRowId: workoutSetRowId,
      exerciseName: exerciseName,
      exerciseType: exerciseType,
      exerciseOrder: exerciseOrder,
      setIndex: setIndex,
      reps: reps,
      weight: weight?.toDouble(),
      seconds: seconds,
      isDone: isDone,
      completedAt: completedAt == null
          ? null
          : DateTime.parse(completedAt).toUtc(),
      updatedByUserId: updatedByUserId,
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class CreateSharedSessionValue {
  const CreateSharedSessionValue({
    required this.exerciseName,
    required this.exerciseType,
    required this.setIndex,
    this.reps,
    this.weight,
    this.seconds,
  });

  final String exerciseName;
  final ExerciseValueType exerciseType;
  final int setIndex;
  final int? reps;
  final double? weight;
  final int? seconds;

  Map<String, Object?> toJson() {
    return {
      'exerciseName': exerciseName,
      'exerciseType': exerciseType.wireName,
      'setIndex': setIndex,
      'reps': reps,
      'weight': weight,
      'seconds': seconds,
    };
  }
}

class UpdateSharedSessionValue {
  const UpdateSharedSessionValue({
    this.reps,
    this.weight,
    this.seconds,
    this.isDone,
  });

  final int? reps;
  final double? weight;
  final int? seconds;
  final bool? isDone;

  Map<String, Object?> toJson() {
    return {
      'reps': reps,
      'weight': weight,
      'seconds': seconds,
      'isDone': isDone,
    };
  }
}
