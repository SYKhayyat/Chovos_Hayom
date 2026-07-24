import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// One recorded crash.
class CrashRecord {
  const CrashRecord({
    required this.at,
    required this.error,
    required this.stack,
    this.context,
  });

  final DateTime at;
  final String error;
  final String stack;

  /// Where it came from ("Flutter framework", "uncaught async"), when known.
  final String? context;

  String format() => [
        '--- ${at.toIso8601String()}${context == null ? '' : ' · $context'}',
        error,
        stack.trimRight(),
        '',
      ].join('\n');
}

/// An on-device crash log.
///
/// The app had no crash reporting of any kind, so a bug that only reproduces on
/// a user's phone was unreportable — they could describe it, and that was all.
/// This is deliberately local: an app whose entire premise is that your learning
/// stays on your device should not start sending stack traces (which can carry
/// file paths and sefer names) to a third party. The user can read the log in
/// Settings and share it if *they* choose to.
///
/// The file is capped and trimmed to the most recent entries, so it can never
/// grow without bound on a device that crashes in a loop.
class CrashLog {
  CrashLog({this.directory, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Where the log is written. Null means the platform's app-support directory;
  /// tests pass a temp dir, which also keeps them off platform channels.
  final Directory? directory;
  final DateTime Function() _now;

  static const fileName = 'crash_log.txt';

  /// Keep the log readable and bounded; older entries are dropped first.
  static const maxRecords = 50;

  Directory? _resolved;

  /// Serialises [record] writes. Two records can arrive in the same instant — a
  /// framework error and an uncaught async error from the same failure — and
  /// each does a read-modify-write of the whole file, so without this the second
  /// to start reads before the first has written and clobbers it. Chaining makes
  /// them queue instead of race.
  Future<void> _writeChain = Future<void>.value();

  Future<File?> _file() async {
    try {
      _resolved ??= directory ?? await getApplicationSupportDirectory();
      return File('${_resolved!.path}${Platform.pathSeparator}$fileName');
    } catch (_) {
      // No writable directory (rare, and not worth crashing over — the whole
      // point of this class is to run when things are already going wrong).
      return null;
    }
  }

  /// Append a crash. Never throws: a failure to record a crash must not become
  /// a second crash.
  Future<void> record(Object error, StackTrace stack, {String? context}) async {
    // Stamp the time now, at the moment of the crash, not when the queued write
    // eventually runs — so a burst of records keeps its true order.
    final entry = CrashRecord(
      at: _now(),
      error: error.toString(),
      stack: stack.toString(),
      context: context,
    );
    final done = _writeChain.then((_) async {
      try {
        final file = await _file();
        if (file == null) return;
        final existing = await file.exists() ? await file.readAsString() : '';
        await file.writeAsString(_trim(existing + entry.format()));
      } catch (_) {
        // Swallowed on purpose: a failure to record a crash must not become a
        // second crash.
      }
    });
    // `done` never rejects (the catch is inside), so the chain stays healthy.
    _writeChain = done;
    return done;
  }

  /// The log as text, newest last. Empty when nothing has crashed.
  Future<String> read() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return '';
      return file.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Nothing useful to do.
    }
  }

  /// Drops the oldest entries so at most [maxRecords] remain. Entries start with
  /// the `--- ` marker written by [CrashRecord.format].
  static String _trim(String log) {
    final marker = RegExp(r'^--- ', multiLine: true);
    final starts = [for (final m in marker.allMatches(log)) m.start];
    if (starts.length <= maxRecords) return log;
    return log.substring(starts[starts.length - maxRecords]);
  }

  /// Installs the handlers and runs [body] inside a guarded zone, so that both
  /// framework errors and stray async errors are recorded.
  ///
  /// Errors are still forwarded to Flutter's default handler, so a debug build
  /// keeps printing them to the console exactly as before.
  Future<void> guard(FutureOr<void> Function() body) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack ?? StackTrace.current,
          context: 'Flutter framework');
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'uncaught async');
      return false; // false = also report it the usual way.
    };
    await runZonedGuarded(body, (error, stack) {
      record(error, stack, context: 'uncaught zone');
    });
  }
}
