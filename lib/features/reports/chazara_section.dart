import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/stats.dart';
import '../../domain/entities/catalog_node.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';
import 'report_screen.dart';

/// Chazara: the units you have been over more than once.
///
/// **This is where the drawer's chazara row leads.** #45 removed the screen it
/// used to open — a spaced-repetition list of things that were *due* — and left
/// the row pointing at statistics, which had nothing to show. This is that
/// something (#46).
///
/// It answers one question: *what am I keeping up with?* Learning is the first
/// pass, so a unit showing 3 has been learned once and returned to twice, and it
/// is the units with the largest numbers that are worth seeing. It is not a due
/// list and never will be: nothing here is late, because nothing is scheduled.
///
/// The count on each row is the same number its sefer's bar draws as an extra
/// line, read one unit at a time instead of rolled up.
class ChazaraSection extends ConsumerWidget {
  const ChazaraSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Only units that have been *gone back to* — see
    // `chazaraRepeatedProvider`, which is why this tab and the drawer's badge
    // can never count different things.
    final passes = ref.watch(chazaraRepeatedProvider);
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;

    if (passes.isEmpty) return ReportEmpty(message: l10n.chazaraEmpty);
    return ReportBody(
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.chazaraRepeatedCount(passes.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final pass in passes)
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(
                _label(l10n, catalog?.byId(pass.nodeId), pass.unitIndex),
              ),
              // The count is the reason this list exists, so it is the trailing
              // figure rather than buried in a subtitle.
              trailing: Text(
                '${pass.passes}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: pass.passes > 1 ? Text(l10n.chazaraPassHint) : null,
            ),
        ],
      ),
    );
  }

  /// "Shabbos · daf 12".
  ///
  /// The provider already drops units whose sefer has been hidden or removed, so
  /// a missing node here would be a catalog that changed underneath an open
  /// screen. It renders as the bare unit rather than crashing, and as the raw id
  /// if even that is unavailable — the same order of preference the rest of the
  /// app uses.
  String _label(AppLocalizations l10n, CatalogNode? node, int unitIndex) {
    if (node == null) return '$unitIndex';
    return nodeAndUnit(l10n, node, unitIndex);
  }
}
