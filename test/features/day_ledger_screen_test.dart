import 'dart:convert';

import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/repositories/progress_repository.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #42's ledger, at the level a user meets it: the day sheet, and the log.
///
/// **The two directions are deliberately not symmetric, and both halves are
/// tested here.** Ticking in the *calendar* writes the log, so every other view
/// updates at once. Ticking in the *unit grid* writes a tick with **no plan**,
/// so the plan still asks for the unit and it still appears in this day's ledger
/// — and a grid un-tick cannot remove anything the plan wanted.
void main() {
  const shabbos = 'shas.moed.shabbos';
  final theDay = DateTime(2026, 1, 5);
  final dayKey = ValueKey('day-${Day.of(theDay).ordinal}');

  /// A daily plan over Shabbos, asking for [unitsPerDay] a day.
  ///
  /// Not `const`, so the amount can be varied — a `const` here would have looked
  /// tidier and quietly ignored the parameter, which is the sort of thing that
  /// makes a test pass for the wrong reason.
  String planJson({int unitsPerDay = 3, bool oneWrappingUnit = false}) =>
      jsonEncode(
        PlansConfig(
          plans: [
            LearningPlan(
              id: 'daf-yomi',
              name: 'Daf Yomi',
              unitsPerDay: unitsPerDay,
              assignments: const [PlanAssignment(id: 'a', rule: DailyRule())],
              // A one-unit *wrapping* range is "do this N times a day" (#50);
              // the plain one is Daf Yomi's 156 dapim.
              items: oneWrappingUnit
                  ? const [
                      PlanItem(
                        id: 'i1',
                        nodeId: 'shas.moed.shabbos',
                        startUnit: 2,
                        endUnit: 2,
                        wrapsRange: true,
                      ),
                    ]
                  : const [PlanItem(id: 'i1', nodeId: 'shas.moed.shabbos')],
            ),
          ],
        ).toJson(),
      );

  /// The day sheet, open on [theDay], over [repo].
  /// Two plans, the second on a weekday rule so it is **not** firing on the 5th
  /// and has no business being touched by a reflow aimed at the other.
  String plansWithSecond() => jsonEncode(
    const PlansConfig(
      plans: [
        LearningPlan(
          id: 'daf-yomi',
          name: 'Daf Yomi',
          unitsPerDay: 3,
          assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
          items: [PlanItem(id: 'i1', nodeId: shabbos)],
        ),
        LearningPlan(
          id: 'other',
          name: 'Other',
          unitsPerDay: 2,
          assignments: [
            PlanAssignment(
              id: 'a',
              rule: WeekdayRule(weekdays: {DateTime.monday}),
            ),
          ],
          items: [PlanItem(id: 'i1', nodeId: shabbos)],
        ),
      ],
    ).toJson(),
  );

  Future<InMemoryPreferences> openSheet(
    WidgetTester tester, {
    String? plans,
    ProgressRepository? repo,
    bool secondPlan = false,
  }) async {
    final prefs = InMemoryPreferences({
      PrefKeys.scoped('default', PrefKeys.plans):
          plans ?? (secondPlan ? plansWithSecond() : planJson()),
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(
            repo ?? memoryRepository(),
          ),
          clockProvider.overrideWithValue(() => theDay),
        ],
        child: localizedApp(home: const PlannerCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(dayKey));
    await tester.pumpAndSettle();
    return prefs;
  }

  /// The ledger's checkbox for one unit's [pass]-th occurrence today.
  ///
  /// **The pass is part of the key** (#50), because a plan that asks for the same
  /// unit three times has three rows for it, and a finder that could not say
  /// which pass it meant would be pointing at whichever the tree held first.
  Finder box(int unit, [int pass = 0]) =>
      find.byKey(ValueKey('ledger-daf-yomi-$shabbos-$unit-$pass'));

  group('the ledger appears', () {
    testWidgets('a day asks for its units, with the count', (tester) async {
      await openSheet(tester);
      expect(find.text('Daf Yomi'), findsWidgets);
      expect(box(2), findsOneWidget);
      expect(box(3), findsOneWidget);
      expect(box(4), findsOneWidget);
      expect(find.textContaining('0 of 3'), findsOneWidget);
    });

    testWidgets('and a plan asking for more than the sefer holds is short', (
      tester,
    ) async {
      // Shabbos in the fake catalog holds 156, so this asks for a lot; the point
      // is the count matches what the ledger actually shows rather than the plan
      // asking for a number the sefer cannot supply.
      await openSheet(tester, plans: planJson(unitsPerDay: 4));
      expect(find.textContaining('0 of 4'), findsOneWidget);
      expect(box(5), findsOneWidget);
    });
  });

  group('ticking in the calendar writes the log', () {
    testWidgets('and names the plan and the day it was made for', (
      tester,
    ) async {
      final repo = memoryRepository();
      await openSheet(tester, repo: repo);

      await tester.tap(box(2));
      await tester.pumpAndSettle();

      final events = await repo.getEvents('default');
      final tick = events.firstWhere((e) => e.unitIndex == 2);
      expect(tick.action.name, 'done');
      expect(
        tick.planId,
        'daf-yomi',
        reason: 'so the app can tell a plan tick from a grid tick afterwards',
      );
      expect(
        Day.of(tick.occurredAt),
        Day.of(theDay),
        reason:
            'and the day it belongs to is the plan\'s day, not the wall '
            'clock — a tick made on Friday for Thursday lands on Thursday',
      );
    });

    testWidgets('and the tick shows in the sheet', (tester) async {
      final repo = memoryRepository();
      await openSheet(tester, repo: repo);
      expect(find.text('Owed'), findsNWidgets(3));

      await tester.tap(box(2));
      await tester.pumpAndSettle();

      expect(find.text('Done this day'), findsOneWidget);
      expect(find.text('Owed'), findsNWidgets(2));
      expect(find.textContaining('1 of 3'), findsOneWidget);
    });

    testWidgets('a unit done on another day is shown as such, not as done here', (
      tester,
    ) async {
      // Ticking it on the 5th when you did it on the 2nd does not make the 5th
      // look done — and it is not work still owed either. It gets its own state
      // and its own line, because a backlog is the reader's business.
      final repo = memoryRepository();
      await repo.addEvent(
        LearningEvent(
          id: 'e1',
          profileId: 'default',
          nodeId: shabbos,
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 2),
          loggedAt: DateTime(2026, 1, 2),
        ),
      );
      await openSheet(tester, repo: repo);

      expect(box(2), findsOneWidget);
      expect(find.text('Owed'), findsNWidgets(2));
      expect(find.textContaining('Done on'), findsOneWidget);
    });

    testWidgets('an empty ledger is a rest day, not a day of zero', (
      tester,
    ) async {
      // 0 means "nothing on this day" and must never read as an absence.
      final prefs = jsonEncode(
        const PlansConfig(
          plans: [
            LearningPlan(
              id: 'off',
              name: 'Rest',
              unitsPerDay: 0,
              assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
              items: [PlanItem(id: 'i1', nodeId: 'shas.moed.shabbos')],
            ),
          ],
        ).toJson(),
      );
      await openSheet(tester, plans: prefs);
      expect(
        find.byKey(const ValueKey('ledger-off-$shabbos-2-0')),
        findsNothing,
      );
    });
  });

  group('the reverse does not happen', () {
    testWidgets('a unit ticked in the grid is still in the plan\'s list', (
      tester,
    ) async {
      // **The claim that matters most.** This tick carries no plan — it was made
      // in the unit grid and is a fact about the learner — and the plan still
      // asks for the unit, so it must still be offered here, ticked.
      final repo = memoryRepository();
      await repo.addEvent(
        LearningEvent(
          id: 'e1',
          profileId: 'default',
          nodeId: shabbos,
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 5),
          loggedAt: DateTime(2026, 1, 5),
        ),
      );
      await openSheet(tester, repo: repo);

      expect(
        box(2),
        findsOneWidget,
        reason: 'the plan asks for three units, so three rows are shown',
      );
      expect(find.text('Done this day'), findsOneWidget);
      expect(find.textContaining('1 of 3'), findsOneWidget);
    });

    testWidgets('and the plan is not edited by any of it', (tester) async {
      // Neither ticking nor learning removes anything from the plan. The only
      // way a day asks for less is a deliberate planning act.
      final prefs = await openSheet(tester, repo: memoryRepository());
      await tester.tap(box(2));
      await tester.pumpAndSettle();

      final stored = PlansConfig.fromJson(
        (jsonDecode(
                  prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ??
                      '{}',
                )
                as Map)
            .cast<String, dynamic>(),
      );
      expect(stored.plans.single.dateAmounts, isEmpty);
      expect(stored.plans.single.unitsPerDay, 3);
      expect(
        stored.plans.single.items,
        hasLength(1),
        reason: 'the sefer chain is untouched by a tick',
      );
    });
  });

  group('un-ticking from the ledger', () {
    testWidgets('takes back this day\'s tick and offers the unit again', (
      tester,
    ) async {
      final repo = memoryRepository();
      await openSheet(tester, repo: repo);
      await tester.tap(box(2));
      await tester.pumpAndSettle();
      expect(find.text('Done this day'), findsOneWidget);

      await tester.tap(box(2));
      await tester.pumpAndSettle();

      expect(find.text('Owed'), findsNWidgets(3));
      expect(find.textContaining('0 of 3'), findsOneWidget);
      final undone = (await repo.getEvents(
        'default',
      )).where((e) => e.unitIndex == 2);
      expect(
        undone.any((e) => e.action.name == 'undone'),
        isTrue,
        reason: 'and the log records it, rather than the sheet forgetting',
      );
    });

    testWidgets('it names the day it is undoing, not the latest one', (
      tester,
    ) async {
      // You can tick things in the past, so an un-tick names the day it takes
      // back rather than reaching for the most recent.
      final repo = memoryRepository();
      await openSheet(tester, repo: repo);
      await tester.tap(box(2));
      await tester.pumpAndSettle();
      await tester.tap(box(2));
      await tester.pumpAndSettle();

      final undone = (await repo.getEvents(
        'default',
      )).firstWhere((e) => e.action.name == 'undone');
      expect(Day.of(undone.occurredAt), Day.of(theDay));
      expect(undone.planId, 'daf-yomi');
    });
  });

  group('a day where everything is done', () {
    testWidgets('says so', (tester) async {
      final repo = memoryRepository();
      for (final u in [2, 3, 4]) {
        await repo.addEvent(
          LearningEvent(
            id: 'e$u',
            profileId: 'default',
            nodeId: shabbos,
            unitIndex: u,
            action: EventAction.done,
            occurredAt: theDay,
            loggedAt: theDay,
          ),
        );
      }
      await openSheet(tester, repo: repo);
      expect(find.text('Everything for this day is done.'), findsOneWidget);
    });
  });

  group('recompute', () {
    testWidgets('spreading writes a date override and no event', (
      tester,
    ) async {
      // **The promise that matters.** A reflow is a claim about the schedule,
      // never about what was learned, so the log must be exactly as it was.
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('recompute-open-daf-yomi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recompute-apply')));
      await tester.pumpAndSettle();

      final plan = PlansConfig.fromJson(
        (jsonDecode(
                  prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ??
                      '{}',
                )
                as Map)
            .cast<String, dynamic>(),
      ).plans.firstWhere((p) => p.id == 'daf-yomi');
      expect(
        plan.dateAmounts,
        isNotEmpty,
        reason: 'the spread wrote the days it needed to',
      );
      expect(
        await repo.getEvents('default'),
        isEmpty,
        reason: 'and wrote nothing that says anything was learned',
      );
    });

    testWidgets('keeping the same amounts changes nothing', (tester) async {
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo);

      await tester.tap(find.byKey(const ValueKey('recompute-open-daf-yomi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recompute-keep')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recompute-apply')));
      await tester.pumpAndSettle();

      final plan = PlansConfig.fromJson(
        (jsonDecode(
                  prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ??
                      '{}',
                )
                as Map)
            .cast<String, dynamic>(),
      ).plans.firstWhere((p) => p.id == 'daf-yomi');
      expect(
        plan.dateAmounts,
        isEmpty,
        reason:
            'mode 1 is a no-op, and must not put overrides on days that '
            'never had any',
      );
    });

    testWidgets('a plan with no end is not offered "up to its end"', (
      tester,
    ) async {
      final repo = memoryRepository();
      await openSheet(tester, repo: repo);
      await tester.tap(find.byKey(const ValueKey('recompute-open-daf-yomi')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('recompute-until-end')),
        findsNothing,
        reason:
            'an endless plan has no end to spread into, and the option '
            'would do nothing',
      );
      expect(
        find.byKey(const ValueKey('recompute-all')),
        findsOneWidget,
        reason: '"all" is the answer that does apply',
      );
    });

    testWidgets('and it leaves other plans alone', (tester) async {
      final repo = memoryRepository();
      final prefs = await openSheet(tester, repo: repo, secondPlan: true);

      await tester.tap(find.byKey(const ValueKey('recompute-open-daf-yomi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recompute-apply')));
      await tester.pumpAndSettle();

      final plans = PlansConfig.fromJson(
        (jsonDecode(
                  prefs.getString(PrefKeys.scoped('default', PrefKeys.plans)) ??
                      '{}',
                )
                as Map)
            .cast<String, dynamic>(),
      ).plans;
      expect(
        plans.firstWhere((p) => p.id == 'other').dateAmounts,
        isEmpty,
        reason: 'recomputing one plan must not disturb another',
      );
    });
  });

  group('a plan that asks for the same unit more than once a day (#50)', () {
    testWidgets('offers a row per pass, and one is not three', (tester) async {
      // The wrap setting is the user saying "go round again", so a one-unit
      // wrapping range asked for three times is three passes of that unit. Before
      // #50 this offered **one** row and read "0 of 1 done" for a plan asking
      // three.
      final repo = memoryRepository();
      await openSheet(
        tester,
        plans: planJson(unitsPerDay: 3, oneWrappingUnit: true),
        repo: repo,
      );

      expect(box(2, 0), findsOneWidget);
      expect(box(2, 1), findsOneWidget);
      expect(box(2, 2), findsOneWidget);
      expect(find.textContaining('0 of 3'), findsOneWidget);
    });

    testWidgets('ticking a pass writes one event, and shows as one done', (
      tester,
    ) async {
      final repo = memoryRepository();
      await openSheet(
        tester,
        plans: planJson(unitsPerDay: 3, oneWrappingUnit: true),
        repo: repo,
      );

      await tester.tap(box(2, 1));
      await tester.pumpAndSettle();

      final events = await repo.getEvents('default');
      final ticks = events.where((e) => e.unitIndex == 2).toList();
      expect(
        ticks,
        hasLength(1),
        reason:
            'a tap on one row is one pass; three rows sharing a key is how a '
            'single tap becomes three ticks nobody asked for',
      );
      // **The boxes fill as a count.** Three taps of one unit are three events
      // and nothing in the log says which was first, so the ledger cannot say
      // *which* box is ticked — only how many. Inventing an identity for them
      // would be inventing a fact.
      expect(
        tester.widget<CheckboxListTile>(box(2, 0)).value,
        isTrue,
        reason: 'one pass done, so the first box',
      );
      expect(
        tester.widget<CheckboxListTile>(box(2, 1)).value,
        isFalse,
        reason: 'and the second is still owed',
      );
    });
  });
}
