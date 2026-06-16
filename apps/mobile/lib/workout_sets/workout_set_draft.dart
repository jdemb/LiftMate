import '../shared_sessions/shared_session_models.dart';
import 'workout_set_models.dart';

class WorkoutSetDraftExercise {
  const WorkoutSetDraftExercise({
    required this.name,
    required this.exerciseType,
    required this.sets,
    this.reps,
    this.weight,
    this.seconds,
  });

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
      ExerciseValueType.repsWeight => '$sets serie · $reps powt. · ${weight?.toStringAsFixed(0)} kg',
      ExerciseValueType.repsOnly => '$sets serie · $reps powt.',
      ExerciseValueType.time => '$sets serie · $seconds sek.',
    };
  }

  List<WorkoutSetRowRequest> toRows(int exerciseOrder) {
    return List.generate(sets, (index) {
      return WorkoutSetRowRequest(
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
