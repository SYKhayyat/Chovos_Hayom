import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/learning_event.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/progress_repository.dart';
import '../drift/database.dart';

/// Drift-backed [ProgressRepository]. The app's real persistence layer.
class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LearningEvent>> watchEvents(String profileId) {
    final query = _db.select(_db.learningEvents)
      ..where((t) => t.profileId.equals(profileId));
    return query.watch().map((rows) => rows.map(_toEvent).toList());
  }

  @override
  Future<List<LearningEvent>> getEvents(String profileId) async {
    final query = _db.select(_db.learningEvents)
      ..where((t) => t.profileId.equals(profileId));
    final rows = await query.get();
    return rows.map(_toEvent).toList();
  }

  @override
  Future<void> addEvent(LearningEvent e) async {
    await _db.into(_db.learningEvents).insert(
          LearningEventsCompanion.insert(
            id: e.id,
            profileId: e.profileId,
            nodeId: e.nodeId,
            unitIndex: e.unitIndex,
            action: e.action,
            occurredAt: e.occurredAt,
            loggedAt: e.loggedAt,
            durationMin: Value(e.durationMin),
            note: Value(e.note),
          ),
        );
  }

  @override
  Future<void> removeEvent(String eventId) async {
    await (_db.delete(_db.learningEvents)..where((t) => t.id.equals(eventId)))
        .go();
  }

  @override
  Future<List<Profile>> getProfiles() async {
    final rows = await _db.select(_db.profiles).get();
    return rows.map(_toProfile).toList();
  }

  @override
  Future<void> addProfile(Profile p) async {
    await _db.into(_db.profiles).insert(
          ProfilesCompanion.insert(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
            settingsJson: Value(jsonEncode(p.settings)),
          ),
        );
  }

  LearningEvent _toEvent(LearningEventRow row) => LearningEvent(
        id: row.id,
        profileId: row.profileId,
        nodeId: row.nodeId,
        unitIndex: row.unitIndex,
        action: row.action,
        occurredAt: row.occurredAt,
        loggedAt: row.loggedAt,
        durationMin: row.durationMin,
        note: row.note,
      );

  Profile _toProfile(ProfileRow row) => Profile(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        settings: (jsonDecode(row.settingsJson) as Map).cast<String, dynamic>(),
      );
}
