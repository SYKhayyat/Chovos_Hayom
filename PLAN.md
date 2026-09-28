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
- [ ] #34 plan editing 1/2: plans list screen, create/edit, recurrence rule editor. (High)
- [ ] #35 plan editing 2/2: weekday + date overrides, item sequence. (High)
- [ ] #31 calendar day/week/month ranges, browsable by continuous scroll. (Medium)
- [ ] #32 enter dates in English or Hebrew (parsing + shared date input). (Medium)
- [ ] #28 show/edit each day's amount in the calendar; check a day off from it. (Medium)
  (needs #31 for a day view and #32 to name the date being set)

## Routing rule for new issues
Any AI opening an issue here MUST insert it above: data-loss/correctness → Phase 1, polish → Phase 2, new planner scope → Phase 4. Never let roadmap outrank a High. See AI_ISSUE_ROUTING.md.
