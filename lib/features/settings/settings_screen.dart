import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/backup_service.dart';
import '../../application/backup_status.dart';
import '../../application/cycles.dart';
import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/learning_event.dart';
import '../../domain/usecases/fold_log.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';

/// What a restore would change, in the terms the user actually sees.
///
/// Reporting a restore as "removed 2 events, added 0" is true of the log and
/// useless to a reader: un-marking a unit *appends* an `undone` rather than
/// deleting the `done`, so putting that unit back means **deleting** an event,
/// never adding one — and the count reads as though nothing came back even as
/// the daf visibly returns. The log is internal; units are what the user has.
class RestoreDiff {
  const RestoreDiff({
    required this.restored,
    required this.removed,
    required this.staleEvents,
  });

  /// Units the backup has marked that this profile currently does not.
  final int restored;

  /// Units currently marked that the backup does not have.
  final int removed;

  /// Log entries recorded since the backup, which the restore deletes.
  final int staleEvents;

  bool get changesNothing => restored == 0 && removed == 0 && staleEvents == 0;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsSectionCalendar),
          RadioGroup<CalendarMode>(
            groupValue: settings.calendar,
            onChanged: (v) => guarded(context, ref,
                () => notifier.setCalendar(v ?? CalendarMode.gregorian),
                what: l10n.whatChangingCalendar),
            child: Column(
              children: [
                RadioListTile(
                  value: CalendarMode.gregorian,
                  title: Text(l10n.settingsCalendarGregorian),
                ),
                RadioListTile(
                    value: CalendarMode.hebrew,
                    title: Text(l10n.settingsCalendarHebrew)),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionAppearance),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (v) => guarded(context, ref,
                () => notifier.setThemeMode(v ?? ThemeMode.system),
                what: l10n.whatChangingTheme),
            child: Column(
              children: [
                RadioListTile(
                    value: ThemeMode.system,
                    title: Text(l10n.settingsThemeSystem)),
                RadioListTile(
                    value: ThemeMode.light,
                    title: Text(l10n.settingsThemeLight)),
                RadioListTile(
                    value: ThemeMode.dark, title: Text(l10n.settingsThemeDark)),
              ],
            ),
          ),
          // Now a language switch, not just a direction one: this selects the
          // Hebrew string table as well as flipping the layout. The old label
          // ("Hebrew right-to-left layout") described what it could do before
          // the app's own text was translated.
          SwitchListTile(
            title: Text(l10n.settingsLanguage),
            subtitle: Text(l10n.settingsLanguageSubtitle),
            value: settings.hebrewLayout,
            onChanged: (v) => guarded(
                context, ref, () => notifier.setHebrewLayout(v),
                what: l10n.whatChangingLanguage),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionReminders),
          SwitchListTile(
            title: Text(l10n.settingsDailyNudge),
            subtitle: Text(l10n.settingsDailyNudgeSubtitle),
            value: settings.reminderEnabled,
            onChanged: (v) => guarded(
                context, ref, () => notifier.setReminderEnabled(v),
                what: l10n.whatChangingNudge),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionChazara),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(l10n.settingsReviewIntervals),
            subtitle: Text(l10n.settingsReviewIntervalsSubtitle(
                settings.chazaraIntervals.join(', '))),
            onTap: () => _editIntervals(context, ref, settings.chazaraIntervals),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionMeforishBars),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(l10n.settingsMeforishBarsExplainer),
          ),
          for (final layer in ref.watch(allLayersProvider))
            if (layer.id != mainLayerId)
              _MeforishBarSwitch(layer: layer),
          const Divider(),
          _SectionHeader(l10n.settingsSectionProfiles),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(l10n.settingsManageProfiles),
            onTap: () => Navigator.pushNamed(context, Routes.profiles),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionHistory),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.settingsBulkHistory),
            subtitle: Text(() {
              final n = ref.watch(batchHistoryProvider).length;
              return n == 0
                  ? l10n.settingsBulkHistoryEmpty
                  : l10n.settingsBulkHistoryCount(n);
            }()),
            onTap: () => Navigator.pushNamed(context, Routes.bulkHistory),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionBackup),
          // What the export is *for*, stated where the export is. Everything
          // else in this section is a verb; this is the fact that makes the
          // verbs matter.
          const _BackupStandingTile(),
          SwitchListTile(
            title: Text(l10n.settingsBackupReminder),
            subtitle: Text(l10n.settingsBackupReminderSubtitle),
            value: settings.backupReminderEnabled,
            onChanged: (v) => guarded(
                context, ref, () => notifier.setBackupReminderEnabled(v),
                what: l10n.whatChangingBackupReminder),
          ),
          if (settings.backupReminderEnabled)
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.settingsBackupInterval),
              subtitle: Text(
                  l10n.settingsBackupIntervalSubtitle(settings.backupIntervalDays)),
              onTap: () =>
                  _editBackupInterval(context, ref, settings.backupIntervalDays),
            ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.settingsExportFile),
            subtitle: Text(l10n.settingsExportFileSubtitle),
            onTap: () => _exportToFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(l10n.settingsImportFile),
            subtitle: Text(l10n.settingsImportFileSubtitle),
            onTap: () => _importFromFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.settingsRestoreFile),
            subtitle: Text(l10n.settingsRestoreFileSubtitle),
            onTap: () => _importFromFile(context, ref, replace: true),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(l10n.settingsExportClipboard),
            subtitle: Text(l10n.settingsExportClipboardSubtitle),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.settingsImportClipboard),
            subtitle: Text(l10n.settingsImportClipboardSubtitle),
            onTap: () => _import(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.settingsCrashLog),
            subtitle: Text(l10n.settingsCrashLogSubtitle),
            onTap: () => Navigator.pushNamed(context, Routes.crashLog),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsSectionReset),
          ListTile(
            leading: Icon(Icons.restart_alt,
                color: Theme.of(context).colorScheme.error),
            title: Text(l10n.settingsClearSettings),
            subtitle: Text(l10n.settingsClearSettingsSubtitle),
            onTap: () => _clearSettings(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSettings(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsClearTitle),
        content: Text(l10n.settingsClearBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.actionClear)),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final settings = ref.read(settingsProvider.notifier);
    final goals = ref.read(goalsProvider.notifier);

    await guard.run(
      () async {
        // Straight from the repository, not from the providers that cache it.
        // These four were `.asData?.value ?? const []`, which turns a provider
        // still in flight — or one nothing on this screen keeps alive — into an
        // empty list: a clear that silently skips exactly the rows it was asked
        // to remove, and then reports success for it.
        final customNodes = await repo.watchCustomNodes(profileId).first;
        final customLayers = await repo.watchCustomLayers(profileId).first;
        final requirements = await repo.watchLayerRequirements(profileId).first;
        final offered = await repo.watchOfferedLayers(profileId).first;

        await settings.clearAll();
        // Goals are configuration, not history: they travel with the settings
        // in a backup, and `GoalsController.clearAll` was written for this call
        // and then never wired to it — so "clear settings" left every target
        // date behind while claiming to have reset the preferences.
        await goals.clearAll();
        // Cycles are per-profile prefs (`PrefKeys.cycles` ∈ perProfile), so
        // `settings.clearAll` already removed them from disk — but their own
        // controller cached them at build time, so invalidate it to re-read the
        // now-empty pref, or the screen keeps showing cycles that no longer exist.
        ref.invalidate(cyclesConfigProvider);
        // One transaction for the repository half: a clear that dies partway
        // used to leave some custom sefarim gone and others still there, with
        // nothing to tell the user which.
        await repo.transaction(() async {
          for (final n in customNodes) {
            await repo.removeCustomNode(profileId, n.id);
          }
          for (final l in customLayers) {
            await repo.removeCustomLayer(profileId, l.id);
          }
          for (final r in requirements) {
            await repo.clearLayerRequirement(profileId, r.nodeId, r.unitIndex);
          }
          for (final o in offered) {
            await repo.clearOfferedLayers(profileId, o.nodeId, o.unitIndex);
          }
        });
      },
      what: l10n.whatClearingSettings,
      success: l10n.settingsCleared,
    );
  }

  Future<void> _editIntervals(
      BuildContext context, WidgetRef ref, List<int> current) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current.join(', '));
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsIntervalsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsIntervalsBody),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.text,
              decoration:
                  InputDecoration(hintText: l10n.settingsIntervalsHint),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text),
              child: Text(l10n.actionSave)),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null) return;
    final intervals = [
      for (final part in text.split(','))
        if (int.tryParse(part.trim()) case final n?) if (n > 0) n,
    ];
    final settings = ref.read(settingsProvider.notifier);
    await guard.run(() => settings.setChazaraIntervals(intervals),
        what: l10n.whatSavingIntervals);
  }

  Future<void> _editBackupInterval(
      BuildContext context, WidgetRef ref, int current) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: current.toString());
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.settingsBackupInterval),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.settingsBackupIntervalBody),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.settingsBackupIntervalLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.actionCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, ctrl.text),
                child: Text(l10n.actionSave)),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (text == null) return;
    final days = int.tryParse(text.trim()) ?? 0;
    if (days <= 0) {
      guard.report(l10n.settingsBackupIntervalInvalid);
      return;
    }
    await guard.run(
        () => ref.read(settingsProvider.notifier).setBackupIntervalDays(days),
        what: l10n.whatSavingBackupInterval);
  }

  /// Everything the backup carries, read from where it lives.
  ///
  /// The four repository-backed lists used to come off their providers as
  /// `.asData?.value ?? const []`. A provider still in flight — or one nothing
  /// on this screen keeps alive — reads as an **empty list**, which means a
  /// backup that silently leaves out your custom sefarim, your custom mefarshim
  /// and every required/offered set, and says "Saved backup" about it. That is
  /// the same defect goals had before they were added here, and a backup you
  /// only discover is incomplete when you restore it is the worst kind.
  Future<String> _buildExport(WidgetRef ref) async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    return BackupService(repo).export(
      profileId,
      customNodes: await repo.watchCustomNodes(profileId).first,
      customLayers: await repo.watchCustomLayers(profileId).first,
      requirements: await repo.watchLayerRequirements(profileId).first,
      offered: await repo.watchOfferedLayers(profileId).first,
      settings: ref.read(settingsProvider.notifier).toBackup(),
      goals: ref.read(goalsProvider),
    );
  }

  /// Import [jsonStr], applying repo data + settings + goals. Returns a sentence
  /// describing what actually happened. Validation and the repository write
  /// happen inside `importInto`; the preference-backed parts (settings, goals)
  /// are applied after it succeeds.
  ///
  /// Import is a **merge**: it adds events the profile doesn't already have, and
  /// never removes ones it does. Re-importing a backup into the profile it came
  /// from therefore adds nothing — the normal, correct outcome, which a bare
  /// "Imported 0 new events" makes look like a failure. So the message says
  /// which of the two it was.
  Future<String> _applyImport(
      WidgetRef ref, AppLocalizations l10n, String jsonStr,
      {bool replace = false, RestoreDiff? diff}) async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    // The catalog's ids, so a custom sefer filed under a built-in one validates
    // instead of being rejected as an orphan.
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    final data = await BackupService(repo).importInto(
      profileId,
      jsonStr,
      knownParents: {
        if (catalog != null)
          for (final n in catalog.all) n.id: n.parentId,
      },
      replace: replace,
    );
    await ref.read(settingsProvider.notifier).applyBackup(data.settings);
    await ref.read(goalsProvider.notifier).applyBackup(data.goals);
    // Cycles ride in the settings map (they are a per-profile preference) but
    // are owned by a separate controller that read the pref at build time, so it
    // must re-read now that applyBackup has rewritten it — otherwise the imported
    // cycles are on disk but not on screen until the next launch.
    ref.invalidate(cyclesConfigProvider);

    if (replace) {
      // Reported in units, not events. A restore that puts a daf back does it by
      // *deleting* the later `undone`, so an event-level tally reads "removed 2,
      // added 0" while the user watches a completion return.
      return restoreSummary(
          l10n,
          diff ??
              RestoreDiff(
                restored: 0,
                removed: 0,
                staleEvents: data.removedEvents,
              ));
    }
    final added = data.events.length;
    if (added > 0) return l10n.backupImported(added);
    // Nothing new. Say which kind of nothing it was, because "0" alone reads as
    // a failed import. Re-parsing costs one pass over a file the user just
    // chose, and only on this path.
    final inFile = BackupService.parse(jsonStr).events.length;
    return inFile == 0
        ? l10n.backupNoEvents
        : l10n.backupAlreadyUpToDate(inFile);
  }

  /// Import failures are shown verbatim when we know what is wrong — "unit count
  /// is negative" tells the user which file to stop using; "invalid data" does
  /// not.
  ///
  /// The validator's own message is still English: it names a field of the
  /// backup format, and the format is not translated. Everything around it is.
  static String importError(AppLocalizations l10n, Object e) =>
      e is BackupFormatException
          ? l10n.backupImportFailed(e.message)
          : l10n.backupImportUnreadable;

  /// Backup and restore report through the same guard as every other write.
  /// They keep their own *success* wording only because "cancelled" is neither a
  /// success nor a failure — the file dialog closing without a choice is not
  /// something to apologise for.
  /// Whether the picker writes the chosen file itself.
  ///
  /// On Android and iOS it does — it *requires* the bytes and writes them
  /// through the storage-access framework, because the app has no path of its
  /// own to write to. On every desktop platform `saveFile` only runs the dialog
  /// and returns the chosen path, ignoring the bytes entirely, so the write is
  /// ours. Getting this wrong is silent in the worst way: the dialog succeeds,
  /// the guard reports "Saved backup", and nothing was ever written.
  static bool get _pickerWritesTheFile => Platform.isAndroid || Platform.isIOS;

  /// [path] with a `.json` suffix — the extension the import dialog filters for.
  /// A backup saved as `my-backup` cannot be selected in the dialog that
  /// restores it, and an export you cannot import is not a backup.
  static String withJsonExtension(String path) =>
      path.toLowerCase().endsWith('.json') ? path : '$path.json';

  Future<void> _exportToFile(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    var cancelled = false;
    final ok = await guard.run(
      () async {
        final json = await _buildExport(ref);
        final bytes = utf8.encode(json);
        final path = await FilePicker.platform.saveFile(
          dialogTitle: l10n.backupSaveDialogTitle,
          fileName: 'chovos_hayom_backup.json',
          // Constrain the dialog to .json, so what gets written is what the
          // import dialog can see.
          type: FileType.custom,
          allowedExtensions: ['json'],
          // Required on Android/iOS; ignored on desktop — see above.
          bytes: bytes,
        );
        if (path == null) {
          cancelled = true;
          return;
        }
        if (!_pickerWritesTheFile) {
          await File(withJsonExtension(path)).writeAsBytes(bytes, flush: true);
        }
      },
      what: l10n.whatExportingBackup,
    );
    if (!ok) return;
    // Recorded only here: after the write returned, and only when the user
    // actually chose a destination. Stamping it before the dialog — or on a
    // cancel — would mark the profile safe when nothing was written, which is
    // the one failure mode this whole feature exists to prevent.
    if (!cancelled) await _recordBackup(ref);
    guard.report(cancelled ? l10n.backupExportCancelled : l10n.backupSaved);
  }

  /// Stamp the profile as exported, now.
  Future<void> _recordBackup(WidgetRef ref) => ref
      .read(lastBackupProvider.notifier)
      .record(ref.read(clockProvider)());

  Future<void> _importFromFile(BuildContext context, WidgetRef ref,
      {bool replace = false}) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle:
          replace ? l10n.backupChooseRestoreFile : l10n.backupChooseFile,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) {
      guard.report(replace
          ? l10n.backupRestoreCancelled
          : l10n.backupImportCancelled);
      return;
    }
    final json = utf8.decode(bytes);

    // A restore undoes learning, so it says exactly what it will change before
    // it does — computed from the file the user just chose, not estimated.
    RestoreDiff? diff;
    if (replace) {
      try {
        diff = await _restoreDiff(ref, json);
      } catch (e) {
        guard.report(importError(l10n, e));
        return;
      }
      if (!context.mounted) return;
      if (!await _confirmRestore(context, diff)) return;
    }

    String? outcome;
    await guard.run(
      () async => outcome =
          await _applyImport(ref, l10n, json, replace: replace, diff: diff),
      what: replace ? l10n.whatRestoringBackup : l10n.whatImportingBackup,
      describe: (e) => importError(l10n, e),
    );
    final message = outcome;
    if (message != null) guard.report(message);
  }

  /// What restoring [json] would do to this profile, in units.
  ///
  /// Restoring makes the log exactly match the backup, so folding the backup's
  /// events *is* the state afterwards — the prediction and the outcome are the
  /// same numbers, which is why one calculation serves both the warning and the
  /// report.
  Future<RestoreDiff> _restoreDiff(WidgetRef ref, String json) async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final required = ref.read(layerRequirementsProvider);
    final backup = BackupService.parse(json);
    final current = await repo.getEvents(profileId);

    Set<String> marked(Iterable<LearningEvent> events) {
      final fold = FoldLog.fold(events);
      return {
        for (final nodeId in fold.completedByNode.keys)
          for (final unit in fold.doneUnits(nodeId, required)) '$nodeId $unit',
      };
    }

    final now = marked(current);
    final restored = marked(backup.events);
    final backupIds = backup.events.map((e) => e.id).toSet();
    return RestoreDiff(
      restored: restored.difference(now).length,
      removed: now.difference(restored).length,
      staleEvents: current.where((e) => !backupIds.contains(e.id)).length,
    );
  }

  /// A sentence describing [diff] in units, for the report after a restore.
  static String restoreSummary(AppLocalizations l10n, RestoreDiff diff) {
    if (diff.changesNothing) return l10n.restoreAlreadyMatched;
    final parts = [
      if (diff.restored > 0) l10n.restoreSummaryRestored(diff.restored),
      if (diff.removed > 0) l10n.restoreSummaryRemoved(diff.removed),
    ];
    return parts.isEmpty
        // The log changed but nothing you can see did — e.g. only a re-log of
        // the same unit with a different date was undone. Say so plainly.
        ? l10n.restoreNoUnitChange
        : l10n.restoreSummary(parts.join('; '));
  }

  /// Confirms a restore, describing what it will change. Returns false if the
  /// file is unreadable (the error is shown) or the user backs out.
  Future<bool> _confirmRestore(BuildContext context, RestoreDiff diff) async {
    final l10n = AppLocalizations.of(context);
    final losing = diff.removed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(diff.changesNothing
            ? l10n.restoreConfirmNoChange
            : [
                l10n.restoreConfirmIntro,
                if (losing > 0) l10n.restoreConfirmLosing(losing),
                if (diff.restored > 0)
                  l10n.restoreConfirmGaining(diff.restored),
                l10n.restoreConfirmBackupFirst,
              ].join('\n\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: losing == 0
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  ),
            child: Text(l10n.actionRestore),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final ok = await guard.run(
      () async => Clipboard.setData(ClipboardData(text: await _buildExport(ref))),
      what: l10n.whatExportingClipboard,
      success: l10n.backupExportedClipboard,
    );
    // A clipboard export counts: the data left the app, which is what the
    // reminder is asking about. Where the user pastes it is their business.
    if (ok) await _recordBackup(ref);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.backupImportTitle),
          content: TextField(
            controller: ctrl,
            maxLines: 6,
            decoration: InputDecoration(hintText: l10n.backupImportHint),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.actionCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
                child: Text(l10n.actionImport)),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    final payload = text ?? '';
    if (payload.isEmpty) return;

    var outcome = '';
    final ok = await guard.run(
      () async => outcome = await _applyImport(ref, l10n, payload),
      what: l10n.whatImportingBackup,
      describe: (e) => importError(l10n, e),
    );
    if (!ok) return;
    guard.report(outcome);
  }
}

/// Where this profile stands: when it was last exported, and what has happened
/// since. Green once there is nothing unsaved, so the answer is readable at a
/// glance rather than needing arithmetic on a date.
class _BackupStandingTile extends ConsumerWidget {
  const _BackupStandingTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(backupStatusProvider);
    final mode = ref.watch(settingsProvider).calendar;
    final scheme = Theme.of(context).colorScheme;
    final safe = status.unsavedUnits == 0;

    return ListTile(
      leading: Icon(
        safe ? Icons.verified_outlined : Icons.shield_outlined,
        color: safe ? Colors.green : scheme.error,
      ),
      title: Text(status.neverBackedUp
          ? l10n.backupNeverExported
          : l10n.backupLastExported(
              DateDisplay.format(status.lastBackupAt!, mode))),
      subtitle: Text(safe
          ? l10n.backupNothingUnsaved
          : l10n.backupUnsavedUnits(status.unsavedUnits)),
    );
  }
}

/// One meforish's "show its coverage bar" switch.
///
/// Its own widget so the layer's localized name is resolved once and used by
/// both the row and the message its write reports under.
class _MeforishBarSwitch extends ConsumerWidget {
  const _MeforishBarSwitch({required this.layer});
  final Layer layer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final primary = layerName(l10n, layer);
    final secondary = primary == layer.name ? layer.nameHebrew : layer.name;
    return SwitchListTile(
      title: Text(primary),
      subtitle: secondary == null || secondary == primary
          ? null
          : Text(secondary),
      value: settings.showsMeforishBar(layer.id),
      onChanged: (v) => guarded(
        context,
        ref,
        () => ref
            .read(settingsProvider.notifier)
            .setMeforishBarVisible(layer.id, v),
        what: v ? l10n.whatShowingBar(primary) : l10n.whatHidingBar(primary),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
