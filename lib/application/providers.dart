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
import '../domain/usecases/fold_log.dart';
import '../domain/usecases/layer_requirements.dart';
import '../domain/usecases/roll_up.dart';
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
final catalogNodeProvider = Provider.family<CatalogNode?, String>((ref, id) {
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

/// The active profile's required-layer settings (node + unit level).
final layerConfigProvider = StreamProvider<List<LayerRequirementEntry>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.watchLayerRequirements(ref.watch(activeProfileProvider));
});

/// The resolver that answers "which layers must this unit have to be complete?"
/// Built once from the catalog (for inheritance) + the user's config.
final layerRequirementsProvider = Provider<LayerRequirements>((ref) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final entries = ref.watch(layerConfigProvider).asData?.value ?? const [];

  final parentOf = <String, String?>{};
  if (catalog != null) {
    for (final n in catalog.all) {
      parentOf[n.id] = n.parentId;
    }
  }
  final nodeConfig = <String, Set<String>>{};
  final unitConfig = <String, Map<int, Set<String>>>{};
  for (final e in entries) {
    if (e.isNodeLevel) {
      nodeConfig[e.nodeId] = e.layers;
    } else {
      (unitConfig[e.nodeId] ??= {})[e.unitIndex] = e.layers;
    }
  }
  return LayerRequirements(
      nodeConfig: nodeConfig, unitConfig: unitConfig, parentOf: parentOf);
});

// ---------------------------------------------------------------------------
// Log + derived progress
// ---------------------------------------------------------------------------

/// Constructs + appends events with auto-timestamps.
final loggingServiceProvider = Provider<LoggingService>((ref) => LoggingService(
      repository: ref.watch(progressRepositoryProvider),
      profileId: ref.watch(activeProfileProvider),
    ));

/// Reactive event log for the active profile.
final eventsProvider = StreamProvider<List<LearningEvent>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  final profileId = ref.watch(activeProfileProvider);
  return repo.watchEvents(profileId);
});

/// The folded log for the active profile (which units are done, review counts).
final foldProvider = Provider<AsyncValue<LogFold>>((ref) {
  return ref.watch(eventsProvider).whenData(FoldLog.fold);
});

/// The derived progress forest: merged catalog + folded log, rolled up.
///
/// Reuses [foldProvider] rather than folding the log again, so the (potentially
/// large) log is folded once per change and shared across the forest, per-node,
/// stats, and goal providers instead of being recomputed by each.
final progressForestProvider = Provider<AsyncValue<List<ProgressNode>>>((ref) {
  final catalog = ref.watch(mergedCatalogProvider);
  final fold = ref.watch(foldProvider);
  final required = ref.watch(layerRequirementsProvider);
  return catalog.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (c) => fold.whenData((f) => RollUp.buildForest(c, f, required)),
  );
});

/// The progress subtree rooted at [id] (null while loading or if not found).
final progressNodeProvider = Provider.family<ProgressNode?, String>((ref, id) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (catalog == null || fold == null) return null;
  return RollUp.buildNode(catalog, id, fold, ref.watch(layerRequirementsProvider));
});
