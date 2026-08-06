import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:chovos_hayom/data/drift/database.dart';

/// Migration tests against a real on-disk SQLite file.
///
/// These exist because a bad migration is the one bug class that bricks the app
/// permanently: it fails before the first frame, so there is no in-app path to
/// recover, and every subsequent launch fails the same way. Both cases below
/// were live bugs.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chovos_migration');
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

  /// Seeds a database file with [statements], then stamps `user_version`, so we
  /// can hand the app a database shaped exactly like an older (or half-migrated)
  /// install and watch it upgrade.
  void seed(List<String> statements, {required int userVersion}) {
    final db = raw.sqlite3.open(path);
    for (final s in statements) {
      db.execute(s);
    }
    db.execute('PRAGMA user_version = $userVersion');
    db.close();
  }

  /// The learning_events table as it stood at v7 — with the separate `haara`.
  const v7LearningEvents = '''
    CREATE TABLE learning_events (
      id TEXT NOT NULL,
      profile_id TEXT NOT NULL,
      node_id TEXT NOT NULL,
      unit_index INTEGER NOT NULL,
      action INTEGER NOT NULL,
      occurred_at INTEGER NOT NULL,
      logged_at INTEGER NOT NULL,
      duration_min INTEGER NULL,
      note TEXT NULL,
      haara TEXT NULL,
      layers_json TEXT NULL,
      PRIMARY KEY (id)
    )
  ''';

  String insertEvent(String id, {String? note, String? haara}) {
    String q(String? s) => s == null ? 'NULL' : "'${s.replaceAll("'", "''")}'";
    return '''
      INSERT INTO learning_events
        (id, profile_id, node_id, unit_index, action, occurred_at, logged_at, note, haara)
      VALUES ('$id', 'p', 'berachos', 2, 0, 1750000000, 1750000000, ${q(note)}, ${q(haara)})
    ''';
  }

  /// Opens the app database, forcing the migration to run, and returns the
  /// resulting (id, note) pairs.
  Future<Map<String, String?>> openAndReadNotes() async {
    final db = AppDatabase(NativeDatabase(File(path)));
    try {
      final rows =
          await db.customSelect('SELECT id, note FROM learning_events').get();
      return {
        for (final r in rows) r.read<String>('id'): r.read<String?>('note'),
      };
    } finally {
      await db.close();
    }
  }

  test('v7 -> v8 merges haara into note without losing a word', () async {
    seed([
      v7LearningEvents,
      insertEvent('both', note: 'took two sedarim', haara: 'nice chiddush'),
      insertEvent('haara-only', haara: 'a question on Rashi'),
      insertEvent('note-only', note: 'found it hard'),
      insertEvent('neither'),
      insertEvent('blank-haara', note: 'kept', haara: '   '),
    ], userVersion: 7);

    final notes = await openAndReadNotes();

    // Both fields survive, learning-note first, separated by a blank line.
    expect(notes['both'], 'took two sedarim\n\nnice chiddush');
    // A lone value of either kind comes through untouched.
    expect(notes['haara-only'], 'a question on Rashi');
    expect(notes['note-only'], 'found it hard');
    expect(notes['neither'], isNull);
    // A whitespace-only haara must not append a trailing blank line.
    expect(notes['blank-haara'], 'kept');
  });

  test('the merged-away haara column is gone afterwards', () async {
    seed([v7LearningEvents], userVersion: 7);
    await openAndReadNotes();

    final db = raw.sqlite3.open(path);
    final columns = db
        .select('PRAGMA table_info(learning_events)')
        .map((r) => r['name'] as String)
        .toSet();
    final version = db.select('PRAGMA user_version').first['user_version'] as int;
    db.close();

    expect(columns, isNot(contains('haara')));
    expect(columns, contains('note'));
    expect(version, kSchemaVersion);
  });

  test('a half-migrated database still opens instead of bricking', () async {
    // The original bug: a migration died partway, so `haara` was already added
    // but user_version never advanced past 2. Replaying the v2 -> v3 step then
    // threw `duplicate column name: haara` on every single launch, forever.
    //
    // custom_nodes is seeded in its *pre-v2* shape (primary key {id} alone), so
    // this also covers the sibling trap: the v1 -> v2 step rebuilds that table
    // from the current Dart definition, which already carries the columns v5 and
    // v6 go on to add — those steps must notice and skip.
    seed([
      '''
      CREATE TABLE profiles (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        settings_json TEXT NOT NULL DEFAULT '{}',
        PRIMARY KEY (id)
      )
      ''',
      '''
      CREATE TABLE custom_nodes (
        id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        parent_id TEXT NULL,
        name TEXT NOT NULL,
        name_hebrew TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        kind INTEGER NOT NULL,
        unit_label INTEGER NULL,
        unit_count INTEGER NOT NULL DEFAULT 0,
        unit_offset INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      )
      ''',
      "INSERT INTO custom_nodes (id, profile_id, name, kind) VALUES ('n1', 'p', 'My Sefer', 0)",
      v7LearningEvents, // already has `haara`...
      insertEvent('x', note: 'survived', haara: 'and so did this'),
    ], userVersion: 2); // ...but claims to be v2, so v3 will try to add it again

    // Must not throw, and must not lose the rows it already had.
    final notes = await openAndReadNotes();
    expect(notes['x'], 'survived\n\nand so did this');

    // The custom sefer survived the table rebuild, and the schema finished
    // upgrading rather than stalling at the version it crashed on.
    final db = raw.sqlite3.open(path);
    final nodes = db.select('SELECT id FROM custom_nodes');
    final version = db.select('PRAGMA user_version').first['user_version'] as int;
    db.close();

    expect(nodes.map((r) => r['id']), ['n1']);
    expect(version, kSchemaVersion);
  });

  test('v8 -> v9 adds batch_id and its index without touching existing rows',
      () async {
    // The v8 shape: `haara` already merged away, no `batch_id` yet.
    seed([
      '''
      CREATE TABLE learning_events (
        id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        unit_index INTEGER NOT NULL,
        action INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        logged_at INTEGER NOT NULL,
        duration_min INTEGER NULL,
        note TEXT NULL,
        layers_json TEXT NULL,
        PRIMARY KEY (id)
      )
      ''',
      '''
      INSERT INTO learning_events
        (id, profile_id, node_id, unit_index, action, occurred_at, logged_at, note)
      VALUES ('x', 'p', 'berachos', 2, 0, 1750000000, 1750000000, 'kept')
      ''',
    ], userVersion: 8);

    final notes = await openAndReadNotes();
    expect(notes['x'], 'kept', reason: 'pre-existing progress is untouched');

    final db = raw.sqlite3.open(path);
    final columns = db
        .select('PRAGMA table_info(learning_events)')
        .map((r) => r['name'] as String)
        .toSet();
    final indexes = db
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((r) => r['name'] as String)
        .toSet();
    final batchIds = db
        .select('SELECT batch_id FROM learning_events')
        .map((r) => r['batch_id'])
        .toList();
    db.close();

    expect(columns, contains('batch_id'));
    expect(indexes, contains('learning_events_batch'));
    expect(batchIds, [null], reason: 'events written before batches have none');
  });

  test('a v7 database upgrades all the way to the current schema in one run',
      () async {
    // The ordering trap this covers: v8 rebuilds learning_events from the
    // current Dart definition, which now carries `batch_id`. If the v9 column
    // were added after that rebuild rather than before it, the rebuild's
    // column-by-column copy would die on `no such column: batch_id` and no v7
    // install could ever upgrade again.
    seed([
      v7LearningEvents,
      insertEvent('x', note: 'before', haara: 'and after'),
    ], userVersion: 7);

    final notes = await openAndReadNotes();
    expect(notes['x'], 'before\n\nand after');

    final db = raw.sqlite3.open(path);
    final columns = db
        .select('PRAGMA table_info(learning_events)')
        .map((r) => r['name'] as String)
        .toSet();
    final indexes = db
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((r) => r['name'] as String)
        .toSet();
    final version = db.select('PRAGMA user_version').first['user_version'] as int;
    db.close();

    expect(columns, contains('batch_id'));
    expect(columns, isNot(contains('haara')));
    expect(indexes, contains('learning_events_batch'),
        reason: 'the index must outlive the v8 table rebuild');
    expect(version, kSchemaVersion);
  });

  test('v10 -> v11 re-keys learning_events by profile, losing nothing',
      () async {
    // The v10 shape: profile-blind primary key, which is what made the same
    // backup unimportable into a second profile.
    seed([
      '''
      CREATE TABLE learning_events (
        id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        unit_index INTEGER NOT NULL,
        action INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        logged_at INTEGER NOT NULL,
        duration_min INTEGER NULL,
        note TEXT NULL,
        layers_json TEXT NULL,
        batch_id TEXT NULL,
        PRIMARY KEY (id)
      )
      ''',
      'CREATE INDEX learning_events_batch '
          'ON learning_events (profile_id, batch_id)',
      '''
      INSERT INTO learning_events
        (id, profile_id, node_id, unit_index, action, occurred_at, logged_at, note)
      VALUES ('x', 'p1', 'berachos', 2, 0, 1750000000, 1750000000, 'years of it')
      ''',
    ], userVersion: 10);

    final notes = await openAndReadNotes();
    expect(notes['x'], 'years of it', reason: 'no learning is lost re-keying');

    final db = raw.sqlite3.open(path);
    final key = db
        .select('PRAGMA table_info(learning_events)')
        .where((r) => (r['pk'] as int) > 0)
        .map((r) => r['name'] as String)
        .toSet();
    final indexes = db
        .select("SELECT name FROM sqlite_master WHERE type = 'index'")
        .map((r) => r['name'] as String)
        .toSet();
    final version = db.select('PRAGMA user_version').first['user_version'] as int;

    // The whole point, exercised rather than inferred from the schema: the same
    // event id under a second profile now inserts instead of throwing 1555.
    db.execute('''
      INSERT INTO learning_events
        (id, profile_id, node_id, unit_index, action, occurred_at, logged_at)
      VALUES ('x', 'p2', 'berachos', 2, 0, 1750000000, 1750000000)
    ''');
    final ids = db
        .select('SELECT profile_id FROM learning_events ORDER BY profile_id')
        .map((r) => r['profile_id'])
        .toList();
    db.close();

    expect(key, {'profile_id', 'id'});
    expect(indexes, contains('learning_events_batch'),
        reason: 'the rebuild drops the table and its indexes with it, so the '
            'index has to be recreated after it — not before');
    expect(ids, ['p1', 'p2']);
    expect(version, kSchemaVersion);
  });

  test('v9 -> v10 drops the dead settings_json column, keeping profiles',
      () async {
    seed([
      '''
      CREATE TABLE profiles (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        settings_json TEXT NOT NULL DEFAULT '{}',
        PRIMARY KEY (id)
      )
      ''',
      "INSERT INTO profiles (id, name, created_at, settings_json) "
          "VALUES ('p1', 'Yaakov', 1750000000, '{\"theme\":\"dark\"}')",
    ], userVersion: 9);

    final db = AppDatabase(NativeDatabase(File(path)));
    await db.customSelect('SELECT id FROM profiles').get(); // force migration
    await db.close();

    final raw_ = raw.sqlite3.open(path);
    final columns = raw_
        .select('PRAGMA table_info(profiles)')
        .map((r) => r['name'] as String)
        .toSet();
    final rows = raw_.select('SELECT id, name FROM profiles');
    raw_.close();

    expect(columns, isNot(contains('settings_json')));
    expect(rows.single['name'], 'Yaakov', reason: 'the profile itself survives');
  });
  group('v11 -> v12 merges the two layer tables into one', () {
    /// The pair as it stood at v11: membership in `required_layer_configs`
    /// meant "gates completion", membership in `offered_layer_configs` meant
    /// "checkable", and the app took the union of the two at every read.
    const legacyTables = [
      '''
      CREATE TABLE required_layer_configs (
        profile_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        unit_index INTEGER NOT NULL DEFAULT -1,
        layers_json TEXT NOT NULL,
        PRIMARY KEY (profile_id, node_id, unit_index)
      )
      ''',
      '''
      CREATE TABLE offered_layer_configs (
        profile_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        unit_index INTEGER NOT NULL DEFAULT -1,
        layers_json TEXT NOT NULL,
        PRIMARY KEY (profile_id, node_id, unit_index)
      )
      ''',
    ];

    String legacyRow(String table, String node, String layersJson,
            {int unit = -1, String profile = 'p1'}) =>
        "INSERT INTO $table (profile_id, node_id, unit_index, layers_json) "
        "VALUES ('$profile', '$node', $unit, '$layersJson')";

    /// Opens the migrated database and reads `layer_configs` back as
    /// (node, unit) -> decoded role map.
    Map<(String, int), Map<String, String>> readConfigs() {
      final db = raw.sqlite3.open(path);
      final rows =
          db.select('SELECT node_id, unit_index, roles_json FROM layer_configs');
      final out = <(String, int), Map<String, String>>{
        for (final r in rows)
          (r['node_id'] as String, r['unit_index'] as int):
              (jsonDecode(r['roles_json'] as String) as Map)
                  .map((k, v) => MapEntry('$k', '$v')),
      };
      db.close();
      return out;
    }

    Future<void> migrate() async {
      final db = AppDatabase(NativeDatabase(File(path)));
      await db.customSelect('SELECT 1').get();
      await db.close();
    }

    test('required wins over offered, and offered-only becomes optional',
        () async {
      // The exact reconciliation the app used to do at read time — the union,
      // with required taking precedence — now done once, at rest.
      seed([
        ...legacyTables,
        legacyRow('required_layer_configs', 'shas', '["main","rashi"]'),
        legacyRow(
            'offered_layer_configs', 'shas', '["main","rashi","maharsha"]'),
      ], userVersion: 11);

      await migrate();

      expect(readConfigs()[('shas', -1)], {
        'main': 'required',
        'rashi': 'required',
        'maharsha': 'optional',
      });
    });

    test('a scope pinned in only one of the two tables still comes across',
        () async {
      // The delete-a-meforish cascade could clear one table's row and rewrite
      // the other's, so half-pinned scopes really are out there on the one
      // device this schema has ever run on. Neither half may be dropped.
      seed([
        ...legacyTables,
        legacyRow('required_layer_configs', 'nach', '["main"]'),
        legacyRow('offered_layer_configs', 'nach.tehillim', '["main","rashi"]'),
      ], userVersion: 11);

      await migrate();

      final configs = readConfigs();
      expect(configs[('nach', -1)], {'main': 'required'});
      expect(configs[('nach.tehillim', -1)],
          {'main': 'optional', 'rashi': 'optional'});
    });

    test('per-unit overrides keep their unit index', () async {
      seed([
        ...legacyTables,
        legacyRow('required_layer_configs', 'shabbos', '["main","tosafos"]',
            unit: 7),
      ], userVersion: 11);

      await migrate();

      expect(readConfigs()[('shabbos', 7)],
          {'main': 'required', 'tosafos': 'required'});
    });

    test('the legacy tables are gone afterwards', () async {
      seed([
        ...legacyTables,
        legacyRow('required_layer_configs', 'shas', '["main"]'),
      ], userVersion: 11);

      await migrate();

      final db = raw.sqlite3.open(path);
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      final version =
          db.select('PRAGMA user_version').first['user_version'] as int;
      db.close();

      expect(tables, contains('layer_configs'));
      expect(tables, isNot(contains('required_layer_configs')));
      expect(tables, isNot(contains('offered_layer_configs')));
      expect(version, kSchemaVersion);
    });

    test('a v3 database, which predates both tables, still reaches v12',
        () async {
      // v3 is older than the layer feature entirely, so the v4 and v7 steps that
      // used to create these tables purely for v12 to drop are gone. The merge
      // has to tolerate their absence rather than throw during `beforeOpen` —
      // the one failure the user cannot get out of — and the rest of the chain
      // has to still run around it.
      seed([
        v7LearningEvents,
        '''
        CREATE TABLE custom_nodes (
          id TEXT NOT NULL,
          profile_id TEXT NOT NULL,
          parent_id TEXT NULL,
          name TEXT NOT NULL,
          name_hebrew TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          kind INTEGER NOT NULL,
          unit_label INTEGER NULL,
          unit_count INTEGER NOT NULL DEFAULT 0,
          unit_offset INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (profile_id, id)
        )
        ''',
        "INSERT INTO custom_nodes (id, profile_id, name, kind, unit_count) "
            "VALUES ('mine', 'p1', 'My Sefer', 1, 10)",
        insertEvent('x'),
      ], userVersion: 3);

      await migrate();

      final db = raw.sqlite3.open(path);
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      final nodes = db.select('SELECT name FROM custom_nodes');
      final version =
          db.select('PRAGMA user_version').first['user_version'] as int;
      db.close();

      expect(readConfigs(), isEmpty);
      expect(tables, contains('layer_configs'));
      expect(nodes.single['name'], 'My Sefer',
          reason: 'the custom sefer survives the whole chain');
      expect(version, kSchemaVersion);
    });

    test('replaying the step is a no-op rather than a crash', () async {
      // Same replay-safety every other step has: a run that died after the
      // merge but before user_version was bumped must not throw on the retry.
      seed([
        ...legacyTables,
        legacyRow('required_layer_configs', 'shas', '["main","rashi"]'),
      ], userVersion: 11);

      await migrate();
      // Stamp it back and run it again over the already-merged database.
      final stamp = raw.sqlite3.open(path);
      stamp.execute('PRAGMA user_version = 11');
      stamp.close();
      await migrate();

      expect(readConfigs()[('shas', -1)],
          {'main': 'required', 'rashi': 'required'});
    });
  });
}
