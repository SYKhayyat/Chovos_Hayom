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
- **One answer to "which calendar day is this"** — [`lib/core/day.dart`](lib/core/day.dart). A
  `Day` is a whole-day count, so "one day later" and "how many days apart" stay integer
  arithmetic. A local-midnight `DateTime` cannot do that: a `Duration` is elapsed time and a
  calendar day is 23, 24 or 25 hours of it, so `.add(Duration(days: 1))` and
  `.difference(…).inDays` are both wrong twice a year. Everything date-shaped — pace, streaks,
  chazara spacing, cycle position, the finish-date projection, the heatmap, the midnight tick —
  counts in `Day`, and `test/core/day_math_guard_test.dart` fails the build if a second copy of
  that arithmetic appears anywhere in `lib/`.
- **The log is folded twice, and then nobody reads it again.** `LogFold` answers *what is learned
  now* — membership per unit, which is what the tree, the chazara schedule and a siyum want.
  [`LogActivity`](lib/domain/usecases/log_activity.dart) answers *what happened, and when* — the log
  indexed by calendar day, which is what the pace, the streak, the heatmap, the minutes and the
  "have I recorded anything today" nudge want. They are two indexes and not one because an un-marked
  daf leaves the first and stays in the second: the heatmap is a record of a day, not a claim about
  today. Both are built once per change; every question above is then a map lookup. It had grown the
  other way — `statsProvider` held a fold and made five more passes over the log it came from, every
  goal row made another, and the dashboard made one more for a banner, so a user at year seven paid
  nine-plus full scans of ~3,000 events on every mark and every midnight tick, invisibly, because
  the cost scales with history and a freshly-tested phone has none.
  `test/application/log_pass_count_test.dart` counts real passes through a live provider graph — ten
  goal rows must cost zero, a midnight tick must cost zero — and
  `test/domain/log_pass_guard_test.dart` fails the build if a new function takes the whole log,
  listing the seven that legitimately do and why each is its own axis. The backup reminder is one of
  them: *distinct units recorded since an instant*, keyed on `loggedAt`, is a boundary no day index
  can answer. Its pass is honest; **when** it ran was not. It sat in a provider that also watches the
  clock and the settings, so every midnight, every return to the foreground and every theme toggle
  walked every event ever recorded to arrive at a number none of them can move — and the tick
  assertion above held only because that provider had been left out of the count. It is in the count
  now, and the walk happens when the log changes and at no other time.
- **The schema has one version, and it is version 1.** It has had thirteen shapes; none of them
  ever shipped. Every step in the twelve-step migration chain that used to sit under
  [`database.dart`](lib/data/drift/database.dart) existed to carry a database on a machine the
  author was sitting at from one afternoon's schema to the next, and a chain that long starts
  eating itself: v3 added a column so that v8 could merge it away and drop it — so on a v2 database
  v3 ran *only* to give v8 something to read — and v9 had to be written above v8 in the file so
  that v8's table rebuild had a column to copy. It cost 230 lines of migration and 649 of test, and
  the price was still rising: v13 was a one-line value fix and arrived with three migration tests
  of its own that a squash would have carried for free. So the chain is squashed and the history is
  in git. What is left is a doorman: a database written by the last pre-squash build is *already*
  the shape `createAll()` produces, so adopting one is nothing at all — `test/data/schema_test.dart`
  pins that by comparing a fresh database against the schema read off the real device file the
  deleted chain produced, which is what fails if a column ever drifts. Anything else it refuses,
  and refusing leaves the file untouched, because drift stamps `user_version` only after the
  migration callback returns. The next schema change is v2, it will be the first one in this
  project's life that defends somebody else's data, and a bump without a step fails at the door
  rather than silently doing nothing.
- **Derived does not mean re-rendered.** Everything being a fold over the log is only affordable if
  the derivation *stops* where the answer stopped changing. Riverpod re-notifies whenever
  `previous != next`, and Dart compares objects by identity unless told otherwise, so every derived
  value type the graph hands out — `ProgressNode`, `StatsSummary`, `SettingsState`, `SortConfig`,
  `BackupStatus`, `GoalStatus`, `SeriesPoint`, `SessionTimerState` — carries real `==`, the three
  provider families are `autoDispose`, and a screen that wants one field of the settings watches
  that field rather than the object. `test/application/notify_guard_test.dart` enforces all three,
  including the quiet one: a field added to one of those types and left out of its `==` fails the
  build, because otherwise it shows up as a screen that has stopped updating and nothing else looks
  for that.

Clean architecture in layers: `domain/` (pure Dart, no framework) · `data/` (Drift + JSON) ·
`application/` (Riverpod) · `features/` (UI) · `app/` (the route table). Full design in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); the standards every change is held to are in
[`CONTRIBUTING.md`](CONTRIBUTING.md); and if you are about to measure anything on real hardware,
read [`docs/MEASURING.md`](docs/MEASURING.md) first — several of the obvious instruments read zero
on Flutter and look authoritative doing it.

**Stack:** Flutter · Riverpod · Drift (SQLite) · `fl_chart` (charts) · `kosher_dart` (Hebrew
calendar) · `file_picker` (backup) · `shared_preferences` (settings) · `path_provider` (crash log) ·
`flutter_localizations` + `gen-l10n` (English/Hebrew).

## What it does

**Tracking.** An expandable tree of all of Torah — Tanach, Mishnayos, Shas, Yerushalmi, Rambam, Tur,
Shulchan Aruch, Mishna Berura — with progress bars that roll up from every daf and perek to the root.
Open a sefer for its per-unit grid; tap a daf to mark it, tap again to undo. Long-press to log it
with a date, a time, how long it took and a haara, or to view and edit those afterwards. Bulk finish
or clear any node — a whole category, one sefer, or an arbitrary range of dapim — each confirming
with the exact number of units it will change, each undoable from **Bulk action history** today or
next month rather than for four seconds.

**Mefarshim as layers.** Mark a daf per-meforish — Gemara, Rashi, Tosafos, or your own — and a unit
counts as done only once its *required* mefarshim are learned. Each meforish is in exactly one of
three states: *Off*, *Available* (checkable, does not gate completion) or *Required*. Configure it at
any node — Shas, a seder, one mesechta, a single daf — and it inherits down until something nearer
overrides it. The tree shows a thin per-meforish coverage line under each main bar.

**Chazara.** Every review is a first-class pass with its own date, duration, mefarshim and haara. A
spaced-repetition list shows what is due, most-overdue first, with a badge; reviewing pushes the next
date out. Intervals are yours to set.

**One report, five tabs** — Overview, Calculator, Goals, Siyumim, Mefarshim — each keeping its own
address (`/stats`, `/calculator`, `/goals`, `/siyumim`, `/mefarshim`).

- **Overview**: overall %, current streak, 30-day pace, projected siyum date, a cumulative progress
  line and a 12-week activity heatmap.
- **Calculator**, for all of Torah or any category, in three modes: *Rate* (at X/day, +Y on Shabbos →
  finish date), *Cycle* (a custom repeating plan of any length), and *By date* (finish by D → learn
  R/day), whose answer can be kept as a goal — which is what it was computing all along.
- **Goals**: a target date on any sefer, with whether you are on track and the rate you need.
- **Siyumim**: everything completed at every level, mesechta to seder to Shas, dated by its final unit.
- **Mefarshim**: how much of each meforish you have learned across everything.

**Learning cycles.** Daf Yomi Bavli and Yerushalmi are built in, computed from the Hebrew calendar.
Everything else — Mishna Yomi, Rambam Yomi, Amud Yomi, a yeshiva's seder, your own chazara programme
— you define: pick sefarim or a whole category, set units-per-day and a start date, choose whether it
repeats. One-tap logging for whatever today calls for.

**A session timer** that survives leaving the screen, backgrounding the app and quitting it, with a
banner showing the live session wherever you are. Stopping fills in the duration.

**A haara** on any learning or chazara — a chiddush, a question, a maareh makom, how the seder went —
collected into a searchable **Notes Journal**, so nothing has to be classified before it is written.

**Hebrew.** One toggle switches every string in the app into Hebrew and lays it out right-to-left —
screens, menus, confirmations, and the sentence a failed write reports itself with. All 312 sefarim
carry their real names, as do the built-in mefarshim. A mesechta appearing in Mishnayos, Shas,
Yerushalmi and Rambam is disambiguated by where it sits — "Shabbos · Shas · Moed" — derived from its
ancestors, so it translates and so it works for a sefer you added yourself. Anything you add takes
both names.

**Yours, and only yours.** Multiple local profiles, each with its own log and its own settings.
Custom sefarim with your own unit counts. Any node — built-in or custom — can be renamed, re-counted,
re-typed, re-parented, hidden, deleted or reset through a per-profile override layer. Global search
across all of it. Android's automatic cloud backup is switched **off**: left on, it would copy every
daf and every haara to your Google account unasked. The app's own export is the only way anything
leaves the device, and nothing is sent anywhere — including the on-device crash log, which you can
read and copy from Settings.

**Backups, and what each one promises.** *Import* adds what a backup has that you do not and removes
nothing. It cannot undo, and that is not a limitation to work around: the log is append-only, so
un-marking a daf appends an `undone` rather than deleting the `done`, and re-importing an older file
adds nothing while the later `undone` still wins. *Restore* is the one that puts it back, in two
sizes, because "undo my learning back to this backup" and "throw away everything this profile has
become" are different intentions and only one of them deletes a sefer:

| | log | custom sefarim, mefarshim, layer settings | goals | settings |
|---|---|---|---|---|
| **Import** | merged | merged | merged | fills in what you have never set |
| **Restore learning** | reconciled | merged | merged | fills in what you have never set |
| **Restore everything** | reconciled | reconciled | reconciled | reset to the file's |

Both restores say exactly what they will change *before* they change it — units, sefarim and goals —
and report afterwards in units rather than log entries, because putting a daf back is done by
deleting an event, so an event-level tally would read "removed 2, added 0" while a completion
visibly returns. Imported files are validated before anything is written and applied in one
transaction. And Settings tells you where you stand — "last exported 3 March · 41 units learned since
— they exist only on this device" — counting units rather than log entries, going quiet the moment
there is nothing unsaved, and never warning an empty profile.

**Every write either happens or says so.** One guard awaits every user-initiated write, reports
success only *after* it succeeds, and on failure gives one consistent sentence plus a **Details**
button opening the crash log, where it is already recorded under what you were doing ("Marking
Shabbos daf 2 learned"). A form whose save failed stays open with your work in it. Failed *reads* get
the same treatment, with a **Try again** that genuinely re-runs the load.

**It works without a touchscreen.** Not a scaled-down mode — the whole app on a Sonim XP5s: Android
7.1, a 240 × 324dp screen (Material's smallest target is 320 × 480), a D-pad and a numeric keypad. A
focus ring follows whatever holds focus anywhere in the app, the grid answers Tab and Enter, Shift+F10
opens the same menu right-click does, the MENU soft key reaches the unit menu, and screens made only
of figures scroll on the D-pad. The unit grid reads aloud as "daf 7, partly learned, 50%" rather than
as "2, 3, 4, 5".
## Platform status

Both target platforms are built and run-verified, and CI enforces it on every push:

| Platform | Build | Runtime |
|---|---|---|
| **Windows** | `flutter build windows` ✅ | Launches in **both locales**, loads the catalog, no crash-log entries ✅ — and the real on-disk database here, 35 events deep, has been carried through the whole migration chain and then adopted by the squashed schema, keeping every event ✅ |
| **Android** | debug + `--release` (R8) ✅ | Runs on API 36 (moto g stylus 2025). Measured on the device: the logging sheet's confirm button clears the navigation bar by 45px and a tap at its bottom edge registers, the Hebrew progress fraction paints `0 / 12,092  (0.0%)` in that order, the app bar fits `Chovos Hayom`, a backup exported from one profile imports into another, and a deep link opens the same screen whether the app was running or not ✅ |
| **Android, keypad** | `--release` ✅ | Runs on API 25 (Sonim XP5s / XP5800) — a **240 x 324dp screen with no touchscreen**, driven entirely by its D-pad. Measured on the device: focus is visible on every control, the report's figure-only tabs scroll on the D-pad, the bar reads `Chovos Hayom` and `Bereishis` rather than a scaled-down dash, the keypad's MENU key opens the unit menu, and the T9 keypad types into search. Also walked key by key: the app opens on the tree's first generation, three presses of *down* reach the backup banner's named dismiss, the message that replaces it leaves on its own within ten seconds, and the drawer's first row returns to the tree ✅ |
| **CI** | analyze `--fatal-infos`, the full suite, stale-codegen, stale-l10n, untranslated-locale, release APK + R8 assertion | Green on `main` ✅ |

Still needing a real device/eyeball: **file export/import** (the native save/open dialogs — the
logic is wired via `file_picker` but the dialogs themselves want a human), the **generated launcher
icons** (correct by construction), the **`chovoshayom://` deep-link intent filter** (the route table
it feeds is covered by tests, including the URI shape Android delivers, but only a real device
proves the manifest hands it over), and **OS push notifications** (intentionally left out per
product decision; the app uses in-app nudges only). Windows desktop builds require **Developer
Mode** enabled for plugin symlinks. Other desktop platforms are a `flutter create --platforms` away.

Still needing a native reader: **the Hebrew wording**. The machinery is complete and tested — both
locales are key-for-key, the plurals are per-locale, all 312 catalog names are present and unique,
and the tests assert the words change and not just the direction — but "complete and grammatical" is
not the same as "reads the way a ben-Torah would say it". Worth one pass by a native speaker before
release. It is a contained job: the app's own sentences are all in `lib/l10n/app_he.arb`, and the
sefer names are all in `nameHebrew` fields in `assets/catalog/catalog.json`. Those are the only two
files such a pass has to touch.

### Toolchain notes (why some versions are pinned)

Two pins exist because the plugin ecosystem lags Flutter 3.44's Android defaults (AGP 9 / Gradle 9):

- **`file_picker` is held at 8.x.** Version 11's `android/build.gradle` assumes "AGP 9 ⟹ built-in
  Kotlin is on", but Flutter 3.44 ships `android.builtInKotlin=false`, so nothing applies Kotlin to
  its module, `FilePickerPlugin.kt` never compiles, and the Android build fails outright. 8.x has a
  Java Android implementation with the same save/pick surface this app uses. Revisit when file_picker
  ships a Flutter-3.44-compatible release.
- **`android/build.gradle.kts` lifts plugin subprojects to `compileSdk 36`.** file_picker 8.3.7
  hardcodes 34, and `flutter_plugin_android_lifecycle` refuses consumers below 36.

And one that looks like a problem and is not: **`sqlite3_flutter_libs 0.6.0+eol`** appears in
`pubspec.lock`. It is not an abandoned dependency — since `sqlite3` 3.x the native library is built
through Dart's hooks/native-assets mechanism, so that package was *emptied of all its code* and now
exists only as a marker meaning "this app no longer uses the old Flutter-specific build scripts".
`drift_flutter` depends on it for exactly that reason, which is why it is resolved at all; it is not
listed in `pubspec.yaml`, so nobody has to read the `+eol` and go looking for a problem. SQLite
itself comes from `sqlite3` 3.5.0 (the `sqlite3.dll` beside the Windows exe is built by its hook).

The Windows runner's `BINARY_NAME` must stay space-free (`chovos_hayom`) — it is a CMake target id,
and a spaced value makes `add_executable` read it as a target plus a stray source file, failing the
build. The user-facing name is the window title in `windows/runner/main.cpp`.

## Developing

```bash
flutter pub get               # also runs gen-l10n (pubspec: generate: true)
dart run build_runner build   # generates Drift code
flutter analyze               # clean
flutter test                  # all green (CI publishes the count)
```

CI runs all of the above on every push and pull request, plus a release APK build, and is **green on
`main`** — which is worth stating, because for a long time it wasn't running at all: the workflow
existed while the work sat uncommitted, so nothing it promised was actually being enforced. It fails
if the generated Drift/Riverpod code is stale, if the generated localizations are stale, if any
shipped locale is missing a string, or if R8 didn't actually run on the release build.

The Flutter version is **pinned** (`FLUTTER_VERSION` in the workflow) rather than tracking `stable`:
two dependencies are held back precisely because of that version (see *Toolchain notes*), so
following `stable` would mean CI silently testing — and releasing — a combination nobody chose. Bump
it deliberately, with those pins reviewed alongside.

### Translating

Strings live in `lib/l10n/app_en.arb` (the template) and `lib/l10n/app_he.arb`; `l10n.yaml` drives
the codegen. Add a key to the template with a `@key` description, add its translation to every other
locale, and run `flutter gen-l10n` — the output under `lib/l10n/generated/` is **committed**, the
same way the Drift/Riverpod `.g.dart` files are, so a stale table fails CI instead of surfacing as a
missing string on someone's screen. Adding a locale is `app_<code>.arb` plus a full set of keys;
`supportedLocales` follows the generated table automatically.

Two rules keep the domain out of it. `domain/` is pure Dart with no locale, so it holds only what is
genuinely data — a unit's own name, or its number — and everything whose wording depends on the
reader lives in `features/common/naming.dart`. And a message is one whole ARB entry, never a
sentence glued together from a verb and a count: the bulk-action reports used to be
`'$verb $n unit(s)'`, which is a sentence only in a language whose verb comes first and whose plural
is an "s". Plural rules belong in the ARB, where each locale states its own.

`analysis_options.yaml` goes past the `flutter_lints` defaults: `strict-casts` and
`strict-raw-types` (an implicit `dynamic` is how a wrong-typed field becomes a crash three layers
away), `always_declare_return_types`, the `prefer_const_*` family (a const widget is one the
dashboard's tile tree can skip rebuilding), `avoid_dynamic_calls`, `unawaited_futures`, and
`use_build_context_synchronously` promoted from a hint to an **error**. Since CI runs
`--fatal-infos`, all of it is enforced. There is deliberately no formatting rule — the source is
hand-wrapped so its explanatory comments read as prose.

`unawaited_futures` is the one with teeth: a dropped Future is a write nobody is waiting on and
nobody will hear fail, which is exactly what `lib/features/common/guarded.dart` exists to end. Every
write in `features/` goes through that guard, and the lint is what keeps new ones from drifting back
out of it.

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
