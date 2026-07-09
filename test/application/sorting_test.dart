import 'package:chovos_hayom/application/sorting.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:flutter_test/flutter_test.dart';

ProgressNode pn(String id, {int learned = 0, int total = 10}) => ProgressNode(
      node: CatalogNode(id: id, parentId: null, name: id, kind: NodeKind.category),
      learned: learned,
      total: total,
      children: const [],
    );

void main() {
  group('sortChildren', () {
    final a = pn('a', learned: 2); // 20%
    final b = pn('b', learned: 8); // 80%
    final c = pn('c', learned: 5); // 50%
    final input = [a, b, c];

    test('catalog metric leaves order untouched (same instance)', () {
      final out = sortChildren(input, const SortConfig(), const {});
      expect(identical(out, input), isTrue);
    });

    test('percent ascending then descending', () {
      final asc = sortChildren(
          input, const SortConfig(metric: SortMetric.percent), const {});
      expect(asc.map((n) => n.id), ['a', 'c', 'b']);
      final desc = sortChildren(input,
          const SortConfig(metric: SortMetric.percent, descending: true), const {});
      expect(desc.map((n) => n.id), ['b', 'c', 'a']);
    });

    test('last learned puts never-learned first ascending, last descending', () {
      final last = {'a': DateTime(2026, 1, 5), 'b': DateTime(2026, 1, 1)};
      // c has no activity.
      final asc = sortChildren(
          input, const SortConfig(metric: SortMetric.lastLearned), last);
      expect(asc.map((n) => n.id), ['c', 'b', 'a']);
      final desc = sortChildren(
          input,
          const SortConfig(metric: SortMetric.lastLearned, descending: true),
          last);
      expect(desc.map((n) => n.id), ['a', 'b', 'c']);
    });

    test('sort is stable — equal keys keep catalog order', () {
      final flat = [pn('x', learned: 5), pn('y', learned: 5), pn('z', learned: 5)];
      final out = sortChildren(
          flat, const SortConfig(metric: SortMetric.percent), const {});
      expect(out.map((n) => n.id), ['x', 'y', 'z']);
    });
  });
}
