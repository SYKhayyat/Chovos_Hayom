# Contributing to Chovos Hayom

Two halves. The first is everything you need to get the app running, find your way around, and make
a change that fits. The second is the standards that change will be held to — read them before you
write code, not after.

- [Start here](#start-here) · [The repo in five minutes](#the-repo-in-five-minutes) ·
  [Making a change](#making-a-change) · [Writing tests here](#writing-tests-here) ·
  [Before you push](#before-you-push) · [Things that will bite you](#things-that-will-bite-you)
- [How this work must be done](#how-this-work-must-be-done) ·
  [A rule that is written down is a rule that will be broken](#a-rule-that-is-written-down-is-a-rule-that-will-be-broken)

---

## Start here

You need the Flutter SDK at the version pinned in `.github/workflows/ci.yml` (`FLUTTER_VERSION`).
Not `stable` — two dependencies are held back precisely because of that version, so tracking
`stable` means building a combination nobody chose. See *Toolchain notes* in the README.

```bash
flutter pub get                 # also runs gen-l10n (pubspec: generate: true)
dart run build_runner build     # generates the Drift and Riverpod code
flutter test                    # 714 tests, about four minutes
flutter run -d windows          # or -d <your android device>
```

If `flutter test` is green, you have a working checkout. Nothing else is needed to work on the
domain, application or data layers — they are all testable without a device.

To run on hardware you also need the platform toolchain (`flutter doctor` will tell you): the
Android SDK command-line tools plus accepted licences, or Visual Studio's *Desktop development with
C++* workload for Windows. Windows desktop builds additionally need **Developer Mode** enabled, for
plugin symlinks.

## The repo in five minutes

```
lib/
  domain/        pure Dart. No Flutter, no Riverpod, no I/O. Entities, folds, predictors.
    entities/      Catalog, CatalogNode, LearningEvent, Layer
    usecases/      FoldLog, LogActivity, LayerRoles, ChazaraSchedule, Predictor, RollUp
    repositories/  the interfaces data/ implements
  data/          Drift (SQLite) and the JSON catalog. Implements domain's interfaces.
  application/   Riverpod providers, services, the things that orchestrate.
  features/      screens and widgets, one directory per area, plus features/common/.
  core/          framework-free helpers everything uses: Day, parse, breakpoints, focus.
  app/           the route table and app shell.
  l10n/          app_en.arb (the template) and app_he.arb.
test/            mirrors lib/, plus test/support/ (harness) and the guard tests.
tool/            check_coverage.dart, generate_icon.py.
docs/            ARCHITECTURE.md (the long form), MEASURING.md (read before benchmarking).
lamdan/          a design review of the whole repo, and what was done about each finding.
```

**The one idea to hold on to:** an append-only event log is the only truth. Counts, percentages,
roll-ups, streaks, pace, predictions and siyumim are folds over it, computed and never stored. If
you find yourself wanting to save a number so you don't have to recompute it, that is the design
telling you the fold is in the wrong place, not that the rule needs an exception.

**Where to start reading**, in this order, and it is about 400 lines total:

1. `lib/domain/usecases/fold_log.dart` — the log becoming state.
2. `lib/domain/entities/catalog.dart` — why the tree cannot lie to you.
3. `lib/core/day.dart` — why a calendar day is not a `DateTime`.
4. `lib/features/common/guarded.dart` — why every write goes through one place.

`docs/ARCHITECTURE.md` is the long form when you want it. `lamdan/` is worth an hour if you are
going to change something structural: it argues about whether the code should exist at all, and
every finding carries what was actually done about it.

## Making a change

A worked example, because the layering is the part that takes longest to learn. Say you want a unit
to record *who you learned it with*.

1. **Domain first.** Add the field to `LearningEvent` — and `learning_event_fields_test.dart` will
   immediately fail six times, once for each place that copies an event by hand (the JSON codecs,
   the Drift mapping, `withDetails`, `rescopedTo`). That is the guard doing its job: a field added
   and missed in one of them is dropped silently, on an import or at rest.
2. **Data.** Add the column in `lib/data/drift/database.dart`, bump `kSchemaVersion`, and write the
   migration step next to the one that is already there. A bump without a step fails at the door on
   the next launch — deliberately, and `test/data/schema_test.dart` holds that.
   Run `dart run build_runner build` to regenerate.
3. **Backup.** If it is user data, it goes in the backup: bump `BackupService.currentVersion` and
   teach `parse` to read the older shape. Old files must keep importing.
4. **Application.** A service method if it is an action, a provider if it is a question. Providers
   that hand out a value type need that type to have real `==` — see `notify_guard_test.dart`.
5. **UI.** A screen displays and expresses intent; it does not compute. Every write goes through
   `guarded(…)` or `guard.run(…)`. Every string is an ARB entry in both `app_en.arb` and
   `app_he.arb` — a whole sentence, never one glued together from a verb and a count.
6. **Test at the lowest layer that can hold the rule.** A fold is a unit test in milliseconds. Reach
   for a widget test when the rule is about what the user sees or does.

## Writing tests here

`test/support/` exists so a test is about its subject and nothing else:

| Helper | What it gives you |
|---|---|
| `memory_database.dart` | `memoryRepository()` — the real Drift repository on an in-memory database. There is no fake repository, on purpose: the fake used to disagree with the real one, and the bug lived in the gap |
| `fake_catalog.dart` | a four-node catalog (`root → shas → shas.moed → shas.moed.shabbos`) with the real ids |
| `localized_app.dart` | `localizedApp(home:, locale:)` — a `MaterialApp` with the localisations installed; pass `Locale('he')` to assert a screen is translated rather than merely mirrored |
| `layer_roles_dsl.dart` | `roles(required: [...], optional: [...])` for mefarshim settings |
| `failing_progress_repository.dart`, `failing_catalog_repository.dart` | repositories that throw where you tell them to, for the error paths |
| `recording_crash_log.dart`, `counting_log.dart` | what was recorded, and how many passes something made over the log |
| `source_scan.dart` | `dartSourcesUnder()` and `codeLines(…, escapeHatch:)` — the shared reader every guard test uses |

Three habits this codebase holds to:

- **Watch the test fail.** A correctness fix ships with a test that fails before it and passes
  after, and you run it against the old code to see it go red. A guard gets fed a real violation.
  Almost every guard test in `test/` ends with a note saying it was.
- **Assert the consequence, not the mechanism.** `expect(saved(prefs).single.id, 'cycle-1')` says
  editing edited; `expect(controller.saveCalled, isTrue)` says nothing about what the user gets.
- **Read state back the way the app will.** Where something persists, assert on the persisted value
  rather than on the notifier that wrote it — the notifier passes just as well when nothing reached
  disk.

Coverage has a floor per layer, checked by `tool/check_coverage.dart` after `flutter test
--coverage`: `domain/` 90%, `application/` and `core/` 85%, `data/` 70%, `features/` 65%, 75%
overall on hand-written code. Each floor sits a few points under where the suite is today, so
ordinary work never trips it and a real slide does. It prints the five least-covered files on every
run, pass or fail.

## Before you push

```bash
dart run build_runner build     # if you touched a table, an entity or a provider
flutter analyze --fatal-infos   # CI runs it with --fatal-infos; so should you
flutter test --coverage
dart run tool/check_coverage.dart
```

Then: does the README still tell the truth? Documentation drift is a defect, and a change that
alters what the app does or claims is not finished until the README says so.

CI runs all of the above on every push and pull request, plus a release APK build with an assertion
that R8 actually ran, and a release Windows build with an assertion that it actually produced an
executable. It also fails if the generated Drift/Riverpod code is stale or if a shipped locale is
missing a string.

## Things that will bite you

- **`flutter test` fails to delete `sqlite3.dll`.** A previous test process is still alive and
  holding it. Kill stray `dart` / `flutter_tester` processes and run again. Two test runs at once
  will do this to you on Windows.
- **A SnackBar in a widget test will cost you an afternoon, twice.** It sits on screen behind a
  *timer*, not an animation. So `pumpAndSettle` after the tap that shows one waits out its full
  ten-minute default — and worse, a test that *ends* while that timer is still pending leaves the
  binding wedged, so the next tests fail with `'inTest': is not true` and a ten-minute timeout each,
  and the file looks like it is hanging somewhere it is not. Both halves are needed:

  ```dart
  await tester.tap(find.text('Save'));
  await tester.pump();                                 // the bar starts coming in
  await tester.pump(const Duration(milliseconds: 750));
  expect(find.text('Give the cycle a name.'), findsOneWidget);
  await tester.pump(const Duration(seconds: 5));       // its timer fires *here*
  await tester.pumpAndSettle();                        // and it leaves
  ```

  While you are at it, give `pumpAndSettle` a real deadline —
  `pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 15))`. The default is ten minutes, which is not a timeout so much as a way
  of turning "this never settles" into a file that appears to hang. `edit_cycle_screen_test.dart`
  wraps that in a local `settle(tester)`.
- **A finder finds nothing in a `ListView`.** Off-screen children are never built, so they are not
  in the tree to be found. Either scroll to it or give the test a taller view
  (`tester.view.physicalSize`), and say which you meant.
- **Stale generated code.** `no such column`, a missing `.g.dart` symbol, or a provider that does
  not exist usually means `build_runner` has not run since you edited a table or an annotation.
- **There is no `dart format` gate, and this is deliberate.** The source is hand-wrapped so its
  explanatory comments read as prose, and the formatter reflows about a hundred files against that.
  Match the wrapping of the code around you; `flutter analyze --fatal-infos` enforces what matters.

---

# How this work must be done

**Everything here is built to the highest standard — not patched, not worked around, not "good
enough for now."** These are the standards every change is held to. They were buried at line 15 of
an 874-line changelog for a month, which is a poor place for the thing a new contributor most needs.

- **Fix the cause, never the symptom.** If a bug exists because a design decision was
  half-implemented, finish the design. Do not add a guard that hides the failure. If a value is
  wrong, find why it is wrong — do not clamp it.
- **The domain layer stays pure and framework-free.** `domain/` must remain plain Dart with no
  Flutter, no Riverpod, no I/O. Every fix that involves logic belongs in `domain/` or
  `application/`, with the UI reduced to display and intent.
- **Every fix ships with tests.** A correctness fix ships with a test that fails before it and
  passes after — and you *watch* it fail, rather than assuming it would. A performance fix ships
  with a benchmark or an assertion about work done. The suite must stay green; never weaken or
  delete a test to make a change pass.
- **Single source of truth, always.** The append-only event log is the truth; everything else is
  derived. No change may introduce stored derived state, a second fold, or a cached count that can
  drift.
- **Nothing is un-configurable.** No default may be locked. Where a change introduces behaviour, the
  user must be able to change it, and user edits overlay built-ins rather than replacing them.
- **Efficient and snappy.** Single-pass derivations. No O(all events) work in a widget `build`. No
  duplicated folds. Nothing that degrades as the user's history grows — the users with the most
  history are the ones you most want to keep.
- **Desktop-accessible.** Every action must be reachable with mouse and keyboard. Never assume a
  touchscreen, and never make long-press the only path to a feature.
- **Data is sacred.** Destructive or large-scale actions confirm first and are undoable durably —
  not via a SnackBar that vanishes in four seconds. Never make a user's history unrecoverable.
- **Validate at trust boundaries.** Anything entering from a file, clipboard, or backup is hostile
  until proven otherwise. Malformed input must produce a clear error, never a persisted corruption
  that bricks the app.
- **Comments explain *why*, not *what*.** Match the density and voice of the surrounding code — the
  existing codebase does this well; keep it that way.
- **Finish the whole item.** If part of a change is blocked, complete everything else and say
  plainly what was left and why. Do not silently narrow scope.
- **Update `README.md`** whenever a change alters what the app does or claims. Documentation drift is
  a defect.

Where the README overclaims, the correct resolution is to **build the feature up to the claim**, not
to soften the claim.

## A rule that is written down is a rule that will be broken

The hardest-won of these, and the one the others depend on. This codebase spent a month enforcing
its rules in prose, and prose does not fail CI: ten separate places stated a principle clearly and
then broke it, usually within a hundred lines, usually written by the person who had just stated it.
`sorting.dart` spent ten lines condemning conditional watches; `dashboard_screen.dart` promised its
subscriptions were unconditional and watched conditionally sixty-eight lines below, in the same
`build` method.

So: **when you establish a rule, write the test that fails when it is broken**, and feed that test a
violation to prove it can fail. `test/` holds a growing set of these — they read `lib/` as text and
fail the build on the shape of the mistake rather than on its consequences:

| Guard | What it refuses |
|---|---|
| `data/dependency_rule_test.dart` | an import of `data/` from anywhere but the two composition roots, and any Flutter/Drift import inside `domain/` |
| `core/day_math_guard_test.dart` | a fifth hand-rolled answer to "which calendar day is this" |
| `application/notify_guard_test.dart` | a family without `autoDispose`, an unselected `settingsProvider` watch, a field added to a value type and left out of its `==` |
| `domain/log_pass_guard_test.dart` | a new function that takes the whole event log |
| `application/backup_parse_once_test.dart` | a second decode of a backup file — the parse is a trust boundary and happens where the bytes arrive |
| `application/profile_delete_test.dart` | a per-profile preference key or a profile-scoped table that profile deletion does not reach |
| `application/import_scope_test.dart` | a store a backup writes into that does not take an `ImportMode` |
| `domain/learning_event_fields_test.dart` | a field added to `LearningEvent` and left out of one of the six places that copy one |
| `domain/layer_role_guard_test.dart` | a second resolver, table or stream of layer settings, and a screen working out a unit's mefarshim from the roles and the fold itself |
| `domain/catalog_forest_guard_test.dart` | a rival cycle check, growing back beside the one `Catalog` guarantees |
| `features/report_guard_test.dart` | a report screen re-added as its own route, and a section wiring up its own D-pad scrolling instead of using `ReportBody` |
| `features/node_picker_guard_test.dart` | a fifth way to offer the catalog — a hand-rolled picker dialog, node dropdown, or list label |
| `features/text_prompt_guard_test.dart` | a dialog that owns its own `TextEditingController` — the shape that throws one frame after it closes |
| `application/profile_customisations_test.dart` | a fourth hand-written read of the three collections a profile has made |
| `core/parse_test.dart` | a hand-written `int.tryParse` on something a person typed |
| `features/write_guard_scan_test.dart` | a user-initiated write that does not go through `guarded()` — the rule `unawaited_futures` was wrongly credited with |
| `l10n/arb_guard_test.dart` | a translated key nothing displays, a key that is its own translation, an `@metadata` block whose message has been renamed out from under it, and a placeholder left undeclared (and therefore typed `Object`) |

The rot mode worth guarding is the **silent** one — the change that compiles, passes, and quietly
stops something working. A field left out of an `==` does not throw; it shows up as a screen that
has stopped updating.

They all read source the same way, through `test/support/source_scan.dart`: comments stripped so
that the docstring explaining a ban does not trip it, generated code skipped, and **an escape hatch
that is a required argument**. That last part is not tidiness. Five of these files had written the
scanner out for themselves and four were byte-identical; the fifth had quietly dropped the escape
hatch, so one rule was a wall while its neighbours were speed bumps and nothing said so. A guard is
supposed to make the next copy argue for itself, not make it impossible.

## Toolchain

See *Developing* in `README.md` for setup, and `docs/MEASURING.md` before you try to measure
anything on real hardware — several obvious instruments read zero on Flutter and look authoritative
doing it.
