# Chovos Hayom — a lamdan reading

**2026-08-05** · whole repo, 236 tracked files, swept region by region · `master` @ `bf8e1d2`

> **Status, 2026-08-06 (later still, again).** Four rows of **finding 5** — the pace scalar, the
> log→numbers pass, distinct-units-learned-on-a-day and the per-meforish counts — are now resolved.
> See the note below the finding. The rest of finding 5's inventory stands as written.
>
> ---
>
> **Status, 2026-08-06 (later still).** **Finding 7** (*"The test suite tests the layer that never
> breaks"*) is now resolved — see the note below it. Everything else in this document stands as
> written.
>
> ---
>
> **Status, 2026-08-06 (later).** **Finding 3** (*"Required and Offered are one tri-state wearing
> two booleans"*) is now resolved — see the note below it. Everything else in this document stands
> as written.
>
> ---
>
> **Status, 2026-08-06.** Two items have been worked. **Finding 2** (*"Nothing in this app is
> comparable, and nothing is disposable"*) and **finding 1** (`clockProvider`) are now resolved —
> see the second status note below. Everything else in this document stands as written.
>
> ---
>
> **Status, 2026-08-05.** One item has been worked: *"which calendar day is this"* — the first row
> of finding 5, and item 2 of *Where I'd start*. It is marked **✅ Resolved** in the three places
> below where it appears. Everything else in this document stands as written and is untouched.
>
> The finding was worse than reported, in two ways the sweep did not reach. The two conventions did
> not merely differ — the local-midnight one was **wrong**, and provably so on the machine this was
> read on: `DateTime(2026,3,9).difference(DateTime(2026,3,8)).inDays` is `0`, and
> `DateTime(2026,11,1).add(Duration(days:1))` is `2026-11-01 23:00`. That reached four sites the
> report listed as merely duplicated (`backup_reminder:93`, `goal_evaluator:27`,
> `calculator_screen:260`, `stats_screen:179`) plus the midnight tick in `stats.dart:63`, and it
> put `Predictor` — the one place in the app that *produces* dates — squarely in the wrong
> convention. `stats_screen:235` already carried a comment describing this exact defect, having hit
> it once in the heatmap and fixed it locally; that knowledge existed in one file and nowhere else,
> which is this document's whole thesis in miniature.
>
> Resolved by `lib/core/day.dart` (a `Day` value type — a whole-day count, so day arithmetic stays
> integer arithmetic), all nine sites migrated, and the four `_dayNumber` copies, `_dayKey`,
> `_localMidnight` and `_wholeDaysBetween` deleted. Tests: `test/core/day_test.dart` sweeps every
> consecutive pair of days in a year in the host's own timezone, with a negative control that
> asserts the replaced forms *do* disagree on a DST host. **And the rule is now enforced rather
> than stated** — `test/core/day_math_guard_test.dart` reads `lib/` and fails the build on any of
> the four shapes a fifth copy would be written in. That is a direct answer to *The claim*, for
> one row of it.

---

> ### Findings 1 and 2, resolved — and where finding 2 was overstated
>
> **Every count in finding 2 checked out.** Zero `operator ==` in hand-written `lib/` (the single
> hit was `Day`, added the day before); zero `autoDispose`; two unconditional 1 Hz tickers; and
> "13 unselected against 7 selected" is exactly right — there are 16 unselected watches of
> `settingsProvider`, of which three legitimately want the whole object. The mechanism holds too,
> and was checked against the installed framework rather than from memory: Riverpod 3.3.2's
> `updateShouldNotify` is `previous != next`, and v3 still defaults `isAutoDispose: false` for the
> non-codegen API — so the "providers are autoDispose by default in v3" change does not apply here.
>
> **Where the finding oversells itself is its headline trace.** "One `done` event, traced: …" is
> presented as the thing equality fixes, and mostly it is not. A mark genuinely changes the log, so
> it genuinely changes the fold, the forest, the index, `statsProvider` and `backupStatusProvider`
> — no `==` can or should stop any of that. What equality actually buys is **scope**, and that
> turns out to be worth more: the ~300 nodes that did *not* move no longer notify, an unrelated
> goal row no longer re-renders, and — the case the finding does not mention at all — the midnight
> tick and the app-resume invalidation now re-derive everything and then propagate *nothing* when
> the answers are unchanged, instead of repainting every date-dependent screen on every resume.
>
> **`LogFold` is deliberately left without `==`**, against the finding's recommendation. It is
> rebuilt only when the log emits, and an emission almost always means something really changed, so
> the comparison would walk five nested maps over the whole log and return false — the cost of the
> fold again, per mark, to catch a rare no-op write. The reasoning is recorded in `fold_log.dart`
> so it does not get "fixed" later.
>
> **Three families were auto-disposed, not two.** `catalogNodeProvider` is one as well, and it is
> the easiest of the three to accumulate: every node reached from a chazara row, a goal row, the
> grid or the node editor minted an element keyed by its id and kept it.
>
> **The tickers are gated on `isRunning`, not `isActive`.** A *paused* session's readout is the
> banked total and does not move until it is resumed, so `isActive` would have left one of the two
> dead states ticking.
>
> **Finding 1 came with it** — one character, same subsystem, and the equality work above only
> pays off if the tick it absorbs actually fires.
>
> Resolved by `lib/core/equality.dart` (element-wise `listEquals`/`mapEquals`/`setEquals`, pure
> Dart so `domain/` stays package-free); `==`/`hashCode` on `ProgressNode`, `StatsSummary`,
> `SettingsState`, `SortConfig`, `BackupStatus`, `GoalStatus`, `SeriesPoint` and
> `SessionTimerState`; `autoDispose` on all three families; the 13 `.select`s at the call sites
> plus two more on `.length` reads of list providers; the conditional `backupStatusProvider` watch
> lifted out of `forest.when(data:)` — row 2 of *The claim*, which finding 2 lists as an
> amplifier; and both tickers gated.
>
> **And, again, the rule is enforced rather than stated.** `test/application/notify_guard_test.dart`
> fails the build on a family without `autoDispose`, on an unselected `settingsProvider` watch
> outside the two files entitled to one, and — the rot mode that matters — on a field added to any
> of those eight value types and left out of its `==`, which is silent and surfaces as a screen
> that has quietly stopped updating. `provider_notify_test.dart` counts notifications through the
> graph; `rebuild_cost_test.dart` counts real widget rebuilds through `debugOnRebuildDirtyWidget`.
> Between them 13 assertions fail on the pre-fix code, and the deliberate "must still rebuild"
> controls pass on both.

---

## The claim

**This codebase enforces its rules in prose, and prose does not fail CI.**

Twenty-one percent of the hand-written Dart under `lib/` is comment — 2,762 lines against
10,666 of code — and the densest files run 40–57%. That is not a complaint about verbosity.
The comments are *arguments*, they are mostly correct, and several of them are the best
design writing in the repository. The problem is what happens next to them:

| The rule, as written | Where it is broken |
|---|---|
| `layer_requirements.dart:63-65` — *"Two copies of one transformation is how a preview and an outcome come to disagree, so there is one."* | `offered_layers.dart:28-43` is the second copy of that exact transformation, in the file that `import`s the type from the first. **✅ Resolved** — both files deleted; see finding 3. |
| `dashboard_screen.dart:198-200` — *"Watched unconditionally, so this widget's set of subscriptions is the same on every build."* | `dashboard_screen.dart:269` — `ref.watch(backupStatusProvider)` inside the `data:` branch. 68 lines below the rule, same `build` method. **✅ Resolved** — lifted to the unconditional block, as a `.select` on `.due`. |
| `progress_series.dart:20-23` — *"the same key `PaceEngine` and `ChazaraSchedule` use"* | …and then copy-pastes `_dayNumber` a fourth time rather than importing either. **✅ Resolved** — `lib/core/day.dart`, and a guard test that fails the build on a fifth copy. |
| `stats.dart:79-82` — *"watching the tick here means every dependent provider re-derives when the day rolls over"* | `return DateTime.now;` — a static tear-off, which Dart canonicalizes. Nothing re-derives. Ever. **✅ Resolved** — see finding 1. |
| `text_prompt.dart` exists because five dialogs each hand-rolled a controller and threw *used after being disposed* | `_LayerNameDialog` (`mefarshim_config_sheet.dart:400`) and `_RangeDialog` (`bulk_actions_sheet.dart:329`) hand-roll it again. |
| `README.md:358` — *"a message is one whole ARB entry, never a sentence glued together"* | `dateTimeLabel` exists, is translated into Hebrew, and has **zero call sites**; `log_unit_sheet.dart:194` and `add_chazara_sheet.dart:173` each glue the string by hand. |
| `README.md:373` — *"the lint is what keeps new ones from drifting back out of [the guard]"* | `unawaited_futures` fires on expression statements in **async** bodies. The dominant shape here is `onPressed: () => guarded(...)` — a sync arrow closure. Not flagged, any of them. |
| `learning_event.dart:62-68` — `copyWith` deleted because *"nothing called it"* | `backup_service.dart:353` hand-lists all eleven fields to rescope an event. That *is* `copyWith`, minus the compiler's help. |
| `sorting.dart:56-65` — ten lines condemning conditional watches | see row 2. **✅ Resolved** with it, and now guarded: `notify_guard_test.dart`. |
| `backup_service.dart:398-403` — the validator justified by two crashes it prevents | Neither crash exists: `catalog.dart:47` and `inherited_layer_set.dart:38` already refuse to revisit a node, and `catalog_node.dart:101` uses `Iterable.generate`, which is empty for a negative count. The guards that make the validator unnecessary say so in *their own* comments. |

Ten instances. That is not carelessness — every one of these was written by someone who
understood the principle well enough to state it clearly. It is a structural fact: **the only
enforcement mechanism in this project is the author's memory**, and the author has been
sprinting for twenty-nine days.

The whole Flutter app is twenty-nine days old. First commit `2026-07-02`, last `2026-07-31`,
66 commits, 33,096 lines added to `lib/`. Everything before July is the Java original sharing
the repo. That matters for how this review was conducted (see *Method*) and it is the
charitable frame for every finding below: this is not rotted code, it is code that has not yet
had a second pass. This is that pass.

---

## What I committed to before reading any implementation

> One person tracks which dapim they've learned, wants to not lose it, and wants a finish date.
> Ladder: *"a Torah learning tracker"* → *"the old app stored a count and drifted"* → *"I want
> to know where I am and I want history"* → minimum: one append-only table
> `(profile, node, unit, layer, ts)`, the catalog as an immutable JSON asset, **one** fold that
> walks the catalog once and counts events into it, a screen that renders the tree. Predictions
> are `remaining ÷ (events in last 30 days ÷ 30)` — a division, not an engine. ~4k lines of
> Dart plus UI, one repository interface at the SQLite boundary only.

Actual: **14,636 hand-written lines under `lib/`**, plus 9,806 test, 12,218 committed
generated, 2,801 markdown.

Where the sketch was **wrong**, and I'd write it differently now:

- **`restoreLog` vs `import` is a real distinction and I missed it.** The log is append-only, so
  un-marking appends an `undone` rather than deleting the `done`. A merge therefore *cannot*
  undo an un-mark — every id in the file is already present and the later `undone` still wins.
  My "restore is just loading the JSON back" was naive. `backup_service.dart:219-225` found
  this before I did and the six-line stale-id diff at `:242-247` is the whole feature.
- **`LogFold`'s five parallel maps are not over-built.** I predicted a done-set and five features
  each re-folding. All five fields have live, distinct consumers. Keep.
- **`predictor.dart` is not a simulation.** I braced for a day-by-day walk; it is a division
  plus a ≤2n cleanup, and ~95 of its 162 lines are the comment explaining the 80ms-per-keystroke
  version it replaced.

Where the sketch was **right**: nineteen files under `domain/usecases/`, the interfaces with one
production implementer, "everything derived" needing help, the override layer as a second source
of truth about the same tree.

---

## Method

Twelve regions, one fresh-context reader each, every tracked file in exactly one region.
**Excluded and named as such:** `lib/l10n/generated/**` (8,015 lines, generated),
`database.g.dart` (4,153, generated), `windows/flutter/generated_plugin*`, `pubspec.lock`,
PNG/ICO binaries.

**History was used to rank, and it barely could.** On a 29-day-old codebase churn measures
which file was written most recently; churn×age has no age; the "quiet fossil" query returns
55 files whose only crime is having been written last Thursday. The two signals that did survive:

- `README.md` is the **highest-churn file in the repository** — 32 commits, more than any source
  file. That is a finding about the README.
- `drift_progress_repository.dart` ↔ `domain/repositories/progress_repository.dart` co-change
  5 times in 11. An interface that changes whenever its implementation does is not insulating
  anything.

Every claim below is cited to a line. The ten in *The claim* and findings 1, 2, 3, 6 and 12 I
verified by hand rather than taking a reader's word for it.

---

## Findings, ranked by wrongness × cost of leaving it

### 1. `clockProvider` never notifies anything. `rewrite` — one character. **✅ Resolved**

> `return () => DateTime.now();`. `provider_notify_test.dart` pins it by watching the *real*
> provider through an invalidation — deliberately without the `overrideWithValue` that made all 19
> other suites blind to it.

```dart
/// …watching the tick here means every dependent provider re-derives when the
/// day rolls over, without any of them knowing that time is what changed.
final clockProvider = Provider<DateTime Function()>((ref) {
  ref.watch(_dayTickProvider);
  return DateTime.now;              // stats.dart:85
});
```

`DateTime.now` is a static method tear-off. Dart canonicalizes those, so `previous == next` on
every tick and Riverpod propagates nothing. The midnight timer fires into a wall; so does
`invalidateClock` on app resume.

**What breaks in practice:** `cyclesTodayProvider` (`cycles.dart:169`) depends on the mapper, the
config and the clock — and on nothing else. For a user who leaves the app open, today's Daf Yomi
is frozen at whichever day the provider first built, for the life of the process. The streak, the
nudge and the chazara badge are rescued *by accident*, because they also watch `foldProvider` and
re-derive whenever anything is marked.

**Why no test sees it:** all 19 test call sites override with `overrideWithValue(() => fixedDate)`
— a fresh closure, never equal. The suite is structurally incapable of observing the defect.

**Steelman:** if the clock were only ever read inside providers that also watch the log, this
would be harmless. Two of the seven read sites aren't.
**The change:** `return () => DateTime.now();`.
**The cost:** one line. Nineteen overrides keep passing.

---

### 2. Nothing in this app is comparable, and nothing is disposable. `rewrite`. **✅ Resolved**

> Every count here was verified and every one held. See the status note at the top for what the
> finding got right, the one place it oversells itself (the per-mark trace), and the one
> recommendation deliberately not taken (`LogFold`).

```
operator== / hashCode / Equatable / @freezed in hand-written lib/ :  0
autoDispose in lib/                                               :  0
```

Riverpod's default is `previous != next`. Every provider here returns a freshly-allocated
`LogFold`, `List<ProgressNode>`, `Map`, `StatsSummary` or `SettingsState`, so **every hand-off in
the graph notifies unconditionally**.

One `done` event, traced: Drift re-runs `SELECT *` and maps every row → `foldProvider` re-sorts
the entire log (`fold_log.dart:99-103`, O(n log n) per tap) and re-folds it → `progressForestProvider`
allocates all **312 catalog nodes fresh** → `progressIndexProvider` re-walks them → *every*
`progressNodeProvider(id)` and `goalStatusProvider(id)` element touched this session re-runs,
because no family disposes → plus stats, siyumim, mefarshim, chazara, last-activity, batch
history, bulk marker.

`ProgressNode` has no `operator ==` (verified — 33 lines, none), so the `ValueKey`'d tiles cannot
be skipped either. The only thing keeping this survivable is `ListView.builder` capping work at
visible rows — and the dashboard stays mounted under the unit grid, so the full chain runs on
every mark even while the user is looking at a different screen.

Amplifiers, all cheap:
- `dashboard_screen.dart:203` — unselected `watch(settingsProvider)` six lines below a careful
  `.select`. Repo-wide: **13 unselected against 7 selected.** Changing the backup interval
  rebuilds the calculator, cycles, goals, journal, siyum, stats and unit grid.
- `session_banner.dart:33` and `log_unit_sheet.dart:144` — `Timer.periodic(1s)` calling `setState`
  unconditionally, including when the widget returns `SizedBox.shrink()`. A wakeup per second,
  forever, on a battery-powered keypad phone, to redraw nothing.

**Steelman, and half of it lands.** The *algorithm* has been measured, and well:
`derive_cost_test.dart` asserts `fullScans == 0` against a 500,000-unit catalog, folds 100,000
events under a 3-second bound, and runs `ProgressSeries` over 20,000 events across 200 days
specifically to catch constant-factor regressions. That is better performance discipline than most
shipped apps have, and it means the fold is O(n) with a good constant. It is also genuinely true
that the memoization here cannot *disagree* with the log, which is the failure mode people usually
worry about. Riverpod's identity default is the framework's fault, not the author's.

**What the benchmark does not cover** is the seam this finding is actually about. It calls
`FoldLog.fold` directly, in isolation, once. The cost above is how many times that O(n) work runs
*per keypress*, and what happens downstream of it: the Drift re-query and full row-map, the sort,
312 freshly-allocated `ProgressNode`s that no `==` can compare, every never-disposed family
element, and five *more* passes over the log inside `statsProvider` while it is already holding
the fold.

**And it is structurally invisible to hands-on testing, on any hardware.** Verified on a Windows
box and a moto g stylus 2025 (both absorb it trivially) and walked key-by-key on the Sonim — which
would also absorb it, *on a young profile*. The whole thing scales with event count, and a phone
you tested last week has a log of roughly zero. A daf-yomi user at year seven has ~3,000 rows
re-materialized, re-sorted and re-folded per mark. That is when it goes from invisible to a few
hundred milliseconds on 2016-era hardware, and no amount of using the app for an afternoon can
surface it.
**The change:** `==`/`hashCode` on `ProgressNode`, `LogFold`, `SettingsState`, `StatsSummary`
(or `@freezed`); `autoDispose` on the two families; gate the two tickers on `isActive`; the
13 unselected watches become `.select`.
**The cost:** the equality half is small and mechanical. The real work is discovering which of
~40 rebuild paths were silently load-bearing — do it behind the existing
`dashboard_rebuild_test.dart`, incrementally, one provider at a time.

---

### 3. *Required* and *Offered* are one tri-state wearing two booleans. `rewrite`. **✅ Resolved**

> **Every claim in this finding checked out**, including the two that carry it: the twins really are
> the same `fromEntries` loop over the same engine, and their "different" defaults really are the
> identical const `<String>{mainLayerId}`. The six-layer table is right row for row, and the illegal
> fourth state really is repaired by hand at `mefarshim_config_sheet.dart:124`, `:131` and `:182`.
>
> **Where the finding undersells itself is the count.** "*`unit_layer_view.dart:29` defines
> `checkableFor` as `offered ∪ required`*" reads as one reconciliation in one place. It was written
> out by hand at **four**: `UnitLayerView.checkableFor`, plus `bulk_actions_sheet.dart:57`,
> `progress_tile.dart:246` and the config sheet's own seed at `:67` — three call sites that never
> went through the class written to reconcile them, and therefore the three that could have
> disagreed.
>
> **Two things the sweep did not reach.** `BulkMarker.offered` was a **dead field** — passed by the
> provider, stored, and never read once; the pure carrying cost of a second resolver. And the
> meforish-delete cascade could genuinely produce the divergence the union was papering over: it
> cleared a scope's row in one table (its last id was the meforish being deleted) while rewriting
> the other, leaving a node pinned in one table and inheriting in the other. So "the sets were never
> independent" was true of the *intent* and not of the data.
>
> **The finding's diagnosis and its prescription disagree, and the diagnosis wins.** *The change*
> proposes one table with a `role` column and one resolver taking `role` and `defaultSet` — which
> deletes the twin but still stores two membership sets, so the fourth state stays representable and
> the invariant stays hand-enforced at three write sites. The paragraph above it is the one that is
> right: *"that want is a three-valued enum — `off | optional | required`"*. That is what was built.
> One entry holds `Map<String, LayerRole>`; absent means off. A required layer is in the map, so it
> is checkable, so there is nothing to reconcile and nothing to repair.
>
> **One deliberate semantic change.** The two sets could be pinned at different depths of the tree;
> one role map cannot. Nothing real is lost — the config sheet was the only writer and always wrote
> both at the same node in one transaction — and it removes the divergence class above. Said out
> loud because it is a behaviour change, not a refactor.
>
> **Not done, and still true:** the *Related* note. `unitIndex: -1` is still the only value ever
> written, so the per-unit level of the three-level inheritance is still implemented, still carried
> by backups and the resolver, and still unreachable from the UI. It is cheaper now — one write path
> instead of two — but it is not fixed.
>
> Resolved by `lib/domain/entities/layer.dart` (`LayerRole`, `defaultLayerRoles`),
> `lib/domain/usecases/layer_roles.dart` (`LayerConfigEntry` + the one `LayerRoles` resolver) and
> `inherited_layer_roles.dart` (the same engine, resolving a role map); `LayerRequirements`,
> `OfferedLayers`, `UnitLayerView` and `InheritedLayerSet` deleted. One `layer_configs` table
> replaces two, at schema v12, which merges the legacy pair by the same union-with-required-winning
> the app used to apply at read time — and the v4/v7 steps that created those tables are **deleted**,
> because on any database old enough to run them they created an empty table for v12 to drop. Three
> repository methods replace six, one stream replaces two, one provider replaces three, one backup
> array replaces two (backup format v5, with v1–v4 files read back under the role of the array they
> came from — reading an old `requirements` as optional would silently un-complete the user's tree),
> and the config sheet's two chips become one `SegmentedButton`.
>
> **And the rule is enforced rather than stated.** `test/domain/layer_role_guard_test.dart` reads
> `lib/` and fails the build on a second resolver, a second stream or table of layer settings, or a
> hand-written `offered ∪ required` — verified to fail by feeding it a violation, not assumed. Its
> second half is the rot mode that matters and is silent: it iterates `LayerRole.values` through
> `fromName` and through the backup JSON round trip, so a third role added without teaching the
> codecs about it fails CI instead of reading back as *optional* and quietly un-gating completion.
> Six new migration tests cover the merge against real on-disk SQLite, including a scope pinned in
> only one legacy table, a v3 database that predates both, and a replay of the half-finished step.
> `migration_test.dart` had the schema number typed out at four sites and now reads `kSchemaVersion`.
> 495 tests pass; `analyze --fatal-infos` is clean.

`offered_layers.dart` is `layer_requirements.dart` with `Required` search-replaced to `Offered`:
the same `fromEntries` loop, the same three delegating getters, and two "different" defaults that
are both `<String>{mainLayerId}` — the identical const.

The cost is not those 110 lines. It is that the split is replicated through **six layers**:

| Layer | The duplication |
|---|---|
| schema | `RequiredLayerConfigs` and `OfferedLayerConfigs`, byte-identical in shape (`database.dart:80-93`, `:100-113`). Schema v7 exists solely to add the second. |
| repository | six methods differing only in table name (`drift_progress_repository.dart:259-294`, `:298-332`) |
| domain | the two twins above, plus `UnitLayerView` — a third class whose job is reconciling them |
| application | two providers, two streams |
| backup | two export paths, two restore paths, two validator branches |
| UI | a second loop in the delete cascade; an illegal fourth state (required-but-not-available) repaired by hand at `mefarshim_config_sheet.dart:124`, `:131`, `:182` |

**The tell:** `unit_layers_sheet.dart:97-99` renders the two booleans back to the user as *one
word* — `Required` or `Optional`. And `unit_layer_view.dart:29` defines `checkableFor` as
`offered ∪ required`, so the sets were never independent: the second is always a superset.

**Steelman, and it survives:** the *want* is real. "Rashi counts toward done; Maharsha I just want
to tick" is a genuine thing a Daf Yomi learner wants, and no single boolean expresses it.
**But that want is a three-valued enum** — `off | optional | required` — not two booleans with an
invariant enforced by hand in three places.
**The change:** one `layer_configs(profile_id, node_id, unit_index, role, layers_json)` table;
one resolver taking `role` and `defaultSet` — which `InheritedLayerSet` **already accepts as a
constructor parameter**, and which both twins pass the same value to. Delete `OfferedLayers`,
`UnitLayerView`, one table, one schema version, three repo method pairs, two providers.
**The cost:** high — but the schema has never shipped (see finding 4), so this is the last moment
it is cheap. Every month it waits, it gets a migration attached to it.

**Related, same subsystem:** `mefarshim_config_sheet.dart:191` and `:199` both hardcode
`unitIndex: -1`. **Nothing in `lib/` ever writes a per-unit layer override.** Three inheritance
levels are implemented — node config, unit config, ancestor walk — and two are reachable. The
sheet's own doc-comment at `:20` promises the third.

---

### 4. Eleven schema versions in twenty-nine days, for a database that has never shipped. `delete`.

> **Twelve now, and the count is the wrong thing to watch.** Finding 3 added v12 and deleted the v7
> step and one line of v4 outright — they created the two tables v12 merges away, and any database
> old enough to run them has nothing to put in one. So the chain got a step longer and two steps
> shorter, which is this finding's own point made from the other side: the length is a symptom, and
> what actually costs is a step that exists only so a later step has something to read. This finding
> stands otherwise, and the squash is still the right move before v1.
>
> **Thirteen now.** Finding 7 added v13 — a one-line value rewrite of `logged_at`, and the first step
> in the chain that fixes a defect rather than accommodating a shape change. It is also the cheapest
> possible argument for this finding: a squash to v1 would have carried it for free, and instead it
> is a step with its own three migration tests. Every week this waits, the squash gets a little
> less free.

`database.dart:174-295` is 120 lines of migration plus seven schema-introspection helpers
(`_columnsOf`, `_tableExists`, `_isPartOfPrimaryKey`, three `…IfMissing` variants), plus 361
lines of `migration_test.dart`. The only tag, `V1.0.0`, is dated `2026-01-05` and predates the
Flutter rewrite entirely. Every one of these steps defends the developer's own phone.

The chain has already eaten itself twice. **v3 adds a `haara` column that v8 merges away and
drops** — on a v2 database, v3 exists only so that v8 has something to read. **v9 is written out
of order, before v8**, with a ten-line comment explaining that additive columns must precede
table rebuilds or no v7 database can upgrade. That reasoning is correct and it is a rule that
only exists because the chain got long enough to trip over itself.

And the coverage is lopsided the wrong way: the tests start at `user_version = 2`. The v1→v2
`custom_nodes` re-key — the one step that rebuilds a physical table — has no test.

**Steelman:** the author has real learning on a real device and does not want to lose it. That is
the same want the whole app serves, and it would be hypocritical to dismiss it.
**The change:** export the phone's data with the app's own backup, squash to `schemaVersion = 1`,
re-import. Delete 120 lines, seven helpers, 361 test lines.
**The cost:** one round-trip through a feature you already trust enough to ship.

---

### 5. One want, satisfied N times — the inventory. `rewrite`, incrementally.

> ### Four rows resolved — and the one place the diagnosis was wrong
>
> **The counts checked out, and the real number was worse than any single row says.** Walked with a
> counter through a live provider graph rather than by reading: deriving the Statistics surface took
> **seven** full passes over the event log, a midnight tick took **six**, and ten goal rows took
> **ten** more. The per-mark total on the hot path was nine plus one per goal — the fold, five in
> `statsProvider`, `backupStatusProvider`, `batchHistoryProvider`, the dashboard's nudge, and
> `goalStatusProvider` per goal. `derive_cost_test.dart` could not see any of it, because it calls
> `FoldLog.fold` directly, once, in isolation; `provider_notify_test.dart` could not either, because
> it counts notifications, and the notifications were never the problem — the work done before
> deciding not to notify was.
>
> **Where the finding is wrong, and it matters:** *"`LogFold.doneAtByNode` already answers all
> three."* It does not, and building it that way would have shipped a bug. The fold resolves
> membership — an un-marked daf leaves it entirely, and a re-marked one keeps only its latest date.
> The heatmap and the pace are questions about *history*: a daf you learned in March and un-marked
> in June was still learned in March, and March's square must still be lit. Answering them from the
> fold would have silently rewritten the user's past every time they corrected a mark. So it is a
> **second index, not more fields on the first** — `LogActivity`, the log by calendar day — and the
> two are named for the question they answer rather than for the pass that produces them.
>
> **Three of the copies were dead, so they were deleted rather than ported.** `PaceEngine.unitsOn`
> — one of the three sites the *distinct-units-on-a-day* row names — has no production caller at
> all, and neither do `ProgressSeries.dailyDeltas`, `TimeStats.timedSessions` or
> `TimeStats.averageSessionMinutes`. Carrying dead code into a faster index is still carrying dead
> code. That empties `pace_engine.dart` and `time_stats.dart`, which are gone; finding 11's aside
> about `time_stats.dart`'s callerless half is resolved with them.
>
> **The per-meforish row understates itself: the two derivations could genuinely disagree.** They
> are the same arithmetic over the same marked units with the same range clamp, except that `RollUp`
> walks the catalog *from its roots* and `MefarshimStats` walked the fold's node ids. A node whose
> `parentId` points at nothing is in `byId` and not in the forest, so its marks were outside the
> headline `learned` and inside this table. `MefarshimStats.of(forest)` sums the roll-up the
> dashboard bars are already drawn from, which makes them agree by construction. Narrow, and a
> behaviour change, so it is said out loud.
>
> **What the sweep could not reach is that the prescription is not free.** *"One `paceProvider`"* is
> the right answer and adding it broke the app. A `Consumer` that stays mounted under a pushed route
> or an open sheet has its subscriptions paused by `TickerMode` and resumed when the overlay closes;
> resuming one flushes it *and its ancestors*, and a **derived** ancestor that went dirty while it
> slept rebuilds and notifies mid-build, which turns the descendant's re-invalidation into a
> `setState` inside the build phase. Flutter asserts on that. One provider between the dashboard's
> nudge banner and the log was enough to make *drill in, mark a daf, come back* throw every time —
> found by the existing `widget_test.dart`, which is the one test in the suite that walks that
> route. The banner now reads the index directly, one hop from the stream that emitted, and
> `derived_flush_test.dart` pins both paths a mark is made from, with a goal set so the longest
> chain in the app is live.
>
> Resolved by `lib/domain/usecases/log_activity.dart` (one order-independent pass; `unitsDoneByDay`,
> `dailyCounts`, `recordedDoneByDay`, `minutesByDay`, `totalMinutes`, `firstDayLearned`, and the
> five queries as methods so there is no `events` parameter left to pass), `logActivityProvider`
> beside `foldProvider`, `paceProvider` where N+1 scans were, `MefarshimStats.of(forest)`,
> `RemindersPolicy` retyped, `PaceEngine`, `TimeStats` and `ProgressSeries.dailyDone`/`dailyDeltas`
> deleted. `averagePerDay` now costs thirty map lookups instead of a pass over every event ever
> recorded; `streakEndingAt` costs the length of the streak; `dailyCounts` is handed out by identity,
> so `StatsSummary.==` compares the heatmap on a midnight tick in one pointer read.
>
> **And the rule is enforced rather than stated.** `log_pass_count_test.dart` hands the graph an
> event list that counts every element read and asserts in whole passes — two to derive everything,
> zero for ten goal rows, zero for a midnight tick — and three of its five fail on the pre-fix shape
> at 7, 10 and 6, watched fail before being kept. `log_pass_guard_test.dart` reads `lib/` and fails
> the build on a new function taking the whole log, naming the seven that legitimately do and why
> each is its own axis; it was fed a violation rather than assumed to work. And `log_activity_test`
> holds every answer against the *long-hand definition it replaced*, copied verbatim, swept across
> every window end over a log built to hit each edge — a backdated recording, a duration on a
> chazara, a unit marked twice in a day and on two days, an un-mark, a zero duration.
>
> **Not done, and still true:** `backupStatusProvider` still walks the log, on a third axis neither
> index carries — distinct units touched since an *instant*, keyed on `loggedAt`. One pass per change
> and per clock tick. `batchHistoryProvider`, the Notes Journal and the unit details sheet likewise
> ask genuinely different questions of the raw log and were left alone. And the other thirteen rows
> of the inventory below are untouched.

The single largest category by volume. Each row is one idea implemented more than once, in
places that cannot see each other:

| The one want | Times built | Worst consequence |
|---|---|---|
| ~~"which calendar day is this"~~ **✅ Resolved** | ~~**9 sites, 2 incompatible conventions**~~ — all nine migrated to `Day` (`lib/core/day.dart`); the four `_dayNumber` copies, `_dayKey`, `_localMidnight` and `_wholeDaysBetween` are gone, and `test/core/day_math_guard_test.dart` fails the build if the arithmetic reappears outside that file | ~~`Predictor.finishDate` returns a local `DateTime` that the other four would immediately re-ordinalize~~ — and worse: the local-midnight convention was outright wrong across a DST boundary, so five sites (not four) mis-counted one day a year. See the status note at the top |
| ~~distinct-units-learned-on-a-day~~ **✅ Resolved** | ~~3~~ — 2 live and 1 dead (`PaceEngine.unitsOn` had no caller); all now `LogActivity.unitsDoneByDay` | ~~`LogFold.doneAtByNode` already answers all three~~ — it does **not**, and building it that way would have rewritten the user's past on every un-mark. See the status note |
| ~~the pace scalar~~ **✅ Resolved** | ~~once per goal, per tick~~ — one `paceProvider`, and a `double` has real `==`, so an unchanged pace notifies no goal row at all | ~~N goals ⇒ N+1 identical full-log scans per rebuild~~ — measured at ten passes for ten goal rows; now zero |
| ~~per-meforish counts~~ **✅ Resolved** | ~~2~~ — `MefarshimStats.of(forest)` sums the roll-up the dashboard bars are drawn from | ~~same number, two derivations, no test pinning them together~~ — and they could genuinely disagree, on a node whose parent id points at nothing |
| ~~the log→numbers pass~~ **✅ Resolved** | ~~**5 passes in `statsProvider`**~~ — it now watches the two indexes and never the log; every answer is a map lookup | ~~`fold_log.dart:11-14` states the point of the fold was "five ordered passes where one will do"~~ — enforced now, at two passes, by `log_pass_count_test.dart` |
| the date+time+duration+haara form | 2 full copies (`log_unit_sheet`, `add_chazara_sheet`) | two ARB keys for one duration field |
| the meforish checkbox list | 3 | — |
| `nameOf` (layer name with deleted fallback) | 3, and **they disagree** — `unit_details_sheet.dart:155` prints a raw UUID where the other two print a translated string | same fix applied twice out of three |
| the catalog picker | 3 (`cycles_screen:332`, `edit_cycle_screen:237`, `calculator_screen:92`), two of them with cross-referencing comments and **different clamps** (320/400 vs 340/420) | — |
| controller-owning dialog | the shared `text_prompt.dart` + 2 hand-rolls | the bug it was written to end |
| `requiredPerDay` rendering | 3 (`calculator:252`, `goals_screen:69`, `unit_grid_screen:349`) | the Calculator's "By date" mode is a goal you can't save |
| the goal banner widget | 2 byte-identical (`goals_screen:43`, `unit_grid_screen:331`), incl. the delete-with-undo | 2 ARB keys for one sentence |
| "the four customisation lists" | 3 (`settings_screen:289`, `:390`, `backup_service:311`) | shipped a bug: `.asData?.value ?? const []` silently exporting empty lists |
| "is this a positive integer" | 3 layers each, for both interval settings | — |
| JSON parse per restore | 3–4 full decodes of the same file before anything is written | on a Sonim, with a Shas-sized log |
| profile deletion | 2 paths (`drift_progress_repository:120` for 6 tables, `providers.dart:141` for the goals key) | kept in sync by hand |
| `DpadScroll` | 3 call sites — exactly the three report screens | the tax for splitting one report into three routes |

**The change is not "deduplicate."** It is: for each row, build the thing that makes the second
copy impossible. A `core/day.dart` value type. One `LogEntryForm` parameterized by action and
seed. One `NodePicker`. One `paceProvider`. `BackupService.exportProfile` reading its own inputs
instead of taking four lists as parameters.
**The cost:** individually tiny, and `core/day.dart` is the cheapest fix in the repository — one
new file, four deletions, no behaviour change. Do that one first, this week.

---

### 6. Four report screens are Stats sections wearing routes. `delete`.

| screen | lines | how often a user asks its question |
|---|---|---|
| Calculator | 286 | twice a year — and it is the Stats projected-finish tile with the pace made editable |
| Siyumim | 79 | a few times a year — a tree row at 100%, plus a date |
| Goals | 98 | a few times a year — and it **cannot create the thing it lists**; the only creation path is `unit_grid_screen.dart:168`. A screen whose only verb is *delete* |
| Mefarshim progress | 78 | rarely — its own doc-comment concedes it is empty for most users |

Against these, four screens are genuinely daily work surfaces and should not be touched: Cycles,
Chazara, the Journal, the node editor.

The cost of the split is measurable: `DpadScroll` exists at exactly three call sites, and they are
exactly the three screens made entirely of unfocusable figures — the same workaround written three
times because one report became three routes. Plus three of twelve drawer rows, on a phone whose
drawer already needed a "way back" row added because it was too long to be a dead end.

**Steelman:** each is trivially simple (78–98 lines), independently deep-linkable, independently
testable, and `Routes.stats`/`siyumim`/`mefarshim` are asserted in `routes_test.dart` with the
drawer walk device-verified in the README.
**But** none of the four has a widget test of its own, which is exactly what makes the merge cheap.
**The change:** Stats becomes a tabbed report. ~525 lines out, three drawer rows, two `DpadScroll`
copies, one duplicated `requiredPerDay` rendering.

**And in the same region, `delete` `add_chazara_sheet.dart`** (223 lines): same six fields, same
layout, same order as `log_unit_sheet`, differing in `EventAction.reviewed`, the seed set, and one
ARB key. Fold it in with an `action` parameter and the user *gains* the session timer on chazaras —
which is precisely the thing you'd want to time.

---

### 7. The test suite tests the layer that never breaks. `rewrite`. **✅ Resolved**

> **The finding's central claim was right, and it undersold what it was worth.** The double really
> was 344 lines against a 307-line repository, really was used by 38 files, and really had drifted on
> all four named axes — each is now a test in `drift_progress_repository_test.dart` that the double
> passed and the real repository has to earn. Claim 1 held too: `NativeDatabase.memory()` was already
> running under plain `flutter_test` in CI, so nothing had to be added to delete the double, and the
> replacement is the ~8-line `setUp` helper the finding predicted.
>
> **What it did not predict is that the double was hiding a live bug, and a bad one.** Drift's
> `DateTimeColumn` stores `millisecondsSinceEpoch ~/ 1000` — whole seconds. `FoldLog` sorts the log
> by `loggedAt` and breaks ties on the event id, which is a v4 UUID. So *every pair of events inside
> one second* was ordered by a coin flip on random text, and for a `done` and an `undone` on the same
> unit that decides whether the daf is learned — permanently, because the fold is re-derived from the
> log on every read. Mark a daf and un-mark it with two quick taps and roughly half the time it
> stayed marked. Verified rather than reasoned: two events written 900µs apart came back with
> byte-identical timestamps. No test could see it while the suite ran against a double that kept
> `DateTime` objects in a Dart list at full precision — which is this finding's own thesis, arriving
> with a bill attached. `LearningEvents.loggedAt` now stores microseconds through a type converter,
> at schema **v13**, with a value-inspecting idempotency guard so a replayed step cannot multiply by
> a million twice. Both regression tests were watched fail against the old column before being kept.
>
> **A second defect, found the same way and fixed in production rather than in the tests.** Eleven
> call sites read a one-shot value as `await repo.watchCustomNodes(id).first` — open a live query,
> register it in the update store, fetch, emit, cancel, unregister, to answer what a `SELECT`
> answers. The log has had both halves since the beginning (`watchEvents` *and* `getEvents`); the
> other three collections were given only the reactive one, so every reader improvised the other.
> That shape also does not resolve at all under `flutter_test`'s fake clock — a continuous `listen`
> does, `.first` does not — so a widget test that reached one hung rather than failed.
> `getCustomNodes`, `getCustomLayers` and `getLayerConfigs` now exist, sharing one query definition
> and one row mapper with their `watch` halves.
>
> **Where the finding is now stale.** Its coverage table was computed before findings 1–3 landed:
> `core/` is no longer at 3.1 tests per 1,000 lines but 26, because `day.dart` brought its own sweep.
> And "seven screens are never pumped" is now four — `rebuild_cost_test.dart` pumps the journal, the
> siyum screen and the session banner, though only to count rebuilds, never to look at what they
> render.
>
> Resolved by `test/support/memory_database.dart` (the helper, plus the two drift options that make a
> real database usable in a widget test: `dontWarnAboutMultipleDatabases`, whose captured stack trace
> per construction turned a one-minute suite into a four-minute one, and `closeStreamsSynchronously`,
> without which every cancelled query stream leaves a pending timer and the run hangs);
> `FailingProgressRepository` rewritten as a delegating wrapper, which also absorbed a second
> hand-rolled failure double in `import_error_wording_test`; all 110 references migrated; the fake
> deleted. New: `report_screens_test.dart` and `bulk_history_screen_test.dart` build the four screens
> nothing ever built, and `core/daf_yomi_test.dart` covers the file three production files import and
> no test touched. `test/grader/` is dissolved — the three duplicates deleted after checking each
> against what supersedes it (`predictor_cost_test` is line-for-line `predictor_test:184`;
> `sheet_nav_bar_inset_test` covers one of the seven sheets `sheet_insets_test` covers, which also has
> the negative control; `backup_tile_never_exported_test` is three tests in `backup_reminder_test`),
> with the hardware measurements from the deleted ones grafted onto their survivors.
>
> **And the rule is enforced rather than stated.** `test/support/repository_double_guard_test.dart`
> reads `lib/` and `test/` and fails the build on a second `implements ProgressRepository`, on a
> `NativeDatabase.memory()` opened outside the helper, and on a `watchX(...).first`. Each ban carries
> the line it exists to catch and is asserted to still match it, because a source-scanning guard that
> has rotted into matching nothing is the standard way this kind of check dies.
>
> **The cost, said plainly:** `flutter test` went from ~1m30 to ~2m40 on the same machine. That is
> the price of every test opening a real SQLite database, and it is the right trade — but it is a
> real one, and the squash in finding 4 is now worth slightly more than it was.
>
> **Not done, and still true:** `ProgressRepository` grew from 24 methods to 27. Finding 11's
> "revisit whether a ~20-line delegating wrapper is a better shape than a 97-line interface, once the
> in-memory fake is gone" is now unblocked, and pointed at a 105-line interface.

9,806 test lines against 14,636 production is a sane global ratio. The distribution is not:

| area | prod LOC | tests per 1,000 prod lines |
|---|---|---|
| `domain/` | 2,277 | **70.7** |
| `application/` | 2,675 | 35.1 |
| `data/` | 745 | 28.2 |
| **`features/` (UI)** | **7,961** | **16.2** |
| `core/` | 641 | 3.1 |

The pure-Dart domain — the part that is easy to test and rarely wrong — is tested **4.4× more
densely** than the UI. Every one of the last thirteen shipped defects was UI: a confirm button
under the navigation bar, a Hebrew fraction reading backwards, a green tick over a backup that
did not exist, a grid a keyboard could only half reach, a deep link that broke while running.

**Seven screens are never pumped by any test** — 798 lines: bulk history, journal, chazara,
session banner, goals, siyum, mefarshim progress. Each has a fully-tested domain function behind
it. `routes_test.dart:57` and `deep_link_test.dart:132` *construct* them and assert `isNotNull`;
they never build them. `lib/core/daf_yomi.dart`, imported by three production files, has no test
at all.

**And `test/support/in_memory_progress_repository.dart` should be deleted.** 398 lines — 20%
larger than the real repository it doubles — used by 38 files. Its docstring makes two claims:

1. *"no native dependencies"* — but `drift_progress_repository_test.dart:26`,
   `grader/event_id_collision_test.dart:26` and `grader/restore_scope_test.dart:41` already run
   `AppDatabase(NativeDatabase.memory())` under plain `flutter_test`, in CI, today, finishing in
   under a second. `sqlite3` is already a dev dependency.
2. *"a faithful implementation rather than a stub"* — it has already drifted on four axes.
   `updateEvent` replaces the whole object where the real one writes three fields and documents
   identity as immutable. `addProfile` is `_profiles.add` where the real one throws SQLITE 1555
   on a duplicate. It has no `_encodeLayers`, so `backup_service_test.dart:79`'s "round-trips
   layers" proves nothing about the column that stores them. Its `transaction` claims to match
   SQLite's nesting; Drift nests via `SAVEPOINT`, which rolls back differently.

The docstring is honest that this class of drift is why the cross-profile import collision stayed
invisible. It then re-earns the same risk on four new axes.

**The change:** an ~8-line `NativeDatabase.memory()` `setUp`/`tearDown` helper. The failure-injection
doubles need a ~20-line delegating wrapper instead of `extends` — smaller than the class it deletes.
Then spend the 398 lines on the seven unpumped screens.

**`test/grader/` should be dissolved.** A folder named after the review that produced it is a
fossil: nothing in the app is called "grader", nobody editing `log_unit_sheet.dart` will look
there, and four of its seven files are already strictly superseded elsewhere and stayed alive only
because a provenance folder never prompts the question *"is this still the best home for this?"*
`predictor_cost_test`, `sheet_nav_bar_inset_test` and `backup_tile_never_exported_test` are
duplicates — delete. The other four move next to what they test. **Keep every word of the forensic
prose in them; it is the best documentation in the repository.**

---

### 8. The documentation is a fossil of the process that produced it. `delete`.

2,801 lines of markdown outside the code.

| file | lines | verdict |
|---|---|---|
| `fixes.md` | 874 | **Delete**, keeping lines 15–34. It is an index into git — every "Done" row carries a SHA, and the commit messages in this repo are unusually complete, which is what makes the markdown redundant rather than complementary. Lines 692–784 are *explicitly preserved as an obsolete document*. Lines 15–34 are project standards, are the thing a new contributor most needs, and are buried at line 15 of an 874-line changelog. Move them to `CONTRIBUTING.md`. |
| `docs/GRADE-2026-07-29.md` | 302 | **Delete.** Every finding closed; the durable output is `test/grader/`, which is code and survives refactors. |
| `docs/GRADE-2026-07-30.md` | 444 | **Delete, carving out §2** — the four dead oracles for measuring Flutter jank over ADB and the DPI-unaware screenshot trap. ~35 lines, genuinely unrecoverable, belongs in `docs/MEASURING.md`. |
| `docs/BUILD-2026-07-30.md` | 439 | **Delete**, carving out ~20 lines from §5. Twelve work orders, twelve commits, same reasoning at the same length in each commit message. It documents its own rot: it corrects a line number from another doc inside itself. |
| `docs/ARCHITECTURE.md` | 336 | **Cut to §10.** §1 is README again down to the sentence. §5 restates "What works today" as a table. §6's roadmap *contradicts* the README's phase table. §2.2 documents a `UnitState` Drift table **that does not exist**. §7-§8 schedule decisions made nine phases ago. Eight source files cite this by section number and two of the four cited sections are wrong today. |
| `README.md` | 407 | **Cut to ~120.** It is the highest-churn file in the repository. It states the test count **three times and is wrong twice** (413 / 430 / 352; actual 430) — one number, three sites, hand-maintained. Keep: what the app is, the architecture paragraph, Platform status, Toolchain notes, Developing/Translating/Releasing/Icon. Delete: the 12-row phase table and the 200-line "What works today", which is a changelog in release-note voice — every sentence phrased *"it used to be broken"* is a commit message that escaped. |

**Two README paragraphs are not merely stale, they describe behaviour the code does not have.**
`ImportMode` governs the event log and four repository tables and **nothing else** — `goals.dart:55`
merges in every mode and `settings.dart:290` overwrites key-by-key in every mode. So "Import
(merges) … never removes anything" silently replaces your sort order, chazara intervals, hidden
bars and cycles from the file; and "Restore everything … makes the whole profile match the file"
leaves behind every goal set since the backup. That is a missing branch, not a design — fix the
code, then the prose.

---

### 9. The validator defends a door that three other doors already lock. `delete` (146 of 166 lines).

`BackupValidator` (`backup_service.dart:396-561`) justifies itself at `:398-403` with two claims:

- *"a negative `unitCount` makes `RollUp` throw on every dashboard build"* — `roll_up.dart:51`
  assigns it to `total` and never divides; `catalog_node.dart:101` uses `Iterable.generate`, empty
  for a negative count; `ProgressNode` has no assert. It renders `3 / -5`. It does not throw.
- *"a `parentId` cycle makes the inheritance walk recurse forever"* — `catalog.dart:40-56` and
  `inherited_layer_set.dart:38-61` already refuse to visit a node twice, **and both say in their
  own comments that they guard precisely because a hand-edited import can contain a cycle.**

The downstream guards would have sufficed alone, and they also cover cycles created *in-app* by
the node editor, which the validator never sees. Cycle detection now exists in three places with
three theories of who is responsible.

**Steelman:** if the file came from a hostile source, a trust boundary is right and cheap
insurance. **It doesn't** — it is the user's own export from minutes earlier, and `parse` already
rejects anything that isn't JSON of the right shape.
**The change:** keep ~20 lines of bounds checking (file size, `unitCount` clamp). Delete the rest.

---

### 10. Committed generated localizations. `delete` from git.

8,015 lines of `lib/l10n/generated/**` are tracked, and CI has a step to check they aren't stale.

The `.g.dart` precedent doesn't transfer. `build_runner` is slow and describes a schema, so
committing its output buys real time. **`flutter gen-l10n` runs automatically on `flutter pub get`,
in about two seconds, with no schema, no database and no network.** If the output weren't
committed it could not go stale — so the CI step exists to check for a defect the decision to
commit invented. `l10n.yaml`'s comment argues that committing is what makes the staleness check
possible, which is true and circular.

The tax is measurable: across 9 commits touching `lib/l10n/generated`, git records **8,034 lines
added against 1,661 for the ARB files they derive from — 4.8×**. `bf8e1d2` changed 2 ARB lines and
dragged 12 generated lines through the diff. The generated table (8,015) outweighs all of
`lib/features` (7,961) — the string table's machine form is larger than the entire UI it serves.

**The change:** gitignore `lib/l10n/generated`; keep the CI generate step; drop the diff step.
The untranslated-locale gate — the genuinely valuable check — is independent and stays.
**The cost:** one `pub get` after a fresh clone, which Flutter requires anyway.

**While you're in there:** five ARB keys have zero call sites in both locales — `addNodeHebrewName`,
`addNodeNeedName`, `dateTimeLabel`, `errorTitle`, `mefarshimHebrewOptional` (verified). And
`cycleDafHebrew` is `"{sefer} · דף {unit}"` — a Hebrew literal living in **`app_en.arb`**, rendered
unconditionally at `cycles_screen.dart:251`. An English reader gets a Hebrew line; a Hebrew reader
gets it twice.

Also worth saying plainly: **the per-locale plural machinery is unexercised.** All 33 plural
messages in both files use `=1{…} other{…}` — exact-match, which bypasses CLDR entirely. Hebrew
has a real dual and `bulkConfirmUnits` renders `{count} יחידות` for 2. The README defends this
apparatus against `'$verb $n unit(s)'` while shipping the same expressiveness under heavier syntax.

---

### 11. `wrong-but-keep`

- **The `usecase-per-file` structure.** Ten files averaging 72 lines; five of them are classes with
  private constructors holding static methods, which in Dart is a namespace, not an object. It is a
  Java shape. It also costs approximately nothing, and renaming nineteen files is churn with no user
  on the other end. **Leave it.** (`reminders_policy.dart` at 22 lines — one boolean AND with one
  caller — and `time_stats.dart`, half of whose functions have zero callers, are worth folding into
  their single call sites when you're next in there. Not a project.) **`time_stats.dart` is now
  gone** — half of it had no callers and the other half moved into `LogActivity` with finding 5's
  four rows; `reminders_policy.dart` stands.
- **`CatalogRepository`.** One method, one production implementation, and the extension point it was
  built for ("remote/custom sources later") shipped instead as `custom_nodes` merged in a provider,
  bypassing the interface entirely. Deleting it is net-negative-cost. It is also 7 lines. Leave it
  until you touch the file for another reason.
- **`ProgressRepository`.** 97 lines, 24 methods, one production implementation — but three test
  doubles, and `FailingProgressRepository` exists to prove the write-error banner works, which you
  cannot make Drift do on demand. Once finding 7 lands and the in-memory fake is gone, revisit
  whether a ~20-line delegating wrapper is a better shape than a 97-line interface. Not before.
  **Now unblocked** (finding 7 landed) — and pointed at a bigger target than this predicted: one
  production implementation, *one* test double, and 27 methods across 109 lines, because the three
  one-shot getters the eleven `.first` call sites were improvising had to be added. The revisit is
  worth doing; the answer is less obvious than it looks, since the delegating wrapper would still
  need all 27 members.

---

## What I couldn't beat

Not a compliment quota — these are the places I tried to design something better and failed.

- **`routes.dart` is the best 177 lines in the repo.** Ids not objects; nothing in `arguments`, so
  no route is un-restorable; and `_segments` folds `uri.host` in as a leading segment so one table
  serves both the in-app push `/sefer/<id>` and the deep link `chovoshayom://sefer/<id>`, where
  "sefer" is the *authority*, not a path segment. That last detail is the kind of thing you only
  learn by shipping it wrong once. It also kills a staleness class for free: a screen holding an id
  re-resolves against the live catalog, so a rename shows up on an already-open screen.
- **`guarded.dart` earns its 70 executable lines** across 51 write sites — for the two things a
  hand-rolled `try`/`catch` cannot do: capture messenger, navigator, crash log and l10n *before* the
  await, and `persist: false`, because Flutter defaults `SnackBar.persist` to `action != null`, so on
  a device with no swipe every Undo snackbar was permanent. That is genuine cross-cutting policy.
- **`sheet_insets_test.dart:200`** — a deliberate negative control that feeds the checker a
  knowingly-broken sheet and *requires* the assertion to fail. A geometry check that cannot fail is
  what let a dead button ship, and almost nobody writes the control. Best test in the repository.
- **`derive_cost_test.dart`** — a `fullScans` counter asserting **zero** full log scans against a
  500,000-unit catalog, plus 100,000 events folded under a 3-second bound and 20,000 events across
  200 days, both there to catch *constant-factor* regressions rather than algorithmic ones. Almost
  nobody writes the second kind. My first draft of finding 2 implied the derive engine had never
  been measured at scale; that was wrong, and this is why finding 2 is about the provider chain
  around the fold rather than about the fold.
- **`FocusRingOverlay` cannot be a theme,** which was my first instinct. Material paints its focus
  overlay *behind* the app's own filled containers — that's the defect — and no `ThemeData` field
  fixes paint order. Gate its `setState` on scroll notifications; don't touch the architecture.
- **`nodePath`/`qualifiedNodeName` deriving "Shabbos · Shas · Moed" from ancestry** instead of typing
  "(Shas)" into 120 names. It is correct for user-added nodes, and — the part I missed — the
  qualifier *translates*, where a typed suffix would have needed a second hand-typed Hebrew one.
- **`restoreLog` vs `import`**, per the sketch section above. The code found the append-only
  consequence before I did.
- **The keypad work.** `core/keypad.dart` is 226 code lines and 146 comment, and three of its six
  parts (`barActions`, `DpadScroll`, `FocusRingOverlay`) are unconditional cross-platform
  improvements that would be worth keeping if the Sonim went in a river. Only ~19 lines are
  genuinely "this device is 240dp". The file is misnamed, not overbuilt — a file called `keypad.dart`
  that a screen imports to decide whether to show a checkmark in a segmented button has stopped
  describing itself. Split into `breakpoints.dart` / `bar_actions.dart` / `focus.dart`; delete nothing.

---

## The one gate that is missing

CI has six gates and all six earn their runtime — stale codegen, stale l10n, untranslated locale,
`analyze --fatal-infos`, tests, R8 mapping. The `--coverage` flag does not: nothing reads
`lcov.info`, there is no threshold, no badge, no diff.

**There is no Windows job.** The author builds and runs Windows locally, so this is not a coverage
hole — it is a coverage hole *waiting for the week Windows stops being the machine you happen to be
sitting at*. The residual argument is the repo's own, made about R8: that assertion is documented as
toothless locally because Gradle reuses a stale mapping, and meaningful only on a clean checkout.
CMake caches just as aggressively, and the CMake target-id failure that once broke the Windows build
*completely* is exactly the class a warm build tree hides. Four lines of YAML, someday — not urgent.

---

## Where I'd start

1. ~~`return () => DateTime.now();` — today. One character, one real bug.~~ **✅ Done.**
2. ~~`core/day.dart` — one file, four deletions, no behaviour change. This week.~~ **✅ Done.** It
   was seven deletions, not four, and it *was* a behaviour change: the DST arithmetic it replaced
   was wrong, not merely duplicated.
3. ~~`==` on `ProgressNode` and `LogFold`; gate the two 1 Hz tickers. Behind `dashboard_rebuild_test.dart`.~~
   **✅ Done** — eight types, not two; `LogFold` deliberately excluded (see the status note); three
   families auto-disposed; tickers gated on `isRunning`. `dashboard_rebuild_test.dart` turned out
   to be a framework-error net rather than a rebuild counter, so the safety net for this was built
   rather than borrowed: `provider_notify_test.dart`, `rebuild_cost_test.dart` and
   `notify_guard_test.dart`, 29 tests, 13 of which fail on the pre-fix code.
4. Squash the schema to v1 **before** the first release, because after it this stops being free.
5. ~~Collapse required/offered to one `role` column — same deadline, same reason.~~ **✅ Done** —
   and not to a `role` column, which keeps two sets. To one role *map*, which is what this
   document's own diagnosis of finding 3 asks for; the fourth state is now unrepresentable rather
   than repaired. Schema v12, backup format v5, one resolver where there were three.
6. ~~Delete the in-memory repository fake; spend it on the seven unpumped screens.~~ **✅ Done** —
   and the fake was hiding a live bug: sub-second timestamps were being discarded at rest, so a
   mark and an un-mark in the same second were ordered by their random UUIDs. Schema v13. See the
   status note on finding 7 for that, for the eleven one-shot reads dressed as live queries, and
   for what the finding got stale about.
7. Delete `fixes.md`, both GRADEs and BUILD (carving ~55 lines of measurement lore into
   `docs/MEASURING.md`); cut the README to ~120 lines and `ARCHITECTURE.md` to §10.

---

## What I don't know

- **Is there a second user?** Most of what I called over-built — profiles, four import modes,
  per-node mefarshim configuration — is defensible if someone other than the author is going to
  use this, and much less so if not. Every verdict above assumes the README's framing: one person's
  learning, on one device.
- **Is there a release date?** Findings 4 and 3 are cheap now and expensive the day after v1 ships.
  That's a scheduling question, not a design one, and it's yours.
- **What is being built next?** Half of what makes a design wrong is the change it is about to face,
  and that isn't in the repo. If the next thing is a second locale, finding 10 changes shape. If it
  is a sync or backup service, finding 2 (equality) becomes urgent rather than merely correct. If it
  is nothing — if this is done — then findings 5, 8 and 11 are the only ones worth the time.
