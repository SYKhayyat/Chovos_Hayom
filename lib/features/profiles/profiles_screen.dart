import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/keypad.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/error_view.dart';
import '../common/guarded.dart';
import '../common/text_prompt.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profilesTitle),
        // Same move as the cycles screen: the floating button covers the last
        // profile in the list on a 324dp screen, and creating a profile exists
        // nowhere else, so it becomes the bar's one action instead.
        actions: barActions(
          context,
          [
            if (isCompact(context))
              BarAction(
                icon: Icons.person_add,
                label: l10n.profilesNew,
                onPressed: () => _createDialog(context, ref),
              ),
          ],
          moreTooltip: l10n.tooltipMore,
        ),
      ),
      floatingActionButton: isCompact(context)
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.person_add),
              label: Text(l10n.profilesNew),
              onPressed: () => _createDialog(context, ref),
            ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => ErrorView(
          title: l10n.errorProfilesTitle,
          body: l10n.errorProfilesBody,
          error: e,
          stackTrace: stack,
          onRetry: () => ref.invalidate(profilesProvider),
        ),
        data: (list) => ListView(
          children: [
            for (final p in list)
              ListTile(
                leading: Icon(p.id == active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(p.name),
                subtitle: p.id == active ? Text(l10n.profilesActive) : null,
                onTap: () => guarded(
                  context,
                  ref,
                  () => ref.read(activeProfileProvider.notifier).setProfile(p.id),
                  what: l10n.whatSwitchingProfile(p.name),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'rename') _renameDialog(context, ref, p.id, p.name);
                    if (v == 'delete') _confirmDelete(context, ref, p.id, p.name);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'rename', child: Text(l10n.actionRename)),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: list.length > 1,
                      child: Text(l10n.actionDelete),
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
    final l10n = AppLocalizations.of(context);
    final name = await _promptForName(context,
        title: l10n.profilesRenameTitle,
        action: l10n.actionSave,
        initial: current);
    if (name == null || name.isEmpty) return;
    await guard.run(() => profiles.rename(id, name),
        what: l10n.whatRenamingProfile(current, name));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final guard = WriteGuard.of(context, ref);
    final profiles = ref.read(profilesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profilesDeleteTitle(name)),
        content: Text(l10n.profilesDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel)),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await guard.run(
      () => profiles.delete(id),
      what: l10n.whatDeletingProfile(name),
      success: l10n.profileDeleted(name),
      // The menu already disables Delete on the last profile, so this is the
      // defensive path — but the old code caught *every* failure and blamed it
      // on that one cause, which turned a database error into a wrong answer.
      describe: (e) => e is StateError
          ? l10n.profileLastOneKept(name)
          : l10n.profileDeleteFailed(name),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final guard = WriteGuard.of(context, ref);
    final profiles = ref.read(profilesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final name = await _promptForName(context,
        title: l10n.profilesNew, action: l10n.actionCreate);
    if (name == null || name.isEmpty) return;
    await guard.run(() => profiles.create(name),
        what: l10n.whatCreatingProfile(name));
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
    final l10n = AppLocalizations.of(context);
    return promptForText(
      context,
      title: title,
      label: l10n.labelName,
      initialValue: initial,
      confirmLabel: action,
      cancelLabel: l10n.actionCancel,
    );
  }
}
