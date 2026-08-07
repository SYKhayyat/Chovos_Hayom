import 'dart:convert';
import 'dart:io';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_database.dart';
import '../support/source_scan.dart';

/// **A backup is decoded once per restore.**
///
/// It used to be three or four times over. The preview parsed the file; the
/// count of customisations the preview shows parsed it again; the write parsed
/// it a third; and the merge path's "how many events were in the file, then?"
/// — the sentence that distinguishes *nothing new* from *nothing at all* — a
/// fourth. Each one a full `jsonDecode` of a file that at seven years of daf
/// yomi is megabytes, on a phone chosen for being unbreakable rather than fast.
///
/// The fix is not caching. It is that **the parse is a trust boundary**, so it
/// belongs where the untrusted bytes arrive and nowhere else — and everything
/// downstream takes the parsed value. That is a type, not a discipline:
/// `importInto`, `customisationsAtRisk` and `SettingsScreen.restoreDiff` take a
/// `BackupData`, so there is no longer a String to hand them.
void main() {
  test('the write path takes a parsed backup, and validates it', () async {
    final repo = memoryRepository();
    final json = jsonEncode({
      'version': BackupService.currentVersion,
      'events': [
        LearningEvent(
          id: 'e1',
          profileId: 'a',
          nodeId: 'shas.moed.shabbos',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 1),
          layers: const [mainLayerId],
        ).toJson(),
      ],
    });

    // Parsed once, here; the write takes the value.
    final backup = BackupService.parse(json);
    final result = await BackupService(repo).importInto('b', backup);

    expect(result.events, hasLength(1));
    expect((await repo.getEvents('b')).single.id, 'e1');
  });

  test('a parsed backup can be handed to two things without being re-read',
      () async {
    // The preview and the write, in the order the screen does them. Same
    // instance both times, which is the whole of the change.
    final repo = memoryRepository();
    final backup = BackupService.parse(jsonEncode({
      'version': BackupService.currentVersion,
      'events': const [],
      'customNodes': const [],
    }));

    expect(await BackupService(repo).customisationsAtRisk('b', backup), 0);
    final result = await BackupService(repo)
        .importInto('b', backup, mode: ImportMode.restoreEverything);
    expect(result.removedCustomisations, 0);
  });

  /// And the rule, rather than the four sites that used to break it.
  test('only the file boundary turns backup text into a backup', () {
    const escapeHatch = 'backup-parse: ok';
    const definition = 'lib/application/backup_service.dart';
    // The one place untrusted bytes arrive: a file the user picked, or a string
    // they pasted. Both are in the settings screen, and both are one call.
    const boundary = 'lib/features/settings/settings_screen.dart';
    final banned = RegExp(r'BackupService\.parse\(|\bparse\(jsonStr\)');

    expect(banned.hasMatch('final data = BackupService.parse(jsonStr);'),
        isTrue);

    final violations = <String>[];
    var atBoundary = 0;
    for (final path in dartSourcesUnder()) {
      if (path == definition) continue;
      for (final line
          in codeLines(File(path).readAsStringSync(), escapeHatch: escapeHatch)) {
        if (!banned.hasMatch(line.text)) continue;
        if (path == boundary) {
          atBoundary++;
          continue;
        }
        violations.add('$path:${line.line}\n    ${line.text.trim()}');
      }
    }

    expect(violations, isEmpty,
        reason: 'pass the BackupData down instead. A second parse is a second '
            'full decode of a file that can be megabytes.\n\n'
            '${violations.join('\n')}');
    expect(atBoundary, 2,
        reason: 'exactly two: the file the user picked and the text they '
            'pasted. A third would be a third decode, and a first would mean '
            'this guard has stopped pointing at the boundary');
  });
}
