import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/preferences.dart';
import '../data/catalog/json_catalog_repository.dart';
import '../data/drift/database.dart';
import '../data/repositories/drift_progress_repository.dart';
import '../domain/entities/catalog.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/entities/layer.dart';
import '../domain/entities/learning_event.dart';
import '../domain/entities/profile.dart';
import '../domain/entities/progress_node.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/batch_history.dart';
import '../domain/usecases/fold_log.dart';
import '../domain/usecases/layer_roles.dart';
import '../domain/usecases/log_activity.dart';
import '../domain/usecases/mefarshim_stats.dart';
import '../domain/usecases/roll_up.dart';
import 'bulk_marker.dart';
import 'crash_log.dart';
import 'logging_service.dart';

/// App-level key-value preferences. Overridden in `main` with a shared_preferences
/// implementation; defaults to in-memory (used by tests).
final appPreferencesProvider =
    Provider<AppPreferences>((ref) => InMemoryPreferences());

/// The Drift database (app-wide singleton).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// The on-device crash log.
///
/// One instance, shared: the write guard appends to it, and the Settings screen
/// reads the same file back. It is a provider rather than a constructor call so
/// a test can point it at a temp directory instead of the platform's app-support
/// path — which also keeps the test off a platform channel.
final crashLogProvider = Provider<CrashLog>((ref) => CrashLog());

/// Pluggable catalog source (bundled JSON for now).
final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => JsonCatalogRepository());

/// The loaded, indexed base catalog (bundled reference data only).
final catalogProvider =
    FutureProvider<Catalog>((ref) => ref.watch(catalogRepositoryProvider).load());

/// Event-log persistence, Drift-backed.
final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => DriftProgressRepository(ref.watch(databaseProvider)));

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------

/// The active local profile id, persisted across launches.
class ActiveProfileController extends Notifier<String> {
  @override
  String build() =>
      ref.watch(appPreferencesProvider).getString(PrefKeys.activeProfileId) ??
      'default';

  Future<void> setProfile(String id) async {
    await ref
        .read(appPreferencesProvider)
        .setString(PrefKeys.activeProfileId, id);
    state = id;
  }
}

final activeProfileProvider =
    NotifierProvider<ActiveProfileController, String>(ActiveProfileController.new);

/// All profiles; ensures a default profile exists on first run.
class ProfilesController extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() async {
    final repo = ref.watch(progressRepositoryProvider);
    var list = await repo.getProfiles();
    if (list.isEmpty) {
      await repo.addProfile(
          Profile(id: 'default', name: 'Default', createdAt: DateTime.now()));
      list = await repo.getProfiles();
    }
    return list;
  }

  /// Create a new profile and switch to it.
  Future<void> create(String name) async {
    final repo = ref.read(progressRepositoryProvider);
    final id = const Uuid().v4();
    await repo.addProfile(Profile(id: id, name: name, createdAt: DateTime.now()));
    ref.invalidateSelf();
    await future;
    await ref.read(activeProfileProvider.notifier).setProfile(id);
  }

  /// Rename an existing profile.
  Future<void> rename(String id, String name) async {
    await ref.read(progressRepositoryProvider).renameProfile(id, name);
    ref.invalidateSelf();
    await future;
  }

  /// Delete a profile and all of its data. The last remaining profile cannot be
  /// deleted. If the active profile is deleted, switches to another.
  Future<void> delete(String id) async {
    final repo = ref.read(progressRepositoryProvider);
    final profiles = await repo.getProfiles();
    if (profiles.length <= 1) {
      throw StateError('Cannot delete the last profile.');
    }
    await repo.deleteProfile(id);
    // Everything a profile owns in preferences rather than the database — the
    // repository's cascade can't reach any of it, so a key left behind outlives
    // the profile forever, and a new profile that reused the id would inherit a
    // stranger's calendar, cycles, sort order and target dates.
    //
    // One list, in [PrefKeys.ownedBy], rather than a loop over the settings plus
    // three keys named by hand here. Those three were each a comment explaining
    // why they are not in `perProfile` — and three exceptions written at the
    // call site is where the fourth goes missing, which is exactly how `cycles`
    // and nine others were orphaned before the loop existed.
    final prefs = ref.read(appPreferencesProvider);
    for (final key in PrefKeys.ownedBy(id)) {
      await prefs.remove(key);
    }
    if (ref.read(activeProfileProvider) == id) {
      final next = profiles.firstWhere((p) => p.id != id);
      await ref.read(activeProfileProvider.notifier).setProfile(next.id);
    }
    ref.invalidateSelf();
    await future;
  }
}

final profilesProvider =
    AsyncNotifierProvider<ProfilesController, List<Profile>>(
        ProfilesController.new);

// ---------------------------------------------------------------------------
// Catalog + custom nodes
// ---------------------------------------------------------------------------

/// User-defined custom nodes for the active profile.
final customNodesProvider = StreamProvider<List<CatalogNode>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  final profileId = ref.watch(activeProfileProvider);
  return repo.watchCustomNodes(profileId);
});

/// The base catalog merged with the active profile's custom nodes.
final mergedCatalogProvider = Provider<AsyncValue<Catalog>>((ref) {
  final base = ref.watch(catalogProvider);
  final custom = ref.watch(customNodesProvider);
  return base.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (c) => custom.whenData((nodes) {
      // The per-profile override layer: a custom row whose id matches a built-in
      // node *replaces* that node's fields; a new id *adds* a node; `hidden`
      // removes a node (and its subtree). This makes every node editable and
      // deletable without ever mutating the bundled catalog.
      final byId = {for (final n in c.all) n.id: n};
      for (final n in nodes) {
        byId[n.id] = n;
      }
      final hiddenIds = {
        for (final entry in byId.entries)
          if (entry.value.hidden) entry.key
      };
      if (hiddenIds.isEmpty) return Catalog(byId.values.toList());

      // Cascade: hiding a node hides its whole subtree.
      final childIds = <String?, List<String>>{};
      for (final n in byId.values) {
        (childIds[n.parentId] ??= []).add(n.id);
      }
      final removed = <String>{};
      void removeSubtree(String id) {
        if (!removed.add(id)) return;
        for (final child in childIds[id] ?? const <String>[]) {
          removeSubtree(child);
        }
      }
      for (final h in hiddenIds) {
        removeSubtree(h);
      }
      return Catalog(
          [for (final n in byId.values) if (!removed.contains(n.id)) n]);
    }),
  );
});

/// Look up a single node (base or custom) by id.
///
/// Auto-disposed, like the other two families — see [progressNodeProvider] for
/// why. This one is the cheapest of the three to recompute (a map lookup) and
/// the easiest to accumulate: every node reached from a chazara row, a goal
/// row, the unit grid or the node editor mints an element keyed by its id.
final catalogNodeProvider =
    Provider.autoDispose.family<CatalogNode?, String>((ref, id) {
  return ref.watch(mergedCatalogProvider).asData?.value.byId(id);
});

// ---------------------------------------------------------------------------
// Mefarshim (layers) + required-set config
// ---------------------------------------------------------------------------

/// The active profile's user-defined mefarshim.
final customLayersProvider = StreamProvider<List<Layer>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.watchCustomLayers(ref.watch(activeProfileProvider));
});

/// All selectable mefarshim: built-in list + this profile's custom ones.
final allLayersProvider = Provider<List<Layer>>((ref) {
  final custom = ref.watch(customLayersProvider).asData?.value ?? const [];
  return [...builtInLayers, ...custom];
});

/// The active profile's layer settings (node + unit level).
final layerConfigProvider = StreamProvider<List<LayerConfigEntry>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.watchLayerConfigs(ref.watch(activeProfileProvider));
});

/// The one resolver for every layer question: what may be ticked on a unit, what
/// gates its completion, how full its bar is, and where the answer was pinned.
/// Built once from the catalog (for inheritance) + the user's config.
///
/// There were three of these — a required resolver, an identical offered
/// resolver, and a view that reconciled them — over two streams of two tables.
/// A layer's role is one answer, so it is resolved once.
final layerRolesProvider = Provider<LayerRoles>((ref) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final entries = ref.watch(layerConfigProvider).asData?.value ?? const [];

  return LayerRoles.fromEntries(entries, parentOf: parentsOf(catalog));
});

/// Every node's parent, which is all [InheritedLayerRoles] needs of the catalog.
/// Null catalog (still loading) yields an empty map: inheritance then resolves to
/// the default, which is the same answer an unconfigured tree gives.
Map<String, String?> parentsOf(Catalog? catalog) => {
      if (catalog != null)
        for (final n in catalog.all) n.id: n.parentId,
    };

// ---------------------------------------------------------------------------
// Log + derived progress
// ---------------------------------------------------------------------------

/// Constructs + appends events with auto-timestamps.
final loggingServiceProvider = Provider<LoggingService>((ref) => LoggingService(
      repository: ref.watch(progressRepositoryProvider),
      profileId: ref.watch(activeProfileProvider),
    ));

/// Reactive event log for the active profile.
///
/// **Two providers should watch this: [foldProvider] and [logActivityProvider].**
/// Anything else wanting a number out of the log wants one of them — see
/// `log_pass_guard_test.dart` for the three exceptions and why each is its own
/// axis.
final eventsProvider = StreamProvider<List<LearningEvent>>((ref) { // log-pass: ok — the log's own carrier, not a walk of it
  final repo = ref.watch(progressRepositoryProvider);
  final profileId = ref.watch(activeProfileProvider);
  return repo.watchEvents(profileId);
});

/// The folded log for the active profile (which units are done, review counts).
final foldProvider = Provider<AsyncValue<LogFold>>((ref) {
  return ref.watch(eventsProvider).whenData(FoldLog.fold);
});

/// The log indexed by calendar day for the active profile — the *history* half
/// of the derive engine, where [foldProvider] is the *current state* half.
///
/// Everything that used to ask the raw log a question about days — the pace, the
/// streak, the heatmap, the minutes, the "have I recorded anything today" nudge
/// — reads this instead, so the log is walked twice per change rather than nine
/// times plus once per goal. See [LogActivity] for why it is a second index and
/// not more fields on [LogFold].
final logActivityProvider = Provider<AsyncValue<LogActivity>>((ref) {
  return ref.watch(eventsProvider).whenData(LogActivity.of);
});

/// A ready-to-use bulk finish/clear engine, or null while the catalog/log are
/// still loading. Rebuilt whenever the catalog, log, or layer config changes.
final bulkMarkerProvider = Provider<BulkMarker?>((ref) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (catalog == null || fold == null) return null;
  return BulkMarker(
    catalog: catalog,
    fold: fold,
    layers: ref.watch(layerRolesProvider),
    logger: ref.watch(loggingServiceProvider),
  );
});

/// Every bulk action still present in the log, most recent first — the durable
/// undo list. Derived, never stored, so it can't disagree with the log.
final batchHistoryProvider = Provider<List<BulkBatch>>((ref) {
  final events = ref.watch(eventsProvider).asData?.value;
  if (events == null) return const [];
  return BatchHistory.of(events);
});

/// The derived progress forest: merged catalog + folded log, rolled up.
///
/// Reuses [foldProvider] rather than folding the log again, so the (potentially
/// large) log is folded once per change and shared across the forest, per-node,
/// stats, and goal providers instead of being recomputed by each.
final progressForestProvider = Provider<AsyncValue<List<ProgressNode>>>((ref) {
  final catalog = ref.watch(mergedCatalogProvider);
  final fold = ref.watch(foldProvider);
  final layers = ref.watch(layerRolesProvider);
  return catalog.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (c) => fold.whenData((f) => RollUp.buildForest(c, f, layers)),
  );
});

/// Per-meforish totals across the whole catalog (how many units carry each
/// layer as learned), most-learned first.
///
/// Summed off the forest rather than derived from the fold a second time.
/// `RollUp` already counts exactly this per leaf — same walk over the marked
/// units, same clamp to each leaf's valid range — and rolls it up into
/// `ProgressNode.learnedByLayer`, so computing it again was one number with two
/// derivations and nothing pinning them together. Reading the roots also makes
/// the two agree *by construction* on the case where they could differ: a node
/// whose parent id points at nothing is not in the forest, so its marks are not
/// in the headline `learned` — and were, until now, in this table.
final mefarshimStatsProvider = Provider<List<MefarshimStat>>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  if (forest == null) return const [];
  return MefarshimStats.of(forest);
});

/// Every node of the forest by id — built by walking the one forest that
/// [progressForestProvider] already produced.
///
/// Without this, asking for a subtree rebuilt it from the catalog and the fold,
/// so opening a node re-derived progress the forest had just derived, and two
/// screens watching overlapping subtrees paid for the overlap twice.
final progressIndexProvider = Provider<Map<String, ProgressNode>>((ref) {
  final forest = ref.watch(progressForestProvider).asData?.value;
  if (forest == null) return const {};
  final index = <String, ProgressNode>{};
  void walk(ProgressNode n) {
    index[n.id] = n;
    for (final child in n.children) {
      walk(child);
    }
  }

  for (final root in forest) {
    walk(root);
  }
  return index;
});

/// The progress subtree rooted at [id] (null while loading or if not found).
///
/// **Auto-disposed, which is the point of the family and not a detail.** A
/// Riverpod family keeps one element per argument alive for the life of the
/// container unless told otherwise, so every node a user opened this session
/// stayed subscribed to [progressIndexProvider] and re-ran on every mark — for
/// a screen that had been closed an hour ago. Ten mesechtos browsed meant ten
/// live elements re-deriving per tap, and nothing ever brought that number
/// down. Recomputing one of these is a single map lookup; keeping it was the
/// expensive option.
///
/// [ProgressNode] has value equality, so an element that survives (because its
/// screen is still open) still only notifies when its own subtree moved.
final progressNodeProvider = Provider.autoDispose.family<ProgressNode?, String>(
    (ref, id) => ref.watch(progressIndexProvider)[id]);
