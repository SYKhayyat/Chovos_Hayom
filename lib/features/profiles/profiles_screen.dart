import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

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
                onTap: () =>
                    ref.read(activeProfileProvider.notifier).setProfile(p.id),
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
    final name = await _promptForName(context,
        title: 'Rename profile', action: 'Save', initial: current);
    if (name != null && name.isNotEmpty) {
      await ref.read(profilesProvider.notifier).rename(id, name);
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
            'This permanently deletes the profile and all of its learning '
            'history, custom sefarim, and goals. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profilesProvider.notifier).delete(id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted "$name".')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not delete the last remaining profile.')));
    }
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context,
        title: 'New profile', action: 'Create');
    if (name != null && name.isNotEmpty) {
      await ref.read(profilesProvider.notifier).create(name);
    }
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
