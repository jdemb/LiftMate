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

class SharedSession {
  const SharedSession({
    required this.id,
    required this.trainerUserId,
    required this.traineeUserId,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.values,
    this.closedAt,
  });

  final String id;
  final String trainerUserId;
  final String traineeUserId;
  final SharedSessionStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;
  final List<SharedSessionValue> values;

  factory SharedSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final trainerUserId = json['trainerUserId'];
    final traineeUserId = json['traineeUserId'];
    final status = SharedSessionStatus.tryParse(json['status']);
    final version = json['version'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    final closedAt = json['closedAt'];
    final values = json['values'];

    if (id is! String ||
        trainerUserId is! String ||
        traineeUserId is! String ||
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
    required this.exerciseName,
    required this.exerciseType,
    required this.setIndex,
    this.reps,
    this.weight,
    this.seconds,
    this.updatedByUserId,
    this.updatedAt,
  });

  final String id;
  final String exerciseName;
  final ExerciseValueType exerciseType;
  final int setIndex;
  final int? reps;
  final double? weight;
  final int? seconds;
  final String? updatedByUserId;
  final DateTime? updatedAt;

  factory SharedSessionValue.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final exerciseName = json['exerciseName'];
    final exerciseType = ExerciseValueType.tryParse(json['exerciseType']);
    final setIndex = json['setIndex'];
    final reps = json['reps'];
    final weight = json['weight'];
    final seconds = json['seconds'];
    final updatedByUserId = json['updatedByUserId'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        exerciseName is! String ||
        exerciseType == null ||
        setIndex is! int ||
        (reps != null && reps is! int) ||
        (weight != null && weight is! num) ||
        (seconds != null && seconds is! int) ||
        (updatedByUserId != null && updatedByUserId is! String) ||
        (updatedAt != null && updatedAt is! String)) {
      throw const FormatException('Invalid shared session value response body.');
    }

    return SharedSessionValue(
      id: id,
      exerciseName: exerciseName,
      exerciseType: exerciseType,
      setIndex: setIndex,
      reps: reps,
      weight: weight?.toDouble(),
      seconds: seconds,
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
  });

  final int? reps;
  final double? weight;
  final int? seconds;

  Map<String, Object?> toJson() {
    return {
      'reps': reps,
      'weight': weight,
      'seconds': seconds,
    };
  }
}
