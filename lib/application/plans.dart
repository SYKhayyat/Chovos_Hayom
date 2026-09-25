import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../core/planner_dates.dart';
import '../core/preferences.dart';
import '../domain/entities/catalog.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/usecases/fold_log.dart';
import '../domain/usecases/layer_roles.dart';
import '../domain/usecases/learning_plan.dart';
import '../domain/usecases/plan_chain.dart';
import '../domain/usecases/plan_completion.dart';
import 'providers.dart';
import 'stats.dart';

class PlansConfig {
  const PlansConfig({this.plans = const [], this.chains = const []});

  final List<LearningPlan> plans;
  final List<PlanChain> chains;

  Map<String, dynamic> toJson() => {
        'plans': [for (final plan in plans) plan.toJson()],
        'chains': [for (final chain in chains) chain.toJson()],
      };

  factory PlansConfig.fromJson(Map<String, dynamic> json) => PlansConfig(
        plans: [
          for (final plan in (json['plans'] as List<dynamic>? ?? const []))
            LearningPlan.fromJson((plan as Map).cast<String, dynamic>()),
        ],
        chains: [
          for (final chain in (json['chains'] as List<dynamic>? ?? const []))
            PlanChain.fromJson((chain as Map).cast<String, dynamic>()),
        ],
      );
}

class PlansController extends Notifier<PlansConfig> {
  late String _profileId;

  @override
  PlansConfig build() {
    _profileId = ref.watch(activeProfileProvider);
    final raw = ref
        .read(appPreferencesProvider)
        .getString(PrefKeys.scoped(_profileId, PrefKeys.plans));
    if (raw == null || raw.isEmpty) return const PlansConfig();
    try {
      return PlansConfig.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const PlansConfig();
    }
  }

  Future<void> save(LearningPlan plan) async {
    final plans = [
      for (final current in state.plans)
        if (current.id != plan.id) current,
      plan,
    ];
    await _write(state.copyWith(plans: plans));
  }

  Future<void> remove(String id) async {
    await _write(state.copyWith(
      plans: [for (final plan in state.plans) if (plan.id != id) plan],
      chains: [
        for (final chain in state.chains)
          PlanChain(
            id: chain.id,
            name: chain.name,
            planIds: [for (final p in chain.planIds) if (p != id) p],
            mode: chain.mode,
          ),
      ],
    ));
  }

  Future<void> _write(PlansConfig next) async {
    state = next;
    await ref.read(appPreferencesProvider).setString(
        PrefKeys.scoped(_profileId, PrefKeys.plans), jsonEncode(next.toJson()));
  }
}

extension on PlansConfig {
  PlansConfig copyWith({List<LearningPlan>? plans, List<PlanChain>? chains}) =>
      PlansConfig(plans: plans ?? this.plans, chains: chains ?? this.chains);
}

final plansConfigProvider =
    NotifierProvider<PlansController, PlansConfig>(PlansController.new);

class TodayAssignment {
  const TodayAssignment({
    required this.plan,
    required this.assignment,
    required this.node,
    required this.unitNodeId,
    required this.unitIndex,
  });

  final LearningPlan plan;
  final PlanAssignment assignment;
  final CatalogNode node;
  final String unitNodeId;
  final int? unitIndex;

  bool get isComplete => unitIndex == null;
  String get id => '${plan.id}/${assignment.id}';
}

final todayAssignmentsProvider = Provider<List<TodayAssignment>>((ref) {
  final catalog = ref.watch(mergedCatalogProvider).asData?.value;
  final fold = ref.watch(foldProvider).asData?.value;
  if (catalog == null || fold == null) return const [];
  final config = ref.watch(plansConfigProvider);
  final day = Day.of(ref.watch(clockProvider)());
  final info = dayInfoFor(day);
  final layers = ref.watch(layerRolesProvider);
  final byId = {for (final plan in config.plans) plan.id: plan};
  final chained = <String, PlanChain>{
    for (final chain in config.chains) chain.id: chain,
  };
  final active = <String>{};
  for (final chain in config.chains) {
    active.addAll(ChainSchedule.activePlanIds(chain, day, (id, at) {
      final plan = byId[id];
      return plan != null &&
          PlanCompletion.completeBefore(plan, catalog, fold, at, layers: layers);
    }));
  }

  return [
    for (final plan in config.plans)
      if (!chained.values.any((c) => c.planIds.contains(plan.id)) || active.contains(plan.id))
        for (final assignment in PlannerSchedule.assignmentsOn(plan, info))
          if (assignment.targetNodeId != null && catalog.byId(assignment.targetNodeId!) != null)
            () {
              final node = catalog.byId(assignment.targetNodeId!)!;
              final next = _nextUnit(node, catalog, fold, layers);
              return TodayAssignment(
                plan: plan,
                assignment: assignment,
                node: node,
                unitNodeId: next?.$1.id ?? node.id,
                unitIndex: next?.$2,
              );
            }(),
  ];
});

(CatalogNode, int)? _nextUnit(
  CatalogNode node,
  Catalog catalog,
  LogFold fold,
  LayerRoles layers,
) {
  for (final leaf in catalog.leavesUnder(node.id)) {
    final required = layers.requiredFor(leaf.id);
    for (var unit = leaf.unitOffset;
        unit < leaf.unitOffset + leaf.unitCount;
        unit++) {
      final completed = fold.completedLayers(leaf.id, unit);
      if (!required.every(completed.contains)) return (leaf, unit);
    }
  }
  return null;
}
