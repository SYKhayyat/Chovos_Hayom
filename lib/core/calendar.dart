import 'package:kosher_dart/kosher_dart.dart';

/// Which calendar to display dates in. Toggled globally in settings.
enum CalendarMode { gregorian, hebrew }

/// Formats [DateTime]s for display in either calendar. The event log always
/// stores real [DateTime]s; this is purely a presentation layer.
class DateDisplay {
  const DateDisplay._();

  static String format(DateTime date, CalendarMode mode) {
    switch (mode) {
      case CalendarMode.gregorian:
        return '${date.year}-${_two(date.month)}-${_two(date.day)}';
      case CalendarMode.hebrew:
        try {
          final jd = JewishDate.fromDateTime(date);
          final f = HebrewDateFormatter()
            ..hebrewFormat = true
            ..useGershGershayim = true;
          return f.format(jd);
        } catch (_) {
          // Fall back to Gregorian if conversion fails (e.g. out of range).
          return '${date.year}-${_two(date.month)}-${_two(date.day)}';
        }
    }
  }

  /// Like [format] but with the clock time appended (24-hour `HH:mm`). Used where
  /// the exact "time finished" matters, e.g. an item's recorded details.
  static String formatWithTime(DateTime date, CalendarMode mode) =>
      '${format(date, mode)} · ${_two(date.hour)}:${_two(date.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
