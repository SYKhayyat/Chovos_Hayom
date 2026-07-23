import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/backup_service.dart';
import '../../application/providers.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';
import '../common/guarded.dart';
import '../common/missing_item.dart';

/// Create or edit a node. In edit mode ([nodeId] set) it writes a per-profile
/// override keyed by that node's id — so *any* node, built-in included, can be
/// renamed, re-counted, re-typed, or re-parented. [parentId] pre-selects a
/// parent (used by "add sub-item"). Everything is editable; nothing is locked.
///
/// Both are ids rather than a `CatalogNode`, so this screen is reachable by name
/// (`/edit-item/<id>`) and survives a cold start — the form waits for the
/// catalog instead of opening empty against a node that hasn't loaded yet.
class AddCustomNodeScreen extends ConsumerWidget {
  const AddCustomNodeScreen({super.key, this.nodeId, this.parentId});

  final String? nodeId;
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (nodeId == null) return _NodeForm(initialParentId: parentId);

    final existing = ref.watch(catalogNodeProvider(nodeId!));
    if (existing == null) {
      return MissingItemScreen(
        loading: !ref.watch(mergedCatalogProvider).hasValue,
        message: 'This item no longer exists.\n'
            'It may have been hidden or deleted.',
      );
    }
    // Keyed by id so the form seeds itself once per node, and re-seeds if the
    // route is replaced with a different one — but never mid-edit.
    return _NodeForm(key: ValueKey(existing.id), existing: existing);
  }
}

class _NodeForm extends ConsumerStatefulWidget {
  const _NodeForm({super.key, this.existing, this.initialParentId});

  final CatalogNode? existing;
  final String? initialParentId;

  @override
  ConsumerState<_NodeForm> createState() => _NodeFormState();
}

class _NodeFormState extends ConsumerState<_NodeForm> {
  late final TextEditingController _name;
  late final TextEditingController _hebrew;
  late final TextEditingController _count;
  late final TextEditingController _offset;
  late final TextEditingController _names;
  late bool _isLeaf;
  late UnitLabel _label;
  late String? _parentId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _hebrew = TextEditingController(text: e?.nameHebrew ?? '');
    _count = TextEditingController(text: (e?.unitCount ?? 10).toString());
    _offset = TextEditingController(text: (e?.unitOffset ?? 1).toString());
    _names = TextEditingController(text: (e?.unitNames ?? const []).join('\n'));
    _isLeaf = e?.isLeaf ?? true;
    _label = e?.unitLabel ?? UnitLabel.perek;
    _parentId = e?.parentId ?? widget.initialParentId;
  }

  @override
  void dispose() {
    _name.dispose();
    _hebrew.dispose();
    _count.dispose();
    _offset.dispose();
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    // Any node can be a parent (attach anywhere) except the node itself/its
    // descendants (that would orphan the subtree).
    final banned =
        _isEdit ? _descendantIds(catalog, widget.existing!.id) : const <String>{};
    final parents = catalog == null
        ? <CatalogNode>[]
        : (catalog.all.where((n) => !banned.contains(n.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit "${widget.existing!.name}"' : 'Add')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hebrew,
            decoration: const InputDecoration(labelText: 'Hebrew name (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: parents.any((p) => p.id == _parentId) ? _parentId : null,
            decoration: const InputDecoration(labelText: 'Parent'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Top level —')),
              for (final c in parents)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Trackable sefer (has units)'),
            subtitle: const Text('Off = a folder/category'),
            value: _isLeaf,
            onChanged: (v) => setState(() => _isLeaf = v),
          ),
          if (_isLeaf) ...[
            DropdownButtonFormField<UnitLabel>(
              initialValue: _label,
              decoration: const InputDecoration(labelText: 'Unit type'),
              items: [
                for (final l in UnitLabel.values)
                  DropdownMenuItem(value: l, child: Text(l.name)),
              ],
              onChanged: (v) => setState(() => _label = v ?? UnitLabel.perek),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of units'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _offset,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'First unit number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _names,
              minLines: 2,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Unit names (optional, one per line)',
                helperText: 'e.g. parsha or siman titles — shown instead of '
                    'numbers, in order from the first unit.',
                alignLabelWithHint: true,
              ),
            ),
            if (_isEdit)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Lowering the count keeps any progress on the removed units '
                  'hidden but intact — raise it again to restore them.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _save, child: Text(_isEdit ? 'Save' : 'Add')),
        ],
      ),
    );
  }

  Set<String> _descendantIds(Catalog? catalog, String id) {
    final result = <String>{id};
    if (catalog == null) return result;
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final child in catalog.childrenOf(cur)) {
        if (result.add(child.id)) queue.add(child.id);
      }
    }
    return result;
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final guard = WriteGuard.of(context, ref);
    final name = _name.text.trim();
    if (name.isEmpty) {
      guard.report('Please enter a name.');
      return;
    }
    final count = int.tryParse(_count.text.trim()) ?? 0;
    final offset = int.tryParse(_offset.text.trim()) ?? 1;
    if (_isLeaf && count <= 0) {
      guard.report('Number of units must be greater than 0.');
      return;
    }
    // Same bounds the backup importer enforces, so a node can't be created here
    // that a backup of it would then be rejected for.
    if (_isLeaf && count > BackupValidator.maxUnitCount) {
      guard.report('That is more units than any sefer has.');
      return;
    }
    if (_isLeaf && offset < 0) {
      guard.report('The first unit number cannot be negative.');
      return;
    }
    final hebrew = _hebrew.text.trim();
    // Trim trailing blank lines but keep interior blanks (they line up unnamed
    // units with their index).
    final names =
        _isLeaf ? _names.text.split('\n').map((s) => s.trimRight()).toList() : <String>[];
    while (names.isNotEmpty && names.last.trim().isEmpty) {
      names.removeLast();
    }
    if (names.length > count) {
      guard.report('You listed ${names.length} unit names but only have '
          '$count units.');
      return;
    }

    final node = CatalogNode(
      id: widget.existing?.id ?? const Uuid().v4(),
      parentId: _parentId,
      name: name,
      nameHebrew: hebrew.isEmpty ? null : hebrew,
      sortOrder: widget.existing?.sortOrder ?? 0,
      kind: _isLeaf ? NodeKind.leaf : NodeKind.category,
      unitLabel: _isLeaf ? _label : null,
      unitCount: _isLeaf ? count : 0,
      unitOffset: _isLeaf ? offset : 0,
      unitNames: names,
    );

    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final saved = await guard.run(
      () => repo.addCustomNode(profileId, node),
      what: _isEdit ? 'Saving "$name"' : 'Adding "$name"',
    );
    // The form stays open on failure, with everything the user typed still in
    // it — closing it would throw away work that was never written.
    if (saved) navigator.pop();
  }
}
