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

**Stack:** Flutter · Riverpod · Drift (SQLite) · `fl_chart` (later) · `kosher_dart` (later).

## Status

| Phase | Scope | State |
|---|---|---|
| **0 — Foundation** | Event-log core, Drift schema, catalog loader, derive engine, tests | ✅ Done |
| **1 — Parity+** | Full catalog (312 nodes), per-unit grid, session logging, dashboard | ✅ Done |
| **2 — Intelligence** | Charts, pace engine, predictions, Hebrew calendar | ✅ Done |
| 3 — Power | Profiles, custom sefarim, search, export/import, goals | ⏳ Next |
| 4 — Polish | Notifications, timer, more platforms | — |

### What works today
- Expandable tree of all of Torah — Tanach, Mishnayos, Shas, Yerushalmi, Rambam, Tur, Shulchan
  Aruch, Mishna Berura — with live progress bars that roll up from every daf/perek to the root.
- Tap a sefer/mesechta to open its **per-unit grid**; tap a daf to mark it, tap again to undo.
- **Long-press** a unit to log it with a specific date, duration, and note (otherwise the date
  auto-fills to now). Review (chazara) passes are tracked per unit.
- **Statistics**: overall %, current streak, 30-day pace, projected siyum date, a cumulative
  progress line chart, and a 12-week activity heatmap.
- **Siyum calculator** (bidirectional): "at X/day (+Y on Shabbos) I finish on …" and "to finish by
  date D I must learn R/day", for the whole Torah or any category.
- **Hebrew or secular calendar** toggle applied to every date, plus light/dark theme.
- 36 tests covering the derive-from-log engine, catalog integrity, analytics, and the UI flows.

## Developing

```bash
flutter pub get
dart run build_runner build   # generates Drift code
flutter test                  # 22 tests, all green
```

Running the app on a device/desktop needs the platform toolchains (`flutter doctor`):
Android SDK cmdline-tools + licenses, or Visual Studio "Desktop development with C++" for Windows.

---
*Originally a term project by Shaul Khayyat; now being rebuilt properly.*
