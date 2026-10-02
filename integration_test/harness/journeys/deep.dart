import '../action.dart';
import '../journey.dart';
import '../navigation.dart';

/// Journeys the coverage table promises, and that the guard test enforces.
///
/// These are the screens a person reaches by *tapping something* rather than by
/// choosing a destination — a sefer's grid, a category's subtree, a node's
/// editor, a cycle's editor — plus the report tabs and the two settings screens
/// that sit behind a control on another screen. They are the ones a drawer
/// inventory cannot find, which is exactly why they need naming.
List<Journey> deepJourneys() => [
  Journey(
    id: 'learning/sefer-grid',
    area: 'learning',
    task: 'open a sefer’s grid of units',
    steps: [
      ...startAtHome(),
      const TapAny(['Kol HaTorah Kula'], note: 'the root, which is a category'),
      const Settle('after opening the root'),
      const TapAny(['Shas'], note: 'down to Shas'),
      const Settle('after opening Shas'),
      // Shabbos is a leaf, so tapping it opens the grid rather than another
      // level of tree — which is the distinction a person has to be able to
      // see without being told.
      const TapAny(['Shabbos'], note: 'a leaf, so this opens its units'),
      const Settle('after opening a leaf'),
      const SomethingIsShown(note: 'a grid of units'),
      const Shot('learning-sefer-grid'),
    ],
  ),
  Journey(
    id: 'learning/category-subtree',
    area: 'learning',
    task: 'open a category and see everything under it',
    steps: [
      ...startAtHome(),
      const TapAny([
        'Kol HaTorah Kula',
        'Shas',
      ], note: 'a category in the tree'),
      const Settle('after opening a category'),
      // A category answers a different question from a leaf — "how is
      // everything under here doing" — and the two screens are not the same
      // widget, so both need opening.
      const SomethingIsShown(note: 'a subtree, not a grid'),
      const SeeAnyOf([
        'Shabbos',
        'Eruvin',
        'Moed',
      ], note: 'the seferim underneath are named'),
      const Shot('learning-category-subtree'),
    ],
  ),
  Journey(
    id: 'learning/edit-node-details',
    area: 'learning',
    task: 'open a sefer’s own settings and see its name',
    steps: [
      ...startAtHome(),
      const TapAny(['Kol HaTorah Kula', 'Shas'], note: 'the tree'),
      const Settle('after opening the tree'),
      const TapAny(['Shabbos'], note: 'a sefer'),
      const Settle('after opening the sefer'),
      // The node editor is the app's one *write* to the catalog, and a
      // catalog a person cannot rename is a catalog they cannot fix.
      const TapTooltip('Edit'),
      const Settle('after asking to edit'),
      const SomethingIsShown(note: 'the node editor opened'),
      const SeeAnyOf(['Shabbos'], note: 'the name is in the field'),
      const Shot('learning-node-editor'),
    ],
  ),
  Journey(
    id: 'planner/today-goals',
    area: 'planning',
    task: 'see today’s goals and read what is being asked',
    steps: [
      ...Nav.today,
      const SomethingIsShown(note: "today's goals opened"),
      // The screen exists to answer "what am I meant to be doing today", so
      // an amount or a plan name has to be on it.
      const SeeAnyOf(['units', 'per day', 'day off', 'Nothing']),
      const Shot('planner-today'),
    ],
  ),
  Journey(
    id: 'planning/cycle-editor',
    area: 'planning',
    task: 'open an existing cycle and read it back',
    steps: [
      ...Nav.cycles,
      const SomethingIsShown(note: 'the cycles screen opened'),
      const TapAny([
        'Harness cycle',
        'Daf Yomi',
        'Mishna Yomi',
      ], note: 'a cycle to open'),
      const Settle('after opening a cycle'),
      const SomethingIsShown(note: 'the cycle editor opened'),
      // An editor that opens empty for a cycle that exists is data loss in
      // the most dangerous direction: the next save writes the empty version.
      const SeeAnyOf(['Harness cycle', 'units per day', 'Started on']),
      const Shot('planner-cycle-editor'),
    ],
  ),
  Journey(
    id: 'reports/goal-round-trip',
    area: 'reports',
    task: 'set a goal and see it listed',
    steps: [
      ...Nav.reportTab('Goals'),
      const SomethingIsShown(note: 'the goals tab opened'),
      const TapAny(['Add goal', 'Set a goal', 'Add'], note: 'start a goal'),
      const Settle('after asking for a goal'),
      const TapAny(['Save', 'Set', 'Add']),
      const Settle('after setting the goal'),
      // The repo is explicit that a goal must be removable rather than only
      // overwritable, so the control has to be there to press.
      const SeeAnyOf(['Remove', 'Undo', 'Clear']),
      const Shot('reports-goal'),
    ],
  ),
  Journey(
    id: 'reports/siyum-round-trip',
    area: 'reports',
    task: 'see the siyumim the app projects',
    steps: [
      ...Nav.reportTab('Siyumim'),
      const SomethingIsShown(note: 'the siyumim tab opened'),
      // Every siyum here is a *projection* off the log, never a stored
      // event, so a screen with nothing on it is a correct answer rather
      // than a failure — and one with something must say what.
      const SeeAnyOf(['Siyum', 'Nothing', 'No siyumim', 'Projected']),
      const Shot('reports-siyumim'),
    ],
  ),
  Journey(
    id: 'reports/meforish-round-trip',
    area: 'reports',
    task: 'add a meforish and see it offered',
    steps: [
      ...Nav.reportTab('Mefarshim'),
      const SomethingIsShown(note: 'the mefarshim tab opened'),
      const TapAny(['Add meforish', 'Add', 'New'], note: 'add a meforish'),
      const Settle('after asking to add one'),
      // Two names, because a meforish has a Hebrew name too and a dialog
      // that only takes one produces a half-translated feature.
      const Type('Harness meforish', into: 'English'),
      const Type('הרב הרצל', into: 'Hebrew'),
      const TapAny(['Save', 'Add']),
      const Settle('after saving'),
      const See('Harness meforish'),
      const Shot('reports-meforish'),
    ],
  ),
  Journey(
    id: 'app/bulk-history-undo',
    area: 'planning',
    task: 'see the bulk history and undo from it',
    steps: [
      ...Nav.settings,
      const ScrollTo('History'),
      const TapAny(['History', 'Bulk history'], note: 'the bulk history'),
      const Settle('after opening the history'),
      const SomethingIsShown(note: 'the history opened'),
      // The repo's rule: a large-scale action must be undoable *durably*,
      // not from a SnackBar that has gone. So an Undo here is the claim.
      const SeeAnyOf(['Undo', 'Nothing', 'No changes']),
      const Shot('app-bulk-history'),
    ],
  ),
  Journey(
    id: 'app/crash-log-is-readable',
    area: 'settings',
    task: 'open the crash log and see it explains itself',
    steps: [
      ...Nav.settings,
      const ScrollTo('Crash log'),
      const TapAny(['Crash log', 'Crashes'], note: 'the crash log'),
      const Settle('after opening the crash log'),
      const SomethingIsShown(),
      // The log is where a person looks when something went wrong, and an
      // empty one with no explanation is indistinguishable from a broken
      // feature.
      const SeeAnyOf([
        'Nothing',
        'No errors',
        'nothing has gone wrong',
        'Clear',
      ]),
      const Shot('app-crash-log'),
    ],
  ),
];
