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
calendar) · `file_picker` (backup) · `shared_preferences` (settings) · `path_provider` (crash log).

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
| **7 — Production readiness** | Durable bulk undo, validated + atomic import, one-pass derive engine, per-profile settings, configurable learning cycles, release signing + icon + CI + crash log | ✅ Done |

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
  passes or un-marks; an optional **daily nudge** reminds you in-app if you haven't learned today.
- **A session timer that runs while you learn.** Start it, close the sheet, and go learn — it
  survives leaving the screen, backgrounding the app, and quitting it entirely, and a banner shows
  the live session wherever you are so you can pause or discard it. Stopping fills in the duration.
- **Learning cycles, plural**: **Daf Yomi Bavli** and **Daf Yomi Yerushalmi** come built in,
  computed from the Hebrew calendar. Everything else — Mishna Yomi, Rambam Yomi, Amud Yomi, a
  yeshiva's seder, your own chazara programme — you **define yourself**: pick the sefarim (or a
  whole category, expanded in order), set units-per-day and a start date, and choose whether it
  repeats. One-tap logging for whatever today calls for — and if a cycle names a sefer your catalog
  spells differently, you can **link it by hand** instead of hitting a dead end.
- **Chazara scheduling**: a spaced-repetition list of units **due for review**, most-overdue first,
  with a due-count badge; reviewing pushes the next date out.
- **Siyumim at every level**: a running, auto-derived list of everything you've **completed** — a
  mesechta, a seder, Nach, or Shas itself — each dated by its final unit, with the bigger siyumim
  marked as such.
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
  meforish*, and *Clear all*. On a leaf you can also **finish an arbitrary range**. Every bulk
  action is one batched write, and **every one of them confirms first with the exact number of units
  it will change** — the difference between finishing one mesechta and finishing Shas is 64 versus
  12,092, and that number is the whole point. Undo is durable: **Settings → Bulk action history**
  lists every batch and reverts any of them, today or next month — not for four seconds.
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
- **Per-profile settings**: calendar, theme, RTL, sort, chazara intervals, meforish bars and cycles
  all belong to the profile rather than the device, so two people sharing one get their own.
- **Mefarshim configurable at any node**: pin a required/available set on Shas, on a seder, on one
  mesechta, or on a single daf, and it inherits down until something nearer overrides it. Logging
  a meforish carries the same date, duration and haara as anything else.
- **Everything editable**: rename, re-count, re-type, re-parent (attach anywhere), hide/delete, or
  reset **any** node — built-in or custom — via a per-profile override layer; clone a subtree's
  structure; give units real names. A full backup and settings export/import/clear round-trip it all.
- **Your data stays yours.** Android's automatic cloud backup is switched **off** — left on, it
  would copy the database (every daf, every haara) to your Google account by default, unasked. The
  app's own export is the only way your learning leaves the device. Imported backups are
  **validated before anything is written** and applied in one transaction, so a corrupt or
  hand-edited file gives a clear error instead of a permanently broken app. Goals travel with the
  backup, and deleting a profile takes its goals with it.
- **A crash log**, on the device only, readable and copyable from Settings — so a bug that only
  happens on your phone is something you can actually report. Nothing is sent anywhere.
- 224 tests covering the engine, layer fold + required/offered-set resolution, per-meforish roll-up,
  bulk finish/clear + ranges + durable undo, per-meforish stats, catalog overrides, analytics, goals,
  reminders, backup validation, chazara scheduling, siyumim, learning cycles, the session timer,
  per-profile settings, schema migrations, derive-engine cost, and UI.

## Remaining device-only work
Almost everything is verified via `flutter test`. A few things need a real device/build to finish:
**file export/import** (logic is wired via `file_picker`, but the native file dialogs need an
on-device/desktop run to verify — and Windows desktop builds require **Developer Mode** enabled for
plugin symlinks), the **generated launcher icons** (correct by construction, but worth an eyeball
on a real launcher), **OS push notifications** (intentionally left out per product decision; the app
uses in-app nudges only), and **running on Android/desktop** (needs the platform toolchains from
`flutter doctor`). The app targets Android + Windows; other desktop platforms are a
`flutter create --platforms` away.

## Developing

```bash
flutter pub get
dart run build_runner build   # generates Drift code
flutter analyze               # clean
flutter test                  # 224 tests, all green
```

CI runs all of the above on every push and pull request, plus a release APK build, and fails if the
generated Drift/Riverpod code is stale.

`analysis_options.yaml` goes past the `flutter_lints` defaults: `strict-casts` and
`strict-raw-types` (an implicit `dynamic` is how a wrong-typed field becomes a crash three layers
away), `always_declare_return_types`, the `prefer_const_*` family (a const widget is one the
dashboard's tile tree can skip rebuilding), `avoid_dynamic_calls`, `unawaited_futures`, and
`use_build_context_synchronously` promoted from a hint to an **error**. Since CI runs
`--fatal-infos`, all of it is enforced. There is deliberately no formatting rule — the source is
hand-wrapped so its explanatory comments read as prose.

### Releasing

Release builds are signed from `android/key.properties`, which is git-ignored. Copy
`android/key.properties.example`, create a keystore, and fill it in:

```bash
keytool -genkey -v -keystore chovos-hayom-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias chovos-hayom
```

Keep that keystore somewhere you will still have it in five years — losing it means you can never
publish an update to this app again. Without the file, release builds still work, but they are
debug-signed and **not distributable**. Bump `version:` in `pubspec.yaml` before each release.

### Changing the app icon

The icon is drawn in code, so it needs no image tooling installed:

```bash
python tool/generate_icon.py       # the constants at the top are the whole design
dart run flutter_launcher_icons    # regenerate every platform size
```

To use your own artwork instead, replace `assets/icon/icon.png` (square, 1024x1024) and
`assets/icon/icon_foreground.png` (transparent, for Android's adaptive icon, whose mask crops to
roughly the middle 66%), then run only the second command.

Running the app on a device/desktop needs the platform toolchains (`flutter doctor`):
Android SDK cmdline-tools + licenses, or Visual Studio "Desktop development with C++" for Windows.

---
*Originally a term project by Shaul Khayyat; now being rebuilt properly.*
