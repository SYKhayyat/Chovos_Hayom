/// What a layer *is* on a given unit. Three states, and only three:
///
/// - **off** — not in the role map at all. Not checkable, not required.
/// - [optional] — checkable, but does not gate completion. "Maharsha I just
///   want to tick."
/// - [required] — checkable *and* part of the definition of done.
///
/// This used to be two independent booleans held in two tables — *offered* and
/// *required* — which admits a fourth state, required-but-not-offered, that means
/// nothing and had to be repaired by hand at every write site and re-united
/// (`offered ∪ required`) at every read site. One tri-state cannot express it, so
/// there is nothing to repair and nothing to keep in sync.
enum LayerRole {
  /// Tickable on the unit; never counted toward done.
  optional,

  /// Tickable, and the unit is not complete until it is done.
  required;

  /// Round-trips through the stored JSON and through a backup file. Unknown
  /// names read as [optional] — a config naming a role this build does not know
  /// should stay checkable rather than silently start gating completion.
  static LayerRole fromName(String? name) =>
      name == required.name ? required : optional;
}

/// A **layer** of a unit — the primary text or a meforish (commentary) learned
/// on it. A daf can be marked done per layer; a unit counts as complete only
/// when its [LayerRole.required] layers are all done (see `LayerRoles`).
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

/// What a node resolves to when nothing is configured on it or any ancestor:
/// the text alone, required. That is exactly the pre-layers behaviour, so
/// progress recorded before mefarshim existed stays complete.
const Map<String, LayerRole> defaultLayerRoles = {mainLayerId: LayerRole.required};

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
