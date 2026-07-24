import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/learning_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/naming.dart';

/// A single haara paired with where it was written.
class _JournalEntry {
  _JournalEntry(this.event, this.node);
  final LearningEvent event;
  final CatalogNode? node;

  /// Where the haara was written, in the reader's language.
  ///
  /// A method rather than a getter because naming a unit needs the locale, and
  /// this list is built by a provider that has no `BuildContext`. The provider
  /// still does the expensive half — collecting and sorting — once per change;
  /// only the words are deferred to the widget that has the localizations.
  String location(AppLocalizations l10n) {
    final n = node;
    if (n == null) return l10n.journalUnknownItem;
    // `nodeAndUnit` so a named unit reads as its name (Parshas Noach) rather
    // than its index — the same thing the grid and the sheets show.
    return nodeAndUnit(l10n, n, event.unitIndex);
  }
}

/// Every haara-bearing event, paired with its node and sorted newest-first.
///
/// Built once per (log, catalog) change and shared, so typing in the search box
/// only *filters* this list — it used to filter the whole event log and re-sort
/// it on every keystroke, work that doesn't depend on the query and is the same
/// each time. The search is a cheap linear scan over the result.
final _journalEntriesProvider = Provider<List<_JournalEntry>>((ref) {
  final events = ref.watch(eventsProvider).asData?.value ?? const [];
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  return <_JournalEntry>[
    for (final e in events)
      if (e.note != null && e.note!.trim().isNotEmpty)
        _JournalEntry(e, catalog?.byId(e.nodeId)),
  ]..sort((a, b) => b.event.occurredAt.compareTo(a.event.occurredAt));
});

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

  /// Filter the pre-built, pre-sorted list by the current query. No sort here —
  /// that already happened once in [_journalEntriesProvider].
  List<_JournalEntry> _filter(List<_JournalEntry> all, AppLocalizations l10n) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final e in all)
        if (e.event.note!.toLowerCase().contains(q) ||
            e.location(l10n).toLowerCase().contains(q))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider).calendar;
    final l10n = AppLocalizations.of(context);
    final entries = _filter(ref.watch(_journalEntriesProvider), l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.journalTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.journalSearchHint,
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
                            ? l10n.journalEmpty
                            : l10n.journalNoMatches(_query),
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
                        subtitle: Text(l10n.journalSubtitle(
                          entry.location(l10n),
                          DateDisplay.format(entry.event.occurredAt, mode),
                        )),
                        onTap: node != null && node.isLeaf
                            ? () => Navigator.pushNamed(
                                context, Routes.sefer(node.id))
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
