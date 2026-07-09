import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';

/// The list of completed sefarim/mesechtos (siyumim), most recent first — a
/// running record of what you've been maslim.
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
                  'Finish every unit of a sefer and it will appear here. חזק!',
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
                    leading: const Icon(Icons.emoji_events, color: Colors.amber),
                    title: Text(s.node.name),
                    subtitle: Text(
                        'Completed ${DateDisplay.format(s.completedOn, mode)} · '
                        '${s.units} ${s.node.unitLabel?.name ?? 'unit'}s'),
                  ),
              ],
            ),
    );
  }
}
