# Onboarding

Where to start, and in what order.

| You want to | Read |
|---|---|
| Get it building and running | [§1](#1-get-it-running) |
| Understand the one decision everything follows from | [§2](#2-the-one-decision) |
| Know the invariants before you touch anything | [§3](#3-five-invariants-with-guards-behind-them) |
| Write code | [§4](#4-your-first-change), then [`../CONTRIBUTING.md`](../CONTRIBUTING.md) |
| Measure something on hardware | [MEASURING.md](MEASURING.md) — **before** you measure, not after |
| Fix something misbehaving | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

This page is the ordered path. [`../CONTRIBUTING.md`](../CONTRIBUTING.md) is the
practical reference and has the repo tour, the worked example of a change moving
through the layers, and the standards every change is held to — read it second,
not instead.

---

## 1. Get it running

```bash
flutter pub get                 # also runs gen-l10n
dart run build_runner build     # generates the Drift and Riverpod code
flutter test                    # 714 tests, about four minutes
flutter run -d windows          # or your android device
```

**Use the Flutter version pinned in `.github/workflows/ci.yml`, not `stable`.**
Two dependencies are held back precisely because of that version, so following
`stable` means testing — and releasing — a combination nobody chose. The reasons
are in the README's *Toolchain notes*, and they are specific rather than
cautious.

Windows desktop builds need **Developer Mode** enabled, for plugin symlinks.

If anything in those four lines fails, it is almost certainly one of four things
and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) leads with all of them: stale
generated code, the wrong Flutter version, a Windows file lock on `sqlite3.dll`,
or a widget test waiting out a ten-minute default.

### What you are looking at

An expandable tree of all of Torah — Tanach, Mishnayos, Shas, Yerushalmi,
Rambam, Tur, Shulchan Aruch, Mishna Berura — with progress bars that roll up from
every daf and perek to the root, plus history, heatmaps, pace, and finish-date
predictions computed from what you have actually done.

It runs on a phone, on a desktop, and on a **Sonim XP5s** — a 240 × 324dp rugged
keypad phone with **no touchscreen at all** — because a lot of people who learn
seriously do not carry a smartphone. That is a real target with a run-verified
build, not an aspiration, and §4 explains what it costs you when you add a
control.

## 2. The one decision

**An append-only event log is the single source of truth, and everything else is
derived.**

The original Java/Android app stored a single aggregate count as the truth,
which made `learned > total` bugs possible and left no room for history or
predictions. Inverting that gives single-source-of-truth, undo/redo, export,
history/heatmaps, and prediction-from-actual-pace **for free**.

Everything else in the architecture is a consequence:

- **Catalog** — immutable reference data (*what exists in Torah*), seeded from
  JSON assets.
- **Progress** — a per-profile append-only event log (*what you learned, and
  when*), in SQLite.
- **Everything derived** — counts, percentages, roll-ups, pace and predictions
  are folds over the log, never stored.

Layers: `domain/` (pure Dart, no framework) · `data/` (Drift + JSON) ·
`application/` (Riverpod) · `features/` (UI) · `app/` (the route table).

### The log is folded twice, and then nobody reads it again

This is the part that is easy to undo by accident.

| Fold | Answers | Used by |
|---|---|---|
| `LogFold` | *what is learned now* — membership per unit | the tree, the chazara schedule, a siyum |
| `LogActivity` | *what happened, and when* — the log indexed by calendar day | pace, streak, heatmap, minutes, the "recorded anything today" nudge |

**Two indexes and not one**, because an un-marked daf leaves the first and stays
in the second: the heatmap is a record of a day, not a claim about today.

Both are built once per change; every question above is then a map lookup.

It had grown the other way once. `statsProvider` held a fold and made five more
passes over the log it came from, every goal row made another, and the dashboard
made one more for a banner — so a user at year seven paid nine-plus full scans of
~3,000 events on every mark and every midnight tick, **invisibly**, because the
cost scales with history and a freshly-tested phone has none.

There is now a test that counts real passes through a live provider graph (ten
goal rows must cost zero, a midnight tick must cost zero) and a guard that fails
the build if a new function takes the whole log.

## 3. Five invariants, with guards behind them

Each of these is enforced by a test that fails the build when the *pattern*
reappears — not when a specific thing breaks. If one fires at you, it is telling
you something structural, and [TROUBLESHOOTING.md](TROUBLESHOOTING.md#guard-tests)
has the per-guard detail.

### 1. The catalog is a forest — a guarantee, not a hope

Every parent link resolves and no node is its own ancestor, because anything
arriving otherwise is **repaired on the way in**: the offending link is detached,
so the node becomes a top-level sefer you can see and re-file, rather than being
deleted or refused.

The bundled data is a tree, but the per-profile override layer is not obliged to
be — one row whose id matches a built-in replaces that node's parent, so a single
hand-edited line can file a sefer under its own descendant.

Eight places walk that relation, and each used to decide for itself whether a
loop was possible. Six kept a visited-set; two — the undo list's *what did this
batch cover* and the subtree clone — did not, and were an **infinite loop** and a
**stack overflow** respectively.

**One invariant replaced eight opinions**, and it is wider than the import check
it retired, because it also covers loops the node editor and the clone can create
with no file involved.

### 2. One answer to "which calendar day is this"

`lib/core/day.dart`. A `Day` is a whole-day count, so "one day later" and "how
many days apart" stay integer arithmetic.

A local-midnight `DateTime` cannot do that: a `Duration` is elapsed time and a
calendar day is 23, 24 or 25 hours of it, so `.add(Duration(days: 1))` and
`.difference(...).inDays` are **both wrong twice a year**.

Everything date-shaped counts in `Day` — pace, streaks, chazara spacing, cycle
position, the finish-date projection, the heatmap, the midnight tick.

### 3. No function takes the whole log

Seven legitimately do, each listed with why it is its own axis. Everything else
goes through one of the two indexes.

One of the seven is worth reading as a cautionary tale: the backup reminder
asks *distinct units recorded since an instant*, keyed on `loggedAt`, which is a
boundary no day index can answer. **Its pass was honest; when it ran was not.**
It sat in a provider that also watches the clock and the settings, so every
midnight, every return to the foreground and every theme toggle walked every
event ever recorded to arrive at a number none of them can move — and the tick
assertion held only because that provider had been left out of the count.

### 4. Derived does not mean re-rendered

Everything being a fold is only affordable if the derivation **stops** where the
answer stopped changing.

Riverpod re-notifies whenever `previous != next`, and Dart compares by identity
unless told otherwise. So every derived value type the graph hands out —
`ProgressNode`, `StatsSummary`, `SettingsState`, `SortConfig`, `BackupStatus`,
`GoalStatus`, `SeriesPoint`, `SessionTimerState` — carries **real `==`**, the
three provider families are `autoDispose`, and a screen that wants one field of
the settings watches *that field* rather than the object.

The guard enforces all three, including the quiet one: a field added to one of
those types and left out of its `==` fails the build, **because otherwise it
shows up as a screen that has stopped updating and nothing else looks for that.**

### 5. The schema has two versions and one real step

`v2` drops `unit_index` from `layer_configs`, and everything else the doorman
refuses — **refusing leaves the file untouched**, which is what makes "open it
with the build that wrote it and export a backup" a real recovery rather than a
sentence.

A twelve-step chain used to sit there. None of the thirteen shapes ever shipped;
every step existed to carry the author's own database from one afternoon's schema
to the next, and a chain that long starts eating itself — v3 added a column so
that v8 could merge it away and drop it. It cost 230 lines of migration and 649
of test, and the price was still rising. Squashed to v1; history is in git.

## 4. Your first change

The full standards are in [`../CONTRIBUTING.md`](../CONTRIBUTING.md) under *How
this work must be done*. Six of them, condensed, because they genuinely govern
what gets accepted:

**Fix the cause, never the symptom.** If a bug exists because a design decision
was half-implemented, finish the design. Do not add a guard that hides the
failure. If a value is wrong, find why — do not clamp it.

**The domain layer stays pure.** `domain/` is plain Dart with no Flutter, no
Riverpod, no I/O. Every fix involving logic belongs in `domain/` or
`application/`, with the UI reduced to display and intent.

**Every fix ships with tests**, and for a correctness fix you **watch it fail**
before it passes rather than assuming it would. Never weaken or delete a test to
make a change pass.

**Single source of truth, always.** No stored derived state, no second fold, no
cached count that can drift.

**Nothing is un-configurable.** No default may be locked. Where a change
introduces behaviour, the user must be able to change it, and user edits overlay
built-ins rather than replacing them.

**Efficient and snappy.** Single-pass derivations. No O(all events) work in a
widget `build`.

### The loop

```bash
dart run build_runner build      # after any table or annotation change
flutter analyze --fatal-infos
flutter test --coverage
dart run tool/check_coverage.dart
```

Coverage floors are **per layer** — `domain/` 90%, `application/` and `core/`
85%, `data/` 70%, `features/` 65%, 75% overall on hand-written code — each a few
points below what the suite achieves today, so ordinary work never trips it and a
real slide does. The tool prints the five least-covered files every run, because
a gate that speaks only when it fails teaches nobody anything.

**There is no `dart format` gate, deliberately.** The source is hand-wrapped so
its explanatory comments read as prose. Match the wrapping around you.

### If you add a control, it has to work on the keypad phone

240 × 324dp, no touchscreen, driven entirely by a D-pad. **Reachable by D-pad and
showing focus** is the bar. A touch-only affordance is a feature that does not
exist on that device.

What has been walked key by key on real hardware: the app opens on the tree's
first generation, three presses of *down* reach the backup banner's named
dismiss, the message that replaces it leaves on its own within ten seconds, and
the drawer's first row returns to the tree.

### Two things that will cost you an afternoon

Both are in [TROUBLESHOOTING.md](TROUBLESHOOTING.md#widget-tests-specifically)
in full, and both are worth knowing before you write your first widget test:

1. **A SnackBar sits behind a timer, not an animation**, so `pumpAndSettle`
   waits out its ten-minute default — and a test that ends with that timer
   pending wedges the binding, making the *next* tests fail somewhere unrelated.
2. **Always give `pumpAndSettle` a real deadline.** The default is ten minutes,
   which turns "this never settles" into a file that appears to hang.

### Before you measure anything on hardware

Read [MEASURING.md](MEASURING.md) first. **Several of the obvious instruments
read zero on Flutter and look authoritative doing it.**

## 5. Where the honest picture is

Two things are complete-and-tested but not confirmed by a human, and the README
says so plainly rather than implying otherwise:

- **File export/import** — the logic is wired via `file_picker`, but the native
  save/open dialogs want a human. Likewise the generated launcher icons and the
  `chovoshayom://` intent filter, whose route table is covered by tests but whose
  manifest hand-off only a real device proves.
- **The Hebrew wording.** The machinery is complete — both locales key-for-key,
  per-locale plurals, all 312 catalog names present and unique, and tests that
  assert the *words* change and not just the direction. But "complete and
  grammatical" is not "reads the way a ben-Torah would say it". It is a contained
  job: `lib/l10n/app_he.arb` and the `nameHebrew` fields in
  `assets/catalog/catalog.json` are the only two files such a pass has to touch.

`lamdan/chovos-hayom-2026-08-05.md` is a whole-repository design review — about
architecture and whether things should exist, not bugs. Worth reading before a
large change.

---

## Where to go next

- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) — the repo tour, a worked example of
  a change moving through the layers, and the full standards.
- [ARCHITECTURE.md](ARCHITECTURE.md) — the full design.
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — symptom-first.
- [MEASURING.md](MEASURING.md) — before touching hardware.
- [`../README.md`](../README.md) — what it does, platform status, releasing.
