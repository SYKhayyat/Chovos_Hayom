import 'dart:io';

import 'package:chovos_hayom/application/crash_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('chovos_crash');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // A still-open handle on Windows must not mask a real failure.
    }
  });

  CrashLog logFor({DateTime Function()? now}) =>
      CrashLog(directory: dir, now: now);

  test('records an error with its stack and context', () async {
    final log = logFor(now: () => DateTime(2026, 7, 23, 14, 30));
    await log.record(StateError('boom'), StackTrace.fromString('at frame one'));

    final text = await log.read();
    expect(text, contains('2026-07-23T14:30'));
    expect(text, contains('boom'));
    expect(text, contains('at frame one'));
  });

  test('the context says where it came from', () async {
    await logFor().record(Exception('x'), StackTrace.current,
        context: 'Flutter framework');
    expect(await logFor().read(), contains('Flutter framework'));
  });

  test('reading before anything has crashed gives empty, not an error',
      () async {
    expect(await logFor().read(), isEmpty);
  });

  test('appends rather than overwriting', () async {
    final log = logFor();
    await log.record(Exception('first'), StackTrace.fromString('a'));
    await log.record(Exception('second'), StackTrace.fromString('b'));

    final text = await log.read();
    expect(text, contains('first'));
    expect(text, contains('second'));
    expect(text.indexOf('first'), lessThan(text.indexOf('second')),
        reason: 'newest last');
  });

  test('a crash loop cannot grow the log without bound', () async {
    final log = logFor();
    for (var i = 0; i < CrashLog.maxRecords + 20; i++) {
      await log.record(Exception('crash $i'), StackTrace.fromString('frame'));
    }

    final text = await log.read();
    expect('--- '.allMatches(text).length, CrashLog.maxRecords);
    expect(text, isNot(contains('crash 0')), reason: 'oldest dropped first');
    expect(text, contains('crash ${CrashLog.maxRecords + 19}'));
  });

  test('clearing removes the log', () async {
    final log = logFor();
    await log.record(Exception('x'), StackTrace.current);
    await log.clear();
    expect(await log.read(), isEmpty);
  });

  test('an unwritable directory is survived silently', () async {
    // Recording a crash must never become a second crash.
    final log = CrashLog(directory: Directory('/definitely/not/a/real/path'));
    await expectLater(log.record(Exception('x'), StackTrace.current),
        completes);
    expect(await log.read(), isEmpty);
  });
}
