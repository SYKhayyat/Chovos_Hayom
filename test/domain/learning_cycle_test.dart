import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/usecases/learning_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

final _start = DateTime(2026, 1, 1);

SequentialCycle cycle({
  int unitsPerDay = 1,
  bool repeats = true,
  List<CycleSegment> segments = const [
    CycleSegment(nodeId: 'a', unitCount: 3, unitOffset: 1), // units 1,2,3
    CycleSegment(nodeId: 'b', unitCount: 2, unitOffset: 5), // units 5,6
  ],
}) =>
    SequentialCycle(
      id: 'c',
      name: 'Test cycle',
      startDate: _start,
      unitsPerDay: unitsPerDay,
      repeats: repeats,
      segments: segments,
    );

DateTime day(int n) => _start.add(Duration(days: n));

void main() {
  group('SequentialCycle', () {
    test('walks its sefarim in order, one a day', () {
      final c = cycle();
      expect(c.unitsOn(day(0)).single.nodeId, 'a');
      expect(c.unitsOn(day(0)).single.unit, 1);
      expect(c.unitsOn(day(2)).single.unit, 3, reason: 'last unit of A');
      expect(c.unitsOn(day(3)).single.nodeId, 'b');
      expect(c.unitsOn(day(3)).single.unit, 5,
          reason: "B's units start at its own offset");
    });

    test('starts over at the end', () {
      final c = cycle();
      expect(c.totalUnits, 5);
      expect(c.unitsOn(day(5)).single.nodeId, 'a');
      expect(c.unitsOn(day(5)).single.unit, 1);
      expect(c.cycleNumberOn(day(5)), 2);
    });

    test('a one-time programme stops rather than looping', () {
      final c = cycle(repeats: false);
      expect(c.unitsOn(day(4)), hasLength(1));
      expect(c.unitsOn(day(5)), isEmpty);
    });

    test('nothing is scheduled before the start date', () {
      expect(cycle().unitsOn(_start.subtract(const Duration(days: 1))), isEmpty);
      expect(cycle().cycleNumberOn(_start.subtract(const Duration(days: 1))), 0);
    });

    test('more than one unit a day (Mishna Yomi is two)', () {
      final c = cycle(unitsPerDay: 2);
      final firstDay = c.unitsOn(day(0));
      expect(firstDay.map((u) => u.unit), [1, 2]);
      expect(c.unitsOn(day(1)).map((u) => u.unit), [3, 5]);
      // Day 2 opens on the cycle's last unit and rolls into the next one, so it
      // is still counted as the first cycle; day 3 is the second.
      expect(c.cycleNumberOn(day(2)), 1);
      expect(c.unitsOn(day(2)).map((u) => u.unit), [6, 1]);
      expect(c.cycleNumberOn(day(3)), 2);
    });

    test('an empty cycle schedules nothing instead of dividing by zero', () {
      expect(cycle(segments: const []).unitsOn(day(3)), isEmpty);
      expect(cycle(unitsPerDay: 0).unitsOn(day(3)), isEmpty);
    });

    test('round-trips through JSON', () {
      final restored = SequentialCycle.fromJson(cycle(unitsPerDay: 2).toJson());
      expect(restored.name, 'Test cycle');
      expect(restored.unitsPerDay, 2);
      expect(restored.startDate, _start);
      expect(restored.totalUnits, 5);
      expect(restored.unitsOn(day(1)).map((u) => u.unit), [3, 5]);
    });
  });

  group('CycleMapper', () {
    final catalog = Catalog(const [
      CatalogNode(
        id: 'shas.beitza',
        parentId: null,
        name: 'Beitzah',
        nameHebrew: 'ביצה',
        kind: NodeKind.leaf,
        unitLabel: UnitLabel.daf,
        unitCount: 40,
        unitOffset: 2,
      ),
    ]);

    test('a node-defined cycle needs no matching at all', () {
      final mapper = CycleMapper(catalog: catalog);
      final resolved = mapper.resolve(
          const CycleDay(sefer: 'shas.beitza', unit: 3, nodeId: 'shas.beitza'));
      expect(resolved?.id, 'shas.beitza');
    });

    test('matches on an English name ignoring spacing and punctuation', () {
      final mapper = CycleMapper(catalog: catalog);
      expect(mapper.resolve(const CycleDay(sefer: 'Beitzah', unit: 3))?.id,
          'shas.beitza');
    });

    test('matches on the Hebrew name', () {
      final mapper = CycleMapper(catalog: catalog);
      expect(
          mapper
              .resolve(const CycleDay(sefer: 'Nope', seferHebrew: 'ביצה', unit: 3))
              ?.id,
          'shas.beitza');
    });

    test('a differing transliteration finds nothing — and that is what the '
        'user mapping is for', () {
      // "Beitza" vs "Beitzah" is exactly the case that used to silently make a
      // daf unloggable, with nothing the user could do about it.
      expect(CycleMapper(catalog: catalog)
          .resolve(const CycleDay(sefer: 'Beitza', unit: 3)),
          isNull);

      final mapped = CycleMapper(
          catalog: catalog, overrides: const {'Beitza': 'shas.beitza'});
      expect(mapped.resolve(const CycleDay(sefer: 'Beitza', unit: 3))?.id,
          'shas.beitza');
    });

    test('a user mapping wins over name matching', () {
      final other = Catalog(const [
        CatalogNode(
            id: 'a', parentId: null, name: 'Beitzah', kind: NodeKind.leaf,
            unitCount: 5),
        CatalogNode(
            id: 'b', parentId: null, name: 'Something else', kind: NodeKind.leaf,
            unitCount: 5),
      ]);
      final mapper = CycleMapper(catalog: other, overrides: const {'Beitzah': 'b'});
      expect(mapper.resolve(const CycleDay(sefer: 'Beitzah', unit: 1))?.id, 'b');
    });

    test('a stale mapping falls back to name matching rather than breaking', () {
      final mapper = CycleMapper(
          catalog: catalog, overrides: const {'Beitzah': 'deleted-node'});
      expect(mapper.resolve(const CycleDay(sefer: 'Beitzah', unit: 3))?.id,
          'shas.beitza');
    });
  });
}
