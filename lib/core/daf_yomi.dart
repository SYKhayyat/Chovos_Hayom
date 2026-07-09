import 'package:kosher_dart/kosher_dart.dart';

/// Today's Daf Yomi Bavli, computed from the Hebrew calendar.
class DafYomiInfo {
  const DafYomiInfo({
    required this.masechtaEnglish,
    required this.masechtaHebrew,
    required this.daf,
  });

  final String masechtaEnglish;
  final String masechtaHebrew;
  final int daf;
}

/// Computes the Daf Yomi (Bavli) cycle for a given date via kosher_dart. Pure.
class DafYomi {
  const DafYomi._();

  /// The daf learned on [date] in the Daf Yomi cycle, or null if [date] is
  /// before the cycle began (1923) or otherwise out of range.
  static DafYomiInfo? forDate(DateTime date) {
    try {
      final calendar = JewishCalendar.fromDateTime(date);
      final daf = calendar.getDafYomiBavli();
      return DafYomiInfo(
        masechtaEnglish: daf.getMasechtaTransliterated(),
        masechtaHebrew: daf.getMasechta(),
        daf: daf.getDaf(),
      );
    } catch (_) {
      return null;
    }
  }
}
