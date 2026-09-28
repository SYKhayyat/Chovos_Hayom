
/// Reading a date the reader **wrote**, as the counterpart to
/// [DateDisplay.format] writing one.
///
/// Formatting existed and parsing did not, which is the same defect as #30 one
/// layer up: the app stores real [Day]s, can *display* either calendar, and
/// cannot be *told* a date in the calendar its reader thinks in. A Hebrew-only
/// user setting a cycle's start date had to navigate a Gregorian grid.
///
/// **kosher_dart has no parse direction at all** — 2.0.20 ships formatters only,
/// no `parse` and no `fromString` — so the Hebrew half is written here. It is
/// built to be the inverse of what the app's own formatter emits, which is what
/// makes the round-trip test (`parse(format(day)) == day`) the property that
/// makes any of this trustworthy.
///
/// Three things this does *not* do, each of them a decision rather than an
/// omission:
///
/// - **It never guesses.** A date with two valid readings (`4/1/2026` as April
///   1st or January 4th, or a bare *Adar* in a leap year, which is two months)
///   comes back [DateParse.ambiguous] and the caller says so. Picking one
///   silently would put a date override on the wrong day, and an override on the
///   wrong day is a plan quietly asking for nothing.
/// - **It never lands somewhere nearby.** `JewishDate.initDate` *clamps* a 30th
///   in a 29-day month to the 29th, so asking for a day that does not exist
///   would otherwise return a real date one day off. Every candidate is
///   validated against what the library actually built, and a clamped one is
///   treated as unparseable rather than corrected.
/// - **It never reads a bare day without a year as "this year" by itself.** It
///   takes the year from the [reference] day the caller passes — today, or the
///   month being viewed — and the caller echoes the resolved date back, so the
///   year that was filled in is visible rather than implied.
library;
import 'package:kosher_dart/kosher_dart.dart';

import '../domain/usecases/recurrence.dart';
import 'calendar.dart';
import 'day.dart';
import 'parse.dart';

/// What a date field could be.
///
/// Three answers and not a nullable [Day], because the interesting case is the
/// one a null cannot express: a date that was understood and has two readings.
/// That has to be *reported*, not dropped and not guessed, and a type that can
/// only say "a day or nothing" would force one of those two wrong answers.
sealed class DateParse {
  const DateParse();

  /// The one day [text] names, if it names exactly one.
  const factory DateParse.of(Day day) = DateParseExact;

  /// The days [text] could name, in the order they were tried, when it names
  /// more than one and the text does not say which.
  const factory DateParse.ambiguous(List<Day> days) = DateParseAmbiguous;

  /// [text] is not a date this understands. Said loudly: a date field that
  /// silently keeps its old value is a date field that has swallowed a typo.
  const factory DateParse.invalid() = DateParseInvalid;

  /// The day, or null when there is not exactly one to report.
  Day? get dayOrNull => switch (this) {
        DateParseExact(:final day) => day,
        DateParseAmbiguous() || DateParseInvalid() => null,
      };

  /// Whether this is a date, in the sense a caller can act on.
  bool get isValid => this is! DateParseInvalid;
}

class DateParseExact extends DateParse {
  const DateParseExact(this.day);
  final Day day;

  @override
  Day? get dayOrNull => day;

  // `==` and `hashCode` are deliberately absent, and their absence is the point.
  // Every other value type in this app carries them because a Riverpod provider
  // compares its old and new value on every rebuild, and a type without them
  // notifies everything downstream for nothing. Nothing here does that: a
  // `DateParse` is returned by a function, held for one statement, and read for
  // its `dayOrNull` or matched with `isA`. They were written anyway "because the
  // app's value types have them", which is the reasoning `notify_guard_test`
  // exists to catch, applied to a type the guard does not cover.
  @override
  String toString() => 'DateParseExact($day)';
}

class DateParseAmbiguous extends DateParse {
  const DateParseAmbiguous(this.days);
  final List<Day> days;

  @override
  String toString() => 'DateParseAmbiguous($days)';
}

class DateParseInvalid extends DateParse {
  const DateParseInvalid();

  @override
  String toString() => 'DateParseInvalid()';
}

/// One Hebrew month and every way this app's readers may write it.
///
/// **The single table.** The Hebrew rule editor listed the thirteen months in
/// `edit_plan_screen.dart` in transliteration, and the parser needs the same
/// names in Hebrew script as well — so a name added here is a name the picker
/// offers *and* the parser accepts, and a name the parser accepts but the
/// picker cannot show is a month a user can set but not choose.
class HebrewMonthName {
  const HebrewMonthName({
    required this.month,
    required this.hebrew,
    required this.transliterated,
  });

  /// A [HebrewMonth] constant.
  final int month;

  /// Hebrew script, first the [HebrewDateFormatter]'s own spelling.
  final List<String> hebrew;

  /// Latin transliterations, the first being the formatter's.
  ///
  /// More than one each, because transliteration has no standard: the same
  /// month is *Teves*, *Tevet* and *Tavas* depending on who is asking, and a
  /// parser that accepts only the library's spelling accepts a date most of its
  /// readers did not write.
  final List<String> transliterated;

  /// Every spelling, normalised for comparison: no quotes, no spaces, lowercase.
  ///
  /// Quotes because a month name is sometimes written with them (תשר״י) and
  /// spaces because the numerals of the other two parts of the date are full of
  /// them. Lowercase because Hebrew script has no case and ASCII comparisons
  /// should not depend on the keyboard.
  Iterable<String> get spellings => [
        for (final name in [...hebrew, ...transliterated]) _normalise(name),
      ];
}

String _normalise(String name) => name
    .toLowerCase()
    .replaceAll(' ', '')
    .replaceAll(_punctuation, '');

/// The thirteen months, in the order a Hebrew year runs.
///
/// Two months are ambiguous on purpose: a bare *Adar* is Adar I in a leap year
/// and Adar in an ordinary one, which is why [parseDateText] reports both in a
/// leap year rather than picking the ordinary reading.
const List<HebrewMonthName> hebrewMonthNames = [
  HebrewMonthName(
      month: HebrewMonth.nissan,
      hebrew: ['ניסן', 'נסן'],
      transliterated: ['Nissan', 'Nisan']),
  HebrewMonthName(
      month: HebrewMonth.iyar,
      hebrew: ['אייר', 'איר'],
      transliterated: ['Iyar', 'Iyar', 'Eyar']),
  HebrewMonthName(
      month: HebrewMonth.sivan,
      hebrew: ['סיון', 'סיוון'],
      transliterated: ['Sivan', 'Sivan']),
  HebrewMonthName(
      month: HebrewMonth.tammuz,
      hebrew: ['תמוז', 'תמוז'],
      transliterated: ['Tammuz', 'Tamuz', 'Tammouz']),
  HebrewMonthName(
      month: HebrewMonth.av,
      hebrew: ['אב'],
      transliterated: ['Av', 'Av']),
  HebrewMonthName(
      month: HebrewMonth.elul,
      hebrew: ['אלול', 'אול'],
      transliterated: ['Elul', 'Ellul']),
  HebrewMonthName(
      month: HebrewMonth.tishrei,
      hebrew: ['תשרי'],
      transliterated: ['Tishrei', 'Tishri', 'Tishrei']),
  HebrewMonthName(
      month: HebrewMonth.cheshvan,
      hebrew: ['חשוון', 'חשוב', 'חסוון'],
      transliterated: ['Cheshvan', 'Chesvan', 'Chevan']),
  HebrewMonthName(
      month: HebrewMonth.kislev,
      hebrew: ['כסלו', 'כסלו'],
      transliterated: ['Kislev', 'Chislev', 'Kislev']),
  HebrewMonthName(
      month: HebrewMonth.teves,
      hebrew: ['טבת', 'טבת'],
      // *Tevat* is the spelling the feature request itself was written in, so
      // it is a spelling real readers are using.
      transliterated: ['Teves', 'Tevet', 'Tevat', 'Tavas']),
  HebrewMonthName(
      month: HebrewMonth.shevat,
      hebrew: ['שבט'],
      transliterated: ['Shevat', 'Shvat', 'Shbat']),
  HebrewMonthName(
      month: HebrewMonth.adar,
      // Bare. *Adar I* and *Adar II* are the same word with a letter attached,
      // and are listed against their own months below.
      hebrew: ['אדר'],
      transliterated: ['Adar']),
  HebrewMonthName(
      month: HebrewMonth.adarIi,
      hebrew: ['אדר ב', 'אדר ב׳'],
      transliterated: ['Adar II', 'Adar Ii', 'Adar 2', 'Adar Bet', 'Adar B']),
];

/// Adar I's own spellings, kept out of [hebrewMonthNames] because the numbering
/// it would claim is not a month any reader can set by number.
///
/// [HebrewMonth] has thirteen constants and no Adar I, which is correct for
/// *kosher_dart*'s 1..13 numbering and would be wrong for a name list: in a
/// leap year, listing "Adar" and "Adar II" without "Adar I" leaves the reader
/// with a first Adar they cannot name. It resolves to [HebrewMonth.adar], which
/// is what that constant *is* in a leap year.
const _adarINames = ['Adar I', 'Adar 1', 'Adar Alef', 'אדר א'];

/// The marks a Hebrew number may be written with, and never with meaning.
///
/// A geresh, a gershayim, an apostrophe or a plain quote: all four are how
/// people write `ט״ו` and `תשפ"ו`, and the number is the same with or without
/// them. A raw *triple*-quoted string, so the `"` inside is a character in the
/// class rather than the end of the literal.
final _punctuation = RegExp('[\'׳"״]');

/// The value of a Hebrew letter: `א` is 1 through `ת` is 400.
const Map<String, int> _letterValues = {
  'א': 1, 'ב': 2, 'ג': 3, 'ד': 4, 'ה': 5, 'ו': 6, 'ז': 7, 'ח': 8, 'ט': 9,
  'י': 10, 'כ': 20, 'ל': 30, 'מ': 40, 'נ': 50, 'ס': 60, 'ע': 70, 'פ': 80,
  'צ': 90, 'ק': 100, 'ר': 200, 'ש': 300, 'ת': 400,
};

/// The five final forms, which are the same letters and the same values.
///
/// Not a nicety: a year is written with them constantly — a Hebrew year ending
/// in 20 ends *pe* (`ף`), and 5780 written `תש״פ` is the same year as `תש״כ`.
/// A parser without this reads half of all years as malformed.
const Map<String, String> _finalForms = {
  'ך': 'כ',
  'ם': 'מ',
  'ן': 'נ',
  'ף': 'פ',
  'ץ': 'צ',
};

/// The two letters that stand for 15 and 16 in one.
const Map<String, int> _fifteenAndSixteen = {'טו': 15, 'טז': 16};

/// The standalone token a long-form Hebrew year starts with: the five thousand,
/// written apart from the rest of the digits — `ה׳ תשפ"ו` for 5786.
///
/// **Not part of [parseHebrewNumber].** The same letter is the fifth day of a
/// month, so a numeral reader that turned a leading `ה` into 5000 would read
/// the fifth of Tevet as a year and the year 5786 as a day. It is a *year*
/// rule, so it lives with the year.
const _longYearThousands = {'ה', 'ה׳', 'ה״', 'ה"'};

/// A Hebrew year as an integer, from a numeral that is usually short.
///
/// **The thousands are usually left out.** `תשפ"ו` is 5786: the year is written
/// as its last three digits and the five thousand is implied. Read at face value
/// that is 786 — a perfectly-shaped number and a date five millennia out, which
/// is the worst kind of wrong because nothing complains.
///
/// So a year that comes out under a thousand is read as five thousand plus what
/// it said. A year written long puts the five thousand in a *separate* token
/// (`ה׳ תשפ"ו`), and that is [parseHebrewYear]'s caller's job rather than this
/// function's: the same `ה` is the 5th day of a month, so the thousands rule
/// cannot live in the numeral reader without making `ה׳` mean both 5 and 5000.
int? parseHebrewYear(String text, {int thousands = 0}) {
  final value = parseHebrewNumber(text);
  if (value == null) return null;
  // With the thousands written out, what is left are the low digits and nothing
  // is implied — so adding another five thousand here would land the date two
  // thousand years out instead of five hundred.
  if (thousands != 0) return thousands + value;
  return value < 1000 ? value + 5000 : value;
}

/// A Hebrew numeral as an integer, or null if [text] is not one.
///
/// Accepts every spelling a date is written in: with or without geresh and
/// gershayim, with final letters, and with the 15/16 convention. ASCII digits are
/// *not* accepted here — a Hebrew year written `תשפ"ו` and one written `5786` are
/// the same year, and the caller has to know which of the two fields it is
/// holding before it decides.
///
/// **Every letter is its own value here**, including `ה`. In a *day* `ה׳` is the
/// fifth, and a reader who types it must not get 5000.
int? parseHebrewNumber(String text) {
  var letters = text.trim();
  // The punctuation is decoration on a number, never part of it: ט״ו is 15 and
  // טו is 15, and a year is usually written with them.
  letters = letters.replaceAll(_punctuation, '');
  if (letters.isEmpty) return null;

  var total = 0;
  if (letters.length == 2) {
    final fifteen = _fifteenAndSixteen[letters];
    if (fifteen != null) return total + fifteen;
  }
  for (final raw in letters.split('')) {
    final letter = _finalForms[raw] ?? raw;
    final value = _letterValues[letter];
    if (value == null) return null;
    total += value;
  }
  return total;
}

/// The Gregorian months, by the names a reader is likely to type.
const Map<String, int> _gregorianMonths = {
  'january': 1, 'jan': 1,
  'february': 2, 'feb': 2, 'febr': 2,
  'march': 3, 'mar': 3,
  'april': 4, 'apr': 4,
  'may': 5,
  'june': 6, 'jun': 6,
  'july': 7, 'jul': 7,
  'august': 8, 'aug': 8,
  'september': 9, 'sep': 9, 'sept': 9,
  'october': 10, 'oct': 10,
  'november': 11, 'nov': 11,
  'december': 12, 'dec': 12,
};

final _isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
final _numbersOnly = RegExp(r'^\d+$');
final _numericTriple = RegExp(r'^(\d{1,2})[/.](\d{1,2})[/.](\d{2,4})$');
final _anyHebrewLetter = RegExp(r'[֐-׿]');

/// Whether [text] is written as a Hebrew date.
///
/// **Two ways in, and the rule is stated rather than guessed.** A date is
/// Hebrew if it contains a Hebrew letter, *or* if it names a Hebrew month in
/// transliteration — because `15 Teves 5786` has no Hebrew letter in it at all,
/// and a rule that only looked for script would hand every transliterated date
/// to the Gregorian parser, which cannot read a month called *Teves* and would
/// refuse a date the reader wrote perfectly clearly.
///
/// No overlap to arbitrate: not one Hebrew month is transliterated to a
/// Gregorian month name, and not one Gregorian month name is a Hebrew one. The
/// two sets are disjoint, so this test cannot be the wrong one for any text.
bool _looksHebrew(String text) {
  if (_anyHebrewLetter.hasMatch(text)) return true;
  return text
      .split(RegExp(r'[\s,]+'))
      .any((token) => token.isNotEmpty && _hebrewMonth(token) != null);
}

/// Read [text] as a date, in whichever calendar it is written in.
///
/// **Which calendar** is [ _looksHebrew]: Hebrew script or a Hebrew month name,
/// and Gregorian otherwise. A reader can type in whichever calendar they think
/// in without choosing a mode first.
///
/// [reference] supplies the year for a date that does not give one (`Jan 4`,
/// `ד׳ טבת`) and is the caller's today or the day being viewed. Without it, a
/// yearless date is invalid rather than silently dated to 1970 or to the
/// computer's clock.
DateParse parseDateText(String text, {Day? reference}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const DateParseInvalid();
  return _looksHebrew(trimmed)
      ? _parseHebrew(trimmed, reference)
      : _parseGregorian(trimmed, reference);
}

DateParse _single(List<Day> candidates) => switch (candidates.toSet().length) {
      0 => const DateParseInvalid(),
      1 => DateParseExact(candidates.first),
      // Two readings of one string, ordered as they were tried. Reported rather
      // than resolved: `4/1/2026` is April 1st in the United States and
      // January 4th almost everywhere else, and this app does not know which of
      // its readers is which.
      _ => DateParseAmbiguous(candidates),
    };

DateParse _parseGregorian(String text, Day? reference) {
  final iso = _isoDate.firstMatch(text);
  if (iso != null) {
    // Year-first, so this one is never ambiguous — which is most of why the
    // app's own output is the shape it is.
    return _single(_gregorian(
      nonNegativeInt(iso.group(1))!,
      nonNegativeInt(iso.group(2))!,
      nonNegativeInt(iso.group(3))!,
    ));
  }

  final tokens = text.toLowerCase().split(RegExp(r'[\s,]+')).where((t) => t.isNotEmpty).toList();

  // "4/1/2026" and "1.4.2026": three numbers and no name, so the order is the
  // only thing saying which is the day. Where both orders are valid dates the
  // text is ambiguous, and that is the answer.
  if (tokens.length == 1 && _numericTriple.firstMatch(tokens.first) != null) {
    final m = _numericTriple.firstMatch(tokens.first)!;
    final a = nonNegativeInt(m.group(1))!;
    final b = nonNegativeInt(m.group(2))!;
    final year = _expandYear(nonNegativeInt(m.group(3))!);
    // Day-first first, then month-first, and the order is the order the
    // candidates are offered in. It is not a claim about which is right — both
    // come back — it is just a stable order to show them in.
    return _single([
      ..._gregorian(year, b, a),
      ..._gregorian(year, a, b),
    ]);
  }

  // Otherwise a month name with one or two numbers, in any order: "4 Jan 2026",
  // "Jan 4 2026" and "Jan 4" are all dates someone would type.
  int? month;
  final numbers = <int>[];
  for (final token in tokens) {
    final name = _gregorianMonths[token];
    if (name != null) {
      if (month != null) return const DateParseInvalid();
      month = name;
      continue;
    }
    if (!_numbersOnly.hasMatch(token)) return const DateParseInvalid();
    final value = nonNegativeInt(token);
    if (value == null) return const DateParseInvalid();
    numbers.add(value);
  }
  if (month == null || numbers.isEmpty || numbers.length > 2) {
    return const DateParseInvalid();
  }

  final year = numbers.length == 2
      ? _expandYear(numbers.last)
      : reference?.midnight.year;
  if (year == null) return const DateParseInvalid();
  return _single(_gregorian(year, month, numbers.first));
}

List<Day> _gregorian(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return const [];
  final date = DateTime(year, month, day);
  // DateTime *rolls over* rather than refusing: DateTime(2026, 2, 30) is the
  // 2nd of March. Left alone, every typo past the end of a month would become a
  // real date somewhere else entirely.
  if (date.month != month || date.day != day) return const [];
  return [Day.of(date)];
}

int _expandYear(int year) =>
    year < 100 ? 2000 + year : year;

DateParse _parseHebrew(String text, Day? reference) {
  final tokens = text
      .split(RegExp(r'[\s,]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  // A month name may be two words — *Adar II*, *Adar Bet* — and a token that is
  // not a month by itself is retried joined to the one after it. Without this
  // `Adar II` reads as the bare month *Adar* followed by a stray *II* and is
  // refused, which is the worst way to be wrong about a leap year: the two Adars
  // are a month apart.
  ({int month, bool bare})? month;
  final numbers = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    // The **longest** name wins, so the two-token *Adar I* and *Adar II* beat
    // the one-token bare *Adar*. Reading the bare month first would take `אדר א`
    // as an ambiguous Adar followed by a day of one — and *Alef* is a letter,
    // so it parses as the numeral 1 rather than as being nothing at all.
    final joined =
        i + 1 < tokens.length ? _hebrewMonth('$token ${tokens[i + 1]}') : null;
    final found = joined ?? _hebrewMonth(token);
    if (found != null) {
      if (month != null) return const DateParseInvalid();
      month = found;
      if (joined != null) i++;
      continue;
    }
    if (_asNumber(token) == null) return const DateParseInvalid();
    numbers.add(token);
  }
  if (month == null || numbers.isEmpty || numbers.length > 3) {
    return const DateParseInvalid();
  }


  // **`ה׳` is two different things and the text does not say which.** It is the
  // fifth of a month, and it is the five thousand a long-form year starts with.
  // The day reading is the default, and it is the one the app's own formatter
  // produces: `ה׳ שבט תשפ"ד` is the fifth of Shevat, because a short-form year
  // has no thousands token of its own. The year reading needs three number
  // tokens, one of them the thousands, so that a day and a year are left over.
  //
  // Taken apart by **position**, not by looking for a token that is not the
  // day. Searching by value looks equivalent and is not: `1 Tishrei 1` has a day
  // and a year that are the *same string*, so a search for "the other one" finds
  // nothing and `lastWhere` throws — a date field crashing on a date somebody
  // typed. The fields are positional in every spelling, so position it is.
  final isLongFormYear = numbers.length == 3 &&
      numbers.any((t) => _longYearThousands.contains(t.trim()));
  final fields = isLongFormYear
      ? [for (final t in numbers)
          if (!_longYearThousands.contains(t.trim())) t]
      : numbers;
  if (fields.isEmpty || fields.length > 2) return const DateParseInvalid();
  final dayToken = fields.first;
  final yearToken = fields.length == 2 ? fields[1] : null;
  final day = _asNumber(dayToken)!;
  if (day < 1 || day > 30) return const DateParseInvalid();

  // A year written in plain digits is already whole; one written in Hebrew
  // letters usually omits its thousands, so it is read as a year. Both spellings
  // of the same year have to land in the same place, and [parseHebrewYear] is
  // where that difference is known.
  final year = yearToken == null
      // A yearless Hebrew date takes the *Hebrew* year of the reference, not its
      // Gregorian one: 2026 is 5786 only from Rosh Hashanah onwards, and the two
      // answers are seven months apart.
      ? (reference == null
          ? null
          : JewishDate.fromDateTime(reference.midnight).getJewishYear())
      : parseHebrewYear(
          yearToken,
          thousands: isLongFormYear ? 5000 : 0,
        ) ??
          _asNumber(yearToken);
  if (year == null) return const DateParseInvalid();

  // A bare *Adar* in a leap year is two months, and the text does not say
  // which. An ordinary year has one Adar and this is not ambiguous.
  final months = month.bare && _isHebrewLeapYear(year)
      ? [HebrewMonth.adar, HebrewMonth.adarIi]
      : [month.month];

  return _single([
    for (final m in months) ..._hebrew(year, m, day),
  ]);
}

/// A token as a plain integer: ASCII digits, or Hebrew letters.
///
/// The ASCII half goes through [nonNegativeInt] rather than a hand-rolled
/// `int.tryParse`, because that is the app's one parser for a number somebody
/// typed and `parse_test.dart` refuses a second one. It is the right function:
/// a day, a month or a year is never negative, and a `-3` that someone typed is
/// not a date.
int? _asNumber(String token) {
  final trimmed = token.trim();
  if (_numbersOnly.hasMatch(trimmed)) return nonNegativeInt(trimmed);
  return parseHebrewNumber(trimmed);
}

bool _isHebrewLeapYear(int year) =>
    ((7 * year) + 1) % 19 < 7;

List<Day> _hebrew(int year, int month, int day) {
  if (day < 1 || day > 30 || year < 1) return const [];
  // **Every** failure is a refusal, not a crash, and the exception type is not
  // known in advance.
  //
  // `JewishDate.initDate` documents an `ArgumentError` for a day below 1 or a
  // year below 0, and that is what it throws for `0 Tishrei 1`. But `1 Tishrei
  // 1` throws a **`StateError`** from a lookup inside the month-of-year
  // calculation, and a date field that throws on what somebody typed takes the
  // screen down with it. Catching `ArgumentError` alone — which is what this did
  // first — catches the case the docstring mentions and not the one a user is
  // most likely to reach.
  //
  // So the contract is the whole of it: a parser over hostile text returns an
  // answer for every input, and "unparseable" is one of the answers.
  late final JewishDate date;
  try {
    date = JewishDate.initDate(
      jewishYear: year,
      jewishMonth: month,
      jewishDayOfMonth: day,
    );
  } catch (_) {
    return const [];
  }
  // The library **clamps** a 30th in a 29-day month down to the 29th rather
  // than refusing, so asking the date it built is how a nonexistent day is
  // caught — and it is also how a year the calendar cannot represent is caught,
  // since a clamped or out-of-range year comes back as something else entirely.
  if (date.getJewishDayOfMonth() != day) return const [];
  final gregorianYear = date.getGregorianYear();
  if (gregorianYear < 1 || gregorianYear > 9999) return const [];
  return [Day.of(DateTime(
    gregorianYear,
    date.getGregorianMonth(),
    date.getGregorianDayOfMonth(),
  ))];
}

/// Which Hebrew month [token] names, and whether it named a bare *Adar*.
({int month, bool bare})? _hebrewMonth(String token) {
  final name = _normalise(token);
  // Longest spellings first: "adar ii" contains "adar", and matching the short
  // one first would read every Adar II as an ambiguous Adar.
  final candidates = hebrewMonthNames.expand((m) => m.spellings.map((s) => (m.month, s)))
      .toList()
    ..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  for (final (month, spelling) in candidates) {
    if (spelling == name) {
      return (month: month, bare: _isBareAdar(spelling));
    }
  }
  for (final spelling in _adarINames) {
    if (_normalise(spelling) == name) {
      return (month: HebrewMonth.adar, bare: false);
    }
  }
  return null;
}

bool _isBareAdar(String normalised) => normalised == 'אדר' || normalised == 'adar';

/// [day] written the way [DateDisplay] writes it in [mode], which is the string
/// [parseDateText] is required to read back.
///
/// Here as a named function rather than only as a test expectation, because the
/// round trip is a property of the *pair*: if the display ever changes shape
/// the parse stops matching, and this is what makes that visible instead of
/// leaving it to be noticed.
String formatDateForParsing(Day day, CalendarMode mode) =>
    DateDisplay.format(day.midnight, mode);
