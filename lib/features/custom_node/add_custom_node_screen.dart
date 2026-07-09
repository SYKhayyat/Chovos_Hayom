import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';

/// Create or edit a node. In edit mode ([existing] set) it writes a per-profile
/// override keyed by that node's id — so *any* node, built-in included, can be
/// renamed, re-counted, re-typed, or re-parented. [initialParentId] pre-selects
/// a parent (used by "add sub-item"). Everything is editable; nothing is locked.
class AddCustomNodeScreen extends ConsumerStatefulWidget {
  const AddCustomNodeScreen({super.key, this.existing, this.initialParentId});

  final CatalogNode? existing;
  final String? initialParentId;

  @override
  ConsumerState<AddCustomNodeScreen> createState() =>
      _AddCustomNodeScreenState();
}

class _AddCustomNodeScreenState extends ConsumerState<AddCustomNodeScreen> {
  late final TextEditingController _name;
  late final TextEditingController _hebrew;
  late final TextEditingController _count;
  late final TextEditingController _offset;
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
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Please enter a name.')));
      return;
    }
    final count = int.tryParse(_count.text.trim()) ?? 0;
    final offset = int.tryParse(_offset.text.trim()) ?? 1;
    if (_isLeaf && count <= 0) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Number of units must be greater than 0.')));
      return;
    }
    final hebrew = _hebrew.text.trim();

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
    );

    final profileId = ref.read(activeProfileProvider);
    await ref.read(progressRepositoryProvider).addCustomNode(profileId, node);
    if (mounted) Navigator.of(context).pop();
  }
}
