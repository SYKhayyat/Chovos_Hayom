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
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The append-only event log — the single source of truth.
@DataClassName('LearningEventRow')
class LearningEvents extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get nodeId => text()();
  IntColumn get unitIndex => integer()();
  IntColumn get action => intEnum<EventAction>()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get loggedAt => dateTime()();
  IntColumn get durationMin => integer().nullable()();

  /// A note *about the learning experience* (how it went, how long, where you
  /// stopped). Shown on the item but never in the Notes Journal.
  TextColumn get note => text().nullable()();

  /// A **haara** — a note *on the material itself* (an insight on the daf). These
  /// are what the Notes Journal collects.
  TextColumn get haara => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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

  // Custom nodes are profile-scoped: two profiles may hold nodes with the same
  // id (e.g. the same backup imported into both). The primary key must include
  // profileId, or the second import throws a uniqueness violation.
  @override
  Set<Column> get primaryKey => {profileId, id};
}

@DriftDatabase(tables: [Profiles, LearningEvents, CustomNodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (Android/desktop) via drift_flutter.
  AppDatabase.open() : super(driftDatabase(name: 'chovos_hayom'));

  @override
  int get schemaVersion => 3;

  /// Every schema change must extend [MigrationStrategy.onUpgrade]. Without this,
  /// bumping [schemaVersion] silently does nothing on existing installs and
  /// derails into `no such column` crashes or data loss.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: CustomNodes primary key changed {id} -> {profileId, id}.
          // TableMigration recreates the physical table, preserving existing
          // rows, so no custom sefarim are lost.
          if (from < 2) {
            await m.alterTable(TableMigration(customNodes));
          }
          // v2 -> v3: add the `haara` note column (additive; existing rows keep
          // their `note` as the learning-note and get a null haara).
          if (from < 3) {
            await m.addColumn(learningEvents, learningEvents.haara);
          }
        },
      );
}
