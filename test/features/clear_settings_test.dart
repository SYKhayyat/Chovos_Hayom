import 'dart:convert';

import 'package:chovos_hayom/application/goals.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/settings.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// *Clear settings* names what it removes, and removes exactly that.
///
/// `GoalsController.clearAll` was written for this call — its doc comment says
/// so — and then never wired to it, so a reset that promised to reset the
/// preferences quietly kept every target date. Goals are configuration, not
/// history: they travel with the settings in a backup, so they go with them
/// here too, and the confirmation says so before anything happens.
void main() {
  testWidgets('clearing settings clears goals and custom sefarim, not the log',
      (tester) async {
    final repo = memoryRepository();
    await repo.addCustomNode(
      'default',
      const CatalogNode(
        id: 'mine',
        parentId: null,
        name: 'My sefer',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.perek,
        unitCount: 5,
        unitOffset: 1,
      ),
    );
    await repo.addEvent(LearningEvent(
      id: 'e1',
      profileId: 'default',
      nodeId: 'shas.moed.shabbos',
      unitIndex: 2,
      action: EventAction.done,
      occurredAt: DateTime(2026, 5, 1),
      loggedAt: DateTime(2026, 5, 1),
    ));
    final prefs = InMemoryPreferences({
      PrefKeys.goalsFor('default'):
          jsonEncode({'shas.moed.shabbos': '2027-01-01T00:00:00.000'}),
      PrefKeys.themeMode: 'dark',
      PrefKeys.scoped('default', PrefKeys.chazaraIntervals): '2,4,8',
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(prefs),
      ],
      child: localizedApp(home: const SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(goalsProvider), isNotEmpty);
    expect(container.read(settingsProvider).chazaraIntervals, [2, 4, 8]);

    await tester.scrollUntilVisible(find.text('Clear settings'), 200);
    // scrollUntilVisible stops the moment the target is attached, which can
    // leave it flush against the viewport edge where a tap misses it.
    await tester.ensureVisible(find.text('Clear settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear settings'));
    await tester.pumpAndSettle();

    // The confirmation says what goes, before it goes.
    expect(find.textContaining('removes your goals'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(container.read(goalsProvider), isEmpty);
    expect(container.read(settingsProvider).chazaraIntervals,
        isNot([2, 4, 8]));
    // The theme is the *device's*, and this resets one profile. A reset that
    // changes what language or theme you are looking at is not one anybody
    // asked for — and for a Hebrew reader it would mean pressing "Clear
    // settings" and landing in English.
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
    // Asked of the repository, not of `customNodesProvider` — nothing on this
    // screen keeps that provider alive, so it is still loading here. Which is
    // the whole reason the clear reads the repository directly: reading the
    // cache would have found an empty list and deleted nothing.
    expect(await repo.getCustomNodes('default'), isEmpty);
    // The log is history, and history is never what a settings reset touches.
    expect(await repo.getEvents('default'), hasLength(1));
  });
}
