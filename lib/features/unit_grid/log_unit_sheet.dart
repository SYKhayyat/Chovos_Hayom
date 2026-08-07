import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/session_timer.dart';
import '../../application/settings.dart';
import '../../application/stats.dart';
import '../../core/calendar.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/layer.dart';
import '../../domain/usecases/unit_mefarshim.dart';
import '../../l10n/generated/app_localizations.dart';
import '../common/guarded.dart';
import '../common/naming.dart';
import 'meforish_checklist.dart';

/// Result of the logging sheet. [occurredAt] is null when the user did not set a
/// date/time manually, so the caller auto-fills "now".
class LogUnitResult {
  const LogUnitResult({
    this.occurredAt,
    this.durationMin,
    this.note,
    this.layers = const [mainLayerId],
  });

  final DateTime? occurredAt;
  final int? durationMin;

  /// The haara — one free-text field, whatever the user wanted to record.
  /// Surfaced in the Notes Journal.
  final String? note;

  /// Which layers this log marks. Defaults to the primary text; on a layered
  /// unit the sheet offers the checkable set so one action records "I learned
  /// Rashi on this daf for 40 minutes, and here's my chiddush".
  final List<String> layers;
}

/// A modal sheet for logging a unit — or editing an already-logged one, or
/// recording a chazara on it — with an optional manual date **and time**, the
/// shared session timer, a duration, a free-text haara, and (on a layered unit)
/// which mefarshim it covers. Returns null if cancelled.
///
/// **This is the only form in the app that records learning.** There used to be
/// two. `add_chazara_sheet.dart` was 223 lines of the same six fields in the
/// same order with the same nav-bar inset workaround and the same manual
/// date/time switch, differing in an `EventAction`, a seed set and one string —
/// and it had drifted in three ways, every one of them in the copy's favour of
/// being worse: it read the wall clock directly instead of `clockProvider`, so
/// no test could place it in time; it had no session timer, which is precisely
/// what you would want on a chazara; and it asked for the duration through a
/// second ARB key saying the same thing as the first. Folding it in is what
/// makes those three impossible rather than fixed.
///
/// Pass [initialOccurredAt]/[initialDurationMin]/[initialNote] to pre-fill the
/// fields (edit mode); [saveLabel] labels the confirm button. Pass
/// [layerOptions] to offer a meforish checklist, with [initialLayers] selected
/// and [checklistLabel] over it. [nodeId]/[unitIndex] tie the session timer to
/// what is being learned.
Future<LogUnitResult?> showLogUnitSheet(
  BuildContext context, {
  required String title,

  /// A second line under [title] — which unit this is, when the title is naming
  /// the *action* ("Add chazara") rather than the unit.
  String? subtitle,
  DateTime? initialOccurredAt,
  int? initialDurationMin,
  String? initialNote,

  /// Null uses "Mark learned". A default *value* can't be a localized string —
  /// it has to be resolved from a context — so the default is expressed as
  /// absence and filled in where the sheet is built.
  String? saveLabel,

  /// The mefarshim to offer, already resolved against the unit — see
  /// [UnitMefarshim]. Empty means this unit is a one-tap toggle and the sheet
  /// shows no checklist at all.
  List<UnitMeforish> layerOptions = const [],

  /// Every meforish the app knows about, for turning the ids above into names.
  List<Layer> layers = const [],
  Set<String> initialLayers = const {mainLayerId},

  /// Null uses "What you learned:". Absence for the same reason as [saveLabel].
  String? checklistLabel,
  String? nodeId,
  int? unitIndex,
}) {
  return showModalBottomSheet<LogUnitResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The nav-bar inset, the same way the other sheets get it. Without it the
    // confirm button was laid out *underneath* the system navigation bar, where
    // a tap belongs to the system and never reaches the app: measured on a phone
    // (1220x2712, 135px nav bar), two thirds of "Mark learned" was dead, and
    // aiming at it opened Recents. Of the nine sheets in the app, the two that
    // reached for `viewInsets.bottom` — this one and "Log chazara" — were exactly
    // the two that broke, because the keyboard inset was written in place of the
    // nav-bar inset rather than in addition to it.
    //
    // The two compose rather than double up: `SafeArea` reads MediaQuery's
    // `padding`, whose bottom Flutter already zeroes while the keyboard covers
    // it, and the keyboard is added inside. Android 15+ enforces edge-to-edge,
    // so this is every current phone, not an exotic configuration.
    builder: (_) => SafeArea(
      child: _LogUnitSheet(
        title: title,
        subtitle: subtitle,
        initialOccurredAt: initialOccurredAt,
        initialDurationMin: initialDurationMin,
        initialNote: initialNote,
        saveLabel: saveLabel,
        layerOptions: layerOptions,
        layers: layers,
        initialLayers: initialLayers,
        checklistLabel: checklistLabel,
        nodeId: nodeId,
        unitIndex: unitIndex,
      ),
    ),
  );
}

class _LogUnitSheet extends ConsumerStatefulWidget {
  const _LogUnitSheet({
    required this.title,
    this.subtitle,
    this.saveLabel,
    required this.layerOptions,
    required this.layers,
    required this.initialLayers,
    this.checklistLabel,
    this.initialOccurredAt,
    this.initialDurationMin,
    this.initialNote,
    this.nodeId,
    this.unitIndex,
  });

  final String title;
  final String? subtitle;
  final String? saveLabel;
  final String? checklistLabel;
  final DateTime? initialOccurredAt;
  final int? initialDurationMin;
  final String? initialNote;
  final List<UnitMeforish> layerOptions;
  final List<Layer> layers;
  final Set<String> initialLayers;
  final String? nodeId;
  final int? unitIndex;

  @override
  ConsumerState<_LogUnitSheet> createState() => _LogUnitSheetState();
}

class _LogUnitSheetState extends ConsumerState<_LogUnitSheet> {
  late bool _manualDate;
  late DateTime _date; // date + time of "finished learning"
  late final TextEditingController _durationCtrl;
  late final TextEditingController _noteCtrl;
  late final Set<String> _selectedLayers;

  /// Redraws the elapsed readout once a second **while the timer is running**.
  /// Display only — the elapsed time itself lives in [sessionTimerProvider] and
  /// is derived from wall-clock instants, so nothing is lost if this widget
  /// goes away.
  ///
  /// Started from `build` rather than `initState`, and stopped when the session
  /// is not running. It used to start unconditionally and run for as long as
  /// the sheet was open, which for the ordinary case — open the sheet, tick a
  /// meforish, confirm, with no timer ever started — is a wakeup a second to
  /// redraw a readout that reads `00:00`. A paused session needs no tick
  /// either: `elapsedAt` returns the banked total until it is resumed.
  Timer? _ticker;

  /// See [_ticker]. Idempotent, so calling it on every build is free.
  void _syncTicker(bool running) {
    if (running == (_ticker != null)) return;
    if (!running) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    // Editing an existing event (has an occurredAt) starts in manual mode with
    // its stored date/time; a fresh log defaults to "now" and manual off.
    _manualDate = widget.initialOccurredAt != null;
    _date = widget.initialOccurredAt ?? ref.read(clockProvider)();
    _durationCtrl = TextEditingController(
        text: widget.initialDurationMin?.toString() ?? '');
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _selectedLayers = {...widget.initialLayers};
    if (_selectedLayers.isEmpty) _selectedLayers.add(mainLayerId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _durationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(clockProvider)();

  Future<void> _toggleTimer() async {
    final timer = ref.read(sessionTimerProvider.notifier);
    final running = ref.read(sessionTimerProvider).isRunning;
    final l10n = AppLocalizations.of(context);
    final ok = await guarded(
      context,
      ref,
      () => timer.toggle(_now,
          label: widget.title,
          nodeId: widget.nodeId,
          unitIndex: widget.unitIndex),
      what: running ? l10n.whatPausingTimer : l10n.whatStartingTimer,
    );
    if (!ok) return;
    // Pausing offers the time it measured as the duration, without overwriting
    // a number the user typed themselves.
    final session = ref.read(sessionTimerProvider);
    if (!session.isRunning) {
      final minutes = session.minutesAt(_now);
      if (minutes > 0) _durationCtrl.text = '$minutes';
    }
  }

  static String _clock(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date =
          DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _date.hour, minute: _date.minute),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
          _date.year, _date.month, _date.day, picked.hour, picked.minute));
    }
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    // The session ends when it is recorded; leaving it running would let it
    // bleed into whatever is logged next. A failure here is worth saying — the
    // banner would otherwise keep counting a session the user thinks is over —
    // but it must not block the log itself, which is the point of the sheet.
    if (ref.read(sessionTimerProvider).isActive) {
      await guarded(context, ref,
          () => ref.read(sessionTimerProvider.notifier).reset(),
          what: AppLocalizations.of(context).whatEndingTimer);
    }
    if (!mounted) return;
    Navigator.of(context).pop(LogUnitResult(
      occurredAt: _manualDate ? _date : null,
      durationMin: duration,
      note: note.isEmpty ? null : note,
      layers: _selectedLayers.toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // The keyboard only. The system navigation bar is the *other* inset, and it
    // is handled by the `SafeArea` this sheet is built inside — see
    // [showLogUnitSheet].
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final session = ref.watch(sessionTimerProvider);
    _syncTicker(session.isRunning);
    final elapsed = session.elapsedAt(_now);
    final l10n = AppLocalizations.of(context);
    // The one date this sheet displays, read the same way every other date in
    // the app is. This used to be a private `_dateTimeLabel` that formatted
    // `yyyy-MM-dd · HH:mm` by hand — so the *only* screen where you choose a
    // date was the only screen that ignored the Hebrew calendar setting, and
    // showed you a Gregorian date to confirm a mark every other surface would
    // then render as a Hebrew one.
    final calendar = ref.watch(settingsProvider.select((s) => s.calendar));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            if (widget.subtitle != null)
              Text(widget.subtitle!,
                  style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (widget.layerOptions.isNotEmpty) ...[
              Text(widget.checklistLabel ?? l10n.logSheetWhatYouLearned,
                  style: Theme.of(context).textTheme.labelLarge),
              MeforishChecklist(
                mefarshim: widget.layerOptions,
                layers: widget.layers,
                isChecked: _selectedLayers.contains,
                onChanged: (id, checked) => setState(() {
                  if (checked) {
                    _selectedLayers.add(id);
                  } else {
                    _selectedLayers.remove(id);
                  }
                }),
              ),
              const Divider(),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.logSheetManualDateTime),
              subtitle: Text(_manualDate
                  ? DateDisplay.formatWithTime(_date, calendar)
                  : l10n.logSheetDefaultsToNow),
              value: _manualDate,
              onChanged: (v) => setState(() => _manualDate = v),
            ),
            if (_manualDate)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(l10n.logSheetPickDate),
                    onPressed: _pickDate,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(l10n.logSheetPickTime),
                    onPressed: _pickTime,
                  ),
                ],
              ),
            Row(
              children: [
                Text(l10n.logSheetTimer(_clock(elapsed)),
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (session.isActive && !session.isRunning)
                  TextButton(
                    onPressed: () => guarded(context, ref,
                        () => ref.read(sessionTimerProvider.notifier).reset(),
                        what: l10n.whatResettingTimer),
                    child: Text(l10n.actionReset),
                  ),
                FilledButton.tonalIcon(
                  icon: Icon(session.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(session.isRunning
                      ? l10n.logSheetStop
                      : l10n.logSheetStart),
                  onPressed: _toggleTimer,
                ),
              ],
            ),
            if (session.isRunning)
              Text(
                l10n.logSheetKeepsRunning,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.logSheetDuration,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.logSheetHaara,
                hintText: l10n.logSheetHaaraHint,
                helperText: l10n.logSheetHaaraHelper,
              ),
              maxLines: 5,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedLayers.isEmpty ? null : _save,
                  child: Text(widget.saveLabel ?? l10n.logSheetMarkLearned),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Log one unit with a date, a duration, a haara — **and**, on a layered unit,
/// which mefarshim it covers.
///
/// Those two features used to be mutually exclusive: the checklist marked a
/// meforish with no date, duration or haara, and this sheet always wrote
/// `layers: [main]`, so on a layered unit it only marked the text. There was no
/// way to record "I learned Rashi on this daf for 40 minutes and here's my
/// chiddush". One sheet now does both, and the layer checklist is seeded with
/// whatever the unit still needs.
Future<void> logWithDetails(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) async {
  final roles = ref.read(layerRolesProvider);
  final fold = ref.read(foldProvider).asData?.value;
  final allLayers = ref.read(allLayersProvider);
  final logger = ref.read(loggingServiceProvider);
  final guard = WriteGuard.of(context, ref);
  final l10n = AppLocalizations.of(context);
  final heading = nodeAndUnit(l10n, node, unit);

  final layered = UnitMefarshim.isLayered(roles, node.id, unit);
  final mefarshim = UnitMefarshim.of(
    roles: roles,
    fold: fold,
    layerOrder: [for (final l in allLayers) l.id],
    nodeId: node.id,
    unitIndex: unit,
  );

  final result = await showLogUnitSheet(
    context,
    title: heading,
    nodeId: node.id,
    unitIndex: unit,
    // What this unit offers to be ticked — not what was learned on it. A
    // meforish turned off or deleted since is history, and history is what a
    // chazara records; this is a *new* learning.
    layerOptions: layered ? mefarshim.checkable : const [],
    layers: allLayers,
    // Default to what is still outstanding; if nothing is, to everything
    // required.
    initialLayers: layered
        ? (mefarshim.outstanding.isNotEmpty
            ? mefarshim.outstanding
            : mefarshim.required)
        : UnitMefarshim.justTheText,
  );
  if (result == null) return;
  await guard.run(
    () => logger.markDone(node.id, unit,
        occurredAt: result.occurredAt,
        durationMin: result.durationMin,
        note: result.note,
        layers: result.layers),
    what: l10n.whatLogging(heading),
  );
}

/// Log one chazara (review) pass over [unit]: which mefarshim were reviewed,
/// when, how long, and any notes. Each pass is independent of the main learning
/// and of other passes, so you can review just Tosafos one time and the whole
/// daf the next.
///
/// The same form as [logWithDetails], down to the session timer — which this
/// action never had, and which a chazara wants at least as much as a first
/// learning does. What differs is three arguments and the verb at the end.
Future<void> logChazaraWithDetails(
  BuildContext context,
  WidgetRef ref, {
  required CatalogNode node,
  required int unit,
}) async {
  final roles = ref.read(layerRolesProvider);
  final fold = ref.read(foldProvider).asData?.value;
  final allLayers = ref.read(allLayersProvider);
  final logger = ref.read(loggingServiceProvider);
  final guard = WriteGuard.of(context, ref);
  final l10n = AppLocalizations.of(context);
  final heading = nodeAndUnit(l10n, node, unit);

  final mefarshim = UnitMefarshim.of(
    roles: roles,
    fold: fold,
    layerOrder: [for (final l in allLayers) l.id],
    nodeId: node.id,
    unitIndex: unit,
  );
  // What can be reviewed: everything this unit needs, plus anything already
  // learned on it that it no longer needs.
  //
  // That second half used to be filtered through the mefarshim list, which
  // *drops* a meforish deleted since the unit was marked — while the seed below
  // still selected it, because the seed came from the log and the options did
  // not. The sheet then submitted a layer with no checkbox in it. One list
  // answers both now, so a row and its tick cannot come apart.
  final options = mefarshim.reviewable;
  final completed = mefarshim.done;

  final result = await showLogUnitSheet(
    context,
    title: l10n.addChazaraTitle,
    subtitle: heading,
    nodeId: node.id,
    unitIndex: unit,
    saveLabel: l10n.addChazaraSubmit,
    checklistLabel: l10n.addChazaraReviewed,
    layerOptions: options,
    layers: allLayers,
    // A fresh pass defaults to reviewing everything currently learned.
    initialLayers: completed.isEmpty
        ? {for (final m in options) m.layerId}
        : completed,
  );
  if (result == null) return;
  await guard.run(
    () => logger.markReview(
      node.id,
      unit,
      occurredAt: result.occurredAt,
      durationMin: result.durationMin,
      note: result.note,
      layers: result.layers,
    ),
    what: l10n.whatLoggingChazara(heading),
  );
}
