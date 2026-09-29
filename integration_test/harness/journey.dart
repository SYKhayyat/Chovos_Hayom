import 'package:flutter_test/flutter_test.dart';

import 'action.dart';
import 'navigation.dart';
import 'device_profile.dart';

/// One thing a person was trying to do, start to finish.
///
/// **A journey, not a screen.** The unit here is a *task* — "mark a daf and watch
/// it roll up", "set Thursday off and see the plan ask for less", "back up and
/// restore" — because that is the only thing whose failure is meaningful. A test
/// that pumps a screen and checks it did not throw has proved that a widget tree
/// exists; it has not proved that a person can learn a daf.
///
/// So each journey names the task, says which area it belongs to, and lists the
/// steps a person would take. It records **no expected strings of its own** —
/// those live in the steps, next to the action that should produce them, which is
/// where a failure needs them.
class Journey {
  const Journey({
    required this.id,
    required this.area,
    required this.task,
    required this.steps,
    this.tags = const <String>{},
  });

  /// A stable slug: `planner/date-override-as-day-off`. Used for filtering a run
  /// and for naming a screenshot, so it has to survive a reworded title.
  final String id;

  /// The part of the app, for the coverage report.
  final String area;

  /// The task in a sentence, for the report and for whoever reads the failure.
  final String task;

  final List<Act> steps;

  /// Extra dimensions a journey is run under, beyond the two defaults.
  ///
  /// `keys: true` means this one *has* to be driven by the D-pad, because
  /// tapping is not a path the device's user has. `hebrew: true` means it only
  /// makes sense in the Hebrew locale.
  final Set<String> tags;

  bool get byKeysOnly => tags.contains('keys');
  bool get hebrewOnly => tags.contains('hebrew');

  @override
  String toString() => '$id — $task';
}

/// Says something to whoever is running the harness.
///
/// **The one sanctioned `print` in this tree.** A harness's whole output *is*
/// its report, and `flutter test` surfaces `print` and nothing else — there is no
/// logger on a device, and the alternative is a reporter nobody can read without
/// a debugger attached. It is one function with one `ignore` rather than a
/// comment on every line, so the exemption is visible as a decision instead of
/// as noise the analyzer asked us to paste.
void say(String line) {
  // ignore: avoid_print
  print(line);
}

/// What happened when a journey ran.
class JourneyResult {
  JourneyResult({
    required this.journey,
    required this.ok,
    this.failedStep,
    this.error,
    this.seconds = 0,
  });

  final Journey journey;
  final bool ok;

  /// Which step failed, and what it was trying to do. Null when it passed.
  final String? failedStep;
  final Object? error;
  final double seconds;

  String get line => ok
      ? '  ok    ${journey.id} (${seconds.toStringAsFixed(1)}s)'
      : '  FAIL  ${journey.id}\n'
          '          at: $failedStep\n'
          '          ${error.toString().split('\n').join('\n          ')}';
}

/// Runs journeys and keeps going.
///
/// **Every journey runs even after one fails, and every failure is reported.**
/// The alternative — the first failure ends the run — is what makes an
/// end-to-end suite useless: on a first run against real hardware most failures
/// are the harness's own fault, and stopping at the first one means a person
/// fixes them one at a time over a day. So a failure is recorded, a screenshot
/// is taken, and the next journey starts.
class HarnessRunner {
  HarnessRunner(this.results);

  final List<JourneyResult> results;

  int get passed => results.where((r) => r.ok).length;
  int get failed => results.length - passed;

  /// Runs [journeys], driving each with [input].
  Future<void> run(
    WidgetTester tester,
    DeviceProfile device,
    HarnessInput input, {
    List<Journey> journeys = const [],
  }) async {
    for (final journey in journeys) {
      // **Between journeys, not between steps, and not at all was the bug.**
      // The first run on real hardware passed journey 1 and failed all 34 after
      // it on their first step, because journey 1 left the drawer open and
      // nothing put it back. One journey's leftovers reaching the next is a
      // harness defect, not a property of the app: a person starts each task
      // from a screen they chose.
      //
      // The reset is best-effort on purpose. If it cannot get home — the app is
      // mid-dialog, or a previous journey genuinely wedged it — the next journey
      // should still run and report its own failure, rather than the whole run
      // dying on someone else's leftovers.
      try {
        final reset = HarnessContext(tester, device, input);
        for (final act in backToHome()) {
          await act.run(reset);
        }
      } catch (e) {
        say('  (could not get home before ${journey.id}: $e)');
      }
      results.add(await _runOne(tester, device, input, journey));
    }
  }

  Future<JourneyResult> _runOne(
    WidgetTester tester,
    DeviceProfile device,
    HarnessInput input,
    Journey journey,
  ) async {
    final watch = Stopwatch()..start();
    final context = HarnessContext(tester, device, input);
    String? failedStep;
    Object? error;
    try {
      for (var i = 0; i < journey.steps.length; i++) {
        final step = journey.steps[i];
        try {
          await step.run(context);
        } catch (e) {
          failedStep = '${i + 1}/${journey.steps.length} — ${step.intent}';
          error = e;
          // A step that threw has left the app in a state nobody can reason
          // about, so the rest of the journey is abandoned rather than run
          // against a screen the person never meant to be on. The *next* journey
          // still runs, which is the part that matters.
          break;
        }
      }
    } catch (e) {
      failedStep ??= 'before the first step';
      error = e;
    }
    watch.stop();
    if (error != null) {
      // The screenshot is the point of a device harness: the text of a failure
      // says what was expected, and the image is the only thing that says what
      // the screen actually looked like.
      try {
        await context.screenshot('FAIL-${journey.id.replaceAll('/', '-')}');
      } catch (_) {
        // A harness that cannot take a picture must not also lose the failure.
      }
    }
    return JourneyResult(
      journey: journey,
      ok: error == null,
      failedStep: failedStep,
      error: error,
      seconds: watch.elapsedMilliseconds / 1000,
    );
  }

  /// The report, as text. Printed at the end of a run and written to a file, so
  /// a person reading CI output does not have to scroll.
  String report() {
    final buffer = StringBuffer()
      ..writeln('\n$passed passed, $failed failed, ${results.length} journeys')
      ..writeln('-' * 72);
    for (final result in results) {
      buffer.writeln(result.line);
    }
    if (failed > 0) {
      buffer
        ..writeln('-' * 72)
        ..writeln('Failed, by area:');
      final byArea = <String, List<JourneyResult>>{};
      for (final result in results.where((r) => !r.ok)) {
        byArea.putIfAbsent(result.journey.area, () => []).add(result);
      }
      for (final entry in byArea.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value.map((r) => r.journey.id).join(', ')}');
      }
    }
    return buffer.toString();
  }

  /// What ran, grouped by area, and how much of each area passed.
  ///
  /// Printed on every run including a clean one, because "which journeys exist
  /// and which of them passed" is the question a coverage report exists to
  /// answer and a green tick alone does not.
  String coverage() {
    final byArea = <String, List<JourneyResult>>{};
    for (final result in results) {
      byArea.putIfAbsent(result.journey.area, () => []).add(result);
    }
    final buffer = StringBuffer()
      ..writeln('\nCoverage by area')
      ..writeln('-' * 72);
    final areas = byArea.keys.toList()..sort();
    for (final area in areas) {
      final inArea = byArea[area]!;
      final good = inArea.where((r) => r.ok).length;
      buffer.writeln('  ${area.padRight(14)} $good/${inArea.length} passed'
          '  ${inArea.map((r) => r.journey.id.split('/').last).join(', ')}');
    }
    return buffer.toString();
  }
}
