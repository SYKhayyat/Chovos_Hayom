import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/layer.dart';

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
  /// UUID — so two events one second apart in storage were ordered by a coin
  /// flip on random text. Mark a daf and un-mark it inside the same second and
  /// the `undone` won only if its UUID happened to sort later; otherwise the
  /// daf stayed learned, permanently, because the fold re-derives from the log
  /// every time. This was invisible for as long as the tests ran against an
  /// in-memory double that kept `DateTime` objects in a Dart list at full
  /// precision.
  IntColumn get loggedAt => integer().map(const _MicrosecondsSinceEpoch())();
  IntColumn get durationMin => integer().nullable()();

  /// A **haara** — the single free-text field on an event: an insight on the daf,
  /// a question, how the seder went, whatever you want to keep. Every non-empty
  /// one shows up in the Notes Journal. (Until v8 this was split into `note` and
  /// a separate `haara`; the v7 -> v8 migration folds the two together here.)
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
/// This replaces the `required_layer_configs` / `offered_layer_configs` pair,
/// which stored one tri-state as two membership tables and so admitted a fourth
/// state — required-but-not-offered — that meant nothing, plus a whole class of
/// half-written config where a node was pinned in one table and inherited in the
/// other. One row now carries the whole answer for a scope.
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
/// Named rather than inlined so the migration tests can assert "it upgraded all
/// the way" against the app's own number. They each typed `11`, at four sites,
/// and the next bump failed all four with *expected 11, got 12* — a true
/// statement about the test and nothing at all about the migration.
const kSchemaVersion = 13;

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

  /// Every schema change must extend [MigrationStrategy.onUpgrade]. Without this,
  /// bumping [schemaVersion] silently does nothing on existing installs and
  /// derails into `no such column` crashes or data loss.
  ///
  /// Each step is written to be **idempotent**: it inspects the live schema and
  /// skips work that is already there. A migration is not guaranteed to be
  /// atomic — `alterTable` in particular has to run with foreign keys off and
  /// commits as it goes — so a run that dies partway leaves the column added but
  /// `user_version` un-bumped, and the next launch replays the same steps. Under
  /// a plain `addColumn` that replay throws `duplicate column name: ...` and the
  /// app can never open again. Guarding every step makes the replay a no-op and
  /// lets the database finish upgrading.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: CustomNodes primary key changed {id} -> {profileId, id}.
          // TableMigration recreates the physical table, preserving existing
          // rows, so no custom sefarim are lost. Note this recreates it from the
          // *current* Dart definition, so it also brings along every column
          // added in v5/v6 — hence those steps must check before adding.
          if (from < 2 && !await _isPartOfPrimaryKey('custom_nodes', 'profile_id')) {
            await m.alterTable(TableMigration(customNodes));
          }
          // v2 -> v3: add the `haara` note column. Superseded by v8, which merges
          // it back into `note` — so on a database old enough to need both steps,
          // v3 adds the column purely so v8 has something to read and drop. The
          // raw SQL is deliberate: `learningEvents.haara` no longer exists in the
          // Dart schema, so there is no generated column to hand to addColumn.
          if (from < 3) {
            await _addRawColumnIfMissing('learning_events', 'haara',
                'ALTER TABLE learning_events ADD COLUMN haara TEXT NULL');
          }
          // v3 -> v4: per-layer (mefarshim) support — an additive column plus
          // two new config tables. No existing row is touched; a null layersJson
          // reads as the text-only default, so all prior progress is preserved.
          //
          // It also created `required_layer_configs`, and v7 created
          // `offered_layer_configs`. Both are gone at v12, which merges them
          // into `layer_configs` — and a database this old has neither table nor
          // any row that could go in one, so creating them here purely for v12
          // to drop was ceremony. v12 checks whether each table is actually
          // there, which is the only thing that made this step load-bearing.
          if (from < 4) {
            await _addColumnIfMissing(m, learningEvents, learningEvents.layersJson);
            await _createTableIfMissing(m, customLayers);
          }
          // v4 -> v5: the per-profile catalog override layer (edit/hide any node).
          if (from < 5) {
            await _addColumnIfMissing(m, customNodes, customNodes.hidden);
          }
          // v5 -> v6: optional named units.
          if (from < 6) {
            await _addColumnIfMissing(m, customNodes, customNodes.unitNamesJson);
          }
          // v6 -> v7 created `offered_layer_configs`. Deleted with the v4 line
          // above and for the same reason: v12 merges that table away, and a
          // database old enough to reach this step has nothing to merge.
          // v8 -> v9: tag bulk-written events with the batch that wrote them, so
          // "finish all" stays undoable durably instead of only for as long as a
          // snackbar lives. Additive and null for every existing row: events
          // written before this simply have no batch to undo.
          //
          // Out of version order on purpose. `alterTable` below rebuilds
          // learning_events from the *current* Dart definition and copies the
          // rows column-by-column — including this one. If the physical table
          // did not have `batch_id` by then, that copy would fail with
          // `no such column: batch_id` and no v7 database could ever upgrade.
          // The rule this follows: **additive columns run before any rebuild of
          // the same table.** Every future step must keep it.
          if (from < 9) {
            await _addColumnIfMissing(m, learningEvents, learningEvents.batchId);
          }
          // v7 -> v8: collapse the two note fields into one. The learning-note /
          // haara split asked the user to classify a thought before writing it;
          // now there is a single haara you can use however you like.
          //
          // Merge first, drop second — and never lose a word. A row with both
          // keeps both, joined by a blank line (learning-note first, the order
          // they were shown in), matching LearningEvent.mergeNotes so a database
          // upgrade and a legacy backup import land on identical text.
          if (from < 8 &&
              (await _columnsOf('learning_events')).contains('haara')) {
            await customStatement('''
              UPDATE learning_events SET note = CASE
                WHEN note IS NULL OR trim(note) = '' THEN trim(haara)
                ELSE trim(note) || char(10) || char(10) || trim(haara)
              END
              WHERE haara IS NOT NULL AND trim(haara) <> ''
            ''');
            // Recreates the table from the current Dart definition, which no
            // longer has `haara` — every surviving column is copied across.
            await m.alterTable(TableMigration(learningEvents));
          }
          // v9 -> v10: drop `profiles.settings_json`. It was written on create
          // and never read once — the shape of a per-profile settings store that
          // was never built. Settings are now per-profile in preferences (where
          // the theme can be read before the first frame), so the column is dead
          // weight and goes rather than lingering as a false affordance.
          if (from < 10 &&
              (await _columnsOf('profiles')).contains('settings_json')) {
            await m.alterTable(TableMigration(profiles));
          }
          // v10 -> v11: learning_events primary key {id} -> {profileId, id}, the
          // same change custom_nodes got at v2 and for the same reason — see the
          // comment on the table. Rebuilds the physical table from the current
          // Dart definition, preserving every row, so no learning is lost.
          //
          // Guarded on the live schema rather than on `from` alone, because a run
          // that dies after the rebuild but before user_version is bumped would
          // otherwise replay it. Last, per the additive-before-rebuild rule: the
          // rebuild copies the columns the Dart definition has, so batch_id must
          // already exist on the physical table by now (it does — v9, above).
          //
          // The table-exists check is not ceremony: `_isPartOfPrimaryKey`
          // answers false both for "the key lacks this column" and for "there is
          // no such table", and rebuilding a table that isn't there throws
          // during `beforeOpen` — which is the one failure the user cannot get
          // out of. Every step below the rebuild has to be as suspicious.
          final hasEvents = await _tableExists('learning_events');
          if (from < 11 &&
              hasEvents &&
              !await _isPartOfPrimaryKey('learning_events', 'profile_id')) {
            await m.alterTable(TableMigration(learningEvents));
          }
          // The batch index goes last, and unconditionally: every rebuild of
          // learning_events (v8's, and v11's above) drops the table and takes
          // its indexes with it, so an index created earlier in this same run
          // would silently vanish. Idempotent, so it is a no-op when the index
          // survived — which is the common case.
          if (hasEvents) {
            await _createIndexIfMissing('learning_events_batch',
                'CREATE INDEX learning_events_batch '
                    'ON learning_events (profile_id, batch_id)');
          }
          // v11 -> v12: collapse `required_layer_configs` + `offered_layer_configs`
          // into one `layer_configs` holding a role per layer. Two membership
          // tables were storing one tri-state, which made a fourth state
          // (required-but-not-offered) representable and left every reader to
          // re-unite them by hand.
          //
          // Placed after the index rather than in version order because it
          // touches neither learning_events nor any table above it — the
          // additive-before-rebuild rule is about one table's own history, and
          // this shares none with them. It creates a table and drops two; it
          // never rebuilds one, so nothing below it can be invalidated either.
          if (from < 12) await _mergeLayerConfigs(m);
          // v12 -> v13: `logged_at` moves from whole seconds to microseconds.
          //
          // A pure value rewrite — the column stays an integer, so there is no
          // table to rebuild and nothing above this can be invalidated by it.
          //
          // Idempotent by inspecting the values rather than by `from`, like
          // every other step: a run that dies after this UPDATE but before
          // `user_version` is bumped would otherwise multiply by a million
          // twice and land every event in the year 58692. Seconds since the
          // epoch stay below 1e11 until the year 5138 and microseconds passed
          // it in 1973, so the threshold separates the two cleanly and the
          // replay is a no-op. Rows already converted are left alone, which
          // also means a half-finished run finishes correctly rather than
          // needing to start over.
          //
          // Guarded on `hasEvents` for the reason the v11 step spells out: a
          // database that has never had the table is not a database this may
          // throw on.
          if (from < 13 && hasEvents) {
            await customStatement('UPDATE learning_events '
                'SET logged_at = logged_at * 1000000 '
                'WHERE logged_at < 100000000000');
          }
        },
      );

  /// Merges the two legacy layer tables into [layerConfigs] and drops them.
  ///
  /// The merge rule is the one the app already applied at *read* time —
  /// `checkable = offered ∪ required`, with required winning — so a tree that
  /// was complete before the upgrade is complete after it. Anything present in
  /// only the offered table becomes [LayerRole.optional]; everything required
  /// stays required.
  ///
  /// Idempotent like every other step: it is guarded on the legacy tables still
  /// existing, and writes with `INSERT OR REPLACE`, so a run that dies partway
  /// and replays lands on the same rows. Reading and re-encoding in Dart rather
  /// than in SQL is deliberate — the JSON1 extension is not guaranteed to be
  /// compiled into the SQLite this ships against, and a migration is the worst
  /// possible place to discover that.
  Future<void> _mergeLayerConfigs(Migrator m) async {
    await _createTableIfMissing(m, layerConfigs);
    final hasRequired = await _tableExists('required_layer_configs');
    final hasOffered = await _tableExists('offered_layer_configs');
    if (!hasRequired && !hasOffered) return;

    // (profileId, nodeId, unitIndex) -> layer id -> role.
    final merged = <(String, String, int), Map<String, LayerRole>>{};
    Future<void> collect(String table, LayerRole role) async {
      final rows = await customSelect(
              'SELECT profile_id, node_id, unit_index, layers_json FROM $table')
          .get();
      for (final r in rows) {
        final key = (
          r.read<String>('profile_id'),
          r.read<String>('node_id'),
          r.read<int>('unit_index'),
        );
        final roles = merged[key] ??= {};
        for (final id in jsonDecode(r.read<String>('layers_json')) as List) {
          // Required wins: it is read second, so it overwrites an optional
          // entry the offered table put here, never the other way round.
          roles['$id'] = role;
        }
      }
    }

    if (hasOffered) await collect('offered_layer_configs', LayerRole.optional);
    if (hasRequired) await collect('required_layer_configs', LayerRole.required);

    for (final e in merged.entries) {
      if (e.value.isEmpty) continue;
      final (profileId, nodeId, unitIndex) = e.key;
      await customStatement(
        'INSERT OR REPLACE INTO layer_configs '
        '(profile_id, node_id, unit_index, roles_json) VALUES (?, ?, ?, ?)',
        [
          profileId,
          nodeId,
          unitIndex,
          jsonEncode({for (final r in e.value.entries) r.key: r.value.name}),
        ],
      );
    }

    if (hasRequired) {
      await customStatement('DROP TABLE required_layer_configs');
    }
    if (hasOffered) {
      await customStatement('DROP TABLE offered_layer_configs');
    }
  }

  /// Column names currently on [table], straight from SQLite.
  Future<Set<String>> _columnsOf(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?1",
      variables: [Variable<String>(table)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _isPartOfPrimaryKey(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    for (final r in rows) {
      if (r.read<String>('name') == column) return r.read<int>('pk') > 0;
    }
    return false;
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn column,
  ) async {
    final existing = await _columnsOf(table.actualTableName);
    if (!existing.contains(column.name)) {
      await m.addColumn(table, column);
    }
  }

  /// Adds a column that no longer exists in the Dart schema (so [Migrator] can't
  /// build the statement itself), skipping it if the table already has it.
  Future<void> _addRawColumnIfMissing(
    String table,
    String column,
    String sql,
  ) async {
    final existing = await _columnsOf(table);
    if (!existing.contains(column)) await customStatement(sql);
  }

  Future<void> _createTableIfMissing(
      Migrator m, TableInfo<Table, dynamic> table) async {
    if (!await _tableExists(table.actualTableName)) {
      await m.createTable(table);
    }
  }

  /// Same replay-safety as the column helpers: a migration that died after
  /// creating the index must not throw `index ... already exists` on the retry.
  Future<void> _createIndexIfMissing(String name, String sql) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?1",
      variables: [Variable<String>(name)],
    ).get();
    if (rows.isEmpty) await customStatement(sql);
  }
}
