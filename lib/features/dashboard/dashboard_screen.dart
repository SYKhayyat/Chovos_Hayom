import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/backup_status.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/sorting.dart';
import '../../application/stats.dart';
import '../../domain/entities/progress_node.dart';
import '../../domain/usecases/reminders_policy.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/error_view.dart';
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
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Icon(
                _expanded.isEmpty ? Icons.unfold_more : Icons.unfold_less),
            tooltip: _expanded.isEmpty ? l10n.expandAll : l10n.collapseAll,
            onPressed: () => _setExpanded(_expanded.isEmpty),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            color: sort.active ? Theme.of(context).colorScheme.primary : null,
            tooltip: sort.active
                ? l10n.tooltipSortActive(sortMetricLabel(l10n, sort.metric))
                : l10n.tooltipSort,
            onPressed: () => showSortSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.tooltipSearch,
            onPressed: catalog == null
                ? null
                : () => showSearch(
                      context: context,
                      delegate: CatalogSearchDelegate(catalog.all.toList()),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: l10n.tooltipStatistics,
            onPressed: () => Navigator.pushNamed(context, Routes.stats),
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: l10n.tooltipSiyumCalculator,
            onPressed: () => Navigator.pushNamed(context, Routes.calculator),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.settings),
              child: Text(l10n.backupBannerAction),
            ),
          ],
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

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration:
                BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(l10n.appTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                  Text(l10n.drawerProfile(activeName),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary)),
                ],
              ),
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
    );
  }

  /// Close the drawer, then go. Two calls on the same navigator, so the drawer
  /// is never left open behind the screen it opened.
  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    Navigator.pushNamed(context, route);
  }
}
