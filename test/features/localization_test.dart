import 'dart:convert';
import 'dart:io';

import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/stats/stats_screen.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:chovos_hayom/l10n/generated/app_localizations.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/memory_database.dart';
import '../support/localized_app.dart';

/// The app declared `supportedLocales: [en, he]` and shipped a "Hebrew layout"
/// toggle for a long time while every string in it was hardcoded English — so
/// the toggle produced right-to-left *English*, and `nameHebrew`, carried on
/// every node and meforish through the catalog, the database and the backup
/// format, was never once displayed.
///
/// These tests are what stop that from being true again: they assert that
/// choosing Hebrew changes the words, not just the direction.
void main() {
  Widget stats(ProgressRepository repo, Locale locale) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10, 12)),
        ],
        child: localizedApp(home: const StatsScreen(), locale: locale),
      );

  LearningEvent done(int unit, DateTime day) => LearningEvent(
        id: 'e$unit',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: day,
        loggedAt: day,
      );

  testWidgets('a Hebrew locale translates the words, not just the direction',
      (tester) async {
    final repo = memoryRepository();
    await repo.addEvent(done(2, DateTime(2026, 1, 10)));

    await tester.pumpWidget(stats(repo, const Locale('he')));
    await tester.pumpAndSettle();

    expect(find.text('סטטיסטיקה'), findsOneWidget);
    expect(find.text('רצף'), findsOneWidget);
    // The English these replaced must be gone — a missing key silently falling
    // back to the template locale is exactly the failure worth catching.
    expect(find.text('Statistics'), findsNothing);
    expect(find.text('Streak'), findsNothing);
  });

  testWidgets('the Hebrew locale lays the app out right-to-left', (tester) async {
    final repo = memoryRepository();
    await tester.pumpWidget(stats(repo, const Locale('he')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(StatsScreen))),
        TextDirection.rtl);
  });

  testWidgets('English is still English', (tester) async {
    final repo = memoryRepository();
    await tester.pumpWidget(stats(repo, const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(StatsScreen))),
        TextDirection.ltr);
  });

  testWidgets('a node with a Hebrew name is shown by it under a Hebrew locale',
      (tester) async {
    // `nameHebrew` has been stored and searched since the first version and
    // never displayed. This is the assertion that it is now the name a Hebrew
    // reader sees.
    final repo = memoryRepository();
    final app = ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
      ],
      child: localizedApp(
        home: const UnitGridScreen(nodeId: 'shas.moed.shabbos'),
        locale: const Locale('he'),
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    // The fake catalog's Shabbos has no Hebrew name, so it falls back to the
    // name it has rather than to a blank — a partly-named catalog must degrade
    // to what it showed before, not to nothing.
    expect(find.text('Shabbos'), findsOneWidget);

    // Give it one, and the Hebrew locale reads it instead.
    final node = (await FakeCatalogRepository().load()).byId('shas.moed.shabbos')!;
    await repo.addCustomNode(
        'default', node.copyWith(nameHebrew: 'שבת'));
    await tester.pumpAndSettle();
    expect(find.text('שבת'), findsOneWidget);
    expect(find.text('Shabbos'), findsNothing);
  });

  test('every string the app ships in English also exists in Hebrew', () {
    // gen-l10n writes an untranslated-messages report on every build (see
    // l10n.yaml) and CI fails on a non-empty one — but that only runs when
    // someone regenerates. This fails in the suite, next to the change.
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;

    bool isMessage(String key) => !key.startsWith('@');

    final en = arb('app_en.arb').keys.where(isMessage).toSet();
    final he = arb('app_he.arb').keys.where(isMessage).toSet();

    expect(en.difference(he), isEmpty,
        reason: 'these keys have no Hebrew translation');
    expect(he.difference(en), isEmpty,
        reason: 'these Hebrew keys no longer exist in the English template');
  });

  test('both locales resolve without a widget tree', () {
    // `lookupAppLocalizations` is what lets the pure reporting helpers stay unit
    // tested; if a locale were dropped from the generated table this is where it
    // would show.
    expect(lookupAppLocalizations(const Locale('en')).appTitle, 'Chovos Hayom');
    expect(lookupAppLocalizations(const Locale('he')).appTitle, 'חובות היום');
  });
}
