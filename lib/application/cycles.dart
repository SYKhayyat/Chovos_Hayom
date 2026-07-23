import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/daf_yomi.dart';
import '../core/preferences.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/usecases/learning_cycle.dart';
import 'providers.dart';
import 'stats.dart';

/// A cycle as the UI sees it: its identity, and what it calls for today.
class CycleToday {
  const CycleToday({
    required this.id,
    required this.name,
    required this.description,
    required this.units,
    required this.isBuiltIn,
    this.cycleNumber,
  });

  final String id;
  final String name;
  final String description;

  /// What to learn today, already resolved against the catalog where possible.
  final List<ResolvedCycleUnit> units;
  final bool isBuiltIn;

  /// Which pass through a user-defined cycle today falls in (null for built-ins,
  /// whose numbering the calendar owns).
  final int? cycleNumber;
}

/// One unit of a cycle, paired with the catalog node it maps to (if any).
class ResolvedCycleUnit {
  const ResolvedCycleUnit({required this.day, required this.node});
  final CycleDay day;

  /// Null when the cycle names a sefer the catalog doesn't have under that
  /// spelling — the UI offers to link it, which writes a mapping.
  final CatalogNode? node;

  /// True when the unit falls inside the mapped node's real unit range.
  bool get isLoggable => node != null && node!.containsUnit(day.unit);
}

/// The user's cycle configuration, persisted per profile: which built-ins are
/// hidden, their own cycles, and any sefer-name mappings they've pinned.
class CyclesConfig {
  const CyclesConfig({
    this.hiddenBuiltIns = const {},
    this.custom = const [],
    this.mappings = const {},
  });

  final Set<String> hiddenBuiltIns;
  final List<SequentialCycle> custom;

  /// Cycle-sefer name -> node id, for when a transliteration doesn't match.
  final Map<String, String> mappings;

  CyclesConfig copyWith({
    Set<String>? hiddenBuiltIns,
    List<SequentialCycle>? custom,
    Map<String, String>? mappings,
  }) =>
      CyclesConfig(
        hiddenBuiltIns: hiddenBuiltIns ?? this.hiddenBuiltIns,
        custom: custom ?? this.custom,
        mappings: mappings ?? this.mappings,
      );

  Map<String, dynamic> toJson() => {
        'hiddenBuiltIns': hiddenBuiltIns.toList(),
        'custom': [for (final c in custom) c.toJson()],
        'mappings': mappings,
      };

  factory CyclesConfig.fromJson(Map<String, dynamic> json) => CyclesConfig(
        hiddenBuiltIns: {
          for (final id in (json['hiddenBuiltIns'] as List? ?? [])) '$id',
        },
        custom: [
          for (final c in (json['custom'] as List? ?? []))
            SequentialCycle.fromJson((c as Map).cast<String, dynamic>()),
        ],
        mappings: {
          for (final e in (json['mappings'] as Map? ?? {}).entries)
            '${e.key}': '${e.value}',
        },
      );
}

/// Reads and writes the active profile's cycle configuration.
class CyclesController extends Notifier<CyclesConfig> {
  late String _profileId;

  @override
  CyclesConfig build() {
    _profileId = ref.watch(activeProfileProvider);
    final raw = ref
        .read(appPreferencesProvider)
        .getString(PrefKeys.scoped(_profileId, PrefKeys.cycles));
    if (raw == null || raw.isEmpty) return const CyclesConfig();
    try {
      return CyclesConfig.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // A corrupt value must never stop the app opening.
      return const CyclesConfig();
    }
  }

  Future<void> _write(CyclesConfig next) async {
    state = next;
    await ref.read(appPreferencesProvider).setString(
        PrefKeys.scoped(_profileId, PrefKeys.cycles), jsonEncode(next.toJson()));
  }

  Future<void> setBuiltInVisible(String id, bool visible) {
    final hidden = {...state.hiddenBuiltIns};
    visible ? hidden.remove(id) : hidden.add(id);
    return _write(state.copyWith(hiddenBuiltIns: hidden));
  }

  /// Add or replace a user-defined cycle (matched by id).
  Future<void> save(SequentialCycle cycle) {
    final next = [
      for (final c in state.custom)
        if (c.id != cycle.id) c,
      cycle,
    ];
    return _write(state.copyWith(custom: next));
  }

  Future<void> remove(String id) => _write(state.copyWith(
        custom: [
          for (final c in state.custom)
            if (c.id != id) c,
        ],
      ));

  /// Pin which catalog node a cycle's sefer name refers to.
  Future<void> mapSefer(String seferName, String nodeId) => _write(
      state.copyWith(mappings: {...state.mappings, seferName: nodeId}));

  Future<void> unmapSefer(String seferName) => _write(state.copyWith(
        mappings: {...state.mappings}..remove(seferName),
      ));
}

final cyclesConfigProvider =
    NotifierProvider<CyclesController, CyclesConfig>(CyclesController.new);

/// Resolves cycle sefer names to catalog nodes, honouring the user's mappings.
final cycleMapperProvider = Provider<CycleMapper?>((ref) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  if (catalog == null) return null;
  return CycleMapper(
    catalog: catalog,
    overrides: ref.watch(cyclesConfigProvider).mappings,
  );
});

/// Every cycle the user follows and what each calls for today — built-ins the
/// calendar computes, plus their own. Re-derives when the day turns over,
/// because it watches the clock.
final cyclesTodayProvider = Provider<List<CycleToday>>((ref) {
  final mapper = ref.watch(cycleMapperProvider);
  if (mapper == null) return const [];
  final config = ref.watch(cyclesConfigProvider);
  final now = ref.watch(clockProvider)();

  List<ResolvedCycleUnit> resolve(List<CycleDay> days) => [
        for (final d in days) ResolvedCycleUnit(day: d, node: mapper.resolve(d)),
      ];

  return [
    for (final builtIn in CalendarCycle.all)
      if (!config.hiddenBuiltIns.contains(builtIn.id))
        CycleToday(
          id: builtIn.id,
          name: builtIn.name,
          description: builtIn.description,
          units: resolve(builtIn.unitsOn(now)),
          isBuiltIn: true,
        ),
    for (final cycle in config.custom)
      CycleToday(
        id: cycle.id,
        name: cycle.name,
        description: '${cycle.unitsPerDay} '
            '${cycle.unitsPerDay == 1 ? 'unit' : 'units'} a day · '
            '${cycle.totalUnits} in the cycle',
        units: resolve(cycle.unitsOn(now)),
        isBuiltIn: false,
        cycleNumber: cycle.cycleNumberOn(now),
      ),
  ];
});
