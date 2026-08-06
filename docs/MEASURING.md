# Measuring this app on real hardware

Everything here was learned by getting it wrong first, during two adversarial grading rounds against
a release build on a moto g stylus 2025 and on Windows. It is kept because none of it is recoverable
from the source: these are facts about the *instruments*, and every one of them looked authoritative
while reading nothing at all.

The rule underneath all of it: **audit the instrument before you trust its readings.** An assertion
made against a system in the wrong state fails toward false positives — it tells you there is a bug.

---

## Auditing the test suite before trusting it

The same rule turned on the suite. Two techniques, both cheap enough to repeat whenever the suite
starts feeling like reassurance rather than evidence:

- **Mutation testing.** Apply a deliberate defect to `lib/`, run the whole suite, revert. Five
  mutations, five killed: `RollUp` dropping its out-of-range clamp, the backup validator skipping
  its parent-cycle check, `FoldLog` clearing the learned-date on a partial un-mark, `importInto`
  ignoring its mode and never deleting stale events, and event validation dropping the
  negative-duration check. What you are looking for is the assertion that *cannot* fail — the
  "delete the line, then assert the line is gone" shape, the swallowed exception, the `|| true`.
- **Break a CI gate on purpose.** Deleting one key from `app_he.arb` and running `flutter gen-l10n`
  should turn `l10n_untranslated.json` into `{"he": ["thatKey"]}`, which the translation step fails
  on. A gate nobody has watched fail is a gate nobody knows is wired up.

The general form is `test/features/sheet_insets_test.dart:200` — a deliberate negative control that
feeds the checker a knowingly-broken sheet and *requires* the assertion to fail. A geometry check
that cannot fail is what let a dead button ship.

---

## Instruments that measure nothing on Flutter

Three ways to look for jank over ADB. All three are standard Android advice. None of them work here.

| Oracle | Why it is silent |
|---|---|
| `logcat \| grep "Skipped N frames"` | `Choreographer` watches the Android **main** thread. Dart runs on Flutter's own UI thread, so the frames it drops are invisible to it. |
| `dumpsys gfxinfo <pkg>` | reports `Total frames rendered: 0`. Flutter does not render through HWUI. |
| whole-screen pixel diff after a keystroke | **misleading, which is worse than dead.** `TextEditingController` repaints `EditableText` itself, *before* the parent's `setState` runs the expensive compute. The character appearing on screen looks exactly like the answer arriving. |

What did work, and is the shape to reach for: **hash only the region that displays the answer**, run
a cheap input first as a control to measure the probe's own cost, and amplify by repeating the input
ten times so the signal clears the noise.

Stopping at oracle 1 or 2 reports "no jank found". Stopping at oracle 3 reported ~500 ms of jank
that was not there. The failure modes point in opposite directions, which is the argument for
building the control rather than trusting the first number that appears.

---

## Traps on the desktop side

- **A DPI-unaware host lies about window geometry and screenshots.** A PowerShell host that has not
  called `SetProcessDpiAwarenessContext` gets `GetWindowRect` reporting 1280×720 for a real 1600×900
  window, and `CopyFromScreen` captures the top-left corner of the window rather than the window.
  The screenshots are vivid and look like the app clipping its own right edge on every row. It is
  the capture. This is the single most convincing false finding either round produced.
- **`IsIconic` first, always.** A minimized window reports its rect as roughly 226×32 at
  −25600,−25600 — and −25600 is −32000 scaled by 125% DPI, so even the nonsense is DPI-scaled
  nonsense.

---

## Traps on the device side

- **A stored crash record is evidence about the build that wrote it, not about the one running.**
  `adb install -r` preserves app data and the in-app crash log is append-only, so a failure from a
  previous build sits there dated *today* and reads as live. Three independent ways to tell, all
  worth checking before spending an afternoon on a fixed bug: compare its timestamp against when the
  current run started; look for it quoted verbatim in an older report; and check whether its stack
  points at line numbers that still exist. Ours pointed at `settings_screen.dart:395` when the
  method had moved to 409.
- **Another app can steal the foreground mid-measurement.** One app on the test device foregrounded
  itself every ~30 seconds, which ate several injected taps and one whole screenshot. Check
  `topResumedActivity` around anything that depends on where a tap landed — it is the only thing
  that distinguishes "my tap opened Recents" from "another app took focus".
- **Give a screen time to load before you dump it.** Reading the crash log 3 seconds after opening it
  showed nothing and got reported as empty. The dump was racing the screen's load.

---

## Findings that were correct by design

Two that survived to the edge of being filed, both worth knowing before re-deriving them:

- **The backup reminder "overcounts".** It reported 14 units unsaved after 1 unit was learned.
  `BackupReminder.evaluate` counts distinct units *touched* since the export and deliberately
  includes un-marks — the probing itself had touched the extra units. It says so in a comment.
- **An export filename typed without an extension writes a file with no `.json`.** Android's picker
  takes the name literally, and `withJsonExtension` only guards the desktop path, where the app does
  the writing. Checked rather than assumed: the import picker lists the extension-less file anyway
  and it opens, and the default filename the app supplies already ends in `.json`.

---

## What a phone found that no test could

Kept as the argument for running on hardware at all. Each of these had passing tests over it:

- A confirm button sitting under the three-button navigation bar. The sheet was correct; its
  *buttons* were in the system's 135px band, so the primary logging action opened Recents.
- A progress fraction rendering backwards in Hebrew — `(0.0%)  12,092 / 0` — for want of a bidi
  isolate around the numerals.
- A green "you are backed up" tick on a profile that had never been exported.
- A deep link that opened the right screen from cold and said "Not found" when the app was already
  running. Android delivers the second link through `onNewIntent`, which reaches the framework as
  `pushRouteInformation`, and the framework's default handler rebuilds the route from path + query +
  fragment — **discarding the authority**, which is where this app puts the screen type. Every
  existing deep-link test drove the cold path.

The pattern in all four: the test suite drove the path the author was thinking about. The device
drove the other one.
