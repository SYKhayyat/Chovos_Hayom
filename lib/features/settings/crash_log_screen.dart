import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';

/// Reads back the on-device crash log.
///
/// The point is that a bug which only reproduces on the user's device stops
/// being unreportable. Nothing is sent anywhere: the log lives on the device,
/// and copying it out is the user's decision.
///
/// It reads the log through [crashLogProvider] rather than constructing its own,
/// so it is guaranteed to be the same file the write guard appends failures to —
/// the *Details* action on a failed write lands here and finds the entry.
class CrashLogScreen extends ConsumerStatefulWidget {
  const CrashLogScreen({super.key});

  @override
  ConsumerState<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends ConsumerState<CrashLogScreen> {
  String? _contents;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await ref.read(crashLogProvider).read();
    if (mounted) setState(() => _contents = text);
  }

  @override
  Widget build(BuildContext context) {
    final contents = _contents;
    final isEmpty = contents != null && contents.trim().isEmpty;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.crashLogTitle),
        actions: [
          if (contents != null && !isEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: l10n.crashLogCopy,
              // Through the guard like everything else — a clipboard write can
              // fail on its platform channel, and "copied" when nothing was is
              // exactly the class of lie the guard exists to stop.
              onPressed: () => guarded(
                context,
                ref,
                () => Clipboard.setData(ClipboardData(text: contents)),
                what: l10n.whatCopyingCrashLog,
                success: l10n.crashLogCopied,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.crashLogClear,
              onPressed: () async {
                await ref.read(crashLogProvider).clear();
                await _load();
              },
            ),
          ],
        ],
      ),
      body: contents == null
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.crashLogEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    contents,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
    );
  }
}
