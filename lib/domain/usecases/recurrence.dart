import 'package:chovos_hayom/core/day.dart';

/// Which calendar a recurrence rule is written in, and therefore which fields
/// of [DayInfo] it needs.
///
/// Gregorian rules read [DayInfo.weekday] and [DayInfo.dayOfMonth], both
/// derivable from a [Day] without any calendar library. Hebrew rules read the
/// Hebrew fields, which only a Hebrew-aware reader (in `core/`) can fill. A
/// Hebrew rule evaluated against a [DayInfo] whose Hebrew fields are still
/// null fails loudly rather than silently never firing.
enum RuleCalendar { gregorian, hebrew }

/// What a recurrence rule needs to know about a single day, precomputed so the
/// rules themselves are dumb predicates.
///
/// The Hebrew fields are null until a Hebrew-aware reader fills them. Nothing
/// here is computed by the domain; the reader is the one place a [Day] meets
/// the Hebrew calendar.
class DayInfo {
  const DayInfo({
    required this.day,
    required this.weekday,
    required this.dayOfMonth,
    this.hebrewDayOfMonth,
    this.hebrewMonth,
    this.hebrewYear,
  });

  final Day day;

  /// `DateTime.monday` (1) .. `DateTime.sunday` (7). The 7-day week is not
  /// Gregorian, so this is the same weekday in both calendars.
  final int weekday;

  /// Gregorian day of month, 1..31.
  final int dayOfMonth;

  /// Hebrew day of month, 1..30.
  final int? hebrewDayOfMonth;

  /// Hebrew month in the year-ordered numbering of [HebrewMonth], 1..13.
  final int? hebrewMonth;
  final int? hebrewYear;

  bool get hasHebrew => hebrewDayOfMonth != null;

  @override
  bool operator ==(Object other) =>
      other is DayInfo &&
      other.day == day &&
      other.weekday == weekday &&
      other.dayOfMonth == dayOfMonth &&
      other.hebrewDayOfMonth == hebrewDayOfMonth &&
      other.hebrewMonth == hebrewMonth &&
      other.hebrewYear == hebrewYear;

  @override
  int get hashCode =>
      Object.hash(day, weekday, dayOfMonth, hebrewDayOfMonth, hebrewMonth, hebrewYear);

  @override
  String toString() => 'DayInfo($day, weekday=$weekday, day=$dayOfMonth, '
      'hebrew=$hebrewDayOfMonth/$hebrewMonth/$hebrewYear)';
}

/// Hebrew month numbers in the year-ordered convention kosher_dart uses
/// (Nissan=1 .. Adar II=13), so the numbers in a [HebrewDayRule] mean the
/// same thing the reader reports. [tishrei] is the start of the Hebrew *year*;
/// [adarIi] exists only in a leap year.
abstract final class HebrewMonth {
  static const nissan = 1;
  static const iyar = 2;
  static const sivan = 3;
  static const tammuz = 4;
  static const av = 5;
  static const elul = 6;
  static const tishrei = 7;
  static const cheshvan = 8;
  static const kislev = 9;
  static const teves = 10;
  static const shevat = 11;
  static const adar = 12;
  static const adarIi = 13;
}

/// A recurrence rule: the *when* of a plan. It never says what is learned.
///
/// Rules are dumb predicates over a precomputed [DayInfo] and combine with
/// [OrRule], [AndRule] and [NotRule], so "Mishna Yomi daily + Chumash on
/// Wednesdays and the 1st of the Hebrew month" is one plan of two assignments
/// rather than a special case.
sealed class RecurrenceRule {
  const RecurrenceRule();

  /// The calendar this rule is written in. A composite is Hebrew when any
  /// part of it is — the reader fills Hebrew fields whenever a Hebrew rule is
  /// anywhere in the plan.
  RuleCalendar get calendar;

  bool matches(DayInfo day);

  Map<String, dynamic> toJson();

  /// Decodes a rule from the tagged form [toJson] writes, validating at the
  /// boundary: a malformed or out-of-range rule is refused rather than
  /// silently accepted.
  static RecurrenceRule fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'daily':
        return const DailyRule();
      case 'weekdays':
        final weekdays = _intSet(json['weekdays']);
        _check(
          weekdays
              .every((w) => w >= DateTime.monday && w <= DateTime.sunday),
          'weekdays out of range 1..7: '
              '${weekdays.where((w) => w < DateTime.monday || w > DateTime.sunday).toList()}',
        );
        return WeekdayRule(weekdays: weekdays);
      case 'dayOfMonth':
        final days = _intSet(json['days']);
        _check(
          days.every((d) => d >= 1 && d <= 31),
          'days of month out of range 1..31: '
              '${days.where((d) => d < 1 || d > 31).toList()}',
        );
        return DayOfMonthRule(days: days);
      case 'hebrewDay':
        final day = (json['day'] as num?)?.toInt();
        final month = (json['month'] as num?)?.toInt();
        _check(day != null && day >= 1 && day <= 30,
            'Hebrew day of month must be 1..30, got $day');
        _check(month == null || (month >= 1 && month <= 13),
            'Hebrew month must be 1..13, got $month');
        return HebrewDayRule(day: day!, month: month);
      case 'or':
        return OrRule(_ruleList(json['rules'], 'or'));
      case 'and':
        return AndRule(_ruleList(json['rules'], 'and'));
      case 'not':
        final inner = json['rule'];
        _check(inner is Map<dynamic, dynamic>,
            'a "not" rule needs a "rule" map');
        return NotRule(RecurrenceRule.fromJson(
            (inner as Map<dynamic, dynamic>).cast<String, dynamic>()));
      default:
        throw FormatException(
            'unknown recurrence rule type: ${json['type']}');
    }
  }
}

/// Fires every day, whatever the calendar says.
class DailyRule extends RecurrenceRule {
  const DailyRule();

  @override
  RuleCalendar get calendar => RuleCalendar.gregorian;

  @override
  bool matches(DayInfo day) => true;

  @override
  Map<String, dynamic> toJson() => {'type': 'daily'};

  @override
  bool operator ==(Object other) => other is DailyRule;

  @override
  int get hashCode => 1;
}

/// Fires on the listed weekdays only. An empty set fires on nothing.
class WeekdayRule extends RecurrenceRule {
  const WeekdayRule({required this.weekdays});

  final Set<int> weekdays;

  @override
  RuleCalendar get calendar => RuleCalendar.gregorian;

  @override
  bool matches(DayInfo day) => weekdays.contains(day.weekday);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'weekdays', 'weekdays': weekdays.toList()};

  @override
  bool operator ==(Object other) =>
      other is WeekdayRule &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hashAllUnordered(weekdays);
}

/// Fires on the listed Gregorian day-of-month numbers (1..31) only. A day
/// number a month does not have simply never fires in it.
class DayOfMonthRule extends RecurrenceRule {
  const DayOfMonthRule({required this.days});

  final Set<int> days;

  @override
  RuleCalendar get calendar => RuleCalendar.gregorian;

  @override
  bool matches(DayInfo day) => days.contains(day.dayOfMonth);

  @override
  Map<String, dynamic> toJson() => {'type': 'dayOfMonth', 'days': days.toList()};

  @override
  bool operator ==(Object other) =>
      other is DayOfMonthRule &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hashAllUnordered(days);
}

/// Fires on a Hebrew day-of-month, either in every Hebrew month or — with a
/// pinned [month] — in that month only. A day a Hebrew month does not have
/// (there is no 30th in a 29-day month) never fires in it; that is the reader's
/// truth, not a special case here.
class HebrewDayRule extends RecurrenceRule {
  const HebrewDayRule({required this.day, this.month});

  /// Hebrew day of month, 1..30.
  final int day;

  /// Hebrew month (see [HebrewMonth]), or null for "every Hebrew month".
  final int? month;

  @override
  RuleCalendar get calendar => RuleCalendar.hebrew;

  @override
  bool matches(DayInfo info) {
    final hd = info.hebrewDayOfMonth;
    if (hd == null) {
      throw StateError(
          'A Hebrew recurrence rule needs a Hebrew-aware DayInfo reader; '
          'the reader for ${info.day} supplied no Hebrew fields.');
    }
    return hd == day && (month == null || info.hebrewMonth == month);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'hebrewDay',
        'day': day,
        if (month != null) 'month': month,
      };

  @override
  bool operator ==(Object other) =>
      other is HebrewDayRule && other.day == day && other.month == month;

  @override
  int get hashCode => Object.hash(day, month);
}

/// Fires when any child rule fires. Empty: fires on nothing.
class OrRule extends RecurrenceRule {
  const OrRule(this.rules);

  final List<RecurrenceRule> rules;

  @override
  RuleCalendar get calendar => rules.any((r) => r.calendar == RuleCalendar.hebrew)
      ? RuleCalendar.hebrew
      : RuleCalendar.gregorian;

  @override
  bool matches(DayInfo day) => rules.any((r) => r.matches(day));

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'or', 'rules': [for (final r in rules) r.toJson()]};

  @override
  bool operator ==(Object other) =>
      other is OrRule && _sameList(rules, other.rules);

  @override
  int get hashCode => Object.hashAll(rules);
}

/// Fires when every child rule fires. Empty: fires on everything.
class AndRule extends RecurrenceRule {
  const AndRule(this.rules);

  final List<RecurrenceRule> rules;

  @override
  RuleCalendar get calendar => rules.any((r) => r.calendar == RuleCalendar.hebrew)
      ? RuleCalendar.hebrew
      : RuleCalendar.gregorian;

  @override
  bool matches(DayInfo day) => rules.every((r) => r.matches(day));

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'and', 'rules': [for (final r in rules) r.toJson()]};

  @override
  bool operator ==(Object other) =>
      other is AndRule && _sameList(rules, other.rules);

  @override
  int get hashCode => Object.hashAll(rules);
}

/// Fires when [rule] does not. "Every day except Shabbos" is an `AndRule` of a
/// [DailyRule] and a `NotRule` of a Shabbos [WeekdayRule].
class NotRule extends RecurrenceRule {
  const NotRule(this.rule);

  final RecurrenceRule rule;

  @override
  RuleCalendar get calendar => rule.calendar;

  @override
  bool matches(DayInfo day) => !rule.matches(day);

  @override
  Map<String, dynamic> toJson() => {'type': 'not', 'rule': rule.toJson()};

  @override
  bool operator ==(Object other) => other is NotRule && other.rule == rule;

  @override
  int get hashCode => rule.hashCode;
}

void _check(bool ok, String message) {
  if (!ok) throw FormatException(message);
}

Set<int> _intSet(Object? raw) {
  final list = raw as List<dynamic>? ?? const <dynamic>[];
  return {for (final e in list) (e as num).toInt()};
}

List<RecurrenceRule> _ruleList(Object? raw, String type) {
  final list = raw as List<dynamic>?;
  _check(list != null, 'an "$type" rule needs a "rules" list');
  return [
    for (final r in list!)
      RecurrenceRule.fromJson((r as Map<dynamic, dynamic>).cast<String, dynamic>()),
  ];
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}