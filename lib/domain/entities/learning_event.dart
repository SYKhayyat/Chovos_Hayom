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

  /// Returns a copy with edited annotations, where passing null *clears* the
  /// field (unlike [copyWith], whose null means "keep existing"). Used when the
  /// user edits an item's details and, e.g., deletes its note or duration.
  LearningEvent withDetails({
    required DateTime occurredAt,
    required int? durationMin,
    required String? note,
  }) =>
      LearningEvent(
        id: id,
        profileId: profileId,
        nodeId: nodeId,
        unitIndex: unitIndex,
        action: action,
        occurredAt: occurredAt,
        loggedAt: loggedAt,
        durationMin: durationMin,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'nodeId': nodeId,
        'unitIndex': unitIndex,
        'action': action.name,
        'occurredAt': occurredAt.toIso8601String(),
        'loggedAt': loggedAt.toIso8601String(),
        if (durationMin != null) 'durationMin': durationMin,
        if (note != null) 'note': note,
      };

  factory LearningEvent.fromJson(Map<String, dynamic> json) => LearningEvent(
        id: json['id'] as String,
        profileId: json['profileId'] as String,
        nodeId: json['nodeId'] as String,
        unitIndex: (json['unitIndex'] as num).toInt(),
        action: EventAction.values.byName(json['action'] as String),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        loggedAt: DateTime.parse(json['loggedAt'] as String),
        durationMin: (json['durationMin'] as num?)?.toInt(),
        note: json['note'] as String?,
      );
}
