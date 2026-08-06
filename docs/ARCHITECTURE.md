# Chovos Hayom — Architecture & Phase 0 Plan

> Total rewrite in Flutter. Clean slate: legacy Java/SharedPreferences app deleted (lives in git
> history / GitHub). Stack: **Flutter + Dart · Riverpod (codegen) · Drift (SQLite)**. v1 targets
> **Android + Windows**; code kept portable for macOS/Linux/iOS later.
>
> Guiding constraints (from product owner): **modular, easy to extend, highly configurable,
> feature-rich.** These are treated as first-class architectural requirements — see §10.

---

## 1. The core idea

The legacy app's original sin: it stored an **aggregate count** (`learned`) as the source of truth
and treated the granular per-unit list as throwaway. That is the root of every desync and
`learned > total` bug, and it made history/charts impossible (no timestamps existed anywhere).

The rewrite inverts this. **The source of truth is an append-only event log. Everything else is
derived.** This single decision delivers, for free: single-source-of-truth, undo/redo,
export/import, history/heatmaps/pace, and prediction-from-actual-pace.

Two things are kept strictly separate (the legacy code fatally conflated them):

- **Catalog** — immutable reference data. *What exists in Torah.* Seeded from a JSON asset.
- **Progress** — per-profile mutable data. *What this user learned, and when.* An event log.

---

## 2. Data model

### 2.1 Catalog (immutable, versioned, seeded from `assets/catalog/*.json`)

```
CatalogNode
  id           String   stable slug, e.g. "shas.moed.shabbos"   (PK)
  parentId     String?  null at root
  name         String   display name (English)
  nameHebrew   String?  Hebrew display name (for RTL / Hebrew UI)
  sortOrder    int      default order among siblings
  kind         enum     category | sefer | leaf
  # leaf-only unit definition:
  unitLabel    enum?    perek | daf | amud | siman | halacha | page | custom
  unitCount    int      number of atomic units (ALWAYS integer)
  unitOffset   int      first unit index (e.g. 2 for a gemara starting daf ב)
```

- Leaves are the only nodes with enumerable units. Categories/sefarim aggregate their children.
- **DECIDED — irregular units:** units are **always integers**. A mesechta ending on a single amud,
  or any half-unit, is **counted as a full unit** (round up). No `double` counts anywhere — this
  kills the legacy half-daf `double` math outright.
- Catalog ships with a `catalogVersion`. Corpus corrections bump the version; a lightweight
  reconciler updates the cached copy without touching user progress (progress refers to nodes by
  stable `id`).

### 2.2 Progress (per profile, in Drift)

```
Profile
  id           String  (PK)
  name         String
  createdAt    DateTime

  -- No settings column. A profile's preferences (calendar, theme, RTL, sort,
  -- chazara intervals, meforish bars, cycles) live in AppPreferences under
  -- profile-scoped keys, because the theme must be readable synchronously
  -- before the first frame — long before this database is open. The schema
  -- did carry a `settingsJson` column that nothing ever read; it was dropped
  -- in schema v10 rather than left as a false affordance.

LearningEvent            -- append-only; NEVER updated or deleted in normal use
  id           String  (PK, uuid)
  profileId    String  (FK)
  nodeId       String  (catalog or custom leaf id)
  unitIndex    int      which specific perek/daf
  action       enum     done | undone | reviewed   (reviewed = chazara pass)
  occurredAt   DateTime WHEN it was learned (defaults to now unless user sets it)
  loggedAt     DateTime WHEN it was recorded (always now)
  durationMin  int?     optional session length
  note         String?
  tagsJson     String?  optional labels (chavrusa, location, "with Rashi", ...)

CustomNode               -- user-defined sefarim/categories; same shape as CatalogNode,
  ...                       profile-scoped and editable. USER SUPPLIES unit counts/labels
                            (no bundled catalog exists for custom content).

UnitState                -- MATERIALIZED VIEW / cache, fully rebuildable from the log
  profileId, nodeId, unitIndex, isDone, reviewCount, lastEventId
```

Rules:
- `occurredAt` auto-fills to `now()` **only if the user didn't supply a date/time** (your spec).
- `loggedAt` is always `now()`.
- Aggregate `learned` / percentages are **never stored** — they are folds over `UnitState`.
  `learned > total` is structurally impossible.
- Undo = append an inverse event (or truncate the tail); redo = replay. Export = dump the log.
- **Custom sources:** when a user creates a custom sefer/category, *they* fill in the unit label and
  count. Same schema as the bundled catalog, so every feature works on it identically.

---

## 3. Layers (clean architecture)

```
lib/
  app/             the route table: every screen addressable by name, ids in the path
  core/            cross-cutting: settings registry, DI, result/error types, date/calendar utils
                     - day.dart       Day: a calendar day as a whole-day count. The single
                                      answer to "which calendar day is this" — see the
                                      dependency-rule note below
                     - calendar.dart  DateDisplay: formatting a date for a human, Gregorian
                                      or Hebrew. Presentation only
  domain/          pure Dart. NO Flutter, NO Drift imports.
    entities/         CatalogNode, LearningEvent, Profile, UnitState, Progress, Goal, Cycle
    repositories/     abstract interfaces (CatalogRepository, ProgressRepository, ...)
    usecases/         pure functions/services:
                        - FoldLog        (events -> UnitState set, incl. review counts)
                        - RollUp         (leaf progress -> parent aggregates over the tree)
                        - LogActivity    (log -> indexed by calendar day: units learned per
                                          day, minutes per day, what was recorded when.
                                          Pace, streaks and the heatmap are lookups on it)
                        - Predictor      (bidirectional: pace->date  AND  targetDate->required rate)
                        - SequentialCycle / CycleMapper
                                         (a user-defined cycle -> "today's unit",
                                          plus name -> catalog node resolution)
                        - BatchHistory   (log -> the undoable bulk actions in it)
                        - SiyumFinder    (progress forest -> completed nodes at
                                          every level, not just leaves)
  data/            depends on domain.
    drift/            database.dart, tables, DAOs
    catalog/          JSON asset loader + version reconciler (pluggable source)
    repositories/     Drift-backed implementations of domain interfaces
    mappers/          row <-> entity
  features/        self-contained feature modules (see §10); each owns its
                   presentation + application (Riverpod notifiers/providers).
    common/           the one write guard, the one read-failure view, the
                      "this id no longer exists" screen, and naming.dart —
                      every domain value that has to become words
    reports/          the one report screen and its five tab bodies — Overview,
                      Calculator, Goals, Siyumim, Mefarshim. Five routes, one
                      Scaffold: they read the same providers and answer the same
                      question at different zooms, and none of them is a surface
                      you work on
    dashboard/  unit_grid/  chazara/  journal/  cycles/  profiles/  search/  settings/
  l10n/            app_en.arb + app_he.arb (source) and generated/ (committed
                   output, diffed by CI the same way the .g.dart files are)
  main.dart
assets/
  catalog/          shas.json, tanach.json, rambam.json, ... + catalog_index.json
  cycles/           daf_yomi.json, mishnah_yomi.json, ...
test/
  domain/           heavy unit tests (fold, rollup, pace, predictor) — pure, fast
  data/             repo tests against in-memory Drift
  widget/           tree view, logging flow
```

**Dependency rule:** `features → domain ← data`, `core` available to all. Domain depends on nothing
but `core`, and on exactly one thing in it: `Day`. Calendar-day arithmetic is the one piece of
cross-cutting logic every layer needs — pace, chazara spacing, cycle position, projections, the
heatmap, the midnight tick — and the alternative to sharing it was the four byte-identical private
copies (in two mutually disagreeing conventions) that `Day` replaced. It is pure Dart with no
imports, so the domain layer stays framework-free. `test/core/day_math_guard_test.dart` enforces
the "one place" half of that claim; it is a build failure, not a convention.
The `Predictor` is pure and is where the legacy "Calculate" logic gets reborn —
fed from the *actual* log instead of a typed-in number, and bidirectional so it also answers
"to finish by date X, learn Y/day (and Z on Shabbos)."

---

## 4. State management (Riverpod, codegen)

```
databaseProvider            -> Drift AppDatabase (singleton)
settingsProvider            -> typed, reactive settings registry (§10)
catalogRepositoryProvider   -> loads + caches JSON catalog (pluggable source)
progressRepositoryProvider  -> Drift-backed, scoped by activeProfile
activeProfileProvider       -> current profile id (switchable)
progressTreeProvider        -> reactive: watches the log, folds + rolls up, emits the tree
                               with per-node % and remaining. UI rebuilds automatically.
foldProvider / logActivityProvider -> the two indexes of the log: what is learned
                               now, and what happened when. Everything below reads these,
                               never the log (test/domain/log_pass_guard_test.dart)
paceProvider / goalStatusProvider -> derived analytics. The pace is one number for the
                               profile, derived once — every goal row used to scan the
                               whole log for its own copy
backupStatusProvider        -> the third axis: distinct units recorded since an instant,
                               keyed on loggedAt. Memoised on the log's identity inside
                               its Notifier rather than lifted into a second provider —
                               a derived provider between the log and the dashboard
                               asserts on route pop (test/features/derived_flush_test.dart)
```

Drift's reactive streams + Riverpod mean: append an event → `UnitState` updates → tree provider
re-emits → dashboard re-renders. No manual refresh plumbing (the legacy app was riddled with it).

---

## 5. Feature list → where it lands

| Your feature | Mechanism |
|---|---|
| Per-unit tracking & display | `UnitState` + tree view with per-node progress bars |
| Session logging (date/duration/note) | `LearningEvent` fields; auto `occurredAt` |
| Charts / heatmaps / predictions | lookups on `LogActivity`; `Predictor` |
| Custom sefarim/categories | `CustomNode` (same schema; **user fills in unit counts**) |
| Hebrew/secular calendar toggle | `kosher_dart`; a display layer over every DateTime |
| Custom cycles / rolling averages | `LogActivity.averagePerDay` windows + `Predictor` |
| Multiple local profiles | `profileId` designed in from day 0 |
| Expandable tree view | replaces legacy drill-down; the visible tree is **flattened** to rows and fed to a `ListView.builder`, so only what is on screen is built (see §10) |
| Multi-criteria sorting | sort/compare over the derived tree |
| Recommendation engine | `Predictor` (targetDate → required rate) — same code as prediction |
| Global search | filter/query over catalog + custom nodes (Drift FTS optional) |
| Export/import | serialize the event log + custom nodes + settings (versioned JSON). **Import merges; restore replaces** — see §10 |
| Undo/redo | inverse events / log tail — falls out of the architecture |
| Single source of truth | derive `learned`; storing it is impossible by design |
| Reminders/notifications | Phase 4; needs `LogActivity` to detect "behind" first |
| Timer / auto date-time | stopwatch → `durationMin`; auto `occurredAt` unless manual |

---

## 6. Roadmap (phased)

- **Phase 0 — Foundation (this plan).** Project scaffold, Drift schema, catalog-as-JSON loader,
  the pure derive-from-log engine, test harness. No pretty UI yet.
- **Phase 1 — Parity+.** Expandable tree with progress bars, per-unit toggle, session logging with
  auto-date, dashboard. Already beats the legacy app.
- **Phase 2 — Intelligence.** History/charts, `PaceEngine`, bidirectional `Predictor` (unifies
  Calculate + recommendation + custom cycles), Hebrew-calendar toggle, streaks.
- **Phase 3 — Power.** Profiles UI, custom sefarim, sort/search, export/import, goals, known cycles.
- **Phase 4 — Polish.** Notifications, timer, chazara UI, drag-order, i18n/RTL polish, more platforms.

Undo/redo and single-source-of-truth are *not* phases — they're consequences of Phase 0.

---

## 7. Phase 0 — concrete deliverables

1. **Repo hygiene:** legacy Java app **deleted** (on GitHub). Fresh Flutter project scaffolded at
   repo root, Android + Windows targets configured.
2. **Dependencies:** `flutter_riverpod` + `riverpod_generator`, `drift` + `drift_flutter` +
   `sqlite3_flutter_libs`, `uuid`, `path_provider`. (`kosher_dart`, `fl_chart` deferred.)
3. **Domain entities + repository interfaces** (pure Dart).
4. **Drift schema:** `Profile`, `LearningEvent`, `CustomNode`, `UnitState` tables + DAOs.
5. **Catalog JSON:** author a *small* first slice (Shas/Moed) + loader + version field. Full corpus
   authoring is its own sub-task (hand-ported from legacy counts, retrievable from git history).
6. **Derive engine:** `FoldLog`, `RollUp`, first cut of `PaceEngine` — fully unit-tested.
7. **Reactive wiring:** `progressTreeProvider` end-to-end: insert an event → tree reflects it.
8. **Tests green:** domain unit tests + one in-memory Drift repo test + one widget smoke test.

**Definition of done for Phase 0:** marking a unit done in one leaf updates that leaf's %, rolls up
to its parents, survives restart, and is provably reconstructed from the log alone — all under test.

---

## 8. Decisions log

- **Irregular units → count half as full.** All units integer; no doubles. *(Resolved.)*
- **Custom sources → user supplies unit counts.** *(Resolved.)*
- **Legacy code → deleted.** On GitHub / git history. *(Resolved.)*
- **Catalog authoring** — hand-port curated counts from legacy `TasksSetup.java` (via git history).
- **Charting package** — `fl_chart` likely; decide in Phase 2.

---

## 9. Additional features folded in (proposed)

Beyond the original list, these fit the log-as-truth model cheaply and raise the app from tracker to
companion:

- **Chazara / review tracking.** `reviewed` events + `reviewCount` per unit. First-learning vs.
  review passes are distinguishable everywhere — central to serious learning, absent from most apps.
- **Streaks & consistency.** Daily learning streak + activity heatmap, straight from the log.
- **Per-node goals + on-track status.** Set a target date on any node; `Predictor` flags
  ahead/behind and the required rate. This is the "recommendation engine" made concrete and personal.
- **Learning cycles as first-class.** Shipped as an *engine*, not a bundled list: Daf Yomi Bavli
  and Yerushalmi are built in because `kosher_dart` computes them authoritatively from the Hebrew
  calendar, and everything else (Amud Yomi, Mishna Yomi, Rambam Yomi, a personal seder) is a
  `SequentialCycle` the user defines — sefarim in order, units per day, a start date. Inventing a
  start date for a cycle in a religious-practice app would be worse than not shipping it, and with
  the engine there, not shipping it costs the user nothing. Each has a **"Today" view**.
- **Full Hebrew / RTL support + UI language toggle.** Hebrew node names, RTL layout, English/Hebrew
  UI — important for this audience, and cheap if designed in from the start (hence `nameHebrew`).
- **Siyum tracking & celebration.** Detect completions, list past siyumim and upcoming ones
  (legacy README advertised a siyum listing — carried forward and upgraded).
- **Data-integrity tools.** "Rebuild derived state from log" maintenance action + versioned export;
  makes the derive-from-log guarantee operable, not just theoretical.

---

## 10. Cross-cutting principles: modular, configurable, extensible

Explicit product requirements, enforced architecturally:

- **Feature modules.** Each feature under `features/<name>/` is self-contained (its own widgets +
  Riverpod notifiers), depends only on `domain` + `core`, and is registered via a small feature
  registry. Adding a feature = adding a folder, not editing a god-object (the legacy app was one big
  web of static globals — explicitly rejected).
- **Everything behind interfaces, injected via Riverpod.** Repositories, catalog source, clock, and
  id-generator are all swappable — trivial to test, trivial to re-point (e.g. bundled JSON today,
  remote catalog later) with no call-site changes.
- **Central settings registry.** One typed, reactive store for all configuration (theme, language,
  calendar, default sort, advanced-calc toggle, cycle subscriptions, ...). Features read config from
  it; nothing hardcodes behavior. "Highly configurable" lives here.
- **Derive, don't store.** New analytics = a new pure function over the log. No schema migration, no
  risk of desync — the whole reason the rewrite exists.
- **Catalog & cycles as data, not code.** New sefarim, corpus fixes, and new limud cycles ship as
  JSON assets (or user input) — no Dart changes, no release for content updates.
- **Screens are addressed by name, and take ids.** `lib/app/routes.dart` is the one route table.
  A destination that is a builder closure cannot be *asked for* from outside the widget tree, which
  rules out deep links, notification taps and OS state restoration — all three arrive as a string.
  So a route carries ids rather than objects, and everything a screen needs lives in its path
  (no `arguments`, so nothing is un-restorable because of what was passed to it). Screens resolve
  their id against the live catalog on every build, which also means a rename or a re-count made
  while a screen is open is visible on that screen rather than waiting for it to be reopened.
- **A write reads the repository, never a cache of it.** `.asData?.value ?? const []` is fine for
  rendering — an empty list draws as "nothing yet" and the next frame corrects it — and is a silent
  lie anywhere a *decision* is made from it, because "not loaded" and "there is none" become the
  same answer. A backup built that way omits your custom sefarim and reports success; a clear built
  that way deletes nothing and reports success. Write paths await the repository's own streams.
- **One policy for every write.** `features/common/guarded.dart` is the only place a
  user-initiated write is awaited, reported, and recorded. Success is reported *after* the write
  succeeds — never alongside it — a failure is recorded to the on-device `CrashLog` labelled with
  what the user was doing, and every failure reads the same way, with a *Details* action that opens
  the log. `unawaited_futures` is on precisely so nothing drifts back out of this.
- **One policy for every failed read, too.** `features/common/error_view.dart` is the read-side
  counterpart: it names what could not be loaded, says whether anything was lost (nothing is — these
  are all reads), records the failure to the same `CrashLog` *once per mount*, and offers a retry
  that re-runs the load. A provider error is not an uncaught exception, so `FlutterError.onError`
  and the guarded zone never see one; without this they reach neither the log nor the user as
  anything but a raw `toString`.
- **The domain has no language.** `domain/` is pure Dart, which means it cannot decide what to
  *call* anything. It holds what is genuinely data — a unit's own name, or its number
  (`CatalogNode.unitDisplay`) — and everything whose wording depends on who is reading lives in
  `features/common/naming.dart`. `unitHeading` used to build `'daf 5'` in the domain by
  interpolating an enum's English name, which is a presentation decision taken three layers below
  the presentation, and the reason the Hebrew toggle could only ever mirror the app rather than
  translate it.
- **A message is one ARB entry, not a sentence assembled at the call site.** The bulk reports were
  built as `'$verb $n unit(s)'`; that is a sentence only in a language whose verb comes first and
  whose plural is an "s". Each action supplies its whole message and each locale states its own
  plural rules, which is also what lets `12,092` be grouped by the locale rather than by a
  hand-rolled thousands helper.
- **Import merges; restore replaces — and only one of them can undo.** The log is append-only, so
  un-marking a unit *appends* an `undone` rather than deleting the `done`. A merge therefore cannot
  reverse anything done after a backup: every id in the file is already present, so nothing is added,
  while the later `undone` still wins. Making a profile match a backup means **deleting** the events
  recorded since it — which is why restore is a separate, confirmed action rather than a flag on
  import. Merge stays the default because a replacing import would destroy whichever device you
  imported *into*.
- **Report in units; the log is internal.** A restore that puts a daf back does it by deleting an
  event, never adding one, so an event-level tally reads "removed 2, added 0" at the moment the user
  watches a completion return. Anything user-facing is phrased in the derived thing they can see —
  units marked — not in log entries. The same rule is why "0 new events" now explains *which* kind
  of nothing it was.
- **The tree renders lazily.** The dashboard flattens the *visible* tree (a node, then its children
  only if expanded) into a row list and feeds `ListView.builder`. Expansion state lives on the
  screen rather than inside each tile, which is what makes flattening possible — and means
  *Expand all* builds a screenful of rows instead of mounting all ~312 tiles, each with a progress
  bar and a per-meforish bar row, in one frame.
- **Group calendar days by a UTC ordinal, not a local `DateTime`.** Constructing a *local*
  `DateTime(y, m, d)` forces a timezone conversion roughly 230× more expensive than the UTC form
  (measured: 2,163 ms vs 8 ms per 20,000). Anything that buckets the log by day keys on the integer
  ordinal and materialises one `DateTime` per *distinct day*. `derive_cost_test.dart` guards this:
  the scans-counter catches algorithmic regressions, and two benchmarks catch constant-factor ones,
  which is the shape this bug had.
