import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/crash_log.dart';
import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';

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
/// The messenger, navigator and localizations are captured *before* the write,
/// so a sheet that pops itself before saving still reports its outcome (and so
/// no `BuildContext` is used across an async gap).
class WriteGuard {
  const WriteGuard(
      this._messenger, this._navigator, this._crashLog, this._l10n);

  /// Captures everything needed to report an outcome, up front.
  factory WriteGuard.of(BuildContext context, WidgetRef ref) => WriteGuard(
        ScaffoldMessenger.of(context),
        Navigator.of(context, rootNavigator: true),
        ref.read(crashLogProvider),
        AppLocalizations.of(context),
      );

  final ScaffoldMessengerState _messenger;
  final NavigatorState _navigator;
  final CrashLog _crashLog;

  /// Captured with the rest: the failure sentence and the *Details* label are
  /// resolved from the context that started the write, not from one that may be
  /// gone by the time it fails.
  final AppLocalizations _l10n;

  /// How long a failure stays on screen. Longer than the default: a message you
  /// only get one shot at reading should not be a message you can miss.
  static const failureDuration = Duration(seconds: 8);

  /// How long a message carrying an action stays. Long enough to walk a D-pad
  /// over to *Undo*, which is several presses from wherever the write left
  /// focus.
  static const actionDuration = Duration(seconds: 10);

  /// The plain case, and Flutter's own default.
  static const messageDuration = Duration(seconds: 4);

  /// Every snack bar the app shows, built the one way.
  ///
  /// `persist: false` is the entire reason this exists. Flutter defaults that
  /// flag to `action != null`, so *any* message with an Undo or a Details button
  /// stays up until something takes it away — and on a touchscreen that
  /// something is a swipe. A keypad phone has no swipe. Measured on the Sonim:
  /// dismissing the backup banner put "Backup reminder off — turn it back on in
  /// Settings → Backup" across the bottom third of a 324dp screen, where it sat
  /// for as long as anyone cared to watch, with no key on the device that would
  /// remove it. The user's report was that the warning could not be dismissed,
  /// and they were right — dismissing it replaced it with something permanent.
  ///
  /// So these time out again, as they did before the flag existed, with a longer
  /// window when there is an action worth reaching. Nothing changes on a
  /// touchscreen except that a bar the user ignored now leaves by itself.
  static SnackBar _bar(
    String message, {
    SnackBarAction? action,
    Duration? duration,
  }) =>
      SnackBar(
        content: Text(message),
        action: action,
        persist: false,
        duration:
            duration ?? (action == null ? messageDuration : actionDuration),
      );

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
      _messenger.showSnackBar(_bar(
        describe?.call(error) ?? _l10n.writeFailed(what),
        duration: failureDuration,
        action: SnackBarAction(
          label: _l10n.actionDetails,
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
      _messenger.showSnackBar(_bar(message, action: action));
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
