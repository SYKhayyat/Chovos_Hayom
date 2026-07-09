import 'enums.dart';
import 'layer.dart';

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
    this.haara,
    this.layers = const [mainLayerId],
  });

  final String id;
  final String profileId;
  final String nodeId;
  final int unitIndex;
  final EventAction action;

  /// Which layers (the text and/or mefarshim) this event marks or unmarks.
  /// Defaults to `[main]` — the primary text — matching pre-layers events.
  final List<String> layers;

  /// When the unit was *learned*. Defaults to now at creation unless the user
  /// supplies a date/time.
  final DateTime occurredAt;

  /// When the event was *recorded*. Always now at creation. Also defines the
  /// canonical fold order (append order).
  final DateTime loggedAt;

  final int? durationMin;

  /// A note *about the learning experience* (how it went, how long it took).
  /// Stays with the item; not surfaced in the Notes Journal.
  final String? note;

  /// A **haara** — a note *on the material itself* (an insight on the daf). These
  /// are what the Notes Journal collects.
  final String? haara;

  LearningEvent copyWith({
    DateTime? occurredAt,
    int? durationMin,
    String? note,
    String? haara,
    List<String>? layers,
  }) =>
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
        haara: haara ?? this.haara,
        layers: layers ?? this.layers,
      );

  /// Returns a copy with edited annotations, where passing null *clears* the
  /// field (unlike [copyWith], whose null means "keep existing"). Used when the
  /// user edits an item's details and, e.g., deletes its note or duration.
  LearningEvent withDetails({
    required DateTime occurredAt,
    required int? durationMin,
    required String? note,
    required String? haara,
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
        haara: haara,
        layers: layers,
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
        if (haara != null) 'haara': haara,
        // Omit the default single-'main' list to keep old backups byte-identical.
        if (!(layers.length == 1 && layers.first == mainLayerId)) 'layers': layers,
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
        haara: json['haara'] as String?,
        layers: (json['layers'] as List?)?.cast<String>() ??
            const [mainLayerId],
      );
}
