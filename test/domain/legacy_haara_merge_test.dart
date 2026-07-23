import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/domain/entities/learning_event.dart';

/// The note/haara split was merged into a single field. Backups written before
/// that still carry both, so importing one must fold them together on exactly
/// the same rule the v7 -> v8 database migration uses — otherwise the same
/// backup restores differently depending on how it gets in.
void main() {
  group('mergeNotes', () {
    test('keeps both, learning-note first, separated by a blank line', () {
      expect(LearningEvent.mergeNotes('how it went', 'the chiddush'),
          'how it went\n\nthe chiddush');
    });

    test('a lone value of either kind passes through untouched', () {
      expect(LearningEvent.mergeNotes(null, 'just a haara'), 'just a haara');
      expect(LearningEvent.mergeNotes('just a note', null), 'just a note');
    });

    test('whitespace counts as empty, and never leaves a dangling separator', () {
      expect(LearningEvent.mergeNotes('  kept  ', '   '), 'kept');
      expect(LearningEvent.mergeNotes('   ', ' kept '), 'kept');
      expect(LearningEvent.mergeNotes(null, null), isNull);
      expect(LearningEvent.mergeNotes('', ''), isNull);
    });
  });

  group('legacy backup import', () {
    Map<String, dynamic> legacyJson({String? note, String? haara}) => {
          'id': 'e1',
          'profileId': 'p',
          'nodeId': 'berachos',
          'unitIndex': 2,
          'action': 'done',
          'occurredAt': '2026-01-01T00:00:00.000',
          'loggedAt': '2026-01-01T00:00:00.000',
          'note': ?note,
          'haara': ?haara,
        };

    test('an old backup carrying both fields loses neither', () {
      final e = LearningEvent.fromJson(
          legacyJson(note: 'took two sedarim', haara: 'nice chiddush'));
      expect(e.note, 'took two sedarim\n\nnice chiddush');
    });

    test('an old haara-only backup keeps its haara', () {
      final e = LearningEvent.fromJson(legacyJson(haara: 'a question on Rashi'));
      expect(e.note, 'a question on Rashi');
    });

    test('round-tripping a current backup is stable', () {
      final e = LearningEvent.fromJson(legacyJson(note: 'kept'));
      final again = LearningEvent.fromJson(e.toJson());
      expect(again.note, 'kept');
      expect(e.toJson().containsKey('haara'), isFalse);
    });
  });
}
