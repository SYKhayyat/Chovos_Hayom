import 'package:kosher_dart/kosher_dart.dart';

/// Which calendar to display dates in. Toggled globally in settings.
enum CalendarMode { gregorian, hebrew }

/// How the day sheet arranges a day's work. A **setting**, not a per-day choice
/// (#48).
///
/// The issue's reasoning for a setting rather than a switch in the sheet is the
/// part worth keeping: the number of plans firing is usually the same from day
/// to day, so the layout that suits a person suits their week — and a control
/// that only appears once you have already opened the sheet is a control that
/// gets used once and then sits there.
///
/// Beside [CalendarMode] rather than with the day sheet's widget, because this
/// is a *mode* like that one and `application/settings.dart` needs to hold it,
/// which a widget file cannot do.
enum DaySheetLayout {
  /// One row per plan firing that day, each with its own units. The **default**,
  /// and the only one of the three that stays readable when several plans fire
  /// on the same day — which is the ordinary case, not the exception.
  byPlan,

  /// Every unit the day owes in one flat list, each naming the plan it belongs
  /// to. Fewest taps when a day is small.
  flat,

  /// One line per plan with its count and how much is done, expanding to the
  /// checkboxes. For a screen with many plans firing and little interest in most
  /// of them.
  collapsed,
}

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
