import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/backup_service.dart';
import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/layer.dart';
import '../common/guarded.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Calendar'),
          RadioGroup<CalendarMode>(
            groupValue: settings.calendar,
            onChanged: (v) => guarded(context, ref,
                () => notifier.setCalendar(v ?? CalendarMode.gregorian),
                what: 'Changing the calendar'),
            child: const Column(
              children: [
                RadioListTile(
                  value: CalendarMode.gregorian,
                  title: Text('Secular (Gregorian)'),
                ),
                RadioListTile(value: CalendarMode.hebrew, title: Text('Hebrew')),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (v) => guarded(context, ref,
                () => notifier.setThemeMode(v ?? ThemeMode.system),
                what: 'Changing the theme'),
            child: const Column(
              children: [
                RadioListTile(value: ThemeMode.system, title: Text('Follow system')),
                RadioListTile(value: ThemeMode.light, title: Text('Light')),
                RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Hebrew (right-to-left) layout'),
            subtitle: const Text('Render the whole app in Hebrew RTL'),
            value: settings.hebrewLayout,
            onChanged: (v) => guarded(
                context, ref, () => notifier.setHebrewLayout(v),
                what: 'Changing the layout direction'),
          ),
          const Divider(),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            title: const Text('Daily learning nudge'),
            subtitle: const Text(
                'Show a reminder in the app if you have not learned today'),
            value: settings.reminderEnabled,
            onChanged: (v) => guarded(
                context, ref, () => notifier.setReminderEnabled(v),
                what: 'Changing the daily nudge'),
          ),
          const Divider(),
          const _SectionHeader('Chazara'),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Review intervals'),
            subtitle: Text('${settings.chazaraIntervals.join(', ')} days '
                'after each pass'),
            onTap: () => _editIntervals(context, ref, settings.chazaraIntervals),
          ),
          const Divider(),
          const _SectionHeader('Mefarshim bars'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Show or hide each meforish’s coverage line under the '
                'tree’s progress bars.'),
          ),
          for (final layer in ref.watch(allLayersProvider))
            if (layer.id != mainLayerId)
              SwitchListTile(
                title: Text(layer.name),
                subtitle:
                    layer.nameHebrew != null ? Text(layer.nameHebrew!) : null,
                value: settings.showsMeforishBar(layer.id),
                onChanged: (v) => guarded(context, ref,
                    () => notifier.setMeforishBarVisible(layer.id, v),
                    what: '${v ? 'Showing' : 'Hiding'} the ${layer.name} bar'),
              ),
          const Divider(),
          const _SectionHeader('Profiles'),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Manage profiles'),
            onTap: () => Navigator.pushNamed(context, Routes.profiles),
          ),
          const Divider(),
          const _SectionHeader('History'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Bulk action history'),
            subtitle: Text(() {
              final n = ref.watch(batchHistoryProvider).length;
              return n == 0
                  ? 'Undo a finish-all or clear-all, any time'
                  : '$n undoable ${n == 1 ? 'action' : 'actions'}';
            }()),
            onTap: () => Navigator.pushNamed(context, Routes.bulkHistory),
          ),
          const Divider(),
          const _SectionHeader('Backup'),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Export to file'),
            subtitle: const Text('Save all progress as a JSON file'),
            onTap: () => _exportToFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Import from file'),
            subtitle: const Text('Restore/merge from a saved JSON file'),
            onTap: () => _importFromFile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export to clipboard'),
            subtitle: const Text('Copy all progress as JSON'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import from clipboard'),
            subtitle: const Text('Paste a previous export to restore/merge'),
            onTap: () => _import(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Crash log'),
            subtitle: const Text(
                'Kept on this device only — copy it into a bug report'),
            onTap: () => Navigator.pushNamed(context, Routes.crashLog),
          ),
          const Divider(),
          const _SectionHeader('Reset'),
          ListTile(
            leading: Icon(Icons.restart_alt,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Clear settings'),
            subtitle: const Text('Reset preferences, goals, custom sefarim, '
                'mefarshim, and required-set settings. Your learning log is '
                'kept.'),
            onTap: () => _clearSettings(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSettings(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all settings?'),
        content: const Text(
            'This resets preferences and removes your goals, custom sefarim, '
            'custom mefarshim, and required-mefarshim settings. Your learning '
            'log (everything you marked done) is not touched.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear')),
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
      what: 'Clearing your settings',
      success: 'Settings cleared',
    );
  }

  Future<void> _editIntervals(
      BuildContext context, WidgetRef ref, List<int> current) async {
    final guard = WriteGuard.of(context, ref);
    final ctrl = TextEditingController(text: current.join(', '));
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chazara review intervals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Days after each pass before the next review is due, e.g. '
                '"1, 3, 7, 16, 35, 70". The last value repeats after that.'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(hintText: '1, 3, 7, 16, 35, 70'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text),
              child: const Text('Save')),
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
        what: 'Saving your chazara intervals');
  }

  Future<String> _buildExport(WidgetRef ref) async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    return BackupService(repo).export(
      profileId,
      customNodes: ref.read(customNodesProvider).asData?.value ?? const [],
      customLayers: ref.read(customLayersProvider).asData?.value ?? const [],
      requirements: ref.read(layerConfigProvider).asData?.value ?? const [],
      offered: ref.read(offeredConfigProvider).asData?.value ?? const [],
      settings: ref.read(settingsProvider.notifier).toBackup(),
      goals: ref.read(goalsProvider),
    );
  }

  /// Import [jsonStr], applying repo data + settings + goals. Returns events
  /// added. Validation and the repository write happen inside `importInto`; the
  /// preference-backed parts (settings, goals) are applied after it succeeds.
  Future<int> _applyImport(WidgetRef ref, String jsonStr) async {
    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    // The catalog's ids, so a custom sefer filed under a built-in one validates
    // instead of being rejected as an orphan.
    final catalog = ref.read(mergedCatalogProvider).asData?.value;
    final data = await BackupService(repo).importInto(
      profileId,
      jsonStr,
      knownNodeIds: {
        if (catalog != null)
          for (final n in catalog.all) n.id,
      },
    );
    await ref.read(settingsProvider.notifier).applyBackup(data.settings);
    await ref.read(goalsProvider.notifier).applyBackup(data.goals);
    return data.events.length;
  }

  /// Import failures are shown verbatim when we know what is wrong — "unit count
  /// is negative" tells the user which file to stop using; "invalid data" does
  /// not.
  static String _importError(Object e) => e is BackupFormatException
      ? 'Import failed: ${e.message}'
      : 'Import failed: the file could not be read.';

  /// Backup and restore report through the same guard as every other write.
  /// They keep their own *success* wording only because "cancelled" is neither a
  /// success nor a failure — the file dialog closing without a choice is not
  /// something to apologise for.
  Future<void> _exportToFile(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    var cancelled = false;
    final ok = await guard.run(
      () async {
        final json = await _buildExport(ref);
        final path = await FilePicker.saveFile(
          dialogTitle: 'Save backup',
          fileName: 'chovos_hayom_backup.json',
          bytes: utf8.encode(json),
        );
        cancelled = path == null;
      },
      what: 'Exporting your backup',
    );
    if (!ok) return;
    guard.report(cancelled ? 'Export cancelled' : 'Saved backup');
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    String? outcome;
    await guard.run(
      () async {
        final result = await FilePicker.pickFiles(
          dialogTitle: 'Choose a backup file',
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true,
        );
        final bytes = result?.files.single.bytes;
        if (bytes == null) {
          outcome = 'Import cancelled';
          return;
        }
        outcome = 'Imported ${await _applyImport(ref, utf8.decode(bytes))} '
            'new events';
      },
      what: 'Importing your backup',
      describe: _importError,
    );
    final message = outcome;
    if (message != null) guard.report(message);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    await guard.run(
      () async => Clipboard.setData(ClipboardData(text: await _buildExport(ref))),
      what: 'Exporting to the clipboard',
      success: 'Exported to clipboard',
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final ctrl = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import data'),
          content: TextField(
            controller: ctrl,
            maxLines: 6,
            decoration:
                const InputDecoration(hintText: 'Paste export JSON here'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
                child: const Text('Import')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    final payload = text ?? '';
    if (payload.isEmpty) return;

    var added = 0;
    final ok = await guard.run(
      () async => added = await _applyImport(ref, payload),
      what: 'Importing your backup',
      describe: _importError,
    );
    if (!ok) return;
    guard.report('Imported $added new events');
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
