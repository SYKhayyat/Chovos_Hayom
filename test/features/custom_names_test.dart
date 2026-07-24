import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/features/custom_node/add_custom_node_screen.dart';
import 'package:chovos_hayom/features/unit_grid/mefarshim_config_sheet.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/in_memory_progress_repository.dart';
import '../support/localized_app.dart';

/// Anything the user creates can carry both names, in either order.
///
/// The bundled catalog now has a Hebrew name for all 312 nodes, and the built-in
/// mefarshim always did — so the only things that could still read as English
/// under a Hebrew locale are the ones the *user* adds. Both forms take both
/// names, either alone is enough, and a custom meforish can be edited after the
/// fact, which it could not before: it could only be created and deleted, so a
/// Hebrew name you didn't type at creation was unreachable except by deleting
/// the meforish and every required/offered set that named it.
void main() {
  /// Brings [finder] into view.
  ///
  /// Both forms scroll and their confirm button sits at the bottom. A lazy
  /// sliver does not *build* its off-screen children at all, so the button is
  /// not merely invisible — it does not exist to be found — which rules out
  /// `ensureVisible` on its own. And `scrollUntilVisible` insists on exactly one
  /// Scrollable, while these screens have several (the form's list plus each
  /// dropdown's). So: drag the outermost scrollable until the target exists,
  /// then let ensureVisible finish the job.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(FilledButton, label);
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> enterInto(
      WidgetTester tester, String label, String value) async {
    final finder = find.widgetWithText(TextField, label);
    await reveal(tester, finder);
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
  }

  Widget nodeForm(InMemoryProgressRepository repo,
          {Locale locale = const Locale('en')}) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: localizedApp(
            home: const AddCustomNodeScreen(), locale: locale),
      );

  Widget mefarshimSheet(InMemoryProgressRepository repo,
          {Locale locale = const Locale('en')}) =>
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo),
        ],
        child: localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showMefarshimConfigSheet(context, ref,
                      node: const CatalogNode(
                          id: 'shas',
                          parentId: 'root',
                          name: 'Shas',
                          kind: NodeKind.category)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          locale: locale,
        ),
      );

  group('custom sefer', () {
    testWidgets('offers both names, labelled so the pairing is obvious',
        (tester) async {
      await tester.pumpWidget(nodeForm(InMemoryProgressRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Name (English)'), findsOneWidget);
      expect(find.text('Name (Hebrew)'), findsOneWidget);
    });

    testWidgets('a Hebrew-only name is enough', (tester) async {
      // Someone working entirely in Hebrew should not have to invent a
      // transliteration to get past the form.
      final repo = InMemoryProgressRepository();
      await tester.pumpWidget(nodeForm(repo));
      await tester.pumpAndSettle();

      await enterInto(tester, 'Name (Hebrew)', 'מסילת ישרים');
      await tapButton(tester, 'Add');

      final saved = (await repo.watchCustomNodes('default').first).single;
      expect(saved.nameHebrew, 'מסילת ישרים');
      // ...and it stands in as the primary name, so an English locale shows it
      // rather than a blank.
      expect(saved.name, 'מסילת ישרים');
    });

    testWidgets('an English-only name still works', (tester) async {
      final repo = InMemoryProgressRepository();
      await tester.pumpWidget(nodeForm(repo));
      await tester.pumpAndSettle();

      await enterInto(tester, 'Name (English)', 'Mesilas Yesharim');
      await tapButton(tester, 'Add');

      final saved = (await repo.watchCustomNodes('default').first).single;
      expect(saved.name, 'Mesilas Yesharim');
      expect(saved.nameHebrew, isNull);
    });

    testWidgets('neither name is refused, and says why', (tester) async {
      final repo = InMemoryProgressRepository();
      await tester.pumpWidget(nodeForm(repo));
      await tester.pumpAndSettle();

      await tapButton(tester, 'Add');

      expect(find.textContaining('in either language'), findsOneWidget);
      expect(await repo.watchCustomNodes('default').first, isEmpty);
    });
  });

  group('custom meforish', () {
    testWidgets('can be given a Hebrew name after it was created',
        (tester) async {
      final repo = InMemoryProgressRepository();
      await repo.addCustomLayer(
          'default', const Layer(id: 'ml', name: 'Maharal'));

      await tester.pumpWidget(mefarshimSheet(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The affordance that did not exist at all before.
      await reveal(tester, find.byTooltip('Edit meforish'));
      await tester.tap(find.byTooltip('Edit meforish'));
      await tester.pumpAndSettle();

      // Scoped to the dialog: the sheet behind it has a Save button of its own.
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextField, 'Name (Hebrew)')),
          'מהר״ל');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Save')));
      await tester.pumpAndSettle();

      final saved = (await repo.watchCustomLayers('default').first).single;
      expect(saved.nameHebrew, 'מהר״ל');
      // The id is unchanged, so every event and every required/offered set that
      // named this meforish still points at it.
      expect(saved.id, 'ml');
      expect(saved.name, 'Maharal');
    });

    testWidgets('built-in mefarshim are not the user\'s to rename',
        (tester) async {
      final repo = InMemoryProgressRepository();
      await tester.pumpWidget(mefarshimSheet(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Only custom layers get the pencil; there are none yet.
      expect(find.byTooltip('Edit meforish'), findsNothing);
      expect(find.text('Rashi'), findsOneWidget);
    });

    testWidgets('a Hebrew-only meforish name is enough', (tester) async {
      final repo = InMemoryProgressRepository();
      await tester.pumpWidget(mefarshimSheet(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Add a meforish'));
      await tester.tap(find.text('Add a meforish'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextField, 'Name (Hebrew)')),
          'פני יהושע');
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Add')));
      await tester.pumpAndSettle();

      final saved = (await repo.watchCustomLayers('default').first).single;
      expect(saved.nameHebrew, 'פני יהושע');
      expect(saved.name, 'פני יהושע');
    });
  });
}
