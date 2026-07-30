import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/data/drift/database.dart';
import 'package:chovos_hayom/data/repositories/drift_progress_repository.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/profile.dart';

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
/// reconciled. Custom sefarim, custom mefarshim and the required/offered layer
/// configs go through `addCustomNode`/`setLayerRequirement`, which upsert. A row
/// the backup does not contain is never removed.
///
/// So a custom sefer invented after the backup survives the restore that said it
/// would undo it. `backup_service_test.dart` covers the merge and the replace of
/// *events*; nothing asserts on the non-event rows under `replace: true`.
void main() {
  late AppDatabase db;
  late DriftProgressRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftProgressRepository(db);
  });

  tearDown(() => db.close());

  test('restoring undoes a custom sefer added after the backup', () async {
    await repo.addProfile(
        Profile(id: 'p1', name: 'Reuven', createdAt: DateTime(2026)));

    // A backup is taken while the profile is clean.
    final service = BackupService(repo);
    final backup = await service.export('p1', customNodes: const []);

    // Afterwards the user invents a sefer they later regret.
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
    expect((await repo.watchCustomNodes('p1').first).length, 1);

    // "Restore from file" — "undoing anything recorded since it".
    await service.importInto('p1', backup, replace: true);

    expect(await repo.watchCustomNodes('p1').first, isEmpty,
        reason: 'the restore promised to undo everything recorded since the '
            'backup, but only the event log was reconciled');
  });
}
