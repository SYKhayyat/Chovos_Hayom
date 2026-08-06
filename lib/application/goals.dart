import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../core/preferences.dart';
import '../domain/usecases/goal_evaluator.dart';
import 'backup_service.dart';
import 'providers.dart';
import 'stats.dart';

/// Target finish dates per node, scoped to the active profile and persisted.
class GoalsController extends Notifier<Map<String, DateTime>> {
  String _key(String profileId) => PrefKeys.goalsFor(profileId);

  @override
  Map<String, DateTime> build() {
    final profileId = ref.watch(activeProfileProvider);
    final raw = ref.watch(appPreferencesProvider).getString(_key(profileId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: DateTime.parse(e.value as String),
      };
    } catch (_) {
      // A corrupt value must never stop the app opening. goalsProvider is
      // watched by the dashboard tiles, the unit grid and the Goals screen, so
      // a throw here takes all three down — a lost goal map is a far smaller
      // loss than a launch failure. (Same guard, same reason, as
      // CyclesController.build and SessionTimerController.build.)
      return {};
    }
  }

  Future<void> _persist() async {
    final profileId = ref.read(activeProfileProvider);
    final raw = jsonEncode(
        state.map((k, v) => MapEntry(k, v.toIso8601String())));
    await ref.read(appPreferencesProvider).setString(_key(profileId), raw);
  }

  Future<void> setGoal(String nodeId, DateTime target) async {
    state = {...state, nodeId: target};
    await _persist();
  }

  Future<void> removeGoal(String nodeId) async {
    state = {...state}..remove(nodeId);
    await _persist();
  }

  /// Apply goals from an imported backup, as far as [mode] allows.
  ///
  /// A merge stays a merge: an imported goal wins for a node it names, and goals
  /// the backup does not mention are kept. Unlike the preference map — where the
  /// backup carries every key whether the learner ever set it or not, so
  /// `SettingsNotifier.applyBackup` cannot read intent off the file — a node
  /// only appears here because somebody picked a date for it. Naming it *is* the
  /// intent, so honouring it is the right merge.
  ///
  /// [ImportMode.restoreEverything] means "make this whole profile match the
  /// file", and a target date the learner set last week is exactly the kind of
  /// thing that mode is for undoing. So goals the backup does not name are
  /// dropped — which is what [goalsRemovedBy] counts for the confirmation.
  ///
  /// Returns how many it deleted, so the report afterwards can say what happened
  /// rather than repeat what was predicted. `BackupData.removedCustomisations`
  /// is the same value for the same reason: a report that echoes the prediction
  /// cannot notice when the two come apart.
  Future<int> applyBackup(Map<String, DateTime> goals, ImportMode mode) async {
    final dropped = goalsRemovedBy(state, goals, mode).toSet();
    if (goals.isEmpty && dropped.isEmpty) return 0;
    state = {
      for (final e in state.entries)
        if (!dropped.contains(e.key)) e.key: e.value,
      ...goals,
    };
    await _persist();
    return dropped.length;
  }

  /// The nodes whose goal an import in [mode] would delete: the ones [current]
  /// has a target for and [backup] does not name. Empty for the two modes that
  /// only ever add.
  ///
  /// One function, called twice — by the confirmation that counts them and by
  /// the import that deletes them — for the reason
  /// `BackupService._customisationsToRemove` is one function: a preview computed
  /// separately from the outcome is one that will eventually disagree with it,
  /// and this one is telling the user how much they are about to lose.
  static Iterable<String> goalsRemovedBy(
    Map<String, DateTime> current,
    Map<String, DateTime> backup,
    ImportMode mode,
  ) =>
      mode.replacesCustomisation
          ? current.keys.where((nodeId) => !backup.containsKey(nodeId))
          : const [];

  /// Drop every goal for the active profile (part of "clear settings").
  Future<void> clearAll() async {
    state = const {};
    await _persist();
  }
}

final goalsProvider =
    NotifierProvider<GoalsController, Map<String, DateTime>>(GoalsController.new);

/// Evaluated status for a node's goal (null if no goal is set).
///
/// Auto-disposed for the reason [progressNodeProvider] is. It used to be more
/// urgent than that: this element scanned the entire event log itself, through
/// `PaceEngine.averagePerDay`, so a kept-alive one meant that scan ran once per
/// node-you-once-looked-at on every mark, forever. The scan is gone either way —
/// the pace is one number for the whole profile and is derived once, in
/// [paceProvider] — so what an element costs now is a map lookup and a
/// subtraction, and what N goals cost is N of those rather than N full passes
/// over the log.
final goalStatusProvider =
    Provider.autoDispose.family<GoalStatus?, String>((ref, nodeId) {
  final target = ref.watch(goalsProvider)[nodeId];
  if (target == null) return null;
  final node = ref.watch(progressNodeProvider(nodeId));
  if (node == null) return null;
  // Goals persist as `DateTime` because that is what the date picker and the
  // settings file speak; the calendar day they mean is resolved here, once, at
  // the boundary into the domain.
  return GoalEvaluator.evaluate(
    remaining: node.remaining,
    from: Day.of(ref.watch(clockProvider)()),
    target: Day.of(target),
    currentPace: ref.watch(paceProvider),
  );
});
