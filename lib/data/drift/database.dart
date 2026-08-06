import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/enums.dart';

part 'database.g.dart';

/// A `DateTime` stored at full precision, as microseconds since the epoch.
///
/// Drift's own `DateTimeColumn` stores whole seconds. That is fine for a date
/// the user picked and wrong for anything the app orders by; see
/// [LearningEvents.loggedAt]. Always UTC-agnostic in the same way drift's is —
/// the epoch value carries the instant, and the local/UTC flag is not stored,
/// so it reads back local exactly as it went in.
class _MicrosecondsSinceEpoch extends TypeConverter<DateTime, int> {
  const _MicrosecondsSinceEpoch();

  @override
  DateTime fromSql(int fromDb) => DateTime.fromMicrosecondsSinceEpoch(fromDb);

  @override
  int toSql(DateTime value) => value.microsecondsSinceEpoch;
}

/// Local user profiles. All progress is scoped by [Profiles.id].
@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The append-only event log — the single source of truth.
@DataClassName('LearningEventRow')
@TableIndex(name: 'learning_events_batch', columns: {#profileId, #batchId})
class LearningEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();
  IntColumn get unitIndex => integer()();
  IntColumn get action => intEnum<EventAction>()();
  DateTimeColumn get occurredAt => dateTime()();

  /// When this event was appended — the log's **order**, and the only column
  /// whose sub-second part is load-bearing.
  ///
  /// Stored as microseconds rather than through drift's `DateTimeColumn`, which
  /// writes `millisecondsSinceEpoch ~/ 1000` and so discards everything below a
  /// second. `FoldLog` sorts by this and breaks ties on the event id — a v4
  /// UUID — so two events that landed in the same stored second were ordered by
  /// a coin flip on random text. Mark a daf and un-mark it in one go and
  /// the `undone` won only if its UUID happened to sort later; otherwise the
  /// daf stayed learned, permanently, because the fold re-derives from the log
  /// every time. This was invisible for as long as the tests ran against an
  /// in-memory double that kept `DateTime` objects in a Dart list at full
  /// precision.
  IntColumn get loggedAt => integer().map(const _MicrosecondsSinceEpoch())();
  IntColumn get durationMin => integer().nullable()();

  /// A **haara** — the single free-text field on an event: an insight on the daf,
  /// a question, how the seder went, whatever you want to keep. Every non-empty
  /// one shows up in the Notes Journal. (This was once split into `note` and a
  /// separate `haara`, which asked the user to classify a thought before writing
  /// it. Backup files old enough to carry both are still read: see
  /// `LearningEvent.mergeNotes`, which folds the pair into this column.)
  TextColumn get note => text().nullable()();

  /// JSON list of layer ids this event marks/unmarks (the text and/or mefarshim).
  /// Null is read as `["main"]` — the primary text — matching pre-layers events.
  TextColumn get layersJson => text().nullable()();

  /// Groups the events written by one bulk action, so it stays undoable long
  /// after the snackbar is gone. Null on ordinary single marks. Indexed, since
  /// the undo list groups the whole log by it.
  TextColumn get batchId => text().nullable()();

  // Events are profile-scoped, exactly like custom_nodes below: the same backup
  // imported into two profiles carries the same event ids into both, so a
  // profile-blind key makes the second import throw a uniqueness violation
  // (SqliteException 1555) and the whole feature unusable. That reasoning was
  // written on `CustomNodes` and never generalised — this table was the one of
  // six that omitted profileId.
  //
  // The consequence for every reader: an event id is only unique *within* a
  // profile, so no query may find an event by id alone. See
  // [ProgressRepository.removeEvents] and its siblings, which all take the
  // profile they act in.
  @override
  Set<Column> get primaryKey => {profileId, id};
}

/// User-defined mefarshim (learning layers), on top of the built-in list. Custom
/// so the user is never limited to a fixed set of commentaries.
@DataClassName('CustomLayerRow')
class CustomLayers extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get name => text()();
  TextColumn get nameHebrew => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {profileId, id};
}

/// What each layer *is* at a node (unitIndex = -1) or on a single unit — the
/// user's mefarshim answer for that scope. Sparse and inherited (see
/// `LayerRoles`); absence anywhere means "just the text, required".
///
/// One row carries the whole answer for a scope. It replaced a pair of
/// membership tables — *required* and *offered* — that stored one tri-state as
/// two sets, and so admitted a fourth state (required-but-not-offered) that
/// meant nothing, plus a whole class of half-written config where a node was
/// pinned in one table and inherited in the other. Backup files written before
/// that still carry the two arrays and are read back into roles; the tables
/// themselves are gone, along with the migration that merged them.
@DataClassName('LayerConfigRow')
class LayerConfigs extends Table {
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();

  /// -1 = the node-level default (applies to all its units); >= 0 = a per-unit
  /// override for that unit index.
  IntColumn get unitIndex => integer().withDefault(const Constant(-1))();

  /// JSON object of layer id -> role name ("optional" | "required").
  TextColumn get rolesJson => text()();

  @override
  Set<Column> get primaryKey => {profileId, nodeId, unitIndex};
}

/// User-defined sefarim/categories. Same shape as a catalog node, but editable
/// and profile-scoped; the user supplies the unit counts.
@DataClassName('CustomNodeRow')
class CustomNodes extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameHebrew => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get kind => intEnum<NodeKind>()();
  IntColumn get unitLabel => intEnum<UnitLabel>().nullable()();
  IntColumn get unitCount => integer().withDefault(const Constant(0))();
  IntColumn get unitOffset => integer().withDefault(const Constant(0))();

  /// When a row's id matches a built-in node it *overrides* that node's fields;
  /// [hidden] true means the node (built-in or custom) is removed from the tree.
  /// This is the per-profile override layer that makes every node editable.
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Optional JSON list of real unit names (parsha/siman titles), in unit order.
  TextColumn get unitNamesJson => text().nullable()();

  // Custom nodes are profile-scoped: two profiles may hold nodes with the same
  // id (e.g. the same backup imported into both). The primary key must include
  // profileId, or the second import throws a uniqueness violation.
  @override
  Set<Column> get primaryKey => {profileId, id};
}

/// The schema version this build expects.
///
/// **One** — and this database has had thirteen shapes. It is one because none
/// of those shapes ever shipped: the only tag in the repository predates the
/// Flutter rewrite entirely, and every install that has ever existed is a
/// machine the author was sitting at. A twelve-step migration chain whose whole
/// job is to carry one phone from Tuesday's schema to Wednesday's is not
/// insurance, it is a second copy of the schema written in reverse — and it had
/// started eating itself. v3 added a `haara` column so that v8 could merge it
/// away and drop it, which means on a v2 database v3 existed only to give v8
/// something to read. v9 had to be *written before v8* so that v8's table
/// rebuild had a `batch_id` column to copy. v4 and v7 created two tables that
/// v12 merged into one. Every step needed its own idempotency guard, because
/// `alterTable` runs with foreign keys off and commits as it goes, so a run
/// that died halfway left the column added and `user_version` un-bumped and the
/// replay had to be a no-op rather than `duplicate column name`.
///
/// That was 230 lines of migration and 649 of test defending two databases,
/// and the price was still rising: schema v13 — a one-line value rewrite that
/// fixed a real defect — arrived with three migration tests of its own that a
/// squash would have carried for free.
///
/// So the chain is gone. `onCreate` builds the current shape directly and the
/// history is in git, where a history belongs. This becomes 2 the first time
/// the schema changes *after* v1 ships, and that step will be the first one in
/// this project's life that defends somebody else's data.
const kSchemaVersion = 1;

/// The last shape written before the squash — the one database version other
/// than [kSchemaVersion] this build will open.
///
/// v13 was the head of the deleted chain, so its physical schema is exactly
/// what `createAll()` now produces: the same five tables, the same columns, the
/// same `learning_events_batch` index. Adopting one is therefore *nothing* —
/// the clause in [AppDatabase.migration] returns, drift stamps `user_version`
/// to 1, and the file carries on. It is the reason upgrading to this build
/// costs an existing install no round trip through a backup file.
///
/// Delete it once every install has opened a post-squash build. It exists so
/// that the squash is free for a database that is already at head, not so the
/// chain can start growing again from the other end.
const kPreSquashSchemaVersion = 13;

/// The database on disk is a shape this build has no path to.
///
/// Thrown rather than muddled through, because the alternative is opening a
/// database whose physical columns do not match the Dart definition and finding
/// out one query at a time — a v12 file, for instance, still keeps `logged_at`
/// in whole seconds, so every event in it would read back as an instant in
/// 1970 and the log would silently reorder itself. Refusing leaves the file
/// untouched: drift only stamps `user_version` *after* the migration callback
/// returns, so a database rejected here can still be opened by the build that
/// wrote it.
///
/// The message *is* the recovery, because it is the one the user reads:
/// `databaseProvider` throwing surfaces through `ErrorView`, which shows the
/// exception's text under *Show details* and appends it to the crash log.
class SchemaMismatchException implements Exception {
  const SchemaMismatchException(this.onDisk, this.expected);

  /// `user_version` as found on disk.
  final int onDisk;

  /// What this build creates — [kSchemaVersion].
  final int expected;

  @override
  String toString() => onDisk > expected
      ? 'This database was written by a build from before the schema squash '
          '(schema v$onDisk); this build creates v$expected and no longer '
          'carries the migrations between them. Open it once with a build at '
          'schema v$kPreSquashSchemaVersion (the last one before the squash) '
          'and then this one, or restore a backup into a fresh install.'
      : 'schemaVersion was raised to v$expected without a migration step for a '
          'v$onDisk database. Add one to AppDatabase.migration — a bump on its '
          'own changes nothing but the number.';
}

@DriftDatabase(tables: [
  Profiles,
  LearningEvents,
  CustomNodes,
  CustomLayers,
  LayerConfigs
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (Android/desktop) via drift_flutter.
  AppDatabase.open() : super(driftDatabase(name: 'chovos_hayom'));

  @override
  int get schemaVersion => kSchemaVersion;

  /// There is no migration chain any more — see [kSchemaVersion] for why the
  /// twelve steps that used to be here are in git rather than in this file.
  ///
  /// What is left is a doorman. `onUpgrade` runs whenever the version on disk
  /// differs from this build's, in *either* direction (drift's `hadUpgrade` is
  /// `versionBefore != versionNow`), and there are exactly two ways to get
  /// here:
  ///
  /// - **A database at [kPreSquashSchemaVersion].** Same tables, same columns,
  ///   same index — v13 is the shape `createAll` now produces. Nothing to do;
  ///   returning lets drift stamp `user_version` to 1.
  /// - **Anything else.** Either an older pre-squash database, whose shape this
  ///   build cannot produce and must not guess at, or a [schemaVersion] raised
  ///   without a step to go with it. Both throw, and the second one is the
  ///   reason this method still exists rather than being left at drift's
  ///   default: the next schema change in this project's life has to fail
  ///   loudly here instead of silently doing nothing on an existing install.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == kPreSquashSchemaVersion && to == kSchemaVersion) return;
          throw SchemaMismatchException(from, to);
        },
      );
}
