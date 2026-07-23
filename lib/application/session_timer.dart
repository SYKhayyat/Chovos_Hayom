import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences.dart';
import 'providers.dart';

/// A learning session being timed.
///
/// Elapsed time is derived from a start *instant* plus previously-accumulated
/// time, never from a tick counter — so it stays correct while the app is
/// backgrounded, asleep, or closed entirely.
class SessionTimerState {
  const SessionTimerState({
    this.runningSince,
    this.accumulated = Duration.zero,
    this.label,
    this.nodeId,
    this.unitIndex,
  });

  /// When the current run began, or null if paused.
  final DateTime? runningSince;

  /// Time banked from previous runs of this session.
  final Duration accumulated;

  /// What is being learned, for the banner ("Shabbos · daf 12").
  final String? label;

  /// The unit this session is for, so stopping it can log against it.
  final String? nodeId;
  final int? unitIndex;

  bool get isRunning => runningSince != null;

  /// True once the session exists at all — running, or paused with time on it.
  bool get isActive => isRunning || accumulated > Duration.zero;

  Duration elapsedAt(DateTime now) =>
      accumulated +
      (runningSince == null ? Duration.zero : now.difference(runningSince!));

  /// Whole minutes, rounded up — what gets written as `durationMin`. A session
  /// of any length counts as at least a minute.
  int minutesAt(DateTime now) {
    final seconds = elapsedAt(now).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 60).ceil();
  }

  Map<String, dynamic> toJson() => {
        if (runningSince != null) 'runningSince': runningSince!.toIso8601String(),
        'accumulatedSeconds': accumulated.inSeconds,
        if (label != null) 'label': label,
        if (nodeId != null) 'nodeId': nodeId,
        if (unitIndex != null) 'unitIndex': unitIndex,
      };

  factory SessionTimerState.fromJson(Map<String, dynamic> json) =>
      SessionTimerState(
        runningSince: json['runningSince'] == null
            ? null
            : DateTime.tryParse(json['runningSince'] as String),
        accumulated:
            Duration(seconds: (json['accumulatedSeconds'] as num?)?.toInt() ?? 0),
        label: json['label'] as String?,
        nodeId: json['nodeId'] as String?,
        unitIndex: (json['unitIndex'] as num?)?.toInt(),
      );
}

/// The one learning-session timer, owned by the app rather than by a sheet.
///
/// It used to be a `Stopwatch` living inside the logging modal: dismiss the
/// sheet — or let Android tear it down — and the elapsed time was gone. A timer
/// you have to keep staring at is not usable for its stated purpose, which is to
/// run *while you learn*. This one survives closing the sheet, leaving the
/// screen, backgrounding the app, and quitting it, because it is persisted and
/// derived from wall-clock instants.
class SessionTimerController extends Notifier<SessionTimerState> {
  @override
  SessionTimerState build() {
    final raw = ref.watch(appPreferencesProvider).getString(PrefKeys.sessionTimer);
    if (raw == null || raw.isEmpty) return const SessionTimerState();
    try {
      return SessionTimerState.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // A corrupt value must not stop the app from opening; a lost timer is a
      // far smaller loss than a launch failure.
      return const SessionTimerState();
    }
  }

  Future<void> _write(SessionTimerState next) async {
    state = next;
    final prefs = ref.read(appPreferencesProvider);
    if (!next.isActive) {
      await prefs.remove(PrefKeys.sessionTimer);
    } else {
      await prefs.setString(PrefKeys.sessionTimer, jsonEncode(next.toJson()));
    }
  }

  /// Start (or resume) timing. Starting for a *different* unit replaces the
  /// session rather than adding to it — two sedarim are not one session.
  Future<void> start({
    required DateTime now,
    String? label,
    String? nodeId,
    int? unitIndex,
  }) async {
    final sameTarget = state.nodeId == nodeId && state.unitIndex == unitIndex;
    await _write(SessionTimerState(
      runningSince: now,
      accumulated: sameTarget ? state.accumulated : Duration.zero,
      label: label ?? (sameTarget ? state.label : null),
      nodeId: nodeId,
      unitIndex: unitIndex,
    ));
  }

  /// Pause, banking the time run so far.
  Future<void> pause(DateTime now) async {
    if (!state.isRunning) return;
    await _write(SessionTimerState(
      accumulated: state.elapsedAt(now),
      label: state.label,
      nodeId: state.nodeId,
      unitIndex: state.unitIndex,
    ));
  }

  Future<void> toggle(DateTime now,
      {String? label, String? nodeId, int? unitIndex}) async {
    if (state.isRunning) return pause(now);
    return start(now: now, label: label, nodeId: nodeId, unitIndex: unitIndex);
  }

  /// Clear the session entirely (after it has been logged, or discarded).
  Future<void> reset() => _write(const SessionTimerState());
}

final sessionTimerProvider =
    NotifierProvider<SessionTimerController, SessionTimerState>(
        SessionTimerController.new);
