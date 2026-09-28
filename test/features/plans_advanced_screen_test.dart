import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/edit_plan_advanced_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// The depth of a plan: the days that differ from the base amount, and the
/// seferim it works through in order (#35).
///
/// The test that matters most here is the one about `0`. A day off is an amount
/// rather than a flag precisely so that "nothing on this day" and "not set" stay
/// different facts, and the UI is the only place that can blur them.
void main() {
  const sonim = Size(240, 324);

  late InMemoryPreferences prefs;

  setUp(() => prefs = InMemoryPreferences());

  LearningPlan seed({int unitsPerDay = 10}) => LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: unitsPerDay,
        assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
      );

  Future<void> put(LearningPlan plan) => prefs.setString(
      PrefKeys.scoped('default', PrefKeys.plans),
      jsonEncode(PlansConfig(plans: [plan]).toJson()));

  PlansConfig config() {
    final raw =
        prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ?? '{}';
    return PlansConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// The screen with [repo] as its progress store, so a test can put custom
  /// sefarim into the catalog before the screen reads it.
  ///
  /// Shared with the one that needs an extra leaf, because a fake second
  /// catalog would have made the merge — which is how a user's own sefer
  /// reaches the tree — the thing under test instead of the sequence.
  Future<void> pumpWith(
    WidgetTester tester, {
    Size? size,
    ProgressRepository? repo,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size ?? const Size(800, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repo ?? memoryRepository()),
          clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
        ],
        child: localizedApp(home: const EditPlanAdvancedScreen(planId: 'p')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {Size? size, ProgressRepository? repo}) =>
      pumpWith(tester, size: size, repo: repo);

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps the sequence's *Add a sefer* **button**.
  ///
  /// Scoped to the button because the picker's own title is the same string —
  /// `find.text('Add a sefer')` matches twice the moment the dialog is open, and
  /// a finder that matches two things taps neither.
  Future<void> tapAddSefer(WidgetTester tester) =>
      scrollAndTap(tester, find.widgetWithText(TextButton, 'Add a sefer'));

  /// Picks a weekday in the picker sheet, then types an amount and saves.
  Future<void> addWeekday(
    WidgetTester tester,
    String weekdayName,
    String amount,
  ) async {
    await scrollAndTap(tester, find.text('Add a weekday'));
    // A weekday that already has an override shows twice - as its row and in
    // the sheet - and the sheet is on top, so the last match is the right one.
    await scrollAndTap(tester, find.text(weekdayName).last);
    await tester.enterText(find.byType(TextField).last, amount);
    await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
  }


  group('weekday overrides', () {
    testWidgets('says so when every day is the same', (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.text('Every day asks the same amount.'), findsOneWidget);
    });

    testWidgets('an added weekday shows its own amount, not the base',
        (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Tuesday', '5');
      // Asserted before saving: saving pops the screen, so afterwards there is
      // nothing left to read the row off.
      expect(find.text('5'), findsOneWidget,
          reason: 'the base is 10, so a row reading "10" would prove nothing');
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, {DateTime.tuesday: 5});
    });

    testWidgets('two weekdays can differ from each other', (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Tuesday', '5');
      await addWeekday(tester, 'Thursday', '15');
      await scrollAndTap(tester, find.text('Save'));

      expect(config().plans.single.weekdayAmounts,
          {DateTime.tuesday: 5, DateTime.thursday: 15});
    });

    testWidgets('a weekday can be removed again', (tester) async {
      await put(const LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 10,
        weekdayAmounts: {DateTime.friday: 3},
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
      ));
      await pump(tester);
      expect(find.text('3'), findsOneWidget);

      // Keyed, because a ListView only builds what is on screen: locating the
      // row by its text, or by "the last tile", silently depends on scroll
      // position and breaks the moment a row is added or removed.
      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('weekday-${DateTime.friday}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, isEmpty);
    });

    testWidgets('a bad amount is refused, not saved', (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a weekday'));
      await scrollAndTap(tester, find.text('Wednesday'));
      await tester.enterText(find.byType(TextField).last, '-3');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('Enter a whole number, zero or more.'), findsOneWidget);

      // And the sheet is still open, so nothing was silently stored.
      expect(config().plans.single.weekdayAmounts, isEmpty);
    });
  });

  group('zero is a deliberate amount, not an empty field', () {
    testWidgets('a weekday set to 0 says so', (tester) async {
      await put(seed());
      await pump(tester);
      await addWeekday(tester, 'Friday', '0');

      // "0" alone is a number the eye slides past; "0 · day off" is a fact.
      expect(find.text('0 · day off'), findsOneWidget);
      expect(find.text('Every day asks the same amount.'), findsNothing,
          reason: 'a rest day is not the same as no override');

      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.weekdayAmounts, {DateTime.friday: 0});
    });

    testWidgets('a date set to 0 says so and survives the round trip',
        (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      // The picker opens on the clock's day; take it as-is.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));

      expect(find.text('0 · day off'), findsOneWidget);
      await scrollAndTap(tester, find.text('Save'));

      final dates = config().plans.single.dateAmounts;
      expect(dates, hasLength(1));
      expect(dates.values.single, 0);
    });
  });

  group('date overrides', () {
    testWidgets('says so when no date differs', (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.text('Every date asks the same amount.'), findsOneWidget);
    });

    testWidgets('an added date is stored under its own day', (tester) async {
      await put(seed());
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '4');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      await scrollAndTap(tester, find.text('Save'));

      // The clock's day, derived rather than hard-coded: a guessed ordinal is
      // how this test came to expect 11 April.
      expect(config().plans.single.dateAmounts, {Day.of(DateTime(2026, 1, 10)): 4});
    });

    testWidgets('a date can be removed', (tester) async {
      await put(seed(
        unitsPerDay: 10,
      ));
      await pump(tester);
      await scrollAndTap(tester, find.text('Add a date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '4');
      await scrollAndTap(tester, find.widgetWithText(FilledButton, 'Save'));
      await scrollAndTap(
        tester,
        find.descendant(
          of: find.byKey(ValueKey('date-${Day.of(DateTime(2026, 1, 10))}')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await scrollAndTap(tester, find.text('Save'));
      expect(config().plans.single.dateAmounts, isEmpty);
    });
  });

  group('the item sequence', () {
    /// Picks a sefer from the shared node picker, the way a user does.
    Future<void> addSefer(WidgetTester tester, String label) async {
      await tapAddSefer(tester);
      // The row is the picker's own, and the dialog sits above the form, so the
      // last match is the one on top.
      await scrollAndTap(tester, find.text(label).last);
    }

    /// A plan whose sequence is [nodes], in order.
    LearningPlan sequenced(List<String> nodes) => LearningPlan(
          id: 'p',
          name: 'Yoma',
          unitsPerDay: 10,
          assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
          items: [
            for (var i = 0; i < nodes.length; i++)
              PlanItem(id: 'i$i', nodeId: nodes[i]),
          ],
        );

    /// The node ids of the saved sequence, in order.
    List<String> sequence() =>
        config().plans.single.items.map((i) => i.nodeId).toList();

    /// The *Move up* / *Move down* button on the row for [id].
    ///
    /// Reached through the row's key and then the button's tooltip, because
    /// those are the two things that mean the same thing on a D-pad. The index
    /// is not a finder: a `ListView` builds lazily, so "the second tile" is a
    /// claim about scroll position that stops being true the moment a row is
    /// added.
    Finder moveButton(String id, {required bool up}) => find.descendant(
          of: find.byKey(ValueKey('item-$id')),
          matching: find.byTooltip(up ? 'Move up' : 'Move down'),
        );

    /// The [IconButton] carrying that tooltip, taken as an **ancestor** of it.
    ///
    /// `IconButton` builds the [Tooltip] inside itself rather than around it, so
    /// the tooltip finder lands one level too deep to search *downwards* for the
    /// button — which reads as "the widget is missing" and is really a finder
    /// pointing the wrong way.
    IconButton moveIconButton(
      WidgetTester tester,
      String id, {
      required bool up,
    }) =>
        tester.widget<IconButton>(
          find
              .ancestor(
                of: moveButton(id, up: up),
                matching: find.byType(IconButton),
              )
              .first,
        );

    Finder removeButton(String id) => find.descendant(
          of: find.byKey(ValueKey('item-$id')),
          matching: find.byIcon(Icons.close),
        );

    testWidgets('a sefer can be added to the sequence', (tester) async {
      await put(seed());
      await pump(tester);
      await addSefer(tester, 'Shabbos — Shas · Moed');
      await scrollAndTap(tester, find.text('Save'));

      expect(sequence(), ['shas.moed.shabbos']);
    });

    testWidgets('a category becomes one item, not one per sefer under it',
        (tester) async {
      // "Shas · Moed" holds Shabbos and Eruvin, so a picker that expanded it
      // would add two rows and the total would count Shabbos twice.
      final repo = memoryRepository();
      await repo.addCustomNode(
        'default',
        const CatalogNode(
          id: 'shas.moed.eruvin',
          parentId: 'shas.moed',
          name: 'Eruvin',
          kind: NodeKind.leaf,
          unitLabel: UnitLabel.daf,
          unitCount: 104,
          unitOffset: 2,
        ),
      );
      await put(seed());
      await pumpWith(tester, repo: repo);
      await addSefer(tester, 'Moed — Shas');

      // Read before saving: saving pops the screen, so afterwards there is
      // nothing left to read the total off. One row, because a category is one
      // step — and the row count is the thing an expanded picker gets wrong.
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .where((t) => t.key.toString().contains('item-')),
        hasLength(1),
      );
      // 156 + 104, so an expanded picker would have said 416 and listed two rows.
      expect(find.text('260 units in total'), findsOneWidget);
      await scrollAndTap(tester, find.text('Save'));
      expect(sequence(), ['shas.moed']);
    });

    testWidgets('the total counts the units under every sefer in it',
        (tester) async {
      await put(sequenced(['shas.moed.shabbos', 'shas.moed']));
      await pump(tester);

      // 156 under the leaf, 156 under the category that contains it — a
      // sequence may revisit a sefer, and each item is counted once.
      expect(find.text('312 units in total'), findsOneWidget);
    });

    testWidgets('the up and down buttons reorder, and the ends cannot move off',
        (tester) async {
      await put(sequenced(['shas.moed.shabbos', 'shas.moed']));
      await pump(tester);
      // Brought into view before being read. The rows are the last thing on a
      // tall `ListView`, so they may not have been built yet — and `ensureVisible`
      // on a finder that matches nothing throws, which is the honest failure and
      // the reason this is not a silent no-op.
      await tester.ensureVisible(find.byKey(const ValueKey('item-i0')));
      await tester.pumpAndSettle();

      // The first row has nowhere up and the last nowhere down. Asserted on the
      // button rather than by tapping and finding nothing moved, because a
      // disabled button is the affordance a D-pad user is reading.
      expect(moveIconButton(tester, 'i0', up: true).onPressed, isNull);
      expect(moveIconButton(tester, 'i1', up: false).onPressed, isNull);

      // Move the second row up — the path that needs no drag gesture.
      await scrollAndTap(tester, moveButton('i1', up: true));
      await scrollAndTap(tester, find.text('Save'));

      expect(sequence(), ['shas.moed', 'shas.moed.shabbos']);
    });

    testWidgets('a sefer can be taken back out', (tester) async {
      await put(sequenced(['shas.moed.shabbos', 'shas.moed']));
      await pump(tester);
      await scrollAndTap(tester, removeButton('i0'));
      await scrollAndTap(tester, find.text('Save'));

      expect(sequence(), ['shas.moed']);
    });

    testWidgets('the flow toggle is saved alongside the sequence',
        (tester) async {
      await put(seed());
      await pump(tester);
      expect(find.text('Continue to the next sefer'), findsOneWidget);
      await scrollAndTap(tester, find.text('Continue to the next sefer'));
      await addSefer(tester, 'Shabbos — Shas · Moed');
      await scrollAndTap(tester, find.text('Save'));

      final plan = config().plans.single;
      expect(plan.flowsToNextItem, isTrue);
      expect(plan.items, hasLength(1),
          reason: 'the toggle must not cost the sequence');
    });

    testWidgets('saving the sequence keeps everything not on this screen',
        (tester) async {
      // Every field below is set here and absent from this screen, which is the
      // whole risk: _applyTo() rebuilds the plan from what it can see, and a
      // field it cannot see is a field it drops. The weekday and date overrides
      // have their own group above; this is the one that has no UI here at all.
      final holiday = Day.of(DateTime(2026, 3, 2));
      final movedFrom = Day.of(DateTime(2026, 2, 1));
      final movedTo = Day.of(DateTime(2026, 2, 8));
      await put(LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 25,
        displayCalendar: RuleCalendar.hebrew,
        spillover: SpilloverMode.slide,
        weekdayAmounts: const {DateTime.friday: 3},
        dateAmounts: {holiday: 0},
        assignments: const [
          PlanAssignment(
            id: 'a',
            rule: WeekdayRule(weekdays: {DateTime.wednesday}),
            targetNodeId: 'shas.moed.shabbos',
            unitsPerFiring: 7,
            label: 'after Shacharis',
          ),
        ],
        overrides: [
          PlanOverride(assignmentId: 'a', from: movedFrom, to: movedTo),
        ],
        items: const [PlanItem(id: 'i0', nodeId: 'shas.moed.shabbos')],
      ));
      await pump(tester);
      await addSefer(tester, 'Moed — Shas');
      await scrollAndTap(tester, find.text('Save'));

      final plan = config().plans.single;
      expect(plan.name, 'Yoma');
      expect(plan.unitsPerDay, 25);
      expect(plan.displayCalendar, RuleCalendar.hebrew);
      expect(plan.spillover, SpilloverMode.slide);
      expect(plan.weekdayAmounts, {DateTime.friday: 3});
      expect(plan.dateAmounts, {holiday: 0});
      final a = plan.assignments.single;
      expect(a.rule, const WeekdayRule(weekdays: {DateTime.wednesday}));
      expect(a.targetNodeId, 'shas.moed.shabbos');
      expect(a.unitsPerFiring, 7);
      expect(a.label, 'after Shacharis');
      expect(plan.overrides, [
        PlanOverride(assignmentId: 'a', from: movedFrom, to: movedTo),
      ]);
    });

    testWidgets('the same sefer twice in a list keeps two distinct items',
        (tester) async {
      // The id used to be minted from the list's *length*: `'item-$length-$node'`.
      // A length is a position, not an identity, so a sefer added again once the
      // list has shrunk back to that length re-mints the id of the copy already
      // there: add Moed twice, take the first out, add Moed again, and both
      // items are `item-1-shas.moed`.
      //
      // Not hypothetical for the sequence, and it costs twice. The rows are keyed
      // by this id, so two items sharing one are two tiles Flutter collapses into
      // one — the list stops being reorderable — and `PlanPosition` reports
      // `itemId`, so the position can no longer say which sefer you are on.
      await put(seed());
      await pump(tester);
      await addSefer(tester, 'Moed — Shas');
      await addSefer(tester, 'Moed — Shas');
      // Found by the name on the row, not by a key: the id is the thing under
      // test, so the test cannot use it to find its way around.
      await scrollAndTap(
        tester,
        find.descendant(
          of: find.ancestor(
            of: find.text('Moed'),
            matching: find.byType(ListTile),
          ).first,
          matching: find.byIcon(Icons.close),
        ),
      );
      await addSefer(tester, 'Moed — Shas');

      // Both rows are on screen and are separately addressable, which is the
      // user-visible half: two tiles sharing a key is a list that cannot be
      // reordered at all.
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .where((t) => t.key.toString().contains('item-')),
        hasLength(2),
      );
      final keys = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => t.key)
          .where((k) => k.toString().contains('item-'))
          .toList();
      expect(keys.toSet(), hasLength(2), reason: 'a key is an identity');

      await scrollAndTap(tester, find.text('Save'));
      final items = config().plans.single.items;
      expect(items.map((i) => i.nodeId), ['shas.moed', 'shas.moed']);
      expect(items.map((i) => i.id).toSet(), hasLength(2));
    });
  });

  group('robustness and the D-pad device', () {
    testWidgets('a plan that no longer exists does not throw', (tester) async {
      await put(seed());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
            progressRepositoryProvider.overrideWithValue(memoryRepository()),
            clockProvider.overrideWithValue(() => DateTime(2026, 1, 10)),
          ],
          child: localizedApp(
              home: const EditPlanAdvancedScreen(planId: 'gone')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole form lays out on a 240dp screen', (tester) async {
      await put(seed());
      await pump(tester, size: sonim);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: 'the reorder row of three icon buttons is the tight spot here');
    });

    testWidgets('the sequence lays out on a 240dp screen', (tester) async {
      // The test above says the reorder row is the tight spot and could not
      // check it, because with an empty sequence there is no reorder row. A
      // sequence is the point of this screen, and 240dp is the device it is
      // built for: three icon buttons plus a drag handle plus a sefer's name is
      // a row that has to fit in a screen narrower than the word.
      await put(const LearningPlan(
        id: 'p',
        name: 'Yoma',
        unitsPerDay: 10,
        assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
        items: [
          PlanItem(id: 'i0', nodeId: 'shas.moed.shabbos'),
          PlanItem(id: 'i1', nodeId: 'shas.moed'),
        ],
      ));
      await pump(tester, size: sonim);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull,
          reason: 'a sequence row at 240dp is the whole screen width');
    });
  });
}
