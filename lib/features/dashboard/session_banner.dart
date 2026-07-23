import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/session_timer.dart';
import '../../application/stats.dart';

/// The running-session strip: shows a live learning session wherever you are,
/// and lets you pause or discard it without hunting for the sheet you started
/// it in.
///
/// The timer is meant to run *while you learn*, which means the sheet that
/// started it is closed and you are looking at a sefer. Without something like
/// this, a session you forgot about would keep counting invisibly.
class SessionBanner extends ConsumerStatefulWidget {
  const SessionBanner({super.key});

  @override
  ConsumerState<SessionBanner> createState() => _SessionBannerState();
}

class _SessionBannerState extends ConsumerState<SessionBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redraws the readout only; the elapsed time itself is derived from
    // wall-clock instants held in the provider.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionTimerProvider);
    if (!session.isActive) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final now = ref.read(clockProvider)();
    final seconds = session.elapsedAt(now).inSeconds;
    final clock = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';

    return Container(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(session.isRunning ? Icons.timer : Icons.timer_off_outlined,
              size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.label == null
                  ? '$clock  ·  ${session.isRunning ? 'learning' : 'paused'}'
                  : '$clock  ·  ${session.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          IconButton(
            icon: Icon(session.isRunning ? Icons.pause : Icons.play_arrow),
            tooltip: session.isRunning ? 'Pause session' : 'Resume session',
            color: scheme.onPrimaryContainer,
            onPressed: () =>
                ref.read(sessionTimerProvider.notifier).toggle(now),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Discard session',
            color: scheme.onPrimaryContainer,
            onPressed: () => ref.read(sessionTimerProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }
}
