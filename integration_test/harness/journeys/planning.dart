import 'package:flutter/services.dart';

import '../action.dart';
import '../journey.dart';
import '../navigation.dart';

/// Planning: the calendar, plans, rules, overrides and dates.
///
/// **The newest and the least covered part of the app by its own account**, and
/// the part where the compact device hurts most: a calendar is a grid on a
/// 240dp screen, a segmented control is a row of words, and a date field is
/// something a numeric keypad cannot type into. So these journeys lean on the
/// D-pad and on the size change, and several are tagged `keys` because a pointer
/// journey would prove nothing about the phone.
List<Journey> planningJourneys() => [
  Journey(
    id: 'planner/calendar-three-ranges',
    area: 'planning',
    task: 'switch the calendar between day, week and month',
    steps: [
      ...Nav.calendar,
      const SomethingIsShown(note: 'the calendar opened'),
      // The three ranges are a segmented control, and on the keypad phone the
      // longest of the three words is what decides whether it fits.
      const See('Day'),
      const See('Week'),
      const See('Month'),
      const Tap('Day'),
      const Settle('after switching to the day range'),
      const SeeAnyOf([
        "Today's goals",
        'Nothing is scheduled',
      ], note: 'a day view with something on it or an honest empty state'),
      const Tap('Week'),
      const Settle('after switching to the week range'),
      const Tap('Month'),
      const Settle('after switching to the month range'),
      const Shot('planner-calendar-month'),
    ],
  ),
  Journey(
    id: 'planner/calendar-arrows-step',
    area: 'planning',
    task: 'move between months with the arrows, and back again',
    steps: [
      ...Nav.calendar,
      const SeeAnyOf(['2026-', '2025-', '2027-'], note: 'a month heading'),
      const TapTooltip('Next month'),
      const Settle('after going forward a month'),
      const TapTooltip('Next month'),
      const Settle('after going forward again'),
      const TapTooltip('Previous month'),
      const Settle('after coming back one'),
      // Back where it started is the property that makes the arrows usable
      // rather than a one-way ratchet, and it is a real bug shape: a step
      // that is not an involution loses a day a month at a time.
      const TapTooltip('Previous month'),
      const Settle('after coming back to where it was'),
      const Shot('planner-calendar-stepped'),
    ],
    tags: {'keys'},
  ),
  Journey(
    id: 'planner/calendar-pages-by-key',
    area: 'planning',
    task: 'page the calendar with left and right, on a keypad phone',
    steps: [
      ...Nav.calendar,
      // Focus is walked down into the calendar first, because that is the
      // honest shape of it: a D-pad user has pressed "down" to get off the
      // app bar, and left/right is the paging gesture from there.
      const Press(LogicalKeyboardKey.arrowDown, times: 3),
      const Settle('after moving focus onto the calendar'),
      const SeeAnyOf(['2026-', '2025-', '2027-'], note: 'a month heading'),
      const Press(LogicalKeyboardKey.arrowRight),
      const Settle('after paging right'),
      const Press(LogicalKeyboardKey.arrowRight),
      const Settle('after paging right again'),
      const Press(LogicalKeyboardKey.arrowLeft),
      const Settle('after paging back left'),
      const Shot('planner-calendar-paged-by-key'),
    ],
    tags: {'keys'},
  ),
  Journey(
    id: 'planner/calendar-day-sheet',
    area: 'planning',
    task: 'open a day from the calendar and see what it asks for',
    steps: [
      ...Nav.calendar,
      const TapAny(['Day'], note: 'the day range names a date'),
      const Settle('after switching to days'),
      const TapAny([
        '2026-',
        '2025-',
      ], note: 'the day heading, which is also the day’s row'),
      const Settle('after opening the day'),
      const SeeAnyOf([
        'Nothing is scheduled',
        'units per day',
        'day off',
      ], note: 'the day says what it wants of that day'),
      const Shot('planner-day-sheet'),
    ],
  ),
  Journey(
    id: 'planner/plans-list-and-create',
    area: 'planning',
    task: 'see the plans, and make a new one',
    steps: [
      ...Nav.plans,
      const SomethingIsShown(note: 'the plans list opened'),
      const TapAny(['New plan', 'Add', 'Create'], note: 'start a new plan'),
      const Settle('after asking for a new plan'),
      const SomethingIsShown(note: 'the plan editor opened'),
      const Type('Harness plan', into: 'Name', note: 'name the plan'),
      const TapAny(['Save', 'Create'], note: 'keep it'),
      const Settle('after saving'),
      const See('Harness plan', note: 'the plan is listed by the name given'),
      const Shot('planner-plans-list'),
    ],
  ),
  Journey(
    id: 'planner/plan-rules',
    area: 'planning',
    task: 'change a plan’s rule and see the plan still list it',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const SomethingIsShown(note: 'the editor opened'),
      // The four rule kinds and the three spillover modes are the options
      // the app offers, and a settings screen nobody can change is the
      // failure the repo names first.
      const SeeAnyOf([
        'Daily',
        'Every day',
        'Weekdays',
      ], note: 'the rule control'),
      const Shot('planner-plan-editor'),
    ],
  ),
  Journey(
    id: 'planner/plan-overrides-and-sequence',
    area: 'planning',
    task: 'open a plan’s overrides and its sefer sequence',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const TapAny([
        'Overrides and sequence',
        'Advanced',
        'Overrides',
      ], note: 'the advanced editor'),
      const Settle('after opening the overrides editor'),
      const SomethingIsShown(note: 'the overrides editor opened'),
      // Three sections, and the sequence is the one with no equivalent
      // anywhere else in the app.
      const SeeAnyOf(['Different amounts on certain weekdays']),
      const SeeAnyOf(['Different amounts on certain dates']),
      const SeeAnyOf(['Sefarim, in order', 'No seferim yet']),
      const Shot('planner-plan-overrides'),
    ],
  ),
  Journey(
    id: 'planner/date-typed-in-english',
    area: 'planning',
    task: 'set a date override by typing a date in English',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const TapAny([
        'Overrides and sequence',
        'Advanced',
        'Overrides',
      ], note: 'the advanced editor'),
      const Settle('after opening the overrides editor'),
      const TapAny(['Add a date'], note: 'a date override'),
      const Settle('after asking for a date'),
      // The field, then a date in the reader's own words, then the amount.
      const Type('4 Jan 2026', note: 'a date, in English'),
      const Settle('after typing the date'),
      const See(
        'That is 2026-01-04.',
        note:
            'the field says back what it read — the echo is the '
            'feature, and without it a typo is silent',
      ),
      const TapAny(['Save'], note: 'accept the date'),
      const Settle('after accepting'),
      const TapAny(['Save'], note: 'accept the amount'),
      const Settle('after the amount'),
      const See('2026-01-04', note: 'the override row is named by that date'),
      const Shot('planner-date-english'),
    ],
  ),
  Journey(
    id: 'planner/date-typed-in-hebrew',
    area: 'planning',
    task: 'set a date override by typing a date in Hebrew script',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const TapAny([
        'Overrides and sequence',
        'Advanced',
        'Overrides',
      ], note: 'the advanced editor'),
      const Settle('after opening the overrides editor'),
      const TapAny(['Add a date'], note: 'a date override'),
      const Settle('after asking for a date'),
      // 1 Tishrei 5787 is 12 September 2026, which is pinned in
      // planner_dates_test — so this is a known day, not one the harness and
      // the assertion agree on by accident.
      const Type('א׳ תשרי תשפ״ז', note: 'a date, in Hebrew script'),
      const Settle('after typing the date'),
      const See(
        'That is 2026-09-12.',
        note: 'a Hebrew date read back as the day it is',
      ),
      const Shot('planner-date-hebrew'),
    ],
  ),
  Journey(
    id: 'planner/date-ambiguous-is-reported',
    area: 'planning',
    task: 'type an ambiguous date and be told it is ambiguous',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const TapAny([
        'Overrides and sequence',
        'Advanced',
        'Overrides',
      ], note: 'the advanced editor'),
      const Settle('after opening the overrides editor'),
      const TapAny(['Add a date'], note: 'a date override'),
      const Settle('after asking for a date'),
      // 4/1/2026 is April 1st in one half of the world and January 4th in
      // the other. The app must say so rather than pick, because a date
      // override on the wrong day is a plan quietly asking for nothing.
      const Type('4/1/2026', note: 'a date with two readings'),
      const Settle('after typing the ambiguous date'),
      const TapAny(['Save'], note: 'try to accept it'),
      const Settle('after trying to accept'),
      const SeeAnyOf(['2026-01-04'], note: 'one reading is named'),
      const SeeAnyOf(['2026-04-01'], note: 'and so is the other'),
      const Shot('planner-date-ambiguous'),
    ],
  ),
  Journey(
    id: 'planner/date-refuses-nonsense',
    area: 'planning',
    task: 'type something that is not a date and be refused',
    steps: [
      ...Nav.plans,
      const TapAny(['Harness plan', 'New plan'], note: 'a plan to edit'),
      const Settle('after opening the plan'),
      const TapAny([
        'Overrides and sequence',
        'Advanced',
        'Overrides',
      ], note: 'the advanced editor'),
      const Settle('after opening the overrides editor'),
      const TapAny(['Add a date'], note: 'a date override'),
      const Settle('after asking for a date'),
      const Type('the day after tomorrow', note: 'not a date'),
      const Settle('after typing nonsense'),
      const TapAny(['Save'], note: 'try to accept it'),
      const Settle('after trying to accept'),
      const See('That is not a date this can read.'),
      // And the field is still open, holding what was typed: a dialog that
      // closes before it complains has thrown away a dozen key presses on a
      // keypad phone.
      const See('the day after tomorrow'),
      const Shot('planner-date-refused'),
    ],
  ),
  Journey(
    id: 'planner/cycles-round-trip',
    area: 'planning',
    task: 'make a learning cycle and see it listed',
    steps: [
      ...Nav.cycles,
      const SomethingIsShown(note: 'the cycles screen opened'),
      const TapAny(['New cycle', 'Add', 'Create'], note: 'start a cycle'),
      const Settle('after asking for a new cycle'),
      const SomethingIsShown(note: 'the cycle editor opened'),
      const Type('Harness cycle', into: 'Name', note: 'name the cycle'),
      const TapAny(['Add a sefer'], note: 'a sefer to it'),
      const Settle('after asking for a sefer'),
      const TapAny(['Shabbos', 'Shas'], note: 'pick one'),
      const Settle('after picking a sefer'),
      const SeeAnyOf(['Shabbos'], note: 'the chosen sefer is named on the row'),
      const TapAny(['Create cycle', 'Save'], note: 'keep the cycle'),
      const Settle('after saving'),
      const See('Harness cycle', note: 'the cycle is listed by name'),
      const Shot('planner-cycles'),
    ],
  ),
];
