/// App bar actions that fold into a menu when the bar has no room for them.
///
/// Unconditional rather than device-specific: an overflow menu is what every app
/// bar does when it runs out of room, and this one differs only in *when* it
/// decides that. See `breakpoints.dart` for the screen it was measured on, and
/// for why these three files are three files.
library;

import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// One app bar action, described rather than built, so the same list can be
/// rendered either as icons or as rows in a menu.
class BarAction {
  const BarAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.tint,
  });

  final IconData icon;

  /// Its tooltip on a wide screen and its visible name in the overflow menu.
  final String label;

  /// Null disables it, in the bar and in the menu alike.
  final VoidCallback? onPressed;

  /// A colour the icon carries state in — the sort button's "a sort is active".
  /// Whatever tint the actions carry is also given to the overflow icon, so
  /// folding them away does not hide the fact that one of them is switched on.
  final Color? tint;
}

/// Lays out app bar [actions]: separate buttons where there is room, one
/// overflow menu where there is not.
///
/// A 240dp bar has room for a drawer button and about one action. With three it
/// left the title roughly ten pixels, and since both bars in this app scale
/// their title to fit rather than truncate it, what you got was the app's name
/// shrunk to an illegible dash — on every screen, including the unit grid, which
/// therefore never said which sefer you were looking at.
///
/// Folding costs nothing: a menu row carries a label as well as an icon, so on
/// the phone these become *more* discoverable than unlabelled icons were.
List<Widget> barActions(
  BuildContext context,
  List<BarAction> actions, {
  required String moreTooltip,
}) {
  // A single action is left alone even on the phone: a back button, a title and
  // one icon fit in 240dp, and burying one item under a menu costs a key press
  // to reveal what the icon already said.
  if (!isCompact(context) || actions.length <= 1) {
    return [
      for (final a in actions)
        IconButton(
          icon: Icon(a.icon),
          color: a.tint,
          tooltip: a.label,
          onPressed: a.onPressed,
        ),
    ];
  }
  final tint = actions.map((a) => a.tint).firstWhere((c) => c != null,
      orElse: () => null);
  return [
    PopupMenuButton<int>(
      icon: Icon(Icons.more_vert, color: tint),
      tooltip: moreTooltip,
      onSelected: (i) => actions[i].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(actions[i].icon, color: actions[i].tint),
              title: Text(actions[i].label),
            ),
          ),
      ],
    ),
  ];
}
