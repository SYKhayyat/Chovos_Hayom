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
import '../support/in_memory_progress_repository.dart';

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
    final repo = InMemoryProgressRepository();
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
      PrefKeys.scoped('default', PrefKeys.themeMode): 'dark',
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(goalsProvider), isNotEmpty);
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

    await tester.scrollUntilVisible(find.text('Clear settings'), 200);
    await tester.tap(find.text('Clear settings'));
    await tester.pumpAndSettle();

    // The confirmation says what goes, before it goes.
    expect(find.textContaining('removes your goals'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(container.read(goalsProvider), isEmpty);
    expect(container.read(settingsProvider).themeMode, ThemeMode.system);
    // Asked of the repository, not of `customNodesProvider` — nothing on this
    // screen keeps that provider alive, so it is still loading here. Which is
    // the whole reason the clear reads the repository directly: reading the
    // cache would have found an empty list and deleted nothing.
    expect(await repo.watchCustomNodes('default').first, isEmpty);
    // The log is history, and history is never what a settings reset touches.
    expect(await repo.getEvents('default'), hasLength(1));
  });
}
