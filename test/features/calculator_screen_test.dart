import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/features/calculator/calculator_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

void main() {
  testWidgets('forward calc projects a finish date at 1/day', (tester) async {
    final clock = DateTime(2026, 1, 1, 12);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider
              .overrideWithValue(memoryRepository()),
          clockProvider.overrideWithValue(() => clock),
        ],
        child: localizedApp(home: const CalculatorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Default node = root (156 units in the fake catalog), default rate = 1/day.
    expect(find.textContaining('156 of 156 left'), findsOneWidget);
    expect(find.textContaining('You will finish on'), findsOneWidget);

    // Switch to the custom-cycle mode; default 7-day cycle should compute.
    await tester.tap(find.text('Cycle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cycle length: 7 days'), findsOneWidget);
    expect(find.textContaining('You will finish on'), findsOneWidget);
  });
}
