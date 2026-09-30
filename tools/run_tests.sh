#!/usr/bin/env bash
# Run all GUT tests headless. Usage: tools/run_tests.sh   (set GODOT to your Godot binary if not on PATH)
set -e
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
