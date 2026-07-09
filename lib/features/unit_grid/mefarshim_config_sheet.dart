import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/layer_requirements.dart';

/// Editor for a node's *required mefarshim* — the layers a unit needs before it
/// counts as complete. Pinning here applies to every unit under [node] unless a
/// nearer node or a single unit overrides it. Fully user-driven: add your own
/// mefarshim, require any subset, and reset back to the inherited default.
Future<void> showMefarshimConfigSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _MefarshimConfigSheet(node: node),
  );
}

class _MefarshimConfigSheet extends ConsumerStatefulWidget {
  const _MefarshimConfigSheet({required this.node});
  final CatalogNode node;

  @override
  ConsumerState<_MefarshimConfigSheet> createState() =>
      _MefarshimConfigSheetState();
}

class _MefarshimConfigSheetState extends ConsumerState<_MefarshimConfigSheet> {
  Set<String>? _selected; // null until seeded from the effective set

  @override
  Widget build(BuildContext context) {
    final layers = ref.watch(allLayersProvider);
    final required = ref.watch(layerRequirementsProvider);
    final theme = Theme.of(context);

    // Seed the selection from the currently-effective set the first time.
    _selected ??= {...required.forNode(widget.node.id)};
    final selected = _selected!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Required mefarshim', style: theme.textTheme.titleLarge),
              Text(widget.node.name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'A unit here counts as done once these are all learned. '
                'Applies to everything under it unless overridden.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final layer in layers)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: selected.contains(layer.id),
                  title: Text(layer.name),
                  subtitle: layer.nameHebrew != null ? Text(layer.nameHebrew!) : null,
                  secondary: layer.builtIn
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Delete meforish',
                          onPressed: () => ref
                              .read(progressRepositoryProvider)
                              .removeCustomLayer(
                                  ref.read(activeProfileProvider), layer.id),
                        ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(layer.id);
                    } else {
                      selected.remove(layer.id);
                    }
                  }),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add a meforish'),
                onPressed: _addCustomLayer,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(progressRepositoryProvider)
                          .clearLayerRequirement(
                              ref.read(activeProfileProvider), widget.node.id, -1);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Reset to inherited'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      await ref.read(progressRepositoryProvider).setLayerRequirement(
                            ref.read(activeProfileProvider),
                            LayerRequirementEntry(
                              nodeId: widget.node.id,
                              unitIndex: -1,
                              layers: selected.isEmpty ? {mainLayerId} : selected,
                            ),
                          );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomLayer() async {
    final nameCtrl = TextEditingController();
    final hebrewCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New meforish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: hebrewCtrl,
              decoration: const InputDecoration(labelText: 'Hebrew (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final hebrew = hebrewCtrl.text.trim();
    nameCtrl.dispose();
    hebrewCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    final id = const Uuid().v4();
    await ref.read(progressRepositoryProvider).addCustomLayer(
          ref.read(activeProfileProvider),
          Layer(id: id, name: name, nameHebrew: hebrew.isEmpty ? null : hebrew),
        );
    if (mounted) setState(() => _selected!.add(id));
  }
}
