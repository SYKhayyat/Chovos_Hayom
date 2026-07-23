import 'package:chovos_hayom/application/crash_log.dart';

/// A [CrashLog] that keeps its entries in memory.
///
/// The real one writes a file, and a widget test's fake-async zone never pumps
/// the real event loop, so awaiting that write inside `pumpAndSettle` deadlocks.
/// The file behaviour is covered directly in `test/application/crash_log_test`;
/// what a *widget* test needs to know is only whether the guard recorded
/// anything, and under what name.
class RecordingCrashLog extends CrashLog {
  RecordingCrashLog();

  final entries = <String>[];

  @override
  Future<void> record(Object error, StackTrace stack, {String? context}) async {
    entries.add('${context ?? 'unlabelled'}: $error');
  }

  @override
  Future<String> read() async => entries.join('\n');

  @override
  Future<void> clear() async => entries.clear();
}
