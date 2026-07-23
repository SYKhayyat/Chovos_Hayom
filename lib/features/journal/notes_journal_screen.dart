import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/learning_event.dart';
import '../unit_grid/unit_grid_screen.dart';

/// A single haara paired with where it was written.
class _JournalEntry {
  _JournalEntry(this.event, this.node);
  final LearningEvent event;
  final CatalogNode? node;

  String get location {
    final n = node;
    if (n == null) return 'Unknown item';
    // `unitHeading` so a named unit reads as its name (Parshas Noach) rather
    // than its index — the same thing the grid and the sheets show.
    return '${n.name} · ${n.unitHeading(event.unitIndex)}';
  }
}

/// The **Notes Journal**: every haara you've written, newest first, each showing
/// where it belongs and tapping through to that unit. There is one note field per
/// event, so everything you write is collected here — no classifying up front.
class NotesJournalScreen extends ConsumerStatefulWidget {
  const NotesJournalScreen({super.key});

  @override
  ConsumerState<NotesJournalScreen> createState() => _NotesJournalScreenState();
}

class _NotesJournalScreenState extends ConsumerState<NotesJournalScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_JournalEntry> _entries(List<LearningEvent> events, Catalog? catalog) {
    final entries = <_JournalEntry>[
      for (final e in events)
        if (e.note != null && e.note!.trim().isNotEmpty)
          _JournalEntry(e, catalog?.byId(e.nodeId)),
    ]..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries
        .where((e) =>
            e.event.note!.toLowerCase().contains(q) ||
            e.location.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider).asData?.value ?? const [];
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final mode = ref.watch(settingsProvider).calendar;
    final entries = _entries(events, catalog);

    return Scaffold(
      appBar: AppBar(title: const Text('Notes Journal')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search haaros…',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isEmpty
                            ? 'No haaros yet.\nAdd one when you log or edit a daf — '
                                'the "Haara" field lands here.'
                            : 'No haaros match “$_query”.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final node = entry.node;
                      return ListTile(
                        leading: const Icon(Icons.lightbulb_outline),
                        title: Text(entry.event.note!.trim()),
                        subtitle: Text(
                          '${entry.location} · '
                          '${DateDisplay.format(entry.event.occurredAt, mode)}',
                        ),
                        onTap: node != null && node.isLeaf
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => UnitGridScreen(node: node),
                                  ),
                                )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
