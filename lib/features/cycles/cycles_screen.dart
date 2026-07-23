import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cycles.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../core/daf_yomi.dart';
import '../../domain/entities/catalog_node.dart';
import 'edit_cycle_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning cycles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Which cycles to show',
            onPressed: () => _showBuiltInPicker(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New cycle'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditCycleScreen()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text('Today · ${DateDisplay.format(now, mode)}',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          if (cycles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No cycles yet. Turn on a built-in one, or define your own — '
                  'any sefarim, in any order, at any pace.',
                ),
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
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Built-in cycles are the ones the Hebrew calendar can work '
                    'out exactly. For anything else, define your own.',
                  ),
                ),
                for (final c in CalendarCycle.all)
                  SwitchListTile(
                    title: Text(c.name),
                    subtitle: Text(c.description),
                    value: !hidden.contains(c.id),
                    onChanged: (v) => notifier.setBuiltInVisible(c.id, v),
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
                      Text(cycle.name, style: theme.textTheme.labelLarge),
                      Text(
                        cycle.cycleNumber == null
                            ? cycle.description
                            : '${cycle.description} · cycle ${cycle.cycleNumber}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!cycle.isBuiltIn)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Edit cycle',
                    onSelected: (v) => _onMenu(context, ref, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (cycle.units.isEmpty)
              const Text("This cycle has nothing scheduled for today.")
            else
              for (final unit in cycle.units) _UnitRow(unit: unit),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String action) async {
    final notifier = ref.read(cyclesConfigProvider.notifier);
    final existing =
        ref.read(cyclesConfigProvider).custom.where((c) => c.id == cycle.id);
    switch (action) {
      case 'edit':
        if (existing.isEmpty) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EditCycleScreen(existing: existing.first)));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete “${cycle.name}”?'),
            content: const Text(
                'Only the cycle is removed. Everything you learned through it '
                'stays in your log.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true) await notifier.remove(cycle.id);
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

    final title = node == null
        ? '${day.sefer} ${day.unit}'
        : '${node.name} · ${node.unitHeading(day.unit)}';
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
            Text('${day.seferHebrew} · דף ${day.unit}',
                style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (node == null)
            _LinkPrompt(seferName: day.sefer)
          else if (!unit.isLoggable)
            Text(
              '“${node.name}” doesn’t have a unit ${day.unit}, so this can’t be '
              'logged. Check the sefer’s unit count, or link this cycle to a '
              'different one.',
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
                    ? 'Already learned ✓'
                    : 'Learned ${DateDisplay.format(learnedOn, mode)} ✓'),
              ),
            ])
          else
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Log ${node.unitHeading(day.unit)}'),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                ref.read(loggingServiceProvider).markDone(node.id, day.unit);
                messenger.showSnackBar(SnackBar(content: Text('Logged $title')));
              },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('“$seferName” isn’t in your catalog under that name.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.link, size: 18),
          label: const Text('Link it to a sefer'),
          onPressed: () => _pick(context, ref),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    if (catalog == null) return;
    final leaves = [
      for (final n in catalog.all)
        if (n.isLeaf) n,
    ]..sort((a, b) => a.name.compareTo(b.name));

    final chosen = await showDialog<CatalogNode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Link “$seferName” to…'),
        children: [
          SizedBox(
            width: 320,
            height: 400,
            child: ListView.builder(
              itemCount: leaves.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(leaves[i].name),
                subtitle: leaves[i].nameHebrew == null
                    ? null
                    : Text(leaves[i].nameHebrew!),
                onTap: () => Navigator.pop(dialogContext, leaves[i]),
              ),
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(cyclesConfigProvider.notifier).mapSefer(seferName, chosen.id);
  }
}
