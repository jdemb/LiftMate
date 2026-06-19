import '../shared_sessions/shared_session_models.dart';
import 'training_history_models.dart';

const _months = [
  'sty',
  'lut',
  'mar',
  'kwi',
  'maj',
  'cze',
  'lip',
  'sie',
  'wrz',
  'paź',
  'lis',
  'gru',
];

String formatHistoryDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String formatHistoryShortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
}

String formatHistoryDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) {
    return '$minutes min';
  }
  if (remaining == 0) {
    return '$hours godz.';
  }
  return '$hours godz. $remaining min';
}

String formatExerciseCount(int count) =>
    '$count ${_plural(count, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}';

String formatSeriesCount(int count) =>
    '$count ${_plural(count, 'seria', 'serie', 'serii')}';

String formatHistoryValue(num value, ExerciseValueType type) {
  final formatted = _number(value);
  return switch (type) {
    ExerciseValueType.repsWeight => '$formatted kg',
    ExerciseValueType.repsOnly => '$formatted powt.',
    ExerciseValueType.time => '$formatted s',
  };
}

String formatHistorySeries(
  TrainingHistorySeries series,
  ExerciseValueType type,
) {
  return switch (type) {
    ExerciseValueType.repsWeight =>
      '${_number(series.weight ?? 0)}×${series.reps ?? 0}',
    ExerciseValueType.repsOnly => '${series.reps ?? 0}',
    ExerciseValueType.time => '${series.seconds ?? 0}s',
  };
}

String formatSignedDelta(num value, String unit) {
  final prefix = value > 0 ? '+' : '';
  return '$prefix${_number(value)} $unit';
}

String _plural(int value, String one, String few, String many) {
  final lastTwo = value % 100;
  if (value == 1) return one;
  if (lastTwo >= 12 && lastTwo <= 14) return many;
  final last = value % 10;
  return last >= 2 && last <= 4 ? few : many;
}

String _number(num value) {
  final text = value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}
