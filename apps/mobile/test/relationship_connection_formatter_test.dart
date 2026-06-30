import 'package:flutter_test/flutter_test.dart';
import 'package:liftmate/relationships/relationship_formatters.dart';

void main() {
  test('formats feminine, masculine and neutral connection status', () {
    final connectedAt = DateTime(2026, 3, 8);

    expect(
      formatTraineeConnectionStatus('Anna Nowak', connectedAt),
      'Połączona od marca 2026',
    );
    expect(
      formatTraineeConnectionStatus('Piotr Kowalski', connectedAt),
      'Połączony od marca 2026',
    );
    expect(
      formatTraineeConnectionStatus('Alex Nowak', connectedAt),
      'Połączono od marca 2026',
    );
    expect(formatTraineeConnectionStatus('Alex Nowak', null), 'Połączono');
  });

  test('uses every Polish genitive month form', () {
    const months = [
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

    for (var month = 1; month <= 12; month += 1) {
      expect(
        formatTraineeConnectionStatus('Anna', DateTime(2026, month, 15)),
        'Połączona od ${months[month - 1]} 2026',
      );
    }
  });

  test('handles Polish masculine exceptions ending with a', () {
    expect(formatTraineeConnectionStatus('Kuba Nowak', null), 'Połączony');
  });
}
