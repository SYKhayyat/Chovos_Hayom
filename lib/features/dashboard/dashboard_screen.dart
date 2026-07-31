import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/backup_status.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/sorting.dart';
import '../../application/stats.dart';
import '../../core/keypad.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/progress_node.dart';
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
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final l10n = AppLocalizations.of(context);

    final sort = ref.watch(settingsProvider.select((s) => s.sort));
    // Watched unconditionally, so this widget's set of subscriptions is the same
    // on every build. The roll-up is still only paid for when a sort needs it —
    // that gate moved inside the provider. See nodeLastActivityProvider.
    final lastActivity = ref.watch(nodeLastActivityProvider);

    final reminderOn = ref.watch(settingsProvider).reminderEnabled;
    final events = ref.watch(eventsProvider).asData?.value ?? const [];
    final showNudge = RemindersPolicy.shouldRemind(
      enabled: reminderOn,
      events: events,
      now: ref.watch(clockProvider)(),
    );

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
            if (showNudge) const _NudgeBanner(),
            if (ref.watch(backupStatusProvider).due) const _BackupBanner(),
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
              const SizedBox(height: 4),
              Text(l10n.backupBannerWhy,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onErrorContainer)),
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
          // warning that just becomes noise. Turning it off here is one tap,
          // says where to turn it back on, and offers Undo — so a mis-tap on a
          // safety feature costs nothing.
          dismiss: IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: l10n.backupBannerDismiss,
            color: scheme.onErrorContainer,
            onPressed: () => _dismiss(context, ref, l10n),
          ),
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
    required Widget dismiss,
  }) {
    if (!isCompact(context)) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(child: text),
          const SizedBox(width: 8),
          action,
          dismiss,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [icon, const SizedBox(width: 12), Expanded(child: text)],
        ),
        const SizedBox(height: 8),
        // Wrapped rather than a Row: "Back up" and the close button together
        // come to 11px more than a 240dp card has, and a Row would simply
        // overflow — which is the whole family of bug this banner is being
        // fixed for. A translation can only make the button wider, so the
        // layout that cannot overflow is the one to use.
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [action, dismiss],
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

class _NudgeBanner extends StatelessWidget {
  const _NudgeBanner();

  @override
  Widget build(BuildContext context) {
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
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n.navLearningCycles),
              onTap: () => _go(context, Routes.cycles),
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: Text(l10n.navGoals),
              onTap: () => _go(context, Routes.goals),
            ),
            Consumer(builder: (context, ref, _) {
              final dueCount = ref.watch(chazaraDueProvider).length;
              return ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.navChazaraDue),
                trailing: dueCount == 0
                    ? null
                    : Badge(label: Text('$dueCount')),
                onTap: () => _go(context, Routes.chazara),
              );
            }),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(l10n.navSiyumim),
              onTap: () => _go(context, Routes.siyumim),
            ),
            // These two were app-bar icons until the bar ran out of room for the
            // app's own name. They are destinations like everything else here, and
            // a named row is easier to find than an unlabelled icon.
            ListTile(
              leading: const Icon(Icons.insights),
              title: Text(l10n.navStatistics),
              onTap: () => _go(context, Routes.stats),
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: Text(l10n.navSiyumCalculator),
              onTap: () => _go(context, Routes.calculator),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.navNotesJournal),
              onTap: () => _go(context, Routes.journal),
            ),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: Text(l10n.navMefarshimProgress),
              onTap: () => _go(context, Routes.mefarshim),
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
