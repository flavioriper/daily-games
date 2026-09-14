#!/bin/sh
# Rebuild the procedural model slots from tools/build_pieces.py, export the
# hand-modelled tile from art/tile.blend, run both through the contract
# checks, and re-import in Godot so the game picks them up.
# Fails loudly: Blender's default exit code on a Python exception is 0, so
# --python-exit-code makes a broken build stop before the exporter runs.
set -e
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
"$BLENDER" -b --python-exit-code 1 \
  --python tools/build_pieces.py --python tools/blender_export.py -- \
  Emblem_Sun Emblem_Moon Empty_Mark Rim_Edge Rim_Corner
# The tile cube is hand-modelled, so it comes from its own tracked .blend.
"$BLENDER" -b art/tile.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Tile
if ! godot --headless --path . --import > /tmp/godot_import.log 2>&1; then
  echo "godot --import failed; see /tmp/godot_import.log" >&2
  tail -20 /tmp/godot_import.log >&2
  exit 1
fi
ls -la assets/models/*.glb
