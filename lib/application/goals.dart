import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/usecases/goal_evaluator.dart';
import '../domain/usecases/pace_engine.dart';
import 'providers.dart';
import 'stats.dart';

/// Target finish dates per node, scoped to the active profile and persisted.
class GoalsController extends Notifier<Map<String, DateTime>> {
  String _key(String profileId) => 'goals:$profileId';

  @override
  Map<String, DateTime> build() {
    final profileId = ref.watch(activeProfileProvider);
    final raw = ref.watch(appPreferencesProvider).getString(_key(profileId));
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in map.entries) e.key: DateTime.parse(e.value as String),
    };
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
}

final goalsProvider =
    NotifierProvider<GoalsController, Map<String, DateTime>>(GoalsController.new);

/// Evaluated status for a node's goal (null if no goal is set).
final goalStatusProvider = Provider.family<GoalStatus?, String>((ref, nodeId) {
  final target = ref.watch(goalsProvider)[nodeId];
  if (target == null) return null;
  final node = ref.watch(progressNodeProvider(nodeId));
  final events = ref.watch(eventsProvider).asData?.value;
  if (node == null || events == null) return null;
  final now = ref.watch(clockProvider)();
  final pace = PaceEngine.averagePerDay(events, now: now, windowDays: 30);
  return GoalEvaluator.evaluate(
    remaining: node.remaining,
    from: now,
    target: target,
    currentPace: pace,
  );
});
