import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// The unit grid, read aloud.
///
/// A cell shows whether it is learned through **colour alone** — a filled square
/// against an empty one — and its only text child is the bare unit number. So
/// the app's central screen announced itself as "2, 3, 4, 5…", with the one
/// thing worth knowing carried entirely in a channel a screen reader cannot see.
/// These pin the words that now carry it.
void main() {
  LearningEvent done(int unit, {List<String> layers = const ['main']}) =>
      LearningEvent(
        id: 'e$unit-${layers.join()}',
        profileId: 'default',
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 1, 1),
        loggedAt: DateTime(2026, 1, 1),
        layers: layers,
        durationMin: unit == 4 ? 30 : null,
      );

  Widget grid(InMemoryProgressRepository repo,
          {Locale locale = const Locale('en')}) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: localizedApp(
          home: const UnitGridScreen(nodeId: 'shas.moed.shabbos'),
          locale: locale,
        ),
      );

  testWidgets('a cell says whether it is learned, not only shows it',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(grid(repo));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('daf 2, learned'), findsOneWidget);
    expect(find.bySemanticsLabel('daf 3, not learned'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a chazara count and recorded details are announced too',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(4));
    await repo.addEvent(LearningEvent(
      id: 'r4',
      profileId: 'default',
      nodeId: 'shas.moed.shabbos',
      unitIndex: 4,
      action: EventAction.reviewed,
      occurredAt: DateTime(2026, 1, 5),
      loggedAt: DateTime(2026, 1, 5),
    ));

    await tester.pumpWidget(grid(repo));
    await tester.pumpAndSettle();

    // The ↻ badge and the note glyph are both icons/glyphs with no text of their
    // own; without this they were invisible to a reader.
    expect(
      find.bySemanticsLabel('daf 4, learned, 1 chazara, has recorded details'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('the cell announces as a button, checked, and reachable',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(grid(repo));
    await tester.pumpAndSettle();

    // `isFocusable` + a focus action matter as much as the label: they are how a
    // reader arrives at the cell at all. An earlier version of this wrapped the
    // InkWell in `Semantics(excludeSemantics: true)`, which replaced the label
    // correctly and dropped the focusability with it.
    expect(
      tester.getSemantics(find.bySemanticsLabel('daf 2, learned')),
      matchesSemantics(
        label: 'daf 2, learned',
        isButton: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
        hasLongPressAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the announcement is translated with everything else',
      (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryProgressRepository();
    await repo.addEvent(done(2));

    await tester.pumpWidget(grid(repo, locale: const Locale('he')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('דף 2, נלמד'), findsOneWidget);
    expect(find.bySemanticsLabel('דף 3, לא נלמד'), findsOneWidget);
    handle.dispose();
  });
}
