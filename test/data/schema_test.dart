import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:chovos_hayom/data/drift/database.dart';

/// What is left of `migration_test.dart` after the chain was squashed, plus the
/// one step written since.
///
/// The file this replaces was 649 lines covering twelve migration steps, and
/// every one of those steps existed to carry a database that had never left the
/// author's own machines. The steps are gone; what remains is a doorman with a
/// single door in it, and these are the things worth knowing about both.
///
/// The reason any of this is tested at all is unchanged, and it is the reason
/// the old file gave: **a bad migration is the one bug class that bricks the app
/// permanently.** It fails before the first frame, so there is no in-app path to
/// recover, and every subsequent launch fails the same way. That is why the
/// doorman refuses a shape it does not know rather than opening it and finding
/// out one query at a time — and why *refusing* has to be provably harmless to
/// the file, which is the middle group below.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chovos_schema');
    path = '${dir.path}/test.sqlite';
  });

  tearDown(() async {
    // On Windows a still-open handle blocks deletion; a leftover temp dir must
    // not mask the real failure, so this is best-effort.
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  /// The schema at v1 — the shape the squash produced, and the only one this
  /// build has a step from.
  ///
  /// It is read off the real Windows database the deleted chain had actually
  /// produced rather than re-typed from the Dart definitions, which is what
  /// makes it evidence rather than a restatement: every one of these five tables
  /// reached this shape by a different route — `profiles` was rebuilt at v10 to
  /// drop a dead column, `custom_nodes` at v2 and `learning_events` at v8 and
  /// v11 to re-key them, `custom_layers` was created at v4 and `layer_configs`
  /// at v12.
  const v1Schema = <String>[
    'CREATE TABLE "custom_layers" ("id" TEXT NOT NULL, "profile_id" TEXT NOT '
        'NULL, "name" TEXT NOT NULL, "name_hebrew" TEXT NULL, "sort_order" '
        'INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("profile_id", "id"))',
    'CREATE TABLE "custom_nodes" ("id" TEXT NOT NULL, "profile_id" TEXT NOT '
        'NULL, "parent_id" TEXT NULL, "name" TEXT NOT NULL, "name_hebrew" TEXT '
        'NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, "kind" INTEGER NOT '
        'NULL, "unit_label" INTEGER NULL, "unit_count" INTEGER NOT NULL DEFAULT '
        '0, "unit_offset" INTEGER NOT NULL DEFAULT 0, "hidden" INTEGER NOT NULL '
        'DEFAULT 0 CHECK ("hidden" IN (0, 1)), "unit_names_json" TEXT NULL, '
        'PRIMARY KEY ("profile_id", "id"))',
    'CREATE TABLE "layer_configs" ("profile_id" TEXT NOT NULL, "node_id" TEXT '
        'NOT NULL, "unit_index" INTEGER NOT NULL DEFAULT -1, "roles_json" TEXT '
        'NOT NULL, PRIMARY KEY ("profile_id", "node_id", "unit_index"))',
    'CREATE TABLE "learning_events" ("id" TEXT NOT NULL, "profile_id" TEXT NOT '
        'NULL, "node_id" TEXT NOT NULL, "unit_index" INTEGER NOT NULL, "action" '
        'INTEGER NOT NULL, "occurred_at" INTEGER NOT NULL, "logged_at" INTEGER '
        'NOT NULL, "duration_min" INTEGER NULL, "note" TEXT NULL, "layers_json" '
        'TEXT NULL, "batch_id" TEXT NULL, PRIMARY KEY ("profile_id", "id"))',
    'CREATE TABLE "profiles" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, '
        '"created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX learning_events_batch '
        'ON learning_events (profile_id, batch_id)',
  ];

  /// One event, written the way a v1 database holds one: `logged_at` in
  /// microseconds, because that is what the last step of the deleted chain did
  /// and the squash inherited.
  const microseconds = 1750000000 * 1000000;
  const insertEvent = 'INSERT INTO learning_events '
      '(id, profile_id, node_id, unit_index, action, occurred_at, logged_at, note) '
      "VALUES ('e1', 'p1', 'berachos', 2, 0, 1750000000, $microseconds, "
      "'seven years of this')";

  /// Writes [statements] into the file and stamps `user_version`, so the app can
  /// be handed a database shaped exactly like some older install.
  void seed(List<String> statements, {required int userVersion}) {
    final db = raw.sqlite3.open(path);
    for (final s in statements) {
      db.execute(s);
    }
    db.execute('PRAGMA user_version = $userVersion');
    db.close();
  }

  /// Opens the file as the app does, which is what forces the migration
  /// callback to run.
  Future<void> open() async {
    final db = AppDatabase(NativeDatabase(File(path)));
    try {
      await db.customSelect('SELECT 1').get();
    } finally {
      await db.close();
    }
  }

  /// `(user_version, schema statements, event ids, logged_at by id)`.
  ({int version, List<String> schema, List<String> ids, List<int> loggedAt})
      inspect() {
    final db = raw.sqlite3.open(path);
    final version =
        db.select('PRAGMA user_version').first['user_version'] as int;
    final schema = db
        .select('SELECT sql FROM sqlite_master '
            'WHERE sql IS NOT NULL ORDER BY type DESC, name')
        .map((r) => r['sql'] as String)
        .toList();
    final events = db.select('SELECT id, logged_at FROM learning_events '
        'ORDER BY id');
    final out = (
      version: version,
      schema: schema,
      ids: events.map((r) => r['id'] as String).toList(),
      loggedAt: events.map((r) => r['logged_at'] as int).toList(),
    );
    db.close();
    return out;
  }

  /// The rows a v1 database can hold in `layer_configs`: one pinned at a node,
  /// and one pinned on a single unit — the scope nothing ever wrote, which is
  /// why v2 has no room for it.
  const insertConfigs = <String>[
    'INSERT INTO layer_configs (profile_id, node_id, unit_index, roles_json) '
        'VALUES (\'p1\', \'berachos\', -1, \'{"main":"required"}\')',
    'INSERT INTO layer_configs (profile_id, node_id, unit_index, roles_json) '
        'VALUES (\'p1\', \'berachos\', 7, \'{"rashi":"required"}\')',
  ];

  /// The table as v2 defines it — no `unit_index`, and a two-column key.
  const layerConfigsAtV2 =
      'CREATE TABLE "layer_configs" ("profile_id" TEXT NOT NULL, "node_id" '
      'TEXT NOT NULL, "roles_json" TEXT NOT NULL, PRIMARY KEY ("profile_id", '
      '"node_id"))';

  /// `(node_id, roles_json)` for every layer setting on disk.
  List<(String, String)> layerConfigs() {
    final db = raw.sqlite3.open(path);
    final rows = db.select(
        'SELECT node_id, roles_json FROM layer_configs ORDER BY node_id');
    final out = [
      for (final r in rows) (r['node_id'] as String, r['roles_json'] as String),
    ];
    db.close();
    return out;
  }

  group('a fresh database', () {
    test('is created at the current version, in one step', () async {
      await open();
      expect(inspect().version, kSchemaVersion);
      expect(kSchemaVersion, 2,
          reason: 'the chain was squashed to 1 and has had exactly one step '
              'since; a third means this file needs another group');
    });

    test('is the squashed shape, with unit_index gone from layer_configs',
        () async {
      // The pair of claims this file exists to hold. Everything but
      // `layer_configs` is byte-for-byte what the twelve-step chain arrived at
      // — if a column, a default or the batch index moves here, a v1 database
      // stops being migratable and this fails, which is the moment to write a
      // v3 step rather than to edit this list.
      await open();

      final schema = inspect().schema;
      expect(schema.where((s) => !s.contains('layer_configs')),
          v1Schema.where((s) => !s.contains('layer_configs')));
      expect(schema.singleWhere((s) => s.contains('TABLE "layer_configs"')),
          layerConfigsAtV2);
    });
  });

  group('a database at v1', () {
    test('keeps its node-level settings and loses the dead column', () async {
      seed([...v1Schema, insertEvent, ...insertConfigs], userVersion: 1);

      await open();

      final after = inspect();
      expect(after.version, kSchemaVersion, reason: 'stamped up to v2');
      expect(after.ids, ['e1'], reason: 'the log is not what this step touches');
      expect(after.loggedAt, [microseconds],
          reason: 'the seconds-to-microseconds rewrite was the last step of the '
              'deleted chain — running anything like it again would put every '
              'event in the year 58692, which nothing downstream would notice '
              'beyond the log quietly reordering itself');
      expect(layerConfigs(), [('berachos', '{"main":"required"}')],
          reason: 'the node-level row survives; the unit-scoped one is dropped '
              'rather than folded into it, which would have replaced the '
              'node\'s own answer with one unit\'s');
      expect(after.schema.singleWhere((s) => s.contains('TABLE "layer_configs"')),
          layerConfigsAtV2);
    });

    test('and is an ordinary database on every launch after that', () async {
      seed([...v1Schema, insertEvent, ...insertConfigs], userVersion: 1);

      await open();
      await open();

      expect(inspect().ids, ['e1']);
      expect(layerConfigs(), [('berachos', '{"main":"required"}')]);
    });

    test('a half-finished run is replayable rather than stuck', () async {
      // `alterTable` rebuilds and commits as it goes, and drift stamps
      // `user_version` only after the callback returns — so a run that dies in
      // between leaves a v2-shaped table in a file still marked v1. Without the
      // column check in the step, the retry would die on `no such column:
      // unit_index` and the install would never open again. This is that file.
      seed([
        for (final s in v1Schema)
          if (s.contains('TABLE "layer_configs"')) layerConfigsAtV2 else s,
        insertEvent,
        'INSERT INTO layer_configs (profile_id, node_id, roles_json) '
            'VALUES (\'p1\', \'berachos\', \'{"main":"required"}\')',
      ], userVersion: 1);

      await open();

      expect(inspect().version, kSchemaVersion);
      expect(layerConfigs(), [('berachos', '{"main":"required"}')]);
    });
  });

  group('a database this build has no path to', () {
    test('a pre-squash shape is refused, not guessed at', () async {
      // v13 was the head of the deleted chain, and this build used to adopt it
      // for free. That clause is gone: it existed so the squash cost an
      // existing install nothing, and it said in its own comment to delete it
      // once every install had opened a post-squash build.
      seed([...v1Schema, insertEvent], userVersion: 13);

      await expectLater(open(), throwsA(isA<SchemaMismatchException>()));
    });

    test('and refusing leaves the file exactly as it was', () async {
      // The property that makes refusing safe rather than merely loud: drift
      // stamps `user_version` only *after* the migration callback returns, so a
      // database rejected here can still be opened by the build that wrote it.
      // Without this, "export a backup from the old build" would not be a
      // recovery.
      seed([...v1Schema, insertEvent], userVersion: 13);

      await expectLater(open(), throwsA(isA<SchemaMismatchException>()));

      final after = inspect();
      expect(after.version, 13);
      expect(after.ids, ['e1']);
      expect(after.loggedAt, [microseconds]);
    });

    test('and says how to get out of it', () {
      // This message is not a log line — it is what the user reads. A provider
      // that throws surfaces through `ErrorView`, which prints the exception
      // under *Show details* and appends it to the crash log. It has to name a
      // recovery that still exists: the build that wrote the file can still
      // open it, so the way out is a backup taken there.
      final message =
          const SchemaMismatchException(13, kSchemaVersion).toString();
      expect(message, contains('Export a backup'));
      expect(message, contains('fresh install'));
    });

    test('a schemaVersion raised without a step fails loudly', () async {
      // The rot mode the deleted chain's own doc comment warned about, kept
      // rather than deleted with it: bumping the number on its own used to
      // change nothing on an existing install and derail into `no such column`
      // later. It now throws at the door, on the first launch, with the reason.
      await open(); // creates it at the current version

      final next = _FutureSchema(NativeDatabase(File(path)));
      await expectLater(next.customSelect('SELECT 1').get(),
          throwsA(isA<SchemaMismatchException>()));
      await next.close();

      expect(inspect().version, kSchemaVersion,
          reason: 'and leaves the database at the version it can still open');
    });
  });
}

/// The next schema change, arriving without the step that has to come with it.
class _FutureSchema extends AppDatabase {
  _FutureSchema(super.e);

  @override
  int get schemaVersion => kSchemaVersion + 1;
}
