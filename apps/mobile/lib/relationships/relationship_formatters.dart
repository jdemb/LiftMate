String formatWeeklyStreakFlame(int streak) => '🔥 $streak';

String formatWeekCount(int count) {
  if (count == 1) {
    return '1 tydzień';
  }

  final lastTwoDigits = count % 100;
  final lastDigit = count % 10;
  if (lastTwoDigits < 12 || lastTwoDigits > 14) {
    if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count tygodnie';
    }
  }

  return '$count tygodni';
}

String formatLastWorkout(DateTime? completedAt, {DateTime? now}) {
  if (completedAt == null) {
    return 'nie zaczął';
  }

  final localNow = (now ?? DateTime.now()).toLocal();
  final localCompletedAt = completedAt.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final completedDay = DateTime(
    localCompletedAt.year,
    localCompletedAt.month,
    localCompletedAt.day,
  );
  final days = today.difference(completedDay).inDays;

  if (days <= 0) {
    return 'dzisiaj';
  }
  if (days == 1) {
    return 'wczoraj';
  }
  return '$days dni temu';
}

const _polishGenitiveMonths = <String>[
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

const _masculineNames = <String>{
  'adam',
  'adrian',
  'aleksander',
  'andrzej',
  'antoni',
  'barnaba',
  'bartosz',
  'dawid',
  'filip',
  'grzegorz',
  'jakub',
  'jan',
  'jarema',
  'jerzy',
  'kacper',
  'karol',
  'kosma',
  'krzysztof',
  'kuba',
  'łukasz',
  'maciej',
  'marcin',
  'marek',
  'mateusz',
  'michał',
  'mikołaj',
  'paweł',
  'piotr',
  'przemysław',
  'rafał',
  'robert',
  'sebastian',
  'szymon',
  'tomasz',
  'wojciech',
  'zbigniew',
};

const _neutralNames = <String>{
  'alex',
  'andrea',
  'ari',
  'mika',
  'nikita',
  'noa',
  'sasza',
};

String formatTraineeConnectionStatus(
  String displayName,
  DateTime? connectedAt,
) {
  final trimmed = displayName.trim();
  final normalized = trimmed.isEmpty
      ? ''
      : trimmed.split(RegExp(r'\s+')).first.toLowerCase();

  final String status;
  if (normalized.isEmpty || _neutralNames.contains(normalized)) {
    status = 'Połączono';
  } else if (_masculineNames.contains(normalized)) {
    status = 'Połączony';
  } else if (normalized.endsWith('a')) {
    status = 'Połączona';
  } else {
    status = 'Połączono';
  }

  if (connectedAt == null) {
    return status;
  }

  final localDate = connectedAt.toLocal();
  final month = _polishGenitiveMonths[localDate.month - 1];
  return '$status od $month ${localDate.year}';
}
