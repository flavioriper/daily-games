#!/bin/sh
# Rebuild the procedural model slots from tools/build_pieces.py, export the
# hand-modelled tile assembly from art/tile.blend, run both through the
# contract checks, and re-import in Godot so the game picks them up.
# Fails loudly: Blender's default exit code on a Python exception is 0, so
# --python-exit-code makes a broken build stop before the exporter runs.
set -e
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
"$BLENDER" -b --python-exit-code 1 \
  --python tools/build_pieces.py --python tools/blender_export.py -- \
  Rim_Edge Rim_Corner
# The tile is hand-modelled, so it comes from its own tracked .blend. `Tile`
# is a collection there -- the body plus the sun and moon inlaid in its faces
# -- and the exporter writes the whole collection into one tile.glb.
"$BLENDER" -b art/tile.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Tile
# Code Break's pieces are hand-modelled too: four collections in one .blend,
# one .glb each.
"$BLENDER" -b art/codebreak.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Socket Peg Pip Lid
if ! godot --headless --path . --import > /tmp/godot_import.log 2>&1; then
  echo "godot --import failed; see /tmp/godot_import.log" >&2
  tail -20 /tmp/godot_import.log >&2
  exit 1
fi
ls -la assets/models/*.glb
