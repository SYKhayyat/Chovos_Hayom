import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('named units', () {
    const node = CatalogNode(
      id: 'parshiyos',
      parentId: null,
      name: 'Sefer Bereishis',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.perek,
      unitCount: 3,
      unitOffset: 1,
      unitNames: ['Bereishis', 'Noach', 'Lech Lecha'],
    );

    test('unitDisplay returns the name in order from the offset', () {
      expect(node.unitDisplay(1), 'Bereishis');
      expect(node.unitDisplay(3), 'Lech Lecha');
    });

    test('unitDisplay falls back to the number past the names', () {
      expect(node.unitDisplay(9), '9');
    });

    test('unitHeading uses the name, or the type + number when unnamed', () {
      expect(node.unitHeading(2), 'Noach');
      const plain = CatalogNode(
        id: 'x',
        parentId: null,
        name: 'X',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 5,
        unitOffset: 2,
      );
      expect(plain.unitHeading(4), 'daf 4');
    });

    test('unitNames survive a JSON round-trip', () {
      final back = CatalogNode.fromJson(node.toJson());
      expect(back.unitNames, ['Bereishis', 'Noach', 'Lech Lecha']);
    });
  });
}
