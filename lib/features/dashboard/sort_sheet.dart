import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../application/sorting.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

/// Bottom sheet to choose how the tree's children are ordered: a metric, a
/// direction, and which generation the sort applies to.
Future<void> showSortSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SortSheet(),
  );
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(settingsProvider.select((s) => s.sort));
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.sortSheetTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              RadioGroup<SortMetric>(
                groupValue: config.metric,
                onChanged: (v) {
                  if (v == null) return;
                  guarded(context, ref,
                      () => notifier.setSort(config.copyWith(metric: v)),
                      what: l10n.whatSavingSortOrder);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in SortMetric.values)
                      RadioListTile<SortMetric>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(sortMetricLabel(l10n, m)),
                        value: m,
                      ),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.sortDescending),
                subtitle: Text(l10n.sortDescendingSubtitle),
                value: config.descending,
                onChanged: config.active
                    ? (v) => guarded(context, ref,
                        () => notifier.setSort(config.copyWith(descending: v)),
                        what: l10n.whatSavingSortOrder)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(l10n.sortApplyTo, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _levelChip(context, ref, config, null, l10n.sortAllLevels),
                  for (var l = 1; l <= 5; l++)
                    _levelChip(context, ref, config, l,
                        l == 1 ? l10n.sortChildren : l10n.sortLevel(l)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelChip(BuildContext context, WidgetRef ref, SortConfig config,
      int? level, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: config.level == level,
      onSelected: config.active
          ? (_) => guarded(
              context,
              ref,
              () => ref
                  .read(settingsProvider.notifier)
                  .setSort(config.copyWith(level: level)),
              what: AppLocalizations.of(context).whatSavingSortOrder)
          : null,
    );
  }
}
