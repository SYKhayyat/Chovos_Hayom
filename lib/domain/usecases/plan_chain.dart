import 'package:chovos_hayom/core/day.dart';

/// How a [PlanChain] hands over from one plan to the next.
///
/// The [D] from the planner epic, resolved: **the default is the priority
/// queue**, and strict is the opt-in. The difference is which plans may be due
/// while an earlier one is behind:
///
/// * **priority** — a plan is active when it is incomplete and sits at or after
///   the first incomplete plan. Missed work *spills forward*: the backlog stays
///   due every day until it clears, and the next plan in the queue is due
///   alongside it, earlier first.
/// * **strict** — only the first incomplete plan is active. Nothing after it is
///   due until it completes; the chain is a true sequence.
///
/// In both modes the handover is a fold, not a switch: the day an earlier plan
/// completes — early or late — is the day the next becomes active, because
/// completion is read from the log, never stored.
enum ChainMode { priority, strict }

/// A sequence of plans: learn X, then Y. The plans are named by id; the active
/// plans on a day are derived, never stored.
///
/// The order is the priority order. A plan may appear once — a plan repeated in
/// its own chain is meaningless, and the JSON boundary refuses it.
class PlanChain {
  const PlanChain({
    required this.id,
    required this.name,
    required this.planIds,
    this.mode = ChainMode.priority,
  });

  final String id;
  final String name;

  /// The plans in chain order, first to last.
  final List<String> planIds;

  /// How completion hands over. Defaults to [ChainMode.priority], per the epic.
  final ChainMode mode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'planIds': planIds,
        'mode': mode.name,
      };

  factory PlanChain.fromJson(Map<String, dynamic> json) {
    final planIds = [
      for (final p in (json['planIds'] as List<dynamic>? ?? const [])) '$p',
    ];
    if (planIds.isEmpty) {
      throw const FormatException('a chain needs at least one plan');
    }
    final unique = planIds.toSet();
    if (unique.length != planIds.length) {
      throw const FormatException('a chain cannot name a plan twice');
    }
    final rawMode = json['mode'];
    final mode = rawMode == null
        ? ChainMode.priority
        : ChainMode.values.firstWhere(
            (m) => m.name == rawMode,
            orElse: () => throw const FormatException(
                'unknown chain mode — expected "priority" or "strict"'),
          );
    return PlanChain(
      id: json['id'] as String,
      name: json['name'] as String,
      planIds: planIds,
      mode: mode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanChain &&
      other.id == id &&
      other.name == name &&
      other.mode == mode &&
      _samePlanIds(planIds, other.planIds);

  @override
  int get hashCode => Object.hash(id, name, mode, Object.hashAll(planIds));

  static bool _samePlanIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The chain's answer: which plans are active on a day, derived from a
/// log-fold predicate. The event log is never touched here.
class ChainSchedule {
  const ChainSchedule._();

  /// The indices into [chain.planIds] of the plans active on [day], ascending.
  ///
  /// [complete] answers "has this plan finished by [day]" — the caller folds
  /// the log to say so. It must be monotone (the log is append-only), and the
  /// handover it produces is exact either way: finish early, and the next plan
  /// is active the same day; finish late, and the previous stays active.
  static List<int> activePlanIndices(
    PlanChain chain,
    Day day,
    bool Function(String planId, Day day) complete,
  ) {
    final firstIncomplete = chain.planIds.indexWhere((id) => !complete(id, day));
    if (firstIncomplete < 0) return const [];

    switch (chain.mode) {
      case ChainMode.strict:
        return [firstIncomplete];
      case ChainMode.priority:
        return [
          for (var i = firstIncomplete; i < chain.planIds.length; i++)
            if (!complete(chain.planIds[i], day)) i,
        ];
    }
  }

  /// The ids of the plans active on [day], in chain order.
  static List<String> activePlanIds(
    PlanChain chain,
    Day day,
    bool Function(String planId, Day day) complete,
  ) =>
      [
        for (final i
            in activePlanIndices(chain, day, complete))
          chain.planIds[i],
      ];
}