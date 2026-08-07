import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/features/common/node_picker.dart';
import 'package:chovos_hayom/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

/// There were four ways to pick a node out of the catalog and no two agreed.
///
/// The one that mattered is the node editor's parent dropdown: it sorted by
/// `a.name` — the raw English field — and labelled each row with the bare name.
/// A Hebrew reader therefore got a list in an order with no visible explanation,
/// containing four rows all reading "שבת". Both halves are tested here in
/// Hebrew, because both are invisible in English on this catalog.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  /// Four sefarim named "Shabbos", under three different works, plus a
  /// mesechta whose English and Hebrew names sort in opposite orders — Zevachim
  /// (זבחים) files under Z in English and ז in Hebrew, Arachin (ערכין) under A
  /// and ע.
  Catalog catalog() => Catalog(const [
        CatalogNode(
            id: 'root',
            parentId: null,
            name: 'Kol HaTorah Kula',
            nameHebrew: 'כל התורה כולה',
            kind: NodeKind.category),
        CatalogNode(
            id: 'shas',
            parentId: 'root',
            name: 'Shas',
            nameHebrew: 'ש״ס',
            kind: NodeKind.category),
        CatalogNode(
            id: 'shas.moed',
            parentId: 'shas',
            name: 'Moed',
            nameHebrew: 'מועד',
            kind: NodeKind.category),
        CatalogNode(
          id: 'shas.moed.shabbos',
          parentId: 'shas.moed',
          name: 'Shabbos',
          nameHebrew: 'שבת',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 156,
          unitOffset: 2,
        ),
        CatalogNode(
          id: 'shas.kodashim.zevachim',
          parentId: 'shas',
          name: 'Zevachim',
          nameHebrew: 'זבחים',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 120,
          unitOffset: 2,
        ),
        CatalogNode(
          id: 'shas.kodashim.arachin',
          parentId: 'shas',
          name: 'Arachin',
          nameHebrew: 'ערכין',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 34,
          unitOffset: 2,
        ),
        CatalogNode(
            id: 'mishnayos',
            parentId: 'root',
            name: 'Mishnayos',
            nameHebrew: 'משניות',
            kind: NodeKind.category),
        CatalogNode(
          id: 'mishnayos.shabbos',
          parentId: 'mishnayos',
          name: 'Shabbos',
          nameHebrew: 'שבת',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.perek,
          unitCount: 24,
          unitOffset: 1,
        ),
      ]);

  group('nodeChoices', () {
    test('walks the tree in order, carrying how deep each node is', () {
      final choices = nodeChoices(en, catalog());

      // Siblings in the order [Catalog] holds them — `sortOrder`, then name —
      // which is the order the tree itself is drawn in, so the picker and the
      // dashboard agree about what comes after what.
      expect(choices.map((c) => c.id).toList(), [
        'root',
        'mishnayos',
        'mishnayos.shabbos',
        'shas',
        'shas.kodashim.arachin',
        'shas.moed',
        'shas.moed.shabbos',
        'shas.kodashim.zevachim',
      ]);
      expect(choices.map((c) => c.depth).toList(), [0, 1, 2, 1, 2, 2, 3, 2]);
    });

    test('every label distinguishes a node from its namesakes', () {
      final labels = {
        for (final c in nodeChoices(en, catalog())) c.id: c.label,
      };

      // Two "Shabbos"es, and neither row is ambiguous.
      expect(labels['shas.moed.shabbos'], 'Shabbos — Shas · Moed');
      expect(labels['mishnayos.shabbos'], 'Shabbos — Mishnayos');
      // A root and its immediate children qualify nothing: everything is under
      // "Kol HaTorah Kula", so saying so adds no information.
      expect(labels['root'], 'Kol HaTorah Kula');
      expect(labels['shas'], 'Shas');
    });

    test('by name, it sorts by the label the reader is looking at', () {
      List<String> order(AppLocalizations l10n) => [
            for (final c in nodeChoices(l10n, catalog(),
                where: (n) => n.isLeaf, order: NodeOrder.name))
              c.node.id,
          ];

      // English: Arachin, Shabbos, Shabbos, Zevachim.
      expect(order(en), [
        'shas.kodashim.arachin',
        'mishnayos.shabbos',
        'shas.moed.shabbos',
        'shas.kodashim.zevachim',
      ]);
      // Hebrew: זבחים, ערכין, שבת, שבת — a different order entirely, and the
      // one a Hebrew reader can actually follow down the list. The old
      // `sort((a, b) => a.name.compareTo(b.name))` gave them the English one.
      expect(order(he), [
        'shas.kodashim.zevachim',
        'shas.kodashim.arachin',
        'mishnayos.shabbos',
        'shas.moed.shabbos',
      ]);
    });

    test('a name-ordered list carries no depth, because there is no tree left',
        () {
      final choices =
          nodeChoices(en, catalog(), order: NodeOrder.name);
      expect(choices.every((c) => c.depth == 0), isTrue);
    });

    test('exclude drops a node and everything under it', () {
      final ids = [
        for (final c in nodeChoices(en, catalog(), exclude: {'shas'})) c.id,
      ];

      // Filing Shas under Moed would orphan Moed, so neither Shas nor anything
      // beneath it may be offered as its parent.
      expect(ids, ['root', 'mishnayos', 'mishnayos.shabbos']);
    });

    test('maxDepth stops the walk without dropping the shallow siblings', () {
      final ids = [for (final c in nodeChoices(en, catalog(), maxDepth: 1)) c.id],
          deep = [for (final c in nodeChoices(en, catalog(), maxDepth: 2)) c.id];

      expect(ids, ['root', 'mishnayos', 'shas']);
      expect(deep, contains('shas.moed'));
      expect(deep, isNot(contains('shas.moed.shabbos')));
    });

    test('the two second lines say the two things a picker needs', () {
      final sized = {
        for (final c
            in nodeChoices(en, catalog(), secondary: nodeSizeLine))
          c.id: c.secondary,
      };
      expect(sized['shas.moed.shabbos'], '156 dapim');
      expect(sized['shas'], 'everything underneath');

      // The other-language name, for the list you are matching a
      // transliteration against — and null where there is nothing to add.
      final other = {
        for (final c in nodeChoices(en, catalog(), secondary: nodeOtherName))
          c.id: c.secondary,
      };
      expect(other['shas.moed.shabbos'], 'שבת');
      expect(
          nodeChoices(he, catalog(), secondary: nodeOtherName)
              .firstWhere((c) => c.id == 'shas.moed.shabbos')
              .secondary,
          'Shabbos');
    });
  });

  group('showNodePicker', () {
    /// The Sonim XP5s, which is the whole reason the size is clamped rather
    /// than fixed: 240dp is narrower than either of the two hard-coded widths
    /// the two old copies used.
    const sonim = Size(240, 324);

    testWidgets('fits inside a 240dp screen instead of hanging off it',
        (tester) async {
      tester.view.physicalSize = sonim;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final choices = nodeChoices(en, catalog(), secondary: nodeSizeLine);
      await tester.pumpWidget(localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNodePicker(context,
                    title: 'Pick one', choices: choices, showKindIcon: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final list = tester.getSize(find.byType(ListView));
      expect(list.width, lessThanOrEqualTo(sonim.width),
          reason: 'a dialog wider than the display is one whose trailing edge '
              '— where a long qualified name ends — cannot be read at all');
      expect(list.height, lessThanOrEqualTo(sonim.height));
    });

    testWidgets('returns the node that was tapped', (tester) async {
      CatalogNode? picked;
      final choices = nodeChoices(en, catalog(), where: (n) => n.isLeaf);
      await tester.pumpWidget(localizedApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await showNodePicker(context,
                    title: 'Pick one', choices: choices),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shabbos — Mishnayos'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'mishnayos.shabbos');
    });
  });

  group('NodeDropdown', () {
    Widget dropdown(List<NodeChoice> choices, String? value,
            {String? noneLabel}) =>
        localizedApp(
          home: Scaffold(
            body: NodeDropdown(
              label: 'Parent',
              choices: choices,
              value: value,
              noneLabel: noneLabel,
              onChanged: (_) {},
            ),
          ),
        );

    testWidgets('shows the qualified name, closed and open', (tester) async {
      final choices = nodeChoices(en, catalog());
      await tester.pumpWidget(
          dropdown(choices, 'mishnayos.shabbos', noneLabel: 'Top level'));
      await tester.pumpAndSettle();

      // The qualifier is in the label itself, which is what a *closed*
      // dropdown needs: one line, no neighbours, and an indent that says
      // nothing without the rows above it to measure against.
      expect(find.textContaining('Shabbos — Mishnayos'), findsWidgets);
      expect(
          tester
              .widgetList<Text>(find.textContaining('Shabbos — Mishnayos'))
              .first
              .data,
          '      Shabbos — Mishnayos',
          reason: 'and the indent is still there for when the list is open');
    });

    testWidgets('a value the list no longer contains falls back rather than '
        'throwing', (tester) async {
      // The node editor's own case: re-parenting excludes the node's subtree,
      // so a node whose current parent is inside that subtree opens with a
      // selection the list cannot offer.
      final choices = nodeChoices(en, catalog(), exclude: {'shas'});
      await tester.pumpWidget(
          dropdown(choices, 'shas.moed', noneLabel: 'Top level'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Top level'), findsOneWidget);
    });

    testWidgets('with no none entry it falls back to the first row',
        (tester) async {
      final choices = nodeChoices(en, catalog(), maxDepth: 1);
      await tester.pumpWidget(dropdown(choices, 'nothing-like-this'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kol HaTorah Kula'), findsOneWidget);
    });
  });
}
