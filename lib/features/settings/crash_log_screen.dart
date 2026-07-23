import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crash log'),
        actions: [
          if (contents != null && !isEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy to clipboard',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: contents));
                messenger.showSnackBar(
                    const SnackBar(content: Text('Crash log copied')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear log',
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nothing has crashed. \n\n'
                      'If something ever does, the details land here — on this '
                      'device only — so you can copy them into a bug report.',
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
