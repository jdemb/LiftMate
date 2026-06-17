import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/workout_sets/workout_set_text.dart';

void main() {
  group('exerciseCountLabel', () {
    test('uses Polish exercise count grammar', () {
      expect(exerciseCountLabel(1), '1 ćwiczenie');
      expect(exerciseCountLabel(2), '2 ćwiczenia');
      expect(exerciseCountLabel(4), '4 ćwiczenia');
      expect(exerciseCountLabel(5), '5 ćwiczeń');
      expect(exerciseCountLabel(12), '12 ćwiczeń');
      expect(exerciseCountLabel(22), '22 ćwiczenia');
      expect(exerciseCountLabel(25), '25 ćwiczeń');
    });
  });
}
