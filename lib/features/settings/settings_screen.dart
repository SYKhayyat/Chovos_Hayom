import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/backup_service.dart';
import '../../application/goals.dart';
import '../../application/providers.dart';
import '../../application/settings.dart';
import '../../core/calendar.dart';
import '../../domain/entities/layer.dart';
import '../history/bulk_history_screen.dart';
import '../profiles/profiles_screen.dart';
import 'crash_log_screen.dart';

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
            onChanged: (v) => notifier.setCalendar(v ?? CalendarMode.gregorian),
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
            onChanged: (v) => notifier.setThemeMode(v ?? ThemeMode.system),
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
            onChanged: notifier.setHebrewLayout,
          ),
          const Divider(),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            title: const Text('Daily learning nudge'),
            subtitle: const Text(
                'Show a reminder in the app if you have not learned today'),
            value: settings.reminderEnabled,
            onChanged: notifier.setReminderEnabled,
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
                onChanged: (v) => notifier.setMeforishBarVisible(layer.id, v),
              ),
          const Divider(),
          const _SectionHeader('Profiles'),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Manage profiles'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilesScreen()),
            ),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkHistoryScreen()),
            ),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CrashLogScreen()),
            ),
          ),
          const Divider(),
          const _SectionHeader('Reset'),
          ListTile(
            leading: Icon(Icons.restart_alt,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Clear settings'),
            subtitle: const Text('Reset preferences, custom sefarim, mefarshim, '
                'and required-set settings. Your learning log is kept.'),
            onTap: () => _clearSettings(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSettings(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all settings?'),
        content: const Text(
            'This resets preferences and removes your custom sefarim, custom '
            'mefarshim, and required-mefarshim settings. Your learning log '
            '(everything you marked done) is not touched.'),
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
    await ref.read(settingsProvider.notifier).clearAll();
    for (final n in ref.read(customNodesProvider).asData?.value ?? const []) {
      await repo.removeCustomNode(profileId, n.id);
    }
    for (final l in ref.read(customLayersProvider).asData?.value ?? const []) {
      await repo.removeCustomLayer(profileId, l.id);
    }
    for (final r in ref.read(layerConfigProvider).asData?.value ?? const []) {
      await repo.clearLayerRequirement(profileId, r.nodeId, r.unitIndex);
    }
    for (final o in ref.read(offeredConfigProvider).asData?.value ?? const []) {
      await repo.clearOfferedLayers(profileId, o.nodeId, o.unitIndex);
    }
    messenger.showSnackBar(const SnackBar(content: Text('Settings cleared')));
  }

  Future<void> _editIntervals(
      BuildContext context, WidgetRef ref, List<int> current) async {
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
    await ref.read(settingsProvider.notifier).setChazaraIntervals(intervals);
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

  Future<void> _exportToFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await _buildExport(ref);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup',
        fileName: 'chovos_hayom_backup.json',
        bytes: utf8.encode(json),
      );
      messenger.showSnackBar(SnackBar(
        content: Text(path == null ? 'Export cancelled' : 'Saved backup'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose a backup file',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Import cancelled')));
        return;
      }
      final added = await _applyImport(ref, utf8.decode(bytes));
      messenger.showSnackBar(
          SnackBar(content: Text('Imported $added new events')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(_importError(e)), duration: const Duration(seconds: 8)));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final json = await _buildExport(ref);
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported to clipboard')),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Import data'),
          content: TextField(
            controller: ctrl,
            maxLines: 6,
            decoration:
                const InputDecoration(hintText: 'Paste export JSON here'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Import')),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (text == null || text.isEmpty) return;

    try {
      final added = await _applyImport(ref, text);
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $added new events')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(_importError(e)), duration: const Duration(seconds: 8)));
    }
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
