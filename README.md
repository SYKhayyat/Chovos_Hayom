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
`application/` (Riverpod) · `features/` (UI) · `app/` (the route table). Full design in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

**Stack:** Flutter · Riverpod · Drift (SQLite) · `fl_chart` (charts) · `kosher_dart` (Hebrew
calendar) · `file_picker` (backup) · `shared_preferences` (settings) · `path_provider` (crash log) ·
`flutter_localizations` + `gen-l10n` (English/Hebrew).

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
| **7 — Production readiness** | Durable bulk undo, validated + atomic import, one-pass derive engine, per-profile settings, configurable learning cycles, release signing + icon + CI + crash log, one write-error policy, named routes + deep links | ✅ Done |
| **8 — Shipping it** | Partial-un-mark data-loss fix, backup covers every per-profile key, profile-delete cleanup, override-cycle validation, day-ordinal series keying, lazy tree rendering, real restore-from-backup — and the app actually **built and run** on Windows and Android | ✅ Done |
| **9 — Speaking Hebrew** | Full English/Hebrew localization (the toggle translates rather than mirrors), `nameHebrew` finally displayed, screen-reader labels on the unit grid, a real error view with retry behind every failed read, and CI that pins its toolchain and fails on a stale or incomplete string table | ✅ Done |
| **10 — Not losing it** | A backup reminder that counts what is genuinely at risk, so the "everything stays on your device" promise stops being a silent single point of failure | ✅ Done |
| **11 — What a phone found** | Twelve defects from two independent adversarial gradings, three of which no test could have seen and one minute on a phone showed immediately: a confirm button under the navigation bar, a progress fraction reading backwards in Hebrew, a green tick over a backup that did not exist. Plus the cross-profile import that never worked, a restore split into the two things it was pretending to be, a calculator that walked 200,000 days inside `build()`, and a grid a keyboard could only half reach. Then the phone was plugged in and found a thirteenth: a deep link that opened the right screen from cold and "Not found" when the app was already running | ✅ Done |

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
  with a due-count badge; reviewing pushes the next date out. Only units that are actually complete
  appear — ticking an optional meforish doesn't put a half-learned daf on the list — and a unit whose
  sefer you've since hidden or shrunk drops off rather than lingering as a dead row.
- **Siyumim at every level**: a running, auto-derived list of everything you've **completed** — a
  mesechta, a seder, Nach, or Shas itself — each dated by its final unit, with the bigger siyumim
  marked as such.
- **Time analytics**: total time learned and time-this-month, from logged session durations.
- **Import merges; Restore replaces.** Two separate actions, because they answer different
  questions. *Import* adds whatever a backup has that you don't and never removes anything — so
  re-importing a backup you already have reports "already up to date" rather than a bare "0". But the
  log is append-only: un-marking a daf *appends* an `undone`, it doesn't delete the `done`. So a
  merge can never undo something you did after the backup — every id in the file is already present,
  and your later `undone` still wins. *Restore* is the one that puts it back, and it comes in two
  sizes, because "undo my learning back to this backup" and "throw away everything this profile has
  become since" are different intentions and only one of them deletes a sefer. **Restore learning**
  reconciles the log and keeps your custom sefarim, mefarshim and settings; **Restore everything**
  makes the whole profile match the file and deletes the customisations it does not contain. All of
  them report in the terms you can see — "1 unit is marked again; 1 unit is no longer marked" — and
  both restores tell you exactly what they will change *before* they change it, counting the sefarim
  as well as the units, because putting a daf back is done by deleting an event, so an event-level
  tally would read "removed 2, added 0" while a completion visibly returns.
- **A backup imports into a second profile.** It never did: event ids were unique across the whole
  database rather than within a profile, so the same file imported twice collided with itself and
  the import died on a constraint — and the message blamed the *file*, which is the one thing that
  was not at fault and the only copy of that learning. The key is now the profile plus the id, like
  every other table, and a failure that is the app's own says so instead of inviting you to delete
  your backup and make another.
- **Full data management**: **file** (and clipboard) export/import, **delete/rename profiles**,
  **delete custom sefarim**, undo on goal removal, and expand-all / collapse-all for the tree
  (which now starts collapsed).
- **The app speaks Hebrew.** One toggle switches every string in it — screens, menus,
  confirmations, error messages, the sentence a failed write reports itself with — into Hebrew, and
  lays the app out right-to-left. It used to flip the direction and localize Material's own date
  pickers while leaving the app's own text in English, which is a mirror, not a translation.
  **All 312 sefarim** carry their real names (ברכות, בבא מציעא, שולחן ערוך), as do the built-in
  mefarshim (רש״י, תוספות). A mesechta that appears in Mishnayos, Shas, Yerushalmi and Rambam is
  disambiguated by **where it sits**, derived from its ancestors — "Shabbos · Shas · Moed" — rather
  than by a "(Shas)" typed into 120 of the names, which was noise on every row inside Shas, missing
  from every Mishnayos masechta, and impossible for a sefer you add yourself. The four places that
  show a flat list with no tree around it (search results, the calculator's dropdown, both cycle
  pickers) all say which one you are looking at, in either language.
- **Numbers read the right way round in Hebrew.** "0 / 929" was painting as "929 / 0" on every row
  of the tree: digits are weak-left-to-right and a space-padded slash is neutral, so the bidi
  algorithm reversed the whole run and swapped the operands. The numeric templates are wrapped in a
  Unicode isolate, so the line still sits on the right and its contents still read left to right. Anything **you** add takes both names
  too: the custom-sefer and custom-meforish forms offer an English field and a Hebrew one side by
  side, either alone is enough, and a custom meforish can be renamed afterwards — which it could
  not before, so a Hebrew name you didn't type at creation used to be unreachable. Alongside the
  separate Hebrew/secular **calendar** toggle and light/dark theme.
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
  mesechta, or on a single daf, and it inherits down until something nearer overrides it. The sheet
  tells you whether what you're looking at is *set here* or *inherited from* a higher node, and
  opening it without changing anything won't pin the inherited set as an override — so a set on Shas
  keeps reaching a mesechta you merely glanced at. Logging a meforish carries the same date, duration
  and haara as anything else.
- **Everything editable**: rename, re-count, re-type, re-parent (attach anywhere), hide/delete, or
  reset **any** node — built-in or custom — via a per-profile override layer; clone a subtree's
  structure; give units real names. A full backup and settings export/import/clear round-trip it
  all — learning cycles included — and *Clear settings* names everything it removes (preferences,
  goals, learning cycles, custom sefarim, mefarshim, required sets) before it removes any of it,
  leaving the learning log untouched.
- **It tells you when your learning exists in only one place.** Keeping everything on the device is
  the point (see below), and the consequence is that the app's own export is the only copy that
  survives a lost phone — which nothing ever mentioned. Settings now shows where you stand ("last
  exported 3 March · 41 units learned since — they exist only on this device"), and once there is
  unsaved learning older than your chosen interval, the dashboard says so and offers the export.
  It counts **units**, not log entries, so the number means something; it goes quiet the moment
  there is nothing unsaved, however long ago the last export was, so a finished sefer isn't nagged
  about forever; an empty profile is never warned at; and the "last exported" stamp is written
  *after* the export succeeds and never on a failure or a cancel — a false "you're safe" would
  silence the one warning that mattered. The interval is yours to set, and the whole thing is one
  switch to turn off.
- **Your data stays yours.** Android's automatic cloud backup is switched **off** — left on, it
  would copy the database (every daf, every haara) to your Google account by default, unasked. The
  app's own export is the only way your learning leaves the device. Imported backups are
  **validated before anything is written** and applied in one transaction, so a corrupt or
  hand-edited file gives a clear error instead of a permanently broken app — including a hand-edited
  override that would re-parent a built-in sefer beneath its own descendant and empty the tree. Goals
  and cycles travel with the backup, and deleting a profile takes *all* of its settings with it — its
  goals, cycles, and every per-profile preference — not just its learning history.
- **A crash log**, on the device only, readable and copyable from Settings — so a bug that only
  happens on your phone is something you can actually report. Nothing is sent anywhere.
- **A write either happens or it says so.** Every write the app makes goes through one guard: it is
  awaited, it is reported *after* it succeeds rather than alongside it, and if it fails you get one
  consistent sentence naming what failed and a **Details** button that opens the crash log — where
  the failure is already recorded under what you were doing ("Marking Shabbos daf 2 learned").
  Nothing is fire-and-forget, so nothing can fail in silence, and a form whose save failed stays
  open with your work still in it rather than closing over something that was never written.
- **A failed *read* says so too.** The three screens that load data used to render a raw exception
  with no way forward, which made a database that lost a race look identical to a permanently broken
  install. They now say what could not be loaded, say that nothing was lost (every one of them is a
  read), offer **Try again** — which genuinely re-runs the load, and recovers — and put the failure
  in the crash log, so the *Open crash log* they offer is not a promise of something that isn't
  there. A provider error never reached the log before: it isn't an uncaught exception, so none of
  the crash handlers ever saw it.
- **The grid can be read aloud.** A unit cell shows whether it is learned through colour alone, and
  its only text is the bare unit number — so the app's central screen announced itself to a screen
  reader as "2, 3, 4, 5". Each cell now says what it is ("daf 2, learned", "daf 7, partly learned,
  50%"), including its chazara count and whether it carries recorded details, and announces as a
  checked button you can reach by keyboard. Progress bars are marked decorative, since the count
  beside them already carries the number in words.
- **The grid answers a keyboard.** Tab reaches the cells, Enter marks the focused one — and the
  focused one is now *visible*, which it was not: the cell is a filled container and the default
  focus highlight paints behind it, so a keyboard user was marking dapim blind. Shift+F10 or the
  context-menu key opens the same menu right-click does, so logging with a date, a duration, a haara
  or a chazara no longer needs a pointing device.
- **It works on a phone with no touchscreen.** Not a scaled-down mode — the whole app, on a Sonim
  XP5s: Android 7.1, a 240 x 324dp screen (Material's smallest target is 320x480), a D-pad and a
  numeric keypad. It already *ran* there, and already answered the D-pad, because the keyboard
  support above costs nothing extra on a device whose keys arrive as key events — the phone's MENU
  soft key even reaches the unit menu as `LogicalKeyboardKey.contextMenu`, the binding added for
  desktop. What it did not do was ever say **what was selected**: pressing the centre key on the
  unit grid opened "Bulk actions", because focus had started on an app bar icon and nothing on
  screen said so; one more press would have marked a whole sefer learned. A focus ring now follows
  whatever holds focus, anywhere in the app. Screens made only of figures — Statistics, Siyumim,
  Mefarshim progress — could not be scrolled *at all*, holding no focusable widget for the D-pad to
  move to, so everything below the fold was unreachable by any sequence of keys; they scroll now.
  App bars fold their actions into a named menu rather than scaling the app's own name down to an
  illegible dash, floating buttons that sat on top of the content give way to bar actions, and the
  statistics tiles size to their contents instead of to a fixed 2.4 aspect ratio that made every
  figure overflow the card below it. All of it keys off screen *width*, so a phone with a
  touchscreen is pixel-identical to what it was — asserted by tests, not hoped for.
- **Every screen has an address.** Screens are named routes that carry ids (`/sefer/<id>`), never
  widget objects — which is what makes deep links, notification taps and Android's state
  restoration possible at all, and what makes a rename show up on a screen that is already open.
  On Android those addresses are reachable from outside: `chovoshayom://sefer/<id>` opens that
  sefer's grid with the dashboard behind it, and a path the app doesn't serve says so rather than
  showing a blank screen — **whether or not the app was already open**, which is not free: a link
  delivered to a running app arrives on a different channel, and the framework's default handler
  drops the part of the URI that says *which kind* of screen is wanted. (A private scheme, not an `https` App Link — claiming a domain you don't
  own is how a link ends up opening someone else's app.)
- 413 tests covering the engine, layer fold + required/offered-set resolution (including that
  un-ticking one meforish never wipes the rest of a unit's history), per-meforish roll-up,
  bulk finish/clear + ranges + durable undo, per-meforish stats, catalog overrides, analytics, goals,
  reminders, backup validation (including override-row parent cycles), chazara scheduling (complete
  units only), siyumim, learning cycles, the per-profile session timer, per-profile settings + their
  backup coverage and profile-delete cleanup, restore-vs-merge (including that a merge *cannot* undo
  an un-mark and a restore can), schema migrations, derive-engine cost — both the scans-counter and
  two benchmarks that catch constant-factor regressions — lazy tree rendering, the write guard
  + route table, the read-failure view (that retry re-runs the load and recovers, and that a rebuild
  does not re-log the same failure), the grid's screen-reader labels, the backup reminder (that a failed export never stamps the profile as safe, that units are counted rather than log entries, and that a profile with nothing unsaved is left alone), and translation — that Hebrew
  changes the *words* and not only the direction, that both locales are key-for-key complete, and
  that reports read correctly in each.
- The 58 added in phase 11 are mostly about the half of the app a unit test cannot see, and each one
  was watched fail first: the real Drift repository under test at last (it had none, and both of its
  defects were about profile scope), every modal sheet laid out on a phone that has a navigation bar
  — with a control sheet the same assertion must *reject*, since a geometry check that cannot fail is
  what let a dead button ship — the grid driven by keyboard alone, the app bar measured at 1.6x font
  scale, the finish-date predictor checked against a written-out day-by-day walk over nine cycle
  shapes, the backup tile across all four corners of exported x learned, and the restore preview's
  arithmetic against a backup whose mefarshim requirements differ from the profile's.

## Platform status

Both target platforms are built and run-verified, and CI enforces it on every push:

| Platform | Build | Runtime |
|---|---|---|
| **Windows** | `flutter build windows` ✅ | Launches in **both locales**, loads the catalog, no crash-log entries ✅ — and the release binary has now upgraded a real v10 database to the v11 schema in place, keeping every event ✅ |
| **Android** | debug + `--release` (R8) ✅ | Runs on API 36 (moto g stylus 2025). Measured on the device: the logging sheet's confirm button clears the navigation bar by 45px and a tap at its bottom edge registers, the Hebrew progress fraction paints `0 / 12,092  (0.0%)` in that order, the app bar fits `Chovos Hayom`, a backup exported from one profile imports into another, and a deep link opens the same screen whether the app was running or not ✅ |
| **Android, keypad** | `--release` ✅ | Runs on API 25 (Sonim XP5s / XP5800) — a **240 x 324dp screen with no touchscreen**, driven entirely by its D-pad. Measured on the device: focus is visible on every control, Statistics and Siyumim scroll on the D-pad, the bar reads `Chovos Hayom` and `Bereishis` rather than a scaled-down dash, the keypad's MENU key opens the unit menu, and the T9 keypad types into search ✅ |
| **CI** | analyze `--fatal-infos`, 422 tests, stale-codegen, stale-l10n, untranslated-locale, release APK + R8 assertion | Green on `master` ✅ |

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
flutter test                  # 352 tests, all green
```

CI runs all of the above on every push and pull request, plus a release APK build, and is **green on
`master`** — which is worth stating, because for a long time it wasn't running at all: the workflow
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
