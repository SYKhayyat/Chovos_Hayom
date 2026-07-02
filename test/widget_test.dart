import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/data/repositories/in_memory_progress_repository.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_catalog.dart';

void main() {
  testWidgets('dashboard renders the catalog tree and marks a daf', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(InMemoryProgressRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Top of the tree is the root category.
    expect(find.text('Kol HaTorah Kula'), findsOneWidget);

    // Drill root -> Shas -> Moed to reveal the Shabbos leaf.
    await tester.tap(find.text('Kol HaTorah Kula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moed'));
    await tester.pumpAndSettle();
    expect(find.text('Shabbos'), findsOneWidget);

    // Mark one daf; the leaf shows 1 / 156 and it rolls up through the parents
    // (Moed -> Shas -> root all show the same, since Shabbos is the only leaf).
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 / 156'), findsWidgets);
  });
}
