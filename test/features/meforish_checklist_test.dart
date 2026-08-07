import 'package:chovos_hayom/application/logging_service.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The three sheets that show a meforish checklist, through the app rather than
/// through the query underneath them.
///
/// `unit_mefarshim_test.dart` holds the arithmetic. This holds the thing the
/// arithmetic was wrong about: a meforish learned on a unit and **deleted
/// afterwards**. Every one of the three sheets had its own answer, and the
/// chazara sheet's was the one that could submit a layer the user could not
/// see.
void main() {
  const node = 'shas.moed.shabbos';
  const unit = 2;
  const deleted = 'a-meforish-since-deleted';

  Widget grid(ProgressRepository repo) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: localizedApp(home: const UnitGridScreen(nodeId: node)),
      );

  /// A profile where daf 2 was finished with the text and one meforish, and
  /// that meforish has since been deleted — its rows are gone from the layer
  /// settings and from the mefarshim list, and its id survives only in the log,
  /// which is deliberate: the daf really was learned with it.
  Future<ProgressRepository> profileWithADeletedMeforish() async {
    final repo = memoryRepository();
    await repo.setLayerConfig(
      'default',
      const LayerConfigEntry(
        nodeId: node,
        unitIndex: -1,
        roles: {mainLayerId: LayerRole.required, 'rashi': LayerRole.required},
      ),
    );
    final logger = LoggingService(repository: repo, profileId: 'default');
    await logger.markDone(node, unit, layers: const [mainLayerId]);
    await logger.markDone(node, unit, layers: const ['rashi']);
    await logger.markDone(node, unit, layers: const [deleted]);
    return repo;
  }

  /// Long-presses daf 2 and picks [action] out of the cell menu.
  Future<void> cellMenu(WidgetTester tester, String action) async {
    await tester.longPress(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('the per-unit checklist names it rather than printing its uuid',
      (tester) async {
    await tester.pumpWidget(grid(await profileWithADeletedMeforish()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    expect(find.text('Deleted meforish'), findsOneWidget);
    expect(find.textContaining(deleted), findsNothing);
  });

  testWidgets('a chazara can be recorded on it — and can be unticked',
      (tester) async {
    await tester.pumpWidget(grid(await profileWithADeletedMeforish()));
    await tester.pumpAndSettle();
    await cellMenu(tester, 'Add chazara (review)');

    // It is seeded — a fresh pass reviews everything currently learned — and
    // that is only sound if it also has a row. The old sheet filtered its
    // options through the mefarshim list while seeding from the log, so this
    // layer was selected and invisible: submitted with nothing to untick it
    // from.
    final row = find.ancestor(
      of: find.text('Deleted meforish'),
      matching: find.byType(CheckboxListTile),
    );
    expect(row, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(row).value, isTrue);

    await tester.tap(find.text('Deleted meforish'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(row).value, isFalse);
  });

  testWidgets('but a fresh log does not offer it, because the unit does not '
      'ask for it any more', (tester) async {
    await tester.pumpWidget(grid(await profileWithADeletedMeforish()));
    await tester.pumpAndSettle();
    // Daf 2 is already finished, so the menu offers *re*-log.
    await cellMenu(tester, 'Re-log with date / duration / note');

    expect(find.text('Deleted meforish'), findsNothing);
    // The two the unit does still ask for are there.
    expect(find.text('Text (guf)'), findsOneWidget);
    expect(find.text('Rashi'), findsOneWidget);
  });
}
