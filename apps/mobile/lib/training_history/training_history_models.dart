import '../shared_sessions/shared_session_models.dart';

class TrainingHistoryPage {
  const TrainingHistoryPage({required this.items, this.nextCursor});

  final List<TrainingHistorySessionSummary> items;
  final String? nextCursor;

  factory TrainingHistoryPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final nextCursor = json['nextCursor'];
    if (items is! List || (nextCursor != null && nextCursor is! String)) {
      throw const FormatException('Invalid training history page.');
    }
    return TrainingHistoryPage(
      items: _parseList(items, TrainingHistorySessionSummary.fromJson),
      nextCursor: nextCursor,
    );
  }
}

class TrainingHistorySessionSummary {
  const TrainingHistorySessionSummary({
    required this.id,
    required this.workoutSetName,
    required this.startedAt,
    required this.completedAt,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.seriesCount,
  });

  final String id;
  final String workoutSetName;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationSeconds;
  final int exerciseCount;
  final int seriesCount;

  factory TrainingHistorySessionSummary.fromJson(Map<String, dynamic> json) {
    return TrainingHistorySessionSummary(
      id: _string(json, 'id'),
      workoutSetName: _string(json, 'workoutSetName'),
      startedAt: _date(json, 'startedAt'),
      completedAt: _date(json, 'completedAt'),
      durationSeconds: _int(json, 'durationSeconds'),
      exerciseCount: _int(json, 'exerciseCount'),
      seriesCount: _int(json, 'seriesCount'),
    );
  }
}

class TrainingHistorySession {
  const TrainingHistorySession({
    required this.id,
    required this.workoutSetName,
    required this.startedAt,
    required this.completedAt,
    required this.durationSeconds,
    required this.exerciseCount,
    required this.seriesCount,
    required this.exercises,
  });

  final String id;
  final String workoutSetName;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationSeconds;
  final int exerciseCount;
  final int seriesCount;
  final List<TrainingHistoryExercise> exercises;

  factory TrainingHistorySession.fromJson(Map<String, dynamic> json) {
    final exercises = json['exercises'];
    if (exercises is! List) {
      throw const FormatException('Invalid training history session.');
    }
    return TrainingHistorySession(
      id: _string(json, 'id'),
      workoutSetName: _string(json, 'workoutSetName'),
      startedAt: _date(json, 'startedAt'),
      completedAt: _date(json, 'completedAt'),
      durationSeconds: _int(json, 'durationSeconds'),
      exerciseCount: _int(json, 'exerciseCount'),
      seriesCount: _int(json, 'seriesCount'),
      exercises: _parseList(exercises, TrainingHistoryExercise.fromJson),
    );
  }
}

class TrainingHistoryExercise {
  const TrainingHistoryExercise({
    required this.exerciseName,
    required this.type,
    required this.exerciseOrder,
    required this.maximumValue,
    required this.series,
    this.exerciseId,
  });

  final String? exerciseId;
  final String exerciseName;
  final ExerciseValueType type;
  final int exerciseOrder;
  final double maximumValue;
  final List<TrainingHistorySeries> series;

  factory TrainingHistoryExercise.fromJson(Map<String, dynamic> json) {
    final exerciseId = json['exerciseId'];
    final type = ExerciseValueType.tryParse(json['exerciseType']);
    final series = json['series'];
    final maximumValue = json['maximumValue'];
    if ((exerciseId != null && exerciseId is! String) ||
        type == null ||
        series is! List ||
        maximumValue is! num) {
      throw const FormatException('Invalid training history exercise.');
    }
    return TrainingHistoryExercise(
      exerciseId: exerciseId,
      exerciseName: _string(json, 'exerciseName'),
      type: type,
      exerciseOrder: _int(json, 'exerciseOrder'),
      maximumValue: maximumValue.toDouble(),
      series: _parseList(series, TrainingHistorySeries.fromJson),
    );
  }
}

class TrainingHistorySeries {
  const TrainingHistorySeries({
    required this.setIndex,
    this.reps,
    this.weight,
    this.seconds,
  });

  final int setIndex;
  final int? reps;
  final double? weight;
  final int? seconds;

  factory TrainingHistorySeries.fromJson(Map<String, dynamic> json) {
    final reps = json['reps'];
    final weight = json['weight'];
    final seconds = json['seconds'];
    if ((reps != null && reps is! int) ||
        (weight != null && weight is! num) ||
        (seconds != null && seconds is! int)) {
      throw const FormatException('Invalid training history series.');
    }
    return TrainingHistorySeries(
      setIndex: _int(json, 'setIndex'),
      reps: reps,
      weight: weight?.toDouble(),
      seconds: seconds,
    );
  }
}

class ExerciseProgress {
  const ExerciseProgress({
    required this.exerciseId,
    required this.exerciseName,
    required this.type,
    required this.unit,
    required this.startValue,
    required this.currentValue,
    required this.overallDelta,
    required this.points,
  });

  final String exerciseId;
  final String exerciseName;
  final ExerciseValueType type;
  final String unit;
  final double startValue;
  final double currentValue;
  final double overallDelta;
  final List<ExerciseProgressPoint> points;

  factory ExerciseProgress.fromJson(Map<String, dynamic> json) {
    final type = ExerciseValueType.tryParse(json['exerciseType']);
    final start = json['startValue'];
    final current = json['currentValue'];
    final delta = json['overallDelta'];
    final points = json['points'];
    if (type == null ||
        start is! num ||
        current is! num ||
        delta is! num ||
        points is! List) {
      throw const FormatException('Invalid exercise progress.');
    }
    return ExerciseProgress(
      exerciseId: _string(json, 'exerciseId'),
      exerciseName: _string(json, 'exerciseName'),
      type: type,
      unit: _string(json, 'unit'),
      startValue: start.toDouble(),
      currentValue: current.toDouble(),
      overallDelta: delta.toDouble(),
      points: _parseList(points, ExerciseProgressPoint.fromJson),
    );
  }
}

class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.sessionId,
    required this.completedAt,
    required this.value,
    this.delta,
  });

  final String sessionId;
  final DateTime completedAt;
  final double value;
  final double? delta;

  factory ExerciseProgressPoint.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    final delta = json['delta'];
    if (value is! num || (delta != null && delta is! num)) {
      throw const FormatException('Invalid exercise progress point.');
    }
    return ExerciseProgressPoint(
      sessionId: _string(json, 'sessionId'),
      completedAt: _date(json, 'completedAt'),
      value: value.toDouble(),
      delta: delta?.toDouble(),
    );
  }
}

List<T> _parseList<T>(List values, T Function(Map<String, dynamic>) parser) {
  return values
      .map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid training history list item.');
        }
        return parser(value);
      })
      .toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  return DateTime.parse(value).toLocal();
}
