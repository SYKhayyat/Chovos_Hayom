import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/backup_status.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/sorting.dart';
import '../../application/stats.dart';
import '../../core/day.dart';
import '../../core/keypad.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/progress_node.dart';
import '../../domain/usecases/log_activity.dart';
import '../../domain/usecases/reminders_policy.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/error_view.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import '../search/catalog_search_delegate.dart';
import 'progress_tile.dart';
import 'session_banner.dart';
import 'sort_sheet.dart';

/// The main dashboard: an expandable tree of the whole catalog with per-node
/// progress bars. Tapping a leaf opens its per-unit grid.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

/// One visible row of the flattened tree.
class _TreeRow {
  const _TreeRow(this.node, this.depth, this.hasChildren);
  final ProgressNode node;
  final int depth;
  final bool hasChildren;
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Ids of the category nodes currently expanded. The tree starts collapsed.
  ///
  /// Expansion lives here, not in each tile, so the visible tree can be
  /// flattened to a list and rendered lazily — see [_flatten]. It also means
  /// expansion survives a rebuild, which the old epoch-bump-the-key trick
  /// deliberately destroyed.
  final Set<String> _expanded = <String>{};

  /// Whether [_seed] has run. Once only, so *Collapse all* stays collapsed.
  bool _seeded = false;

  /// Opens the top level the first time the tree arrives.
  ///
  /// The catalog is one root — "Kol HaTorah Kula" — with Tanach, Mishnayos, Shas
  /// and the rest hanging off it, and the tree started fully collapsed. So the
  /// app opened on a **single row** reading "Kol HaTorah Kula, 0 / 12,092" above
  /// an empty screen, with no indication that it was a tree at all or that the
  /// chevron at the end of that one row was the way in. Reported from the phone
  /// as "it does not open onto the main tree and I don't know how to get there",
  /// which is a fair description of one row and a blank page.
  ///
  /// Expanding only the roots costs nothing: the visible tree is flattened and
  /// fed to a `ListView.builder`, so this builds the handful of rows that fit on
  /// screen, not the ~312 tiles underneath them.
  ///
  /// Called from `build` and mutating state without a `setState`, deliberately:
  /// it runs before anything in that build reads the set, so the frame being
  /// built is already the one that shows the result. Once only, so *Collapse
  /// all* means collapsed and stays that way.
  void _seed(List<ProgressNode> roots) {
    if (_seeded || roots.isEmpty) return;
    _seeded = true;
    for (final root in roots) {
      if (root.children.isNotEmpty) _expanded.add(root.id);
    }
  }

  void _toggle(String id) => setState(() {
        if (!_expanded.remove(id)) _expanded.add(id);
      });

  void _setExpanded(bool expand) {
    final forest = ref.read(progressForestProvider).asData?.value ?? const [];
    setState(() {
      _expanded.clear();
      if (!expand) return;
      void walk(ProgressNode n) {
        if (n.children.isEmpty) return;
        _expanded.add(n.id);
        for (final c in n.children) {
          walk(c);
        }
      }

      for (final root in forest) {
        walk(root);
      }
    });
  }

  /// The rows the tree currently shows, in order: a node, then its children only
  /// if it is expanded.
  ///
  /// Flattening is what makes the dashboard lazy. `ListView.builder` mounts only
  /// the rows on screen, so *Expand all* no longer builds every one of the ~312
  /// tiles — each with a progress bar and a per-meforish bar row — in one frame.
  /// The sort is applied here, once per generation, rather than by each tile.
  List<_TreeRow> _flatten(
    List<ProgressNode> roots,
    SortConfig config,
    Map<String, DateTime> lastActivity,
  ) {
    final rows = <_TreeRow>[];
    void walk(List<ProgressNode> nodes, int depth) {
      for (final n in nodes) {
        final hasChildren = n.children.isNotEmpty;
        rows.add(_TreeRow(n, depth, hasChildren));
        if (!hasChildren || !_expanded.contains(n.id)) continue;
        // The sort applies only when its configured level targets this
        // generation (null = every level), matching the previous per-tile rule.
        final childDepth = depth + 1;
        final ordered = !config.active ||
                (config.level != null && config.level != childDepth)
            ? n.children
            : sortChildren(n.children, config, lastActivity);
        walk(ordered, childDepth);
      }
    }

    walk(roots, 0);
    return rows;
  }

  /// The app bar's three actions — expand/collapse, sort, search — as separate
  /// buttons where there is room, and folded into one overflow menu where there
  /// is not.
  ///
  /// Measured on the 240dp Sonim screen: a drawer button and three actions leave
  /// the title about ten pixels, and because the title is a [FittedBox] (chosen
  /// so a long name scales rather than truncates) it obligingly shrank "Chovos
  /// Hayom" down to an illegible dash. Nothing was broken enough to notice — the
  /// bar simply had no name in it, on every screen, and the unit grid likewise
  /// never said which sefer you were in.
  ///
  /// Folding the actions away is the ordinary Material answer and it costs
  /// nothing: a menu entry carries a *label* as well as an icon, so on the phone
  /// these three become more discoverable than they were, not less.
  List<Widget> _barActions(
    BuildContext context,
    AppLocalizations l10n,
    SortConfig sort,
    Catalog? catalog,
  ) {
    final expanding = _expanded.isEmpty;
    return barActions(
      context,
      [
        BarAction(
          icon: expanding ? Icons.unfold_more : Icons.unfold_less,
          label: expanding ? l10n.expandAll : l10n.collapseAll,
          onPressed: () => _setExpanded(expanding),
        ),
        BarAction(
          icon: Icons.sort,
          label: sort.active
              ? l10n.tooltipSortActive(sortMetricLabel(l10n, sort.metric))
              : l10n.tooltipSort,
          tint: sort.active ? Theme.of(context).colorScheme.primary : null,
          onPressed: () => showSortSheet(context, ref),
        ),
        BarAction(
          icon: Icons.search,
          label: l10n.tooltipSearch,
          onPressed: catalog == null
              ? null
              : () => showSearch(
                    context: context,
                    delegate: CatalogSearchDelegate(catalog),
                  ),
        ),
      ],
      moreTooltip: l10n.tooltipMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final forest = ref.watch(progressForestProvider);
    // Before anything reads [_expanded] — the app bar's expand/collapse label
    // does, and seeding further down inside `forest.when` would leave that label
    // a frame behind the tree it describes.
    _seed(forest.asData?.value ?? const []);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final l10n = AppLocalizations.of(context);

    final sort = ref.watch(settingsProvider.select((s) => s.sort));
    // Watched unconditionally, so this widget's set of subscriptions is the same
    // on every build. The roll-up is still only paid for when a sort needs it —
    // that gate moved inside the provider. See nodeLastActivityProvider.
    final lastActivity = ref.watch(nodeLastActivityProvider);

    // The nudge is *not* watched here. It used to be, and answering it meant
    // walking every event ever recorded from this `build` to produce one bool.
    // It now lives in [_NudgeBanner], which gates itself — see the note there
    // for why a self-gating ConsumerWidget is the right shape and not merely a
    // tidier one.
    //
    // Up here with the rest of them, and not inside `forest.when(data:)` where
    // it was — 68 lines below the comment above that forbids exactly this. A
    // watch inside the data branch means the subscription exists on a loaded
    // frame and not on a loading or error one, which is the moving-subscription
    // shape `nodeLastActivityProvider` was rewritten to remove.
    final backupDue = ref.watch(backupStatusProvider.select((s) => s.due));

    return Scaffold(
      drawer: const _AppDrawer(),
      appBar: AppBar(
        // Scaled down rather than cut off. On a 1220px phone in English this bar
        // read "Chovos …", and "Chovo…" at 1.6x font scale — the first thing
        // every English user sees, and the app could not fit its own name in it.
        // (Hebrew fits, so nobody testing in Hebrew would ever meet it.)
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(l10n.appTitle),
        ),
        // Three actions, and the rule they follow: the app bar holds what acts on
        // *this* tree — expand, sort, search — and the drawer holds every route
        // to somewhere else. Statistics and the Siyum calculator were the two
        // exceptions and are now drawer entries with names on them, which is both
        // more discoverable than an unlabelled icon and what left room for the
        // title. Nothing is removed; two things moved to where their nine
        // siblings already live.
        actions: _barActions(context, l10n, sort, catalog),
      ),
      // No floating button on a keypad phone.
      //
      // A FAB assumes a thumb: it floats *over* the content, which on a 324dp
      // screen means permanently covering part of the third row, and it is a
      // detached target that directional focus reaches awkwardly if at all.
      // Nothing is lost by dropping it here — the drawer has carried the same
      // "add custom sefer" entry all along, with a name on it.
      floatingActionButton: isCompact(context)
          ? null
          : FloatingActionButton(
              tooltip: l10n.tooltipAddCustomSefer,
              onPressed: () => Navigator.pushNamed(context, Routes.addItem),
              child: const Icon(Icons.add),
            ),
      body: forest.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // The forest is the catalog folded over the log, so a failure here is
        // one of the two — and both are reads. Retrying re-runs the asset load
        // and the query; nothing is written either way, which is the first thing
        // worth telling someone staring at an empty tree.
        error: (e, stack) => ErrorView(
          title: l10n.errorCatalogTitle,
          body: l10n.errorCatalogBody,
          error: e,
          stackTrace: stack,
          onRetry: () {
            ref.invalidate(catalogProvider);
            ref.invalidate(eventsProvider);
          },
        ),
        data: (nodes) {
          final rows = _flatten(nodes, sort, lastActivity);
          // The banners sit in the leading slots of the same lazy list, so they
          // scroll with the tree instead of pinning a second scroll view.
          final leading = <Widget>[
            const SessionBanner(),
            const _NudgeBanner(),
            if (backupDue) const _BackupBanner(),
          ];
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: leading.length + rows.length,
            itemBuilder: (context, i) {
              if (i < leading.length) return leading[i];
              final row = rows[i - leading.length];
              return ProgressTile(
                key: ValueKey(row.node.id),
                node: row.node,
                depth: row.depth,
                hasChildren: row.hasChildren,
                expanded: _expanded.contains(row.node.id),
                onToggle:
                    row.hasChildren ? () => _toggle(row.node.id) : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// "Your learning is only on this device, and some of it isn't saved anywhere."
///
/// Android's automatic cloud backup is deliberately off, so the app's own export
/// is the only copy that survives a lost phone — and until now nothing ever said
/// so. It leads straight to Settings, where the export is, rather than telling
/// the user to go and find it.
class _BackupBanner extends ConsumerWidget {
  const _BackupBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(backupStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    final compact = isCompact(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _layout(
          context,
          icon: Icon(Icons.shield_outlined, color: scheme.onErrorContainer),
          text: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.neverBackedUp
                    ? l10n.backupBannerNever(status.unsavedUnits)
                    : l10n.backupBannerStale(
                        status.unsavedUnits, status.daysSinceBackup ?? 0),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
              // Why it matters, everywhere there is room to say it. On the
              // keypad phone this card already fills the screen on its own —
              // headline, reasoning and two buttons come to more than the 244dp
              // the dashboard has below its app bar, so the tree the app is
              // *for* starts entirely below the fold. The sentence that goes is
              // the explanatory one, and it is still on the Settings screen this
              // banner's own button leads to, under the switch that controls it.
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(l10n.backupBannerWhy,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onErrorContainer)),
              ],
            ],
          ),
          action: FilledButton(
            onPressed: () => Navigator.pushNamed(context, Routes.settings),
            child: Text(l10n.backupBannerAction),
          ),
          // Dismissable from where the annoyance is.
          //
          // The switch has always existed in Settings, but a warning you can
          // only silence by hunting through a screen you may not read is a
          // warning that just becomes noise. Turning it off here is one press,
          // says where to turn it back on, and offers Undo — so a mis-tap on a
          // safety feature costs nothing.
          onDismiss: () => _dismiss(context, ref, l10n),
          dismissLabel: l10n.backupBannerDismiss,
          tint: scheme.onErrorContainer,
        ),
      ),
    );
  }

  /// The banner's parts on one line, or stacked where one line will not hold
  /// them.
  ///
  /// A shield, two lines of prose, a "Back up" button and a close button want
  /// roughly 202dp of the 184 a 240dp screen leaves inside this card, so the
  /// `Expanded` around the prose was handed what was left — nothing — and wrapped
  /// its text to one character per line. A column of single red letters, on the
  /// banner whose whole job is to be read.
  Widget _layout(
    BuildContext context, {
    required Widget icon,
    required Widget text,
    required Widget action,
    required VoidCallback onDismiss,
    required String dismissLabel,
    required Color tint,
  }) {
    if (!isCompact(context)) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: text),
          const SizedBox(width: 8),
          action,
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: dismissLabel,
            color: tint,
            onPressed: onDismiss,
          ),
        ],
      );
    }
    // Two full-width buttons, one under the other, and the close *icon* only on
    // the screens that can hover a tooltip out of it.
    //
    // Measured on the Sonim: a bare ✕ beside "Back up" is reachable only by
    // pressing *right* from that button — plain down skips it and lands in the
    // tree — and its tooltip, which is the only thing that ever said what it
    // does, needs a pointer the device does not have. So the one control that
    // silences the warning was both unlabelled and off the path anyone would
    // walk. That is why the report was "there is no way to dismiss it": there
    // effectively wasn't. Stacked and named, down reaches it and it says so.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [icon, const SizedBox(width: 12), Expanded(child: text)],
        ),
        const SizedBox(height: 8),
        // Full width rather than laid out end-to-end: "Back up" plus a named
        // dismiss come to more than a 240dp card holds, and a translation can
        // only make them wider. A button that owns the row cannot overflow it,
        // and it is a larger target for a D-pad besides.
        SizedBox(width: double.infinity, child: action),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: tint),
            onPressed: onDismiss,
            child: Text(dismissLabel, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Future<void> _dismiss(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final notifier = ref.read(settingsProvider.notifier);
    final guard = WriteGuard.of(context, ref);
    await guard.run(
      () => notifier.setBackupReminderEnabled(false),
      what: l10n.whatChangingBackupReminder,
      success: l10n.backupBannerDismissed,
      undo: SnackBarAction(
        label: l10n.actionUndo,
        onPressed: () => guard.run(
          () => notifier.setBackupReminderEnabled(true),
          what: l10n.whatChangingBackupReminder,
        ),
      ),
    );
  }
}

/// "You haven't learned today." Decides for itself whether to appear.
///
/// **Self-gating, like [SessionBanner] beside it in the same list.** The
/// dashboard's `build` used to ask this question, which meant a banner
/// appearing or clearing rebuilt the whole tree screen — and, worse, that it
/// answered it by walking the entire event log. Neither is true now: the answer
/// is three map lookups on [LogActivity], and only this widget hears it.
///
/// **And the policy call stays here rather than behind a `shouldRemindProvider`,
/// which is not a style preference.** A `Consumer` that stays mounted under a
/// pushed route or an open sheet has its subscriptions paused by `TickerMode`
/// and resumed when the overlay closes. Resuming one flushes it *and its
/// ancestors*; if a **derived** ancestor went dirty while it slept, that
/// ancestor rebuilds and notifies mid-build, and the descendant provider's
/// re-invalidation is a `setState` inside the build phase, which Flutter
/// asserts on. One provider between this banner and the log was enough to make
/// *drill in, mark a daf, come back* throw every time. Watching an index that
/// sits one hop from the log has no such window, because the stream it depends
/// on is what emitted in the first place and is already clean.
/// `derived_flush_test.dart` pins both routes a mark is made from.
class _NudgeBanner extends ConsumerWidget {
  const _NudgeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = RemindersPolicy.shouldRemind(
      enabled: ref.watch(settingsProvider.select((s) => s.reminderEnabled)),
      activity:
          ref.watch(logActivityProvider).asData?.value ?? LogActivity.empty,
      today: Day.of(ref.watch(clockProvider)()),
    );
    if (!show) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(AppLocalizations.of(context).nudgeHaventLearnedToday)),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider).asData?.value ?? const [];
    final active = ref.watch(activeProfileProvider);
    final l10n = AppLocalizations.of(context);
    final activeName =
        profiles.where((p) => p.id == active).map((p) => p.name).firstOrNull ??
            'Default';

    // The drawer is the app's only route to nine screens, so on the phone it
    // matters more than anywhere else that it is all reachable.
    //
    // Two things were wrong at 240x324. A `DrawerHeader` is 160dp tall before
    // its margin, which is half the screen spent on the app's own name, leaving
    // room for two entries. And the list scrolled its items up *under* the
    // translucent status bar, so "Learning cycles" was overprinted by the signal
    // and battery icons — measured on the device, not a theoretical concern.
    final compact = isCompact(context);
    final scheme = Theme.of(context).colorScheme;
    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.appTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: scheme.onPrimary)),
        Text(l10n.drawerProfile(activeName),
            style: TextStyle(color: scheme.onPrimary)),
      ],
    );

    return Drawer(
      child: SafeArea(
        // Only on the keypad phone, and only at the top. There the list scrolls
        // its rows up under the translucent status bar and "Learning cycles"
        // gets overprinted by the signal and battery icons, and the 24dp this
        // costs is worth less than one unreadable row.
        //
        // Everywhere else it is deliberately inert: a `DrawerHeader` is *meant*
        // to run up behind the status bar, and switching this on unconditionally
        // put a black strip above it on the moto — caught by looking, since no
        // test asserts what the drawer looks like above the fold.
        top: compact,
        bottom: false,
        left: false,
        right: false,
        child: ListView(
          children: [
            // A band the height of its own two lines on the phone, and
            // Material's 160dp panel everywhere else.
            if (compact)
              Container(
                width: double.infinity,
                color: scheme.primary,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: headerText,
              )
            else
              DrawerHeader(
                decoration: BoxDecoration(color: scheme.primary),
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: headerText,
                ),
              ),
            // The way back, named.
            //
            // Every other row here is somewhere else. Reported from the
            // phone as "from that screen where you see Notes Journal etc, I
            // don't know how to get to the tree" — and there was no answer to
            // give: the drawer's scrim closes it on a tap, which needs a
            // touchscreen, and the only other way out is a hardware Back key
            // that nothing on screen mentions. A list of destinations that omits
            // the one you came from is a dead end with a scroll bar.
            //
            // It also serves the case it looks like it serves: the dashboard is
            // the app's first route, so from a drawer opened anywhere this comes
            // home rather than merely closing.
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(l10n.navLearningTree),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n.navLearningCycles),
              onTap: () => _go(context, Routes.cycles),
            ),
            Consumer(builder: (context, ref, _) {
              // The count, not the list. The drawer sits in the tree whether it
              // is open or not, and `chazaraDueProvider` re-derives on every
              // mark and every clock tick and hands back a fresh `List` each
              // time — which is never `==` to the last one. All this row wants
              // is a number, and the number rarely changes.
              final dueCount =
                  ref.watch(chazaraDueProvider.select((due) => due.length));
              return ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.navChazaraDue),
                trailing: dueCount == 0
                    ? null
                    : Badge(label: Text('$dueCount')),
                onTap: () => _go(context, Routes.chazara),
              );
            }),
            // Five rows until this one: Statistics, Siyum calculator, Goals,
            // Siyumim and Mefarshim progress. Statistics and the calculator had
            // been app-bar icons until the bar ran out of room for the app's own
            // name, and became rows here; the other three had always been rows.
            // Together they were nearly half a drawer that was already long
            // enough to need a "way back" row, on a 324dp screen you cross with
            // a D-pad. They are tabs of one report now, and this is the one door
            // to it — the individual routes still resolve for anything that
            // links to them.
            ListTile(
              leading: const Icon(Icons.insights),
              title: Text(l10n.navReports),
              onTap: () => _go(context, Routes.stats),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.navNotesJournal),
              onTap: () => _go(context, Routes.journal),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(l10n.navProfiles),
              onTap: () => _go(context, Routes.profiles),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: Text(l10n.navAddCustomSefer),
              onTap: () => _go(context, Routes.addItem),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.navSettings),
              onTap: () => _go(context, Routes.settings),
            ),
          ],
        ),
      ),
    );
  }

  /// Close the drawer, then go. Two calls on the same navigator, so the drawer
  /// is never left open behind the screen it opened.
  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.pushNamed(context, route);
  }
}
