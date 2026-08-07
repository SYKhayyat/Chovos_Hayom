# Chovos Hayom — a lamdan reading

**2026-08-05** · whole repo, 236 tracked files, swept region by region · `master` @ `bf8e1d2`

> **Status, 2026-08-06 (last).** The **`requiredPerDay` rendering** row of finding 5 is now
> resolved, and it is the row where the duplication turned out to be the *smaller* half of the
> problem.
>
> **It was three sites and is two**, the third having gone with `goal_status.dart` when the goal
> banner and the goals row stopped writing the same sentence twice. The two left — the goal line and
> the Calculator's *By date* answer — compute the identical quantity through the identical
> `Predictor.requiredPerDay`, and then each wrote `toStringAsFixed(2)` for itself. One number, two
> spellings, sitting **one button apart**: *Save as goal* is directly under the Calculator's answer.
>
> **And both spellings were wrong, in the same direction.** This is a requirement, not a
> measurement. 155 dapim over 91 days is 1.7032…, and rounding to nearest displays **1.70** — a pace
> you can follow exactly, every day, for ninety-one days, and finish 0.3 of a daf short. The app was
> telling the user a number that does not reach the date it names. `requiredPerDayText` rounds up,
> in the one place the decision now lives.
>
> That is a behaviour change to a number on screen, so it is said out loud: every goal in the app
> now reads one hundredth higher where the division is not exact. `avgPerDay` on the Overview is
> deliberately untouched — a *measured* average rounded up would overstate what the user has done,
> which is the same error pointing the other way.
>
> The rounding has one trap and it is tested: `3.33` is `3.3300000000000000710…` in binary, so a
> bare `(rate * 100).ceil()` reports an exact 3.33 as 3.34. And the rule is enforced rather than
> stated — a file that mentions `requiredPerDay` may not also call `toStringAsFixed`, plus a test
> that reads the Calculator's answer off the screen, saves it, and asserts the goal reports the same
> digits.
>
> ---
>
> **Status, 2026-08-06 (previously last).** The **controller-owning dialog** row of finding 5 — which is also
> row 5 of *The claim* — is now resolved, and the interesting part is **why the rule was broken by
> two dialogs that had a file written to stop them**.
>
> `text_prompt.dart` took **one field**. `_LayerNameDialog` wanted two (a name and its Hebrew), and
> `_RangeDialog` wanted two *and* something else the prompt could not do at all: reject its own
> input and **stay open**. Closing and then complaining throws away what the user typed, which on a
> keypad phone is a dozen key presses to re-enter. So each of them grew a `State`, a pair of
> controllers, a `dispose` and a paragraph explaining the use-after-dispose bug — three copies of
> one piece of knowledge, two of them out of reach of the file that holds it.
>
> That is a sharper version of this document's thesis than "the author forgot". Neither author
> forgot; both read the rule, found the shared thing could not do the job, and wrote the exception
> correctly. **A shared implementation that does not cover the second case is a shared
> implementation that will be copied**, and the copy is where the knowledge rots — the copies here
> happen to be right, and there was nothing making them so.
>
> Resolved by giving the prompt a `List<PromptField>`, a `PromptLayout` (the range's two numbers are
> one answer and read as two questions stacked), a `footer`, and a `validate` callback that returns
> a message and keeps the dialog open. `promptForText` is now a one-field wrapper over it, so all
> five existing callers are untouched. Both hand-rolls are deleted; the range's bounds check came
> out as two pure functions on the way.
>
> **And the rule is enforced rather than stated.** `text_prompt_guard_test.dart` fails the build on
> a file that builds an `AlertDialog` *and* constructs a `TextEditingController` — per file rather
> than per line, because that is the shape of the mistake. Screens and sheets own controllers all
> the time and should: a form's controller dies with its route, not one frame before it. Fed a
> violation and watched to fail.
>
> ---
>
> **Status, 2026-08-06 (previously last).** The **meforish checkbox list** row of finding 5 is now resolved,
> and its *Worst consequence* column — which is empty in the table — turned out to hold the only
> live defect left in the inventory.
>
> **Three lists, four answers.** The row counts the renderings. What is duplicated underneath them
> is the question *which mefarshim does this unit have, and in what state*, and it was worked out
> from the roles and the fold separately by the per-unit checklist, *log with details*, *log a
> chazara* and — a fourth the sweep did not reach — the Chazara screen's one-tap review, whose
> comment claims it does "what the Add-chazara sheet defaults to" and which nothing held to it.
>
> **They disagreed, on the one case that is not hypothetical.** The log is append-only, so a
> meforish deleted after a unit was marked keeps its id in the events — deliberately, because the
> daf really was learned with it. The checklist handled that with a safety loop appending anything
> the mefarshim list did not contain. *Log with details* did not need to. And the chazara sheet
> filtered its **options** through the mefarshim list while seeding its **selection** from the log,
> so that layer was *selected and invisible*: no row, no way to untick it, and submitted anyway. A
> chazara recorded against something the user could neither see nor refuse. Reproduced through the
> real screens in `meforish_checklist_test.dart`, and two of its three assertions were watched to
> fail on the pre-fix shape before being kept.
>
> Resolved by `lib/domain/usecases/unit_mefarshim.dart` — one ordered list where a role of `null`
> is a real state (*learned here, not asked for any more*) rather than an absence — with `all`,
> `checkable`, `reviewable`, `required`, `done` and `outstanding` as the slices the four sites take.
> `MeforishChecklist` draws the rows. `LayerRoles.checkableFor` went with them: nothing called it
> once the last hand-built answer was gone.
>
> **And the rule is enforced rather than stated.** `layer_role_guard_test.dart` grew a second
> group: nothing under `features/` may read `completedLayers` or `requiredFor`, because those are
> the two halves that were being recombined by hand. `forUnit` is deliberately *not* banned and the
> file says why — on its own it carries no done-state, and the name collides with
> `UnitHistoryFinder.forUnit`, which is a different question about the same two arguments. Fed a
> violation rather than assumed to work.
>
> ---
>
> **Status, 2026-08-06 (previously last).** The **catalog picker** row of finding 5 is now resolved.
>
> **It was three and it is four, and the fourth is the one worth having.** The row names
> `cycles_screen`, `edit_cycle_screen` and the Calculator; the node editor's *parent* dropdown is a
> fourth, and while the three the sweep found differ only in cosmetics — two `SimpleDialog`s with
> hard-coded widths of 320 and 340, one of them commented "see the same clamp in
> cycles_screen.dart" *beside a different number*, and both wider than the 240dp screen this app is
> built for — the fourth differs in a way a user can feel. It sorted by `a.name`, the **raw English
> field**, whatever language the reader was in, and labelled each row with the bare name rather
> than the qualified one. So a Hebrew reader choosing where to file a sefer got a list ordered by
> strings that were not on their screen, containing four rows all reading "שבת". Every one of the
> other three carried a comment explaining why its list is qualified. The one written last had
> neither the comment nor the qualifier, which is the finding's own thesis: a rule stated four
> times is a rule nobody owns.
>
> Resolved by `lib/features/common/node_picker.dart` — `nodeChoices` (which nodes, in what order,
> under what label), `showNodePicker` (one clamp, sized to the screen it is on) and `NodeDropdown`
> (the indent, the ellipsis, and a fallback for a value the list no longer contains). All four
> sites migrated. `node_picker_guard_test.dart` refuses a fifth and **names the one deliberate
> exception** — the search delegate, which navigates rather than returns and puts the qualifier in
> a subtitle beside the unit count. The guard asserts the exception is still shaped the way its
> reason says, so it cannot outlive it.
>
> **The Calculator got cheaper on the way past.** It watched `progressForestProvider` and walked
> all 312 nodes into a parallel list on every build to read `remaining` and `total` off *one* of
> them, so a mark anywhere in the catalog rebuilt the tab. It reads `progressNodeProvider(id)` now:
> one map lookup, auto-disposed, with value equality on the other side of it.
>
> **And the guards had grown the defect they exist to catch.** Five of them had written the same
> source scanner out for themselves — comment stripping, generated-code skipping, thirty lines —
> and four were byte-identical. The fifth, `layer_role_guard_test.dart`, had quietly dropped the
> **escape hatch**: every guard's docstring says it is a speed bump rather than a wall, and that
> one was a wall with nothing saying so. `test/support/source_scan.dart` is the one scanner now,
> and it takes the marker as a *required* argument, so a guard cannot forget to have one.
>
> ---
>
> **Status, 2026-08-06 (previously last).** Two rows of **finding 5** that looked already-resolved are now
> settled on their own terms, which is the point of checking rather than assuming: one of them was
> resolved and the other had got *worse* since the count was taken.
>
> **The goal banner really is one widget**, and every part of the row checked out — one `GoalBanner`,
> one `goalStatusText`, one `removeGoalWithUndo`, one ARB key, and `report_guard_test.dart` already
> refusing a second reader of it. What the row could not see is the **residue of its own fix**. The
> two ARB keys became one, and the metadata block beside the survivor was still named for the key
> that went: `@goalBanner` describing a `goalStatus` that no longer existed. Nothing failed, because
> gen-l10n does not require metadata — so the block was ignored and the three placeholders it
> declared as `String` were silently re-inferred as **`Object`**. That is not cosmetic:
> `goalStatus(Object, Object, Object)` accepts the `double` that `requiredPerDay` actually is, and
> renders `2.4285714285714284` into a sentence the declared version will not compile. A declaration
> that has come loose from its message is worse than no declaration, because the table still reads
> as though the types are stated. Both halves are now rules in `arb_guard_test.dart`, fed the real
> violation rather than assumed to work.
>
> **`DpadScroll` was three call sites and is four.** Merging the four report routes into one screen
> did not reduce the count — each section kept its own copy, and `ReportEmpty` grew a fourth — so
> the row's *worst consequence*, "the tax for splitting one report into three routes", is wrong
> about where the tax came from. The wrapper's `skipTraversal: false` is a fact about the **tab bar
> above** all of them, not about any one section, and three sections were each asserting it locally
> with the same paragraph of explanation above it. One `ReportBody` owns it now, and the guard
> refuses a fifth copy inside `reports/`. The two sections that do *not* use it — Goals and the
> Calculator — are deliberate and are said so in the code: they are full of focusable widgets, and
> claiming the arrow keys ahead of traversal would make the D-pad scroll *past* the controls
> instead of onto them.
>
> ---
>
> **Status, 2026-08-06 (previously last).** **Finding 9** (*"The validator defends a door that three other
> doors already lock"*) is now resolved — see the note below it. Its first claim was right and was
> measured rather than believed; its second is **wrong**, and the prescription that follows from it
> would have shipped two crashes. There are eight walks over the parent relation, not three, and the
> two the sweep never reached had no guard at all: one does not return and the other overflows the
> stack, both demonstrated rather than argued. The fix is neither keeping the check nor deleting it —
> `Catalog` now guarantees a forest, so the shape is unrepresentable and the check is genuinely
> redundant for a reason the finding did not have. The line count is a disagreement, argued in the
> note, and so is what survives: four checks earn their place on evidence, and the `knownParents` map
> threaded through two screens to feed the deleted ones goes with them. Findings 5 (nine rows) and 11
> remain.
>
> ---
>
> **Status, 2026-08-06 (previously last).** **Finding 10** (*"Committed generated localizations"*) is now
> resolved — see the note below it. Its headline claim was tested rather than believed (the directory
> was deleted and `pub get` rebuilt it byte-identical), the ratio it rests on survived exactly while
> one of its flourishes expired, and the best evidence for it was already written inside the CI step
> it indicts. The two things the sweep could not reach are both in the paragraph it files under
> *While you're in there*: `dateTimeLabel` is listed as dead weight and is really a key unused
> *because* a screen was hand-gluing the string — the one screen in the app where you choose a date,
> and the only one that ignored the Hebrew calendar setting. And `cycleDafHebrew` is half wrong (the
> Hebrew line is deliberate, as its own `@description` says) and half worse than stated, because the
> comment that made it look harmless — *"the whole bundled catalog"* has no Hebrew names — stopped
> being true for all 312 nodes. The generalizable defect, which the finding does not name, is a key
> stored *identically* in both locales: certified as translated by the gate, maintained by nobody.
> That is now a test. The plural paragraph is a disagreement, argued in the note. Findings 5 (nine
> rows), 9 and 11 remain.
>
> ---
>
> **Status, 2026-08-06 (previously last).** **Finding 8** (*"The documentation is a fossil of the process that
> produced it"*) is now resolved — see the note below it, including the two counts in it that had
> rotted, the third that has been overtaken, and the reason its most valuable sentence is a
> parenthetical in a table of documents to delete. That sentence is about the *code*: `ImportMode`
> governed the log and four tables and nothing else, which broke the promise in both directions —
> the one the finding names, and a worse one it does not, where a **merge** deleted a learning cycle
> in the mode that undertakes to remove nothing. It is the residue of a lineage three earlier
> reviews each got one layer of. `README.md` is 310 lines rather than the ~120 costed, which is a
> disagreement, argued in the note. That was the last item in *Where I'd start*; findings 5 (thirteen
> rows), 9, 10 and 11 remain.
>
> ---
>
> **Status, 2026-08-06 (two back).** **Finding 4** (*"Eleven schema versions in twenty-nine days, for a
> database that has never shipped"*) is now resolved — see the note below it, including the round
> trip it was costed at that turned out not to be needed, the two numbers in it that had grown while
> it waited, and the one thing the sweep could not have reached: the database it is about was not at
> the head of the chain, so squashing without running the chain one last time would have bricked it.
>
> ---
>
> **Status, 2026-08-06 (three back).** **Finding 6** (*"Four report screens are Stats sections wearing
> routes"*) is now resolved — see the note below it, including the one place its arithmetic is
> wrong (the `DpadScroll` count), the one claim that has gone stale since it was written, and the
> keypad interaction the sweep could not have reached. Two rows of **finding 5** go with it: the
> date+time+duration+haara form and `nameOf`.
>
> ---
>
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
| `text_prompt.dart` exists because five dialogs each hand-rolled a controller and threw *used after being disposed* | `_LayerNameDialog` (`mefarshim_config_sheet.dart:400`) and `_RangeDialog` (`bulk_actions_sheet.dart:329`) hand-roll it again. **✅ Resolved** — and neither author had forgotten the rule: the shared prompt took one field and could not reject input, and both of them needed more. A shared thing that does not cover the second case gets copied. See finding 5. |
| `README.md:358` — *"a message is one whole ARB entry, never a sentence glued together"* | `dateTimeLabel` exists, is translated into Hebrew, and has **zero call sites**; `log_unit_sheet.dart:194` and `add_chazara_sheet.dart:173` each glue the string by hand. **✅ Resolved** — one hand-glue by then, and it was a fourth copy of `DateDisplay.formatWithTime` that ignored the calendar setting. See finding 10. |
| `README.md:373` — *"the lint is what keeps new ones from drifting back out of [the guard]"* | `unawaited_futures` fires on expression statements in **async** bodies. The dominant shape here is `onPressed: () => guarded(...)` — a sync arrow closure. Not flagged, any of them. |
| `learning_event.dart:62-68` — `copyWith` deleted because *"nothing called it"* | `backup_service.dart:353` hand-lists all eleven fields to rescope an event. That *is* `copyWith`, minus the compiler's help. |
| `sorting.dart:56-65` — ten lines condemning conditional watches | see row 2. **✅ Resolved** with it, and now guarded: `notify_guard_test.dart`. |
| `backup_service.dart:398-403` — the validator justified by two crashes it prevents | Neither crash exists: `catalog.dart:47` and `inherited_layer_set.dart:38` already refuse to revisit a node, and `catalog_node.dart:101` uses `Iterable.generate`, which is empty for a negative count. The guards that make the validator unnecessary say so in *their own* comments. **✅ Resolved** — and the second half of this row is itself wrong: two more walks had *no* guard, and one of them never returns. See finding 9. |

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

### 4. Eleven schema versions in twenty-nine days, for a database that has never shipped. `delete`. **✅ Resolved**

> ### Squashed to v1 — and the round trip it was costed at turned out to be unnecessary
>
> **Every claim in the finding checked out, and the two numbers in it had grown.** `V1.0.0` is dated
> `2026-01-05` and is still the only tag. The chain really had eaten itself twice, in exactly the two
> places named. The v1 → v2 `custom_nodes` re-key really had no test of its own — the tests start at
> `user_version = 2` — although the *half-migrated* case seeds `custom_nodes` in its pre-v2 shape and
> reaches the step sideways, which is the closest the suite came. What has moved is the size: **230
> lines of migration, not 120, and 649 of test, not 361**, because findings 3 and 7 each added a step
> with its own tests. This finding's whole argument is that the number goes one way, and it did,
> while the finding was sitting there.
>
> **The prescription was more expensive than the problem, and that is the part the sweep could not
> see.** *"Export the phone's data with the app's own backup, squash, re-import"* — one round trip
> through a feature you already trust. It is not needed. A database at the head of the chain is
> **already** the shape `createAll()` produces at v1: same five tables, same columns, same
> `learning_events_batch` index. Verified rather than assumed — the DDL was read straight off the
> real Windows database that the deleted chain had produced, and a fresh v1 database matches it
> statement for statement. So adopting a head-shaped database is *nothing*: drift calls `onUpgrade`
> in **either** direction (`hadUpgrade` is `versionBefore != versionNow`, not `<`), the clause
> returns, and `user_version` is stamped down to 1 on the way past. That is the only line of
> migration code left in the file.
>
> **What the finding could not have known is that the one database it is about was not at head.**
> `Documents/chovos_hayom.sqlite` on the machine this was read on was at **v11 with 35 events** —
> the two most recent steps had never run here, because the app has not been launched on Windows
> since 2026-07-30. So the squash *would* have bricked it, which is the sweep's point about "the
> developer's own phone" arriving from the other side. It was carried through the chain one last
> time with the chain still present (v11 → v13, 35 events intact, the two legacy layer tables
> dropped, `logged_at` rescaled), and then adopted by the squashed build (v13 → v1, 35 events
> intact). A copy of the original sits beside it as `chovos_hayom.pre-squash-backup.sqlite`.
>
> **A database this build cannot produce is refused rather than opened**, and that is not
> defensiveness — a v12 file still holds `logged_at` in whole seconds, so opening one would read
> every event as an instant in 1970 and reorder the log silently. `SchemaMismatchException` carries
> the way out in its own text, because that text is what the user reads: `databaseProvider` throwing
> surfaces through `ErrorView`, which prints it under *Show details* and appends it to the crash
> log. And refusing is provably harmless to the file — drift stamps `user_version` only *after* the
> migration callback returns, so a rejected database can still be opened by the build that wrote it,
> which is what makes "install the older build once" a real recovery rather than a hopeful one.
>
> **The one rule worth keeping from the deleted chain is the one its doc comment opened with:**
> *bumping `schemaVersion` without a step silently does nothing on an existing install.* That is why
> the doorman throws on `from < to` as well. The next schema change in this project's life fails at
> the door, on the first launch, instead of derailing into `no such column` three screens later.
>
> Resolved by `kSchemaVersion = 1`, `kPreSquashSchemaVersion` and `SchemaMismatchException` in
> `lib/data/drift/database.dart`; the twelve-step `onUpgrade`, `_mergeLayerConfigs` and all seven
> schema-introspection helpers deleted, along with the two imports they were the only users of.
> `migration_test.dart` (649 lines) is replaced by `test/data/schema_test.dart` (8 tests), and the
> suite went from 579 tests in 2m03 to 571 in 1m37.
>
> **And the rule is enforced rather than stated.** The claim the adoption clause rests on is that
> v1's shape and v13's are the same shape, and the way that rots is somebody editing a column. So
> the test compares a freshly-created database against the schema **read off the device file the old
> chain produced**, not against the Dart definitions it is checking — watched fail by changing one
> column default, which is exactly the moment to write a real v2 step instead. The adoption tests
> were watched fail with the clause removed, and the refusal tests assert the file is byte-for-byte
> where it was afterwards.
>
> **Not done, and still true:** the `kPreSquashSchemaVersion` clause is itself legacy — six lines
> that exist so that upgrading costs an existing install nothing. It says in its own doc comment
> that it should be deleted once every install has opened a post-squash build.

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
>
> > **Since resolved — and the phrase to distrust was "and per clock tick".** The axis is real and
> > the pass is the price of it; what was wrong was that four things paid it. The provider also
> > watched the clock and the whole `SettingsState`, and neither the date nor any setting can move
> > *distinct units recorded since an instant* by one unit — so every midnight, every return to the
> > foreground and every theme toggle walked the entire log to arrive at the number already in hand.
> > On a Sonim at year seven that is ~3,000 events, a string allocation and a set insert each, on
> > resume, which is precisely the frame the user is watching.
> >
> > **Three tests said this was fine and each was answering a different question.**
> > `provider_notify_test.dart` asserts that re-deriving the backup status over unchanged data
> > notifies nobody — true, and the whole point of the finding above is that notifications were never
> > the cost. `notify_guard_test.dart` exempted this file from the no-whole-`SettingsState` rule on
> > the grounds that it "reads two of them and is itself watched through a `.select`" — but a
> > `.select` downstream stops the *rebuild*, not the *re-derivation*, and it was the re-derivation
> > that walked the log. And `log_pass_count_test.dart`'s own **"a midnight tick re-derives
> > everything and re-reads nothing"** held only because the setUp deliberately excluded the one
> > provider that re-read, in a comment calling both exclusions "one pass each and both honest". The
> > pass was honest. Its schedule was not.
> >
> > **The fix that was wrong first, which is the part worth keeping.** The obvious shape is to lift
> > the count into its own `Provider` and let Riverpod memoise it — memoising is what a provider *is*.
> > It broke the app, in exactly the way *What the sweep could not reach* describes two paragraphs
> > up: one derived provider between the dashboard and the log, and *drill in, mark a daf, come back*
> > throws `setState() during build` every time. `derived_flush_test.dart` caught it on the first
> > run, which is the second time that file has earned itself. So the memo went where it costs no
> > hop — a `Notifier` instance outlives its own `build()`, and the log arrives as a fresh list per
> > emission, so `identical` is a sound key for "the log I already counted". One hop, one pass per
> > log change, zero per tick, zero per setting.
> >
> > **And the count now includes it**: `log_pass_count_test.dart` grew a *the backup axis* group —
> > a tick costs zero, an unrelated setting costs zero, a log change costs exactly one — with the
> > first two watched to fail at 1.0 before the fix. Its clock override became a builder rather than
> > a value so a tick can be modelled by invalidating the *clock*; invalidating the provider under
> > test disposes its element, which would throw the memo away and measure a cold start.
> > `notify_guard_test.dart`'s allowlist is down to the one file that genuinely renders every field.
> >
> > **The other three were checked and are what the note says they are.** `batchHistoryProvider` and
> > the Notes Journal are one pass per log change and only while something is listening — a
> > kept-alive provider with no listeners is marked dirty and not recomputed, measured with the
> > counting log rather than assumed. The unit details sheet is the weakest of the three: it filters
> > the whole log per *build* rather than per change. It stays, because it is a modal for one unit
> > and the only log changes while it is open are the ones made from inside it.
> >
> > > **Then all four were priced, and the answer is that none of them is the problem.** "One pass"
> > > is a count, not a quantity, and the note above kept arguing in counts. Over a 3,000-event log —
> > > seven years of daf yomi, the number this whole finding is scaled to — the two mandatory indexes
> > > cost ~660µs (`FoldLog.fold`, which also sorts) and ~690µs (`LogActivity.of`). Against that, the
> > > backup axis is **28µs**, the batch grouping 25µs, one unit's history 27µs, and the journal's
> > > filter-and-sort 36µs. The third axis is **two percent** of the two it rides along with; all
> > > four together, with every screen that wants one open at once, are under a quarter of either
> > > index. There is no fix here worth the risk of making one. If a mark ever needs to get cheaper
> > > on a Sonim, the two indexes are where the milliseconds are, and the fold's sort is most of it.
> > >
> > > **Counted through the real app rather than argued: three passes per mark, and three is all
> > > there is.** `log_pass_screen_test.dart` is the companion to `log_pass_count_test.dart` and
> > > exists because that file chooses its own subscriptions — it says so in its setUp, and the two
> > > axes it leaves out are exactly the two this note is about. A user does not choose; the screen
> > > they are on does. So the log is handed to `ChovosHayomApp` itself: the dashboard costs the fold,
> > > the day index and the backup axis, once each, and **so does the unit grid**, which was the one
> > > thing here that came out differently from the guess. A grid on its own is one pass; pushing it
> > > over the dashboard does not pause what is underneath, and should not — that is the same
> > > `setState() during build` cliff `derived_flush_test.dart` guards, approached from the other
> > > side. Marking a daf costs three walks wherever you are standing.
> > >
> > > **And one sentence above is wrong, which is the reason to price things rather than reason about
> > > them.** *"The only log changes while it is open are the ones made from inside it"* is true and
> > > is not why the details sheet is cheap. It filters per *build*, and a build is not a log change:
> > > a rotation re-filters it, so does the keyboard a nested chazara sheet brings up, so does a
> > > calendar-mode write. Both are now expectations in the new file rather than a claim in a
> > > document. What makes it tolerable is the 27µs, and what keeps it small is the `.select` on the
> > > one settings field it reads — that is pinned too, because dropping it would turn every settings
> > > write into a full walk, which is the exact defect this whole note began with.

The single largest category by volume. Each row is one idea implemented more than once, in
places that cannot see each other:

| The one want | Times built | Worst consequence |
|---|---|---|
| ~~"which calendar day is this"~~ **✅ Resolved** | ~~**9 sites, 2 incompatible conventions**~~ — all nine migrated to `Day` (`lib/core/day.dart`); the four `_dayNumber` copies, `_dayKey`, `_localMidnight` and `_wholeDaysBetween` are gone, and `test/core/day_math_guard_test.dart` fails the build if the arithmetic reappears outside that file | ~~`Predictor.finishDate` returns a local `DateTime` that the other four would immediately re-ordinalize~~ — and worse: the local-midnight convention was outright wrong across a DST boundary, so five sites (not four) mis-counted one day a year. See the status note at the top |
| ~~distinct-units-learned-on-a-day~~ **✅ Resolved** | ~~3~~ — 2 live and 1 dead (`PaceEngine.unitsOn` had no caller); all now `LogActivity.unitsDoneByDay` | ~~`LogFold.doneAtByNode` already answers all three~~ — it does **not**, and building it that way would have rewritten the user's past on every un-mark. See the status note |
| ~~the pace scalar~~ **✅ Resolved** | ~~once per goal, per tick~~ — one `paceProvider`, and a `double` has real `==`, so an unchanged pace notifies no goal row at all | ~~N goals ⇒ N+1 identical full-log scans per rebuild~~ — measured at ten passes for ten goal rows; now zero |
| ~~per-meforish counts~~ **✅ Resolved** | ~~2~~ — `MefarshimStats.of(forest)` sums the roll-up the dashboard bars are drawn from | ~~same number, two derivations, no test pinning them together~~ — and they could genuinely disagree, on a node whose parent id points at nothing |
| ~~the log→numbers pass~~ **✅ Resolved** | ~~**5 passes in `statsProvider`**~~ — it now watches the two indexes and never the log; every answer is a map lookup | ~~`fold_log.dart:11-14` states the point of the fold was "five ordered passes where one will do"~~ — enforced now, at two passes, by `log_pass_count_test.dart` |
| ~~the date+time+duration+haara form~~ **✅ Resolved** | ~~2 full copies~~ — one `showLogUnitSheet` with an action's title, checklist label and save label passed in; `add_chazara_sheet.dart` deleted | ~~two ARB keys for one duration field~~ — and worse: the copy read the wall clock instead of `clockProvider` and had no session timer. See the note on finding 6 |
| ~~the meforish checkbox list~~ **✅ Resolved** | ~~3~~ — 3 checkbox lists over **4** hand-built answers to *which mefarshim does this unit have*: the checklist, *log with details*, *log a chazara*, and the Chazara screen's one-tap review. One `UnitMefarshim`, three named slices, one `MeforishChecklist` | ~~—~~ the empty column was the finding: the four answers **disagreed**, and the chazara sheet's could submit a layer with no checkbox in it. See the status note |
| ~~`nameOf` (layer name with deleted fallback)~~ **✅ Resolved** | ~~3, and **they disagree**~~ — one `layerById`/`layerNameById` in `naming.dart`; the mefarshim stat rows were a fourth, and also wrong | ~~same fix applied twice out of three~~ — the raw UUID was real and is now a test |
| ~~the catalog picker~~ **✅ Resolved** | ~~3~~ — **4**: the node editor's parent dropdown is one too, and it is the one that mattered. One `node_picker.dart`: `nodeChoices` decides which nodes and in what order, `showNodePicker` owns the clamp, `NodeDropdown` owns the indent | ~~—~~ the missing consequence: the fourth picker sorted by the **raw English** `name` and did not qualify, so a Hebrew reader picking a parent got a list ordered by strings not on their screen, with four rows reading "שבת". See the status note |
| ~~controller-owning dialog~~ **✅ Resolved** | ~~the shared `text_prompt.dart` + 2 hand-rolls~~ — the prompt takes a *list* of fields and a validator now, so both hand-rolls are gone and there is nothing left to hand-roll | ~~the bug it was written to end~~ — and the reason it was hand-rolled anyway: the shared file took **one field** and had nowhere to put a rejection. Both copies wanted two fields, and one of them wanted to say no. See the status note |
| ~~`requiredPerDay` rendering~~ **✅ Resolved** | ~~3~~ — 2 by the time it was reached (the third went with `goal_status.dart`), both writing `toStringAsFixed(2)` for themselves. One `requiredPerDayText` | ~~the Calculator's "By date" mode is a goal you can't save~~ — fixed by finding 6. What the duplication was *hiding* is the real one: both rounded **down**. See the status note |
| ~~the goal banner widget~~ **✅ Resolved** (carried by finding 6's work, and verified rather than assumed) | ~~2 byte-identical~~ — one `GoalBanner`, one `goalStatusText`, one `removeGoalWithUndo`, and `report_guard_test.dart` rule 2 refuses a second reader of `l10n.goalStatus` | ~~2 ARB keys for one sentence~~ — one now, and the *residue of that merge* is the row's real finding: the surviving key's metadata block was still called `@goalBanner`, so it described nothing and `goalStatus`'s three placeholders were re-inferred as `Object`. See the status note |
| "the four customisation lists" | 3 (`settings_screen:289`, `:390`, `backup_service:311`) | shipped a bug: `.asData?.value ?? const []` silently exporting empty lists |
| "is this a positive integer" | 3 layers each, for both interval settings | — |
| JSON parse per restore | 3–4 full decodes of the same file before anything is written | on a Sonim, with a Shas-sized log |
| profile deletion | 2 paths (`drift_progress_repository:120` for 6 tables, `providers.dart:141` for the goals key) | kept in sync by hand |
| ~~`DpadScroll`~~ **✅ Resolved** | ~~3 call sites — exactly the three report screens~~ — it was **4** by the time it was looked at, and merging the routes did not reduce it: the three sections kept their own copies and `ReportEmpty` had grown a fourth. One `ReportBody`, and a guard rule | ~~the tax for splitting one report into three routes~~ — the tax was never the routes. `skipTraversal: false` is a fact about the *tab bar*, and three sections were each asserting it locally |

**The change is not "deduplicate."** It is: for each row, build the thing that makes the second
copy impossible. A `core/day.dart` value type. One `LogEntryForm` parameterized by action and
seed. One `NodePicker`. One `paceProvider`. `BackupService.exportProfile` reading its own inputs
instead of taking four lists as parameters.
**The cost:** individually tiny, and `core/day.dart` is the cheapest fix in the repository — one
new file, four deletions, no behaviour change. Do that one first, this week.

---

### 6. Four report screens are Stats sections wearing routes. `delete`. **✅ Resolved**

> **The thesis held and the arithmetic did not.** Every line count is right to within seven lines
> (Calculator is 293, not 286), the four screens really do read the same providers, Goals really
> could not create the thing it listed, and *"the Calculator's 'By date' mode is a goal you can't
> save"* — a one-line aside in the inventory of finding 5 — turned out to be the most useful
> sentence in the finding. It is the reason the merge is worth doing rather than merely tidy: the
> two screens that compute `requiredPerDay` were three drawer rows apart and could not see each
> other, so the mode that works out the pace needed to finish by a date threw the answer away and
> sent you off to find the sefer and tap a flag. Saving it is four lines and was impossible while
> they were separate routes.
>
> **Where the prescription is arithmetically wrong: "two `DpadScroll` copies" out.** It is zero.
> `DpadScroll` wraps a scroll view, and a tabbed report has one scroll view per tab, so the three
> figure-only sections still each need one — they are in one folder now instead of three, which is
> not the same claim. The finding reasons about the workaround as though it were per *route*; it is
> per *scrollable*. Nothing else in the paragraph depends on this, but "~525 lines out" should be
> read the same way: the four files are ~548 lines and the five sections plus the shell are ~700,
> because the shell, the shared empty state and the shared goal rendering are real code that did not
> exist. What actually leaves is **five drawer rows for one**, four `Scaffold`s, five ARB titles and
> five nav strings, one of two `requiredPerDay` renderings, one of two goal sentences, one of two
> remove-with-undo flows, and — with the second half of the finding — 223 lines of chazara sheet.
> Fewer lines was never the point; fewer places for the same idea to live was.
>
> **And one claim has gone stale since it was written.** *"None of the four has a widget test of its
> own, which is exactly what makes the merge cheap"* was true on 2026-08-05 and stopped being true
> when finding 7 landed: `report_screens_test.dart` builds all four. That is better than what the
> finding wanted — the tests made the merge *safe* rather than cheap, and every one of them survived
> it with its assertions unchanged.
>
> **The second half was worse than reported, in the copy's favour.** `add_chazara_sheet.dart` is
> described as differing in "`EventAction.reviewed`, the seed set, and one ARB key". It also read
> `DateTime.now()` directly instead of `clockProvider` — the finding-1 defect, in a file no test
> could place in time — and had **no session timer**, on the one action in the app where timing what
> you are about to do is most of the point. The finding predicts the user *gains* the timer; it does
> not notice they had lost it. Its `nameOf` fallback was also dead: candidates were built from
> `allLayers`, so the deleted-meforish branch could not be reached.
>
> **What the sweep could not reach is that a tab bar is a second axis of navigation on a device
> that has one.** `DpadScroll` claims focus on arrival and turns up/down into scrolling, releasing
> the key at either end so focus can leave — so getting *out* of a section to the tabs worked
> already. Getting back in did not, and silently: the wrapper is `skipTraversal: true`, which makes
> it invisible to directional focus, and its `autofocus` only fires when nothing in the scope holds
> focus, which after a tab switch is false because the tab does. Reachable one way and not the
> other, which would have left four fifths of the report unreachable on the Sonim. `DpadScroll` grew
> a documented `skipTraversal` parameter; `keypad_test.dart` walks the round trip in both directions
> and was watched fail on the old shape.
>
> **The 240dp check earned itself on its first run.** Walking all five tabs at the Sonim's size
> found the Goals empty state overflowing its tab by 88 pixels — the message *and* the new button
> both below a fold that could not be scrolled. Three hand-rolled `Center` → `Padding(32)` → `Text`
> towers became one `ReportEmpty` that is centred while it fits and scrolls when it does not, which
> is the same shape the summary grid was rebuilt into after "the statistics screen looks very
> glitchy".
>
> Resolved by `lib/features/reports/` (`report_screen.dart` — the shell, the `ReportSection` enum
> and `ReportEmpty` — plus `overview_`, `calculator_`, `goals_`, `siyumim_` and
> `mefarshim_section.dart`), `lib/features/common/goal_status.dart` (one sentence, one colour, one
> icon, one remove-with-undo, and the `GoalBanner` the unit grid wears), and
> `layerById`/`layerNameById` in `naming.dart`, which closes the *`nameOf` × 3, and they disagree*
> row of finding 5 — `unit_details_sheet.dart:155` was printing a raw UUID into the chazara history
> for any meforish deleted since. `add_chazara_sheet.dart` is gone into `log_unit_sheet.dart`, which
> now holds the one form and its two actions; `unit_grid_screen.dart` gave up its copy of
> `logWithDetails` to the same file and its `_GoalBanner` to `goal_status.dart`, and its goal date
> now comes from `clockProvider` rather than the wall clock. Five ARB titles, five nav strings,
> `goalBanner`/`goalRowStatus`/`goalRowReached`/`goalRemoved` and `addChazaraDuration` deleted; the
> five route names kept, each mapping to a tab.
>
> **And the rule is enforced rather than stated.** `test/features/report_guard_test.dart` reads
> `lib/` and fails the build on a `Scaffold` inside `reports/` (a section that has become a route
> again), on the goal sentence rendered outside `goal_status.dart`, and on a second date-and-duration
> logging form — plus a plain existence check on the six deleted paths, because the cheapest way for
> this to come undone is a file reappearing. Each ban was fed a violation and watched catch it. 579
> tests pass; `analyze --fatal-infos` is clean.
>
> **Not done, and still true:** the *catalog picker × 3* row of finding 5. Goal creation deliberately
> reuses the Calculator's dropdown rather than adding a fourth copy, which is why the Goals tab sends
> you there instead of growing a picker — but `cycles_screen:332` and `edit_cycle_screen:237` still
> hold two more, with different clamps.

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
> real one, and the squash in finding 4 is now worth slightly more than it was. **It has since been
> collected**: deleting the twelve-step chain took the suite from 579 tests in ~2m03 to 571 in
> ~1m37, most of it the migration tests opening a real file per case.
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

### 8. The documentation is a fossil of the process that produced it. `delete`. **✅ Resolved**

> **The thesis held; three of the counts had rotted, and the one paragraph that was not about prose
> at all turned out to be the whole finding.** The markdown had grown to 3,033 lines while this sat
> — the fossil was still accreting. `UnitState` is right and understates itself: §2.2 specifies the
> table, §3's entity list names it, and §7 lists building it as a Phase 0 deliverable, so it is three
> places, not one. The roadmap contradiction is exact (§6 ends at five phases, the README's table at
> thirteen). Two counts are wrong: **seven** source files cite `ARCHITECTURE.md` by section, not
> eight — and *"states the test count three times and is wrong twice"* has been overtaken. It states
> it once now and 571 was correct on the day this was read. It is stated **zero** times now, because
> a hand-maintained number in prose has exactly one stable value.
>
> **Where the finding buries its own headline.** *"Two README paragraphs are not merely stale, they
> describe behaviour the code does not have"* is one paragraph inside a table of documents to delete,
> and it is the only unresolved **behavioural defect** left in this report. `ImportMode` reached the
> event log and the four repository tables and stopped; settings and goals live in preferences, are
> applied by the settings screen *after* `importInto` returns, and took no mode at all.
>
> **It breaks the promise in both directions, and the finding only names one of them.** The report
> has the `restoreEverything` half — goals set since the backup survive a restore that undertook to
> delete them. The other half is the destructive one and is not mentioned: a **merge** overwrote
> every setting in the profile with the file's. `cycles` serialises the entire list to one key, so
> merging a backup taken before a cycle was added *deleted that cycle* — in the mode whose whole
> promise is "remove nothing".
>
> **What the sweep could not reach is why the merge half is structural rather than careless.**
> `toBackup()` emits every key in `PrefKeys.perProfile` on every export, filling in the *effective*
> value — which for a profile that has never touched settings is simply the default. So the file
> names every key regardless of intent, and "apply what the file names" cannot mean anything else.
> The fix is not a branch on the file, it is reading intent off the **profile**: `clearAll` removes
> keys rather than writing default values, precisely so an unset key stays unset, which already makes
> "this profile stores a value for this key" the same question as "the learner has expressed a
> preference here". A merge fills in the ones they have not. Goals are the opposite and are left
> alone: a node is in that map only because somebody picked a date for it, so there naming *is* the
> intent, and imported-wins stays the right merge. The two maps look alike and are not, and a fix
> that treated them alike would have been wrong about one of them.
>
> **It is the residue of a three-round lineage, which is the finding's own thesis with a longer
> fuse.** `F4` in the 2026-07-29 grade, `F4` again on 2026-07-30, `W5` in the builder's report — each
> round found the gap between what the copy promised and what the restore did, and each fixed the
> layer it could see. `W5` is where `bool replace` became `ImportMode`; it covered the repository and
> did not know there was a second store. Three reviews, three partial fixes, and the reason none of
> them closed it is that no test asked the same question of every store at once.
>
> Resolved by threading the mode through `SettingsNotifier.applyBackup` and
> `GoalsController.applyBackup`; `GoalsController.goalsRemovedBy`, which the confirmation counts and
> the import deletes from, so the preview and the outcome are one function the way
> `_customisationsToRemove` already was; `RestoreDiff.goals` feeding the red button, because a dialog
> that counts sefarim alone looks harmless while deleting every date the learner is working towards;
> `applyBackup` returning what it deleted so the report says what happened rather than repeating the
> prediction; and four ARB strings — two reworded, two new, in both locales — including
> `settingsRestoreFileSubtitle`, whose *"settings are kept"* was **false when this was written** and
> is now true. That one was fixed by the code catching up to the prose rather than the reverse, which
> is the finding's own prescription taken literally.
>
> **And the rule is enforced rather than stated.** `test/application/import_scope_test.dart`
> enumerates the contract over `PrefKeys.perProfile` rather than spelling it out per key, asserting
> on the *stored string* rather than the parsed state so it needs to know nothing about what any key
> means — which is the only way it outlives the list it iterates. Five of its assertions were watched
> fail against the pre-fix behaviour before being kept. Its last test is the one that matters: the
> compiler already catches a *call site* that forgets the mode, so what it reads `lib/` for is the
> next store — a fourth thing a profile owns whose `applyBackup` never took a mode in the first
> place, which is silent, and is exactly how this one happened.
>
> **On the prose itself, one deliberate divergence.** `fixes.md`, both GRADEs and BUILD are deleted;
> the standards from `fixes.md:15-34` are `CONTRIBUTING.md`; the measurement lore is
> `docs/MEASURING.md` — larger than the ~55 lines costed, because GRADE-29's §2 has a mutation-test
> round and a deliberately-broken CI gate that are as unrecoverable as GRADE-30's dead oracles, and
> the deep-link and crash-log traps in BUILD §5 are the kind of thing that costs an afternoon twice.
> `ARCHITECTURE.md` loses §5–§9 and keeps §1–§4 and §10, renumbered to §5 with its one citation
> updated; §2.2 now documents the five tables that exist and says plainly that `UnitState` never did.
> **The README is 310 lines, not the ~120 costed**, and that is a disagreement rather than a
> shortfall: the finding is right that "What works today" is a changelog in release-note voice, and
> every sentence phrased *"it used to be broken"* is gone, but deleting the section outright leaves a
> README that never says what the product does. It is rewritten in present tense at a third the
> length. The import/restore semantics are a table there now, which is what the two lying paragraphs
> should have been all along.
>
> **Not done, and adjacent:** finding 9. `BackupValidator` is still 166 lines defending a door
> `catalog.dart:47` and `inherited_layer_roles.dart` already lock, and `importInto` still calls it on
> every path touched above. **✅ Since resolved**, and the door was not locked: two more walks had no
> guard, one of which never returns. See the note on finding 9.

2,801 lines of markdown outside the code — **3,033 by the time this was worked.**

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

### 9. The validator defends a door that three other doors already lock. `delete` (146 of 166 lines). **✅ Resolved**

> ### Both claims were checked by running them. The first is right, the second is wrong, and the prescription it leads to would have shipped a hang
>
> **Claim one holds, and it was measured rather than reasoned.** `RollUp` over a node with
> `unitCount: -5` returns `learned=0 total=-5` and throws nothing, exactly as the finding says. The
> justification written at `:398-403` was false on the day it was written.
>
> **But "it does not throw" is itself incomplete.** `unit_grid_screen.dart:145` passes `unitCount`
> straight to `GridView.builder` as its `itemCount`, which defaults `semanticChildCount` to the same
> value, and `ScrollView`'s constructor asserts on a negative one. The dashboard renders `0 / -5`;
> opening the sefer throws. The crash the finding correctly says does not exist had moved one screen
> over, and neither line of the report looks there.
>
> **Claim two is wrong, and this is the one that matters.** The two guards it names are real, but
> *"the downstream guards would have sufficed alone"* does not follow from two of them, and there are
> not three walks over the parent relation — there are **eight**. Six keep a visited-set.
> `naming.nodePath` is capped at depth 16. And two have nothing at all:
> `BulkHistoryScreen._commonAncestor` and `CatalogEditor.cloneStructure`. Both were run against a
> loop rather than argued about: the first **does not return** — a `while (current != null)` with a
> `chain.insert(0, …)` inside it, so it is a wedged process and a growing list, demonstrated by a
> test that had to be killed at 120 seconds — and the second dies with `StackOverflowError`. Deleting
> the cycle check as prescribed would have removed the only thing standing between a hand-edited
> backup and those two.
>
> **So the diagnosis is right and worse than stated, and the prescription is wrong.** *"Cycle
> detection now exists in three places with three theories of who is responsible"* is the finding's
> best sentence; the answer is not to delete one theory and leave seven. It is to make the shape
> unrepresentable in the thing all eight of them walk. `Catalog` now guarantees a forest: every
> parent link resolves, no node is its own ancestor, and a violating link is **detached** rather than
> the file refused — the node becomes a root, visible and re-fileable, where a dangling parent used
> to leave it in `byId`, in search results, and under no root at all, which is the one state there is
> no way out of from inside the app. A ring is cut at exactly one link, chosen as the lowest id so
> two devices restoring the same file agree.
>
> **That is wider than the check it retires**, which is the argument for doing it this way rather
> than adding a seventh and eighth visited-set: the validator only ever saw *imports*, and the node
> editor and the clone can build a loop with no file involved.
>
> **A defect the sweep could not have reached, found while proving the invariant.** `childrenOf` was
> built from the raw node list and `byId` from the same list keyed by id, so a repeated id put one
> row in the index and both in the child map — a walk up and a walk down then disagreed about who a
> node's parent was, and the downward one could loop over a pair the upward one considered fine. Both
> are now built from one de-duplicated index.
>
> **On the arithmetic, a disagreement.** *146 of 166 lines* is too many. Every remaining check was
> put in front of the running app before being kept or cut, and four of them earn their place on
> evidence: a repeated **event** id reaches `addEvents` and comes back as
> `SqliteException(1555): UNIQUE constraint failed` — a driver error shown to someone restoring a
> backup; a repeated **node or meforish** id is worse because it is silent, since the rows are
> written with `insertOnConflictUpdate` and the second replaces the first; a negative `unitCount`
> leaves a sefer permanently uncountable, because `containsUnit` is false for every index; and a
> negative duration is summed into the time statistics. The absurd-`unitCount` ceiling stays too — it
> is the only one with real teeth, since it bounds what a single *Finish all* enumerates. What went
> is 98 of the class's 156 lines: the cycle walk, the parent-resolution check, and the checks for an
> empty id, an empty name, a negative unit offset, a negative unit index, an empty layer list, more
> unit names than units, and the layer-config bounds — each of which is now a test asserting the data
> is *inert* rather than a deleted assertion, because "the file is refused" and "the app is safe"
> are different claims and this class was making the first while stating the second.
>
> **The finding misses the plumbing, which is the cheapest thing in it.** The deleted checks needed
> `knownParents` — a map of the entire bundled catalog, built by the settings screen and threaded
> through `importInto` on every import — for no purpose except giving the cycle walk something to
> walk. It is gone with them.
>
> Resolved by `Catalog._asForest` and a private index-taking constructor
> (`lib/domain/entities/catalog.dart`); `CatalogNode.copyWith` taking the same sentinel for
> `parentId` as its other nullable fields, since `parentId: null` means *make this a root* and a
> plain `??` cannot say it; `BackupValidator` down from 156 lines to 58; `knownParents` deleted from
> `importInto` and from `settings_screen.dart`; and the three comments that argued the old theory —
> in `catalog.dart`, `inherited_layer_roles.dart` and `naming.dart` — rewritten to say which of them
> now relies on the invariant and which does not. `InheritedLayerRoles` keeps its guard, and its
> reason is now one named call site rather than a general suspicion: the restore preview builds a
> parent map by hand, from a backup that has not been through a `Catalog`.
>
> **And the rule is enforced rather than stated.** `catalog_forest_test.dart` is the property over
> eleven adversarial shapes — self-loop, two- and three-node rings, a ring with a tail, two
> independent rings, a chain dangling into one, repeated ids, a repeated id looping against its own
> earlier row — asserting from every node that the chain terminates *and* that every node is reached
> exactly once walking down from the roots, which is the direction the clone takes. Eight of its
> twelve tests were watched fail against the old constructor. `catalog_forest_guard_test.dart` reads
> `lib/` and fails the build on `knownParents` returning or a second cycle check growing back, and
> was fed a violation rather than assumed to work. `cyclic_catalog_test.dart` is the end-to-end pair:
> it imports the loop the way a user would acquire one, then pumps the bulk history screen and calls
> the real `CatalogEditor` — the two walks that had no guard — because the old shape did not fail
> there, it failed to return, and a test that reasons about a walk cannot tell you the screen came
> back. 614 tests pass; `analyze --fatal-infos` is clean.
>
> **Not done, and still true:** `catalog_clone_test.dart` lifts `cloneStructure`'s `collect` walk out
> into the test file and asserts against the copy, which is why it could never have seen this. The
> new end-to-end test drives the real editor, so the behaviour is covered — but the duplicate is
> still sitting there, and it is finding 5's shape appearing in a test rather than in `lib/`.

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

### 10. Committed generated localizations. `delete` from git. **✅ Resolved**

> ### The headline was right and cheaply provable; the paragraph under *While you're in there* was carrying a live bug
>
> **The load-bearing claim was tested rather than believed.** *"`flutter gen-l10n` runs automatically
> on `flutter pub get`"* is the whole argument, and it is the kind of sentence that is true of some
> Flutter versions and not others. So `lib/l10n/generated` was deleted outright and `flutter pub get`
> run against the empty directory: all three files came back, byte-identical to the committed ones.
> The finding holds, on this toolchain, demonstrated.
>
> **Two numbers moved and one has flipped.** It is 12 commits touching the directory now, not 9 — and
> the ratio the finding rests on survived the growth exactly: **+8,253 generated against +1,715 ARB,
> 4.8×**, the same figure it quotes. But *"the generated table (8,015) outweighs all of `lib/features`
> (7,961)"* has stopped being true while the finding waited: 8,064 against 8,172. The rhetorical
> flourish expired; the argument under it did not need it.
>
> **The best evidence for the finding was already written in the file it indicts.** The CI step's own
> comment reads *"`flutter pub get` runs gen-l10n already; this proves the committed output matches
> the .arb it claims to come from"* — which concedes, in the course of justifying itself, that the
> only thing it can catch is a mismatch that `pub get` would have prevented. `l10n.yaml`'s comment
> argues the same circle from the other end. This is the document's own thesis again: the reasoning
> was correct, was written down, and nothing made it fail.
>
> **The five dead keys were all five dead — and one of them was dead for the opposite reason.**
> Confirmed against `lib/` *and* `test/`. Four (`addNodeHebrewName`, `addNodeNeedName`, `errorTitle`,
> `mefarshimHebrewOptional`) are leftovers of de-duplications that reached the call sites and not the
> string table; they are deleted. `dateTimeLabel` is the one the finding lists in the same breath and
> should not have: it is unused *because a screen was building the string by hand instead*, which is
> row 6 of *The claim*. Following it found something neither line predicts. `log_unit_sheet`'s private
> `_dateTimeLabel` formatted `yyyy-MM-dd · HH:mm` itself — so the one screen in the app where you
> *choose* a date was the only screen that ignored the Hebrew calendar setting, confirming a mark
> with a Gregorian date that every other surface would then render as a Hebrew one. It is a fourth
> copy of `DateDisplay.formatWithTime`, and a wrong one. Gone; the sheet reads the setting like
> everything else.
>
> **On `cycleDafHebrew`, half the finding is wrong and the half that lands is worse than it says.**
> *"An English reader gets a Hebrew line"* is not a defect — the key's own `@description` says
> *"Kept Hebrew in every locale — it is the daf's own name"*, and for a Daf Yomi row that is a
> feature, which the finding would have seen by reading two lines further. *"A Hebrew reader gets it
> twice"* is right, and the reason is a fossil of exactly the kind this document is about:
> `naming.dart`'s doc comment states that Hebrew names *"includes the whole bundled catalog today"*
> as the set of nodes lacking one. All 312 carry a `nameHebrew`. The comment described the data at
> the moment it was written, the data changed, and the duplicate line is what that costs.
>
> **The defect the finding did not name is the one worth a test.** `"{sefer} · דף {unit}"` was stored
> *identically* in both `.arb` files. Present in both, so the untranslated-locale gate — the check
> this document rightly calls the genuinely valuable one — certifies it as translated. Identical in
> both, so it is not a translation at all but one Hebrew literal kept in two files that must never
> diverge, spelling `דף` beside the `unitLabelDaf` in `app_he.arb` that already spells it, and
> copying `nodeAndUnit`'s separator along with it. The line is now composed out of the Hebrew table
> (`hebrewDafLine`), so every word in it has one definition and it is the one the Hebrew UI is built
> from — and it renders only when the heading above is not already saying the same three words.
>
> **And the rule is enforced rather than stated.** `test/l10n/arb_guard_test.dart`: every key in the
> template is read by something in `lib/`, and no key is its own translation. The second rule is the
> interesting one, and **the obvious version of it is wrong** — "no Hebrew in `app_en.arb`" would
> reject `settingsLanguage` (`"Hebrew (עברית)"`, which is what every language picker does) and the
> two siyum strings that end English sentences in `חזק!` and `יישר כח!` because that is how the
> people who use this app end them. Those are English strings with different Hebrew translations. The
> defect is not the script; it is a template entry and its translation being the same bytes. Run
> against the 540-key pair, that rule fires on exactly one key and no others. Both rules carry
> negative controls, and the regexes are asserted to still match their own samples — the failure mode
> of every source-scanning check ever written. `cycles_screen_test.dart` is new (the screen had none)
> and its middle test was watched to fail on the pre-fix rendering before it was kept.
>
> **Where the finding oversells itself is the plural paragraph, and this one is a disagreement rather
> than a correction.** All 35 plural messages (33 when it was written) really do use `=1{…}
> other{…}`, and the conclusion drawn from that — that the ARB apparatus ships *"the same
> expressiveness under heavier syntax"* — does not follow. Modern Hebrew takes the regular plural
> after a numeral: `2 יחידות` is what `bulkConfirmUnits` should render for 2 and is what it renders,
> and CLDR's `two` category is for the forms you write *without* a digit in front. The apparatus is
> unexercised because both shipped locales agree, not because it is decorative — and because the
> plural cases live per-locale in each `.arb`, a translator who does want a `two{}` can add one to
> `app_he.arb` alone, with no Dart change and nothing to keep in sync. That is the lever
> `'$verb $n unit(s)'` did not have. Left as it is, deliberately.
>
> Resolved by untracking `lib/l10n/generated/`, gitignoring it with the reasoning beside the entry,
> dropping the diff step from CI while keeping the untranslated gate (now re-running gen-l10n
> explicitly, so the report it reads is produced by a command in the workflow rather than a side
> effect of `pub get`), rewriting the two comments that argued the opposite in `l10n.yaml` and
> `.gitignore`, deleting five ARB keys from both locales, `DateDisplay.formatWithTime` in the log
> sheet, `hebrewDafLine`/`nameIsHebrew` in `naming.dart`, and the two test files above. 592 tests
> green, analyzer clean at `--fatal-infos`, `l10n_untranslated.json` still `{}`.

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
4. ~~Squash the schema to v1 **before** the first release, because after it this stops being free.~~
   **✅ Done** — and it cost less than the finding priced it at, not more: no backup round trip was
   needed, because a database at the head of the chain is already the shape `createAll()` produces
   at v1. What the finding could not see is that the one database it is about was not at head — the
   Windows file here was still v11 — so the chain was run one last time before it was deleted. See
   the status note on finding 4.
5. ~~Collapse required/offered to one `role` column — same deadline, same reason.~~ **✅ Done** —
   and not to a `role` column, which keeps two sets. To one role *map*, which is what this
   document's own diagnosis of finding 3 asks for; the fourth state is now unrepresentable rather
   than repaired. Schema v12, backup format v5, one resolver where there were three.
6. ~~Delete the in-memory repository fake; spend it on the seven unpumped screens.~~ **✅ Done** —
   and the fake was hiding a live bug: sub-second timestamps were being discarded at rest, so a
   mark and an un-mark in the same second were ordered by their random UUIDs. Schema v13. See the
   status note on finding 7 for that, for the eleven one-shot reads dressed as live queries, and
   for what the finding got stale about.
7. ~~Merge the four report screens into a tabbed Stats.~~ **✅ Done** — five tabs, not four
   sections, since Statistics is one of them; the five route names kept and mapped to tabs; the
   drawer down from twelve rows to eight. It was not the `~525 lines out` the finding costs it at
   (see the note), and the win it did not predict is that the Calculator's *By date* answer can now
   be saved as a goal — which is what it had been computing all along.
8. ~~Delete `fixes.md`, both GRADEs and BUILD (carving ~55 lines of measurement lore into
   `docs/MEASURING.md`); cut the README to ~120 lines and `ARCHITECTURE.md` to §10.~~ **✅ Done** —
   and the carve-out is ~130 lines rather than ~55, because GRADE-29's §2 holds a mutation-test
   round and a deliberately-broken CI gate that are as unrecoverable as GRADE-30's dead oracles.
   The standards buried at `fixes.md:15` are `CONTRIBUTING.md`. The README is 310 lines and the
   argument for that is in the note. What this item does not say, and is the reason it was worth
   more than a tidy-up, is that finding 8 contains the only live behavioural defect left in this
   document: `ImportMode` reached one of the two stores a profile lives in.

---

## What I don't know

- **Is there a second user?** Most of what I called over-built — profiles, four import modes,
  per-node mefarshim configuration — is defensible if someone other than the author is going to
  use this, and much less so if not. Every verdict above assumes the README's framing: one person's
  learning, on one device.
- **Is there a release date?** ~~Findings 4 and 3 are cheap now and expensive the day after v1 ships.~~
  Both are done, so the question has stopped being urgent — but it was the right question, and the
  answer to finding 4 is now *the day after v1 ships is when the schema starts having a history
  again*.
  That's a scheduling question, not a design one, and it's yours.
- **What is being built next?** Half of what makes a design wrong is the change it is about to face,
  and that isn't in the repo. If the next thing is a second locale, finding 10 changes shape. If it
  is a sync or backup service, finding 2 (equality) becomes urgent rather than merely correct. If it
  is nothing — if this is done — then findings 5, 8 and 11 are the only ones worth the time.
