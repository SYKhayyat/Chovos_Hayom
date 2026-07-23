import 'package:kosher_dart/kosher_dart.dart';

import '../domain/usecases/learning_cycle.dart';

/// A cycle the app can compute from the Hebrew calendar itself, rather than from
/// a start date and a unit count.
///
/// These are the only cycles shipped as built-ins, and deliberately so: their
/// schedules come from kosher_dart's calendar arithmetic, which accounts for
/// things a "start date + units per day" model cannot (the 2011 change to
/// Shekalim's daf count, leap years, and so on). Every other cycle — Mishna
/// Yomi, Rambam Yomi, Amud Yomi, a yeshiva's own seder — is a
/// [SequentialCycle] the user defines, because the app cannot derive those
/// authoritatively and inventing a start date for one would be worse than
/// leaving it out.
class CalendarCycle {
  const CalendarCycle({
    required this.id,
    required this.name,
    required this.description,
    required this.unitsOn,
  });

  final String id;
  final String name;
  final String description;

  /// What this cycle calls for on a given date. Empty if the date is outside it.
  final List<CycleDay> Function(DateTime) unitsOn;

  static const bavliId = 'daf-yomi-bavli';
  static const yerushalmiId = 'daf-yomi-yerushalmi';

  /// Every calendar-computed cycle, in the order they're shown.
  static const all = <CalendarCycle>[
    CalendarCycle(
      id: bavliId,
      name: 'Daf Yomi (Bavli)',
      description: 'One daf of Talmud Bavli a day',
      unitsOn: _bavli,
    ),
    CalendarCycle(
      id: yerushalmiId,
      name: 'Daf Yomi (Yerushalmi)',
      description: 'One daf of Talmud Yerushalmi a day',
      unitsOn: _yerushalmi,
    ),
  ];

  static List<CycleDay> _bavli(DateTime date) {
    try {
      final daf = JewishCalendar.fromDateTime(date).getDafYomiBavli();
      return [
        CycleDay(
          sefer: daf.getMasechtaTransliterated(),
          seferHebrew: daf.getMasechta(),
          unit: daf.getDaf(),
        ),
      ];
    } catch (_) {
      // Before the cycle began (1923), or otherwise out of range.
      return const [];
    }
  }

  static List<CycleDay> _yerushalmi(DateTime date) {
    try {
      final daf = JewishCalendar.fromDateTime(date).getDafYomiYerushalmi();
      // Yom Kippur and Tisha B'Av are skipped in the Yerushalmi cycle; the
      // calculator reports daf 0 for them.
      if (daf.getDaf() <= 0) return const [];
      return [
        CycleDay(
          sefer: daf.getMasechtaTransliterated(),
          seferHebrew: daf.getMasechta(),
          unit: daf.getDaf(),
        ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
