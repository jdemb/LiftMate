import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/shared_sessions/shared_session_models.dart';
import 'package:liftmate/training_history/training_history_formatters.dart';
import 'package:liftmate/training_history/training_history_models.dart';

void main() {
  test(
    'formatters cover dates, duration, Polish counts, values, and deltas',
    () {
      expect(formatHistoryDate(DateTime.utc(2026, 6, 18)), '18 cze 2026');
      expect(formatHistoryDuration(3660), '1 godz. 1 min');
      expect(formatExerciseCount(1), '1 ćwiczenie');
      expect(formatExerciseCount(2), '2 ćwiczenia');
      expect(formatExerciseCount(5), '5 ćwiczeń');
      expect(formatSeriesCount(1), '1 seria');
      expect(formatSeriesCount(3), '3 serie');
      expect(formatSeriesCount(8), '8 serii');
      expect(formatHistoryValue(42.5, ExerciseValueType.repsWeight), '42,5 kg');
      expect(formatHistoryValue(12, ExerciseValueType.repsOnly), '12 powt.');
      expect(formatHistoryValue(60, ExerciseValueType.time), '60 s');
      expect(formatSignedDelta(5, 'kg'), '+5 kg');
      expect(formatSignedDelta(-2.5, 'kg'), '-2,5 kg');
      expect(formatSignedDelta(0, 'kg'), '0 kg');
    },
  );

  test('series formatter covers every exercise type', () {
    expect(
      formatHistorySeries(
        const TrainingHistorySeries(setIndex: 1, reps: 8, weight: 42.5),
        ExerciseValueType.repsWeight,
      ),
      '42,5×8',
    );
    expect(
      formatHistorySeries(
        const TrainingHistorySeries(setIndex: 1, reps: 12),
        ExerciseValueType.repsOnly,
      ),
      '12',
    );
    expect(
      formatHistorySeries(
        const TrainingHistorySeries(setIndex: 1, seconds: 60),
        ExerciseValueType.time,
      ),
      '60s',
    );
  });
}
