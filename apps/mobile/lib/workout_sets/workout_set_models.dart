import '../shared_sessions/shared_session_models.dart';

class CreateWorkoutSetRequest {
  const CreateWorkoutSetRequest({
    required this.name,
    required this.rows,
  });

  final String name;
  final List<WorkoutSetRowRequest> rows;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class UpdateWorkoutSetRequest extends CreateWorkoutSetRequest {
  const UpdateWorkoutSetRequest({
    required super.name,
    required super.rows,
  });
}

class WorkoutSetRowRequest {
  const WorkoutSetRowRequest({
    required this.exerciseOrder,
    required this.setIndex,
    required this.exerciseName,
    required this.exerciseType,
    this.reps,
    this.weight,
    this.seconds,
  });

  final int exerciseOrder;
  final int setIndex;
  final String exerciseName;
  final ExerciseValueType exerciseType;
  final int? reps;
  final double? weight;
  final int? seconds;

  Map<String, Object?> toJson() {
    return {
      'exerciseOrder': exerciseOrder,
      'setIndex': setIndex,
      'exerciseName': exerciseName,
      'exerciseType': exerciseType.wireName,
      'reps': reps,
      'weight': weight,
      'seconds': seconds,
    };
  }
}

class AssignWorkoutSetRequest {
  const AssignWorkoutSetRequest({required this.traineeUserIds});

  final List<String> traineeUserIds;

  Map<String, Object?> toJson() {
    return {'traineeUserIds': traineeUserIds};
  }
}

class WorkoutSetSummary {
  const WorkoutSetSummary({
    required this.id,
    required this.name,
    required this.exerciseCount,
    required this.rowCount,
    required this.assignedTrainees,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int exerciseCount;
  final int rowCount;
  final int assignedTrainees;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkoutSetSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final exerciseCount = json['exerciseCount'];
    final rowCount = json['rowCount'];
    final assignedTrainees = json['assignedTrainees'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        name is! String ||
        exerciseCount is! int ||
        rowCount is! int ||
        assignedTrainees is! int ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid workout set summary response body.');
    }

    return WorkoutSetSummary(
      id: id,
      name: name,
      exerciseCount: exerciseCount,
      rowCount: rowCount,
      assignedTrainees: assignedTrainees,
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class WorkoutSetDetail {
  const WorkoutSetDetail({
    required this.id,
    required this.name,
    required this.rows,
    required this.assignments,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<WorkoutSetRow> rows;
  final List<WorkoutSetAssignment> assignments;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkoutSetDetail.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rows = json['rows'];
    final assignments = json['assignments'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        name is! String ||
        rows is! List ||
        assignments is! List ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid workout set detail response body.');
    }

    return WorkoutSetDetail(
      id: id,
      name: name,
      rows: _parseList(rows, WorkoutSetRow.fromJson, 'Invalid workout set row response body.'),
      assignments: _parseList(
        assignments,
        WorkoutSetAssignment.fromJson,
        'Invalid workout set assignment response body.',
      ),
      createdAt: DateTime.parse(createdAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

class WorkoutSetRow {
  const WorkoutSetRow({
    required this.id,
    required this.exerciseOrder,
    required this.setIndex,
    required this.exerciseName,
    required this.exerciseType,
    this.reps,
    this.weight,
    this.seconds,
  });

  final String id;
  final int exerciseOrder;
  final int setIndex;
  final String exerciseName;
  final ExerciseValueType exerciseType;
  final int? reps;
  final double? weight;
  final int? seconds;

  factory WorkoutSetRow.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final exerciseOrder = json['exerciseOrder'];
    final setIndex = json['setIndex'];
    final exerciseName = json['exerciseName'];
    final exerciseType = ExerciseValueType.tryParse(json['exerciseType']);
    final reps = json['reps'];
    final weight = json['weight'];
    final seconds = json['seconds'];

    if (id is! String ||
        exerciseOrder is! int ||
        setIndex is! int ||
        exerciseName is! String ||
        exerciseType == null ||
        (reps != null && reps is! int) ||
        (weight != null && weight is! num) ||
        (seconds != null && seconds is! int)) {
      throw const FormatException('Invalid workout set row response body.');
    }

    return WorkoutSetRow(
      id: id,
      exerciseOrder: exerciseOrder,
      setIndex: setIndex,
      exerciseName: exerciseName,
      exerciseType: exerciseType,
      reps: reps,
      weight: weight?.toDouble(),
      seconds: seconds,
    );
  }
}

class WorkoutSetAssignment {
  const WorkoutSetAssignment({
    required this.traineeUserId,
    required this.traineeEmail,
    required this.traineeDisplayName,
    required this.assignedAt,
  });

  final String traineeUserId;
  final String traineeEmail;
  final String traineeDisplayName;
  final DateTime assignedAt;

  factory WorkoutSetAssignment.fromJson(Map<String, dynamic> json) {
    final traineeUserId = json['traineeUserId'];
    final traineeEmail = json['traineeEmail'];
    final traineeDisplayName = json['traineeDisplayName'];
    final assignedAt = json['assignedAt'];

    if (traineeUserId is! String ||
        traineeEmail is! String ||
        traineeDisplayName is! String ||
        assignedAt is! String) {
      throw const FormatException('Invalid workout set assignment response body.');
    }

    return WorkoutSetAssignment(
      traineeUserId: traineeUserId,
      traineeEmail: traineeEmail,
      traineeDisplayName: traineeDisplayName,
      assignedAt: DateTime.parse(assignedAt).toUtc(),
    );
  }
}

class TraineeAssignedWorkoutSet {
  const TraineeAssignedWorkoutSet({
    required this.id,
    required this.name,
    required this.trainerDisplayName,
    required this.rows,
    required this.assignedAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String trainerDisplayName;
  final List<WorkoutSetRow> rows;
  final DateTime assignedAt;
  final DateTime updatedAt;

  factory TraineeAssignedWorkoutSet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final trainerDisplayName = json['trainerDisplayName'];
    final rows = json['rows'];
    final assignedAt = json['assignedAt'];
    final updatedAt = json['updatedAt'];

    if (id is! String ||
        name is! String ||
        trainerDisplayName is! String ||
        rows is! List ||
        assignedAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid trainee assigned workout set response body.');
    }

    return TraineeAssignedWorkoutSet(
      id: id,
      name: name,
      trainerDisplayName: trainerDisplayName,
      rows: _parseList(rows, WorkoutSetRow.fromJson, 'Invalid workout set row response body.'),
      assignedAt: DateTime.parse(assignedAt).toUtc(),
      updatedAt: DateTime.parse(updatedAt).toUtc(),
    );
  }
}

List<T> _parseList<T>(
  List values,
  T Function(Map<String, dynamic> json) parse,
  String message,
) {
  return values.map((value) {
    if (value is! Map<String, dynamic>) {
      throw FormatException(message);
    }

    return parse(value);
  }).toList(growable: false);
}
