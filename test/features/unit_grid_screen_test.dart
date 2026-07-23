import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/features/unit_grid/unit_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';

/// The grid is addressed by id, which is what makes `/sefer/<id>` a route — and
/// what fixes a staleness bug on the way. Holding a `CatalogNode` froze the
/// screen at the moment it was pushed, so an edit made while it was open (from
/// the tree behind it, or from another profile's data arriving) was invisible
/// until you backed out and came in again.
void main() {
  Widget grid(InMemoryProgressRepository repo, {String id = 'shas.moed.shabbos'}) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: UnitGridScreen(nodeId: id)),
      );

  testWidgets('the title follows a rename made while the grid is open',
      (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(grid(repo));
    await tester.pumpAndSettle();
    expect(find.text('Shabbos'), findsOneWidget);

    await repo.addCustomNode(
        'default', fakeCatalog().byId('shas.moed.shabbos')!.copyWith(name: 'Shabbos ב'));
    await tester.pumpAndSettle();

    expect(find.text('Shabbos ב'), findsOneWidget);
    expect(find.text('Shabbos'), findsNothing);
  });

  testWidgets('a unit count raised while the grid is open grows the grid',
      (tester) async {
    final repo = InMemoryProgressRepository();
    await tester.pumpWidget(grid(repo));
    await tester.pumpAndSettle();

    await repo.addCustomNode('default',
        fakeCatalog().byId('shas.moed.shabbos')!.copyWith(unitCount: 3));
    await tester.pumpAndSettle();

    // Offset 2, three units: 2, 3, 4 — and nothing beyond.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });

  testWidgets('an id that does not resolve says so instead of spinning forever',
      (tester) async {
    await tester.pumpWidget(grid(InMemoryProgressRepository(), id: 'gone'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('no longer exists'), findsOneWidget);
  });
}
