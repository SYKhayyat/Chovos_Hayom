import 'package:chovos_hayom/application/backup_service.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:chovos_hayom/features/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_progress_repository.dart';

/// The number a destructive confirmation shows has to be the number that
/// happens.
///
/// F5 in the 2026-07-29 grade, flagged there as reasoned-from-the-code and never
/// reproduced: the preview folded the backup's events against the profile's
/// **current** required-layer sets, and then the import overwrote those sets from
/// the backup. So when a backup carried different requirements, "N units will no
/// longer be marked" — and the identical numbers reused afterwards as the report
/// — described a state that never exists: the new log under the old rules.
///
/// This is the fixture that grade did not build. A unit is complete when the
/// required layers are all done, so changing the requirement from {main, rashi}
/// to {main} alone changes which units count without touching a single event.
void main() {
  const nodeId = 'shas.moed.shabbos';

  LearningEvent mark(String id, int unit, String layer) => LearningEvent(
        id: id,
        profileId: 'p1',
        nodeId: nodeId,
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 7, 1),
        loggedAt: DateTime(2026, 7, 1),
        layers: [layer],
      );

  /// A backup holding the text alone as the requirement, and two units of it
  /// learned.
  Future<String> textOnlyBackup() async {
    final source = InMemoryProgressRepository();
    await source.addEvents([mark('e2', 2, mainLayerId), mark('e3', 3, mainLayerId)]);
    return BackupService(source).export(
      'p1',
      customNodes: const [],
      requirements: const [
        LayerConfigEntry(nodeId: nodeId, unitIndex: -1, layers: {mainLayerId}),
      ],
    );
  }

  test('a backup that relaxes the requirement is previewed under its own rules',
      () async {
    final json = await textOnlyBackup();

    // Here and now, this profile requires Rashi as well, and has nothing logged.
    final repo = InMemoryProgressRepository();
    await repo.setLayerRequirement(
        'p1',
        const LayerConfigEntry(
            nodeId: nodeId, unitIndex: -1, layers: {mainLayerId, 'rashi'}));
    final currentRequired = LayerRequirements.fromEntries(
        await repo.watchLayerRequirements('p1').first);

    final diff = await SettingsScreen.restoreDiff(
      repo: repo,
      profileId: 'p1',
      currentRequired: currentRequired,
      catalogParents: const {nodeId: 'shas.moed'},
      json: json,
      mode: ImportMode.restoreEverything,
    );

    expect(diff.restored, 2,
        reason: 'the restore brings back the {main}-only requirement along with '
            'the events, so both units really are marked afterwards. Folded '
            'against the current {main, rashi} this reads 0, and the user is '
            'told a restore that visibly re-marks two dapim changes nothing');
    expect(diff.removed, 0);
  });

  test('the narrow restore is previewed under the merge it performs', () async {
    // restoreLog upserts the backup's requirements over what is here rather than
    // replacing them, and for this node the backup's row wins — so the answer is
    // the same 2. The difference between the modes shows up when the *profile*
    // holds a requirement the backup does not mention, which restoreLog keeps.
    final json = await textOnlyBackup();

    final repo = InMemoryProgressRepository();
    await repo.setLayerRequirement(
        'p1',
        const LayerConfigEntry(
            nodeId: 'other', unitIndex: -1, layers: {mainLayerId, 'rashi'}));
    final currentRequired = LayerRequirements.fromEntries(
        await repo.watchLayerRequirements('p1').first);

    final kept = await SettingsScreen.restoreDiff(
      repo: repo,
      profileId: 'p1',
      currentRequired: currentRequired,
      catalogParents: const {nodeId: 'shas.moed', 'other': null},
      json: json,
      mode: ImportMode.restoreLog,
    );
    final dropped = await SettingsScreen.restoreDiff(
      repo: repo,
      profileId: 'p1',
      currentRequired: currentRequired,
      catalogParents: const {nodeId: 'shas.moed', 'other': null},
      json: json,
      mode: ImportMode.restoreEverything,
    );

    expect(kept.restored, 2);
    expect(dropped.restored, 2);
    // The unrelated requirement is the one the two modes disagree about, and
    // only the wide one counts it as something it will delete.
    expect(kept.customisations, 0);
    expect(dropped.customisations, 1);
  });

  test('a unit the backup no longer completes is counted as lost', () async {
    // The mirror case, and the one the warning exists for: the backup requires
    // more than this profile does, so units marked today stop qualifying.
    final source = InMemoryProgressRepository();
    await source.addEvent(mark('e2', 2, mainLayerId));
    final json = await BackupService(source).export(
      'p1',
      customNodes: const [],
      requirements: const [
        LayerConfigEntry(
            nodeId: nodeId, unitIndex: -1, layers: {mainLayerId, 'rashi'}),
      ],
    );

    final repo = InMemoryProgressRepository();
    await repo.addEvent(mark('e2', 2, mainLayerId));

    final diff = await SettingsScreen.restoreDiff(
      repo: repo,
      profileId: 'p1',
      currentRequired: LayerRequirements.fromEntries(const []),
      catalogParents: const {nodeId: 'shas.moed'},
      json: json,
      mode: ImportMode.restoreEverything,
    );

    expect(diff.removed, 1,
        reason: 'the same event stops completing the unit once Rashi is '
            'required, and the confirmation has to say so');
    expect(diff.restored, 0);
  });
}
