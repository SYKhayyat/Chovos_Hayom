import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/cycles.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/daf_yomi.dart';
import '../../domain/entities/catalog_node.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

/// Learning cycles: what each of your cycles calls for today, with one tap to
/// log it.
///
/// This used to be a single hardcoded Daf Yomi Bavli card. Anyone learning
/// Mishna Yomi, Rambam Yomi, Amud Yomi, a yeshiva's seder or their own chazara
/// programme had nothing — and a sefer whose transliteration didn't match the
/// catalog silently couldn't be logged, with no way to fix it. Now the built-in
/// cycles are the ones the Hebrew calendar can compute authoritatively, anything
/// else is a cycle you define, and any name mismatch is something you can link
/// by hand.
class CyclesScreen extends ConsumerWidget {
  const CyclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final mode = ref.watch(settingsProvider).calendar;
    final cycles = ref.watch(cyclesTodayProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cyclesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.cyclesWhichToShow,
            onPressed: () => _showBuiltInPicker(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.cyclesNew),
        onPressed: () => Navigator.pushNamed(context, Routes.newCycle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text(l10n.cyclesToday(DateDisplay.format(now, mode)),
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          if (cycles.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.cyclesEmpty),
              ),
            ),
          for (final cycle in cycles) _CycleCard(cycle: cycle),
        ],
      ),
    );
  }

  Future<void> _showBuiltInPicker(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final hidden = ref.watch(cyclesConfigProvider).hiddenBuiltIns;
          final notifier = ref.read(cyclesConfigProvider.notifier);
          final l10n = AppLocalizations.of(context);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(l10n.cyclesBuiltInExplainer),
                ),
                for (final c in CalendarCycle.all)
                  SwitchListTile(
                    title: Text(calendarCycleName(l10n, c)),
                    subtitle: Text(calendarCycleDescription(l10n, c)),
                    value: !hidden.contains(c.id),
                    onChanged: (v) => guarded(
                      context,
                      ref,
                      () => notifier.setBuiltInVisible(c.id, v),
                      what: v
                          ? l10n.whatShowingCycle(calendarCycleName(l10n, c))
                          : l10n.whatHidingCycle(calendarCycleName(l10n, c)),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CycleCard extends ConsumerWidget {
  const _CycleCard({required this.cycle});
  final CycleToday cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Built-in cycles carry English names in `core/`; a user's own cycle is
    // named by the user, so it stays exactly as typed in either language.
    final name = cycleNameById(l10n, cycle.id, cycle.name);
    final description =
        cycleDescriptionById(l10n, cycle.id, cycle.description);
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.labelLarge),
                      Text(
                        cycle.cycleNumber == null
                            ? description
                            : l10n.cycleNumber(description, cycle.cycleNumber!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!cycle.isBuiltIn)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: l10n.tooltipEditCycle,
                    onSelected: (v) => _onMenu(context, ref, v),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
                      PopupMenuItem(
                          value: 'delete', child: Text(l10n.actionDelete)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (cycle.units.isEmpty)
              Text(l10n.cycleNothingToday)
            else
              for (final unit in cycle.units) _UnitRow(unit: unit),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String action) async {
    final notifier = ref.read(cyclesConfigProvider.notifier);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'edit':
        await Navigator.pushNamed(context, Routes.editCycle(cycle.id));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.cycleDeleteTitle(cycle.name)),
            content: Text(l10n.cycleDeleteBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.actionCancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.actionDelete)),
            ],
          ),
        );
        if (ok == true) {
          await guard.run(() => notifier.remove(cycle.id),
              what: l10n.whatDeletingCycle(cycle.name));
        }
    }
  }
}

class _UnitRow extends ConsumerWidget {
  const _UnitRow({required this.unit});
  final ResolvedCycleUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final node = unit.node;
    final day = unit.day;
    final fold = ref.watch(foldProvider).asData?.value;
    final required = ref.watch(layerRequirementsProvider);
    final mode = ref.watch(settingsProvider).calendar;
    final l10n = AppLocalizations.of(context);

    final title = node == null
        ? '${day.sefer} ${day.unit}'
        : nodeAndUnit(l10n, node, day.unit);
    final isDone = unit.isLoggable &&
        (fold?.doneUnits(node!.id, required).contains(day.unit) ?? false);
    final learnedOn = isDone ? fold?.doneAt(node!.id, day.unit) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          if (day.seferHebrew != null)
            Text(l10n.cycleDafHebrew(day.seferHebrew!, day.unit),
                style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (node == null)
            _LinkPrompt(seferName: day.sefer)
          else if (!unit.isLoggable)
            Text(
              l10n.cycleUnitOutOfRange(nodeName(l10n, node), day.unit),
              style: theme.textTheme.bodySmall,
            )
          else if (isDone)
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              // Not "logged for today" — it means this unit is done, whenever
              // that happened, and saying so was simply wrong.
              Expanded(
                child: Text(learnedOn == null
                    ? l10n.cycleAlreadyLearned
                    : l10n.cycleLearnedOn(
                        DateDisplay.format(learnedOn, mode))),
              ),
            ])
          else
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label:
                  Text(l10n.cycleLogButton(unitHeading(l10n, node, day.unit))),
              // This button used to fire the write off unawaited and then say
              // "Logged ✓" whatever happened — the one place in the app where a
              // failed write was reported to the user as a success. The guard
              // awaits it, and the message is now the *consequence* of the write
              // rather than something shown alongside it.
              onPressed: () => guarded(
                context,
                ref,
                () => ref.read(loggingServiceProvider).markDone(node.id, day.unit),
                what: l10n.whatLogging(title),
                success: l10n.cycleLogged(title),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when a cycle names a sefer the catalog has under a different spelling.
/// The old code just said "isn't in your catalog" and left it there.
class _LinkPrompt extends ConsumerWidget {
  const _LinkPrompt({required this.seferName});
  final String seferName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.cycleSeferNotInCatalog(seferName),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.link, size: 18),
          label: Text(l10n.cycleLinkToSefer),
          onPressed: () => _pick(context, ref),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return;
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final leaves = [
      for (final n in catalog.all)
        if (n.isLeaf) n,
    ]..sort((a, b) => nodeName(l10n, a).compareTo(nodeName(l10n, b)));

    final chosen = await showDialog<CatalogNode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.cycleLinkTitle(seferName)),
        children: [
          SizedBox(
            width: 320,
            height: 400,
            child: ListView.builder(
              itemCount: leaves.length,
              itemBuilder: (_, i) {
                // Qualified: this list is every leaf in the catalog, flat and
                // alphabetical, so four rows read "Shabbos" with nothing to
                // choose between them until the ancestor is named.
                final primary = qualifiedNodeName(l10n, catalog, leaves[i]);
                final secondary = primary == leaves[i].name
                    ? leaves[i].nameHebrew
                    : leaves[i].name;
                return ListTile(
                  title: Text(primary),
                  subtitle: secondary == null || secondary == primary
                      ? null
                      : Text(secondary),
                  onTap: () => Navigator.pop(dialogContext, leaves[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final cycles = ref.read(cyclesConfigProvider.notifier);
    final chosenName = nodeName(l10n, chosen);
    await guard.run(
      () => cycles.mapSefer(seferName, chosen.id),
      what: l10n.whatLinkingSefer(seferName, chosenName),
      success: l10n.cycleLinked(seferName, chosenName),
    );
  }
}
