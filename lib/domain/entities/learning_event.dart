import 'enums.dart';

/// An append-only record of a learning action. The event log is the single
/// source of truth; all progress is derived from it (see ARCHITECTURE.md §1).
class LearningEvent {
  const LearningEvent({
    required this.id,
    required this.profileId,
    required this.nodeId,
    required this.unitIndex,
    required this.action,
    required this.occurredAt,
    required this.loggedAt,
    this.durationMin,
    this.note,
  });

  final String id;
  final String profileId;
  final String nodeId;
  final int unitIndex;
  final EventAction action;

  /// When the unit was *learned*. Defaults to now at creation unless the user
  /// supplies a date/time.
  final DateTime occurredAt;

  /// When the event was *recorded*. Always now at creation. Also defines the
  /// canonical fold order (append order).
  final DateTime loggedAt;

  final int? durationMin;
  final String? note;

  LearningEvent copyWith({DateTime? occurredAt, int? durationMin, String? note}) =>
      LearningEvent(
        id: id,
        profileId: profileId,
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: action,
        occurredAt: occurredAt ?? this.occurredAt,
        loggedAt: loggedAt,
        durationMin: durationMin ?? this.durationMin,
        note: note ?? this.note,
      );
}
