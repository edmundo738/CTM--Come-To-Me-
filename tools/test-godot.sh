#!/usr/bin/env bash
# Reproducible Linux shell runner (requires GNU timeout). Set GODOT to the 4.7.2 binary.
# Usage: tools/test-godot.sh [--graphics]
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"

run_check() {
  local marker="$1"
  shift
  local log
  log="$(mktemp)"
  echo "==> $*"
  # Some Godot import failures report exit 0, and failed scripts can hang.
  if ! timeout "${GODOT_TEST_TIMEOUT:-240}" "$godot" "$@" 2>&1 | tee "$log"; then
    echo "Godot command failed or timed out" >&2
    rm -f "$log"
    return 1
  fi
  if grep -qE 'SCRIPT ERROR|^ERROR:|Parse Error:|Compile Error:|Failed to load script' "$log"; then
    echo "Godot reported a script/import error" >&2
    rm -f "$log"
    return 1
  fi
  if [[ -n "$marker" ]] && ! grep -q "^${marker}" "$log"; then
    echo "Missing expected marker: $marker" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

if [[ "${1:-}" == "--graphics" ]]; then
  # Call under a real display/Xvfb; the scripts intentionally fail headless.
  run_check COMBAT_RENDER_PASS --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/combat_render_test.gd
  run_check ENVIRONMENT_RENDER_PASS --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/environment_render_test.gd
  run_check ELECTRIC_RENDER_PASS --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/electric_render_test.gd
  run_check ENEMY_INTENTION_RENDER_PASS --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/enemy_intention_render_test.gd
  run_check SKILL_TREE_RENDER_PASS --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/skill_tree_render_test.gd
elif [[ $# -eq 0 ]]; then
  run_check "" --headless --path . --editor --import
  run_check SELFTEST_PASS --headless --path . --script res://tests/self_test.gd
  run_check ENVIRONMENT_TEST_PASS --headless --path . --script res://tests/environment_test.gd
  run_check ELECTRIC_PRESENTATION_TEST_PASS --headless --path . --script res://tests/electric_presentation_test.gd
  run_check SPECIAL_CONTENT_TEST_PASS --headless --path . --script res://tests/special_content_test.gd
  run_check CONTROLLER_TEST_PASS --headless --path . --script res://tests/controller_test.gd
  run_check TACTICAL_FEEDBACK_TEST_PASS --headless --path . --script res://tests/tactical_feedback_test.gd
  run_check PERFORMANCE_REGRESSION_PASS --headless --path . --script res://tests/performance_regression_test.gd
  run_check EXPRESSIVE_MOVEMENT_TEST_PASS --headless --path . --script res://tests/expressive_movement_test.gd
  run_check COMBAT_FEEL_TEST_PASS --headless --path . --script res://tests/combat_feel_test.gd
  run_check SKILL_TREE_TEST_PASS --headless --path . --script res://tests/skill_tree_test.gd
  run_check CAMPAIGN_STORAGE_TEST_PASS --headless --path . --script res://tests/campaign_storage_test.gd
  run_check SWEEP_PASS --headless --path . --script res://tests/sweep.gd -- floors=1-10 seeds=2 bots=1
  run_check SWEEP_PASS --headless --path . --script res://tests/sweep.gd -- floors=25-35 seeds=1 bots=1
  run_check SWEEP_PASS --headless --path . --script res://tests/sweep.gd -- floors=100-100 seeds=1 bots=0
  run_check SWEEP_PASS --headless --path . --script res://tests/sweep.gd -- floors=200-200 seeds=1 bots=0
else
  echo "Usage: GODOT=/path/to/Godot tools/test-godot.sh [--graphics]" >&2
  exit 2
fi
