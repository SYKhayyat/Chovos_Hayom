import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../common/guarded.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('New profile'),
        onPressed: () => _createDialog(context, ref),
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => ListView(
          children: [
            for (final p in list)
              ListTile(
                leading: Icon(p.id == active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(p.name),
                subtitle: p.id == active ? const Text('Active') : null,
                onTap: () => guarded(
                  context,
                  ref,
                  () => ref.read(activeProfileProvider.notifier).setProfile(p.id),
                  what: 'Switching to "${p.name}"',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') _renameDialog(context, ref, p.id, p.name);
                    if (v == 'delete') _confirmDelete(context, ref, p.id, p.name);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: list.length > 1,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDialog(
      BuildContext context, WidgetRef ref, String id, String current) async {
    final guard = WriteGuard.of(context, ref);
    final profiles = ref.read(profilesProvider.notifier);
    final name = await _promptForName(context,
        title: 'Rename profile', action: 'Save', initial: current);
    if (name == null || name.isEmpty) return;
    await guard.run(() => profiles.rename(id, name),
        what: 'Renaming "$current" to "$name"');
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final guard = WriteGuard.of(context, ref);
    final profiles = ref.read(profilesProvider.notifier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
            'This permanently deletes the profile and all of its learning '
            'history, custom sefarim, and goals. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await guard.run(
      () => profiles.delete(id),
      what: 'Deleting "$name"',
      success: 'Deleted "$name".',
      // The menu already disables Delete on the last profile, so this is the
      // defensive path — but the old code caught *every* failure and blamed it
      // on that one cause, which turned a database error into a wrong answer.
      describe: (e) => e is StateError
          ? 'There has to be at least one profile, so "$name" was kept.'
          : 'Deleting "$name" failed.',
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final profiles = ref.read(profilesProvider.notifier);
    final name = await _promptForName(context,
        title: 'New profile', action: 'Create');
    if (name == null || name.isEmpty) return;
    await guard.run(() => profiles.create(name),
        what: 'Creating the profile "$name"');
  }

  /// One name prompt for both create and rename. Shared so the controller has a
  /// single owner that always disposes it — both dialogs used to build their own
  /// and leak it on every open.
  static Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    required String action,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
                child: Text(action)),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }
}
