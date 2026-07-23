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

  /// A **haara** — whatever you wanted to record about this unit: an insight on
  /// the daf, a question, or how the seder went. One field, yours to use however
  /// you like. Every non-empty one is collected in the Notes Journal.
  ///
  /// This was once split into `note` (the experience) and `haara` (the material);
  /// the two were merged, and [mergeNotes] is how legacy pairs are folded in.
  final String? note;

  LearningEvent copyWith({
    DateTime? occurredAt,
    int? durationMin,
    String? note,
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
        layers: layers ?? this.layers,
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
        // Backups written before the merge carry a separate `haara`. Fold it in
        // rather than dropping it — importing an old backup must not lose text.
        note: mergeNotes(json['note'] as String?, json['haara'] as String?),
        layers: (json['layers'] as List?)?.cast<String>() ??
            const [mainLayerId],
      );

  /// Folds a legacy (note, haara) pair into the single note field. Keeps both
  /// when both exist — separated by a blank line, learning-note first, matching
  /// the order the two fields were shown in — and returns null when neither has
  /// content. Used by both the v7 -> v8 migration and legacy backup import.
  static String? mergeNotes(String? note, String? haara) {
    final a = note?.trim() ?? '';
    final b = haara?.trim() ?? '';
    if (a.isEmpty && b.isEmpty) return null;
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a\n\n$b';
  }
}
