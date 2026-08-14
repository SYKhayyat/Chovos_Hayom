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

/// What each layer *is* at a node — the user's mefarshim answer for it. Sparse
/// and inherited (see `LayerRoles`); absence anywhere means "just the text,
/// required".
///
/// One row carries the whole answer for a node. It replaced a pair of
/// membership tables — *required* and *offered* — that stored one tri-state as
/// two sets, and so admitted a fourth state (required-but-not-offered) that
/// meant nothing, plus a whole class of half-written config where a node was
/// pinned in one table and inherited in the other. Backup files written before
/// that still carry the two arrays and are read back into roles; the tables
/// themselves are gone, along with the migration that merged them.
///
/// It carried a third key column, `unit_index`, for pinning a setting on a
/// single unit rather than a node. `-1` — the node-level sentinel — was the only
/// value ever written to it, because the config sheet is the only writer and it
/// opens from a node. See `LayerConfigEntry` for why that is a dead dimension
/// rather than an unfinished feature, and v2 in [AppDatabase.migration] for what
/// happened to it.
@DataClassName('LayerConfigRow')
class LayerConfigs extends Table {
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();

  /// JSON object of layer id -> role name ("optional" | "required").
  TextColumn get rolesJson => text()();

  @override
  Set<Column> get primaryKey => {profileId, nodeId};
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
/// history is in git, where a history belongs.
///
/// **Two**, then, and the second step is a real one: v2 drops `unit_index` from
/// `layer_configs`. It is the first migration in this project's life written for
/// a database somebody might mind losing rather than to carry a schema from
/// Tuesday to Wednesday, which is the distinction the squash was about — and the
/// point at which the squash stops being free is exactly the point at which
/// steps start being worth writing.
///
/// The clause that adopted a pre-squash (v13) database is **gone** with it. It
/// existed so the squash cost an existing install no round trip through a backup
/// file, and its own doc comment said to delete it once every install had opened
/// a post-squash build. A v13 file now meets [SchemaMismatchException] like any
/// other shape this build has no path to, and the message says what to do.
const kSchemaVersion = 2;

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
          'carries the migrations between them. Export a backup from the build '
          'that wrote it — it can still open this file, which is untouched — '
          'and restore that backup into a fresh install.'
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

  /// One step and a doorman — see [kSchemaVersion] for why the twelve steps that
  /// used to be here are in git rather than in this file.
  ///
  /// `onUpgrade` runs whenever the version on disk differs from this build's, in
  /// *either* direction (drift's `hadUpgrade` is `versionBefore != versionNow`),
  /// and there are exactly two ways to get here:
  ///
  /// - **A database at v1**, the shape the squash produced. [_dropUnitIndex]
  ///   rebuilds `layer_configs` without its dead third key column.
  /// - **Anything else.** Either a pre-squash database, whose shape this build
  ///   cannot produce and must not guess at, or a [schemaVersion] raised without
  ///   a step to go with it. Both throw, and the second one is the reason the
  ///   `else` exists rather than a silent return: a bump on its own used to
  ///   change nothing on an existing install and derail into `no such column`
  ///   several screens later.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from == 1 && to == 2) return _dropUnitIndex(m);
          throw SchemaMismatchException(from, to);
        },
      );

  /// v1 -> v2: `layer_configs` loses `unit_index`, and its primary key with it.
  ///
  /// Rows with a real unit scope are **deleted rather than folded into their
  /// node**. No such row can have been written by the app — the config sheet
  /// opens from a node and always wrote -1 — so the only way to hold one is a
  /// hand-edited backup, and for that file, promoting a single unit's setting to
  /// cover a whole mesechta would be a louder change than dropping it. They are
  /// also what makes the delete necessary rather than tidy: two rows for one
  /// (profile, node) do not fit the new primary key, so copying both is not an
  /// option the table leaves open.
  ///
  /// The column check is what makes a replay safe. `alterTable` rebuilds and
  /// commits as it goes, so a run that dies between the rebuild and drift
  /// stamping `user_version` leaves a v2-shaped table in a file still marked v1;
  /// without this, the retry would fail on `no such column: unit_index` and the
  /// install would be stuck at the door for good. That failure mode cost this
  /// project a guard on every one of the twelve deleted steps; it is cheaper to
  /// keep the lesson than to relearn it.
  Future<void> _dropUnitIndex(Migrator m) async {
    final columns =
        await customSelect("SELECT name FROM pragma_table_info('layer_configs')")
            .get();
    if (!columns.any((r) => r.read<String>('name') == 'unit_index')) return;

    await customStatement('DELETE FROM layer_configs WHERE unit_index >= 0');
    await m.alterTable(TableMigration(layerConfigs));
  }
}
