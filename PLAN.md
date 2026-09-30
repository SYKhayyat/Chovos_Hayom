# PLAN — Chovos_Hayom (closest to release; work top to bottom)

Worker loop: top unchecked item only, fix + widget/unit test, commit, check off, stop.
Done (closed): #1, #2, #3, #4, #5, #6?, #7, #8, #9, #10, #11, #12, #13, #14, #15, #16, #17, #18, #19, #20, #21, #22, #23, #29, #30. (#6 epic tracker stays open as index.)

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
- `LearningEvent` still carries **no `planId`**. Where two plans overlap, a tick
  is attributable to neither. #42 is where that has to be decided.

- [x] #41 the plan as a real entity: sefer chain, per-sefer unit range, start
  date (default today), wrap (two levels) and exactly one pacing mode. (High)
- [ ] #42 the day ledger: per-unit checkboxes in the day sheet, one shared state.
  Ticking from the calendar writes the log; ticking from the unit grid shows on
  the plan but **never erases it** — the plan is what was asked, the log is what
  happened, and the gap between them is the point. (High)
- [ ] #43 `+` and `−` on a day: add units, remove a unit, or skip the plan that
  day. Planning commands; write no log; reflow nothing. Past days behave like any
  other day. (High)
- [ ] #44 recompute: pick a plan and a day, then either keep the same amounts or
  spread the shortfall over the next *x* days (*x* = a number, all, or up to the
  plan's end). Two modes only — a plan is editable, so a different finish date
  needs no third. Invoked from the day sheet **and** the plan screen. (High)
- [ ] #45 chazara is one rule — learned means chazara, the count is the passes.
  Delete the scheduler and the Chazara screen; **wipe** the stored review dates.
  Marking a unit done from the calendar is what makes it chazara. (High)
- [ ] #46 progress bar and box: a completion line and a chazara line (units
  reviewed at least once), sometimes more than one chazara line; `due` comes out;
  the bar gets a colour; when a hairline will not fit the line changes colour
  instead; the box carries a corner number of times finished. (Medium)
- [ ] #47 a screen per plan: how far it has got and how much per day you are
  actually doing. An open-ended plan reports a bare count, never a fraction.
  Also the home of recompute. (Medium)
- [ ] #48 the day sheet's layout is a setting in Settings, with three layouts;
  default is grouped by plan, the only one readable when several plans fire. (Low)

Also open, from the same session and not planner scope:

- [ ] #49 device harness: 26 of 30 journeys still fail on wrong selectors; the
  D-pad path has never run at all. (High — the Sonim has no touchscreen)
- [ ] #39 Linux target aborts on first frame on NixOS: `eglInitialize` fails
  0x3010. Build is green; runtime is not. (Medium)

## Routing rule for new issues
Any AI opening an issue here MUST insert it above: data-loss/correctness → Phase 1, polish → Phase 2, new planner scope → Phase 4. Never let roadmap outrank a High. See AI_ISSUE_ROUTING.md.
