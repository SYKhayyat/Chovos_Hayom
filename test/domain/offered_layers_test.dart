import 'package:chovos_hayom/domain/entities/enums.dart';
import 'package:chovos_hayom/domain/entities/learning_event.dart';
import 'package:chovos_hayom/domain/usecases/fold_log.dart';
import 'package:chovos_hayom/domain/usecases/layer_requirements.dart';
import 'package:chovos_hayom/domain/usecases/offered_layers.dart';
import 'package:chovos_hayom/domain/usecases/unit_layer_view.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEvent ev(EventAction action,
    {int seq = 0,
    int unit = 2,
    String node = 'a',
    List<String> layers = const ['main']}) {
  final t = DateTime(2026, 1, 1).add(Duration(seconds: seq));
  return LearningEvent(
    id: '$node-$unit-${action.name}-$seq-${layers.join()}',
    profileId: 'p',
    nodeId: node,
    unitIndex: unit,
    action: action,
    occurredAt: t,
    loggedAt: t,
    layers: layers,
  );
}

void main() {
  group('OfferedLayers resolution', () {
    test('inherits from the nearest configured ancestor', () {
      final offered = OfferedLayers(
        nodeConfig: {
          'shas': {'main', 'rashi', 'maharsha'}
        },
        parentOf: {'shas': null, 'shabbos': 'shas'},
      );
      expect(offered.forNode('shabbos'), {'main', 'rashi', 'maharsha'});
    });

    test('defaults to text-only when unconfigured', () {
      expect(OfferedLayers().forNode('anything'), {'main'});
    });
  });

  group('UnitLayerView reconciliation', () {
    test('checkable is offered ∪ required; done depends only on required', () {
      // Required = {main}; offered adds an OPTIONAL rashi.
      final required = LayerRequirements(nodeConfig: {
        'a': {'main'}
      });
      final offered = OfferedLayers(nodeConfig: {
        'a': {'main', 'rashi'}
      });
      final view = UnitLayerView(required: required, offered: offered);

      expect(view.requiredFor('a', 2), {'main'});
      expect(view.checkableFor('a', 2), {'main', 'rashi'});
      // Offering an optional meforish makes the unit layered (shows a checklist).
      expect(view.isLayered('a', 2), isTrue);

      // Learning only the text completes the unit — the optional rashi does not
      // gate it.
      final textOnly = FoldLog.fold([ev(EventAction.done, layers: ['main'])]);
      expect(textOnly.doneUnits('a', required), {2});
      // ...but the fraction still reflects only required (full).
      expect(view.fraction('a', 2, textOnly), 1.0);
    });

    test('required layer missing from offered is still checkable', () {
      final required = LayerRequirements(nodeConfig: {
        'a': {'main', 'tosafos'}
      });
      final offered = OfferedLayers(nodeConfig: {
        'a': {'main'} // forgot tosafos here
      });
      final view = UnitLayerView(required: required, offered: offered);
      expect(view.checkableFor('a', 2), {'main', 'tosafos'});
    });

    test('text-only unit is not layered', () {
      final view =
          UnitLayerView(required: LayerRequirements(), offered: OfferedLayers());
      expect(view.isLayered('a', 2), isFalse);
    });
  });
}
