import 'package:flutter/material.dart';

import '../../core/calendar.dart';
import '../../core/date_parse.dart';
import '../../core/day.dart';
import '../../l10n/generated/app_localizations.dart';

/// Setting a date, in either calendar, by typing it or by picking it.
///
/// **One control, because there are two of these already.** A cycle's start date
/// and a plan's date override were both a `showDatePicker` call, which is a
/// Gregorian grid: a reader who thinks in Hebrew dates could set a plan's
/// override only by navigating that grid, and could not type `ד׳ טבת תשפ״ו` or
/// `4 Tevat 5786` at all. The same defect as #30 (the planner printing an ISO
/// date under a Hebrew heading) one layer down — the app can *display* either
/// calendar and could not be *told* one in the other.
///
/// **Typing and picking are both here, on purpose.** Replacing a picker with a
/// text field would be a straight trade: better for a reader who knows the date
/// and reads Hebrew, worse for everyone who wants to look at a year and tap. So
/// the field is the way to *name* a date and the grid is the way to *find* one,
/// and either one ends the dialog with the day.
///
/// The field is seeded with the day being changed, in the reader's own calendar,
/// so the dialog never opens on something the reader cannot read — and it shows
/// what it has understood, live, as they type. That echo is the point: a field
/// that silently keeps its old value has swallowed a typo, and a field that
/// silently reinterprets one has invented a date.
///
/// **A screen and not a dialog**, which was the second attempt.
///
/// It began as an `AlertDialog`, and the widget tests for it passed at 800x600
/// and the 240dp test of the screen that opens it never opened it. Rendering it
/// at 320x432 — the Sonim's real pixel count — showed a dialog whose title was
/// cut off above the top of the screen and whose help text was cut off mid-line:
/// a title, a field, a line naming the formats accepted, the echo of what it
/// read, and two buttons is more content than 324 logical pixels of screen. It
/// did not overflow once it was made scrollable; it overflowed *off the top*,
/// which is the same defect wearing a quieter hat.
///
/// So it is a full-screen route, which is Material's own answer to the same
/// question and needs no `isCompact` branch: everything fits, nothing is clipped,
/// and the app bar is already smaller on this device. It also takes the file out
/// of `text_prompt_guard_test`'s net — a `Scaffold` rather than an `AlertDialog`
/// is not the shape that guard exists to refuse, so the escape hatch this needed
/// is gone rather than justified.
///
/// The controller is created in this file's [State] and disposed in that same
/// [State], so it dies with the widgets that use it — the whole of what
/// `text_prompt.dart` exists to guarantee, and the reason this file is allowed
/// to own one at all.
class DateEntryScreen extends StatefulWidget {
  const DateEntryScreen({
    super.key,
    required this.initial,
    required this.reference,
    required this.mode,
    required this.title,
    required this.help,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.firstDate,
    required this.lastDate,
  });

  /// The day being changed.
  final Day initial;

  /// The day a yearless date takes its year from — today, or the day in view.
  ///
  /// Not the clock. A field seeded from the wall clock is a field no test can
  /// place in time, and the year filled into `Jan 4` should be the year the
  /// reader is looking at rather than whatever year the device thinks it is.
  final Day reference;

  /// Which calendar the reader is seeing, and so which the field is written in.
  final CalendarMode mode;

  final String title;

  /// The formats the field accepts, shown under it. A parser that accepts three
  /// ways to write a date and says nothing about them is a parser the reader has
  /// to guess at.
  final String help;

  final String confirmLabel;
  final String cancelLabel;

  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<DateEntryScreen> createState() => _DateEntryScreenState();
}

class _DateEntryScreenState extends State<DateEntryScreen> {
  late final TextEditingController _field;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Owned here, in a `State`, and disposed in that same `State` — the one
    // thing `text_prompt.dart` exists to guarantee, and the reason this file is
    // outside its net. It is outside that net because this is a `Scaffold` and
    // not an `AlertDialog`: the guard refuses the *shape* of a dialog that owns
    // its own text state, and this is no longer that shape.
    _field = TextEditingController(
      text: DateDisplay.format(widget.initial.midnight, widget.mode),
    );
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// What the field currently says, read the way the app reads one.
  DateParse get _parsed =>
      parseDateText(_field.text, reference: widget.reference);

  /// The day in the reader's own calendar, which is what "this is what you typed"
  /// has to be written in.
  String _echoed(Day day) => DateDisplay.format(day.midnight, widget.mode);

  /// The message a refusal should carry, or null when there is nothing to refuse.
  String? _problem() {
    final parsed = _parsed;
    final refused = switch (parsed) {
      DateParseInvalid() => AppLocalizations.of(context).dateEntryUnreadable,
      DateParseAmbiguous(:final days) =>
        // Both readings, by name. Not a nudge to try again: the field is
        // ambiguous because the *text* is, and the only way out is to say which
        // — so the two dates are offered and the reader picks.
        AppLocalizations.of(
          context,
        ).dateEntryAmbiguous([for (final d in days) _echoed(d)].join('  ·  ')),
      DateParseExact() => null,
    };
    if (refused != null) return refused;
    // **Out of range is refused too**, and this is the half that is easy to
    // forget: the grid will not offer a day before [firstDate], and a field that
    // accepted one anyway would let a plan hold a date its own calendar cannot
    // reach. Typing is not a way around the bounds — it is a different way of
    // respecting them.
    final day = parsed.dayOrNull!;
    final at = day.midnight;
    if (at.isBefore(widget.firstDate) || at.isAfter(widget.lastDate)) {
      return AppLocalizations.of(context).dateEntryOutOfRange;
    }
    return null;
  }

  /// Accept the day, or say why not.
  ///
  /// **[_problem] is the only thing that decides**, and it is asked *first* and
  /// unconditionally. It used to be consulted only when the text had failed to
  /// parse, with the out-of-range check living inside it — so the range was
  /// checked in a place nothing called for a date that had parsed, and a typed
  /// `1 Jan 1850` sailed straight through the bounds the grid would not cross.
  /// One question, asked once, is the whole fix.
  void _submit() {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.pop(context, _parsed.dayOrNull!);
  }

  Future<void> _pick() async {
    final parsed = _parsed;
    // Opens on the day in the field if it names one, so the grid and the text
    // are never disagreeing about which day is being changed.
    final start = parsed.dayOrNull ?? widget.initial;
    final picked = await showDatePicker(
      context: context,
      initialDate: start.midnight,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked == null || !mounted) return;
    if (DateDisplay.format(picked, widget.mode) == _field.text) return;
    setState(() {
      _field.text = DateDisplay.format(picked, widget.mode);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parsed = _parsed;
    final echoed = parsed.dayOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _field,
              autofocus: true,
              // Both scripts, so a Hebrew date is not reflowed by an LTR
              // keyboard's assumptions and an ISO date is not reversed.
              textDirection: _isHebrew(_field.text)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l10n.dateEntryField,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.event),
                  tooltip: l10n.dateEntryPick,
                  onPressed: _pick,
                ),
              ),
              // Re-echoing needs a rebuild on every keystroke, which is the one
              // thing a prompt with a `validate` callback cannot do: it is only
              // asked at submit time.
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(widget.help, style: Theme.of(context).textTheme.bodySmall),
            if (echoed != null) ...[
              const SizedBox(height: 8),
              // What it understood, not what was typed. The difference matters
              // most for a date with no year in it, where the year came from
              // the reference and the reader has to be told which.
              Text(
                l10n.dateEntryMeans(_echoed(echoed)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      // A list of children and a pinned row of buttons, so the buttons are
      // always reachable and the prose scrolls under them. A dialog would have
      // had to choose which of the two to clip.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.cancelLabel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether [text] is written in Hebrew script, so the field can be laid out
/// for it.
///
/// Which is not the same question as [parseDateText]'s — a transliterated date
/// has no Hebrew letters — so this is only about the *script*, which is what
/// decides the direction. Being wrong here is cosmetic; being wrong in the
/// parser is a wrong date.
bool _isHebrew(String text) => RegExp(r'[֐-׿]').hasMatch(text);

/// Ask for a date. Returns null if dismissed.
///
/// The one place a date is asked for, so #27 and #28 do not each invent their
/// own — and so the formats the parser accepts are stated in one place, in the
/// user's language, rather than discovered by trying them.
Future<Day?> promptForDate(
  BuildContext context, {
  required Day initial,
  required Day reference,
  required CalendarMode mode,
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? help,
  DateTime? firstDate,
  DateTime? lastDate,
}) =>
    // A route on the **root** navigator, so the entry is always the whole
    // screen and never a dialog stacked inside a dialog — which is the case
    // that made it a dialog in the first place.
    Navigator.of(context, rootNavigator: true).push<Day>(
      MaterialPageRoute(
        builder: (routeContext) {
          final l10n = AppLocalizations.of(routeContext);
          return DateEntryScreen(
            initial: initial,
            reference: reference,
            mode: mode,
            title: title,
            help: help ?? l10n.dateEntryHelp,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            firstDate: firstDate ?? DateTime(2000),
            lastDate: lastDate ?? DateTime(2100),
          );
        },
      ),
    );
