import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/crash_log.dart';
import '../../application/providers.dart';

/// The one policy for a write the user started.
///
/// Error handling used to be per-call-site and therefore inconsistent: some
/// writes were wrapped in a try/catch with a snackbar, the identical write sixty
/// lines away was fire-and-forget, and one — *Log today's daf* — was both
/// fire-and-forget **and** reported "Logged ✓" unconditionally, so a write that
/// failed was shown to the user as a success. In an app whose whole point is
/// that your learning is recorded, telling someone it was recorded when it was
/// not is the worst possible failure mode: they have no reason to look again.
///
/// Every write now goes through here, and here does four things in a fixed
/// order:
///
/// 1. **Awaits the write.** Nothing is fire-and-forget, so nothing can fail
///    silently. (`unawaited_futures` catches the ones inside `async` bodies; the
///    rest were found by hand and are now all here.)
/// 2. **Reports success only after it succeeded.** The optional [success]
///    message is shown *after* the await returns, never before it.
/// 3. **Records the failure** to the on-device [CrashLog], tagged with what the
///    user was doing — so the log reads "Marking Shabbos daf 2 learned" rather
///    than a bare stack trace.
/// 4. **Says so, in one sentence, in one voice**, with a *Details* action that
///    opens the crash log — the one moment the crash log is actually worth
///    offering.
///
/// The messenger and navigator are captured *before* the write, so a sheet that
/// pops itself before saving still reports its outcome (and so no `BuildContext`
/// is used across an async gap).
class WriteGuard {
  const WriteGuard(this._messenger, this._navigator, this._crashLog);

  /// Captures everything needed to report an outcome, up front.
  factory WriteGuard.of(BuildContext context, WidgetRef ref) => WriteGuard(
        ScaffoldMessenger.of(context),
        Navigator.of(context, rootNavigator: true),
        ref.read(crashLogProvider),
      );

  final ScaffoldMessengerState _messenger;
  final NavigatorState _navigator;
  final CrashLog _crashLog;

  /// How long a failure stays on screen. Longer than the default: a message you
  /// only get one shot at reading should not be a message you can miss.
  static const failureDuration = Duration(seconds: 8);

  /// Runs [write] and reports what happened. Returns true when it succeeded, so
  /// a caller can decide whether to close a form or leave it open with the
  /// user's input intact.
  ///
  /// [what] names the action as a phrase that completes "… failed" — e.g.
  /// "Marking this daf learned", "Saving your settings". It is both the
  /// user-facing sentence and the label the crash log files the error under.
  /// [describe] overrides the message for errors the app can explain better than
  /// a generic failure can (a malformed backup names the field that is wrong).
  Future<bool> run(
    Future<void> Function() write, {
    required String what,
    String? success,
    SnackBarAction? undo,
    String Function(Object error)? describe,
  }) async {
    try {
      await write();
    } catch (error, stack) {
      await _crashLog.record(error, stack, context: what);
      _messenger.showSnackBar(SnackBar(
        content: Text(describe?.call(error) ?? '$what failed.'),
        duration: failureDuration,
        action: SnackBarAction(
          label: 'Details',
          onPressed: () => _navigator.pushNamed(Routes.crashLog),
        ),
      ));
      return false;
    }
    if (success != null) report(success, action: undo);
    return true;
  }

  /// Say something on the same messenger failures use.
  ///
  /// For the outcomes that are neither a plain success nor a failure: a file
  /// dialog the user cancelled, a count that is only known after the write
  /// ("42 events removed"), or a form rejecting its own input before there is
  /// anything to write. Having it here is what stops a screen from capturing a
  /// second messenger and quietly growing a second set of conventions.
  void report(String message, {SnackBarAction? action}) =>
      _messenger.showSnackBar(SnackBar(content: Text(message), action: action));
}

/// [WriteGuard.of] + [WriteGuard.run] in one call — the shape almost every call
/// site wants. Kept as a free function so a write reads as one statement.
Future<bool> guarded(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() write, {
  required String what,
  String? success,
  SnackBarAction? undo,
  String Function(Object error)? describe,
}) =>
    WriteGuard.of(context, ref).run(
      write,
      what: what,
      success: success,
      undo: undo,
      describe: describe,
    );
