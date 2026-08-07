import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/layer.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_roles.dart';
import 'package:chovos_hayom/domain/usecases/unit_mefarshim.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Which mefarshim apply to this unit, and in what state" was answered by hand
/// at three call sites, and the answers differed on exactly the case that
/// matters: a meforish that was learned and has since been turned off or
/// deleted.
///
/// The log is append-only and those units really were learned with it, so the
/// answer has to be representable. It now is, and the three sites take three
/// named slices of one list rather than three set expressions.
void main() {
  const node = 'shas.moed.shabbos';
  const unit = 2;

  LearningEvent done(String layer, {int at = 1}) => LearningEvent(
        id: 'e$layer$at',
        profileId: 'p',
        nodeId: node,
        unitIndex: unit,
        action: EventAction.done,
        occurredAt: DateTime(2026, 3, at),
        loggedAt: DateTime(2026, 3, at),
        layers: [layer],
      );

  LayerRoles rolesOf(Map<String, LayerRole> roles) => LayerRoles.fromEntries([
        LayerConfigEntry(nodeId: node, unitIndex: -1, roles: roles),
      ]);

  UnitMefarshim ask(
    Map<String, LayerRole> roles, {
    List<LearningEvent> log = const [],
    List<String> order = const [mainLayerId, 'rashi', 'tosafos', 'maharsha'],
  }) =>
      UnitMefarshim.of(
        roles: rolesOf(roles),
        fold: FoldLog.fold(log),
        layerOrder: order,
        nodeId: node,
        unitIndex: unit,
      );

  test('the rows follow the mefarshim list, not the config or the log', () {
    final m = ask(
      const {
        'tosafos': LayerRole.required,
        mainLayerId: LayerRole.required,
        'rashi': LayerRole.optional,
      },
      log: [done('tosafos')],
    );

    expect(m.all.map((e) => e.layerId).toList(),
        [mainLayerId, 'rashi', 'tosafos']);
    expect(m.all.map((e) => e.isDone).toList(), [false, false, true]);
  });

  test('a meforish that is off and not learned is simply not here', () {
    final m = ask(const {mainLayerId: LayerRole.required});
    expect(m.all.map((e) => e.layerId), [mainLayerId]);
  });

  group('a meforish learned and since turned off', () {
    // The unit was finished with Rashi; the node has since stopped asking for
    // Rashi at all.
    final m = ask(
      const {mainLayerId: LayerRole.required},
      log: [done(mainLayerId), done('rashi')],
    );

    test('is still in the list, with no role', () {
      final rashi = m.all.firstWhere((e) => e.layerId == 'rashi');
      expect(rashi.role, isNull);
      expect(rashi.isDone, isTrue);
      expect(rashi.isCheckableHere, isFalse);
    });

    test('is not offered as something to tick on a fresh log', () {
      // Recording that you learned it *again* is a chazara, not a first
      // learning, and the unit does not ask for it any more.
      expect(m.checkable.map((e) => e.layerId), [mainLayerId]);
    });

    test('is offered as something to review, which is the case that was wrong',
        () {
      // The old chazara sheet filtered its options through the mefarshim list
      // while seeding its selection from the log, so this layer was *selected
      // and invisible*: submitted with no checkbox to untick it.
      expect(m.reviewable.map((e) => e.layerId), [mainLayerId, 'rashi']);
      expect(m.done, {mainLayerId, 'rashi'});
      expect(m.done.difference({for (final e in m.reviewable) e.layerId}),
          isEmpty,
          reason: 'every layer the chazara sheet seeds must have a row it can '
              'be unticked from');
    });
  });

  test('a meforish deleted outright keeps its place in the list', () {
    // Deleting a meforish rewrites the settings but deliberately not the log,
    // so its id survives in events and in nothing else. It comes last, because
    // the mefarshim list no longer contains it to order it by.
    final m = ask(
      const {mainLayerId: LayerRole.required, 'rashi': LayerRole.required},
      log: [done(mainLayerId), done('a-deleted-uuid')],
    );

    expect(m.all.map((e) => e.layerId).toList(),
        [mainLayerId, 'rashi', 'a-deleted-uuid']);
    expect(m.all.last.role, isNull);
    expect(m.reviewable.map((e) => e.layerId),
        [mainLayerId, 'rashi', 'a-deleted-uuid']);
  });

  test('outstanding is what a fresh log arrives with ticked', () {
    final m = ask(
      const {
        mainLayerId: LayerRole.required,
        'rashi': LayerRole.required,
        'maharsha': LayerRole.optional,
      },
      log: [done(mainLayerId)],
    );

    expect(m.required, {mainLayerId, 'rashi'});
    expect(m.outstanding, {'rashi'});
    // Optional mefarshim are tickable and are never pre-ticked: they do not
    // gate completion, so nothing about the unit says you meant to learn one.
    expect(m.checkable.map((e) => e.layerId),
        [mainLayerId, 'rashi', 'maharsha']);
  });

  test('a null fold reads as nothing learned rather than throwing', () {
    final m = UnitMefarshim.of(
      roles: rolesOf(const {mainLayerId: LayerRole.required}),
      fold: null,
      layerOrder: const [mainLayerId],
      nodeId: node,
      unitIndex: unit,
    );
    expect(m.done, isEmpty);
    expect(m.outstanding, {mainLayerId});
  });

  test('an unconfigured unit is the text alone, required', () {
    final m = UnitMefarshim.of(
      roles: LayerRoles.fromEntries(const []),
      fold: FoldLog.fold(const []),
      layerOrder: const [mainLayerId, 'rashi'],
      nodeId: node,
      unitIndex: unit,
    );
    expect(m.all.map((e) => e.layerId), [mainLayerId]);
    expect(m.all.single.isRequired, isTrue);
    // Which is why the chazara sheet's old "if there are no options, invent a
    // Text row" fallback was unreachable: there is always one.
    expect(m.reviewable, isNotEmpty);
  });
}
