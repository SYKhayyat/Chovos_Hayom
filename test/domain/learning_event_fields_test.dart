import 'dart:io';

import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// A field added to [LearningEvent] and left out of one of the six places that
/// copy one is dropped **silently**.
///
/// `copyWith` was deleted from this class because nothing called it, and the
/// argument for deleting it was right: it sat next to `withDetails`, whose null
/// means *clear this field*, while `copyWith`'s null means *keep it* — two
/// near-identical methods with inverted null semantics, waiting for whoever
/// reaches for the familiar name.
///
/// What the deletion missed is that something *was* doing the job, by hand.
/// `BackupService._rescope` listed all eleven fields to change one, so a field
/// added here and not there would have been dropped from every event of every
/// imported backup — at the one moment a user is restoring data they cannot
/// lose. It is `rescopedTo` on this class now: named, one field, no null that
/// could mean two things.
///
/// And the same shape exists five more times — `withDetails`, `toJson`,
/// `fromJson`, and the two halves of the Drift mapping — so this holds all six
/// to the constructor rather than to each other.
void main() {
  /// Every parameter of the primary constructor, read out of the source. There
  /// is no reflection under `flutter_test`, and a list typed here would be the
  /// same hand-written enumeration this test exists to catch.
  List<String> constructorFields() {
    final source =
        File('lib/domain/entities/learning_event.dart').readAsStringSync();
    final ctor = RegExp(r'const LearningEvent\(\{([\s\S]*?)\}\);')
        .firstMatch(source)
        ?.group(1);
    expect(ctor, isNotNull,
        reason: 'the constructor has moved, so this guard reads nothing');
    return [
      for (final m in RegExp(r'this\.(\w+)').allMatches(ctor!)) m.group(1)!,
    ];
  }

  test('the field list is read, not assumed', () {
    final fields = constructorFields();
    expect(fields, containsAll(<String>['id', 'profileId', 'layers', 'batchId']));
    expect(fields, hasLength(11));
  });

  test('every place that copies an event names every field', () {
    final source =
        File('lib/domain/entities/learning_event.dart').readAsStringSync();
    final repository =
        File('lib/data/repositories/drift_progress_repository.dart')
            .readAsStringSync();

    /// The body of a member, so a field mentioned elsewhere in the file does
    /// not excuse the one that omits it.
    String body(String haystack, String signature, String end) {
      final m = RegExp(RegExp.escape(signature) + r'[\s\S]*?' + RegExp.escape(end))
          .firstMatch(haystack);
      expect(m, isNotNull, reason: '$signature has moved');
      return m!.group(0)!;
    }

    final copiers = <String, String>{
      'withDetails': body(source, 'LearningEvent withDetails(', ');'),
      'rescopedTo': body(source, 'LearningEvent rescopedTo(', ');'),
      'toJson': body(source, 'Map<String, dynamic> toJson()', '};'),
      'fromJson': body(source, 'factory LearningEvent.fromJson(', ');'),
      '_eventCompanion':
          body(repository, 'LearningEventsCompanion _eventCompanion(', ');'),
      '_toEvent': body(repository, 'LearningEvent _toEvent(', ');'),
    };

    /// Two fields are stored under a different name, and both are deliberate:
    /// the layers list is encoded to JSON in a `layersJson` column (so a
    /// default-only list can stay null and keep old rows byte-identical), and
    /// the note is reassembled from a legacy `note`/`haara` pair on the way in.
    const spelledDifferently = <String, List<String>>{
      'layers': ['layersJson', 'layers'],
      'note': ['note', 'mergeNotes'],
    };

    final missing = <String>[];
    for (final field in constructorFields()) {
      final names = spelledDifferently[field] ?? [field];
      for (final entry in copiers.entries) {
        if (names.any(entry.value.contains)) continue;
        missing.add('${entry.key} drops "$field"');
      }
    }

    expect(missing, isEmpty,
        reason: 'a field this class carries and one of its copiers does not is '
            'lost silently — on an import, on an edit, or at rest:\n'
            '${missing.join('\n')}');
  });

  test('re-scoping changes the profile and nothing else', () {
    // Every field set to something distinguishable, so a dropped one is a
    // failure rather than a coincidence.
    final original = LearningEvent(
      id: 'e1',
      profileId: 'from',
      nodeId: 'shas.moed.shabbos',
      unitIndex: 42,
      action: EventAction.reviewed,
      occurredAt: DateTime(2026, 3, 9, 14, 30),
      loggedAt: DateTime(2026, 3, 10, 8, 15),
      durationMin: 45,
      note: 'a chiddush',
      layers: const ['main', 'rashi'],
      batchId: 'batch-7',
    );

    final moved = original.rescopedTo('to');

    expect(moved.profileId, 'to');
    // Compared through `toJson`, which enumerates every field — so this
    // assertion grows with the class rather than needing to be extended.
    final before = original.toJson()..remove('profileId');
    final after = moved.toJson()..remove('profileId');
    expect(after, before);
    expect(moved.id, 'e1',
        reason: 'ids are unique within a profile, not across the store — the '
            'same backup in two profiles putting the same ids in both is the '
            'feature');
  });
}
