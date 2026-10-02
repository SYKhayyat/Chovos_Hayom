import '../action.dart';
import '../journey.dart';
import '../navigation.dart';

/// Learning: marking, unmarking, details, chazara, mefarshim, the journal.
///
/// **The area where the app's central promise lives** — an append-only log that
/// everything else is derived from. So most of these journeys end by looking at
/// a *consequence* rather than a control: a number moved, a row appeared, a
/// percentage changed. A journey that asserted "the button was pressed" would
/// pass on an app that learned nothing.
List<Journey> learningJourneys() => [
  Journey(
    id: 'learning/tree-opens',
    area: 'learning',
    task: 'open the learning tree and see a sefer',
    steps: [
      ...startAtHome(),
      const SomethingIsShown(note: 'the tree is on screen'),
      // A category, because that is what the drawer calls the tree and it
      // is the screen a person actually starts from.
      const TapAny([
        'Shas',
        'Shabbos',
        'Kol HaTorah Kula',
      ], note: 'a node in the tree'),
      const Settle('after opening a node'),
      const SomethingIsShown(note: 'a node opened rather than a blank page'),
      const Shot('learning-tree-node'),
    ],
  ),
  Journey(
    id: 'learning/mark-a-daf',
    area: 'learning',
    task: 'mark one daf learned, and see it held',
    steps: [
      ...startAtHome(),
      const TapAny([
        'Shas',
        'Shabbos',
        'Kol HaTorah Kula',
      ], note: 'a node in the tree'),
      const Settle('after opening a node'),
      // The grid is a grid of units; a cell is the unit. Tapping one is the
      // app's primary action and the one the whole log exists to record.
      const TapAny(['1', '2', '3'], note: 'the first daf in the grid'),
      const Settle('after tapping a daf'),
      // Marking asks, or marks — and either way something must now say so.
      // The app is designed so that the *only* truth is the log, so a mark
      // that shows nowhere is a mark that did not happen.
      const SeeAnyOf(['Marked', 'Learned', 'Undo', 'Mark as learned']),
      const Shot('learning-marked-a-daf'),
    ],
  ),
  Journey(
    id: 'learning/mark-then-unmark',
    area: 'learning',
    task: 'unmark a daf, and see the mark undone',
    steps: [
      ...startAtHome(),
      const TapAny([
        'Shas',
        'Shabbos',
        'Kol HaTorah Kula',
      ], note: 'a node in the tree'),
      const Settle('after opening a node'),
      const TapAny(['1', '2', '3'], note: 'the first daf'),
      const Settle('after tapping a daf'),
      const SeeAnyOf(['Marked', 'Learned', 'Undo', 'Mark as learned']),
      const TapAny(['Undo'], note: 'undo the mark just made'),
      const Settle('after undoing'),
      // Un-marking appends rather than deletes, so the unit must be back to
      // unmarked — and the app must not be left claiming otherwise.
      const SeeAnyOf(['Mark', 'Mark as learned', 'Not learned']),
      const Shot('learning-unmarked'),
    ],
  ),
  Journey(
    id: 'learning/per-unit-details',
    area: 'learning',
    task: 'open one unit and see what it holds',
    steps: [
      ...startAtHome(),
      const TapAny([
        'Shas',
        'Shabbos',
        'Kol HaTorah Kula',
      ], note: 'a node in the tree'),
      const Settle('after opening a node'),
      // Details are a long press or a secondary action on a cell; the point
      // of the journey is that a person can *get* to them, and a journey
      // that cannot find the gesture is telling us something real.
      const LongPress('1', note: 'a grid cell, for its details'),
      const Settle('after long-pressing a daf'),
      const SomethingIsShown(note: 'the details sheet opened'),
      const Shot('learning-unit-details'),
    ],
  ),
  Journey(
    id: 'learning/chazara-report',
    area: 'learning',
    task: 'see the chazara row and what it reports about repeats',
    steps: [
      ...startAtHome(),
      // **The report, not a due list** (#45). There is no schedule, so this
      // row never hides itself: "nothing is due" is not a state any more,
      // and a row that appears and disappears with hidden state is a row
      // nobody learns to find. What it carries is a count of units passed
      // more than once, and it opens the Chazara tab of the report screen
      // where those units are listed (#46).
      const TapTooltip(Nav.openMenu),
      const SeeAnyOf(['Chazara']),
      const TapAny(['Chazara']),
      const Settle('after opening the chazara row'),
      const SomethingIsShown(),
      const Shot('learning-chazara'),
    ],
  ),
  Journey(
    id: 'learning/journal-round-trip',
    area: 'learning',
    task: 'write a note in the journal and see it listed',
    steps: [
      ...Nav.journal,
      const SomethingIsShown(note: 'the journal opened'),
      // A journal that cannot be written to is a journal that is a reader.
      const TapAny(['Add', 'New note', 'Add note'], note: 'add a note'),
      const Settle('after asking for a new note'),
      const Type('harness: a note a person wrote', note: 'the note body'),
      const TapAny(['Save', 'Add'], note: 'keep it'),
      const Settle('after saving the note'),
      const See('harness: a note a person wrote'),
      const Shot('learning-journal-note'),
    ],
  ),
  Journey(
    id: 'learning/custom-sefer-round-trip',
    area: 'learning',
    task: 'add a custom sefer and see it in the tree',
    steps: [
      ...Nav.addSefer,
      const SomethingIsShown(note: 'the add-sefer form opened'),
      const Type('Harness sefer', into: 'Name', note: 'the new sefer’s name'),
      const TapAny(['Save', 'Add', 'Create'], note: 'create it'),
      const Settle('after creating a custom sefer'),
      const See(
        'Harness sefer',
        note: 'the sefer I just made is named back to me',
      ),
      const Shot('learning-custom-sefer'),
    ],
  ),
];
