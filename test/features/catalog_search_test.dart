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

  test('every match is returned, with no cap and nothing dropped', () {
    // There was a `.take(50)` here and nothing said it had happened, so a search
    // for a common word showed fifty rows and silently discarded the rest —
    // including, possibly, the one being looked for. Sixty is chosen to sit just
    // past the old ceiling.
    final delegate = CatalogSearchDelegate(manyMatching(60))..query = 'shiur';

    expect(delegate.matches(), hasLength(60));
    expect(delegate.matches().last.name, 'Shiur 60',
        reason: 'the results past the old cap are the ones that vanished');
  });

  test('a query matching nothing returns nothing, not everything', () {
    final delegate = CatalogSearchDelegate(manyMatching(3))..query = 'zzz';

    expect(delegate.matches(), isEmpty);
  });

  test('an empty query is not a match-all', () {
    final delegate = CatalogSearchDelegate(manyMatching(3))..query = '   ';

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

    final delegate = CatalogSearchDelegate(manyMatching(60));
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
