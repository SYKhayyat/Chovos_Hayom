import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../core/day.dart';
import '../../core/bar_actions.dart';
import '../../core/focus.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/usecases/fold_log.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/error_view.dart';
import '../common/goal_status.dart';
import '../common/guarded.dart';
import '../common/missing_item.dart';
import '../common/naming.dart';
import 'bulk_actions_sheet.dart';
import 'log_unit_sheet.dart';
import 'mefarshim_config_sheet.dart';
import 'unit_details_sheet.dart';
import 'unit_layers_sheet.dart';

/// A grid of every unit (daf/perek/siman) in a leaf. Tap toggles done; long-press
/// opens a menu to log details, add a chazara (review), or un-mark.
///
/// Addressed by **id**, not by a `CatalogNode`: holding the node meant the screen
/// froze it at push time, so renaming a sefer (or changing its unit count) while
/// its grid was open left the old name in the app bar. Resolving the id against
/// the live catalog on every build is also what lets `/sefer/<id>` be a route.
class UnitGridScreen extends ConsumerWidget {
  const UnitGridScreen({super.key, required this.nodeId});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(catalogNodeProvider(nodeId));
    if (node == null) {
      return MissingItemScreen(
        loading: !ref.watch(mergedCatalogProvider).hasValue,
        message: AppLocalizations.of(context).seferMissing,
      );
    }
    return _UnitGrid(node: node);
  }
}

class _UnitGrid extends ConsumerWidget {
  const _UnitGrid({required this.node});

  final CatalogNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldAsync = ref.watch(foldProvider);
    final goal = ref.watch(goalStatusProvider(node.id));
    final l10n = AppLocalizations.of(context);
    final name = nodeName(l10n, node);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        // Three actions plus a back button on a 240dp bar left the sefer's own
        // name no room, so the grid showed a screenful of numbered cells and
        // nothing saying which sefer they belonged to. See [barActions].
        actions: barActions(
          context,
          [
            BarAction(
              icon: Icons.checklist,
              label: l10n.tooltipBulkActions,
              onPressed: () => showBulkActionsSheet(context, ref, node: node),
            ),
            BarAction(
              icon: Icons.auto_stories_outlined,
              label: l10n.tooltipMefarshim,
              onPressed: () =>
                  showMefarshimConfigSheet(context, ref, node: node),
            ),
            BarAction(
              icon: Icons.flag_outlined,
              label: l10n.tooltipSetGoalDate,
              onPressed: () => _setGoal(context, ref),
            ),
          ],
          moreTooltip: l10n.tooltipMore,
        ),
      ),
      body: Column(
        children: [
          if (goal != null)
            GoalBanner(goal: goal, nodeId: node.id, name: name),
          Expanded(
            child: foldAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // The fold is the event log; a failure here is the database, and
              // reading it failing changes nothing that is in it.
              error: (e, stack) => ErrorView(
                title: l10n.errorLogTitle,
                body: l10n.errorLogBody,
                error: e,
                stackTrace: stack,
                onRetry: () => ref.invalidate(eventsProvider),
              ),
              data: (fold) => _grid(context, ref, fold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setGoal(BuildContext context, WidgetRef ref) async {
    // Through the clock, like every other "what day is it" in the app — reading
    // the wall clock here made the one screen that *creates* a goal the one
    // screen no test could place in time.
    final now = ref.read(clockProvider)();
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: (Day.of(now) + 180).midnight,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await guard.run(
      () => ref.read(goalsProvider.notifier).setGoal(node.id, picked),
      what: l10n.whatSettingGoal(nodeName(l10n, node)),
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref, LogFold fold) {
    final roles = ref.watch(layerRolesProvider);
    final done = fold.doneUnits(node.id, roles);
    final l10n = AppLocalizations.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: node.unitCount,
      itemBuilder: (context, i) {
        final unit = node.unitOffset + i;
        final isDone = done.contains(unit);
        // A unit shows the per-layer checklist when more than the text is
        // checkable on it; its fill fraction tracks only the *required* layers, so
        // optional mefarshim never inflate progress.
        final layered = roles.isLayered(node.id, unit);
        final fraction = isDone
            ? 1.0
            : (layered ? roles.fraction(node.id, unit, fold) : 0.0);
        final reviewCount = fold.reviewCount(node.id, unit);
        final hasDetails = isDone && fold.isAnnotated(node.id, unit);
        return _UnitCell(
          label: node.unitDisplay(unit),
          // Everything the cell says visually, said in words.
          //
          // A cell shows its state through *colour alone* — a filled square is
          // learned, an empty one is not — which a screen reader cannot see, and
          // which is the one thing on this screen worth knowing. Its only text
          // child is the bare unit number, so the whole grid announced as
          // "1, 2, 3, 4" with no indication of what had been learned: the app's
          // central screen, unusable without sight. State, partial fill, chazara
          // count and the details dot are all named here.
          semanticLabel: [
            if (isDone)
              l10n.gridCellSemanticDone(unitHeading(l10n, node, unit))
            else if (fraction > 0)
              l10n.gridCellSemanticPartial(
                  unitHeading(l10n, node, unit), (fraction * 100).round())
            else
              l10n.gridCellSemanticNotDone(unitHeading(l10n, node, unit)),
            if (reviewCount > 0) l10n.gridCellSemanticReviews(reviewCount),
            if (hasDetails) l10n.gridCellSemanticHasDetails,
          ].join(', '),
          isDone: isDone,
          fraction: fraction,
          reviewCount: reviewCount,
          // The "there are details here" dot. Comes off the shared fold rather
          // than a scan of the whole log on every grid rebuild.
          hasDetails: hasDetails,
          onTap: () async {
            // Layered units open a per-meforish checklist; text-only units
            // toggle with a single tap (reversible — tapping again undoes).
            if (layered) {
              await showUnitLayersSheet(context, ref, node: node, unit: unit);
              return;
            }
            final logger = ref.read(loggingServiceProvider);
            final heading = nodeAndUnit(l10n, node, unit);
            await guarded(
              context,
              ref,
              () => isDone
                  ? logger.markUndone(node.id, unit)
                  : logger.markDone(node.id, unit),
              what: isDone
                  ? l10n.whatUnmarking(heading)
                  : l10n.whatMarkingLearned(heading),
            );
          },
          onLongPress: () => _cellMenu(context, ref, unit, isDone),
        );
      },
    );
  }

  Future<void> _cellMenu(
      BuildContext context, WidgetRef ref, int unit, bool isDone) async {
    final logger = ref.read(loggingServiceProvider);
    final l10n = AppLocalizations.of(context);
    final heading = nodeAndUnit(l10n, node, unit);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDone)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.cellMenuViewEditDetails),
                subtitle: Text(l10n.cellMenuViewEditDetailsSubtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showUnitDetailsSheet(context, ref, node: node, unit: unit);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: Text(
                  isDone ? l10n.cellMenuRelog : l10n.cellMenuLog),
              onTap: () async {
                Navigator.pop(sheetContext);
                await logWithDetails(context, ref, node: node, unit: unit);
              },
            ),
            if (isDone) ...[
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.cellMenuAddChazara),
                onTap: () {
                  Navigator.pop(sheetContext);
                  logChazaraWithDetails(context, ref, node: node, unit: unit);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo),
                title: Text(l10n.cellMenuUnmark),
                onTap: () {
                  Navigator.pop(sheetContext);
                  guarded(context, ref, () => logger.markUndone(node.id, unit),
                      what: l10n.whatUnmarking(heading));
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.check),
                title: Text(l10n.cellMenuMarkLearned),
                onTap: () {
                  Navigator.pop(sheetContext);
                  guarded(context, ref, () => logger.markDone(node.id, unit),
                      what: l10n.whatMarkingLearned(heading));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// One square of the grid.
///
/// Stateful only to know whether it holds keyboard focus. That is not a detail:
/// the cell is an `InkWell` inside a filled `Container` inside a `ClipRRect`, so
/// the InkWell's own focus highlight paints *underneath* the fill and is
/// invisible. Measured on the desktop build — five Tabs and Enter marked daf 7,
/// and no screenshot before the Enter showed focus anywhere. A keyboard user was
/// marking blind.
class _UnitCell extends StatefulWidget {
  const _UnitCell({
    required this.label,
    required this.semanticLabel,
    required this.isDone,
    required this.fraction,
    required this.reviewCount,
    required this.hasDetails,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;

  /// What the cell announces to a screen reader — its state in words, since the
  /// visual carries it in colour. See where this is built in `_grid`.
  final String semanticLabel;

  final bool isDone;

  /// 0..1 share of required layers done — a partial fill for layered units.
  final double fraction;
  final int reviewCount;
  final bool hasDetails;
  final VoidCallback onTap;

  /// Opens the cell menu. Reached by long-press, by right-click, and — since
  /// there was no keyboard route to it at all — by the context-menu key or
  /// Shift+F10 while the cell is focused.
  final VoidCallback onLongPress;

  @override
  State<_UnitCell> createState() => _UnitCellState();
}

class _UnitCellState extends State<_UnitCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = widget.isDone;
    final fraction = widget.fraction;
    final reviewCount = widget.reviewCount;
    final label = widget.label;
    final partial = !isDone && fraction > 0;
    // The label wraps the InkWell rather than replacing its semantics: the
    // InkWell is what advertises the cell as focusable and enabled, which is how
    // a reader reaches it in the first place. `checked` adds the state the
    // colour was carrying alone.
    return Semantics(
      label: widget.semanticLabel,
      // An InkWell announces itself as focusable and tappable but not as a
      // *button*, and carries no enabled state; both are added here so the cell
      // reads as the control it is. `checked` carries the completion the fill
      // colour was carrying alone.
      button: true,
      enabled: true,
      checked: isDone,
      child: CallbackShortcuts(
        // The keyboard route to the cell menu. Right-click reaches it and the
        // comment below used to call that "desktop-friendly, no touchscreen
        // required" — true of a *mouse*. With a keyboard alone you could toggle
        // "learned" and nothing else: no duration, no haara, no chazara, no
        // details. Measured: Shift+F10 did nothing, because `lib/` contained no
        // key handling of any kind.
        //
        // Both conventional keys, since which one a keyboard has varies:
        // Shift+F10 works everywhere, the dedicated context-menu key exists on
        // most full-size Windows keyboards and no laptop.
        //
        // On the Sonim these turn out to already be the right bindings: Android
        // delivers its `KEYCODE_MENU` — the keypad's left soft key — as
        // [LogicalKeyboardKey.contextMenu], the same logical key a Windows menu
        // key sends. The keyboard route added for desktop reached the phone
        // unchanged.
        bindings: contextMenuBindings(widget.onLongPress),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          // Right-click / secondary-tap opens the same menu — desktop-friendly,
          // no touchscreen required.
          onSecondaryTap: widget.onLongPress,
          // Drives the ring below. The InkWell's own `focusColor` cannot be seen
          // here: it paints behind the filled container this cell is made of.
          onFocusChange: (focused) => setState(() => _focused = focused),
          borderRadius: BorderRadius.circular(8),
          // The number, the ↻ badge and the note glyph are all already inside
          // the label above, as a sentence rather than three loose fragments —
          // so the visuals contribute nothing further to what is read out.
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDone ? scheme.primary : scheme.surfaceContainerHighest,
                  // The focus ring. Drawn against the cell's *own* background,
                  // so it takes that background's "on" colour and is legible on
                  // a filled cell and an empty one alike — the default highlight
                  // is not, which is how a keyboard user came to be marking
                  // dapim with nothing on screen telling them which.
                  border: _focused
                      ? Border.all(
                          width: 2,
                          color:
                              isDone ? scheme.onPrimary : scheme.onSurface)
                      : null,
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Partial-completion fill rising from the bottom.
                    if (partial)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: fraction.clamp(0.05, 1),
                            child: Container(
                              color: scheme.primary.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Shrink long named-unit labels so they still fit.
                          fontSize: label.length > 3 ? 10 : 14,
                          color: isDone
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (reviewCount > 0)
                      // Directional: the chazara count belongs in the trailing
                      // top corner and the note glyph in the leading bottom one,
                      // which swap sides under a right-to-left layout.
                      PositionedDirectional(
                        end: 4,
                        top: 2,
                        child: Text('↻$reviewCount',
                            style: TextStyle(
                                fontSize: 10,
                                color: isDone
                                    ? scheme.onPrimary
                                    : scheme.primary)),
                      ),
                    if (widget.hasDetails)
                      PositionedDirectional(
                        start: 5,
                        bottom: 4,
                        child: Icon(Icons.sticky_note_2,
                            size: 11,
                            color: isDone ? scheme.onPrimary : scheme.primary),
                      ),
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
