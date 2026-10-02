import 'package:chovos_hayom/domain/entities/catalog.dart';
import 'package:chovos_hayom/domain/entities/progress_node.dart';
import 'package:chovos_hayom/domain/entities/catalog_node.dart';
import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:chovos_hayom/domain/usecases/roll_up.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/layer_roles_dsl.dart';

/// #46 — the second and third lines of a sefer's progress bar: how many units
/// have been finished **more than once**, and **more than twice**.
///
/// **These counts exist because learning is the first pass (#45).** Before that,
/// "reviewed" was something separate from "learned" and the two bars were about
/// different things. Now a unit's first pass *is* its learning, so a unit at 3
/// passes has been learned once and gone back to twice — which is what makes
/// "finished more than once" a count worth drawing rather than a restatement of
/// the line above it.
///
/// Everything here goes through the real [FoldLog], because the whole risk in
/// this feature is the two disagreeing about what a pass is.

/// One leaf: units 2,3,4 — a small sefer, so "all of it" is reachable in a test.
final _catalog = Catalog(const [
  CatalogNode(
    id: 'root',
    parentId: null,
    name: 'Root',
    kind: NodeKind.category,
  ),
  CatalogNode(
    id: 'a',
    parentId: 'root',
    name: 'A',
    kind: NodeKind.leaf,
    unitLabel: UnitLabel.daf,
    unitCount: 3,
    unitOffset: 2,
  ), // valid units: 2, 3, 4
]);

/// A log where each entry is `unit -> passes`. [doneLayers] lets a unit be
/// started but not finished, which is the case the round counts must refuse.
LogFold _log(Map<int, int> passes, [Map<int, Set<String>>? doneLayers]) {
  var seq = 0;
  final events = <LearningEvent>[];
  LearningEvent at(int unit, EventAction action, {Set<String>? layers}) =>
      LearningEvent(
        id: 'e${seq++}',
        profileId: 'p',
        nodeId: 'a',
        unitIndex: unit,
        action: action,
        occurredAt: DateTime(2026, 1, 1),
        loggedAt: DateTime(2026, 1, 1),
        layers: layers?.toList() ?? const ['main'],
      );
  passes.forEach((unit, count) {
    events.add(
      at(unit, EventAction.done, layers: doneLayers?[unit] ?? {'main'}),
    );
    for (var i = 1; i < count; i++) {
      events.add(
        at(unit, EventAction.reviewed, layers: doneLayers?[unit] ?? {'main'}),
      );
    }
  });
  return FoldLog.fold(events);
}

ProgressNode _node(LogFold fold) =>
    RollUp.buildForest(_catalog, fold).single.children.single;

void main() {
  group('the extra bar lines', () {
    test('a unit finished once is on the first line and no other', () {
      // The whole point of a second line being necessary: the counts have to be
      // able to differ, and the commonest state is "learned, never revisited".
      final n = _node(_log({2: 1, 3: 1}));
      expect(n.learned, 2);
      expect(n.finishedAgain, 0);
      expect(n.finishedAgainAgain, 0);
    });

    test('finishing twice moves it to the second line only', () {
      final n = _node(_log({2: 2}));
      expect(n.learned, 1, reason: 'the first line counts units, not passes');
      expect(n.finishedAgain, 1);
      expect(
        n.finishedAgainAgain,
        0,
        reason: 'twice is not three times, however it is phrased',
      );
    });

    test('finishing three times fills the third line too', () {
      final n = _node(_log({2: 3}));
      expect(n.finishedAgain, 1);
      expect(n.finishedAgainAgain, 1);
    });

    test('the sefer is not finished again until every round is counted', () {
      // The 240dp case the issue describes: learned 2 of 3, been over one of
      // them twice. The lines read 2/3, 1/3, 0/3 — and the zero is why a line
      // with nothing on it must not be drawn.
      final n = _node(_log({2: 2, 3: 1}));
      expect(n.learned, 2);
      expect(n.total, 3);
      expect(n.finishedAgain, 1);
      expect(n.finishedAgainAgain, 0);
    });

    test('counts roll up to a parent', () {
      final fold = _log({2: 3, 3: 2, 4: 1});
      final root = RollUp.buildForest(_catalog, fold).single;
      expect(root.learned, 3);
      expect(root.finishedAgain, 2);
      expect(root.finishedAgainAgain, 1);
    });
  });

  group('a round has to be finished', () {
    // The rule the user set: 2 of 3 meforishim is not a completed daf, so it is
    // on no line at all — not the first, and emphatically not the second.
    final requiredMainAndRashi = LayerRoles(
      nodeConfig: {
        'a': roles(required: ['main', 'rashi']),
      },
    );

    test('a partly-done unit is not learned', () {
      final fold = _log(
        {2: 1},
        {
          2: {'main'},
        },
      );
      final node = RollUp.buildForest(
        _catalog,
        fold,
        requiredMainAndRashi,
      ).single.children.single;
      expect(node.learned, 0);
      expect(node.finishedAgain, 0);
    });

    test('and reviews on it do not make it chazara', () {
      // The tempting wrong answer: it has two marks on it, so it looks like two
      // passes. It has one *finished* pass and a review of something still
      // unfinished, which is not a round.
      final fold = _log(
        {2: 3},
        {
          2: {'main'},
        },
      );
      final node = RollUp.buildForest(
        _catalog,
        fold,
        requiredMainAndRashi,
      ).single.children.single;
      expect(node.learned, 0);
      expect(node.finishedAgain, 0);
      expect(node.finishedAgainAgain, 0);
    });

    test('completing it later moves it onto the line it earned', () {
      // Same daf, third round added once it was actually finished.
      var seq = 0;
      final events = <LearningEvent>[
        LearningEvent(
          id: 'e${seq++}',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 1),
          layers: const ['main'],
        ),
        LearningEvent(
          id: 'e${seq++}',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.reviewed,
          occurredAt: DateTime(2026, 1, 2),
          loggedAt: DateTime(2026, 1, 2),
          layers: const ['main'],
        ),
        // The finishing tick. A `reviewed` event does not carry layers — only
        // `done` adds to a unit's completed set — so the daf is completed by
        // marking the missing meforish, which is what the grid's checklist
        // actually does.
        LearningEvent(
          id: 'e${seq++}',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.done,
          occurredAt: DateTime(2026, 1, 3),
          loggedAt: DateTime(2026, 1, 3),
          layers: const ['rashi'],
        ),
      ];
      final node = RollUp.buildForest(
        _catalog,
        FoldLog.fold(events),
        requiredMainAndRashi,
      ).single.children.single;
      expect(node.learned, 1);
      // One review, so one extra round — it lands on the second line and not
      // the third. Asking for three passes here would be asking for a review
      // that was never written.
      expect(node.finishedAgain, 1);
      expect(node.finishedAgainAgain, 0);
    });
  });

  group('the counts cannot disagree with each other', () {
    test('the third line is never ahead of the second', () {
      // An invariant the roll-up cannot break — it only adds — so it is stated
      // rather than assumed. If it ever fails, a bar is drawing a line that is
      // longer than the one below it.
      for (final passes in <Map<int, int>>[
        {},
        {2: 1},
        {2: 2},
        {2: 3},
        {2: 4},
        {2: 3, 3: 2, 4: 5},
      ]) {
        final n = _node(_log(passes));
        expect(n.finishedAgainAgain, lessThanOrEqualTo(n.finishedAgain));
        expect(
          n.finishedAgain,
          lessThanOrEqualTo(n.learned),
          reason:
              'a unit cannot be finished again without being finished: '
              '$passes',
        );
      }
    });

    test('a unit never finished has no passes at all', () {
      final fold = FoldLog.fold([
        LearningEvent(
          id: 'e1',
          profileId: 'p',
          nodeId: 'a',
          unitIndex: 2,
          action: EventAction.reviewed,
          occurredAt: DateTime(2026, 1, 1),
          loggedAt: DateTime(2026, 1, 1),
        ),
      ]);
      final n = _node(fold);
      expect(n.learned, 0);
      expect(n.finishedAgain, 0);
    });

    test('un-marking takes the unit off every line', () {
      // The grid's un-tick writes a second `done` that clears it, so the counts
      // have to fall with it. A line that kept a ghost unit would show a sefer
      // as finished again after the reader removed it.
      var seq = 0;
      final events = <LearningEvent>[];
      for (final unit in [2]) {
        events.add(
          LearningEvent(
            id: 'e${seq++}',
            profileId: 'p',
            nodeId: 'a',
            unitIndex: unit,
            action: EventAction.done,
            occurredAt: DateTime(2026, 1, 1),
            loggedAt: DateTime(2026, 1, 1),
            layers: const ['main'],
          ),
        );
        events.add(
          LearningEvent(
            id: 'e${seq++}',
            profileId: 'p',
            nodeId: 'a',
            unitIndex: unit,
            action: EventAction.reviewed,
            occurredAt: DateTime(2026, 1, 2),
            loggedAt: DateTime(2026, 1, 2),
            layers: const ['main'],
          ),
        );
        events.add(
          LearningEvent(
            id: 'e${seq++}',
            profileId: 'p',
            nodeId: 'a',
            unitIndex: unit,
            action: EventAction.undone,
            occurredAt: DateTime(2026, 1, 3),
            loggedAt: DateTime(2026, 1, 3),
          ),
        );
      }
      final n = _node(FoldLog.fold(events));
      expect(n.learned, 0);
      expect(n.finishedAgain, 0);
      expect(n.finishedAgainAgain, 0);
    });
  });
}
