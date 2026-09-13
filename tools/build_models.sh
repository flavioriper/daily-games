#!/bin/sh
# Rebuild every model slot from tools/build_pieces.py, export through the
# contract checks, and re-import in Godot so the game picks them up.
set -e
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
"$BLENDER" -b --python tools/build_pieces.py --python tools/blender_export.py -- \
  Tile Emblem_Sun Emblem_Moon Empty_Mark Rim_Edge Rim_Corner
godot --headless --path . --import >/dev/null 2>&1 || true
ls -la assets/models/*.glb
