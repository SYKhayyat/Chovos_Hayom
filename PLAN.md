# PLAN — Chovos_Hayom (closest to release; work top to bottom)

Worker loop: top unchecked item only, fix + widget/unit test, commit, check off, stop.
Done (closed): #1, #2, #3, #4, #5, #6?, #7, #8, #9, #10, #11, #12, #13, #14, #15, #16, #17, #18, #19, #20, #21, #22, #23, #29, #30, #47. (#6 epic tracker stays open as index.)

## Phase 1 — Release blockers (the 1 High + correctness Mediums)
- [x] #33 derive_cost wall-clock guard still flaky: healthy and regression costs too close to separate by timing. (Medium)
- [x] #29 planner week view anchored to the 1st of the month, not the current week. (Medium)
- [x] #30 planner week list shows a raw ISO date, bypassing DateDisplay/Hebrew labels. (Medium)
- [x] #23 flaky wall-clock budget in derive_cost_test fails under suite load → CI red for no reason. (Medium)
- [x] #18 bulk finish/clear unchunked single txn → chunk/stream (ANR/OOM). (High)
- [x] #13 requiredPerDay off-by-one vs finishDate. (Medium)
- [x] #14 partial un-mark diverges details vs fold. (Medium)
- [x] #15 date pickers forbid today. (Medium)

## Phase 2 — Polish Mediums/Lows
- [x] #20 journal tiebreak.
- [x] #5 coverage (edit_cycle_screen 1.4% first).

## Phase 3 — Planner roadmap (in dependency order, after release) — COMPLETE
- [x] #7 Phase 2 today-goals screen.
- [x] #8 Phase 3 calendar.
- [x] #11 Phase 5 rescheduling.
- [x] #12 Phase 6 siyumim events. (#10 P1 + #9 P4 landed.)

## Phase 4 — Customizable schedule (the plan as a first-class, editable entity)
Amounts, overrides and spillover. Requested as: set an amount per day; make any
weekday or any single date different (a day off is just an amount of 0, not a
flag); decide per plan whether a shortfall rolls forward or slides the schedule;
flow on to the next sefer (Yoma → Sukkah → Chagigah → Moed); browse the calendar
day by day, week by week, month by month; and set any of it up in English or
Hebrew dates. Land in order.
- [x] #24 per-day amounts + weekday/date overrides (day-off = amount 0). (High)
- [x] #25 spillover modes: ignore / catch-up / slide, per plan. (High)
- [x] #26 item sequence, where-you-are-holding, siyum projection. (High)
- [x] #27 plan editing UI — split into #34 + #35.
- [x] #34 plan editing 1/2: plans list screen, create/edit, recurrence rule editor. (High)
- [x] #35 plan editing 2/2: weekday + date overrides, item sequence — SHIPPED, sequence tests outstanding.
- [x] #37 no test timeout: one hanging test wedged the whole run. (High)
- [x] #36 item-sequence half of #35 has no widget coverage. (Medium)
- [x] #31 calendar day/week/month ranges, browsable by continuous scroll. (Medium)
- [x] #32 enter dates in English or Hebrew (parsing + shared date input). (Medium)
- [x] #28 show/edit each day's amount in the calendar; check a day off from it. (Medium)
  (#31 gave it a day view; #32 lets the date being set be typed, in either
  calendar, from the plan editor's date overrides)

## Phase 6 — The plan as a real entity, and the day ledger (High)

(Phase **6**, not 5: the planner roadmap's epic items carry their own
sub-numbering, and `- [x] #11 Phase 5 rescheduling` up in Phase 3 already owns
the name "Phase 5". Two different schemes now claimed it, and a reader scanning
for the new work found the old, checked, finished one.)

Designed in full before any of it is built. The calendar **UI does not change**;
what changes is what a plan is, and the rest are consequences. Nobody is using
the app yet, so there is **no migration work** on any of this — the migration
instinct that governs the rest of this file is pure cost here.

Start at the top: the rest are inexpressible without it. **#41 landed** — with
one ruling that shaped it and one consequence worth knowing before #42:

- A **wrapping range is infinite, so a plan has no lap counter and no "remaining"**.
  `PlanRunProgress.totalUnits` returns **null** (not zero) for such a plan, and
  the plan screen shows a bare count. Only a finite plan can be a fraction.
- The **position** — first unit not done, or the range's start again when they
  are all done — is the **calendar's** to show (#42), not the plan screen's.
- **#42 answered the `planId` question this line used to leave open.** A tick
  carries the plan it was made for and the day; a null plan id means "made in
  the unit grid", which is what keeps the two screens independent.

- [x] #41 the plan as a real entity: sefer chain, per-sefer unit range, start
  date (default today), wrap (two levels) and exactly one pacing mode. (High)
- [x] #42 the day ledger: per-unit checkboxes in the day sheet, one shared state.
  Ticking from the calendar writes the log; ticking from the unit grid shows on
  the plan but **never erases it** — the plan is what was asked, the log is what
  happened, and the gap between them is the point. (High)
  Landed with the **event carrying the plan and day it was made for** (a
  `planId`, null meaning "made in the grid"), which is what lets the two screens
  stay independent instead of one having to know about the other.
- [x] #43 `+` and `−` on a day: add units, remove a unit, or skip the plan that
  day. Planning commands; write no log; reflow nothing. Past days behave like any
  other day. (High)
  A **skip** is distinct from an amount of `0`: a zero says the plan was
  scheduled and asked for nothing, a skip says it had nothing to do there, and
  only the first leaves an answer for the day. A standalone `+` creates a real
  (tiny) plan, because the ledger reads the plan and a day with no plan has no
  row to tick.
- [x] #44 recompute: pick a plan and a day, then either keep the same amounts or
  spread the shortfall over the next *x* days (*x* = a number, all, or up to the
  plan's end). Two modes only — a plan is editable, so a different finish date
  needs no third. Invoked from the day sheet **and** the plan screen. (High)
  A reflow **moves the plan's finish date** when the spread pushes past it, and
  says so: everything is customizable, so a reflow that could not honour the
  plan's own constraint would not be a reflow. It writes no events and touches
  no other plan — both are structural, not guarded.
- [x] #45 chazara is one rule — learned means chazara, the count is the passes.
  Delete the scheduler and the Chazara screen; **wipe** the stored review dates.
  Marking a unit done from the calendar is what makes it chazara. (High)
  Shipped: `LogFold.chazaraCount` derives passes as reviews + 1, so the count is
  a fold over the log and **nothing about a review is stored** — there were no
  stored review dates to wipe, which is the point. The scheduler, the screen,
  the `/chazara` route and the interval setting are gone; the drawer row reports
  units passed more than once. **The destination was #46's job** and is now
  filled: a `Chazara` tab on the report screen, which the row opens.
- [x] #46 progress bar and box: a completion line and a chazara line (units
  reviewed at least once), sometimes more than one chazara line; `due` comes out;
  the bar gets a colour; when a hairline will not fit the line changes colour
  instead; the box carries a corner number of times finished. (Medium)
  Shipped: `RoundsBar` draws one line per **round** — learned, then gone back
  to once, twice — each its own colour and thinning as the stack grows, capped at
  three lines with a `+n` marker for deeper rounds rather than a bar that quietly
  under-reports. A line with nothing on it is **not drawn**: an empty second line
  reads as "you are behind" when it means the opposite. Only fully-learned dafim
  count, so a daf with 2 of 3 meforishim is on no line. The box shows a bare
  `2`/`3` from two passes up (the `1` on every learned box would be noise), which
  is passes rather than reviews so it agrees with the sefer's lines. `due` is gone
  from the bar, having gone with the scheduler in #45.
- [x] #47 a screen per plan: how far it has got and how much per day you are
  actually doing. An open-ended plan reports a bare count, never a fraction.
  Also the home of recompute. (Medium)
  Shipped: `Routes.plan` (`/planner/plans/view/<id>`) opens `PlanScreen`, and the
  plans list's tap opens **this** rather than the editor — tapping a plan's name
  is a request to see the plan, and the screen has its own edit button. Two
  rulings the issue left open, both settled here:
  - **The rate is per day the plan *asked for*, not per calendar day.** A plan
    that fires only on Shabbos and asks ten a Shabbos, kept up on perfectly,
    divides by its *active* days; divided by calendar days it reports 10 ÷ 7
    against an asked 10 and reads as running at a seventh of speed. A deliberate
    day off (an amount of `0`) is in neither side. This is the one number on the
    screen that could mis-report a perfectly on-pace plan, so the denominator is
    the days the plan actually asked on.
  - **Both windows are shown, each named with the days it covers** — the
    whole-plan average (`since <date>`) and the recent seven. A whole-plan
    average hides a plan that started well and stopped; a recent window is noisy
    on a young plan; each is the other's cure, so the screen shows both and names
    the window behind each. `since` is the plan's own start date when it has one,
    and the first day worked otherwise — `startDay` null means *today*, and a rate
    averaged over one unfinished day is not a rate.
  `asOf` is **excluded** from the window, which is deliberately the opposite of
  what `Recompute.shortfallAsOf` does with the same day: a shortfall wants that
  day's work counted, a rate averaged over a partly-finished day is depressed by
  work *not yet done* rather than work *not done*. Both reasons are written where
  they are applied.
  **Two fixes at the root, both needed before the screen could be honest:**
  - `PlanRange.rangesOf` is now **the one answer to "what does this plan
    cover?"** — the item sequence, or the assignment targets when it has no
    sequence, which is the fallback `PlanProgress` already made. `totalUnits`,
    `doneUnits` and `unitInRange` all read it, so an index means the same thing
    everywhere and a deleted node leaves a hole rather than sliding the chain
    down one. Until this, a plan with no sequence reported **no total and zero
    done** — read as "infinite with nothing done" when all it was was a plan with
    no sefer named on it, which is the shape the plan editor makes. `DayLedger`
    reads it too, so the day sheet's ledger now has rows for such a plan instead
    of none.
  - `totalUnits`'s null is now read as *three* states — no end, wraps, names
    nothing — via `PlanStanding.coversNothing`. A plan that names a sefer and has
    simply not been worked on yet is a **fourth** state, and conflating it with
    the third told a user who set a plan up yesterday to add a sefer they had
    already added.
  The reflow sheet moved out of `calendar_screen.dart` into
  `planner/reflow_sheet.dart` so the day sheet and the plan screen share one
  implementation rather than two that could each lose a remainder.
- [x] #48 the day sheet's layout is a setting in Settings, with three layouts;
  default is grouped by plan, the only one readable when several plans fire. (Low)
  Shipped: `DaySheetLayout` (`byPlan` / `flat` / `collapsed`) in `core/calendar.dart`
  beside `CalendarMode` — `application/settings.dart` has to hold it, which a
  widget file cannot do. One pref key, per-profile, in the backup.
  **The setting changes only how the day's *work* is listed.** The per-plan amount
  rows, the `+`/`−` commands and the reflow are the same in all three, because
  they are facts about a plan and about the day rather than about how the units
  read — a layout switch that also moved the buttons would be three settings to
  learn rather than one. Each layout is asserted to keep the rest.
  Two rulings worth writing down:
  - **The reflow sits inside a collapsed plan's expansion.** It is something you
    do *to one plan*, and the layout exists for a day with many plans and little
    interest in most of them. Opening the plan you mean is the price of the
    compact view, paid only on the plan it applies to.
  - **The count is on the collapsed line even while collapsed.** A glance still
    has to say whether anything is outstanding — that is the whole reason to pick
    this layout rather than to scroll.
  The sheet was inline in `calendar_screen.dart` and is now `DaySheet` in its own
  file: three copies of a sheet that edits plans, writes to the log and offers a
  reflow are three chances for them to disagree about what a day is. The
  `+`/`−` helpers moved **verbatim** — the first attempt at a rewrite silently
  turned two buttons into one-per-plan and lost the node picker behind "start a
  new plan", which is the kind of change that reads as a refactor and is a
  feature removal.
  The golden harness now loads the **full** `MaterialIcons` font from
  `bin/cache/artifacts` rather than the engine's `font_subset/fixtures` subset
  (~1000 glyphs of several thousand), which was rendering every icon outside that
  subset as a notdef box — in a golden, indistinguishable from a broken app.

## Phase 7 — what a plan says about *how often* (new scope)

Filed from the #41 session. A plan now says **what** to work through and **when**
(#41's chain, unit range, start date, pacing); these are the next two questions
about the same object. **After Phase 6** — nothing in it is blocked, and nothing
in it blocks anything there.

- [ ] #50 a plan says how many times: "do this N times a day" (not merely "N
  units"), and a plan can ask to be **reviewed** — everything planned in the last
  *y* days — on a fixed date, every *x* days, or a day of the week. (Medium)
  Needs a ruling on whether "three times a day" is a counter separate from
  chazara; #45 owns that answer, so land after it.

Also open, from the same session and not planner scope:

- [ ] #49 device harness: 26 of 30 journeys still fail on wrong selectors; the
  D-pad path has never run at all. (High — the Sonim has no touchscreen)
- [ ] #39 Linux target aborts on first frame on NixOS: `eglInitialize` fails
  0x3010. Build is green; runtime is not. (Medium)

## Routing rule for new issues
Any AI opening an issue here MUST insert it above: data-loss/correctness → Phase 1, polish → Phase 2, new planner scope → Phase 4. Never let roadmap outrank a High. See AI_ISSUE_ROUTING.md.
