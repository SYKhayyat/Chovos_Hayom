# Chovos Hayom — Architecture

> Stack: **Flutter + Dart · Riverpod · Drift (SQLite)**. Ships on **Android + Windows**; the code is
> kept portable for macOS/Linux/iOS.
>
> Guiding constraints: **modular, easy to extend, highly configurable, feature-rich.** These are
> treated as first-class architectural requirements — see §5.
>
> This describes the architecture as it *is*. It began life as a plan and spent a while being both,
> which is how §2.2 came to specify a table that was never built, and how the roadmap that used to
> sit here came to list five phases against the README's thirteen. The scheduling half — the
> roadmap, the Phase 0 deliverables, the decisions log and the proposed-features list, all of them
> long since answered — is gone; git history has it. What is left is meant to be true, and seven
> source files cite it by section number, so keep the numbering stable.

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
  -- rather than left as a false affordance.

LearningEvent            -- append-only; NEVER updated or deleted in normal use
  id           String  (PK, uuid)
  profileId    String  (FK)
  nodeId       String  (catalog or custom leaf id)
  unitIndex    int      which specific perek/daf
  action       enum     done | undone | reviewed   (reviewed = chazara pass)
  occurredAt   DateTime WHEN it was learned (defaults to now unless user sets it)
  loggedAt     int      WHEN it was recorded (always now), stored as microseconds
                        since epoch. Drift's DateTime column is second-resolution,
                        which silently ordered a mark and an un-mark made in the
                        same second by their random UUIDs
  durationMin  int?     optional session length
  note         String?
  layersJson   String?  which layers this event covers (the text, Rashi, ...)
  batchId      String?  groups a bulk action, so it can be undone as one

CustomNode               -- user-defined sefarim/categories; same shape as CatalogNode,
  ...                       profile-scoped and editable. USER SUPPLIES unit counts/labels
                            (no bundled catalog exists for custom content). Also carries
                            `hidden` and `unitNamesJson`, which is how a *built-in* node is
                            overridden: an override row shadows the catalog by id.

CustomLayer              -- user-defined mefarshim, profile-scoped
LayerConfig              -- per (node, unitIndex) map of layer -> role
                            (off | optional | required); absent means off.
                            unitIndex -1 means "this node and below"
```

Five tables, and that is the whole of it. **There is no `UnitState` table, and there never was one** —
this section specified one as a materialized cache for the project's whole life, and two source files
cite this section by number while a third names the entity. Nothing was ever built, which is the
correct outcome: a cache of the fold is exactly the stored derived state §1 exists to refuse. The
fold is computed on demand, once per log change, by `FoldLog` — see §4.

Rules:
- `occurredAt` auto-fills to `now()` **only if the user didn't supply a date/time**.
- `loggedAt` is always `now()`.
- Aggregate `learned` / percentages are **never stored** — they are folds over the log.
  `learned > total` is structurally impossible.
- Undo = append an inverse event; redo = replay. Export = dump the log.
- **Custom sources:** when a user creates a custom sefer/category, *they* fill in the unit label and
  count. Same schema as the bundled catalog, so every feature works on it identically.
- **A profile is spread across two stores, and a backup has to reconcile both.** The five tables
  above, plus the preferences noted on `Profile` — settings and goals. `ImportMode` says how much of
  a profile an import may replace, and it has to mean the same thing in both stores: it reached the
  tables and not the preferences for a month, so a *merge* overwrote settings it promised to leave
  alone while *restore everything* left goals it promised to delete.
  `test/application/import_scope_test.dart` enumerates the contract over every key that exists.

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
    entities/         CatalogNode, Catalog, LearningEvent, Profile, ProgressNode, Layer
    repositories/     abstract interfaces (CatalogRepository, ProgressRepository, ...)
    usecases/         pure functions/services:
                        - FoldLog        (events -> LogFold: which units are complete,
                                          review counts, recorded details — one pass)
                        - RollUp         (leaf progress -> parent aggregates over the tree)
                        - LogActivity    (log -> indexed by calendar day: units learned per
                                          day, minutes per day, what was recorded when.
                                          Pace, streaks and the heatmap are lookups on it)
                        - Predictor      (bidirectional: pace->date  AND  targetDate->required rate)
                        - SequentialCycle / CycleMapper
                                         (a user-defined cycle -> "today's unit",
                                          plus name -> catalog node resolution)
                        - UnitMefarshim  (roles + fold -> which mefarshim one unit
                                          has and what state each is in. Three
                                          sheets took three slices of it by hand
                                          and disagreed about a meforish learned
                                          and deleted since)
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
                      "this id no longer exists" screen, naming.dart — every
                      domain value that has to become words — and
                      node_picker.dart, the one way the catalog is offered to
                      be chosen from (a dialog, a dropdown, and the three
                      decisions both of them make the same way)
    reports/          the one report screen and its five tab bodies — Overview,
                      Calculator, Goals, Siyumim, Mefarshim. Five routes, one
                      Scaffold: they read the same providers and answer the same
                      question at different zooms, and none of them is a surface
                      you work on. A section made of figures wraps itself in
                      ReportBody, which owns the D-pad scrolling the three
                      focusable-widget-free ones need; Goals and the Calculator
                      are controls and do not
    dashboard/  unit_grid/  chazara/  journal/  cycles/  profiles/  search/  settings/
  l10n/            app_en.arb + app_he.arb (source) and generated/ (gitignored —
                   `flutter pub get` rebuilds it in ~2s from the two files beside
                   it, so unlike the .g.dart files it has no stale state to diff.
                   test/l10n/arb_guard_test.dart holds the .arb pair to the rules
                   the generator has no opinion about: no dead key, no key that
                   is its own translation, no @metadata block orphaned by a
                   rename, no placeholder left undeclared and therefore Object)
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

## 5. Cross-cutting principles: modular, configurable, extensible

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
