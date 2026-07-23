import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/entities/enums.dart';

part 'database.g.dart';

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
  DateTimeColumn get loggedAt => dateTime()();
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

  @override
  Set<Column> get primaryKey => {id};
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

/// Which layers are *required* for completion, pinned at a node (unitIndex = -1)
/// or overridden for a single unit. Sparse and inherited (see LayerRequirements);
/// absence anywhere means "just the text".
@DataClassName('LayerRequirementRow')
class RequiredLayerConfigs extends Table {
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();

  /// -1 = the node-level default (applies to all its units); >= 0 = a per-unit
  /// override for that unit index.
  IntColumn get unitIndex => integer().withDefault(const Constant(-1))();

  /// JSON list of required layer ids.
  TextColumn get layersJson => text()();

  @override
  Set<Column> get primaryKey => {profileId, nodeId, unitIndex};
}

/// Which layers are *offered* (checkable) on a unit, pinned at a node
/// (unitIndex = -1) or overridden for a single unit. Same sparse+inherited shape
/// as [RequiredLayerConfigs], but these do **not** gate completion — they only
/// decide which mefarshim you may tick. Absence anywhere means "just the text".
@DataClassName('OfferedLayerRow')
class OfferedLayerConfigs extends Table {
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();

  /// -1 = the node-level default (applies to all its units); >= 0 = a per-unit
  /// override for that unit index.
  IntColumn get unitIndex => integer().withDefault(const Constant(-1))();

  /// JSON list of offered layer ids.
  TextColumn get layersJson => text()();

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

@DriftDatabase(tables: [
  Profiles,
  LearningEvents,
  CustomNodes,
  CustomLayers,
  RequiredLayerConfigs,
  OfferedLayerConfigs
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (Android/desktop) via drift_flutter.
  AppDatabase.open() : super(driftDatabase(name: 'chovos_hayom'));

  @override
  int get schemaVersion => 10;

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
          if (from < 4) {
            await _addColumnIfMissing(m, learningEvents, learningEvents.layersJson);
            await _createTableIfMissing(m, customLayers);
            await _createTableIfMissing(m, requiredLayerConfigs);
          }
          // v4 -> v5: the per-profile catalog override layer (edit/hide any node).
          if (from < 5) {
            await _addColumnIfMissing(m, customNodes, customNodes.hidden);
          }
          // v5 -> v6: optional named units.
          if (from < 6) {
            await _addColumnIfMissing(m, customNodes, customNodes.unitNamesJson);
          }
          // v6 -> v7: offered (checkable) mefarshim, separate from required.
          // Additive: a new config table; absence reads as text-only, so no
          // existing progress or required-set config changes.
          if (from < 7) {
            await _createTableIfMissing(m, offeredLayerConfigs);
          }
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
          // The batch index goes last: the v8 rebuild drops and recreates
          // learning_events, which would take any index created before it.
          if (from < 9) {
            await _createIndexIfMissing('learning_events_batch',
                'CREATE INDEX learning_events_batch '
                    'ON learning_events (profile_id, batch_id)');
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
        },
      );

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
