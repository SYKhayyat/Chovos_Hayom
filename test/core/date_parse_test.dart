import 'package:chovos_hayom/core/calendar.dart';
import 'package:chovos_hayom/core/date_parse.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';

/// Reading a date the reader wrote (#32).
///
/// The round trip is the test that makes any of this trustworthy: the app
/// formats a day with [DateDisplay] and the parser has to read that exact string
/// back to the same day, in both calendars, over a spread that includes every
/// place a Hebrew calendar is awkward — the 29th and 30th of months that change
/// length with the year, Kislev in a short year, and Adar II, which exists in
/// seven years out of nineteen and not in the other twelve.
void main() {
  Day d(int y, int m, int day) => Day.of(DateTime(y, m, day));

  /// Every 15th of a month for eight years: monthly, so it lands in all
  /// thirteen Hebrew months and in both Adars of a leap year, without being so
  /// dense that a failure names no year.
  List<Day> spread() => [
    for (var year = 2023; year <= 2030; year++)
      for (var month = 1; month <= 12; month++)
        Day.of(DateTime(year, month, 15)),
  ];

  group('the round trip', () {
    test('parse(format(day)) is the day, in Gregorian', () {
      for (final day in spread()) {
        final text = formatDateForParsing(day, CalendarMode.gregorian);
        expect(parseDateText(text).dayOrNull, day, reason: 'read back "$text"');
      }
    });

    test('parse(format(day)) is the day, in Hebrew', () {
      for (final day in spread()) {
        final text = formatDateForParsing(day, CalendarMode.hebrew);
        expect(parseDateText(text).dayOrNull, day, reason: 'read back "$text"');
      }
    });

    test('and at the ends of the months, in both calendars', () {
      // The 1st and the last day of every month for three years. The last day
      // is where a 29-day Hebrew month and a 30-day one differ, and where
      // Kislev and Cheshvan change length with the year.
      for (var year = 2025; year <= 2027; year++) {
        for (var month = 1; month <= 12; month++) {
          final last = DateTime(year, month + 1, 0).day;
          for (final day in [1, last]) {
            final g = Day.of(DateTime(year, month, day));
            expect(
              parseDateText(
                formatDateForParsing(g, CalendarMode.gregorian),
              ).dayOrNull,
              g,
              reason: '$g',
            );
            expect(
              parseDateText(
                formatDateForParsing(g, CalendarMode.hebrew),
              ).dayOrNull,
              g,
              reason: '$g in Hebrew',
            );
          }
        }
      }
    });
  });

  group('Gregorian dates', () {
    test('the ISO form the app itself prints', () {
      expect(parseDateText('2026-01-04').dayOrNull, d(2026, 1, 4));
      expect(parseDateText('2026-1-4').dayOrNull, d(2026, 1, 4));
    });

    test('a day and a month name, either way round', () {
      expect(parseDateText('4 Jan 2026').dayOrNull, d(2026, 1, 4));
      expect(parseDateText('Jan 4 2026').dayOrNull, d(2026, 1, 4));
      expect(parseDateText('4 January 2026').dayOrNull, d(2026, 1, 4));
      expect(parseDateText('4 SEP 2026').dayOrNull, d(2026, 9, 4));
    });

    test('a two-digit year is this century', () {
      // Stated rather than assumed: "4/1/26" is 2026, not 1926 and not 2026
      // plus an offset. A schedule is a plan about the reader's own life.
      expect(parseDateText('4 Jan 26').dayOrNull, d(2026, 1, 4));
    });

    test('a bare day and month takes the year it was given', () {
      // The one place this parser fills something in, and it is filled from a
      // day the caller passed and shows back — never from the clock.
      expect(
        parseDateText('Jan 4', reference: d(2026, 1, 10)).dayOrNull,
        d(2026, 1, 4),
      );
      expect(
        parseDateText('Jan 4', reference: d(2029, 6, 6)).dayOrNull,
        d(2029, 1, 4),
      );
    });

    test('without a reference a yearless date is refused, not dated', () {
      expect(parseDateText('Jan 4').isValid, isFalse);
    });

    test('a day that does not exist is refused rather than rolled over', () {
      // `DateTime(2026, 2, 30)` is the 2nd of March, so a parser that trusted it
      // would turn a typo into a real date two months out.
      expect(parseDateText('30 Feb 2026').isValid, isFalse);
      expect(parseDateText('2026-02-30').isValid, isFalse);
      expect(parseDateText('31 Apr 2026').isValid, isFalse);
    });

    test('nonsense is refused', () {
      for (final text in [
        '',
        'tomorrow',
        '4 Smarch 2026',
        'Jan 2026',
        '2026-13-01',
        '2026-01',
        '4 Jan 2026 5 Feb 2026',
      ]) {
        expect(parseDateText(text).isValid, isFalse, reason: '"$text"');
      }
    });
  });

  group('ambiguity is reported, never guessed', () {
    test('4/1/2026 is two dates, so it is two answers', () {
      // April 1st in the United States, January 4th nearly everywhere else.
      // The app does not know which of its readers is which.
      final parsed = parseDateText('4/1/2026');
      expect(parsed, isA<DateParseAmbiguous>());
      expect((parsed as DateParseAmbiguous).days, [
        d(2026, 1, 4),
        d(2026, 4, 1),
      ]);
    });

    test('but a triple only one way round is a date', () {
      // 25 cannot be a month, so the order is not in doubt and there is nothing
      // to ask about.
      expect(parseDateText('25/1/2026').dayOrNull, d(2026, 1, 25));
      expect(parseDateText('1/25/2026').dayOrNull, d(2026, 1, 25));
    });

    test('a bare Adar in a leap year is two months', () {
      // 5787 is a leap year, so *Adar* is Adar I and Adar II and the text does
      // not say which. The two answers are a fortnight apart.
      final parsed = parseDateText('1 Adar 5787');
      expect(parsed, isA<DateParseAmbiguous>());
      final days = (parsed as DateParseAmbiguous).days;
      expect(days, hasLength(2));
      // Adar II 1 in 5787 is 10 March 2027 (pinned in planner_dates_test), and
      // Adar I has 30 days, so the two readings are a month apart.
      expect(days, contains(d(2027, 3, 10)));
      expect(days, contains(d(2027, 3, 10) - 30));
    });

    test('and a named Adar II is not ambiguous', () {
      expect(parseDateText('1 Adar II 5787').dayOrNull, d(2027, 3, 10));
      expect(
        parseDateText('1 אדר ב 5787'.replaceAll(RegExp(r'\d'), '7')).isValid,
        isTrue,
        reason: 'digits are transliterated, not Hebrew numerals',
      );
    });

    test('a bare Adar in an ordinary year is one month', () {
      // 5786 has one Adar, so there is nothing to choose between. 1 Adar 5786 is
      // 18 February 2026 — the same day as Purim 14 Adar 5786 four days shy of
      // 4 March, which is where Purim 5786 falls.
      expect(parseDateText('1 Adar 5786').dayOrNull, d(2026, 2, 18));
    });

    test(
      'an ISO date is never ambiguous, which is most of why it is the format',
      () {
        expect(parseDateText('2026-01-04'), isA<DateParseExact>());
      },
    );
  });

  group('Hebrew dates', () {
    test('Hebrew script, as the app writes it', () {
      expect(parseDateText('ט״ו טבת תשפ״ו').dayOrNull, d(2026, 1, 4));
      // 1 Tishrei 5787, which is Rosh Hashanah 2027 and is pinned as 12
      // September 2026 in planner_dates_test — so this is a known day, not one
      // the parser and the assertion agree on by accident.
      expect(parseDateText('א׳ תשרי תשפ״ז').dayOrNull, d(2026, 9, 12));
    });

    test('the same date without the gersh and the gershayim', () {
      // Which is how it is typed, and how a lot of it is printed: the marks are
      // decoration on a number and never part of it.
      expect(parseDateText('טו טבת תשפו').dayOrNull, d(2026, 1, 4));
      expect(parseDateText("טו טבת תשפ\"ו").dayOrNull, d(2026, 1, 4));
      expect(parseDateText('א תשרי תשפז').dayOrNull, d(2026, 9, 12));
    });

    test('the same date with a long year', () {
      // `ה׳` is five thousand and not five — read as five, the year is 5781
      // years out and the parse would be a perfectly-shaped wrong date.
      expect(parseDateText('ט״ו טבת ה׳ תשפ״ו').dayOrNull, d(2026, 1, 4));
    });

    test('final letters, which is how most years are written', () {
      // The five final forms are the same letters and the same values, and most
      // of the years a reader types are spelled with one. A parser without them
      // refuses a large fraction of real dates, and refusing a date is a date
      // the reader has to go and look up.
      expect(parseHebrewNumber('תש״ץ'), 790, reason: 'final tsadi');
      expect(parseHebrewNumber('תש״ם'), 740, reason: 'final mem');
      expect(parseHebrewNumber('תש״ן'), 750, reason: 'final nun');
      expect(parseHebrewNumber('תש״ך'), 720, reason: 'final kaf');
      expect(parseHebrewNumber('תש״ף'), 780, reason: 'final pe');
      expect(
        parseHebrewYear('תש״ץ'),
        5790,
        reason: 'and the year adds its thousands',
      );
      // The non-final spellings of the same numbers are the same numbers.
      expect(parseHebrewNumber('תשצ'), 790);
      expect(parseHebrewYear('תשצ'), 5790);
      expect(parseHebrewYear('תש״ף'), 5780);
    });

    test('a year written with final letters round trips too', () {
      // The formatter has a flag for final-form years, and this is the date it
      // produces with it on. Checked through the round trip because the point is
      // that the parser reads what the *formatter* writes, in either spelling.
      for (final year in [5790, 5740, 5750, 5720]) {
        final jd = JewishDate.initDate(
          jewishYear: year,
          jewishMonth: HebrewMonth.teves,
          jewishDayOfMonth: 15,
        );
        final text =
            (HebrewDateFormatter()
                  ..hebrewFormat = true
                  ..useGershGershayim = true
                  ..useFinalFormLetters = true)
                .format(jd);
        expect(
          parseDateText(text).dayOrNull,
          Day.of(
            DateTime(
              jd.getGregorianYear(),
              jd.getGregorianMonth(),
              jd.getGregorianDayOfMonth(),
            ),
          ),
          reason: 'read back "$text"',
        );
      }
    });

    test('the 15th is one letter, not a ten and a five', () {
      expect(parseHebrewNumber('טו'), 15);
      expect(parseHebrewNumber('טז'), 16);
      expect(parseHebrewNumber('ט״ו'), 15);
      expect(parseHebrewNumber('ט״ז'), 16);
    });

    test(
      'transliterated months, which is how people who do not read the script say it',
      () {
        expect(parseDateText('15 Teves 5786').dayOrNull, d(2026, 1, 4));
        expect(parseDateText('4 Tevat 5786').dayOrNull, d(2025, 12, 24));
        // 1 Tishrei 5787 is Rosh Hashanah, pinned as 12 September 2026 in
        // planner_dates_test.
        expect(parseDateText('1 Tishrei 5787').dayOrNull, d(2026, 9, 12));
        expect(parseDateText('15 Tishri 5786').dayOrNull, d(2025, 10, 7));
      },
    );

    test('and the spellings other people use for the same months', () {
      // Transliteration has no standard: the same month is Teves, Tevet and
      // Tavas, and a parser that accepts only the library's spelling refuses a
      // date its reader certainly meant.
      expect(parseDateText('4 Tevet 5786').dayOrNull, d(2025, 12, 24));
      expect(parseDateText('4 Chevan 5786').dayOrNull, d(2025, 10, 26));
      expect(parseDateText('1 Tishrei 5787').dayOrNull, d(2026, 9, 12));
    });

    test('a day of Hebrew numerals with a transliterated month', () {
      // The mixture that comes out of a phone keyboard: Hebrew letters for the
      // day, Latin for the month.
      expect(parseDateText('ט״ו Teves 5786').dayOrNull, d(2026, 1, 4));
    });

    test('a day of Hebrew numerals beside a Hebrew month', () {
      expect(parseDateText('ד׳ טבת תשפ״ו').dayOrNull, d(2025, 12, 24));
      expect(parseDateText('ט״ו טבת תשפ״ו').dayOrNull, d(2026, 1, 4));
    });

    test('a yearless Hebrew date takes the year it was given', () {
      expect(
        parseDateText('ט״ו טבת', reference: d(2026, 1, 10)).dayOrNull,
        d(2026, 1, 4),
      );
      // And the year it takes is the **Hebrew** year of the reference, not its
      // Gregorian one — which is the whole reason it cannot just copy the year
      // across. 1 March 2026 is Hebrew year 5786, not 5785, so 1 Tishrei lands
      // in the previous Gregorian year entirely.
      expect(
        parseDateText('א׳ תשרי', reference: d(2026, 3, 1)).dayOrNull,
        d(2025, 9, 23),
      );
    });

    test('a 30th of a 29-day month is refused, not pulled back a day', () {
      // kosher_dart **clamps** a 30th in a 29-day month down to the 29th rather
      // than refusing, so without this check "30 Kislev 5784" would silently
      // become the 29th — a date the reader did not write, one day out, with
      // nothing said about it.
      //
      // Kislev is the demonstration because it is 29 days in one Hebrew year and
      // 30 in the next, and those two years are the *same* month name: 5784 is a
      // complete year and 5786 a short one, so the difference is the calendar's
      // and not the spelling's. (Checked against kosher_dart directly, because
      // which years are complete is not something to assert from memory.)
      expect(
        parseDateText('30 Kislev 5784').isValid,
        isFalse,
        reason: '5784 is a complete year: Kislev has 29 days',
      );
      expect(parseDateText('29 Kislev 5784').isValid, isTrue);
      expect(
        parseDateText('30 Kislev 5786').isValid,
        isTrue,
        reason: '5786 is a short year: Kislev has 30',
      );
      // Cheshvan moves the other way, which is why both months are named here.
      expect(parseDateText('30 Cheshvan 5786').isValid, isFalse);
      expect(parseDateText('30 Cheshvan 5785').isValid, isTrue);
    });

    test('and Tevet, which is 29 days in every year, has no 30th at all', () {
      // A month that never has a 30th is the cheapest way to see that the check
      // is about the calendar rather than about a hard-coded list.
      for (final year in [5784, 5785, 5786, 5787, 5788]) {
        expect(
          parseDateText('30 Teves $year').isValid,
          isFalse,
          reason: '$year',
        );
        expect(
          parseDateText('29 Teves $year').isValid,
          isTrue,
          reason: '$year',
        );
      }
    });

    test('Adar II does not exist in an ordinary year', () {
      expect(parseDateText('1 Adar II 5786').isValid, isFalse);
      expect(parseDateText('1 Adar II 5787').isValid, isTrue);
    });

    test('a Hebrew day above 30 is refused', () {
      expect(parseDateText('31 Teves 5786').isValid, isFalse);
    });

    test('Hebrew that is not a date is refused', () {
      for (final text in [
        'שלום', // a greeting
        'ט״ו טבתא תשפ״ו', // a month name misspelt
        'ט״ו טבת תשפ״ו יום', // a stray word
      ]) {
        expect(parseDateText(text).isValid, isFalse, reason: '"$text"');
      }
    });

    test('a year the calendar cannot represent is refused, not thrown', () {
      // Found by probing the ends rather than by reasoning about them:
      // `JewishDate.initDate` documents an `ArgumentError` for a year below 1,
      // and for `1 Tishrei 1` it throws a **StateError** from a lookup inside the
      // month-of-year calculation. A date field that throws on what somebody
      // typed takes the screen down with it, so every failure is caught and the
      // answer is "not a date".
      for (final text in [
        '1 Tishrei 1',
        '1 Tishrei 0',
        '1 Tishrei 99999',
        '30 Tishrei 1',
        '1 Tishrei 100000000',
      ]) {
        expect(parseDateText(text).isValid, isFalse, reason: '"$text"');
      }
    });

    test(
      'a Gregorian year is not a Hebrew one, even next to a Hebrew month',
      () {
        // `4 Av 2026` is a Hebrew month and a Gregorian year in the same string.
        // Read as Hebrew it would be the 4th of Av in Hebrew year 2026 — five
        // centuries off. The day check catches it: that date does not exist in
        // that year, so it is refused rather than resolved to something absurd.
        for (final text in ['4 Av 2026', '1 Nissan 2026', '15 Sivan 2026']) {
          expect(parseDateText(text).isValid, isFalse, reason: '"$text"');
        }
      },
    );

    test('a year this far back is a real date, and is read as one', () {
      // Recorded because it looked like a bug while writing the test above:
      // `תשל"ו` is 5736, which is the 20th century, and a Hebrew year is *not*
      // out of range just because it looks small. The thousands are added by
      // rule, not by "is this plausible".
      expect(parseHebrewYear('תשל״ו'), 5736);
      expect(parseDateText('ט״ו טבת תשל״ו').isValid, isTrue);
    });
  });

  group('which calendar, and why that is not a guess', () {
    test(
      'Hebrew letters mean a Hebrew date, everything else a Gregorian one',
      () {
        // Stated once, and there is no overlap to arbitrate: no Gregorian month is
        // written in Hebrew script, so this rule cannot be the wrong one.
        expect(parseDateText('4 Jan 2026').dayOrNull, d(2026, 1, 4));
        expect(parseDateText('4 Teves 5786').dayOrNull, d(2025, 12, 24));
      },
    );

    test('a year alone is not a date', () {
      // Otherwise a Hebrew year with no month and day would be a plausible
      // reading of half a Hebrew date, and a bare "2026" a date in January.
      expect(parseDateText('2026').isValid, isFalse);
      expect(parseDateText('תשפ״ו').isValid, isFalse);
    });
  });
}
