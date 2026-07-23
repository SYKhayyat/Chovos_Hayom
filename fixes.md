# Chovos Hayom — Production-Readiness Assessment & Fix List

> **Assessment date:** 2026-07-23 · **Commit at time of review:** `6d36596` (plus a large uncommitted working tree)
> **Verified by:** `flutter analyze` (clean), `flutter test` (122 pass), catalog JSON validation (312 nodes / 12,092 units), and a benchmark of the derive engine.

---

## How this work must be done

**Everything in this document must be built to the highest standard — not patched, not worked around, not "good enough for now."**

This is the bar for every fix below:

- **Fix the cause, never the symptom.** If a bug exists because a design decision was half-implemented, finish the design. Do not add a guard that hides the failure. If a value is wrong, find why it is wrong — do not clamp it.
- **The domain layer stays pure and framework-free.** `domain/` must remain plain Dart with no Flutter, no Riverpod, no I/O. Every fix that involves logic belongs in `domain/` or `application/`, with the UI reduced to display and intent.
- **Every fix ships with tests.** A correctness fix ships with a test that fails before it and passes after. A performance fix ships with a benchmark or an assertion about work done. The suite must stay green; never weaken or delete a test to make a change pass.
- **Single source of truth, always.** The append-only event log is the truth; everything else is derived. No fix may introduce stored derived state, a second fold, or a cached count that can drift.
- **Nothing is un-configurable.** No default may be locked. Where a fix introduces behaviour, the user must be able to change it, and user edits overlay built-ins rather than replacing them.
- **Efficient and snappy.** Single-pass derivations. No O(all events) work in a widget `build`. No duplicated folds. Nothing that degrades as the user's history grows — the users with the most history are the ones you most want to keep.
- **Desktop-accessible.** Every action must be reachable with mouse and keyboard. Never assume a touchscreen, and never make long-press the only path to a feature.
- **Data is sacred.** Destructive or large-scale actions confirm first and are undoable durably — not via a SnackBar that vanishes in four seconds. Never make a user's history unrecoverable.
- **Validate at trust boundaries.** Anything entering from a file, clipboard, or backup is hostile until proven otherwise. Malformed input must produce a clear error, never a persisted corruption that bricks the app.
- **Comments explain *why*, not *what*.** Match the density and voice of the surrounding code — the existing codebase does this well; keep it that way.
- **Finish the whole item.** If part of a fix is blocked, complete everything else and say plainly what was left and why. Do not silently narrow scope.
- **Update `README.md`** whenever a fix changes what the app does or claims. Documentation drift is a defect.

Where the README currently overclaims (backup completeness, node-level mefarshim configuration, siyumim coverage, "learning cycles" plural), the correct resolution is to **build the feature up to the claim**, not to soften the claim.

---

## Verdict

I read the whole codebase, ran `flutter analyze` (clean) and `flutter test` (122 pass), validated the catalog JSON, and benchmarked the derive engine. Here's the honest assessment.

**Architecturally this is genuinely good work — better than most hobby apps and better than a lot of shipped ones. But it is not ready for serious production use.** It can't be released as-is (debug-signed, wrong app name), it has one data-loss trap that a user will hit, a backup that silently doesn't back everything up, and a headline feature whose UI is only half-wired. Call it a strong beta.

---

## 1. Ship blockers (packaging, not code)

| Issue | Where |
|---|---|
| Release builds sign with the **debug key** — cannot go to Play Store | `android/app/build.gradle.kts:32` (the TODO is still there) |
| App name in the launcher is `chovos_hayom`, not "Chovos Hayom" | `android/app/src/main/AndroidManifest.xml:3` |
| Stock Flutter launcher icon; Windows window/exe is `chovos_hayom` | `android/app/src/main/res/mipmap-*`, `windows/CMakeLists.txt:7` |
| Version pinned at `1.0.0+1` since scaffolding | `pubspec.yaml` |
| No CI — `flutter analyze`/`test` are green but nothing enforces that | no `.github/workflows` |
| No crash reporting of any kind | — |
| `android:allowBackup` / data-extraction rules never considered — Android auto-backup will ship your SQLite DB to Google by default | manifest |

Also: 30 packages are behind (`file_picker` 8.3.7 vs 11.0.2). Fine today, a problem when you need a fix.

## 2. Correctness and data-integrity

**a) "Finish all" is an unconfirmed, effectively irreversible 12,000-unit write.** `ProgressTile`'s ⋮ menu offers *Finish all / clear all* on **every** node including the root — `lib/features/dashboard/progress_tile.dart:108`. *Clear all* confirms; **Finish all does not** (`bulk_actions_sheet.dart`, `_run`). One mis-tap on a category writes a `done` event for every daf underneath. The only undo is a SnackBar action that vanishes in ~4 seconds. After that, the sole recovery is *Clear all* — which also wipes the progress you legitimately had. There is no event-log browser, no "undo last batch", no restore point. This is the single most likely way a real user loses real data.

**b) Goals are silently excluded from backup.** Goals live in `shared_preferences` under `goals:$profileId` (`lib/application/goals.dart:11`), but `SettingsNotifier.toBackup()` (`lib/application/settings.dart:166`) enumerates only the fixed `PrefKeys` list. So export → wipe → import loses every goal. The README claims "A full backup and settings export/import/clear round-trips it all." It doesn't. Deleting a profile also leaves its `goals:` key orphaned forever (`ProfilesController.delete` only touches DB tables).

**c) Import is unvalidated and non-atomic.** `BackupService.importInto` (`lib/application/backup_service.dart:99-121`) inserts events one-at-a-time in a loop with no transaction, then writes custom nodes with **zero validation**. A hand-edited or truncated backup with a negative `unitCount` gets persisted, and then `RollUp._build`'s `node.unitIndices` throws `RangeError` on every dashboard build — a permanent red screen with no in-app recovery (the bad row is in SQLite). A `parentId` cycle does the same to `InheritedLayerSet.forNode`'s recursion. The UI validates `count <= 0` on the add-node form; the import path — the actual trust boundary — validates nothing. A half-failed import also leaves partial data behind.

**d) Nothing is time-reactive.** `clockProvider` is `Provider<DateTime Function()>((ref) => DateTime.now)` (`lib/application/stats.dart`). Nothing invalidates it. Leave the app open across midnight and the streak, the "you haven't learned today" nudge, the chazara due badge, and today's Daf Yomi are all stale until some unrelated event forces a rebuild. On desktop, where the app stays open for days, this is visible.

**e) Chazara from the Chazara screen loses the mefarshim.** `chazara_screen.dart` calls `markReview(nodeId, unitIndex)` with the default `layers: [main]`. The Add-chazara sheet defaults to "everything currently learned." Same action, two different recorded meanings depending on where you tapped.

**f) Deleting a custom meforish leaves dangling references.** `mefarshim_config_sheet.dart`'s delete button removes the `CustomLayers` row but not the `RequiredLayerConfigs`/`OfferedLayerConfigs` entries or the `layersJson` in past events. If it was *required* anywhere, those units become uncompletable except via a checkbox labelled with a raw UUID (the "safety" fallback in `unit_layers_sheet.dart:50`). No confirmation dialog either.

**g) Smaller ones:** `cloneStructure` drops `unitNames` (`catalog_editor.dart`) — clone a subtree and the named units become numbers. The Notes Journal and Chazara screens format units as `'$label $unitIndex'` instead of `node.unitDisplay()`, so named units show as numbers there too. `ChazaraSchedule.due` splits its composite key on the *first* space (`key.indexOf(' ')`) — safe today because all IDs are slugs or UUIDs, but it's a `FormatException` waiting for the first ID with a space. TextEditingControllers leak in `settings_screen.dart:296` and both `profiles_screen.dart` dialogs.

## 3. Performance

I benchmarked the derive engine against the real 312-node / 12,092-unit catalog with an 8,000-event log (a serious multi-year user):

```
fold=236ms   forest=169ms   siyum=314ms      (debug JIT; AOT is several × faster)
```

Even discounting JIT by 5×, that's ~140ms of synchronous UI-isolate work, and it runs **on every single tap of a daf**. Worse, the work is duplicated:

- `SiyumFinder.completed` calls `FoldLog.fold(events)` **a second time** (`lib/domain/usecases/siyum.dart:35`) instead of using the shared `foldProvider` — directly contradicting the comment on `providers.dart:311` explaining why the fold is shared.
- `RollUp._build` iterates *every unit of the catalog* (`roll_up.dart:36-42`) for per-layer coverage, not just the marked ones — `MefarshimStats` already shows the cheap way to do it.
- `statsProvider`, `chazaraDueProvider`, and `nodeLastActivityProvider` each re-sort or re-scan the full log on the same invalidation.
- `UnitGridScreen._grid` (`unit_grid_screen.dart:87`) scans the entire event log to build the `annotated` set on every grid rebuild.
- Both `progressForestProvider` and `progressNodeProvider.family` build overlapping subtrees.

SQLite itself is off the main isolate (drift_flutter spawns one), so the I/O is fine — it's the Dart fold that isn't. This contradicts your standing "snappy, single-pass derivations" preference, and it's the thing that degrades as the user's history grows, i.e. exactly the users you most want to keep.

## 4. Intent vs. implementation

**Mefarshim can only be configured on a leaf.** `showMefarshimConfigSheet` has exactly one caller: the unit-grid app bar (`unit_grid_screen.dart:44`). The tree's node menu has no Mefarshim entry. But the whole `InheritedLayerSet` engine, its tests, and the README ("configured at any node and inherited down") are built around pinning at a *high* node. As shipped, "require Rashi across all of Shas" means opening 37 mesechtos one at a time. The domain is right; the UI never exposed it. This is the biggest gap between what was designed and what a user can actually do.

**Logging details and mefarshim are mutually exclusive.** Tapping a layered unit opens the checklist, which calls `markDone(..., layers: [id])` with no date, duration, or haara — there's no way to record "I learned Rashi on this daf for 40 minutes and here's my chiddush." Conversely the long-press "Log with date/duration/note" always writes `layers: [main]`, so on a layered unit it only marks the text. Two features that were each built well don't compose.

**The session timer only works if you stare at it.** It's a `Stopwatch` inside a modal sheet (`log_unit_sheet.dart`). Dismiss the sheet — or, on Android, get the sheet torn down — and the elapsed time is gone. A learning-session timer that can't survive you closing the sheet and going to learn is not usable for its stated purpose.

**Settings are global, but data is per-profile.** `SettingsState` is entirely in `shared_preferences`. Switch profiles and you keep the previous user's calendar, theme, RTL, sort, chazara intervals, and meforish-bar toggles. Meanwhile `Profiles.settingsJson` exists in the schema, is written on create, and is never read — dead weight that shows the original intent was per-profile.

**Siyumim only fire on leaves** (`siyum.dart`). Finish all of Seder Moed, or all of Nach, and nothing is recorded. For an app whose emotional payoff is the siyum, that's a real miss.

**"Learning cycles" is one cycle.** Only Daf Yomi Bavli, matched by regex-normalized name comparison (`cycles_screen.dart:_norm`) with no user-editable mapping and no fallback if a transliteration differs. No Mishna Yomi, Amud Yomi, Rambam Yomi, Daf Yomi Yerushalmi. The button also reads "Logged for today ✓" when it actually means "this daf is done, ever."

## 5. Code quality

The good, and it's substantial: the append-only event log with everything derived is the right call and is executed cleanly; `domain/` is pure, well-commented, and genuinely testable; the migration strategy in `database.dart` is idempotent, guarded, and better-reasoned than most production migrations I read; `InheritedLayerSet` is an elegant unification of required/offered; the hand-rolled stable merge sort in `sorting.dart` is correctly justified. Comments explain *why*, not *what*. 122 tests, analyzer clean at default lints.

Nits: `flutter_lints` with **zero** additions — no `use_build_context_synchronously` hardening beyond the default, no `always_declare_return_types`, no `prefer_const_constructors` enforcement. `InMemoryProgressRepository` ships in `lib/` but is used only by tests. `LearningEvent.copyWith` (null = keep) and `withDetails` (null = clear) sitting side by side is a footgun, mitigated only by a comment. Error handling is inconsistent — `unit_grid_screen.dart:129` wraps a write in try/catch with a SnackBar; the identical write 60 lines down in `_cellMenu` is fire-and-forget. No routing abstraction (raw `MaterialPageRoute` everywhere), which is fine now and painful the day you want deep links or state restoration. README says 113 tests; there are 122.

Process: your working tree has ~35 modified files and 13 untracked ones uncommitted — an entire phase of work outside version control.

## 6. What I'd fix, in order

1. Confirmation dialog on bulk *finish* (with the unit count), and a durable undo — persist the last batch's event IDs so undo outlives the SnackBar.
2. Include goals in `toBackup()`; clear `goals:$profileId` on profile delete.
3. Validate imported `customNodes` (unitCount ≥ 0, no parent cycles, parent exists) and wrap the whole import in one transaction.
4. Fix signing config + app label + icon. That's the difference between "can't ship" and "can ship."
5. Add a Mefarshim entry to the tree's node menu — the engine is already there, this is a menu item.
6. Make `clockProvider` tick (a `StreamProvider` on a midnight boundary, or a lifecycle-resume invalidation).
7. Kill the second fold in `SiyumFinder`, and make `RollUp` walk marked units instead of all 12k.
8. Let the layered checklist carry date/duration/haara.

The foundation is sound enough that all eight of these are contained changes, not rewrites — which is the real compliment to the architecture.
