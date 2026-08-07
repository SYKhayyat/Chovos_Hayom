import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/backup_service.dart';
import '../../application/providers.dart';
import '../../core/parse.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/missing_item.dart';
import '../common/naming.dart';
import '../common/node_picker.dart';

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
        message: AppLocalizations.of(context).itemMissing,
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
    final l10n = AppLocalizations.of(context);
    // Any node can be a parent (attach anywhere) except the node itself and its
    // descendants — filing a node under its own child orphans the subtree. The
    // exclusion is a *region* of the tree, which is why it goes to
    // [nodeChoices] as `exclude` rather than as a filter: skipping the node
    // stops the walk there, so the descendants cost nothing to leave out.
    //
    // Tree order and qualified, like the Calculator's. This list used to be
    // sorted by `a.name` — the raw English field, whatever language the reader
    // was in — and labelled with the bare name, so a Hebrew reader got a list
    // ordered by strings that were not on their screen containing four rows all
    // reading "שבת".
    final parents = catalog == null
        ? const <NodeChoice>[]
        : nodeChoices(
            l10n,
            catalog,
            exclude: _isEdit ? {widget.existing!.id} : const {},
          );
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEdit
              ? l10n.editNodeTitle(nodeName(l10n, widget.existing!))
              : l10n.addNodeTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // The two names sit together, labelled symmetrically, so it is obvious
          // that both exist and which is which. Either alone is enough — see
          // `_save`.
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.labelNameEnglish),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hebrew,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: l10n.labelNameHebrew,
              helperText: l10n.namePairHelp,
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          NodeDropdown(
            label: l10n.addNodeParent,
            choices: parents,
            value: _parentId,
            noneLabel: l10n.addNodeTopLevel,
            onChanged: (v) => setState(() => _parentId = v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.addNodeIsLeaf),
            subtitle: Text(l10n.addNodeIsLeafSubtitle),
            value: _isLeaf,
            onChanged: (v) => setState(() => _isLeaf = v),
          ),
          if (_isLeaf) ...[
            DropdownButtonFormField<UnitLabel>(
              initialValue: _label,
              decoration: InputDecoration(labelText: l10n.addNodeUnitType),
              items: [
                for (final l in UnitLabel.values)
                  DropdownMenuItem(
                      value: l, child: Text(unitLabelName(l10n, l))),
              ],
              onChanged: (v) => setState(() => _label = v ?? UnitLabel.perek),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addNodeUnitCount),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _offset,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.addNodeFirstUnit),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _names,
              minLines: 2,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.addNodeUnitNames,
                helperText: l10n.addNodeUnitNamesHelper,
                alignLabelWithHint: true,
              ),
            ),
            if (_isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.addNodeLoweringCount,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? l10n.actionSave : l10n.actionAdd)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final guard = WriteGuard.of(context, ref);
    final l10n = AppLocalizations.of(context);
    final hebrew = _hebrew.text.trim();
    // Either field alone is enough. Someone working entirely in Hebrew should
    // not have to invent a transliteration to get past the form, so the Hebrew
    // stands in as the primary name — which is also what an English-locale
    // screen then falls back to showing.
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : hebrew;
    if (name.isEmpty) {
      guard.report(l10n.addNodeNeedNameEither);
      return;
    }
    // The same parse the interval settings and the cycle editor use. The
    // offset is the one quantity in the app where **zero is a real answer** — a
    // sefer numbered from zero — so it has its own function rather than a
    // hand-written `>= 0` beside a `> 0`.
    final count = positiveInt(_count.text);
    final offset = nonNegativeInt(_offset.text);
    if (_isLeaf && count == null) {
      guard.report(l10n.addNodeNeedUnits);
      return;
    }
    // Same bounds the backup importer enforces, so a node can't be created here
    // that a backup of it would then be rejected for.
    if (_isLeaf && count! > BackupValidator.maxUnitCount) {
      guard.report(l10n.addNodeTooManyUnits);
      return;
    }
    // Was `int.tryParse(...) ?? 1`, so typing anything unreadable in the
    // first-unit box silently became 1 — a sefer that starts on a different daf
    // than the one the user asked for, with nothing said about it.
    if (_isLeaf && offset == null) {
      guard.report(l10n.addNodeNegativeOffset);
      return;
    }
    // Trim trailing blank lines but keep interior blanks (they line up unnamed
    // units with their index).
    final names =
        _isLeaf ? _names.text.split('\n').map((s) => s.trimRight()).toList() : <String>[];
    while (names.isNotEmpty && names.last.trim().isEmpty) {
      names.removeLast();
    }
    if (_isLeaf && names.length > count!) {
      guard.report(l10n.addNodeTooManyNames(names.length, count));
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
      unitCount: _isLeaf ? count! : 0,
      unitOffset: _isLeaf ? offset! : 0,
      unitNames: names,
    );

    final repo = ref.read(progressRepositoryProvider);
    final profileId = ref.read(activeProfileProvider);
    final saved = await guard.run(
      () => repo.addCustomNode(profileId, node),
      what: _isEdit ? l10n.whatSavingNode(name) : l10n.whatAddingNode(name),
    );
    // The form stays open on failure, with everything the user typed still in
    // it — closing it would throw away work that was never written.
    if (saved) navigator.pop();
  }
}
