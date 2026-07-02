import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Loads the catalog from a bundled JSON asset. Cached after first load.
class JsonCatalogRepository implements CatalogRepository {
  JsonCatalogRepository({this.assetPath = 'assets/catalog/catalog.json'});

  final String assetPath;
  Catalog? _cached;

  @override
  Future<Catalog> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString(assetPath);
    _cached = parse(raw);
    return _cached!;
  }

  /// Parse catalog JSON text into a [Catalog]. Exposed for testing.
  static Catalog parse(String rawJson) {
    final map = jsonDecode(rawJson) as Map<String, dynamic>;
    final nodes = (map['nodes'] as List)
        .map((e) => CatalogNode.fromJson(e as Map<String, dynamic>))
        .toList();
    return Catalog(nodes);
  }
}
