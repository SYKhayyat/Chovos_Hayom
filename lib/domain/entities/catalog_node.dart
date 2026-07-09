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
    this.hidden = false,
    this.unitNames = const [],
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

  /// When true (only ever on a per-profile override row), this node — and its
  /// subtree — is removed from the merged catalog. Built-in catalog data is
  /// never itself hidden; an override row carries this.
  final bool hidden;

  /// Optional real names for units, in unit order from [unitOffset] (e.g. parsha
  /// or siman titles). Empty means units are just numbered.
  final List<String> unitNames;

  bool get isLeaf => kind == NodeKind.leaf;

  /// Compact label for a unit cell: its name if one is set, else its number.
  String unitDisplay(int index) {
    final i = index - unitOffset;
    if (i >= 0 && i < unitNames.length && unitNames[i].trim().isNotEmpty) {
      return unitNames[i];
    }
    return '$index';
  }

  /// Fuller heading for a unit (sheets/titles): its name if set, otherwise the
  /// unit type plus number, e.g. "daf 5".
  String unitHeading(int index) {
    final display = unitDisplay(index);
    if (display != '$index') return display;
    return '${unitLabel?.name ?? 'unit'} $index';
  }

  /// A copy with selected fields changed (for building override rows / edits).
  CatalogNode copyWith({
    String? parentId,
    String? name,
    Object? nameHebrew = _keep,
    int? sortOrder,
    NodeKind? kind,
    Object? unitLabel = _keep,
    int? unitCount,
    int? unitOffset,
    bool? hidden,
    List<String>? unitNames,
  }) =>
      CatalogNode(
        id: id,
        parentId: parentId ?? this.parentId,
        name: name ?? this.name,
        nameHebrew: nameHebrew == _keep ? this.nameHebrew : nameHebrew as String?,
        sortOrder: sortOrder ?? this.sortOrder,
        kind: kind ?? this.kind,
        unitLabel: unitLabel == _keep ? this.unitLabel : unitLabel as UnitLabel?,
        unitCount: unitCount ?? this.unitCount,
        unitOffset: unitOffset ?? this.unitOffset,
        hidden: hidden ?? this.hidden,
        unitNames: unitNames ?? this.unitNames,
      );

  static const _keep = Object();

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
        hidden: json['hidden'] as bool? ?? false,
        unitNames:
            (json['unitNames'] as List?)?.map((e) => e as String).toList() ??
                const [],
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
        if (hidden) 'hidden': true,
        if (unitNames.isNotEmpty) 'unitNames': unitNames,
      };
}
