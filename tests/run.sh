#!/usr/bin/env bash
# Runs the test suites; fails on test failures and on any script or engine error.
#
#   tests/run.sh                     unit, smoke and phone tests
#   tests/run.sh balance             balance tests (slow)
#   tests/run.sh smoke --filter=wave only scene tests whose name contains "wave"
#
# Unit and balance tests run headless. The scene tests (smoke, phone) need a
# display, so the game is really drawn and the window has its real size: they
# use xvfb-run when it is installed, otherwise $DISPLAY. Without either they
# run headless and skip the checks that need rendering. The phone suite runs
# in an 844 x 390 window (a phone held sideways, so the game is letterboxed).
#
# Set GODOT to the Godot 4.4+ binary if it is not on the PATH as "godot".
set -uo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Scripts' class names are registered by an import (a fresh checkout has no
# .godot/ yet, and new classes need registering too).
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

run_suite() {
  local suite="$1"
  shift
  local log="$TMP/$suite.log"
  # --fixed-fps: every frame advances the game by exactly 1/60 s, as fast as
  # the machine can go (scene tests play whole waves in seconds, deterministically).
  local -a cmd=("$GODOT" --path "$ROOT" --fixed-fps 60 --audio-driver Dummy --log-file "$log")
  case "$suite" in
    smoke | phone)
      local size="1000x600"
      [ "$suite" = phone ] && size="844x390"
      cmd+=(--resolution "$size")
      if command -v xvfb-run >/dev/null 2>&1; then
        cmd=(xvfb-run -a -s "-screen 0 1280x800x24" "${cmd[@]}" --rendering-driver opengl3)
      elif [ -n "${DISPLAY:-}" ]; then
        cmd+=(--rendering-driver opengl3 --disable-vsync)
      else
        echo "No display (install xvfb): the $suite tests run headless and skip what needs rendering."
        cmd+=(--headless)
      fi
      ;;
    *)
      cmd+=(--headless)
      ;;
  esac
  "${cmd[@]}" -s res://tests/run_tests.gd -- "$suite" "--log=$log" "$@" 2>&1 | tee "$TMP/$suite.out"
  local status=${PIPESTATUS[0]}
  # Errors inside a test fail that test (the runner reads the log); this also
  # catches errors outside any test, e.g. while loading scripts.
  if grep -qE "^(SCRIPT ERROR|ERROR:|USER ERROR|USER SCRIPT ERROR)" "$TMP/$suite.out"; then
    echo
    echo "Script or engine errors were reported in the $suite suite (see above)."
    return 1
  fi
  return "$status"
}

if [ $# -eq 0 ] || [[ "$1" == --* ]]; then
  suites=(unit smoke phone)
else
  suites=("$1")
  shift
fi

failed=0
for suite in "${suites[@]}"; do
  run_suite "$suite" "$@" || failed=1
done
exit "$failed"
