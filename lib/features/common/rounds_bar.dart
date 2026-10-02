import 'package:flutter/material.dart';

/// A sefer's progress bar: one line per round the reader has something to show
/// (#46).
///
/// **Why more than one line.** Learning is the first pass (#45), so "learned" and
/// "been over more than once" are genuinely different numbers. A sefer where
/// you have learned 3 of 10 and not been back to any of them reads `3/10` over
/// `0/10` — and that gap is the thing worth seeing, because it says the new
/// ground has not been retained yet. One bar cannot say both.
///
/// **A line with nothing on it is not drawn.** [extra] entries of 0 are dropped
/// rather than shown as an empty track: an empty second line reads as "you are
/// behind" when it means "there is no second round yet", which is the opposite.
/// So a bar grows downward as rounds actually happen and never carries a
/// decorative blank.
///
/// **Colour is what separates the lines**, because at 240dp the bars are 6
/// logical pixels tall and a second line has to be thinner still — too thin to
/// tell apart by position alone. Beyond [_maxLines] the remaining rounds are not
/// drawn separately; [overflow] says so in words, because a bar that silently
/// stops telling the truth about how deep it goes is worse than a bar that admits
/// it.
class RoundsBar extends StatelessWidget {
  const RoundsBar({
    super.key,
    required this.learned,
    required this.total,
    this.extra = const [],
    this.overflow = 0,
  });

  /// Units learned — the first round, and the only one always drawn.
  final int learned;
  final int total;

  /// Counts of units finished more than once, more than twice, … in that order.
  /// Zeroes are skipped; see the class note for why.
  final List<int> extra;

  /// How many further rounds exist beyond [extra] and are not drawn.
  final int overflow;

  /// **Three.** One for learned, one for been over twice, one for three times.
  ///
  /// Common sense rather than a measured fit: the extra lines are 3px on a
  /// 6px primary, and three of them is where a fourth stops being a line and
  /// starts being a stripe. Deeper rounds are still *reported* — the bar says so
  /// and the statistics screen lists them — just not drawn.
  static const _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Nothing learned and no units: there is no bar to draw. An empty track
    // here would read as "0% done" on a sefer that does not exist yet, which is
    // a fact about the catalog rather than about the reader.
    if (total <= 0 || learned <= 0) return const SizedBox.shrink();

    final lines = <int>[
      learned,
      // Stop at the cap: a reader with nine rounds does not get nine lines.
      for (final n in extra.take(_maxLines - 1))
        if (n > 0) n,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _Line(
            value: lines[i] / total,
            // The first line keeps the app's primary; the extras walk the
            // secondary and tertiary so they stay distinguishable from it *and*
            // from each other in both light and dark.
            color: i == 0
                ? scheme.primary
                : (i == 1 ? scheme.secondary : scheme.tertiary),
            // Thinner as the stack grows, so the primary line never loses its
            // prominence to a line about a rarer round.
            height: i == 0 ? 6.0 : (i == 1 ? 3.0 : 2.0),
          ),
        ],
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+$overflow',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.value, required this.color, required this.height});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0.0, 1.0),
        backgroundColor: scheme.surfaceContainerHighest,
        color: color,
      ),
    );
  }
}
