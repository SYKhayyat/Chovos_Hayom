#!/usr/bin/env bash
# Run the device harness: the app, driven as a person drives it, on real
# hardware.
#
# **The widget suite cannot see four things this can**: the real font (every test
# renders in Ahem, every glyph the same wide box), the real size of either phone,
# the real input path (a D-pad and a numeric keypad, no touchscreen), and the
# real app — real storage, real catalog, real 312 nodes with their Hebrew names.
# Two of the last layout defects in this repository were invisible to the suite
# and obvious within a second of looking.
#
# Two ways to run, and the difference is worth knowing:
#
#   flutter test integration_test/device_harness_test.dart -d <id>
#     Fast, no screenshots. This is the loop you iterate in.
#
#   flutter drive --driver=test_driver/integration_test.dart \
#                 --target=integration_test/device_harness_test.dart -d <id>
#     Slower, and writes build/screenshots/*.png so a person can look at what
#     the device showed. This is the one that finds "the label does not fit".
#
# Usage:
#   tool/run_device_harness.sh                 # every journey, on the only device
#   tool/run_device_harness.sh --keys          # drive it with the D-pad instead
#   tool/run_device_harness.sh --shots         # and collect screenshots
#   tool/run_device_harness.sh --only planner  # one area, while fixing it
#   tool/run_device_harness.sh --list          # what would run, and nothing else
set -euo pipefail

cd "$(dirname "$0")/.."

INPUT=pointer
SHOTS=0
ONLY=""
LIST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --keys) INPUT=keys; shift ;;
    --pointer) INPUT=pointer; shift ;;
    --shots) SHOTS=1; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH. Install it, or run this with the full path." >&2
  exit 1
fi

# Devices, and a clear failure rather than a confusing one when there is not
# exactly the one you meant. `flutter test -d` with a bad id picks *something*,
# and a harness run on the wrong phone is a wasted afternoon.
DEVICES="$(flutter devices --machine 2>/dev/null \
  | grep -o '"id":"[^"]*","name":"[^"]*"' || true)"
ATTACHABLE="$(printf '%s\n' "$DEVICES" | grep -v '"targetPlatform":"web"' || true)"

if [ "$LIST" = "1" ]; then
  # Read the catalogue out of the guard test rather than parsing the journey
  # files with a shell script, so this listing and the coverage table cannot
  # disagree. Needs no device: that is the point of it.
  echo
  flutter test test/app/device_harness_coverage_test.dart \
    --plain-name "catalogue: the journeys, in a form a person can read" 2>&1 \
    | sed -n '/--- harness catalogue:/,/--- end catalogue ---/p' \
    | sed 's/^ *//;s/^--- //'
  echo
  echo "Run one area:  tool/run_device_harness.sh --only planner/plan"
  exit 0
fi

COUNT="$(printf '%s\n' "$ATTACHABLE" | grep -c '"id"' || true)"
if [ "$COUNT" -eq 0 ]; then
  cat >&2 <<'EOF'
No device found.

  * A phone must be connected with USB debugging on, and `adb devices` must
    list it. Check `flutter devices`.
  * A Linux desktop works too — `flutter run -d linux` — though the repo has no
    linux/ platform folder yet, so it needs `flutter create --platforms=linux .`
    and a clang/ninja/GTK toolchain first.
EOF
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  echo "More than one device is attached; say which:" >&2
  printf '%s\n' "$ATTACHABLE" | sed 's/.*"id":"\([^"]*\)","name":"\([^"]*\)".*/  \1  \2/' >&2
  echo >&2
  echo "Then re-run with a -d flag added, e.g. SHOTS=1 DEVICE=<id> $0" >&2
  exit 1
fi

DEVICE="$(printf '%s\n' "$ATTACHABLE" | sed 's/.*"id":"\([^"]*\)".*/\1/')"
NAME="$(printf '%s\n' "$ATTACHABLE" | sed 's/.*"name":"\([^"]*\)".*/\2/')"
echo "Device: $NAME ($DEVICE)   input: $INPUT   shots: $SHOTS${ONLY:+   only: $ONLY}"

# A journey that hangs must not hang the run, and neither must the app. The
# package's own default is five minutes for the whole suite, which is shorter
# than a full pass of every journey on a slow phone, so the timeout is set here
# and said out loud rather than left to surprise someone.
DEFINES=(--dart-define=HARNESS_INPUT="$INPUT")
[ "$SHOTS" = "1" ] && DEFINES+=(--dart-define=HARNESS_SHOTS=1)
[ -n "$ONLY" ] && DEFINES+=(--dart-define=HARNESS_ONLY="$ONLY")

if [ "$SHOTS" = "1" ]; then
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/device_harness_test.dart \
    -d "$DEVICE" \
    "${DEFINES[@]}"
else
  flutter test integration_test/device_harness_test.dart \
    -d "$DEVICE" \
    "${DEFINES[@]}"
fi

echo
echo "Screenshots (if any) are in build/screenshots/."
echo "Clear the app's data between runs if you want a clean start:"
echo "    adb shell pm clear com.sykhayyat.chovos_hayom"
