import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/repositories/catalog_repository.dart';

import 'fake_catalog.dart';

/// A catalog source that refuses to load, and can then be told to stop refusing.
///
/// The dashboard's error state was the one failure path in the app with no test
/// behind it — it rendered `Center(child: Text('Error: $e'))`, which is hard to
/// get wrong and equally hard to get right. Now that it explains itself, offers
/// a retry and records what happened, all three need a source that can actually
/// fail, and then succeed, so that "retry works" is an assertion rather than a
/// hope.
class FailingCatalogRepository implements CatalogRepository {
  FailingCatalogRepository({this.fail = true});

  /// Flip to false to let the next load succeed.
  bool fail;

  /// How many times [load] has been called, so a test can prove a retry re-ran
  /// it rather than re-rendering a cached failure.
  int loads = 0;

  /// What a refused load throws. Matched in assertions so a test can be sure it
  /// saw this failure and not an incidental one.
  static const message = 'catalog.json is missing from the bundle';

  @override
  Future<Catalog> load() async {
    loads++;
    if (fail) throw StateError(message);
    return fakeCatalog();
  }
}
