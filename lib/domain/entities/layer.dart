/// A **layer** of a unit — the primary text or a meforish (commentary) learned
/// on it. A daf can be marked done per layer; a unit counts as complete only
/// when its *required* layers are all done (see `LayerRequirements`).
class Layer {
  const Layer({
    required this.id,
    required this.name,
    this.nameHebrew,
    this.builtIn = false,
  });

  /// Stable id stored in the log (e.g. 'main', 'rashi', or a custom uuid).
  final String id;
  final String name;
  final String? nameHebrew;

  /// True for the app-provided mefarshim; false for user-defined ones.
  final bool builtIn;

  factory Layer.fromJson(Map<String, dynamic> json) => Layer(
        id: json['id'] as String,
        name: json['name'] as String,
        nameHebrew: json['nameHebrew'] as String?,
        builtIn: json['builtIn'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (nameHebrew != null) 'nameHebrew': nameHebrew,
        'builtIn': builtIn,
      };
}

/// The primary text of any unit — always present, and required by default so
/// that existing progress (which only ever recorded "the text") stays complete.
const mainLayerId = 'main';

/// App-provided mefarshim available to add to any node's required set. Kept flat
/// and universal; the user picks which apply where (nothing is imposed).
const List<Layer> builtInLayers = [
  Layer(id: mainLayerId, name: 'Text (guf)', nameHebrew: 'פנים', builtIn: true),
  Layer(id: 'rashi', name: 'Rashi', nameHebrew: 'רש״י', builtIn: true),
  Layer(id: 'tosafos', name: 'Tosafos', nameHebrew: 'תוספות', builtIn: true),
  Layer(id: 'maharsha', name: 'Maharsha', nameHebrew: 'מהרש״א', builtIn: true),
  Layer(id: 'rosh', name: 'Rosh', nameHebrew: 'רא״ש', builtIn: true),
  Layer(id: 'rif', name: 'Rif', nameHebrew: 'רי״ף', builtIn: true),
  Layer(id: 'bartenura', name: 'Bartenura', nameHebrew: 'ברטנורא', builtIn: true),
  Layer(
      id: 'tosafos_yom_tov',
      name: 'Tosafos Yom Tov',
      nameHebrew: 'תוספות יום טוב',
      builtIn: true),
  Layer(id: 'ramban', name: 'Ramban', nameHebrew: 'רמב״ן', builtIn: true),
  Layer(id: 'sforno', name: 'Sforno', nameHebrew: 'ספורנו', builtIn: true),
  Layer(id: 'ibn_ezra', name: 'Ibn Ezra', nameHebrew: 'אבן עזרא', builtIn: true),
];

final Map<String, Layer> builtInLayersById = {
  for (final l in builtInLayers) l.id: l,
};

/// Suggested mefarshim to quick-add, by a leaf's unit label. Purely a UI
/// convenience for building a required set; never applied automatically.
const Map<String, List<String>> suggestedLayersByUnitLabel = {
  'daf': ['rashi', 'tosafos', 'maharsha'],
  'amud': ['rashi', 'tosafos'],
  'perek': ['bartenura', 'tosafos_yom_tov'],
  'siman': ['rif', 'rosh'],
};
