import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';

import '../support/memory_database.dart';

/// GRADER PROBE — what "restore" actually restores.
///
/// The UI promises, in three places:
///   settingsRestoreFileSubtitle: "Make this profile exactly match a backup,
///                                 undoing anything recorded since it"
///   restoreConfirmIntro:         "This makes the profile exactly match the
///                                 backup, undoing everything recorded since it."
///
/// `BackupService.importInto`'s own doc is narrower and accurate — "the
/// profile's **log** is made to match the backup exactly" — and only the log is
/// reconciled. Custom sefarim, custom mefarshim and the layer settings go
/// through `addCustomNode`/`setLayerConfig`, which upsert. A row the backup does
/// not contain is never removed.
///
/// So a custom sefer invented after the backup survives the restore that said it
/// would undo it. `backup_service_test.dart` covers the merge and the replace of
/// *events*; nothing asserts on the non-event rows under `replace: true`.
///
/// **BUILDER NOTE (W5).** The owner's ruling on the gap was neither of the two
/// options the grade offered: keep today's narrow restore *and* add a wide one,
/// as separate actions, because "undo my learning back to this backup" and
/// "throw away everything this profile has become" are different intentions and
/// only one of them deletes a sefer. So `bool replace` became [ImportMode], and
/// this probe now pins both halves — the wide mode deletes the sefer, and the
/// narrow one is asserted to keep it, which is the promise its copy now makes.
void main() {
  late DriftProgressRepository repo;

  setUp(() {
    repo = memoryRepository();
  });

  /// Takes a backup of a clean profile, then invents a sefer the user regrets.
  Future<String> backupThenAddASefer() async {
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));
    final backup = await BackupService(repo).export('p1', customNodes: const []);
    await repo.addCustomNode(
      'p1',
      const CatalogNode(
        id: 'custom.oops',
        parentId: null,
        name: 'Typo Sefer',
        kind: NodeKind.sefer,
        unitCount: 10,
      ),
    );
    expect((await repo.getCustomNodes('p1')).length, 1);
    return backup;
  }

  test('"Restore everything" undoes a custom sefer added after the backup',
      () async {
    final backup = await backupThenAddASefer();

    final result = await BackupService(repo)
        .importInto('p1', backup, mode: ImportMode.restoreEverything);

    expect(await repo.getCustomNodes('p1'), isEmpty,
        reason: 'this is the restore that promises to undo everything recorded '
            'since the backup');
    expect(result.removedCustomisations, 1,
        reason: 'and it has to be able to say how much, before it does it');
  });

  test('"Restore learning" keeps it, which is what its copy now says', () async {
    final backup = await backupThenAddASefer();

    final result = await BackupService(repo)
        .importInto('p1', backup, mode: ImportMode.restoreLog);

    expect((await repo.getCustomNodes('p1')).single.id, 'custom.oops',
        reason: 'the narrow restore reconciles the log and nothing else — '
            '"Custom sefarim, mefarshim and settings are kept"');
    expect(result.removedCustomisations, 0);
  });
}
