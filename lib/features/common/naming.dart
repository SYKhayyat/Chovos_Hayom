import 'dart:ui' show Locale;

import '../../application/sorting.dart';
import '../../core/daf_yomi.dart';
import '../../domain/entities/catalog.dart';
import '../../domain/entities/catalog_node.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/layer.dart';
import '../../l10n/generated/app_localizations.dart';

/// Turning domain values into words the user reads.
///
/// This lives in `features/` on purpose. `domain/` is pure Dart with no
/// framework and no locale, so it can say *which* unit a mark belongs to but not
/// what to call it — `CatalogNode.unitHeading` produced `'daf 5'` by
/// interpolating an enum's English name, which is a presentation decision made
/// three layers below the presentation. The domain keeps the part that is really
/// data ([CatalogNode.unitDisplay] — a unit's own name, or its number), and
/// everything that depends on what language the reader speaks is here.

/// [text] wrapped in a Unicode LTR isolate, so a numeric expression keeps its
/// own reading order inside a Hebrew sentence.
///
/// Digits are weak-LTR and `/`, `(`, `%` are neutral, so under a Hebrew
/// `Directionality` the bidi algorithm resolves the neutrals from the paragraph
/// and reverses the whole run: `0 / 929  (0.0%)` painted as `(0.0%)  929 / 0`,
/// on every row of the dashboard. Measured on a real screen, on two platforms —
/// the operands *swap*, which reports a different number rather than merely
/// looking odd.
///
/// An isolate (U+2066 … U+2069) rather than flipping the widget's
/// `textDirection`: the line must still *sit* on the right in Hebrew, and only
/// its contents read left to right. Forcing the paragraph LTR would move the
/// whole line to the left margin to fix the digits.
///
/// Applied in every locale, not only Hebrew. In an LTR paragraph an LTR isolate
/// changes nothing, and a rule with a locale condition in it is a rule that gets
/// tested in one locale.
///
/// Not needed for a bare `7/100` — a slash directly between two digits is a
/// Common Separator and joins the numeric run, which is why `meforishCoverage`
/// was safe while the space-padded templates were not. It is applied there
/// anyway: "safe because of where the spaces are" is not a property anyone
/// editing a string table should have to know.
String ltrNumerals(String text) => '$_ltrIsolate$text$_popIsolate';

/// **U+2066 LEFT-TO-RIGHT ISOLATE** and **U+2069 POP DIRECTIONAL ISOLATE**, as
/// escape sequences and under names: they render as nothing, so a bare one pasted
/// into an expression is a character nobody can see and nobody would notice
/// deleting. (The analyzer agrees — `text_direction_code_point_in_literal`
/// rejects the literal form outright.) `bidi_numerals_test.dart` is what notices
/// if they go missing anyway.
const _ltrIsolate = '\u2066';
const _popIsolate = '\u2069';

/// A node's name in the reader's language: its Hebrew name under a Hebrew
/// locale, its primary name otherwise.
///
/// `nameHebrew` has been carried on every node — through the catalog JSON, the
/// database, the backup format and the search index — since the first version,
/// and was never once *displayed*. Reading it here is what makes the Hebrew
/// toggle a real translation of the tree rather than a right-to-left English
/// one. The bundled catalog carries one for all 312 of its nodes; anything
/// without one — a sefer a user added under an English name — falls back to the
/// name it has, so a partly-named catalog degrades to exactly what it showed
/// before instead of to blanks.
String nodeName(AppLocalizations l10n, CatalogNode node) =>
    nameIsHebrew(l10n, node) ? node.nameHebrew! : node.name;

/// Whether [nodeName] is currently answering in Hebrew script — the reader is in
/// Hebrew *and* this node has a Hebrew name to give them.
///
/// Split out of [nodeName] rather than re-derived, because a second screen now
/// needs the question rather than the answer: the Daf Yomi row prints the daf's
/// Hebrew name under its heading, which is worth showing beside an English
/// heading and is the same words twice beside a Hebrew one.
///
/// The comment above used to say the bundled catalog had no Hebrew names. It
/// has carried one for all 312 nodes for some time, which is exactly why the
/// duplicate line became visible.
bool nameIsHebrew(AppLocalizations l10n, CatalogNode node) {
  final hebrew = node.nameHebrew;
  return l10n.localeName.startsWith('he') &&
      hebrew != null &&
      hebrew.isNotEmpty;
}

/// A Daf Yomi day named in Hebrew — `"שבת · דף 12"` — whatever locale the reader
/// is in.
///
/// This is the one line in the app that is Hebrew by *definition* rather than by
/// translation: it is the daf's own name, shown beside a heading in the reader's
/// language. It used to be an ARB key, `cycleDafHebrew`, whose English value was
/// `"{sefer} · דף {unit}"` and whose Hebrew value was the identical string. Three
/// things were wrong with that. The untranslated-locale gate cannot see a key
/// that is present in both files, so nothing noticed the "translation" was a
/// copy. A translator editing one file and not the other would have made the
/// same line render differently in the two locales, silently. And "דף" was
/// spelled a second time, next to the `unitLabelDaf` in `app_he.arb` that
/// already spells it — with `nodeAndUnit`'s separator copied along with it.
///
/// Composed out of the Hebrew table instead, every word in it has exactly one
/// definition, and it is the one the Hebrew UI is already built from.
String hebrewDafLine(String seferHebrew, int unit) {
  final he = _hebrew ??= lookupAppLocalizations(const Locale('he'));
  return he.nodeAndUnit(seferHebrew, he.unitHeading(he.unitLabelDaf, unit));
}

/// Cached: [lookupAppLocalizations] allocates, and this is read per row of a
/// list. It holds no context and no state, so one instance is safe forever.
AppLocalizations? _hebrew;

/// Where [node] sits, named in the reader's language: `"Shas · Moed"`.
///
/// Empty for a root and for anything directly under one, because "Kol HaTorah
/// Kula" qualifies nothing — every node is under it.
///
/// This is the qualifier that used to be *typed into the data*: 120 of the 312
/// catalog names carried a hard-coded "(Shas)", "(Yerushalmi)", "(Rambam)". That
/// made every row inside Shas read "Moed (Shas) → Shabbos (Shas)", where the
/// suffix is pure noise, while Mishnayos masechtos were left bare — so a search
/// for "shabbos" returned four rows of which the *first*, plain "Shabbos", was
/// the one you could not identify. A qualifier that is derived is right for every
/// node, including the ones nobody thought to annotate and the ones a user adds.
String nodePath(AppLocalizations l10n, Catalog catalog, CatalogNode node) {
  final parts = <String>[];
  var current =
      node.parentId == null ? null : catalog.byId(node.parentId!);
  // Bounded: the per-profile override layer can (via a hand-edited import)
  // contain a parent cycle, and this runs while building a list.
  for (var depth = 0; current != null && depth < 16; depth++) {
    if (current.parentId == null) break; // the root names nothing useful
    parts.add(nodeName(l10n, current));
    current = catalog.byId(current.parentId!);
  }
  return parts.reversed.join(' · ');
}

/// [node]'s name with [nodePath] appended when there is one — for the flat lists
/// (search results, the calculator's dropdown, the two cycle pickers) that have
/// no tree around them to supply the context.
String qualifiedNodeName(
    AppLocalizations l10n, Catalog catalog, CatalogNode node) {
  final path = nodePath(l10n, catalog, node);
  final name = nodeName(l10n, node);
  return path.isEmpty ? name : l10n.nodeWithPath(name, path);
}

/// A meforish's name in the reader's language.
///
/// Unlike the catalog, the built-in mefarshim have carried their Hebrew names
/// (רש״י, תוספות) since they were defined — so under a Hebrew locale this is a
/// real translation today, with no data still to add.
String layerName(AppLocalizations l10n, Layer layer) {
  final hebrew = layer.nameHebrew;
  if (l10n.localeName.startsWith('he') && hebrew != null && hebrew.isNotEmpty) {
    return hebrew;
  }
  return layer.name;
}

/// The meforish with this id, or a stand-in named *Deleted meforish*.
///
/// Everything that stores a meforish stores its **id** — a logged event's
/// `layers`, a checkable set, a per-layer stat row — so every screen that
/// renders one has to resolve it, and the resolution can fail: deleting a
/// meforish does not go back and rewrite the events that mention it, by design,
/// because the log is append-only and those units really were learned with it.
///
/// This existed as a private `nameOf` in three files, and **they disagreed**.
/// Two named the missing meforish; `unit_details_sheet` fell back to the id
/// itself, so a chazara line for a user-added meforish read as a raw UUID. The
/// two that were right each carried a comment explaining why — which is how you
/// get the same fix applied twice out of three.
Layer layerById(AppLocalizations l10n, List<Layer> layers, String id) =>
    layers.firstWhere((l) => l.id == id,
        orElse: () => Layer(id: id, name: l10n.deletedMeforish));

/// [layerById] in the reader's language — the form almost every call site wants.
String layerNameById(AppLocalizations l10n, List<Layer> layers, String id) =>
    layerName(l10n, layerById(l10n, layers, id));

/// What one unit of [label] is called, singular ("daf", "perek").
String unitLabelName(AppLocalizations l10n, UnitLabel? label) =>
    switch (label) {
      UnitLabel.perek => l10n.unitLabelPerek,
      UnitLabel.daf => l10n.unitLabelDaf,
      UnitLabel.amud => l10n.unitLabelAmud,
      UnitLabel.siman => l10n.unitLabelSiman,
      UnitLabel.halacha => l10n.unitLabelHalacha,
      UnitLabel.page => l10n.unitLabelPage,
      UnitLabel.custom => l10n.unitLabelCustom,
      null => l10n.unitLabelUnknown,
    };

/// The plural of [unitLabelName] ("dapim", "perakim").
///
/// A separate table rather than an `s` on the singular: the English plurals here
/// are Hebrew words with Hebrew plurals (daf → dapim), so the rule that would
/// work for "page" produces "dafs" for the one that matters most.
String unitLabelPlural(AppLocalizations l10n, UnitLabel? label) =>
    switch (label) {
      UnitLabel.perek => l10n.unitLabelPluralPerek,
      UnitLabel.daf => l10n.unitLabelPluralDaf,
      UnitLabel.amud => l10n.unitLabelPluralAmud,
      UnitLabel.siman => l10n.unitLabelPluralSiman,
      UnitLabel.halacha => l10n.unitLabelPluralHalacha,
      UnitLabel.page => l10n.unitLabelPluralPage,
      UnitLabel.custom => l10n.unitLabelPluralCustom,
      null => l10n.unitLabelPluralUnknown,
    };

/// How many units there are, with the unit named: "64 dapim".
String unitCount(AppLocalizations l10n, int count, UnitLabel? label) =>
    l10n.unitCountWithLabel(count, unitLabelPlural(l10n, label));

/// A unit's heading: its own name when it has one (Parshas Noach), otherwise its
/// type and number ("daf 5"). The localized counterpart of the domain's
/// [CatalogNode.unitDisplay].
String unitHeading(AppLocalizations l10n, CatalogNode node, int index) {
  final display = node.unitDisplay(index);
  // `unitDisplay` returns the bare number when the unit has no name of its own;
  // that is the case that needs a type in front of it.
  if (display != '$index') return display;
  return l10n.unitHeading(unitLabelName(l10n, node.unitLabel), index);
}

/// A unit qualified by its sefer — "Shabbos · daf 12". The heading almost every
/// sheet, snackbar and journal line is built from.
String nodeAndUnit(AppLocalizations l10n, CatalogNode node, int index) =>
    l10n.nodeAndUnit(nodeName(l10n, node), unitHeading(l10n, node, index));

/// The label for a tree-sort metric.
String sortMetricLabel(AppLocalizations l10n, SortMetric metric) =>
    switch (metric) {
      SortMetric.catalog => l10n.sortMetricCatalog,
      SortMetric.name => l10n.sortMetricName,
      SortMetric.percent => l10n.sortMetricPercent,
      SortMetric.learned => l10n.sortMetricLearned,
      SortMetric.remaining => l10n.sortMetricRemaining,
      SortMetric.lastLearned => l10n.sortMetricLastLearned,
    };

/// The name of a built-in, calendar-computed cycle.
///
/// Keyed on the cycle's id rather than carried on [CalendarCycle] itself, which
/// is a `const` list in `core/` and cannot hold a localized string. An id with
/// no entry falls back to the English name in the definition, so adding a cycle
/// there without a translation still shows something real.
String calendarCycleName(AppLocalizations l10n, CalendarCycle cycle) =>
    switch (cycle.id) {
      CalendarCycle.bavliId => l10n.cycleBavliName,
      CalendarCycle.yerushalmiId => l10n.cycleYerushalmiName,
      _ => cycle.name,
    };

String calendarCycleDescription(AppLocalizations l10n, CalendarCycle cycle) =>
    switch (cycle.id) {
      CalendarCycle.bavliId => l10n.cycleBavliDescription,
      CalendarCycle.yerushalmiId => l10n.cycleYerushalmiDescription,
      _ => cycle.description,
    };

/// The same lookup for a cycle already resolved to an id + fallback text, which
/// is the shape the cycles screen has after built-ins and user cycles are merged.
String cycleNameById(AppLocalizations l10n, String id, String fallback) =>
    switch (id) {
      CalendarCycle.bavliId => l10n.cycleBavliName,
      CalendarCycle.yerushalmiId => l10n.cycleYerushalmiName,
      _ => fallback,
    };

String cycleDescriptionById(AppLocalizations l10n, String id, String fallback) =>
    switch (id) {
      CalendarCycle.bavliId => l10n.cycleBavliDescription,
      CalendarCycle.yerushalmiId => l10n.cycleYerushalmiDescription,
      _ => fallback,
    };

/// Minutes as a readable duration: "45 min", "2h", "1h 20m".
String formatMinutes(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.durationMinutes(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? l10n.durationHours(hours)
      : l10n.durationHoursMinutes(hours, rest);
}
