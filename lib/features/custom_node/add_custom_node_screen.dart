import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';

/// Form to add a user-defined sefer/category. The user supplies unit counts
/// (there is no bundled catalog for custom content).
class AddCustomNodeScreen extends ConsumerStatefulWidget {
  const AddCustomNodeScreen({super.key});

  @override
  ConsumerState<AddCustomNodeScreen> createState() =>
      _AddCustomNodeScreenState();
}

class _AddCustomNodeScreenState extends ConsumerState<AddCustomNodeScreen> {
  final _name = TextEditingController();
  final _count = TextEditingController(text: '10');
  final _offset = TextEditingController(text: '1');
  bool _isLeaf = true;
  UnitLabel _label = UnitLabel.perek;
  String? _parentId; // null = top level

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final categories = catalog == null
        ? <CatalogNode>[]
        : catalog.all.where((n) => !n.isLeaf).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Add custom')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(labelText: 'Parent (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Top level —')),
              for (final c in categories)
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
              decoration:
                  const InputDecoration(labelText: 'First unit number'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Add')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final count = int.tryParse(_count.text.trim()) ?? 0;
    final offset = int.tryParse(_offset.text.trim()) ?? 1;
    if (_isLeaf && count <= 0) return;

    final node = CatalogNode(
      id: const Uuid().v4(),
      parentId: _parentId,
      name: name,
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
