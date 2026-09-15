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
# Pipes: seven hand-modelled collections in one .blend, one .glb each.
"$BLENDER" -b art/pipes.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Pipe_Pad Pipe_Cap Pipe_Straight \
  Pipe_Elbow Pipe_Tee Pipe_Cross Valve
# Balance: ten hand-modelled collections in one .blend, one .glb each.
"$BLENDER" -b art/balance.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Scale_Stand Scale_Beam Scale_Pan Plinth \
  Weight_Disc Token_Ball Token_Cube Token_Prism Token_Gem Token_Cross
# Untangle: one hand-modelled collection. Its ropes are not models -- the
# board rebuilds each one as a tube from its own simulation.
"$BLENDER" -b art/untangle.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Post
# Shikaku: four hand-modelled collections -- the plot floor, the dry-stone
# wall, the block that closes a corner, and the marker stone with its nine
# carved numerals.
"$BLENDER" -b art/shikaku.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Plot_Pad Wall_Edge Wall_Post Clue_Stone
if ! godot --headless --path . --import > /tmp/godot_import.log 2>&1; then
  echo "godot --import failed; see /tmp/godot_import.log" >&2
  tail -20 /tmp/godot_import.log >&2
  exit 1
fi
ls -la assets/models/*.glb
