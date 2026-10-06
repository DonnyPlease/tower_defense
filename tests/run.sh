#!/usr/bin/env bash
# Runs the test suites; fails on test failures and on any script or engine error.
#
#   tests/run.sh                     unit, smoke, phone and boot tests
#   tests/run.sh balance             balance tests (slow)
#   tests/run.sh smoke --filter=wave only scene tests whose name contains "wave"
#   tests/run.sh boot                start the game as a player does and look at the first frames
#   tests/run.sh web                 the exported web build in a real browser (Playwright)
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

# Starts the game the way a player does (its real main scene, a real window,
# no test runner), records the first 90 frames, and checks the title screen is
# drawn, its demo is moving, nothing was logged as an error, and it quit cleanly.
run_boot() {
  local frames=90
  local dir="$TMP/boot"
  mkdir -p "$dir"
  local -a cmd=("$GODOT" --path "$ROOT" --fixed-fps 60 --audio-driver Dummy --resolution 1000x600
    --rendering-driver opengl3 --write-movie "$dir/frame.png" --quit-after "$frames" --log-file "$dir/godot.log")
  if command -v xvfb-run >/dev/null 2>&1; then
    cmd=(xvfb-run -a -s "-screen 0 1280x800x24" "${cmd[@]}")
  elif [ -z "${DISPLAY:-}" ]; then
    echo "The boot test needs a display (install xvfb)."
    return 1
  fi
  echo "boot: starting the game"
  "${cmd[@]}" >"$dir/stdout.log" 2>&1
  local status=$?
  if [ "$status" -ne 0 ]; then
    echo "  ✗ the game exited with status $status"
    cat "$dir/stdout.log"
    return 1
  fi
  if grep -qE "^(SCRIPT ERROR|ERROR:|USER ERROR|USER SCRIPT ERROR)" "$dir/godot.log"; then
    echo "  ✗ errors were logged while starting:"
    grep -E -A1 "^(SCRIPT ERROR|ERROR:|USER ERROR|USER SCRIPT ERROR)" "$dir/godot.log"
    return 1
  fi
  "$GODOT" --headless --path "$ROOT" -s res://tests/boot/check_boot.gd -- "$dir" "$frames"
}

# The web build in a real browser (needs node, python3 and network access the
# first time): exports it with the Web templates, then plays it with Playwright.
run_web() {
  local version
  version="$("$GODOT" --version | cut -d. -f1-4)" # e.g. 4.4.1.stable
  local templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
  if [ ! -f "$templates/web_nothreads_release.zip" ] || [ ! -f "$templates/web_nothreads_debug.zip" ]; then
    echo "Installing the Web export templates for Godot $version..."
    python3 -m venv "$TMP/venv" && "$TMP/venv/bin/pip" install --quiet remotezip \
      && "$TMP/venv/bin/python" "$ROOT/tests/web/install_template.py" "$version" "$templates" || return 1
  fi
  # The debug build prints script errors to the browser console (the release
  # build, which players get, doesn't), so the tests use both.
  rm -rf "$ROOT/build/web" "$ROOT/build/web-debug"
  mkdir -p "$ROOT/build/web" "$ROOT/build/web-debug"
  "$GODOT" --headless --path "$ROOT" --export-release Web "$ROOT/build/web/index.html" >"$TMP/export-release.out" 2>&1
  "$GODOT" --headless --path "$ROOT" --export-debug Web "$ROOT/build/web-debug/index.html" >"$TMP/export-debug.out" 2>&1
  if [ ! -s "$ROOT/build/web/index.pck" ] || [ ! -s "$ROOT/build/web-debug/index.pck" ]; then
    echo "The Web export failed:"
    cat "$TMP/export-release.out" "$TMP/export-debug.out"
    return 1
  fi
  (cd "$ROOT/tests/web" && npm ci --no-audit --no-fund --silent && npx playwright test "$@")
}

if [ $# -eq 0 ] || [[ "$1" == --* ]]; then
  suites=(unit smoke phone boot)
else
  suites=("$1")
  shift
fi

failed=0
for suite in "${suites[@]}"; do
  case "$suite" in
    web) run_web "$@" || failed=1 ;;
    boot) run_boot || failed=1 ;;
    *) run_suite "$suite" "$@" || failed=1 ;;
  esac
done
exit "$failed"
