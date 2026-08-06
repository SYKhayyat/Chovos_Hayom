import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_catalog.dart';
import 'support/memory_database.dart';

void main() {
  testWidgets('drill into a leaf, mark a daf in the grid, see it roll up',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(memoryRepository()),
        ],
        child: const ChovosHayomApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Drill Shas -> Moed, then open the Shabbos leaf's grid. The root above
    // them opens itself, so the app never lands on a single closed row.
    await tester.tap(find.text('Shas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shabbos'));
    await tester.pumpAndSettle();

    // Grid shows daf cells starting at 2 (offset).
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();

    // Back to the dashboard; Shabbos now shows 1 / 156 (rolled up too).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('1 / 156'), findsWidgets);
  });
}
