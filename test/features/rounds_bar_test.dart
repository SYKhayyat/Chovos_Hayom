import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:chovos_hayom/features/common/rounds_bar.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/localized_app.dart';

/// #46 — the second and third lines of a sefer's bar.
///
/// The rule that matters is **a line with nothing on it is not drawn**. A sefer
/// you have learned 3 of 10 and not returned to reads `3/10` and nothing else; if
/// the empty second line were drawn, it would look like a bar reporting that you
/// are behind on something, when it means there is nothing there yet. These pin
/// that, because it is the kind of rule a future "let's always show both lines"
/// tidy-up would break without noticing anything was wrong.
void main() {
  Widget bar({
    required int learned,
    required int total,
    List<int> extra = const [],
    int overflow = 0,
  }) => localizedApp(
    home: Scaffold(
      body: RoundsBar(
        learned: learned,
        total: total,
        extra: extra,
        overflow: overflow,
      ),
    ),
  );

  // Counts the drawn lines rather than eyeballing them.
  int lines(WidgetTester tester) =>
      tester.widgetList(find.byType(LinearProgressIndicator)).length;

  testWidgets('a learned sefer shows one line and no more', (tester) async {
    // The commonest state in the app, and the one that must stay quiet: 3 of 10
    // learned, nothing returned to. No empty second line saying "0/10".
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [0, 0]));
    await tester.pumpAndSettle();

    expect(lines(tester), 1);
  });

  testWidgets('being over something once adds the second line', (tester) async {
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [1, 0]));
    await tester.pumpAndSettle();

    expect(lines(tester), 2);
  });

  testWidgets('and being over something twice adds a third', (tester) async {
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [1, 1]));
    await tester.pumpAndSettle();

    expect(lines(tester), 3);
  });

  testWidgets('the lines are different colours, so they can be told apart', (
    tester,
  ) async {
    // Colour is the only thing separating them: at 240dp the second line is 3
    // logical pixels tall, which is too thin to identify by position alone.
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [1, 1]));
    await tester.pumpAndSettle();

    final colors = [
      for (final w in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ))
        w.color,
    ];
    expect(colors.length, 3);
    expect(colors.toSet().length, 3, reason: 'each line its own colour');
  });

  testWidgets('the second line is thinner than the first', (tester) async {
    // The primary line is about the ground covered; the extras are about
    // retention. A rarer round must not outweigh the commoner one.
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [1, 1]));
    await tester.pumpAndSettle();

    final heights = [
      for (final w in tester.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      ))
        w.minHeight ?? 0,
    ];
    expect(heights[0], greaterThan(heights[1]));
    expect(heights[1], greaterThan(heights[2]));
  });

  testWidgets('a zero extra does not get a line of its own', (tester) async {
    // Even with a third round present, the *second* being empty leaves a gap
    // rather than a stack — a reader should not have to infer that "nothing at
    // 2 but something at 3" is possible.
    await tester.pumpWidget(bar(learned: 5, total: 10, extra: [0, 2]));
    await tester.pumpAndSettle();

    expect(lines(tester), 2);
  });

  testWidgets('an empty sefer draws nothing at all', (tester) async {
    await tester.pumpWidget(bar(learned: 0, total: 10, extra: [0, 0]));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a sefer with no units does not divide by zero', (tester) async {
    // An empty category: `total` is 0 and the value would be NaN.
    await tester.pumpWidget(bar(learned: 0, total: 0, extra: [1, 1]));
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rounds past the third are reported rather than drawn', (
    tester,
  ) async {
    // A bar that quietly stops at three lines claims a depth it does not have.
    // The overflow marker says there is more.
    await tester.pumpWidget(
      bar(learned: 6, total: 10, extra: [3, 2], overflow: 2),
    );
    await tester.pumpAndSettle();

    expect(lines(tester), 3, reason: 'three lines is the cap');
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('nothing is marked overflow when the rounds fit', (tester) async {
    await tester.pumpWidget(bar(learned: 3, total: 10, extra: [1, 1]));
    await tester.pumpAndSettle();

    expect(find.textContaining('+'), findsNothing);
  });

  group('how deep the rounds go', () {
    // What tells the bar whether it is hiding rounds behind the "+n" marker.

    ProgressNode node({int learned = 0, int again = 0, int thrice = 0}) =>
        ProgressNode(
          node: const CatalogNode(
            id: 'a',
            parentId: null,
            name: 'A',
            kind: NodeKind.leaf,
            unitLabel: UnitLabel.daf,
            unitCount: 10,
          ),
          learned: learned,
          total: 10,
          children: const [],
          finishedAgain: again,
          finishedAgainAgain: thrice,
        );

    test('a sefer with nothing in it has no rounds', () {
      expect(node().maxRound, 0);
    });

    test('learning one unit is round one', () {
      expect(node(learned: 3).maxRound, 1);
    });

    test('going back to something is round two', () {
      expect(node(learned: 3, again: 1).maxRound, 2);
    });

    test('going back twice is round three', () {
      expect(node(learned: 3, again: 1, thrice: 1).maxRound, 3);
    });
  });
}
