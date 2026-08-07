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
| `core/day_math_guard_test.dart` | a fifth hand-rolled answer to "which calendar day is this" |
| `application/notify_guard_test.dart` | a family without `autoDispose`, an unselected `settingsProvider` watch, a field added to a value type and left out of its `==` |
| `application/log_pass_guard_test.dart` | a new function that takes the whole event log |
| `application/import_scope_test.dart` | a store a backup writes into that does not take an `ImportMode` |
| `domain/layer_role_guard_test.dart` | a second resolver, table or stream of layer settings |
| `features/report_guard_test.dart` | a report screen re-added as its own route, and a section wiring up its own D-pad scrolling instead of using `ReportBody` |
| `features/node_picker_guard_test.dart` | a fifth way to offer the catalog — a hand-rolled picker dialog, node dropdown, or list label |
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

There is deliberately **no `dart format` gate**. The codebase is hand-wrapped so the explanatory
comments read well, and the formatter reflows about a hundred files against that. `flutter analyze
--fatal-infos` enforces what actually matters.
