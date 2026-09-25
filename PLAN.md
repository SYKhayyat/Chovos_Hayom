# PLAN — Chovos_Hayom (closest to release; work top to bottom)

Worker loop: top unchecked item only, fix + widget/unit test, commit, check off, stop.
Done (closed): #1, #2, #3, #4, #6?, #9, #10, #16, #17, #19, #21, #22. (#6 epic tracker stays open as index.)

## Phase 1 — Release blockers (the 1 High + correctness Mediums)
- [x] #18 bulk finish/clear unchunked single txn → chunk/stream (ANR/OOM). (High)
- [x] #13 requiredPerDay off-by-one vs finishDate. (Medium)
- [x] #14 partial un-mark diverges details vs fold. (Medium)
- [x] #15 date pickers forbid today. (Medium)

## Phase 2 — Polish Mediums/Lows
- [x] #20 journal tiebreak.
- [ ] #5 coverage (edit_cycle_screen 1.4% first).

## Phase 3 — Planner roadmap (in dependency order, after release)
- [ ] #7 Phase 2 today-goals screen → #8 Phase 3 calendar → #11 Phase 5 rescheduling → #12 Phase 6 siyumim events. (#10 P1 + #9 P4 landed.)

## Routing rule for new issues
Any AI opening an issue here MUST insert it above: data-loss/correctness → Phase 1, polish → Phase 2, new planner scope → Phase 3. Never let roadmap outrank a High. See AI_ISSUE_ROUTING.md.
