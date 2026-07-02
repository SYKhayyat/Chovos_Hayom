import 'package:chovos_hayom/core/calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateDisplay', () {
    final date = DateTime(2026, 1, 10);

    test('gregorian formats as ISO-ish yyyy-mm-dd', () {
      expect(DateDisplay.format(date, CalendarMode.gregorian), '2026-01-10');
    });

    test('hebrew produces a string containing Hebrew letters', () {
      final s = DateDisplay.format(date, CalendarMode.hebrew);
      expect(s, isNotEmpty);
      expect(RegExp(r'[א-ת]').hasMatch(s), isTrue,
          reason: 'expected Hebrew letters in "$s"');
    });
  });
}
