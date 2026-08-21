# Troubleshooting

Symptom first. Most problems here are one of four things: stale generated code,
the wrong Flutter version, a Windows file lock, or a widget test waiting out a
ten-minute default.

The command that fixes the most:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The check that saves the most time:

```bash
flutter --version        # must match FLUTTER_VERSION in .github/workflows/ci.yml
```

---

## Contents

- [Setup and toolchain](#setup-and-toolchain)
- [Generated code](#generated-code)
- [Running the tests](#running-the-tests)
- [Widget tests specifically](#widget-tests-specifically)
- [Guard tests](#guard-tests)
- [Windows](#windows)
- [Android and the keypad phone](#android-and-the-keypad-phone)
- [Localisation](#localisation)
- [The database](#the-database)
- [CI and gates](#ci-and-gates)
- [Behaviour that looks wrong and is not](#behaviour-that-looks-wrong-and-is-not)

---

## Setup and toolchain

### The four commands

```bash
flutter pub get                 # also runs gen-l10n (pubspec: generate: true)
dart run build_runner build     # generates the Drift and Riverpod code
flutter test                    # 714 tests, about four minutes
flutter run -d windows          # or your android device
```

### Use the pinned Flutter version, not `stable`

`FLUTTER_VERSION` in `.github/workflows/ci.yml` is the version to install.

This is not fussiness. **Two dependencies are held back precisely because of
that version**, so following `stable` means testing — and releasing — a
combination nobody chose.

### The Android build fails compiling `FilePickerPlugin.kt`

`file_picker` has been upgraded past 8.x. Put it back.

Version 11's `android/build.gradle` assumes "AGP 9 implies built-in Kotlin is
on", but Flutter 3.44 ships `android.builtInKotlin=false`, so nothing applies
Kotlin to its module, `FilePickerPlugin.kt` never compiles, and the Android
build fails outright.

8.x has a Java Android implementation with the same save/pick surface this app
uses. Revisit when `file_picker` ships a Flutter-3.44-compatible release.

### A plugin fails on `compileSdk`

`android/build.gradle.kts` lifts plugin subprojects to `compileSdk 36` for a
reason: `file_picker` 8.3.7 hardcodes 34, and
`flutter_plugin_android_lifecycle` refuses consumers below 36. If you removed
that lift, put it back.

### `sqlite3_flutter_libs 0.6.0+eol` in `pubspec.lock`

**Not an abandoned dependency, and nothing to fix.**

Since `sqlite3` 3.x the native library is built through Dart's
hooks/native-assets mechanism, so that package was *emptied of all its code* and
now exists only as a marker meaning "this app no longer uses the old
Flutter-specific build scripts". `drift_flutter` depends on it for exactly that
reason, which is why it resolves at all.

It is deliberately not listed in `pubspec.yaml`, so nobody has to read the
`+eol` and go looking for a problem. SQLite itself comes from `sqlite3` 3.5.0 —
the `sqlite3.dll` beside the Windows exe is built by its hook.

## Generated code

### `no such column`, a missing `.g.dart` symbol, or a provider that does not exist

`build_runner` has not run since you edited a table or an annotation.

```bash
dart run build_runner build --delete-conflicting-outputs
```

This is the single most common failure in the repository. CI has a stale-codegen
gate for it, so it will also fail your push.

### `build_runner` reports conflicting outputs

`--delete-conflicting-outputs`, as above. It happens after a rename or a
branch switch.

### CI says the generated code is stale and mine is fine

Run `build_runner` and commit the result. The generated files are checked in
deliberately so that a clone builds without a codegen step, and the gate exists
because a stale `.g.dart` is otherwise invisible until runtime.

## Running the tests

### `flutter test` fails to delete `sqlite3.dll`

A previous test process is still alive and holding it. Kill stray `dart` and
`flutter_tester` processes and run again.

**Two test runs at once will do this to you on Windows.** Do not run the suite in
two terminals.

### The suite takes four minutes and I only changed one file

```bash
flutter test test/domain/                 # one directory
flutter test test/domain/day_math_test.dart
flutter test --name 'substring of the test name'
```

Run the whole suite before pushing.

### Coverage

```bash
flutter test --coverage
dart run tool/check_coverage.dart
```

The floors are **per layer**: `domain/` 90%, `application/` and `core/` 85%,
`data/` 70%, `features/` 65%, and 75% overall on hand-written code, with
generated code excluded. Each sits a few points below what the suite achieves
today, so ordinary work never trips it and a real slide does.

The reason for each floor is written in that file. It also prints the five
least-covered files every run, **because a gate that speaks only when it fails
teaches nobody anything.**

Historical note worth knowing: `--coverage` ran for a long time and uploaded
`lcov.info` as an artifact that nothing read — no threshold, no badge, no diff.
A number nobody looks at only ever goes down.

## Widget tests specifically

### A test file appears to hang

**Almost always a SnackBar, and it will cost you an afternoon twice if you do
not know this.**

A SnackBar sits on screen behind a **timer**, not an animation. So
`pumpAndSettle` after the tap that shows one waits out its full **ten-minute**
default. Worse: a test that *ends* while that timer is still pending leaves the
binding wedged, so the next tests fail with `'inTest': is not true` and a
ten-minute timeout each — and the file looks like it is hanging somewhere it is
not.

Both halves are needed:

```dart
await tester.tap(find.text('Save'));
await tester.pump();                                 // the bar starts coming in
await tester.pump(const Duration(milliseconds: 750));
expect(find.text('Give the cycle a name.'), findsOneWidget);
await tester.pump(const Duration(seconds: 5));       // its timer fires *here*
await tester.pumpAndSettle();                        // and it leaves
```

### Always give `pumpAndSettle` a real deadline

```dart
await tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 15),
);
```

The default is ten minutes, which is not a timeout so much as a way of turning
"this never settles" into a file that appears to hang.
`edit_cycle_screen_test.dart` wraps that in a local `settle(tester)` — copy it.

### `'inTest': is not true` in a test that looks unrelated

A *previous* test left a pending timer. See the SnackBar entry above. Look at
the test before the failing one, not at the failing one.

### A finder finds nothing that is clearly on screen

Off-screen children of a `ListView` are never built, so they are not in the tree
to be found.

Either scroll to it, or give the test a taller view via
`tester.view.physicalSize` — **and say in the test which one you meant.**

## Guard tests

Several tests exist to fail the build when a *pattern* reappears rather than
when a specific thing breaks. If one fails, it is telling you something
structural.

| Guard | Fails when |
|---|---|
| `catalog_forest_guard_test.dart` | A rival cycle check grows back. One invariant replaced eight opinions; six kept a visited-set and two did not, and were an infinite loop and a stack overflow respectively. |
| `day_math_guard_test.dart` | A second copy of calendar-day arithmetic appears anywhere in `lib/`. |
| `log_pass_guard_test.dart` | A new function takes the whole log. It lists the seven that legitimately do, and why each is its own axis. |
| `notify_guard_test.dart` | A field is added to a derived value type and left out of its `==`. |

### `notify_guard_test` failed after I added a field

Add it to that type's `==`. This guard exists because otherwise the symptom is
"a screen has stopped updating" and nothing else looks for that.

Riverpod re-notifies whenever `previous != next`, and Dart compares by identity
unless told otherwise — so every derived value type the graph hands out carries
real `==`, the three provider families are `autoDispose`, and a screen that wants
one field of the settings watches *that field* rather than the object.

### `log_pass_guard_test` failed on a function I wrote

You wrote something that walks the whole event log. Either fold it into one of
the two existing indexes, or add it to the list with a reason.

Background: this had grown the wrong way once. `statsProvider` held a fold and
made five more passes over the log it came from, every goal row made another, and
the dashboard made one more for a banner — so a user at year seven paid nine-plus
full scans of ~3,000 events on every mark and every midnight tick, **invisibly**,
because the cost scales with history and a freshly-tested phone has none.

`log_pass_count_test.dart` counts real passes through a live provider graph: ten
goal rows must cost zero, a midnight tick must cost zero.

### `day_math_guard_test` failed

You used `DateTime` arithmetic for a calendar day somewhere. Use `Day`
(`lib/core/day.dart`).

A `Duration` is elapsed time and a calendar day is 23, 24 or 25 hours of it, so
`.add(Duration(days: 1))` and `.difference(...).inDays` are **both wrong twice a
year**. Everything date-shaped counts in `Day`.

## Windows

### `flutter build windows` fails on plugin symlinks

Enable **Developer Mode** in Windows settings. Flutter plugins need it to create
symlinks.

### The CMake build fails with a stray source file

`BINARY_NAME` in the Windows runner must stay **space-free** (`chovos_hayom`).
It is a CMake target id, and a spaced value makes `add_executable` read it as a
target plus a stray source file, failing the build outright.

The user-facing name is the window title in `windows/runner/main.cpp`.

### The Windows build works on my machine and fails in CI

That is the job doing what it exists for. There was no Windows job at all for a
long time, on a platform the app ships to — every Windows build happened on the
author's machine.

**CMake caches aggressively, and the CMake target-id failure above is exactly
the class a warm build tree hides.** Try a clean tree:

```bash
flutter clean
flutter pub get
dart run build_runner build
flutter build windows
```

## Android and the keypad phone

### The release APK builds but R8 did not run

The CI assertion for this is **documented as toothless locally**, because Gradle
reuses a stale mapping. It is meaningful only on a clean checkout.

If you need to verify locally, `flutter clean` first.

### Something is unreachable on the Sonim XP5s

The keypad phone is a real target, not an aspiration: **240 × 324dp, no
touchscreen at all**, driven entirely by its D-pad. It is run-verified on API 25.

What has been measured on the device: focus is visible on every control, the
report's figure-only tabs scroll on the D-pad, the bar reads `Chovos Hayom` and
`Bereishis` rather than a scaled-down dash, the MENU key opens the unit menu, and
the T9 keypad types into search.

If you add a control, it must be **reachable by D-pad and show focus**. A
touch-only affordance is a feature that does not exist on that device.

### Deep links

`chovoshayom://`. The route table it feeds is covered by tests, including the URI
shape Android delivers — but **only a real device proves the manifest hands it
over**. It is on the list of things still needing an eyeball.

### File export/import does nothing

The logic is wired via `file_picker`, but the native save/open dialogs
themselves have not been driven by a human. This is a known untested surface, not
a claim that it works.

### Push notifications never arrive

There are none, by product decision. The app uses **in-app nudges only**.

## Localisation

### A string shows as its key, or in the wrong language

```bash
flutter gen-l10n
```

`flutter pub get` also runs it (`generate: true` in `pubspec.yaml`).

Strings live in `lib/l10n/app_en.arb` (the template) and `lib/l10n/app_he.arb`;
`l10n.yaml` drives the codegen. Add a key to the template **with a `@key`
description**, add its translation to every other locale, then regenerate.

Adding a locale is `app_<code>.arb` plus a full set of keys; `supportedLocales`
follows the generated table automatically.

### CI fails with an untranslated locale

A key exists in the template and not in `app_he.arb`. That gate is real and it
is the one to satisfy.

### Why is there no stale-l10n gate?

Deliberately absent — it was checking for a defect it had itself created. See
*Translating* in the README.

### The Hebrew reads oddly

Known, and honestly stated. The machinery is complete and tested — both locales
are key-for-key, plurals are per-locale, all 312 catalog names are present and
unique, and the tests assert the *words* change and not just the direction.

But "complete and grammatical" is not "reads the way a ben-Torah would say it".
It wants one pass by a native speaker, and it is a contained job: the app's own
sentences are all in `lib/l10n/app_he.arb`, and the sefer names are all in
`nameHebrew` fields in `assets/catalog/catalog.json`. **Those are the only two
files such a pass has to touch.**

## The database

### A migration failed

The schema has **two versions**, and the doorman refuses everything else —
**refusing leaves the file untouched**, which is what makes "open it with the
build that wrote it and export a backup" a real recovery rather than a sentence.

A bump without a step fails at the door rather than silently doing nothing.

The one real step is **v2**, which drops `unit_index` from `layer_configs`. It
is the first migration in this project's life written for data somebody might
mind losing, and it carries an idempotency guard: `alterTable` commits as it goes
while drift stamps `user_version` only at the end, so a run that dies in between
must be replayable rather than fatal.

`test/data/schema_test.dart` holds all of it, including a fresh database compared
against the schema read off the real device file the deleted chain produced.

### Where did the twelve-step migration chain go?

Squashed to v1; the history is in git. None of the thirteen shapes ever shipped —
every step existed to carry a database on the author's own machine from one
afternoon's schema to the next, and a chain that long starts eating itself: v3
added a column so that v8 could merge it away and drop it, and v9 had to be
written above v8 so v8's table rebuild had a column to copy.

It cost 230 lines of migration and 649 of test, and the price was still rising.

### A sefer appears under a strange parent

The catalog is a **forest, guaranteed** — every parent link resolves and no node
is its own ancestor, because anything arriving otherwise is **repaired on the way
in**: the offending link is detached, so the node becomes a top-level sefer you
can see and re-file, rather than being deleted or refused.

So a sefer at the top level that you did not put there is that repair having
happened. The bundled data is a tree, but the per-profile override layer is not
obliged to be — one row whose id matches a built-in replaces that node's parent,
so a single hand-edited line can file a sefer under its own descendant.

## CI and gates

CI runs, on every push and pull request:

- `flutter analyze --fatal-infos`
- the full suite
- per-layer coverage floors
- stale-codegen
- untranslated-locale
- a release APK build **and an assertion that R8 actually ran**
- a release Windows build **and an assertion that it produced an executable**

### There is no `dart format` gate, and that is deliberate

The source is hand-wrapped so its explanatory comments read as prose, and the
formatter reflows about a hundred files against that. Match the wrapping of the
code around you; `flutter analyze --fatal-infos` enforces what matters.

Do not add one without discussing it.

### CI is green and I do not trust it

Reasonable instinct, and there is precedent: for a long time CI **was not running
at all** — the workflow existed while the work sat uncommitted, so nothing it
promised was being enforced.

It is green on `main` now, and the specific things it fails on are listed above.

## Behaviour that looks wrong and is not

### The heatmap shows a day I later un-marked

Correct. The log is folded twice into two indexes, and an un-marked daf leaves
the first and stays in the second: **the heatmap is a record of a day, not a
claim about today.**

`LogFold` answers *what is learned now* — membership per unit, which is what the
tree, the chazara schedule and a siyum want. `LogActivity` answers *what
happened, and when* — the log indexed by calendar day, which is what pace,
streak, heatmap, minutes and the "have I recorded anything today" nudge want.

### A count is wrong

There are no stored counts. Counts, percentages, roll-ups, pace and predictions
are **folds over the append-only event log, never stored** — which is the whole
point of the rewrite. The original stored a single aggregate as the source of
truth, which made `learned > total` bugs possible.

So a wrong count is a wrong fold, and the log itself is intact. Export a backup
before investigating.

### Predictions look pessimistic or optimistic

They are computed from **your actual pace**, not from a target. A week off moves
them.

---

## Before you push

```bash
flutter analyze --fatal-infos
flutter test --coverage
dart run tool/check_coverage.dart
```

And if you are about to measure anything on real hardware, read
[MEASURING.md](MEASURING.md) first — **several of the obvious instruments read
zero on Flutter and look authoritative doing it.**

## Reporting something not on this page

Include the platform (Windows / Android / the Sonim), the Flutter version,
whether `build_runner` had been run, and for anything data-shaped, whether you
can still export a backup.
