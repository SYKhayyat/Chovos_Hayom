import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/features/journal/notes_journal_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

void main() {
  testWidgets('orders notes by occurred, recorded, then id', (tester) async {
    final repo = memoryRepository();
    LearningEvent note(
      String id,
      String text, {
      required int occurredHour,
      required int loggedHour,
    }) =>
        LearningEvent(
          id: id,
          profileId: 'default',
          nodeId: 'shas.moed.shabbos',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 10, occurredHour),
          loggedAt: DateTime(2026, 1, 10, loggedHour),
          note: text,
        );

    await repo.addEvents([
      note('a', 'same time a', occurredHour: 10, loggedHour: 10),
      note('z', 'same time z', occurredHour: 10, loggedHour: 10),
      note('b', 'later recorded', occurredHour: 10, loggedHour: 12),
      note('c', 'later occurred', occurredHour: 11, loggedHour: 11),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        ],
        child: localizedApp(home: const NotesJournalScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final order = [
      'later occurred',
      'later recorded',
      'same time z',
      'same time a',
    ].map((text) => tester.getTopLeft(find.text(text)).dy).toList();
    expect(order, orderedEquals([...order]..sort()));
  });
}
