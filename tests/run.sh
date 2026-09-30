#!/usr/bin/env bash
# Runs the headless test suites and fails on test failures *and* on any engine
# or script error (GDScript has no exceptions, so a crashing test only shows
# up as an error in the log).
#
#   tests/run.sh                  unit + smoke tests
#   tests/run.sh balance          balance tests (slow)
#   tests/run.sh unit --filter=maze
#
# Set GODOT to the Godot 4.4+ binary if it is not on the PATH as "godot".
set -uo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Scripts' class names are registered by an import (a fresh checkout has no
# .godot/ yet, and new classes need registering too).
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

# --fixed-fps: every frame advances the game by exactly 1/60 s, as fast as the
# machine can go (scene tests play whole waves in seconds, deterministically).
# --resolution: a window as big as the game, so screen and game coordinates match.
"$GODOT" --headless --path "$ROOT" --fixed-fps 60 --resolution 1000x600 \
  -s res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error" "$LOG"; then
  echo
  echo "Engine or script errors were reported (see above):"
  grep -E -A2 "SCRIPT ERROR|^ERROR:|Parse Error" "$LOG" | head -40
  exit 1
fi
exit "$status"
