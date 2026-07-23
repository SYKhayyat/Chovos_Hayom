import 'catalog_node.dart';

/// A node of the catalog tree annotated with derived progress. Produced by
/// [RollUp]; never persisted (see ARCHITECTURE.md §1).
class ProgressNode {
  ProgressNode({
    required this.node,
    required this.learned,
    required this.total,
    required this.children,
    this.learnedByLayer = const {},
  });

  final CatalogNode node;
  final int learned;
  final int total;
  final List<ProgressNode> children;

  /// layer id -> number of in-range units under this node that have that layer
  /// learned (e.g. how many dapim have Rashi). Denominator is [total]. Rolled up
  /// from every descendant leaf; empty for a node with no layered progress.
  final Map<String, int> learnedByLayer;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;
  bool get isComplete => total > 0 && learned >= total;

  /// Units under this node that have [layerId] learned (0 if none).
  int learnedFor(String layerId) => learnedByLayer[layerId] ?? 0;

  String get id => node.id;
  String get name => node.name;
}
