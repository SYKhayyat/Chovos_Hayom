import 'dart:convert';

import 'package:chovos_hayom/app/routes.dart';
import 'package:chovos_hayom/application/plans.dart';
import 'package:chovos_hayom/application/providers.dart';
import 'package:chovos_hayom/application/stats.dart';
import 'package:chovos_hayom/core/day.dart';
import 'package:chovos_hayom/core/preferences.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/learning_plan.dart';
import 'package:chovos_hayom/domain/usecases/plan_review.dart';
import 'package:chovos_hayom/domain/usecases/recurrence.dart';
import 'package:chovos_hayom/features/planner/plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_catalog.dart';
import '../support/localized_app.dart';
import '../support/memory_database.dart';

/// #47 — the plan screen. What a plan has got to, how fast it is actually
/// moving, and the reflow both it and the day's sheet share.
///
/// **The assertions are about numbers the user reads**, because that is what this
/// screen is: a plan that is behind has to say so, an endless one must not
/// invent a percentage, and a plan naming no sefer must not read as an infinite
/// plan with nothing done.
void main() {
  const sonim = Size(240, 324);

  /// The clock every test runs at. A Tuesday, so a Shabbos-only rule has exactly
  /// one firing day in the recent window — which is what makes the "not behind"
  /// test mean something.
  final today = Day.of(DateTime(2026, 3, 10));

  late InMemoryPreferences prefs;

  setUp(() => prefs = InMemoryPreferences());

  /// Seed one plan, as a restart would find it.
  Future<void> seed(LearningPlan plan) => prefs.setString(
    PrefKeys.scoped('default', PrefKeys.plans),
    jsonEncode(PlansConfig(plans: [plan]).toJson()),
  );

  /// A daily plan over part of Shabbos, which is the shape most plans have.
  LearningPlan plan({
    int unitsPerDay = 5,
    int? startUnit = 2,
    int? endUnit = 25,
    bool wraps = false,
    Day? from,
    RecurrenceRule? rule,
    List<PlanItem>? items,
    PlanReview? review,
  }) => LearningPlan(
    id: 'p',
    name: 'Daf Yomi',
    unitsPerDay: unitsPerDay,
    pacing: AmountPerDay(unitsPerDay),
    startDay: from,
    review: review,
    items:
        items ??
        [
          PlanItem(
            id: 'i1',
            nodeId: 'shas.moed.shabbos',
            startUnit: startUnit,
            endUnit: endUnit,
            wrapsRange: wraps,
          ),
        ],
    assignments: [PlanAssignment(id: 'a', rule: rule ?? const DailyRule())],
  );

  /// **One repository, handed to both the screen and the log writer.** The
  /// first version of this file built its own inside the helper, so the work it
  /// "logged" went into a different database than the one under test and the
  /// screen correctly reported none of it -- which is a way of writing a test
  /// that passes for the wrong reason, or fails confusingly.
  late DriftProgressRepository repository;

  setUp(() => repository = memoryRepository());

  Future<void> pump(WidgetTester tester, {Size? size}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size ?? const Size(800, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWithValue(prefs),
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          progressRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => DateTime(2026, 3, 10, 9)),
        ],
        child: localizedApp(
          home: const PlanScreen(planId: 'p'),
          // The real router, because this screen navigates by name — which is
          // the whole point of the route table and the reason a deep link can
          // reach this screen at all.
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Marks the units of Shabbos done, on [day], in the log the screen reads.
  Future<void> log(Iterable<int> units, Day day) async {
    for (final unit in units) {
      await repository.addEvent(
        LearningEvent(
          id: 'e$unit-${day.toString()}',
          profileId: 'default',
          nodeId: 'shas.moed.shabbos',
          unitIndex: unit,
          action: EventAction.done,
          occurredAt: day.midnight,
          loggedAt: day.midnight,
        ),
      );
    }
  }

  group('where it stands', () {
    testWidgets('a finite plan reports a fraction and a bar', (tester) async {
      await seed(plan(from: today - 3));
      await pump(tester);

      // 24 units in the range, none done.
      expect(find.text('0 of 24 units done'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.textContaining('On Shabbos · daf'),
        findsOneWidget,
        reason: 'the position names the unit the plan is on',
      );
    });

    testWidgets('an endless plan reports a count and no bar', (tester) async {
      await seed(plan(startUnit: 2, endUnit: 25, wraps: true, from: today - 3));
      await pump(tester);

      // **A bare count, never a percentage.** The bar needs a denominator and
      // this plan has no end to be a fraction of; drawing one anyway would be a
      // bar quietly under-reporting its own plan.
      expect(find.text('0 units done'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('a plan naming no sefer says so, rather than showing zero', (
      tester,
    ) async {
      // The plan the editor creates: a name, a rule and an amount, no sefer.
      // Reporting this as an endless plan with nothing done is a lie about a
      // real plan, and this is the screen that would have printed it.
      await seed(
        const LearningPlan(
          id: 'p',
          name: 'Morning',
          unitsPerDay: 5,
          pacing: AmountPerDay(5),
          assignments: [PlanAssignment(id: 'a', rule: DailyRule())],
        ),
      );
      await pump(tester);

      expect(find.textContaining('does not name a sefer'), findsOneWidget);
      expect(find.text('0 units done'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('How it is going'), findsNothing);
      // The reflow is about what a day *asks for*, which a plan with no sefer
      // still asks for -- so it must stay reachable rather than being hidden
      // behind the empty state.
      expect(find.byKey(const ValueKey('plan-recompute')), findsOneWidget);
    });
  });

  group('how fast you are moving', () {
    testWidgets('reports the average and the recent window, each named', (
      tester,
    ) async {
      await seed(plan(from: today - 6));
      await pump(tester);

      // Both windows, because the issue leaves it open and each hides what the
      // other shows. `since` names the whole-plan figure's window, since an
      // average over an unnamed window has no scale.
      expect(find.textContaining('since 2026-03-04'), findsOneWidget);
      expect(
        find.textContaining('over the last 6 days'),
        findsOneWidget,
        reason: 'fewer than seven on a young plan, and it says how many',
      );
      expect(find.text('This plan asks for 5 a day.'), findsOneWidget);
    });

    testWidgets('says plainly that a slow plan is behind', (tester) async {
      await seed(plan(unitsPerDay: 7, from: today - 3));
      await pump(tester);
      // Nothing done at all, so the recent rate is 0 against an asked 7.
      expect(find.text('Behind the rate this plan asks for.'), findsOneWidget);
    });

    testWidgets('does not call a Shabbos-only plan behind', (tester) async {
      // The visible mis-report the per-active-day rule exists to stop. Ten units
      // a Shabbos, done perfectly, is exactly on pace: a calendar-day average
      // would report 10/7 against an asked 10 and read as a seventh of speed.
      //
      // 2026-03-07 is the Saturday in the window -- `today` is a Tuesday.
      await log([for (var u = 2; u <= 11; u++) u], today - 3);
      await seed(
        plan(
          unitsPerDay: 10,
          from: today - 3,
          rule: const WeekdayRule(weekdays: {DateTime.saturday}),
        ),
      );
      await pump(tester);

      // Ten units on the one Shabbos it asked on, and the label counts the days
      // it asked on rather than the two the rule did not fire.
      expect(
        find.textContaining('over the last 1 day it asked on'),
        findsOneWidget,
      );
      expect(find.textContaining('Doing 10 a day since'), findsOneWidget);
      expect(find.text('Behind the rate this plan asks for.'), findsNothing);
    });

    testWidgets('but does call a Shabbos-only plan behind when it is short', (
      tester,
    ) async {
      // The same plan doing four of the ten it asked for. Without this the test
      // above would also pass on a screen that never says anything.
      await log([2, 3, 4, 5], today - 3);
      await seed(
        plan(
          unitsPerDay: 10,
          from: today - 3,
          rule: const WeekdayRule(weekdays: {DateTime.saturday}),
        ),
      );
      await pump(tester);
      expect(find.text('Behind the rate this plan asks for.'), findsOneWidget);
    });

    testWidgets('a plan with no work in it yet says there is no rate', (
      tester,
    ) async {
      // No start date and an empty log: there is no window to average over, and
      // a fresh plan is not behind, it has not started.
      await seed(plan());
      await pump(tester);
      expect(
        find.text('Nothing worked yet, so there is no rate to show.'),
        findsOneWidget,
      );
      expect(find.text('Behind the rate this plan asks for.'), findsNothing);
    });
  });

  group('editing', () {
    testWidgets('the plan screen offers the editor, by a name and not an icon', (
      tester,
    ) async {
      await seed(plan(from: today - 3));
      await pump(tester);

      // The Sonim has no touchscreen, so an icon-only control announced only by
      // a tooltip is a control a D-pad user has to hunt for.
      expect(find.byKey(const ValueKey('plan-edit')), findsOneWidget);
      expect(find.text('Edit plan'), findsOneWidget);

      await tester.tap(find.text('Edit plan'));
      await tester.pumpAndSettle();
      // The editor, which is a different screen reached from here rather than
      // being what tapping a plan in the list does.
      expect(find.text('Name'), findsOneWidget);
    });
  });

  group('recompute', () {
    testWidgets('asks which day, then offers the same two modes', (
      tester,
    ) async {
      await seed(plan(from: today - 3));
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('plan-recompute')));
      await tester.pumpAndSettle();
      // The shared date field, not a second Gregorian-only picker.
      expect(find.text('Recompute from which day?'), findsOneWidget);

      // The date screen offers Save twice — app bar and pinned row — so the
      // button is named rather than the word.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // **The same sheet the day sheet opens**, which is the whole reason it was
      // moved out of the calendar: two copies would be two chances for one of
      // them to lose a remainder into a rounding error.
      expect(find.text('Keep the same amounts'), findsOneWidget);
      expect(find.text('Spread the shortfall'), findsOneWidget);
    });

    testWidgets('and writes the reflow onto the plan, not the log', (
      tester,
    ) async {
      await seed(plan(unitsPerDay: 5, from: today - 3));
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('plan-recompute')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Save'),
        warnIfMissed: false,
      ); // apply
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      final raw = prefs.getString(PrefKeys.scoped('default', PrefKeys.plans))!;
      final saved = PlansConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      ).plans.single;
      expect(
        saved.dateAmounts,
        isNotEmpty,
        reason: 'three days short, spread over the days that follow',
      );
    });
  });

  group('what the plan would like reviewed (#50)', () {
    testWidgets('a plan that asks for no review shows no review section', (
      tester,
    ) async {
      // **The absence of a section is the setting.** Every plan nobody has
      // touched does not ask for a review, and a section saying so on each of
      // them would be noise on the common case.
      await seed(plan(from: today - 6));
      await pump(tester);
      expect(find.text('Review'), findsNothing);
      expect(find.text('Not a review day.'), findsNothing);
    });

    testWidgets('and one that has a schedule says when today is not its day', (
      tester,
    ) async {
      // 2026-03-10 is a Tuesday, so a Saturday review is not due today — which
      // is an answer rather than a gap: the fold asks about one day, and a plan
      // with a schedule is not a plan carrying a list of pending reviews.
      await seed(
        plan(
          from: today - 6,
          review: const PlanReview(
            windowDays: 7,
            when: ReviewOnWeekday(DateTime.saturday),
          ),
        ),
      );
      await pump(tester);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Not a review day.'), findsOneWidget);
    });

    testWidgets('lists what is due on a review day, with when it was learned', (
      tester,
    ) async {
      // 2026-03-14 is the Saturday.
      final sabbath = Day.of(DateTime(2026, 3, 14));
      await log([2, 3], sabbath - 2);
      await seed(
        plan(
          from: sabbath - 6,
          review: const PlanReview(
            windowDays: 7,
            when: ReviewOnWeekday(DateTime.saturday),
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWithValue(prefs),
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            progressRepositoryProvider.overrideWithValue(repository),
            clockProvider.overrideWithValue(() => DateTime(2026, 3, 14, 9)),
          ],
          child: localizedApp(
            home: const PlanScreen(planId: 'p'),
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('2 due a review'), findsOneWidget);
      expect(find.textContaining('Shabbos · daf 2'), findsWidgets);
      expect(
        find.text('Learned 2026-03-12'),
        findsNWidgets(2),
        reason:
            'both units were learned that day, and the date is what makes '
            'the window legible rather than an invisible cut-off',
      );
    });
  });

  group('the D-pad device', () {
    testWidgets('the whole screen lays out on a 240dp screen', (tester) async {
      await seed(plan(from: today - 6));
      await pump(tester, size: sonim);

      // Scroll the lot: every section must lay out and nothing may overflow.
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
