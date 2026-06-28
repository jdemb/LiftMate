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
