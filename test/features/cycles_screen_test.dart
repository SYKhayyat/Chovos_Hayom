import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/daf_yomi.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/cycles/cycles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The Daf Yomi row's second line — the daf named in Hebrew, under a heading in
/// the reader's own language.
///
/// It was an ARB key, `cycleDafHebrew`, whose English value was
/// `"{sefer} · דף {unit}"` and whose Hebrew value was that same string. Two
/// things were wrong with it. One is invisible from the app: a message present
/// in both locales and identical in both passes the untranslated-locale gate
/// while being not a translation but a literal stored twice, and
/// `test/l10n/arb_guard_test.dart` is what now refuses it. The other is visible
/// on the screen and is what these tests are about — under a Hebrew locale the
/// heading above it *already says this*, because all 312 bundled catalog nodes
/// carry a `nameHebrew`, so the row printed the same three words twice.
///
/// The line is still right for an English reader, and still right for a Hebrew
/// reader whose sefer has not been linked to a catalog node, where the heading
/// is a transliteration. It is only the third case that was wrong, which is why
/// the condition is "does the heading already say it" rather than "is the reader
/// in Hebrew".
void main() {
  /// A day on which the Bavli cycle is learning Maseches Shabbos.
  ///
  /// Searched for rather than written down. The fake catalog holds exactly one
  /// masechta, so the date has to land in it — and a Daf Yomi date is a fact
  /// about a 2,711-day cycle that began in 1923, not something worth asserting
  /// from memory. (The first guess here was three masechtos and five years out.)
  /// Reading it out of the same calendar the screen reads means this file cannot
  /// drift from the cycle, and the `expect` below is what fires if the search
  /// ever comes back empty rather than merely wrong.
  late final DateTime date;
  late final int daf;

  setUpAll(() {
    final bavli = CalendarCycle.all.first;
    DateTime? found;
    // Shabbos follows Berachos, so it is inside the first year of any cycle;
    // scanning two puts a whole cycle boundary inside the window.
    var probe = DateTime(2020, 1, 5, 9);
    for (var i = 0; i < 730 && found == null; i++) {
      final days = bavli.unitsOn(probe);
      if (days.length == 1 && days.single.sefer == 'Shabbos') found = probe;
      probe = probe.add(const Duration(days: 1));
    }

    expect(found, isNotNull,
        reason: 'no day in two years of the Bavli cycle is in Shabbos, which '
            'means the cycle calculator changed under this test rather than '
            'this test being wrong about a date');
    date = found!;

    final day = bavli.unitsOn(date).single;
    // Asserted rather than assumed: every expectation below reads "the heading
    // and the line under it say the same words", which is trivially true of two
    // strings that are both empty because the sefer never resolved to a node.
    expect(day.seferHebrew, 'שבת');
    daf = day.unit;
  });

  Widget screen({required Locale locale, required ProgressRepository repo}) =>
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => date),
        ],
        child: localizedApp(home: const CyclesScreen(), locale: locale),
      );

  testWidgets('an English heading gets the Hebrew line beside it',
      (tester) async {
    await tester.pumpWidget(screen(locale: const Locale('en'), repo: memoryRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Shabbos · daf $daf'), findsOneWidget);
    expect(find.text('שבת · דף $daf'), findsOneWidget);
  });

  testWidgets('a Hebrew heading does not get the same words underneath it',
      (tester) async {
    final repo = memoryRepository();
    // The bundled catalog names every node in Hebrew; the fake deliberately does
    // not, so the Hebrew name is supplied here the same way a user's override
    // supplies one. Without it a Hebrew reader's heading is a transliteration
    // and the Hebrew line is the only Hebrew on the row — which is the case
    // below.
    final node = (await FakeCatalogRepository().load()).byId('shas.moed.shabbos')!;
    await repo.addCustomNode('default', node.copyWith(nameHebrew: 'שבת'));

    await tester.pumpWidget(screen(locale: const Locale('he'), repo: repo));
    await tester.pumpAndSettle();

    // Exactly one. This is the assertion that fails on the pre-fix code, where
    // the heading and the line below it were the same string rendered twice.
    expect(find.text('שבת · דף $daf'), findsOneWidget);
    expect(find.text('Shabbos · daf $daf'), findsNothing);
  });

  testWidgets('a Hebrew reader whose sefer is not named in Hebrew still gets it',
      (tester) async {
    // The heading falls back to the name the node has — "Shabbos" — so the
    // Hebrew line is carrying the only Hebrew on the row and must stay. A rule
    // written as "hide it under a Hebrew locale" would have deleted it here.
    await tester.pumpWidget(screen(locale: const Locale('he'), repo: memoryRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Shabbos · דף $daf'), findsOneWidget);
    expect(find.text('שבת · דף $daf'), findsOneWidget);
  });
}
