import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';

/// A tiny catalog (root → Shas → Moed → Shabbos) for tests, using the same ids
/// as the real seed so logging calls line up.
Catalog fakeCatalog() => Catalog(const [
      CatalogNode(id: 'root', parentId: null, name: 'Kol HaTorah Kula', kind: NodeKind.category),
      CatalogNode(id: 'shas', parentId: 'root', name: 'Shas', kind: NodeKind.category),
      CatalogNode(id: 'shas.moed', parentId: 'shas', name: 'Moed', kind: NodeKind.category),
      CatalogNode(
        id: 'shas.moed.shabbos',
        parentId: 'shas.moed',
        name: 'Shabbos',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 156,
        unitOffset: 2,
      ),
    ]);

class FakeCatalogRepository implements CatalogRepository {
  @override
  Future<Catalog> load() async => fakeCatalog();
}
