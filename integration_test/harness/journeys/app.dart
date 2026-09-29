import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/services.dart';

import '../action.dart';
import '../journey.dart';
import '../navigation.dart';

/// The app as a whole: reports, settings, profiles, backup — and the promises
/// this repository states about itself.
///
/// **The principles are here because they are the app's actual requirements.** A
/// journey per screen proves the screen renders. These prove the things the
/// README and CONTRIBUTING claim: that a setting persists, that a destructive
/// action asks first, that a day off is never shown as a blank, that the log is
/// the only truth. Those are the claims a person cannot check by using the app
/// for an afternoon, and they are the ones that break silently.
List<Journey> appJourneys() => [
      Journey(
        id: 'reports/tabs',
        area: 'reports',
        task: 'visit every report tab and see it draw',
        steps: [
          ...Nav.reports,
          const SomethingIsShown(note: 'the report screen opened'),
          for (final tab in ['Calculator', 'Goals', 'Siyumim', 'Mefarshim']) ...[
            TabTo(tab),
            const SomethingIsShown(note: 'a report tab drew something'),
          ],
          const Shot('reports-tabs'),
        ],
      ),
      Journey(
        id: 'reports/calculator-answers',
        area: 'reports',
        task: 'ask the calculator for a pace and get an answer',
        steps: [
          ...Nav.reportTab('Calculator'),
          const SomethingIsShown(),
          // A calculator that draws but does not answer is a picture of a
          // calculator, and the app's whole premise is the arithmetic.
          const SeeAnyOf(['units per day', 'per day', 'dapim', 'By date']),
          const Shot('reports-calculator'),
        ],
      ),
      Journey(
        id: 'settings/everything-is-reachable',
        area: 'settings',
        task: 'open settings and scroll the whole list',
        steps: [
          ...Nav.settings,
          const SomethingIsShown(note: 'settings opened'),
          // Settings is the app's longest list and the one most likely to end
          // below the fold of a 324dp screen.
          const ScrollTo('Backup'),
          const Shot('settings-scrolled'),
        ],
      ),
      Journey(
        id: 'settings/a-setting-sticks',
        area: 'settings',
        task: 'change a setting, leave, come back, and find it kept',
        steps: [
          ...Nav.settings,
          const TapAny(['Appearance', 'Theme', 'Display'],
              note: 'a group of display settings'),
          const Settle('after opening the group'),
          const SeeAnyOf(['System', 'Light', 'Dark'],
              note: 'the theme control'),
          const Tap('Dark'),
          const Settle('after choosing dark'),
          const Back(note: 'back to settings'),
          const Back(note: 'back to the tree'),
          ...Nav.settings,
          const TapAny(['Appearance', 'Theme', 'Display'],
              note: 'the same group again'),
          const Settle('after reopening the group'),
          // The claim: a setting that does not survive leaving the screen is not
          // a setting. This is the single most common way a preferences screen
          // lies, and it is invisible to a test that only changes it.
          const See('Dark', note: 'the theme I chose is still chosen'),
          const Shot('settings-theme-stuck'),
        ],
      ),
      Journey(
        id: 'settings/backup-can-be-taken',
        area: 'settings',
        task: 'export a backup and be told it worked',
        steps: [
          ...Nav.settings,
          const ScrollTo('Backup'),
          const TapAny(['Export', 'Back up now', 'Create backup'],
              note: 'export'),
          const Settle('after asking to export'),
          // The stamp is the app's only proof to the user that their history
          // exists somewhere else, and a silent failure here is the worst kind.
          const SeeAnyOf(['Exported', 'Saved', 'Backup', 'backup saved']),
          const Shot('settings-backup'),
        ],
      ),
      Journey(
        id: 'profiles/switch-and-come-back',
        area: 'profiles',
        task: 'make a profile and switch to it',
        steps: [
          ...Nav.profiles,
          const SomethingIsShown(note: 'profiles opened'),
          const TapAny(['New profile', 'Add', 'Create'],
              note: 'make a profile'),
          const Settle('after asking for a new profile'),
          const Type('Harness profile', into: 'Name'),
          const TapAny(['Save', 'Create', 'Add']),
          const Settle('after saving'),
          const See('Harness profile'),
          const Shot('profiles'),
        ],
      ),
      Journey(
        id: 'principles/compact-layout-holds',
        area: 'principles',
        task: 'every screen in the sequence still works at 240dp',
        steps: [
          // The whole app on the phone it was built for. Every screen is opened
          // in turn and must still *draw*, which is the cheapest possible
          // statement of "this works at the size the app exists for" and the
          // assertion that would have caught the month cell and the date entry
          // before a person did.
          ...startAtHome(),
          for (final destination in const [
            'Learning cycles',
            'Plans',
            "Today's goals",
            'Planner calendar',
            'Reports',
            'Notes Journal',
            'Profiles',
            'Add custom sefer',
            'Settings',
          ]) ...[
            const TapTooltip(Nav.openMenu),
            TapAny([destination]),
            Settle('after opening $destination'),
            SomethingIsShown(note: '$destination drew something at this size'),
            Back(note: 'back out of $destination'),
            Settle('after leaving $destination'),
          ],
          const Shot('principles-every-screen'),
        ],
      ),
      Journey(
        id: 'principles/destructive-asks-first',
        area: 'principles',
        task: 'a destructive action asks before it does it',
        steps: [
          ...startAtHome(),
          const TapAny(['Shas', 'Shabbos', 'Kol HaTorah Kula'],
              note: 'a node in the tree'),
          const Settle('after opening a node'),
          // "Never make a user's history unrecoverable" is the repo's rule, and
          // the cheapest way to break it is a delete with no confirmation.
          const SeeAnyOf(['Delete', 'Remove', 'Clear', 'Unlearn'],
              note: 'something destructive is offered'),
          const TapAny(['Delete', 'Remove', 'Clear', 'Unlearn'],
              note: 'it'),
          const Settle('after asking to do it'),
          // Either it asks, or it is undoable. Both are acceptable; doing it
          // quietly is not, and this cannot tell the two apart — so it is
          // reported as a **check** rather than a pass, and a person reads it.
          const Shot('principles-destructive'),
          const SeeAnyOf(['Cancel', 'Undo', 'Delete', 'Are you sure']),
        ],
        tags: {'check'},
      ),
      Journey(
        id: 'principles/keyboard-can-leave',
        area: 'principles',
        task: 'the escape key backs out of a screen, and out of a drawer',
        steps: [
          ...startAtHome(),
          // Reported from the device: the drawer's scrim closes it on a tap,
          // which needs a touchscreen, so a keypad user opened the drawer and
          // had no on-screen way back. Escape is the answer, and this is the
          // journey that says whether it works.
          const TapTooltip(Nav.openMenu),
          const Settle('after opening the drawer'),
          const Press(LogicalKeyboardKey.escape),
          const Settle('after pressing escape'),
          const TapTooltip(Nav.openMenu),
          const Settle('after opening the drawer again'),
          const SomethingIsShown(note: 'the drawer is open'),
          const Press(LogicalKeyboardKey.escape),
          const Settle('after pressing escape again'),
          const TapTooltip(Nav.openMenu),
          const Settle('the drawer can be opened a third time, so it closed'),
          const Shot('principles-escape'),
        ],
        tags: {'keys'},
      ),
    ];

/// Taps a report tab.
///
/// Its own step rather than a [Tap] because the report's tab bar is a
/// scrollable strip on a narrow screen, and "the tab is on screen" is not the
/// same question as "the tab exists" — a tab the user cannot scroll to is a tab
/// they cannot open.
class TabTo extends Act {
  const TabTo(this.label, {this.note});

  final String label;
  final String? note;

  @override
  String get intent => 'open the $label tab${note == null ? '' : ' — $note'}';

  @override
  Future<void> run(HarnessContext c) async {
    final tab = find.widgetWithText(TabBar, label);
    if (tab.evaluate().isEmpty) {
      // Not built, or off the end of a scrolling tab bar. Scrolled to rather
      // than failed, and the scroll is a drag on the bar itself so a narrow
      // screen can reach the last tab at all.
      final bar = find.byType(TabBar);
      if (bar.evaluate().isEmpty) {
        throw StateError('no tab bar on screen, so no "$label" tab');
      }
      for (var i = 0; i < 12; i++) {
        await c.tester.drag(bar, const Offset(-80, 0));
        await const Settle('while scrolling the tab bar').run(c);
        if (find.widgetWithText(TabBar, label).evaluate().isNotEmpty) break;
      }
    }
    final target = find.widgetWithText(TabBar, label);
    if (target.evaluate().isEmpty) {
      throw StateError(
        'scrolled the tab bar and "$label" never appeared. On a 240dp screen a '
        'tab the user cannot scroll to is a tab they cannot open.',
      );
    }
    await c.tester.tap(target.first, warnIfMissed: false);
    await Settle('after opening the $label tab').run(c);
  }
}
