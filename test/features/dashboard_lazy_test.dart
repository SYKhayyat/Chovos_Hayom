import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';
import 'package:chovos_hayom/features/dashboard/progress_tile.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_progress_repository.dart';

const _categories = 20;
const _leavesEach = 20;
// root + categories + their leaves
const _totalNodes = 1 + _categories + _categories * _leavesEach;

/// A catalog big enough that mounting all of it would be obvious — the real one
/// is 312 nodes, this is 421.
Catalog _bigCatalog() {
  final nodes = <CatalogNode>[
    const CatalogNode(
        id: 'root', parentId: null, name: 'Kol HaTorah Kula', kind: NodeKind.category),
  ];
  for (var c = 0; c < _categories; c++) {
    nodes.add(CatalogNode(
        id: 'cat$c', parentId: 'root', name: 'Category $c', kind: NodeKind.category));
    for (var l = 0; l < _leavesEach; l++) {
      nodes.add(CatalogNode(
        id: 'cat$c.leaf$l',
        parentId: 'cat$c',
        name: 'Sefer $c-$l',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 10,
        unitOffset: 1,
      ));
    }
  }
  return Catalog(nodes);
}

class _BigCatalogRepository implements CatalogRepository {
  @override
  Future<Catalog> load() async => _bigCatalog();
}

/// The dashboard tree must render lazily. It used to be an eager `ListView` of
/// recursive `ExpansionTile`s, so *Expand all* mounted every node — each with a
/// LinearProgressIndicator plus a per-meforish bar row — in a single frame, which
/// is the one action that janks on a mid-range phone.
void main() {
  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_BigCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('expand-all reveals the tree without mounting all of it',
      (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();

    // It really did expand: a first-generation child is on screen...
    expect(find.text('Category 0'), findsOneWidget);
    // ...and so is one of its leaves, so the expansion cascaded.
    expect(find.text('Sefer 0-0'), findsOneWidget);

    // ...but only a screenful of rows is actually built.
    final mounted = find.byType(ProgressTile).evaluate().length;
    expect(
      mounted,
      lessThan(_totalNodes ~/ 4),
      reason: 'expand-all mounted $mounted of $_totalNodes tiles — the tree is '
          'not rendering lazily',
    );
  });

  testWidgets('collapse-all returns to the roots', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();
    expect(find.text('Category 0'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pumpAndSettle();

    // Only the root survives; its children are gone from the flattened list.
    expect(find.text('Kol HaTorah Kula'), findsOneWidget);
    expect(find.text('Category 0'), findsNothing);
    expect(find.byType(ProgressTile), findsOneWidget);
  });

  testWidgets('expanding one node does not expand its siblings',
      (tester) async {
    await pumpDashboard(tester);

    // Open the root, then a single category.
    await tester.tap(find.text('Kol HaTorah Kula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category 0'));
    await tester.pumpAndSettle();

    expect(find.text('Sefer 0-0'), findsOneWidget);
    // Category 1 stayed closed, so none of its leaves entered the flattened
    // list. (Category 1's own row is itself off-screen — Category 0's twenty
    // leaves now sit above it — which is the laziness doing its job.)
    expect(find.text('Sefer 1-0'), findsNothing);
  });
}
