#!/usr/bin/env bash
# Build and validate every spec in a folder.
# Usage: build_all.sh <specs_dir> <out_dir> [--preview]
set -u
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BLENDER="${BLENDER_PATH:-blender}"
SPECS="$1"; OUT="$2"; PREVIEW="${3:-}"
fail=0
for spec in "$SPECS"/*.json; do
  id="$(basename "$spec" .json)"
  echo "=== $id"
  "$BLENDER" -b --factory-startup --python "$SKILL_DIR/scripts/build_asset.py" -- \
      --spec "$spec" --out "$OUT" $PREVIEW 2>&1 | grep -E "BUILD_OK|Traceback|Error:" | grep -v EGL | cut -c1-160
  python3 "$SKILL_DIR/scripts/validate_glb.py" "$OUT/$id.glb" || fail=1
done
exit $fail
