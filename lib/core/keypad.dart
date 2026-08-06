import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Support for phones that have no touchscreen at all — a D-pad, a centre key
/// and a numeric keypad, and nothing else.
///
/// The device this was built against is a Sonim XP5s: Android 7.1.2, a 320x432
/// screen at 213dpi, which is **240 x 324 logical pixels**. Material's smallest
/// design target is 320x480, so this is a quarter narrower and a third shorter
/// than anything upstream accounts for, and every fixed width or fixed aspect
/// ratio in the app was written for a screen that is not this one.
///
/// Measured on that device before any of this existed: the app ran, focus moved
/// on the D-pad and the centre key activated things — Flutter gives all of that
/// for free — but *nothing on screen ever changed to say what was selected*.
/// Pressing the centre key on the unit grid opened "Bulk actions", because focus
/// had started on an app bar icon and there was no way to know. One more press
/// would have marked an entire sefer learned. That is the defect this file
/// exists to remove: the app was operable and blind.

/// Widths below this belong to a keypad phone rather than a small touchscreen.
///
/// The narrowest ordinary phone is 320dp and a common one is 360dp, so this
/// threshold cannot fire on a real touchscreen; the target device is 240dp.
const double kCompactWidth = 300;

/// Whether the app is drawing on a keypad-phone screen.
///
/// Layout decisions keyed off this are about *width*, not about the input
/// device — a 240dp screen needs one column whether or not it can be touched.
bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactWidth;

/// The keys that open a context menu on the focused control.
///
/// Android's `KEYCODE_MENU` — the left soft key on the XP5s keypad — arrives as
/// [LogicalKeyboardKey.contextMenu], the same logical key a Windows menu key
/// sends, so the bindings the desktop build already had reach the phone's menu
/// key unchanged. Shift+F10 is kept for keyboards that have no menu key.
Map<ShortcutActivator, VoidCallback> contextMenuBindings(VoidCallback open) => {
      const SingleActivator(LogicalKeyboardKey.f10, shift: true): open,
      const SingleActivator(LogicalKeyboardKey.contextMenu): open,
    };

/// Applies the handful of theme tweaks a 240dp screen needs, or nothing at all
/// on any other screen.
///
/// This sits in `MaterialApp.builder` rather than in the `ThemeData` itself
/// because the decision needs a `MediaQuery`, which does not exist yet where the
/// theme is built.
Widget compactTheme(BuildContext context, Widget child) {
  if (!isCompact(context)) return child;
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        // Material's 22sp title needs about 160dp for two ordinary words, and
        // "Learning cycles" was arriving as "Learning…" on a bar that had the
        // room and was just asking for too much of it. One step down, plus half
        // the usual gap after the back button, fits the longest title this app
        // has — and it is still the largest text on the screen.
        titleTextStyle: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.onSurface),
        titleSpacing: 8,
      ),
    ),
    child: child,
  );
}

/// One app bar action, described rather than built, so the same list can be
/// rendered either as icons or as rows in a menu.
class BarAction {
  const BarAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.tint,
  });

  final IconData icon;

  /// Its tooltip on a wide screen and its visible name in the overflow menu.
  final String label;

  /// Null disables it, in the bar and in the menu alike.
  final VoidCallback? onPressed;

  /// A colour the icon carries state in — the sort button's "a sort is active".
  /// Whatever tint the actions carry is also given to the overflow icon, so
  /// folding them away does not hide the fact that one of them is switched on.
  final Color? tint;
}

/// Lays out app bar [actions]: separate buttons where there is room, one
/// overflow menu where there is not.
///
/// A 240dp bar has room for a drawer button and about one action. With three it
/// left the title roughly ten pixels, and since both bars in this app scale
/// their title to fit rather than truncate it, what you got was the app's name
/// shrunk to an illegible dash — on every screen, including the unit grid, which
/// therefore never said which sefer you were looking at.
///
/// Folding costs nothing: a menu row carries a label as well as an icon, so on
/// the phone these become *more* discoverable than unlabelled icons were.
List<Widget> barActions(
  BuildContext context,
  List<BarAction> actions, {
  required String moreTooltip,
}) {
  // A single action is left alone even on the phone: a back button, a title and
  // one icon fit in 240dp, and burying one item under a menu costs a key press
  // to reveal what the icon already said.
  if (!isCompact(context) || actions.length <= 1) {
    return [
      for (final a in actions)
        IconButton(
          icon: Icon(a.icon),
          color: a.tint,
          tooltip: a.label,
          onPressed: a.onPressed,
        ),
    ];
  }
  final tint = actions.map((a) => a.tint).firstWhere((c) => c != null,
      orElse: () => null);
  return [
    PopupMenuButton<int>(
      icon: Icon(Icons.more_vert, color: tint),
      tooltip: moreTooltip,
      onSelected: (i) => actions[i].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(actions[i].icon, color: actions[i].tint),
              title: Text(actions[i].label),
            ),
          ),
      ],
    ),
  ];
}

/// Makes a scroll view reachable with a D-pad when nothing inside it can focus.
///
/// Directional focus moves *between focusable widgets*, and scrolls only as a
/// side effect of bringing the newly focused one into view. A screen made of
/// plain text and figures — Statistics is the whole of one — contains no
/// focusable widget at all, so the D-pad has nowhere to move focus to and the
/// list never scrolls by a single pixel. Measured on the device: four presses of
/// "down" on Statistics moved nothing, and the chart below the fold could not be
/// reached by any sequence of keys.
///
/// This wrapper takes focus itself and turns up/down into scrolling. It only
/// does so while it holds *primary* focus, which is what keeps it out of the way
/// on screens that do have focusable children: there, traversal reaches them,
/// this node never holds primary focus, and the ordinary ensure-visible
/// behaviour is left alone.
class DpadScroll extends StatefulWidget {
  const DpadScroll({
    super.key,
    required this.builder,
    this.autofocus = true,
    this.skipTraversal = true,
  });

  /// Builds the scroll view, which must be given the controller passed in —
  /// that controller is what the arrow keys move. Handing it out this way keeps
  /// the lifetime here, so a `ConsumerWidget` screen can use this without
  /// growing a [State] of its own purely to own a controller.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// Whether to claim focus on arrival. True is right for a screen with nothing
  /// else to focus; false where something more useful should start focused.
  final bool autofocus;

  /// Whether directional focus steps *past* this wrapper rather than onto it.
  ///
  /// True — the default — is right for a whole screen made of figures: nothing
  /// else here can hold focus, [autofocus] has already claimed it, and being
  /// skipped is what keeps the wrapper out of the way on a screen that does
  /// have focusable children.
  ///
  /// False is for a scroll view that sits *under* something focusable, which on
  /// arrival is where focus starts. The report's tab bar is the case: pressing
  /// down from a tab has to be able to land somewhere, and [autofocus] cannot
  /// help — it only fires when nothing in the scope holds focus, and after a tab
  /// switch the tab itself does. Skipped, the wrapper is unreachable and the
  /// section below it never scrolls, which is the whole defect this class was
  /// written to remove, arrived at from the other side.
  final bool skipTraversal;

  @override
  State<DpadScroll> createState() => _DpadScrollState();
}

class _DpadScrollState extends State<DpadScroll> {
  final ScrollController _controller = ScrollController();
  final FocusNode _node = FocusNode(debugLabel: 'DpadScroll');

  @override
  void dispose() {
    _controller.dispose();
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Repeats included: holding "down" should keep scrolling, which is the only
    // bearable way to cross a long screen on a keypad.
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    // While a child holds focus, traversal owns the arrow keys.
    if (!_node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (!_controller.hasClients) return KeyEventResult.ignored;

    final viewport = _controller.position.viewportDimension;
    // Just under a screenful, so a line of context survives each press and you
    // can tell the screen moved rather than jumped.
    final page = viewport * 0.8;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => viewport * 0.35,
      LogicalKeyboardKey.arrowUp => -viewport * 0.35,
      LogicalKeyboardKey.pageDown => page,
      LogicalKeyboardKey.pageUp => -page,
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;

    final position = _controller.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    // At either end the key is deliberately *not* claimed, so focus can still
    // leave the screen — otherwise the app bar becomes unreachable from a
    // screen like this one.
    if (target == position.pixels) return KeyEventResult.ignored;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      // Held, but — by default — never stopped at: traversal on a screen that
      // *does* have focusable children should step between those, not through
      // the wrapper around them. See [skipTraversal] for the case that wants
      // the opposite.
      skipTraversal: widget.skipTraversal,
      onKeyEvent: _onKey,
      // A permanently visible thumb is the only clue on a keypad phone that
      // there is anything below the fold — there is no drag-to-discover. On
      // every other device the scrollbar keeps its usual fade-in behaviour, so
      // this changes nothing there.
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: isCompact(context),
        child: widget.builder(context, _controller),
      ),
    );
  }
}

/// Draws a ring around whatever currently has focus, anywhere in the app.
///
/// Material paints a focus overlay on its own controls, but it is a low-opacity
/// wash tuned for a desktop pointer sitting beside a keyboard, and on a 2.6"
/// screen it is not perceptible — measured, not assumed. Worse, the controls
/// this app builds itself paint a filled background *over* that overlay, which
/// the unit grid had already worked around with a hand-drawn ring of its own.
///
/// One overlay at the root fixes every case at once, including the screens that
/// have not been written yet: it reads the focused element's rectangle straight
/// out of the render tree, so a widget needs to do nothing to take part.
/// The ring itself, so a test can assert both that it appears on a keypad
/// screen and that it stays away on every other one.
const Key focusRingKey = Key('focus-ring');

class FocusRingOverlay extends StatefulWidget {
  const FocusRingOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<FocusRingOverlay> createState() => _FocusRingOverlayState();
}

class _FocusRingOverlayState extends State<FocusRingOverlay> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
    // A second, separate subscription, and not a redundant one: *which* node has
    // focus and *whether* focus should be shown at all are two notifications on
    // two listener lists. Listening only to the first meant the ring never
    // appeared the moment it was supposed to — when the user reached for a key
    // for the first time — because that changes the mode, not the focus.
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    super.dispose();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _highlightChanged(FocusHighlightMode mode) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Material's *own* focus overlays are driven by the highlight strategy, and
    // on a keypad phone they should be on from the start rather than from the
    // first key press. Setting it notifies every focus listener — including this
    // one, which responds with `setState` — so it cannot be done while a build
    // is in flight, which is exactly what doing it inside `build` amounted to.
    final wanted = isCompact(context)
        ? FocusHighlightStrategy.alwaysTraditional
        : FocusHighlightStrategy.automatic;
    if (FocusManager.instance.highlightStrategy == wanted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.highlightStrategy = wanted;
    });
  }

  /// Whether a ring should be drawn at all right now.
  ///
  /// This is what keeps the overlay from changing anything on a touchscreen.
  /// Everywhere except a keypad phone it defers to Flutter's own highlight
  /// mode, which is "traditional" only once a key has actually been pressed —
  /// so a phone or tablet user who never touches a keyboard never sees a ring,
  /// and a desktop user who tabs through gets a much clearer one than before.
  ///
  /// On a compact screen there is no touchscreen to defer to: the first key
  /// press is already navigation, and waiting for one before showing where
  /// focus *is* gets the order backwards.
  bool _ringsVisible(BuildContext context) =>
      isCompact(context) ||
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// Where the focused widget is on screen, or null if there is nothing to ring.
  Rect? _focusRect() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || !focused.hasPrimaryFocus) return null;
    final context = focused.context;
    if (context == null) return null;
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return null;
    final origin = object.localToGlobal(Offset.zero);
    if (!origin.dx.isFinite || !origin.dy.isFinite) return null;
    final rect = origin & object.size;
    if (rect.isEmpty) return null;

    // A text field draws its own caret and selection; ringing it as well only
    // adds noise around the one control whose focus is already obvious.
    if (focused.context!.widget is EditableText) return null;

    // Whole-screen nodes — the scroll wrapper above, a route's own focus scope —
    // would outline the entire display, which says nothing about *what* is
    // selected. Those are skipped rather than drawn.
    final screen = MediaQuery.sizeOf(context);
    if (rect.width * rect.height > screen.width * screen.height * 0.6) {
      return null;
    }
    return rect;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      // A rectangle read out of the render tree goes stale the moment the thing
      // it describes slides up the screen, and focus does not change while a
      // list scrolls. Re-reading on every scroll notification is what keeps the
      // ring attached to its widget.
      onNotification: (_) {
        if (mounted) setState(() {});
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Builder(builder: (context) {
            if (!_ringsVisible(context)) return const SizedBox.shrink();
            final rect = _focusRect();
            if (rect == null) return const SizedBox.shrink();
            return Positioned.fromRect(
              // Sitting just outside the widget, so it frames rather than
              // covers — a 64dp grid cell has no room to give up to a border.
              rect: rect.inflate(2),
              child: IgnorePointer(
                child: DecoratedBox(
                  key: focusRingKey,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.primary, width: 2),
                    // A wash inside the ring as well: on a screen this small the
                    // outline alone is easy to lose against dense text.
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
