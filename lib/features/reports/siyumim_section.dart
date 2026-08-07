import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';
import 'report_screen.dart';

/// The list of siyumim, most recent first — a running record of what you've
/// been maslim.
///
/// Every level counts: a mesechta, a seder, and Shas itself are all siyumim, and
/// the bigger ones are marked as such rather than sitting in the list looking
/// like any other line.
class SiyumimSection extends ConsumerWidget {
  const SiyumimSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siyumim = ref.watch(siyumimProvider);
    final mode = ref.watch(settingsProvider.select((s) => s.calendar));
    final l10n = AppLocalizations.of(context);

    if (siyumim.isEmpty) return ReportEmpty(message: l10n.siyumEmpty);
    // A roll of honour, not a menu: every row here is a `ListTile` with no
    // `onTap`, so none of them can hold focus and a D-pad had nothing to
    // move to. Without this the list was frozen at whatever the first
    // screenful happened to be. Same defect as the Overview tab, and now the
    // same [ReportBody].
    return ReportBody(
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.siyumCount(siyumim.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final s in siyumim)
            ListTile(
              leading: Icon(
                s.isCategory ? Icons.workspace_premium : Icons.emoji_events,
                color: Colors.amber,
                // A siyum on a whole seder deserves to look bigger than a
                // siyum on one mesechta.
                size: s.isCategory ? 30 : 24,
              ),
              title: Text(
                nodeName(l10n, s.node),
                style: s.isCategory
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null,
              ),
              subtitle: Text(
                  l10n.siyumCompleted(
                        DateDisplay.format(s.completedOn, mode),
                        unitCount(l10n, s.units, s.node.unitLabel),
                      ) +
                      (s.isCategory ? l10n.siyumEverythingUnderneath : '')),
            ),
        ],
      ),
    );
  }
}
