import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/preferences.dart';
import '../data/catalog/json_catalog_repository.dart';
import '../data/drift/database.dart';
import '../data/repositories/drift_progress_repository.dart';
import '../domain/entities/catalog.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/entities/learning_event.dart';
import '../domain/entities/profile.dart';
import '../domain/entities/progress_node.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/usecases/fold_log.dart';
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
    data: (c) => custom.whenData((nodes) => Catalog([...c.all, ...nodes])),
  );
});

/// Look up a single node (base or custom) by id.
final catalogNodeProvider = Provider.family<CatalogNode?, String>((ref, id) {
  return ref.watch(mergedCatalogProvider).asData?.value.byId(id);
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
final progressForestProvider = Provider<AsyncValue<List<ProgressNode>>>((ref) {
  final catalog = ref.watch(mergedCatalogProvider);
  final events = ref.watch(eventsProvider);
  return catalog.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (c) => events.whenData((e) => RollUp.buildForest(c, FoldLog.fold(e))),
  );
});

/// The progress subtree rooted at [id] (null while loading or if not found).
final progressNodeProvider = Provider.family<ProgressNode?, String>((ref, id) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final events = ref.watch(eventsProvider).asData?.value;
  if (catalog == null || events == null) return null;
  return RollUp.buildNode(catalog, id, FoldLog.fold(events));
});
