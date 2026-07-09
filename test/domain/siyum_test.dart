import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/siyum.dart';
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;
LearningEvent done(String node, int unit, DateTime day) => LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.done,
      occurredAt: day,
      loggedAt: day,
    );

final catalog = Catalog([
  const CatalogNode(id: 'root', parentId: null, name: 'Root', kind: NodeKind.category),
  const CatalogNode(
      id: 'small',
      parentId: 'root',
      name: 'Small',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.perek,
      unitCount: 3,
      unitOffset: 1),
  const CatalogNode(
      id: 'big',
      parentId: 'root',
      name: 'Big',
      kind: NodeKind.leaf,
      unitLabel: UnitLabel.daf,
      unitCount: 5,
      unitOffset: 2),
]);

void main() {
  setUp(() => _seq = 0);

  test('a leaf with every unit done is a siyum, dated by the last unit', () {
    final events = [
      done('small', 1, DateTime(2026, 1, 1)),
      done('small', 2, DateTime(2026, 1, 5)),
      done('small', 3, DateTime(2026, 1, 3)),
    ];
    final siyumim = SiyumFinder.completed(catalog, events);
    expect(siyumim, hasLength(1));
    expect(siyumim.first.node.id, 'small');
    expect(siyumim.first.completedOn, DateTime(2026, 1, 5)); // latest unit
    expect(siyumim.first.units, 3);
  });

  test('a partially-done leaf is not a siyum', () {
    final events = [
      done('big', 2, DateTime(2026, 1, 1)),
      done('big', 3, DateTime(2026, 1, 2)),
    ];
    expect(SiyumFinder.completed(catalog, events), isEmpty);
  });

  test('multiple siyumim are sorted most-recent first', () {
    final events = [
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      for (var u = 2; u <= 6; u++) done('big', u, DateTime(2026, 2, 20)),
    ];
    final siyumim = SiyumFinder.completed(catalog, events);
    expect(siyumim.map((s) => s.node.id).toList(), ['big', 'small']);
  });
}
