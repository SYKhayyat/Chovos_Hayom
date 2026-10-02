import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../core/planner_dates.dart';
import '../core/preferences.dart';
import '../domain/entities/catalog_node.dart';
import '../domain/usecases/learning_plan.dart';
import '../domain/usecases/plan_chain.dart';
import '../domain/usecases/plan_completion.dart';
import '../domain/usecases/plan_position.dart';
import '../domain/usecases/plan_rate.dart';
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
      return PlansConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
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
    await _write(
      state.copyWith(
        plans: [
          for (final plan in state.plans)
            if (plan.id != id) plan,
        ],
        chains: [
          for (final chain in state.chains)
            PlanChain(
              id: chain.id,
              name: chain.name,
              planIds: [
                for (final p in chain.planIds)
                  if (p != id) p,
              ],
              mode: chain.mode,
            ),
        ],
      ),
    );
  }

  Future<void> _write(PlansConfig next) async {
    state = next;
    await ref
        .read(appPreferencesProvider)
        .setString(
          PrefKeys.scoped(_profileId, PrefKeys.plans),
          jsonEncode(next.toJson()),
        );
  }
}

extension on PlansConfig {
  PlansConfig copyWith({List<LearningPlan>? plans, List<PlanChain>? chains}) =>
      PlansConfig(plans: plans ?? this.plans, chains: chains ?? this.chains);
}

final plansConfigProvider = NotifierProvider<PlansController, PlansConfig>(
  PlansController.new,
);

/// One plan by id, or null when there is no such plan.
///
/// A single lookup rather than the whole list, because the plan screen reads one
/// and the list is a field the editor has to scan. Returns null rather than
/// throwing so a plan deleted from under an open screen — which happens when the
/// delete button is used on the very screen showing it — resolves to something
/// the screen can say rather than to a crash.
final planByIdProvider = Provider.autoDispose.family<LearningPlan?, String>((
  ref,
  id,
) {
  for (final plan in ref.watch(plansConfigProvider).plans) {
    if (plan.id == id) return plan;
  }
  return null;
});

/// Where the plan [id] stands and how fast it is moving.
///
/// **Auto-disposed, like every other family here** (`notify_guard_test.dart`
/// enforces it): this one walks the plan's ranges and then the days it has been
/// running, and a plan screen closed an hour ago has no business re-deriving
/// that on every mark.
///
/// Null while the catalog or the log is still loading, rather than a standing
/// with nothing in it — an empty plan and an unreadable log are different states
/// and the screen says so for one of them.
final planStandingProvider = Provider.autoDispose.family<PlanStanding?, String>(
  (ref, id) {
    final catalog = ref.watch(mergedCatalogProvider).asData?.value;
    final fold = ref.watch(foldProvider).asData?.value;
    final plan = ref.watch(planByIdProvider(id));
    if (catalog == null || fold == null || plan == null) return null;
    return PlanRate.of(
      plan,
      catalog,
      fold,
      Day.of(ref.watch(clockProvider)()),
      layers: ref.watch(layerRolesProvider),
    );
  },
);

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
    active.addAll(
      ChainSchedule.activePlanIds(chain, day, (id, at) {
        final plan = byId[id];
        return plan != null &&
            PlanCompletion.completeBefore(
              plan,
              catalog,
              fold,
              at,
              layers: layers,
            );
      }),
    );
  }

  return [
    for (final plan in config.plans)
      if (!chained.values.any((c) => c.planIds.contains(plan.id)) ||
          active.contains(plan.id))
        for (final assignment in PlannerSchedule.assignmentsOn(plan, info))
          if (assignment.targetNodeId != null &&
              catalog.byId(assignment.targetNodeId!) != null)
            () {
              final node = catalog.byId(assignment.targetNodeId!)!;
              final next = PlanProgress.nextUnitUnder(
                node,
                catalog,
                fold,
                layers: layers,
              );
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
