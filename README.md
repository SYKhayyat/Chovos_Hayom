# Chovos Hayom

Track your Torah learning — perek by perek, daf by daf — with real progress, history, and
finish-date predictions. A ground-up **Flutter** rewrite of the original Android app, built for
Android, Windows, and (later) macOS/Linux/iOS.

## Why the rewrite

The original (Java/Android) stored a single aggregate count as the source of truth, which made
`learned > total` bugs possible and left no room for history or predictions. This version inverts
that: **an append-only event log is the single source of truth, and everything else is derived.**
That one decision gives single-source-of-truth, undo/redo, export, history/heatmaps, and
prediction-from-actual-pace for free.

## Architecture (short version)

- **Catalog** — immutable reference data (*what exists in Torah*), seeded from JSON assets.
- **Progress** — a per-profile append-only event log (*what you learned, and when*), in SQLite.
- **Everything derived** — counts, percentages, roll-ups, pace, and predictions are folds over the
  log, never stored.

Clean architecture in layers: `domain/` (pure Dart, no framework) · `data/` (Drift + JSON) ·
`application/` (Riverpod) · `features/` (UI). Full design in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

**Stack:** Flutter · Riverpod · Drift (SQLite) · `fl_chart` (charts) · `kosher_dart` (Hebrew
calendar) · `file_picker` (backup) · `shared_preferences` (settings).

## Status

| Phase | Scope | State |
|---|---|---|
| **0 — Foundation** | Event-log core, Drift schema, catalog loader, derive engine, tests | ✅ Done |
| **1 — Parity+** | Full catalog (312 nodes), per-unit grid, session logging, dashboard | ✅ Done |
| **2 — Intelligence** | Charts, pace engine, predictions, Hebrew calendar | ✅ Done |
| **3 — Power** | Profiles, custom sefarim, search, export/import | ✅ Done |
| **4 — Polish** | Goals, chazara UI, session timer, in-app reminders | ✅ Done |
| **5 — Hardening+** | Migration strategy, correctness fixes, cycles, chazara scheduling, siyumim, time analytics, RTL, file backup, full data management | ✅ Done |
| **6 — Depth** | Haaros + Notes Journal, tree sorting, **mefarshim as per-daf layers** (custom + configurable required sets), chazara as first-class passes, full node editability (edit/hide/reset/clone **any** node, named units, attach-anywhere), settings export/import/clear | ✅ Done |

### What works today
- Expandable tree of all of Torah — Tanach, Mishnayos, Shas, Yerushalmi, Rambam, Tur, Shulchan
  Aruch, Mishna Berura — with live progress bars that roll up from every daf/perek to the root.
- Tap a sefer/mesechta to open its **per-unit grid**; tap a daf to mark it, tap again to undo.
- **Long-press** a unit to log it with a specific date **and time**, how long it took, and a haara
  (otherwise the date/time auto-fills to now). Long-press a *finished* unit for **View / edit
  details** — see and change when you finished, the duration, the haara, and its review history
  after the fact. A small note glyph marks units that carry recorded details. Review (chazara)
  passes are tracked per unit.
- **Statistics**: overall %, current streak, 30-day pace, projected siyum date, a cumulative
  progress line chart, and a 12-week activity heatmap.
- **Siyum calculator**, three modes, for the whole Torah or any category:
  *Rate* ("at X/day, +Y on Shabbos → finish date"), *Cycle* (a **custom repeating cycle of any
  length** — set each cycle-day's amount and which day you're currently on, e.g. a 7- or 30-day plan),
  and *By date* ("to finish by date D → learn R/day").
- **Hebrew or secular calendar** toggle applied to every date, plus light/dark theme.
- **Multiple local profiles** (switch between users; each has its own log), **custom sefarim**
  (add your own trackable sefer or habit with your own unit counts), **global search** across
  everything, and **export/import** of all data as JSON. Settings persist across launches.
- **Goals**: set a target finish date on any sefer and see whether you're on track and the daily
  rate you need; a Goals screen lists them all. A **chazara menu** (long-press a unit) logs review
  passes or un-marks; a **session stopwatch** in the log sheet fills in the duration; an optional
  **daily nudge** reminds you in-app if you haven't learned today.
- **Built-in learning cycles**: today's **Daf Yomi** (Bavli) computed from the Hebrew calendar, with
  one-tap logging when the daf maps to a mesechta in your catalog.
- **Chazara scheduling**: a spaced-repetition list of units **due for review**, most-overdue first,
  with a due-count badge; reviewing pushes the next date out.
- **Siyumim**: a running, auto-derived list of every sefer/mesechta you've **completed**, dated by
  its final unit.
- **Time analytics**: total time learned and time-this-month, from logged session durations.
- **Full data management**: **file** (and clipboard) export/import, **delete/rename profiles**,
  **delete custom sefarim**, undo on goal removal, and expand-all / collapse-all for the tree
  (which now starts collapsed).
- **Optional Hebrew (RTL) layout** toggle, alongside the Hebrew/secular calendar and light/dark theme.
- **Mefarshim as layers**: mark a daf done per-meforish (Gemara, Rashi, Tosafos, or your own
  custom mefarshim); a unit is "done" only once its *required* mefarshim are learned. Required
  sets are configured at any node and inherited down (default is text-only, so existing progress is
  never invalidated). The grid shows a partial fill until a layered unit is complete.
- **Offered vs. required mefarshim**: each meforish has two independent switches — *Available*
  (you can check it off here) and *Required* (it gates completion). So you can **track a meforish
  without mandating it for "done"** — the checkable set is not the same as the definition of done.
  Both inherit down a node and default to text-only.
- **Bulk finish / clear** on any node — a whole category cascades to every daf underneath, or a
  single sefer at a time: *Finish all* (each unit's required set), *Mark all — Text* or *— any
  meforish*, and *Clear all*. Everything is one batched write with a one-tap **Undo**; destructive
  clears confirm first. On a leaf you can also **finish an arbitrary range** — pick any start and
  end unit.
- **Mefarshim progress**: a running breakdown of how much of each meforish (and the text) you've
  learned across everything — meaningful now that optional mefarshim are tracked separately from
  progress bars. In the **tree**, each node also shows a thin per-meforish coverage line under its
  main bar (e.g. a Gemara's main progress plus a little Rashi / Tosafos bar) wherever mefarshim are
  enabled — rolled up from every daf underneath. Each meforish's line can be switched on/off
  individually in **Settings → Mefarshim bars**.
- **A haara** per learning/chazara: one free-text field, used however you like — a chiddush, a
  question, a maareh makom, or how the seder went. Every non-empty one is collected in a searchable
  **Notes Journal**, so nothing needs classifying before you write it. Every finished unit's
  details — when, how long, the haara, and its full chazara history — are viewable and editable
  after the fact.
- **Chazara as first-class passes**: each review records its own date/time, duration, mefarshim,
  and haara, with user-configurable spaced-repetition intervals.
- **Configurable tree sorting** by percent / amount / last-learned / name, at any chosen depth.
- **Everything editable**: rename, re-count, re-type, re-parent (attach anywhere), hide/delete, or
  reset **any** node — built-in or custom — via a per-profile override layer; clone a subtree's
  structure; give units real names. A full backup and settings export/import/clear round-trip it all.
- 113 tests covering the engine, layer fold + required/offered-set resolution, per-meforish roll-up,
  bulk finish/clear + ranges, per-meforish stats, catalog overrides, analytics, goals, reminders,
  backup, chazara scheduling, siyumim, time analytics, and UI.

## Remaining device-only work
Almost everything is verified via `flutter test`. A few things need a real device/build to finish:
**file export/import** (logic is wired via `file_picker`, but the native file dialogs need an
on-device/desktop run to verify — and Windows desktop builds require **Developer Mode** enabled for
plugin symlinks), **OS push notifications** (intentionally left out per product decision; the app
uses in-app nudges only), and **running on Android/desktop** (needs the platform toolchains from
`flutter doctor`). The app targets Android + Windows; other desktop platforms are a
`flutter create --platforms` away.

## Developing

```bash
flutter pub get
dart run build_runner build   # generates Drift code
flutter test                  # 113 tests, all green
```

Running the app on a device/desktop needs the platform toolchains (`flutter doctor`):
Android SDK cmdline-tools + licenses, or Visual Studio "Desktop development with C++" for Windows.

---
*Originally a term project by Shaul Khayyat; now being rebuilt properly.*
