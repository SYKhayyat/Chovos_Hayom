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
  TextColumn get note => text().nullable()();

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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles, LearningEvents, CustomNodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (Android/desktop) via drift_flutter.
  AppDatabase.open() : super(driftDatabase(name: 'chovos_hayom'));

  @override
  int get schemaVersion => 1;
}
