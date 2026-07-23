import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';

/// The list of siyumim, most recent first — a running record of what you've
/// been maslim.
///
/// Every level counts: a mesechta, a seder, and Shas itself are all siyumim, and
/// the bigger ones are marked as such rather than sitting in the list looking
/// like any other line.
class SiyumScreen extends ConsumerWidget {
  const SiyumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siyumim = ref.watch(siyumimProvider);
    final mode = ref.watch(settingsProvider).calendar;

    return Scaffold(
      appBar: AppBar(title: const Text('Siyumim')),
      body: siyumim.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No siyumim yet.\n'
                  'Finish every unit of a sefer — or of a whole seder — and it '
                  'will appear here. חזק!',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${siyumim.length} siyum${siyumim.length == 1 ? '' : 'im'} — יישר כח!',
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
                      s.node.name,
                      style: s.isCategory
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                    subtitle: Text(
                        'Completed ${DateDisplay.format(s.completedOn, mode)} · '
                        '${s.units} ${s.node.unitLabel?.name ?? 'unit'}s'
                        '${s.isCategory ? ' · everything underneath' : ''}'),
                  ),
              ],
            ),
    );
  }
}
