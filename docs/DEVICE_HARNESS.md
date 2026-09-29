# The device harness

`integration_test/device_harness_test.dart` runs the real app on real hardware
and drives it the way a person does. It is the half of the testing that cannot
happen on your machine.

```bash
tool/run_device_harness.sh --list     # what would run; needs no device
tool/run_device_harness.sh            # every journey, on the attached device
tool/run_device_harness.sh --keys     # same journeys, through the D-pad
tool/run_device_harness.sh --shots    # and collect screenshots
tool/run_device_harness.sh --only planner/plan
```

## Why it exists

Everything in `test/` runs against Ahem, a font where every glyph is the same
wide box, at whatever size a `TestFlutterView` was told to be. That is the right
instrument for logic and the wrong one for layout. Two defects found in this
repository were invisible to the suite and obvious within a second of looking at
a phone:

- a segmented control rendering its range as `Mo / nth` — the month label did not
  fit, and no box-and-glyph arithmetic would have said so;
- a month cell shrinking to 78% of its allotted width to make room.

Both are *type* defects. Neither had a failing test, because the suite was
rendering in a font no device has. A harness that runs the real font at the real
size is the only thing that catches them.

The harness exists for the four things a host cannot see, and one of them is not
about layout at all:

| Blind on a host | What the harness sees |
| --- | --- |
| Real type — every glyph an identical box | The real font, the real metrics, and whether a label fits |
| Real size — one arbitrary viewport | The device's own viewport **and** the other phone's, in one run |
| Real input — a tap | The focus tree and the centre key, which is the Sonim's only input |
| Real wiring — fakes standing in | Real `main()`, real Drift, the real 312-node catalog with its Hebrew names |

## What a run does

Each journey is a **task**, not a route. It opens a drawer like a person, taps a
label, and then checks a *consequence* — that the name is now on screen, that a
mark is still marked after a rebuild, that a number changed. Journeys that only
checked "the screen did not throw" would pass against a screen that renders
nothing at all, so there is a `SomethingIsShown` step and there are `See` steps.

Journeys are written to be **tolerant about wording and strict about behaviour**.
`TapAny` is given every label a thing might be called, because this was written
without a device attached and a wrong guess about copy should cost one edit to a
list rather than a rewrite of the journey. What it will not do is accept the
wrong *outcome*: if a journey says a mark should be visible and it is not, that
is a failure.

### The two input paths

`--keys` runs the same journeys with `HARNESS_INPUT=keys`, which types and
presses instead of tapping: it walks the focus tree to the next focusable thing
and presses the centre key. This is the only input a Sonim XP5s has, and a suite
that only taps has tested the Moto and skipped the phone the compact layout
exists for. Run both before believing a journey works.

### Why journeys are written as if the person is new

Every step names what is on screen (`Settle`) or what should be found (`See`).
When a step fails, the harness prints what *was* there, so triage is reading a
line of output rather than reading code. The first run on real hardware should
be expected to fail; treat each failure as a harness bug until it is proved
otherwise, and change the *journey* rather than the app when the app is right.

## Coverage

`test/app/device_harness_coverage_test.dart` keeps the catalogue honest, in both
directions, and runs in CI:

- **every route in `Routes` is claimed** by at least one journey — including the
  *families* (`/sefer/<id>`, `/category/<id>`, `/edit-item/<id>`,
  `/cycles/edit/<id>`), because those are reached by tapping a name rather than by
  choosing a destination, and a drawer inventory cannot find them;
- **no journey claims a screen it does not open** — a claim on a journey that
  does not exist reads as coverage that is not there, which is the more dangerous
  failure;
- journey ids are unique and carry an area, because the report and the
  screenshots are keyed on them;
- the D-pad path exists and is reachable.

The claims are declared in `integration_test/harness/coverage.dart`, so the table
is the answer to "what does this actually test?" and not something you have to
reverse-engineer from a run.

## Screenshots

`--shots` writes PNGs to `build/screenshots/`. They need `flutter drive` and
`test_driver/integration_test.dart`, because on Android the Flutter surface must
be converted to an image and the bytes have to come back across the wire — which
is what the driver is for, and why `flutter test` does not do it.

Screenshots are the point of the exercise, not a side effect: they are what a
person actually looked at. This version of `integration_test` documents a
`revertFlutterImage` that the class does not have, so nothing is converted back.
That is only a problem for whatever runs after the harness, which is nothing.

## Viewports and text scale

Each run sweeps the native viewport **first** — it is the one that is really
this phone, and the one whose screenshots mean anything — and then the other
phone's, so one device can stand in for the other. `1.3x` text is applied too:
`MediaQuery.textScalerOf` is always `1.0` in a test, which is exactly why large
text is a device-only concern. The OS scale is read *before* anything overrides
it, so the header reports the device's setting rather than the harness's.

## Linux

The harness itself is platform-agnostic — it is `integration_test`, and it runs
on a desktop the same as on a phone. The repository currently has `android/`
and `windows/` and no `linux/` target, so a Linux run needs the target and a
toolchain first:

```bash
flutter create --platforms=linux .
# plus clang, ninja-build, and GTK3 development packages
tool/run_device_harness.sh          # with the desktop as the only device
```

That is a deliberate gap rather than an oversight: adding a platform target is a
product decision, and the harness is written so that the day there is one, no
journey needs to change.

## When a run fails

The report at the end of the run lists every journey, its steps, and what was on
screen when it stopped. A failing run is still a useful run — it is the first
thing to check before a widget test, and the only thing that can catch a defect
in the real font.
