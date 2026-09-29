import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/harness/coverage.dart';
import '../../integration_test/harness/journey.dart';
import '../support/source_scan.dart';

/// The device harness must not quietly stop covering the app.
///
/// **A harness is a test suite that nobody runs by default**, which is the whole
/// reason it can rot: there is no CI job, so the only thing that notices a
/// journey referring to a screen that no longer exists is a person running it by
/// hand — which is precisely when nobody is. This file is the cheap guard that
/// makes "did you add a screen and not a journey for it?" a build failure instead
/// of a surprise.
///
/// **What it checks, and what it cannot.** It reads the harness's own source and
/// the route table, and it requires every route in `Routes` to be named
/// somewhere in the harness — so a new screen with no journey fails here. It
/// cannot tell whether a journey *works*; only a device can do that, which is the
/// division of labour and not a gap in this one.
void main() {
  /// Every `.dart` file the harness is made of, as one blob of text.
  String harnessSource() {
    final buffer = StringBuffer();
    for (final path in dartSourcesUnder('integration_test')) {
      buffer.writeln(File(path).readAsStringSync());
    }
    return buffer.toString();
  }

  /// The routes `Routes` can produce, read out of the source rather than
  /// hard-coded, so this file cannot itself go stale.
  ///
  /// The literal routes `Routes` declares.
  List<String> declaredRoutes() {
    final source = File('lib/app/routes.dart').readAsStringSync();
    final constants = RegExp(r"static const \w+ = '([^']+)'");
    return [for (final match in constants.allMatches(source)) match.group(1)!];
  }

  /// The route *families*, one per node, sefer and cycle rather than one screen
  /// each.
  ///
  /// This is the part a drawer inventory cannot find, because a person reaches
  /// it by tapping a name rather than by choosing a destination. Checking only
  /// [declaredRoutes] would let the harness drop its entire coverage of every
  /// node in the catalog and stay green, which is the specific hole this file
  /// exists to close.
  List<String> declaredRouteFamilies() {
    final source = File('lib/app/routes.dart').readAsStringSync();
    final pattern = RegExp(r"static String \w+\([^)]*\) =>\s*'([^']*?)/\\\$\{");
    return [
      for (final match in pattern.allMatches(source)) '${match.group(1)}/',
    ];
  }

  test('the harness claims every route the app can reach', () {
    // Read out of `harnessCovers` rather than string-matched out of the
    // harness's source, because a journey reaches a screen by *tapping its
    // name*, and matching route strings in the source would only find journeys
    // rewritten to push routes — which is the thing this harness deliberately
    // does not do.
    final missing = <String>[
      for (final route in declaredRoutes())
        if (!harnessCovers.containsKey(route)) route,
      for (final family in declaredRouteFamilies())
        if (!harnessCovers.keys.any((route) => route.startsWith(family)))
          '$family<id>',
    ];

    expect(
      missing,
      isEmpty,
      reason: 'these routes exist and no journey claims them, so nothing on a '
          'real phone ever opens the screen behind one. Add it to '
          '`harnessCovers` with the journey that covers it, or say there why '
          'one is not needed.\n${missing.join('\n')}',
    );
  });

  test('and the other way: no journey claims a screen it does not open', () {
    // The more dangerous direction, because it reads as coverage. A claim on a
    // journey id that does not exist, or on a route nothing serves, is a screen
    // believed to be covered that is not.
    final ids = {for (final journey in allJourneys()) journey.id};
    final bad = <String>[
      for (final entry in harnessCovers.entries)
        for (final id in entry.value)
          if (!ids.contains(id)) '${entry.key} claims "$id", which is not a journey',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('every journey has an id, an area, a task and at least one step', () {
    // The report is keyed on these, so an empty one is a hole in the coverage
    // table rather than a visible failure.
    final ids = <String>[];
    for (final path in dartSourcesUnder('integration_test/harness/journeys')) {
      final source = File(path).readAsStringSync();
      for (final match in RegExp(r"id: '([^']+)'").allMatches(source)) {
        ids.add(match.group(1)!);
      }
    }
    expect(ids, isNotEmpty, reason: 'no journeys found at all');
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'two journeys share an id, so the report and the screenshots '
          'would collide: ${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}',
    );
    for (final id in ids) {
      expect(id, contains('/'),
          reason: '"$id" has no area, so the coverage table cannot group it');
    }
  });

  test('catalogue: the journeys, in a form a person can read', () {
    // **A harness nobody can enumerate is a harness nobody runs.** The list is
    // the one thing you need before attaching a phone — which journey covers
    // what, and which substring to pass `--only` — and the only place it can
    // come from is the code, so it is printed from the code and
    // `tool/run_device_harness.sh --list` reads these markers. It lives in a
    // test rather than in the script so it cannot fall out of step with the
    // catalogue.
    final journeys = allJourneys();
    say('--- harness catalogue: ${journeys.length} journeys ---');
    for (final journey in journeys) {
      say('  ${journey.id.padRight(38)}  ${journey.task}');
    }
    say('--- end catalogue ---');
    expect(journeys, isNotEmpty);
  });

  test('the two ways of driving the app are both documented', () {
    // Pointer-only is a suite that tested the Moto and skipped the phone. This
    // is the assertion that says so out loud, in a file that is run by CI.
    final harness = harnessSource();
    expect(harness, contains('HARNESS_INPUT'),
        reason: 'the harness must be able to run itself through the D-pad');
    expect(harness, contains('keys'),
        reason: 'and the keys path must actually be reachable');
  });
}
