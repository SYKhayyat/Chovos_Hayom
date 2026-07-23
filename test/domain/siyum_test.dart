import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
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

LearningEvent undone(String node, int unit, DateTime day) => LearningEvent(
      id: 'e${_seq++}',
      profileId: 'p',
      nodeId: node,
      unitIndex: unit,
      action: EventAction.undone,
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

List<Siyum> siyumimFor(List<LearningEvent> events) {
  final fold = FoldLog.fold(events);
  return SiyumFinder.completed(RollUp.buildForest(catalog, fold), fold);
}

void main() {
  setUp(() => _seq = 0);

  test('a leaf with every unit done is a siyum, dated by the last unit', () {
    final siyumim = siyumimFor([
      done('small', 1, DateTime(2026, 1, 1)),
      done('small', 2, DateTime(2026, 1, 5)),
      done('small', 3, DateTime(2026, 1, 3)),
    ]);
    expect(siyumim, hasLength(1));
    expect(siyumim.first.node.id, 'small');
    expect(siyumim.first.completedOn, DateTime(2026, 1, 5)); // latest unit
    expect(siyumim.first.units, 3);
  });

  test('a partially-done leaf is not a siyum', () {
    expect(
        siyumimFor([
          done('big', 2, DateTime(2026, 1, 1)),
          done('big', 3, DateTime(2026, 1, 2)),
        ]),
        isEmpty);
  });

  test('multiple siyumim are sorted most-recent first', () {
    final siyumim = siyumimFor([
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      for (var u = 2; u <= 6; u++) done('big', u, DateTime(2026, 2, 20)),
    ]);
    // Finishing Big also finishes Root, on the same day — the larger siyum
    // leads, then Big, then the older one.
    expect(siyumim.map((s) => s.node.id).toList(), ['root', 'big', 'small']);
  });

  test('finishing everything under a category is a siyum on the category too',
      () {
    // The whole point: an app whose payoff is the siyum must not stay silent
    // when you finish a seder.
    final siyumim = siyumimFor([
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      for (var u = 2; u <= 6; u++) done('big', u, DateTime(2026, 2, 20)),
    ]);
    final root = siyumim.firstWhere((s) => s.node.id == 'root');
    expect(root.isCategory, isTrue);
    expect(root.units, 8, reason: 'every unit underneath');
    expect(root.completedOn, DateTime(2026, 2, 20),
        reason: 'dated by the last unit anywhere underneath');
    expect(root.depth, 0);
  });

  test('a category with one unfinished child is not a siyum', () {
    final siyumim = siyumimFor([
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      done('big', 2, DateTime(2026, 2, 20)),
    ]);
    expect(siyumim.map((s) => s.node.id), ['small']);
  });

  test('un-marking a unit revokes the siyum', () {
    final siyumim = siyumimFor([
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      undone('small', 2, DateTime(2026, 1, 11)),
    ]);
    expect(siyumim, isEmpty);
  });

  test('the bigger siyum leads when two land on the same day', () {
    final siyumim = siyumimFor([
      for (var u = 1; u <= 3; u++) done('small', u, DateTime(2026, 1, 10)),
      for (var u = 2; u <= 6; u++) done('big', u, DateTime(2026, 1, 10)),
    ]);
    expect(siyumim.first.node.id, 'root', reason: '8 units beats 5 and 3');
    expect(siyumim.map((s) => s.units), [8, 5, 3]);
  });

  test('nothing learned yields no siyumim', () {
    expect(siyumimFor([]), isEmpty);
  });
}
