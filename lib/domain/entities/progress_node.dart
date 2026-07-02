import 'catalog_node.dart';

/// A node of the catalog tree annotated with derived progress. Produced by
/// [RollUp]; never persisted (see ARCHITECTURE.md §1).
class ProgressNode {
  ProgressNode({
    required this.node,
    required this.learned,
    required this.total,
    required this.children,
  });

  final CatalogNode node;
  final int learned;
  final int total;
  final List<ProgressNode> children;

  double get percent => total <= 0 ? 0 : 100 * learned / total;
  int get remaining => total - learned;
  bool get isComplete => total > 0 && learned >= total;

  String get id => node.id;
  String get name => node.name;
}
