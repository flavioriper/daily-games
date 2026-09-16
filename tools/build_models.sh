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
# Pipes: eleven hand-modelled collections in one .blend, one .glb each. The
# island rework added the four at the end: the block the terrain is built out
# of, the pump that lifts water a level, and the tank and pool the day's route
# runs between. The pump is the straight stood on end and both fixtures wear a
# copy of the cap's one arm, so all three are cut from the pipe shapes already
# in this file rather than modelled again.
"$BLENDER" -b art/pipes.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Pipe_Pad Pipe_Cap Pipe_Straight \
  Pipe_Elbow Pipe_Tee Pipe_Cross Valve Block Pump Source_Tank Drain_Pool
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
# Tents: four hand-modelled collections -- the turf cell, the conifer, the
# tent and the cairn. The row and column counts are Shikaku's `clue_stone`,
# which is why that one carries a zero numeral as well.
"$BLENDER" -b art/tents.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Turf_Pad Camp_Tree Tent Cairn
# Light Up: two hand-modelled collections -- the block of stone that stops the
# light and the lantern that makes it. The court's flagstones are Shikaku's
# `plot_pad` and the chip that rules a cell out is Tents' `cairn`.
"$BLENDER" -b art/lightup.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Wall_Block Lantern
# Nonogram and One Line: two hand-modelled collections in one .blend -- the
# slate tile a filled cell carries and one cell's length of plank. Everything
# else those two boards stand on is borrowed: Shikaku's plot_pad and
# clue_stone, Tents' cairn, Untangle's post.
"$BLENDER" -b art/grids.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Mosaic_Tile Plank
# Horse Pen: seven collections in one .blend. The horse, one cell of timber
# fence and an apple were each begun from a BlenderKit asset and cut down to
# the contract in the live Blender session; the polish pass added the hay bale
# that replaced the fence on the board, the water channel that replaced the
# pond, and the wheat tuft and flower the board scatters as MultiMeshes. The
# meadow itself is Tents' turf_pad and a boulder is Code Break's rock.
"$BLENDER" -b art/horse.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Horse Fence Apple Bale Channel Stalk Flower
# Snake Apple: the head, cut from a BlenderKit snake, and the burrow, built in
# the live session. The body is a tube the board builds along its cells.
"$BLENDER" -b art/snake.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Snake_Head Burrow
# Code Break's screen: the deck strip and six scenery pieces, modelled in the
# live session into one .blend.
"$BLENDER" -b art/scenery.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Deck Pier_Post Boulder Bush Daisy Tuft Signpost
# The backdrop the whole game sits in: a painted landscape. The meadow is two
# meshes -- the rolling ground, with a basin sculpted in it for the pond, and
# 4626 blades of grass baked down from the original hair particles -- and the
# tree clumps and blossom are painted alpha cards the stage billboards. `Hills`
# is the outer roll of the source scene's 200-unit terrain with its middle cut
# out, the silhouette the sky sits behind; `Cloud` is the painted cloud card.
# Both are in frame for the first time now that the camera is pitched at 7
# degrees rather than 68 (world/stage.gd, and the low-horizon spec). None of it
# obeys the cell footprint rules, so the slots are UNBOUNDED in
# blender_export.py.
"$BLENDER" -b art/landscape.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Meadow Foliage Blossom Hills Cloud
# The menu and HUD title board: one plank, its leaf sprigs and its two screws.
# The lettering is not in here -- ui/hud/sign_view.gd extrudes the title and
# motto with TextMesh in the display face, so the words stay data and a new
# puzzle costs a registry line rather than an export.
"$BLENDER" -b art/sign.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Title_Sign
# The first screen's two textured props, each cut down from a Meshy export in
# the live session (welded, decimated, one Base Color image, base at zero):
# the camper standing on the path and the fence diorama along the frame's
# bottom edge. See the contract's "Textured props" section.
"$BLENDER" -b art/mascot_camper.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Mascot_Camper
"$BLENDER" -b art/camp_sign.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Camp_Sign
# The scout, the map-reading character the first screen is being rebuilt
# around: another Meshy export cut down in the live session -- welded, its
# normal and metal/rough maps dropped, decimated 890k triangles to 30k, its
# paint at 1024 like the camper's, and scaled to the mascot budget (the map
# held out front makes depth the binding axis, not height). Two layers, not
# one: the map is cut out onto `Map_sway` so the wind can move it, and the
# body carries the `Blink` and `Mouth` shape keys world/mascot.gd drives.
"$BLENDER" -b art/mascot_scout.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Mascot_Scout
# Two pieces of the peeplet project's valley, brought over as geometry and
# dressed by this project's toon pipeline: the broadleaf oak (its source is
# art/peeplet_trees.blend, cut down in the live session into art/oak.blend --
# trunk on Bark, leaf cards on Leaf_flat with their baked smooth normals) and
# the grass clump the campsite's turf is scattered from.
"$BLENDER" -b art/oak.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Oak
"$BLENDER" -b art/grass_clump.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Grass_Clump
# The grass of the BlenderKit grass field (the same author's sibling of the
# landscape's lake scene, appended into art/grassfield.blend as its own
# scene): its terrain's hair settings copied onto a half-cell emitter, the
# strands converted to curves and ribboned by the Grass_Ribbon node group,
# baked to Grass_Patch_Blades. The emitter and strands stay in Grass_Source
# for a re-bake; only the Grass_Patch collection exports.
"$BLENDER" -b art/grassfield.blend --python-exit-code 1 \
  --python tools/blender_export.py -- Grass_Patch
if ! godot --headless --path . --import > /tmp/godot_import.log 2>&1; then
  echo "godot --import failed; see /tmp/godot_import.log" >&2
  tail -20 /tmp/godot_import.log >&2
  exit 1
fi
ls -la assets/models/*.glb
