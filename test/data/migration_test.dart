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
    expect(version, 9);
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
    expect(version, 9);
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

  test('a v7 database upgrades all the way to v9 in one run', () async {
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
    expect(version, 9);
  });
}
