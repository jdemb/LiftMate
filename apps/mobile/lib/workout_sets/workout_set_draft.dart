import '../shared_sessions/shared_session_models.dart';
import 'workout_set_models.dart';

class WorkoutSetDraftExercise {
  const WorkoutSetDraftExercise({
    required this.draftId,
    required this.name,
    required this.exerciseType,
    required this.sets,
    this.exerciseId,
    this.rowIds = const [],
    this.reps,
    this.weight,
    this.seconds,
  });

  factory WorkoutSetDraftExercise.create({
    required String name,
    required ExerciseValueType exerciseType,
    required int sets,
    int? reps,
    double? weight,
    int? seconds,
  }) {
    final id = _nextDraftId;
    _nextDraftId += 1;
    return WorkoutSetDraftExercise(
      draftId: 'draft-$id',
      name: name,
      exerciseType: exerciseType,
      sets: sets,
      rowIds: const [],
      reps: reps,
      weight: weight,
      seconds: seconds,
    );
  }

  factory WorkoutSetDraftExercise.fromRows(
    int exerciseOrder,
    List<WorkoutSetRow> rows,
  ) {
    final sortedRows = [...rows]
      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
    final first = sortedRows.first;
    return WorkoutSetDraftExercise(
      draftId: 'existing-$exerciseOrder',
      exerciseId: first.exerciseId,
      rowIds: sortedRows.map((row) => row.id).toList(growable: false),
      name: first.exerciseName,
      exerciseType: first.exerciseType,
      sets: sortedRows.length,
      reps: first.reps,
      weight: first.weight,
      seconds: first.seconds,
    );
  }

  static int _nextDraftId = 1;

  final String draftId;
  final String? exerciseId;
  final List<String?> rowIds;
  final String name;
  final ExerciseValueType exerciseType;
  final int sets;
  final int? reps;
  final double? weight;
  final int? seconds;

  String get typeLabel {
    return switch (exerciseType) {
      ExerciseValueType.repsWeight => 'waga',
      ExerciseValueType.repsOnly => 'powt.',
      ExerciseValueType.time => 'czas',
    };
  }

  String get params {
    return switch (exerciseType) {
      ExerciseValueType.repsWeight =>
        '$sets serie · $reps powt. · ${weight?.toStringAsFixed(0)} kg',
      ExerciseValueType.repsOnly => '$sets serie · $reps powt.',
      ExerciseValueType.time => '$sets serie · $seconds sek.',
    };
  }

  List<WorkoutSetRowRequest> toRows(int exerciseOrder) {
    return List.generate(sets, (index) {
      return WorkoutSetRowRequest(
        id: index < rowIds.length ? rowIds[index] : null,
        exerciseId: exerciseId,
        exerciseOrder: exerciseOrder,
        setIndex: index + 1,
        exerciseName: name,
        exerciseType: exerciseType,
        reps: reps,
        weight: weight,
        seconds: seconds,
      );
    }, growable: false);
  }
}
