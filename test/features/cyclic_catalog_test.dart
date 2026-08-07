import 'dart:convert';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/application/catalog_editor.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/features/history/bulk_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The two walks that had no guard, run against the shape that used to wedge
/// them.
///
/// `BulkHistoryScreen._commonAncestor` and `CatalogEditor.cloneStructure` both
/// walk the parent relation with no visited-set. Neither of them is careless:
/// six other walks in this app do keep one, and a reader of any of those six
/// would reasonably conclude the tree can loop — these two concluded it cannot.
/// Both were right about the *intent* and wrong about the *data*, because an
/// override row is not constrained by the form that writes it.
///
/// These are end-to-end on purpose. The old shape did not fail here, it failed
/// to return: `chainOf` grows a list forever, and `collect` recurses forever.
/// A test that reasons about the walk cannot tell you the screen came back, so
/// these pump the screen and call the editor.
///
/// The cycle is installed the way a user would actually acquire one — by
/// importing a hand-edited backup — which is also the path that used to be
/// refused, and now is not.
void main() {
  const profile = 'default';

  /// An override making `shas` a child of its own child, closing a loop in which
  /// every id belongs to the bundled catalog.
  final loop = jsonEncode({
    'version': BackupService.currentVersion,
    'events': const [],
    'customNodes': [
      const CatalogNode(
        id: 'shas',
        parentId: 'shas.moed',
        name: 'Shas',
        kind: NodeKind.category,
      ).toJson(),
    ],
  });

  ProviderContainer container(ProgressRepository repo) =>
      ProviderContainer(overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
      ]);

  Future<ProviderContainer> withLoopImported(ProgressRepository repo) async {
    await BackupService(repo).importInto(profile, loop);
    final c = container(repo);
    addTearDown(c.dispose);
    final sub = c.listen(mergedCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(catalogProvider.future);
    await pumpEventQueue();
    return c;
  }

  test('a backup that closes a loop is imported rather than refused', () async {
    final repo = memoryRepository();
    // This used to throw "…is its own ancestor". Refusing was the wrong verb:
    // the file is the user's own export, everything else in it is fine, and the
    // one bad link is repairable without asking them anything.
    final c = await withLoopImported(repo);

    expect((await repo.getCustomNodes(profile)).single.id, 'shas');
    final catalog = c.read(mergedCatalogProvider).value!;
    // The loop is cut at the lower id, so Shas is a root and everything under
    // it keeps its place — nothing the user had is missing from the tree.
    expect(catalog.byId('shas')!.parentId, isNull);
    expect(catalog.childrenOf('shas').map((n) => n.id), ['shas.moed']);
    expect(catalog.childrenOf('shas.moed').map((n) => n.id),
        ['shas.moed.shabbos']);
    expect(catalog.leavesUnder('shas').map((n) => n.id), ['shas.moed.shabbos']);
  });

  testWidgets('the bulk history screen returns on a looped catalog',
      (tester) async {
    final repo = memoryRepository();
    // Two nodes in one batch, because `_where` names a single-node batch
    // straight off `byId` and only walks ancestors when it has to reconcile
    // several — which is what a "finish all" on a category produces.
    await repo.addEvents([
      for (final (id, node) in [
        ('a', 'shas.moed.shabbos'),
        ('b', 'shas.moed'),
      ])
        LearningEvent(
          id: id,
          profileId: profile,
          nodeId: node,
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 5, 14, 30),
          loggedAt: DateTime(2026, 1, 5, 14, 30),
          batchId: 'b1',
        ),
    ]);
    await BackupService(repo).importInto(profile, loop);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
        appPreferencesProvider.overrideWithValue(InMemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
      ],
      child: localizedApp(home: const BulkHistoryScreen()),
    ));
    await tester.pumpAndSettle();

    // Reaching this line at all is the assertion; the caption is the proof that
    // the ancestor walk finished with the right answer rather than an early
    // bail-out. Moed is the deepest node containing both, which is only true
    // once the loop above it has been cut.
    expect(find.textContaining('Finished 2 units'), findsOneWidget);
    expect(find.textContaining('Moed'), findsOneWidget);
  });

  testWidgets('cloning a subtree returns on a looped catalog', (tester) async {
    final repo = memoryRepository();
    await BackupService(repo).importInto(profile, loop);

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        progressRepositoryProvider.overrideWithValue(repo),
      ],
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        // Watched so the merged catalog is built and kept alive for the editor.
        ref.watch(mergedCatalogProvider);
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();

    final catalog = captured.read(mergedCatalogProvider).value!;
    // The real editor, not a copy of its walk: `catalog_clone_test.dart` lifts
    // `collect` out into the test file, which is why it could never have seen
    // this.
    await CatalogEditor(captured).cloneStructure(catalog.byId('shas')!);
    await tester.pumpAndSettle();

    final copies = (await repo.getCustomNodes(profile))
        .where((n) => n.name.endsWith('(copy)'));
    expect(copies, hasLength(1), reason: 'the clone finished, once');
    // Four nodes cloned (shas, moed, shabbos) plus the override row itself.
    expect((await repo.getCustomNodes(profile)).length, 4);
  });
}
