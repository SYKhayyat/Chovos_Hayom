import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// What a screen shows when the data it needs could not be loaded.
///
/// The three places this replaces each rendered `Center(child: Text('Error: $e'))`
/// — a raw exception, in English, with no way forward. That is the one moment a
/// user meets a failure *outside* the write guard, and it was the only failure
/// path in the app that did none of what the guard does: it did not say what
/// happened in a sentence, it did not record anything, and it offered no action,
/// so a transient database open failure looked identical to a permanently broken
/// install and left "force-quit the app" as the only move.
///
/// This does the same four things the guard does, in the same order:
///
/// 1. **Says what failed**, in a sentence about the user's data rather than
///    about a `FileSystemException`.
/// 2. **Says what it means for their learning** — every one of these is a *read*
///    that failed, so nothing was lost, and that is the first thing worth
///    knowing.
/// 3. **Records it to the crash log**, once, so *Open crash log* is not a
///    promise of something that isn't there. Provider errors never reached the
///    log before: `FlutterError.onError` doesn't see an `AsyncValue.error`.
/// 4. **Offers the way out** — retry first, because a Drift open that lost a
///    race succeeds on the second try, and the details underneath for when it
///    doesn't.
class ErrorView extends ConsumerStatefulWidget {
  const ErrorView({
    super.key,
    required this.title,
    required this.body,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  /// One line naming what could not be loaded.
  final String title;

  /// What it means — in particular, whether anything was lost.
  final String body;

  final Object error;
  final StackTrace? stackTrace;

  /// Invalidates whatever provider failed. Null hides the retry button, for the
  /// rare failure that retrying cannot fix.
  final VoidCallback? onRetry;

  @override
  ConsumerState<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends ConsumerState<ErrorView> {
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    // Once per mount, not per build: a rebuild while the error is on screen must
    // not append the same failure again and push the useful history out of a
    // capped log. `initState` cannot await, and the crash log never throws.
    unawaited(ref.read(crashLogProvider).record(
          widget.error,
          widget.stackTrace ?? StackTrace.empty,
          context: widget.title,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: scheme.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.body, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onRetry != null)
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.errorRetry),
                      onPressed: widget.onRetry,
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: Text(l10n.errorOpenCrashLog),
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.crashLog),
                  ),
                  TextButton.icon(
                    icon: Icon(
                        _showDetails ? Icons.expand_less : Icons.expand_more,
                        size: 18),
                    label: Text(_showDetails
                        ? l10n.errorHideDetails
                        : l10n.errorShowDetails),
                    onPressed: () =>
                        setState(() => _showDetails = !_showDetails),
                  ),
                ],
              ),
              if (_showDetails) ...[
                const SizedBox(height: 16),
                Text(l10n.errorDetailsHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Selectable so the user can copy the one line that matters
                  // into a bug report without sending the whole log.
                  child: SelectableText(
                    '${widget.error}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
