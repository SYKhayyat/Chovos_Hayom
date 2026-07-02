import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/json_catalog_repository.dart';
import '../data/drift/database.dart';
import '../data/repositories/drift_progress_repository.dart';
import '../domain/entities/catalog.dart';
import '../domain/entities/learning_event.dart';
import '../domain/entities/progress_node.dart';
import '../domain/repositories/catalog_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/usecases/fold_log.dart';
import '../domain/usecases/roll_up.dart';
import 'logging_service.dart';

/// The Drift database (app-wide singleton).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// Pluggable catalog source (bundled JSON for now).
final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => JsonCatalogRepository());

/// The loaded, indexed catalog.
final catalogProvider =
    FutureProvider<Catalog>((ref) => ref.watch(catalogRepositoryProvider).load());

/// Event-log persistence, Drift-backed.
final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => DriftProgressRepository(ref.watch(databaseProvider)));

/// The active local profile. Phase 3 will make this switchable via UI.
final activeProfileProvider = Provider<String>((ref) => 'default');

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

/// The derived progress forest: catalog + folded log, rolled up. Rebuilds
/// automatically whenever an event is appended.
final progressForestProvider =
    Provider<AsyncValue<List<ProgressNode>>>((ref) {
  final catalog = ref.watch(catalogProvider);
  final events = ref.watch(eventsProvider);
  return catalog.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (c) => events.whenData((e) => RollUp.buildForest(c, FoldLog.fold(e))),
  );
});

/// Look up a single catalog node by id (null while the catalog is loading).
final catalogNodeProvider = Provider.family<CatalogNode?, String>((ref, id) {
  return ref.watch(catalogProvider).asData?.value.byId(id);
});
