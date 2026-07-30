import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/features/search/catalog_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

/// Search over the catalog.
void main() {
  /// [count] leaves that all match "shiur", plus one that does not.
  List<CatalogNode> manyMatching(int count) => [
        for (var i = 1; i <= count; i++)
          CatalogNode(
            id: 'n$i',
            parentId: null,
            name: 'Shiur ${i.toString().padLeft(2, '0')}',
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.daf,
            unitCount: 10,
          ),
        const CatalogNode(
            id: 'other', parentId: null, name: 'Bereishis', kind: NodeKind.leaf),
      ];

  /// The shape the real catalog has, and the reason the qualifier is needed:
  /// one name under three different corpora.
  Catalog fourShabboses() => Catalog(const [
        CatalogNode(id: 'all', parentId: null, name: 'Kol HaTorah Kula', kind: NodeKind.category),
        CatalogNode(id: 'shas', parentId: 'all', name: 'Shas', kind: NodeKind.category),
        CatalogNode(id: 'moedShas', parentId: 'shas', name: 'Moed', kind: NodeKind.category),
        CatalogNode(
            id: 'shabbosShas',
            parentId: 'moedShas',
            name: 'Shabbos',
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.daf,
            unitCount: 156),
        CatalogNode(id: 'mishnayos', parentId: 'all', name: 'Mishnayos', kind: NodeKind.category),
        CatalogNode(id: 'moedMishnayos', parentId: 'mishnayos', name: 'Moed', kind: NodeKind.category),
        CatalogNode(
            id: 'shabbosMishnayos',
            parentId: 'moedMishnayos',
            name: 'Shabbos',
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.perek,
            unitCount: 24),
        CatalogNode(id: 'yerushalmi', parentId: 'all', name: 'Yerushalmi', kind: NodeKind.category),
        CatalogNode(
            id: 'shabbosYerushalmi',
            parentId: 'yerushalmi',
            name: 'Shabbos',
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.daf,
            unitCount: 92),
      ]);

  testWidgets('every result says which corpus it is in', (tester) async {
    // G5: the catalog used to answer this by *typing* "(Shas)" into 120 of its
    // 312 names, so a search for "shabbos" returned four rows of which the
    // first — plain "Shabbos", the Mishnayos one nobody had annotated — was the
    // one you could not identify.
    final delegate = CatalogSearchDelegate(fourShabboses());
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showSearch(context: context, delegate: delegate),
              child: const Text('search'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'shabbos');
    await tester.pumpAndSettle();

    expect(find.text('Shabbos'), findsNWidgets(3));
    expect(find.text('Shas · Moed · 156 dapim'), findsOneWidget);
    expect(find.text('Mishnayos · Moed · 24 perakim'), findsOneWidget);
    // Directly under a corpus: the path is that corpus alone, and the root is
    // never named — everything is under Kol HaTorah Kula, so it qualifies
    // nothing.
    expect(find.text('Yerushalmi · 92 dapim'), findsOneWidget);
    expect(find.textContaining('Kol HaTorah Kula'), findsNothing);
  });

  test('every match is returned, with no cap and nothing dropped', () {
    // There was a `.take(50)` here and nothing said it had happened, so a search
    // for a common word showed fifty rows and silently discarded the rest —
    // including, possibly, the one being looked for. Sixty is chosen to sit just
    // past the old ceiling.
    final delegate = CatalogSearchDelegate(Catalog(manyMatching(60)))..query = 'shiur';

    expect(delegate.matches(), hasLength(60));
    expect(delegate.matches().last.name, 'Shiur 60',
        reason: 'the results past the old cap are the ones that vanished');
  });

  test('a query matching nothing returns nothing, not everything', () {
    final delegate = CatalogSearchDelegate(Catalog(manyMatching(3)))..query = 'zzz';

    expect(delegate.matches(), isEmpty);
  });

  test('an empty query is not a match-all', () {
    final delegate = CatalogSearchDelegate(Catalog(manyMatching(3)))..query = '   ';

    expect(delegate.matches(), isEmpty);
  });

  testWidgets('the results past the old cap really are reachable',
      (tester) async {
    // The list is lazy, so "60 matches" from the function above is not by itself
    // proof that a user can get to the sixtieth. A viewport tall enough for all
    // of them says so without driving a scroll: `ListView.builder` builds what
    // fits, and what fits here is everything.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4400);
    addTearDown(tester.view.reset);

    final delegate = CatalogSearchDelegate(Catalog(manyMatching(60)));
    await tester.pumpWidget(localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showSearch(context: context, delegate: delegate),
              child: const Text('search'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'shiur');
    await tester.pumpAndSettle();

    expect(find.text('Shiur 60'), findsOneWidget,
        reason: 'the sixtieth match is what the old cap threw away');
    expect(find.text('Shiur 01'), findsOneWidget);
  });
}
