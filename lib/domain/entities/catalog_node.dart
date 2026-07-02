import 'enums.dart';

/// A single node in the learning catalog (or a user-defined custom node).
///
/// Immutable reference data. Only [NodeKind.leaf] nodes carry enumerable units;
/// categories and sefarim aggregate their children.
///
/// Units are **always integers** — an uneven daf/amud is counted as a full unit
/// (see ARCHITECTURE.md §2.1). Unit indices for a leaf run
/// `[unitOffset, unitOffset + unitCount)`.
class CatalogNode {
  const CatalogNode({
    required this.id,
    required this.parentId,
    required this.name,
    required this.kind,
    this.nameHebrew,
    this.sortOrder = 0,
    this.unitLabel,
    this.unitCount = 0,
    this.unitOffset = 0,
  });

  final String id;
  final String? parentId;
  final String name;
  final String? nameHebrew;
  final int sortOrder;
  final NodeKind kind;

  /// Leaf-only. Null for categories/sefarim.
  final UnitLabel? unitLabel;

  /// Number of atomic units. 0 for non-leaves.
  final int unitCount;

  /// First unit index (e.g. 2 for a gemara starting at daf ב). 0 for non-leaves.
  final int unitOffset;

  bool get isLeaf => kind == NodeKind.leaf;

  /// The valid unit indices for this leaf, `[unitOffset, unitOffset + unitCount)`.
  Iterable<int> get unitIndices =>
      Iterable<int>.generate(unitCount, (i) => unitOffset + i);

  bool containsUnit(int index) =>
      index >= unitOffset && index < unitOffset + unitCount;

  factory CatalogNode.fromJson(Map<String, dynamic> json) => CatalogNode(
        id: json['id'] as String,
        parentId: json['parentId'] as String?,
        name: json['name'] as String,
        nameHebrew: json['nameHebrew'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        kind: NodeKind.values.byName(json['kind'] as String),
        unitLabel: json['unitLabel'] == null
            ? null
            : UnitLabel.values.byName(json['unitLabel'] as String),
        unitCount: (json['unitCount'] as num?)?.toInt() ?? 0,
        unitOffset: (json['unitOffset'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'name': name,
        if (nameHebrew != null) 'nameHebrew': nameHebrew,
        'sortOrder': sortOrder,
        'kind': kind.name,
        if (unitLabel != null) 'unitLabel': unitLabel!.name,
        'unitCount': unitCount,
        'unitOffset': unitOffset,
      };
}
