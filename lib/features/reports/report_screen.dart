import 'package:flutter/material.dart';

import '../../core/keypad.dart';
import '../../l10n/generated/app_localizations.dart';
import 'calculator_section.dart';
import 'goals_section.dart';
import 'mefarshim_section.dart';
import 'overview_section.dart';
import 'siyumim_section.dart';

/// The five things this app can tell you about your own learning, on one screen.
///
/// These used to be four separate routes plus Statistics — `/stats`,
/// `/calculator`, `/goals`, `/siyumim`, `/mefarshim` — each with its own
/// `Scaffold`, its own `AppBar`, its own title in the string table and its own
/// row in the drawer. Nothing about them was independent except the routing:
/// they read the same providers, they answer the same question at different
/// zooms, and none of them is a place you *work* — the daily surfaces are the
/// tree, the unit grid, Chazara, Cycles and the Journal, and those are
/// deliberately left alone.
///
/// What the split actually cost was paid on the keypad phone. The drawer was
/// twelve rows on a 324dp screen — long enough that it had to grow a "way back"
/// row because a list of destinations that omits the one you came from is a dead
/// end with a scroll bar — and five of those twelve were these. It also meant
/// the Goals screen and the Calculator, which compute the *same number* from the
/// same evaluator, could not see each other: the Calculator's "By date" mode
/// works out the daily rate needed to finish by a date, which is precisely what
/// a goal is, and there was no way to keep the answer. You had to leave, find
/// the sefer, open its grid and tap a flag.
///
/// So they are tabs. One route each still resolves — a link, a shortcut or a
/// restored route naming `/siyumim` opens the report on Siyumim — because the
/// route names were never the problem and breaking them would be a regression
/// for nothing.
enum ReportSection {
  overview,
  calculator,
  goals,
  siyumim,
  mefarshim;

  String label(AppLocalizations l10n) => switch (this) {
        ReportSection.overview => l10n.reportTabOverview,
        ReportSection.calculator => l10n.reportTabCalculator,
        ReportSection.goals => l10n.reportTabGoals,
        ReportSection.siyumim => l10n.reportTabSiyumim,
        ReportSection.mefarshim => l10n.reportTabMefarshim,
      };
}

/// A report section whose content is figures rather than controls.
///
/// Three of the five sections are made entirely of text, bars and tiles: not one
/// widget in Overview, Siyumim or Mefarshim can hold focus. Directional focus
/// moves *between focusable widgets* and scrolls only as a side effect of
/// bringing one into view, so on a keypad phone those three lists were frozen at
/// whatever the first screenful happened to be — measured on the Sonim, where
/// the Overview chart and heatmap could not be reached by any sequence of keys.
///
/// [DpadScroll] is the fix and it was pasted three times, with the same
/// `skipTraversal: false` and the same paragraph explaining it above each copy.
/// That flag is not a fact about any one section: it is a fact about the **tab
/// bar above all of them**, which holds focus after a tab switch, so a wrapper
/// that traversal steps past is a wrapper that pressing *down* from a tab can
/// never reach. Deciding it once, here, is what makes a sixth section arrive
/// scrollable instead of arriving frozen and waiting for somebody to notice on
/// a device they do not have.
///
/// The two sections that do **not** use this are not oversights. Goals is rows
/// of remove buttons and the Calculator is a form; both are full of focusable
/// widgets, so ordinary traversal reaches them and scrolls as it goes, and
/// claiming the arrow keys ahead of it would make the D-pad scroll *past* the
/// controls instead of onto them.
class ReportBody extends StatelessWidget {
  const ReportBody({super.key, required this.builder});

  /// Builds the scroll view, which must take the controller passed in — that is
  /// what the arrow keys move. See [DpadScroll.builder].
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  @override
  Widget build(BuildContext context) =>
      DpadScroll(skipTraversal: false, builder: builder);
}

/// What a report section shows before there is anything to report.
///
/// Three of the five are empty for months, so this is the state a new user
/// actually sees, and it was three hand-rolled `Center` → `Padding(32)` →
/// `Text` towers that could not scroll. On a 240dp screen the Goals one
/// overflowed its own tab by 88 pixels the moment it grew a button, with the
/// message and the way out of it both below the fold and both unreachable —
/// caught by `keypad_test`, on the first run of the check that walks every tab
/// at the Sonim's size.
///
/// Centred while it fits and scrollable when it does not, which is the same
/// shape the summary grid was rebuilt into for the same reason: a layout that
/// fixes a height it does not control is a layout that is wrong on some screen.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty({super.key, required this.message, this.action});

  final String message;

  /// An affordance under the message — the thing to do about being empty.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ReportBody(
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(isCompact(context) ? 16 : 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, this.section = ReportSection.overview});

  /// Which tab this route opens on. Every old route name maps to one of these,
  /// so nothing that used to link to a report screen has to know it moved.
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = isCompact(context);
    return DefaultTabController(
      initialIndex: section.index,
      length: ReportSection.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reportsTitle),
          bottom: TabBar(
            // Five labels do not fit across 240dp, and squeezing them makes
            // every tab a column of letters. Scrolling the bar instead keeps
            // each label readable and costs nothing: directional focus scrolls
            // a tab into view as it reaches it, which is the only way to move
            // between them on a device with no touchscreen anyway.
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            tabs: [
              for (final s in ReportSection.values) Tab(text: s.label(l10n)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OverviewSection(),
            CalculatorSection(),
            GoalsSection(),
            SiyumimSection(),
            MefarshimSection(),
          ],
        ),
      ),
    );
  }
}
