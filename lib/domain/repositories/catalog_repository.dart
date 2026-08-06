import '../entities/catalog.dart';

/// Loads the immutable learning catalog. Implementations are pluggable
/// (bundled JSON now; remote/custom sources later) — see ARCHITECTURE.md §5.
abstract interface class CatalogRepository {
  Future<Catalog> load();
}
