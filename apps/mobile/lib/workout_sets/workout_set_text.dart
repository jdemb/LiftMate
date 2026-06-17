String exerciseCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (count == 1) {
    return '1 ćwiczenie';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$count ćwiczenia';
  }
  return '$count ćwiczeń';
}
