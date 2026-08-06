import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/chazara/chazara_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// Chazara is one of the four screens this app is *worked* on — the tree, the
/// unit grid, Cycles and the Journal are the others — so it stayed a route of
/// its own when the five report screens became tabs. These tests moved out of
/// `report_screens_test.dart` with it.
void main() {
  const profile = 'default';

  LearningEvent done(
    int unit, {
    required String id,
    DateTime? at,
    List<String> layers = const [mainLayerId],
  }) =>
      LearningEvent(
        id: id,
        profileId: profile,
        nodeId: 'shas.moed.shabbos',
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: at ?? DateTime(2026, 1, 1),
        loggedAt: at ?? DateTime(2026, 1, 1),
        layers: layers,
      );

  Widget screen(ProgressRepository repo, {DateTime? now}) => ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
          appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
          clockProvider.overrideWithValue(() => now ?? DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const ChazaraScreen()),
      );

  testWidgets('says so when nothing is due', (tester) async {
    await tester.pumpWidget(screen(memoryRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing due for review'), findsOneWidget);
  });

  testWidgets('an overdue unit is listed with how late it is', (tester) async {
    final repo = memoryRepository();
    // First interval is 1 day, so something learned on the 1st is four days
    // overdue by the 6th.
    await repo.addEvent(done(5, id: 'a', at: DateTime(2026, 1, 1)));

    await tester.pumpWidget(screen(repo, now: DateTime(2026, 1, 6)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shabbos'), findsOneWidget);
    expect(find.textContaining('4 days overdue'), findsOneWidget);
    expect(find.textContaining('no reviews so far'), findsOneWidget);
  });

  testWidgets('the quick Review button logs a pass and clears the row',
      (tester) async {
    final repo = memoryRepository();
    await repo.addEvent(done(5, id: 'a', at: DateTime(2026, 1, 1)));

    await tester.pumpWidget(screen(repo, now: DateTime(2026, 1, 6)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    final events = await repo.getEvents(profile);
    expect(events.where((e) => e.action == EventAction.reviewed), hasLength(1),
        reason: 'one tap is one review pass');
    // Reviewed today, so the next pass is not due today: the row goes, and
    // the screen falls back to its empty state.
    expect(find.textContaining('Nothing due for review'), findsOneWidget);
  });

  testWidgets('a quick review carries the mefarshim the unit was learned with',
      (tester) async {
    // The two review paths used to disagree: this button recorded only the
    // text, so a daf reviewed from here silently lost its mefarshim.
    final repo = memoryRepository();
    await repo.addEvent(done(5,
        id: 'a',
        at: DateTime(2026, 1, 1),
        layers: const [mainLayerId, 'rashi']));

    await tester.pumpWidget(screen(repo, now: DateTime(2026, 1, 6)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    final review = (await repo.getEvents(profile))
        .firstWhere((e) => e.action == EventAction.reviewed);
    expect(review.layers, containsAll(<String>[mainLayerId, 'rashi']));
  });

  testWidgets('the detailed path opens the one log form, with the timer',
      (tester) async {
    // It used to open `add_chazara_sheet.dart`, which was the log form again
    // with no session timer on it — the one action in the app where timing what
    // you are about to do is most of the point.
    final repo = memoryRepository();
    await repo.addEvent(done(5, id: 'a', at: DateTime(2026, 1, 1)));

    await tester.pumpWidget(screen(repo, now: DateTime(2026, 1, 6)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log with details'));
    await tester.pumpAndSettle();

    expect(find.text('Add chazara'), findsOneWidget);
    expect(find.text('Reviewed:'), findsOneWidget);
    expect(find.textContaining('Timer'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    // One duration field, one string. The copy asked the same question through
    // a second ARB key.
    expect(find.text('How long it took (minutes, optional)'), findsOneWidget);
  });
}
