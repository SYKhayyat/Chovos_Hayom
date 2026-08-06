import 'package:chovos_hayom/domain/entities/layer.dart';

/// Terse role maps for tests: `roles(required: ['main', 'rashi'])`.
///
/// Writing `{'main': LayerRole.required, 'rashi': LayerRole.required}` inline
/// buries what a test is actually saying under the enum. Anything absent from
/// both lists is *off*, which is the third state and the whole reason the two
/// boolean tables went away.
Map<String, LayerRole> roles({
  List<String> required = const [],
  List<String> optional = const [],
}) =>
    {
      for (final id in optional) id: LayerRole.optional,
      for (final id in required) id: LayerRole.required,
    };
