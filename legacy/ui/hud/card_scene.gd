extends "res://legacy/ui/hud/model_view.gd"

## A puzzle card's picture: a small diorama of that puzzle's own pieces --
## the same .glb models the board is built from, on the same floor it stands
## on -- in its own little world (ui/hud/model_view.gd), lit and outlined like
## the stage and drawn once. Nothing here is a render of the board; it *is*
## three or four cells of the board, arranged to show what the puzzle is
## about at a glance. A card for a new puzzle costs one builder below.

const Models = preload("res://legacy/core/models.gd")
const Toon = preload("res://legacy/core/toon.gd")
const Scenery = preload("res://legacy/world/scenery.gd")
const Platform = preload("res://legacy/core/platform.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")

## The view: from the front, above and a little to the left, the three-quarter
## look every isometric puzzle thumbnail has.
const YAW := -0.55
const PITCH := 0.62
const FRAME := 1.10
## Binairo's tile rolls a quarter turn per state; the axis alternates, and the
## face up after k steps shows state k % 3 (puzzles/binairo3d.gd _orient).
const QUARTER := TAU / 4.0

var _root: Node3D

func _init() -> void:
	super()
	light_from(Vector3(-3.0, 4.0, 5.0), Vector3.ZERO)

## Builds the diorama for puzzle `id` and frames it. Any id without a builder
## gets a single tile, so an unknown puzzle still has a picture.
func show_puzzle(id: String) -> void:
	if _root != null:
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Diorama"
	view.add_child(_root)
	match id:
		"binairo": _binairo()
		"mastermind": _codebreak()
		"balance": _balance()
		"pipes": _pipes()
		"untangle": _untangle()
		"shikaku": _shikaku()
		"tents": _tents()
		"lightup": _lightup()
		"oneline": _oneline()
		"nonogram": _nonogram()
		"horse": _horse()
		"snake": _snake()
		"rope": _rope()
		"how_big": _how_big()
		_: _put("tile", Vector3.ZERO)
	var dir := Vector3(sin(YAW) * cos(PITCH), sin(PITCH), cos(YAW) * cos(PITCH))
	frame(_bounds(), dir, FRAME)

## The union of every mesh's box under the diorama, in the view's world.
## Transforms are accumulated by hand: the card may be built before it is in
## the tree, when global transforms are not to be trusted.
func _bounds() -> AABB:
	var boxes: Array[AABB] = []
	_collect(_root, Transform3D.IDENTITY, boxes)
	var box := AABB()
	for i in boxes.size():
		box = boxes[i] if i == 0 else box.merge(boxes[i])
	return box

static func _collect(node: Node, xform: Transform3D, out: Array[AABB]) -> void:
	if node.name == Toon.OUTLINE_NODE:
		return
	var here := xform
	if node is Node3D:
		here = xform * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			out.append(here * (node as MeshInstance3D).mesh.get_aabb())
	for child in node.get_children():
		_collect(child, here, out)

# --- placing helpers ---

## One library model at `at`, turned `yaw` about Y and scaled, under a pivot.
func _put(slot: String, at: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	var pivot := Scenery.prop(slot, at, yaw, Vector3.ONE * scale)
	_root.add_child(pivot)
	return pivot.get_child(0)

## A field of `slot` pads at unit spacing, centred on the origin; returns the
## models row-major so a builder can tint or stand things on them.
func _field(slot: String, cols: int, rows: int) -> Array:
	var out := []
	for r in rows:
		for c in cols:
			out.append(_put(slot, _cell(c, r, cols, rows)))
	return out

## Where cell (c, r) of a cols-by-rows field sits, at y 0.
static func _cell(c: int, r: int, cols: int, rows: int) -> Vector3:
	return Vector3(c - (cols - 1) * 0.5, 0.0, r - (rows - 1) * 0.5)

## A rope, pipe or snake: a cylinder from `a` to `b`, in one toon colour.
func _tube(a: Vector3, b: Vector3, radius: float, colour: Color) -> MeshInstance3D:
	var d := b - a
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = d.length()
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(colour)
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	# looking_at points local -Z along the run; the cylinder stands along Y,
	# so a quarter turn about X lays Y onto -Z.
	mi.transform = Transform3D(Basis.looking_at(d, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	_root.add_child(mi)
	return mi

## Shows one numbered layer of a clue stone or wall block and hides the rest.
static func _numeral(model: Node3D, prefix: String, n: int, count: int) -> void:
	for k in count:
		Models.set_layer_visible(model, "%s%d" % [prefix, k], k == n)

# --- one builder per puzzle ---

## Binairo: the stone platform in its moss frame, three tiles rolled to show a
## sun, a moon and a bare face.
func _binairo() -> void:
	_root.add_child(Platform.build(2, 2))
	var states := {Vector2i(0, 0): 1, Vector2i(1, 1): 2, Vector2i(1, 0): 0, Vector2i(0, 1): 1}
	for cell in states:
		var spin := Node3D.new()
		spin.position = _cell(cell.x, cell.y, 2, 2) + Vector3(0.0, Placeholders.TILE_HALF, 0.0)
		spin.basis = _orient(states[cell])
		_root.add_child(spin)
		var tile := Models.instance("tile")
		tile.position.y = -Placeholders.TILE_HALF
		spin.add_child(tile)

static func _orient(steps: int) -> Basis:
	var b := Basis.IDENTITY
	for i in steps:
		b = Basis(Vector3.RIGHT if i % 2 == 0 else Vector3.BACK, QUARTER) * b
	return b

## Code Break: three slots on the plank dock, two pegs set and one still
## under its lid.
func _codebreak() -> void:
	_root.add_child(Scenery.deck(-2.0, 2.0, -1.0, 1.0))
	var colours := [0, 2]
	for i in 3:
		var at := Vector3(i - 1.0, 0.0, 0.0)
		_put("socket", at)
		if i < 2:
			var peg := _put("peg", at + Vector3(0.0, Placeholders.PEG_SEAT, 0.0))
			var c: Color = Pal.PEGS[colours[i]]
			Models.tint_named(peg, "Shell", c)
			Models.tint_named(peg, "Mark_flat", c.darkened(0.35))
			for k in range(1, 8):
				Models.set_layer_visible(peg, "Peg_Mark_%d" % k, k == colours[i] + 1)
		else:
			_put("lid", at + Vector3(0.0, Placeholders.SOCKET_H, 0.0))

## Balance: the scale tipped by a ball against two cubes.
func _balance() -> void:
	_root.add_child(Platform.build(3, 2))
	var stand := _put("scale_stand", Vector3.ZERO)
	var beam_y := Models.height(stand) - 0.06
	var tilt := 0.11
	var beam := _put("scale_beam", Vector3(0.0, beam_y, 0.0))
	beam.get_parent().rotation.z = tilt
	var hang := 1.3
	for side: float in [-1.0, 1.0]:
		var y: float = beam_y + side * hang * tan(tilt) - Placeholders.PAN_DROP
		var pan := _put("scale_pan", Vector3(side * hang, y, 0.0))
		var top: float = y + Models.height(pan) * 0.35
		if side < 0.0:
			_put("token_ball", Vector3(side * hang, top, 0.0))
		else:
			_put("token_cube", Vector3(side * hang - 0.16, top, 0.1), 0.3)
			_put("token_cube", Vector3(side * hang + 0.16, top, -0.12), -0.4)

## Pipes: an island of two blocks by two, a wet elbow, straight and cap on top.
func _pipes() -> void:
	var top := 1.015
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_put("block", _cell(cell.x, cell.y, 2, 2))
	_wet(_put("pipe_elbow", Vector3(-0.5, top, 0.5)))
	_wet(_put("pipe_straight", Vector3(0.5, top, 0.5), PI * 0.5))
	_wet(_put("pipe_cap", Vector3(-0.5, top, -0.5), PI))
	_put("valve", Vector3(0.5, top, -0.5))

func _wet(pipe: Node3D) -> void:
	Models.tint_named(pipe, "Steel", Pal.PIPE_WET)
	Models.tint_named(pipe, "Collar", Pal.PIPE_WET_HI)
	var flow := Models.material_named(pipe, "Flow_flat")
	if flow is ShaderMaterial:
		flow.set_shader_parameter("wet", 1.0)

## Untangle: four posts, the ring of rope between them and the two crossing
## lines that still need pulling apart.
func _untangle() -> void:
	_root.add_child(Platform.build(2, 2))
	var y := Placeholders.ROPE_Y
	var corners := [Vector3(-0.75, 0.0, -0.75), Vector3(0.75, 0.0, -0.75), Vector3(0.75, 0.0, 0.75), Vector3(-0.75, 0.0, 0.75)]
	for c in corners:
		_put("post", c)
	for i in 4:
		var a: Vector3 = corners[i] + Vector3(0.0, y, 0.0)
		var b: Vector3 = corners[(i + 1) % 4] + Vector3(0.0, y, 0.0)
		_tube(a, b, 0.045, Pal.WOOD_DEEP)
	_tube(corners[0] + Vector3(0.0, y, 0.0), corners[2] + Vector3(0.0, y, 0.0), 0.045, Pal.BAD)
	_tube(corners[1] + Vector3(0.0, y + 0.05, 0.0), corners[3] + Vector3(0.0, y + 0.05, 0.0), 0.045, Pal.BAD)

## Shikaku: a field with one two-cell plot walled off and its marker stone.
func _shikaku() -> void:
	var pads := _field("plot_pad", 3, 2)
	var h := Models.height(pads[0])
	for i in [0, 1]:
		Models.tint_named(pads[i], "Stone", Pal.PLOT_SOIL)
	# The plot covers cells (0,0) and (1,0): x -1.5..0.5, z -1..0.
	for x in [-1.0, 0.0]:
		_put("wall_edge", Vector3(x, h, -1.0))
		_put("wall_edge", Vector3(x, h, 0.0))
	_put("wall_edge", Vector3(-1.5, h, -0.5), PI * 0.5)
	_put("wall_edge", Vector3(0.5, h, -0.5), PI * 0.5)
	for corner in [Vector3(-1.5, h, -1.0), Vector3(0.5, h, -1.0), Vector3(-1.5, h, 0.0), Vector3(0.5, h, 0.0)]:
		_put("wall_post", corner)
	var stone := _put("clue_stone", Vector3(-0.5, h, -0.5))
	_numeral(stone, "Clue_Num_", 2, 10)

## Tents: turf, two conifers, a tent beside one and a cairn ruling a cell out.
func _tents() -> void:
	var pads := _field("turf_pad", 3, 2)
	var h := Models.height(pads[0])
	for i in [0, 5]:
		Models.tint_named(pads[i], "Turf", Pal.TURF_TREE)
	_put("camp_tree", _cell(0, 0, 3, 2) + Vector3(0.0, h, 0.0), 0.4)
	_put("camp_tree", _cell(2, 1, 3, 2) + Vector3(0.0, h, 0.0), 2.1)
	_put("tent", _cell(1, 0, 3, 2) + Vector3(0.0, h, 0.0), 0.3)
	_put("cairn", _cell(0, 1, 3, 2) + Vector3(0.0, h, 0.0))

## Light Up: a court with one lantern lit, the stones it reaches warmed, and a
## numbered block.
func _lightup() -> void:
	var pads := _field("plot_pad", 3, 2)
	var h := Models.height(pads[0])
	for i in pads.size():
		Models.tint_named(pads[i], "Stone", Pal.LAMPLIGHT if i in [0, 1, 2, 4] else Pal.FLAGSTONE)
	var lantern := _put("lantern", _cell(1, 0, 3, 2) + Vector3(0.0, h, 0.0))
	Models.tint_named(lantern, "Glass", Pal.SUN)
	Models.tint_named(lantern, "Iron", Pal.LANTERN)
	var block := _put("wall_block", _cell(2, 1, 3, 2) + Vector3(0.0, h, 0.0))
	Models.tint_named(block, "Block", Pal.BLOCK_STONE)
	_numeral(block, "Block_Num_", 1, 5)

## One Line: four posts with two planks laid and the fords still to walk.
func _oneline() -> void:
	_root.add_child(Platform.build(3, 2))
	var posts := [Vector3(-1.0, 0.0, -0.5), Vector3(1.0, 0.0, -0.5), Vector3(1.0, 0.0, 0.5), Vector3(-1.0, 0.0, 0.5)]
	for p in posts:
		_put("post", p)
	var edges := [[0, 1, true], [1, 2, true], [2, 3, false], [3, 0, false], [0, 2, false]]
	for k in edges.size():
		var e: Array = edges[k]
		var a: Vector3 = posts[e[0]]
		var b: Vector3 = posts[e[1]]
		var pivot := Node3D.new()
		pivot.position = (a + b) * 0.5 + Vector3(0.0, k * 0.004, 0.0)
		pivot.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
		_root.add_child(pivot)
		var plank := Models.instance("plank")
		plank.scale.x = (b - a).length()
		Models.tint_named(plank, "Plank", Pal.PLANK_LAID if e[2] else Pal.PLANK_BARE)
		pivot.add_child(plank)

## Nonogram: the mosaic floor with a picture half laid.
func _nonogram() -> void:
	var pads := _field("plot_pad", 3, 3)
	var h := Models.height(pads[0])
	for cell in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		_put("mosaic_tile", _cell(cell.x, cell.y, 3, 3) + Vector3(0.0, h, 0.0))
	Models.tint_named(pads[8], "Stone", Pal.SOCKET_OUT)
	_put("cairn", _cell(2, 2, 3, 3) + Vector3(0.0, h, 0.0), 0.0, 0.8)

## Horse Pen: the horse on its meadow, two bales and an apple.
func _horse() -> void:
	var pads := _field("turf_pad", 3, 2)
	var h := Models.height(pads[0])
	for i in [0, 1, 2]:
		Models.tint_named(pads[i], "Turf", Pal.TURF_REACH)
	var horse := _put("horse", _cell(1, 0, 3, 2) + Vector3(0.0, h, 0.0))
	Models.tint_named(horse, "Hide", Pal.HIDE)
	Models.tint_named(horse, "Mane", Pal.MANE)
	_put("bale", _cell(0, 1, 3, 2) + Vector3(0.0, h, 0.0), 0.2)
	_put("bale", _cell(2, 1, 3, 2) + Vector3(0.0, h, 0.0), -0.3)
	_put("apple", _cell(2, 0, 3, 2) + Vector3(0.0, h, 0.0))

## The Rope: a corner of the plank with the rope laid over four squares,
## between the two pegs it has met. The pegs stand as tall and as slim as the
## board stands them, and the rope runs flat past their feet, the same way.
func _rope() -> void:
	const TALL := 2.4
	const SLIM := 0.72
	var pads := _field("plot_pad", 3, 2)
	var top := Models.height(pads[0])
	for pad in pads:
		Models.tint_named(pad, "Stone", Pal.ROPE_FACE)
	var run := [Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for c in run:
		Models.tint_named(pads[c.y * 3 + c.x], "Stone", Pal.ROPE_UNDER)
	for entry in [[Vector2i(0, 1), 1], [Vector2i(2, 0), 2]]:
		var at: Vector2i = entry[0]
		var peg := _put("clue_stone", _cell(at.x, at.y, 3, 2) + Vector3(0.0, top, 0.0))
		_numeral(peg, "Clue_Num_", int(entry[1]), 10)
		Models.tint_named(peg, "Stone", Pal.GOOD)
		peg.scale = Vector3(SLIM, TALL, SLIM)
	var lift := top + 0.13
	for i in run.size() - 1:
		var a: Vector2i = run[i]
		var b: Vector2i = run[i + 1]
		_tube(_cell(a.x, a.y, 3, 2) + Vector3(0.0, lift, 0.0),
			_cell(b.x, b.y, 3, 2) + Vector3(0.0, lift, 0.0), 0.13, Pal.ROPE_HEMP)

## Snake Apple: the snake winding toward an apple, its burrow behind it.
func _snake() -> void:
	var pads := _field("turf_pad", 3, 2)
	var h := Models.height(pads[0])
	var y := h + 0.15
	_tube(Vector3(-1.0, y, -0.5), Vector3(0.0, y, -0.5), 0.14, Pal.SCALE)
	_tube(Vector3(0.0, y, -0.5), Vector3(0.0, y, 0.5), 0.14, Pal.SCALE)
	_tube(Vector3(0.0, y, 0.5), Vector3(0.7, y, 0.5), 0.14, Pal.SCALE)
	_put("snake_head", Vector3(0.7, h + 0.02, 0.5))
	_put("apple", _cell(2, 0, 3, 2) + Vector3(0.0, h, 0.0))
	var burrow := _put("burrow", _cell(0, 1, 3, 2) + Vector3(0.0, h, 0.0))
	Models.tint_named(burrow, "Earth", Pal.EARTH)

## How Big?: the scout on his dock, and beside him the horse he is to be
## measured against as the silhouette the player will size.
func _how_big() -> void:
	_root.add_child(Scenery.deck(-1.6, 1.6, -0.5, 0.5))
	_put("mascot_scout", Vector3(-0.75, 0.0, 0.0), 0.35, 0.9)
	Models.silhouette(_put("horse", Vector3(0.55, 0.0, 0.0), -0.3, 1.55), Pal.OUTLINE)
