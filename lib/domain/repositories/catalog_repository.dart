import '../entities/catalog.dart';

/// Loads the immutable learning catalog. Implementations are pluggable
/// (bundled JSON now; remote/custom sources later) — see ARCHITECTURE.md §5.
///
/// **Revisited and kept, for a different reason than it was written for.** The
/// extension point it advertises — "remote/custom sources later" — shipped as
/// something else entirely: `custom_nodes` merged over the base catalog in a
/// provider, which bypasses this interface completely and is a better answer,
/// because an override layer can shadow one node rather than replacing the
/// whole source.
///
/// So the stated reason is dead. What is alive is that **this is the seam every
/// widget test injects a catalog through**: five doubles under `test/` — a small
/// fake tree, two fixed ones, a 500,000-unit one for the cost tests, and one
/// that throws so the read-failure view can be seen — used by about fifty test
/// files. Seven lines that let the whole suite run against a four-node catalog
/// instead of the real 312-node asset is not an interface with one
/// implementation; it is an interface with six.
abstract interface class CatalogRepository {
  Future<Catalog> load();
}
