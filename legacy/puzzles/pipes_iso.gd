extends "res://legacy/core/stage_board.gd"

## Pipes, played on a floating island of blocks seen from the corner. Water
## starts in a tank on a high block and has to reach the pool at the drain.
## The player builds the pipeline out of a tray of pieces: tap an open mouth
## and the selected piece lands in the cell that mouth faces, already turned
## to connect. Water runs level and downhill on its own and climbs only
## through a pump, so a drop is free and a climb has to be built. Tall ground
## hides part of the route from any one side, which is why the island turns.
##
## Nothing here knows the rules: `pipes_iso_gen.gd` owns the mouth maths, the
## standing rule, the flow and the day's island. This file is the scene, the
## gestures and the motion.
## Spec: docs/superpowers/specs/2026-09-15-pipes-iso-design.md.

const Gen = preload("res://legacy/puzzles/pipes_iso_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://legacy/core/models.gd")
const Placeholders = preload("res://legacy/core/placeholders.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://legacy/core/toon.gd")
const Fx = preload("res://legacy/world/fx.gd")

## The island is looked at from one of four corners, a quarter turn apart.
const PITCH := 35.0
const START_YAW := 45.0
const STOPS := 4
const STOP_NAMES := ["north-east", "north-west", "south-west", "south-east"]
const HINTS := 3
## A press this long on a piece lifts it back into the tray instead of turning
## it, which is what every builder on a phone does.
const LONG_PRESS := 0.45
## A drag this far across empty ground turns the island.
const SWIPE_MIN := 70.0
## What a tap is tested against: the sphere at an open mouth and the ball
## around a placed piece's hub. A mouth is smaller and wins a tie, since it
## hovers over its own block's crown.
const MOUTH_R := 0.17
const PIECE_R := 0.3
## A piece arrives from a cell above and settles.
const PLACE_DROP := 0.7
const PLACE_TIME := 0.24
const TURN_TIME := 0.22
const SQUASH := 0.08
const SQUASH_TIME := 0.18
const LIFT_TIME := 0.18
const DIP := 0.04
const DIP_TIME := 0.3
## The wetting wave, carried over from the pad board: eight steps so the toon
## cache holds nine colours per material name, staggered by search depth from
## the shallowest cell that just changed rather than from zero, so a run that
## fills deep in the island still races from where the water enters.
const FADE_TIME := 0.25
const FADE_STEPS := 8
const FLOW_STEP := 0.05
const FLOW_OUT_STEP := 0.02
const FLOW_CAP := 1.2
## At most this many mouths pour at once, which leaves Fx.JET_POOL two
## emitters for the source and the drains.
const MAX_LEAKS := 4
const JET_OUT := 0.22
const JET_LIFT := 0.16
const SPARKLE_LIFT := 0.3
## Peek: how far the ground fades while the button is held.
const PEEK_ALPHA := 0.32
## The entrance: the island rises out of the water and its levels arrive from
## the bottom up, which is the only way to pop blocks in by height once every
## level is one merged mesh.
const ENTER_RISE := 0.8
const ENTER_TIME := 0.5
const ENTER_LEVEL := 0.06
const ENTER_POP := 0.3
## The win: one slow turn all the way round, a quarter at a time.
const WIN_TURN_GAP := 0.6
const WIN_FLOW := 2.4
const WIN_FLOW_TIME := 1.2

## The colours the island is built out of. Earth and grass are the block's own
## two layers; a crown carrying a piece is the pale stone every board uses for
## a pad, and one a hint filled is the given stone every board uses for a
## given.
const CROWN_GRASS := 0
const CROWN_STONE := 1
const CROWN_GIVEN := 2

var cols: int = 4
var rows: int = 4
var levels: int = 3
var _heights: Array = []
var _source := Vector3i.ZERO
var _source_mask: int = Gen.N
var _drains: Array = []
var _drain_masks: Dictionary = {}
var _route: Array = []
var _solution: Dictionary = {}
## kind -> how many of that piece are still in the tray, and the order the
## tray shows them in.
var _tray: Dictionary = {}
var _tray_kinds: Array = []
var _selected := ""
## cell -> {"kind": String, "mask": int}: what the player has built.
var _placed: Dictionary = {}
var _locked: Dictionary = {}
## cell -> which of its kind's orientations it is showing, so a tap carries on
## round the list instead of starting again.
var _turned: Dictionary = {}
var _fed: Dictionary = {}
var _wet: Dictionary = {}
var _stop: int = 0
var _peeking := false
## One entry per action that can be taken back.
var _history: Array = []

var fx: Node3D
var _ground: Node3D
var _level_nodes: Array = []
var _crown_nodes: Array = []
var _crown_colour: Dictionary = {}   # Vector2i -> CROWN_*
var _fixtures: Dictionary = {}       # cell -> Node3D
var _pivots: Dictionary = {}         # cell -> Node3D at the hub, carrying the orientation
var _models: Dictionary = {}         # cell -> the model under that pivot
var _flow_mats: Dictionary = {}      # cell -> that piece's own pipe_flow material
var _buds: MultiMeshInstance3D
var _bud_points: Array = []          # [{"cell":, "bit":, "at":}] the taps land on
var _leak_jets: Dictionary = {}
var _leak_at: Dictionary = {}
var _source_jet: int = -1
var _drain_jets: Dictionary = {}
var _fade_tw: Dictionary = {}
var _piece_tw: Dictionary = {}
var _entrance: Array = []
var _win_tw: Tween
## The press being followed: where it started, when, and what it hit.
var _press_at := Vector2.ZERO
var _press_time := 0.0
var _press_hit: Dictionary = {}
var _press_live := false
var _press_used := false

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "pipes"
func title() -> String: return "Pipes"

func rules() -> String:
	return ("Build the pipeline from the tray. Tap an open mouth and the piece lands facing it; "
		+ "tap a piece to turn it, hold it to take it back. "
		+ "Water runs level and downhill on its own and climbs only through a pump. "
		+ "Turn the island to see what the ground hides. The water is the check.")

func board_size() -> Vector2i: return Vector2i(cols, rows)
## The whole island plus a cell's worth of air over its tallest column: the
## box is taken from the terrain, not from the pieces, so the framing does not
## jump when something is placed high. The difficulty's own level count would
## be the safe answer and is the wrong one -- a day whose columns all come out
## three high would then be framed inside six levels of sky and the island
## would sit small in the middle of it.
func board_height() -> float: return float(_tallest()) + 1.0

## The tallest column on the island. The base fits the camera once in
## _ready(), before build() has laid any terrain, so an island that does not
## exist yet is framed by the difficulty's own ceiling.
func _tallest() -> int:
	if _heights.is_empty():
		return levels
	var top := 1
	for z in rows:
		for x in cols:
			top = maxi(top, Gen.height_at(_heights, x, z))
	return top
func plane_height() -> float: return 0.0
func board_pitch() -> float: return PITCH
func board_projection() -> int: return Camera3D.PROJECTION_ORTHOGONAL
## The stop the island is showing. A fit always agrees with where the last
## turn left the camera.
func board_yaw() -> float: return START_YAW + 90.0 * _stop

func build(_rng: RandomNumberGenerator, difficulty: int) -> void:
	var out: Dictionary = Gen.generate(_rng, difficulty)
	cols = int(out.cols)
	rows = int(out.rows)
	levels = int(out.levels)
	_heights = out.heights
	_source = out.source
	_source_mask = int(out.source_mask)
	_drains = out.drains
	_drain_masks = out.get("drain_masks", {})
	_route = out.route
	_solution = out.solution
	_tray = (out.tray as Dictionary).duplicate()
	_tray_kinds = []
	for kind in Gen.KINDS:
		if _tray.has(kind):
			_tray_kinds.append(kind)
	_selected = _tray_kinds[0] if not _tray_kinds.is_empty() else ""
	_placed = {}
	_locked = {}
	_turned = {}
	_history = []
	_stop = 0
	_peeking = false
	_build_scene()
	_reflow(false)
	_refit()
	_enter()

## Every piece comes off the island and back into the tray, and the view goes
## back to the first stop. Hints are unpinned but not refunded.
func reset_board() -> void:
	_stop_entrance()
	# Every piece goes back into the tray on its way off the island, which is
	# the only place the count it came from is still known.
	for cell in _placed.keys():
		var kind := String(_placed[cell].kind)
		_tray[kind] = int(_tray.get(kind, 0)) + 1
		_free_piece(cell)
	_placed = {}
	_locked = {}
	_turned = {}
	_history = []
	_crown_colour = {}
	moves = 0
	if _stop != 0:
		_stop = 0
		_refit()
	_rebuild_crowns()
	_reflow(true)
	fx.cue("reset")

func is_solved() -> bool:
	return Gen.is_solved(_all_pieces(), _source, _drains)

func share_glyphs() -> String:
	var out := ""
	for z in rows:
		for x in cols:
			var col := Vector2i(x, z)
			var cell := Gen.crown(_heights, x, z)
			if cell == _source:
				out += "💧"
			elif _drains.has(cell):
				out += "🌊" if _fed.has(cell) else "⬛"
			elif _column_piece(col):
				out += "🟦" if _column_fed(col) else "⬜"
			else:
				out += "🟩"
		out += "\n"
	return out

func _column_piece(col: Vector2i) -> bool:
	for cell in _placed:
		if cell.x == col.x and cell.z == col.y:
			return true
	return false

func _column_fed(col: Vector2i) -> bool:
	for cell in _fed:
		if cell.x == col.x and cell.z == col.y and _placed.has(cell):
			return true
	return false

# --- the board as the rules see it ---

## Everything the water can be in: the pieces the player placed and the two
## kinds of fixture, which are pieces that cannot be moved.
func _all_pieces() -> Dictionary:
	var pieces: Dictionary = _placed.duplicate(true)
	pieces[_source] = {"kind": "source", "mask": _source_mask}
	for drain in _drains:
		pieces[drain] = {"kind": "drain", "mask": int(_drain_masks[drain])}
	return pieces

func _stands(cell: Vector3i, mask: int) -> bool:
	return Gen.stands(cell, mask, _heights, cols, rows, levels)

# --- the HUD ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "pieces", "view", "status"]

## The tray, in the kinds' own order. A kind with nothing left is disabled
## rather than hidden, so the counts stay where the player learned them.
func pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind in _tray_kinds:
		var count := int(_tray.get(kind, 0))
		out.append({"kind": "pipe_%s" % kind, "count": count,
			"selected": kind == _selected, "enabled": count > 0 and not is_done()})
	return out

func pick(i: int) -> bool:
	if i < 0 or i >= _tray_kinds.size():
		return false
	var kind: String = _tray_kinds[i]
	if int(_tray.get(kind, 0)) <= 0:
		return false
	_selected = kind
	focus_changed.emit()
	return true

func status_text() -> String:
	var left := 0
	for kind in _tray_kinds:
		left += int(_tray[kind])
	var filled := 0
	for drain in _drains:
		if _fed.has(drain):
			filled += 1
	var leaks: int = Gen.leaks(_all_pieces(), _fed).size()
	var trouble := "no leaks" if leaks == 0 else ("1 leak" if leaks == 1 else "%d leaks" % leaks)
	return "Tray %d  ·  Drains %d / %d\nView %s  ·  %s" % [left, filled, _drains.size(),
		STOP_NAMES[_stop % STOP_NAMES.size()], trouble]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes back the last place, turn or lift. Counts no move.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Dictionary = _history.pop_back()
	var cell: Vector3i = last.cell
	match String(last.op):
		"place":
			_remove(cell, false)
		"lift":
			_put(cell, String(last.kind), int(last.mask), false)
		"turn":
			_set_mask(cell, int(last.mask))
	_reflow(true)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Places the next piece of the generator's own route, from the source
## outward, and pins it: the first route cell that is not already carrying the
## right piece. Refused when the tray has none of that kind left. Three per
## puzzle; reset unpins them but does not refund them.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	for entry in _route:
		var cell: Vector3i = entry
		if not _solution.has(cell):
			continue
		var want: Dictionary = _solution[cell]
		if _placed.has(cell) and int(_placed[cell].mask) == int(want.mask) \
				and String(_placed[cell].kind) == String(want.kind):
			continue
		var kind := String(want.kind)
		if _placed.has(cell):
			# Something else is in the way: it goes back to the tray first.
			_remove(cell, true)
		if int(_tray.get(kind, 0)) <= 0:
			return false
		_put(cell, kind, int(want.mask), true)
		_locked[cell] = true
		_history = _forget(cell)
		_paint_crown(cell)
		fx.sparkle(_hub(cell) + Vector3(0.0, SPARKLE_LIFT, 0.0), Pal.WATER_HI)
		fx.cue("hint")
		hints_used += 1
		_reflow(true)
		moved.emit()
		return true
	return false

## History without any entry about `cell`: a hint's cell can no longer be
## turned or lifted, so an entry that would undo into it is dropped.
func _forget(cell: Vector3i) -> Array:
	var kept: Array = []
	for entry in _history:
		if entry.cell != cell:
			kept.append(entry)
	return kept

## The board has no Check button: the water is the check.
func check() -> int:
	return -1

# --- the view ---

## One quarter turn of the island, and the status card's view name with it.
func turn_view() -> void:
	_stop = (_stop + 1) % STOPS
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("turn"):
		_stage.turn(1)
	fx.cue("turn_view")
	moved.emit()

## The ground fades while the button is held, so the pipes behind it show.
## Pieces stay solid and tappable; nothing else changes.
func peek(on: bool) -> void:
	if _peeking == on:
		return
	_peeking = on
	_paint_ground()
	fx.cue("peek" if on else "unpeek")

# --- the scene ---

func _stop_all() -> void:
	_stop_entrance()
	for store in [_fade_tw, _piece_tw]:
		for key in store:
			Motion.stop(store[key])
		store.clear()
	Motion.stop(_win_tw)
	if fx != null and is_instance_valid(fx):
		for cell in _leak_jets:
			fx.stop_jet(_leak_jets[cell])
		for cell in _drain_jets:
			fx.stop_jet(_drain_jets[cell])
		fx.stop_jet(_source_jet)
	_leak_jets.clear()
	_leak_at.clear()
	_drain_jets.clear()
	_source_jet = -1

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pivots = {}
	_models = {}
	_flow_mats = {}
	_fixtures = {}
	_wet = {}
	_fed = {}
	_crown_colour = {}

	fx = Fx.new()
	board.add_child(fx)
	_build_ground()
	_build_fixtures()
	_buds = null
	_rebuild_buds()

## The island: one node per level, carrying that level's blocks merged into a
## single earth mesh and the crowns that end on it merged into one mesh per
## colour. A six-by-six board five levels tall is 180 cubes, which instanced
## would be 180 draw calls and as many again in outlines; merged it is a
## handful. Per level rather than all in one mesh so the entrance can still
## bring the island in from the bottom up -- and the crowns belong to their
## level rather than to a mesh of their own, or they would hang in the air
## over blocks that had not arrived yet.
func _build_ground() -> void:
	_ground = Node3D.new()
	_ground.name = "Ground"
	board.add_child(_ground)
	var sample := Models.instance("block")
	_earth = _layer_of(sample, "Earth")
	_crown = _layer_of(sample, "Grass")
	sample.free()
	_level_nodes = []
	_crown_nodes = []
	for y in levels:
		var node := Node3D.new()
		node.name = "Level_%d" % y
		_ground.add_child(node)
		_level_nodes.append(node)
		var parts: Array = []
		for z in rows:
			for x in cols:
				if y >= Gen.height_at(_heights, x, z):
					continue
				parts.append({"mesh": _earth.mesh,
					"xform": Transform3D(Basis(), _block_at(x, y, z)) * _earth.xform})
		var mi := MeshInstance3D.new()
		mi.name = "Earth"
		mi.mesh = _merge(parts)
		mi.material_override = Toon.material(Pal.EARTH)
		if mi.mesh != null:
			Toon.add_outline(mi)
		node.add_child(mi)
		var row: Array = []
		for i in 3:
			var crown := MeshInstance3D.new()
			crown.name = ["Crown_Grass", "Crown_Stone", "Crown_Given"][i]
			# The cap is flush with its block's crown and inset inside it, so
			# the earth's own outline already draws the cell's edge; a shell of
			# its own would only double that line. Nothing stands under a
			# crown, so it casts nothing either.
			crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(crown)
			row.append(crown)
		_crown_nodes.append(row)
	_rebuild_crowns()

## The block's two layers and where each sits inside it.
var _earth: Dictionary = {}
var _crown: Dictionary = {}

## The crowns, merged per level and per what the column is carrying: plain
## grass, the pale stone of a pad under a piece, or the given stone under a
## piece a hint placed. Rebuilt when a crown changes, which is a placement or
## a hint -- not a frame.
func _rebuild_crowns() -> void:
	if _crown_nodes.is_empty():
		return
	var parts: Array = []
	for y in levels:
		parts.append([[], [], []])
	for z in rows:
		for x in cols:
			var col := Vector2i(x, z)
			var h := Gen.height_at(_heights, x, z)
			var which := int(_crown_colour.get(col, CROWN_GRASS))
			parts[h - 1][which].append({"mesh": _crown.mesh,
				"xform": Transform3D(Basis(), _block_at(x, h - 1, z)) * _crown.xform})
	var colours := [Pal.TURF, Pal.STONE, Pal.STONE_GIVEN]
	for y in levels:
		for i in 3:
			var mi: MeshInstance3D = _crown_nodes[y][i]
			mi.mesh = _merge(parts[y][i])
			mi.material_override = Toon.material(colours[i])
	_paint_ground()

## Where the block at level `y` over column (x, z) sits: a block is a unit
## cube with its base at its own level.
func _block_at(x: int, y: int, z: int) -> Vector3:
	return BoardMath.cell_center(z, x, cols, rows, float(y))

## The mesh of `root`'s layer whose material is called `name`, and where that
## layer sits inside the model -- a block's turf cap is a mesh built at the
## origin and moved onto the crown by its own node, so merging the mesh alone
## would bury every crown at the foot of its column.
static func _layer_of(root: Node3D, name: String) -> Dictionary:
	for mi in Models.meshes(root):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src != null and src.resource_name == name:
				return {"mesh": mi.mesh, "xform": _relative_xform(root, mi)}
	return {"mesh": null, "xform": Transform3D()}

## `node`'s transform in `root`'s space, however deep the export nested it.
static func _relative_xform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D()
	var at: Node3D = node
	while at != null and at != root:
		xform = at.transform * xform
		at = at.get_parent() as Node3D
	return xform

## [{"mesh":, "xform":}] as one mesh, or null when there is nothing to merge.
static func _merge(parts: Array) -> ArrayMesh:
	if parts.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var m: Mesh = part["mesh"]
		if m == null:
			continue
		for i in m.get_surface_count():
			st.append_from(m, i, part["xform"])
	return st.commit()

## Paints the ground: solid, or the see-through variant while peek is held.
## The outline shells go with it -- a dark line round ghosted ground reads as
## a hole cut in the island.
func _paint_ground() -> void:
	var colours := [Pal.TURF, Pal.STONE, Pal.STONE_GIVEN]
	for y in _level_nodes.size():
		_paint_mesh((_level_nodes[y] as Node3D).get_node("Earth"), Pal.EARTH)
		for i in 3:
			_paint_mesh(_crown_nodes[y][i], colours[i])

func _paint_mesh(mi: MeshInstance3D, colour: Color) -> void:
	mi.material_override = Toon.ghost(colour, PEEK_ALPHA) if _peeking else Toon.material(colour)
	Toon.reline(mi)
	var shell := mi.get_node_or_null(Toon.OUTLINE_NODE)
	if shell != null:
		(shell as MeshInstance3D).visible = not _peeking

## The tank on its high block and a pool at every drain, each turned so its
## one mouth faces the pipeline. Both stand on a crown, so they are turned
## about the vertical only -- which is why the generator never hands a fixture
## a mouth pointing up or down.
func _build_fixtures() -> void:
	_add_fixture(_source, "source", _source_mask)
	for drain in _drains:
		_add_fixture(drain, "drain", int(_drain_masks[drain]))
		_set_drain_fed(drain, false)

func _add_fixture(cell: Vector3i, kind: String, mask: int) -> void:
	var pivot := Node3D.new()
	pivot.name = "%s_%d_%d_%d" % [kind, cell.x, cell.y, cell.z]
	pivot.position = _cell_floor(cell)
	pivot.basis = Gen.basis_for(kind, mask)
	board.add_child(pivot)
	var model := Models.instance(Gen.SLOT[kind])
	pivot.add_child(model)
	_fixtures[cell] = pivot

## A drain's basin is dark until the water arrives and the stage's own water
## once it has, so it ripples and catches the same bands as the sea.
func _set_drain_fed(cell: Vector3i, fed: bool) -> void:
	var pivot: Node3D = _fixtures.get(cell)
	if pivot == null:
		return
	var mat: Material = Toon.water() if fed else Toon.material(Pal.FLOW_DRY)
	Models.set_material_named(pivot, "Water_flat", mat)

# --- geometry ---

## The centre of a cell's floor.
func _cell_floor(cell: Vector3i) -> Vector3:
	return BoardMath.cell_center(cell.z, cell.x, cols, rows, float(cell.y))

## A piece's hub: the point its arms radiate from, and the only point two
## pieces have to agree on. TUBE_Y above the cell's floor, so two cells one
## level apart have hubs exactly one unit apart and their arms meet.
func _hub(cell: Vector3i) -> Vector3:
	return _cell_floor(cell) + Vector3(0.0, Placeholders.TUBE_Y, 0.0)

## Where a mouth opens, which is what a tap is tested against.
func _mouth_point(cell: Vector3i, bit: int) -> Vector3:
	var step: Vector3i = Gen.STEP[bit]
	return _hub(cell) + Vector3(step) * Placeholders.ARM_LEN

## How high a model's own hub sits above its base. Every pipe piece is
## modelled with its tube at TUBE_Y; the pump stands on end, so its hub is
## half its own length up.
static func _model_hub(kind: String) -> float:
	if kind == "pump":
		return Placeholders.PUMP_HUB
	return Placeholders.TUBE_Y

## Control-local point over a cell's hub. The win harness taps these.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(_hub(Vector3i(c, Gen.height_at(_heights, c, r), r)))

func mouth_to_local(cell: Vector3i, bit: int) -> Vector2:
	return board_to_local(_mouth_point(cell, bit))

## Control-local point over a placed piece, which is what a tap that turns or
## lifts one has to land on.
func hub_to_local(cell: Vector3i) -> Vector2:
	return board_to_local(_hub(cell))

## The mask a cell is carrying, or 0. The win harness reads it to know whether
## a piece still needs turning.
func mask_at(cell: Vector3i) -> int:
	if _placed.has(cell):
		return int(_placed[cell].mask)
	if cell == _source:
		return _source_mask
	if _drains.has(cell):
		return int(_drain_masks[cell])
	return 0

## Whether the cell holds anything at all, a fixture included.
func filled(cell: Vector3i) -> bool:
	return _placed.has(cell) or _fixtures.has(cell)

## Which tray entry a kind is, for a harness that presses the tray button
## rather than reaching into the board.
func tray_index(kind: String) -> int:
	return _tray_kinds.find(kind)

# --- pieces on the island ---

## Puts `kind` in `cell` at `mask`, taking it out of the tray. `dropped` plays
## the arrival; an undo puts a piece back without one.
func _put(cell: Vector3i, kind: String, mask: int, dropped: bool) -> void:
	_placed[cell] = {"kind": kind, "mask": mask}
	_tray[kind] = maxi(int(_tray.get(kind, 0)) - 1, 0)
	_turned[cell] = _orientation_index(kind, mask)
	var pivot := Node3D.new()
	pivot.name = "piece_%d_%d_%d" % [cell.x, cell.y, cell.z]
	pivot.position = _hub(cell)
	pivot.basis = Gen.basis_for(kind, mask)
	board.add_child(pivot)
	var model := Models.instance(Gen.SLOT[kind])
	model.position = Vector3(0.0, -_model_hub(kind), 0.0)
	pivot.add_child(model)
	_pivots[cell] = pivot
	_models[cell] = model
	_flow_mats[cell] = Models.material_named(model, "Flow_flat")
	_wet[cell] = 0.0
	_paint_crown(cell)
	if dropped:
		pivot.position = _hub(cell) + Vector3(0.0, PLACE_DROP, 0.0)
		Motion.stop(_piece_tw.get(cell))
		_piece_tw[cell] = Motion.settle(pivot, "position:y", _hub(cell).y, PLACE_TIME)
		if _piece_tw[cell] == null:
			pivot.position = _hub(cell)
		else:
			Motion.squash(model, SQUASH, SQUASH_TIME, PLACE_TIME * 0.8)
		fx.cue("place")

## Takes the piece in `cell` off the island and back into the tray.
func _remove(cell: Vector3i, lifted: bool) -> void:
	if not _placed.has(cell):
		return
	var kind := String(_placed[cell].kind)
	_tray[kind] = int(_tray.get(kind, 0)) + 1
	_placed.erase(cell)
	_locked.erase(cell)
	_turned.erase(cell)
	_wet.erase(cell)
	_flow_mats.erase(cell)
	_free_piece(cell, lifted)
	_paint_crown(cell)

func _free_piece(cell: Vector3i, lifted := false) -> void:
	var pivot: Node3D = _pivots.get(cell)
	if pivot == null:
		return
	_pivots.erase(cell)
	_models.erase(cell)
	Motion.stop(_piece_tw.get(cell))
	_piece_tw.erase(cell)
	Motion.stop(_fade_tw.get(cell))
	_fade_tw.erase(cell)
	var tw: Tween = Motion.vanish(pivot, PLACE_DROP * 0.3, LIFT_TIME) if lifted else null
	if tw == null:
		pivot.queue_free()
	else:
		tw.finished.connect(pivot.queue_free)
	if lifted:
		fx.cue("lift")

## Turns the piece in `cell` onto `mask`, with no tray bookkeeping.
func _set_mask(cell: Vector3i, mask: int) -> void:
	if not _placed.has(cell):
		return
	var kind := String(_placed[cell].kind)
	_placed[cell] = {"kind": kind, "mask": mask}
	_turned[cell] = _orientation_index(kind, mask)
	var pivot: Node3D = _pivots[cell]
	Motion.stop(_piece_tw.get(cell))
	# The turn is the state change, so it survives reduce-motion.
	_piece_tw[cell] = Motion.settle(pivot, "basis", Gen.basis_for(kind, mask), TURN_TIME, 0.0, true)
	if _piece_tw[cell] == null:
		pivot.basis = Gen.basis_for(kind, mask)
	Motion.squash(_models[cell], SQUASH, SQUASH_TIME)
	fx.puff(_hub(cell), Pal.STEEL)
	fx.cue("turn")

static func _orientation_index(kind: String, mask: int) -> int:
	var all := Gen.kind_orientations(kind)
	for i in all.size():
		if int(all[i].mask) == mask:
			return i
	return 0

## The crown under a piece is a pad of pale stone, and the given stone where a
## hint placed it. Nothing under it means plain grass again.
func _paint_crown(cell: Vector3i) -> void:
	var col := Vector2i(cell.x, cell.z)
	var which := CROWN_GRASS
	for other in _placed:
		if other.x != cell.x or other.z != cell.z:
			continue
		which = CROWN_GIVEN if _locked.has(other) else maxi(which, CROWN_STONE)
	if int(_crown_colour.get(col, CROWN_GRASS)) == which:
		return
	_crown_colour[col] = which
	_rebuild_crowns()

# --- placing, turning and lifting ---

## The mouths a tap can land on: every open mouth of every piece and fixture
## that has a legal cell behind it, plus the marker the player sees there.
func _rebuild_buds() -> void:
	var pieces := _all_pieces()
	_bud_points = []
	var transforms: Array[Transform3D] = []
	for cell in pieces:
		var mask: int = int(pieces[cell].mask)
		for bit in Gen.bits(mask):
			if Gen.meets(pieces, cell, bit):
				continue
			var step: Vector3i = Gen.STEP[bit]
			var target: Vector3i = cell + step
			if not Gen.is_air(target, _heights, cols, rows, levels):
				continue
			if pieces.has(target):
				continue
			var at := _mouth_point(cell, bit)
			_bud_points.append({"cell": cell, "bit": bit, "at": at})
			transforms.append(Transform3D(Basis().scaled(Vector3.ONE * MOUTH_R), at))
	if _buds == null or not is_instance_valid(_buds):
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 10
		ball.rings = 5
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ball
		_buds = MultiMeshInstance3D.new()
		_buds.name = "Mouths"
		_buds.multimesh = mm
		_buds.material_override = Toon.ghost(Pal.MOON, 0.5)
		_buds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.add_child(_buds)
	_buds.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_buds.multimesh.set_instance_transform(i, transforms[i])

## Places the selected piece in the cell the mouth (`cell`, `bit`) faces,
## turned so it connects. The selection stays, so straights chain.
func _place_at_mouth(cell: Vector3i, bit: int) -> void:
	var target: Vector3i = cell + Gen.STEP[bit]
	var need: int = Gen.OPPOSITE[bit]
	var mask := _first_orientation(_selected, target, need)
	if mask == 0:
		_refuse(target)
		return
	_put(target, _selected, mask, true)
	_history.append({"op": "place", "cell": target, "kind": _selected, "mask": mask})
	_after_change()

## Places the selected piece flat on a block's crown, connected to nothing:
## for starting a stretch early, or laying pieces near a drain and working
## back.
func _place_on_crown(cell: Vector3i) -> void:
	var mask := _first_orientation(_selected, cell, 0)
	if mask == 0:
		_refuse(cell)
		return
	_put(cell, _selected, mask, true)
	_history.append({"op": "place", "cell": cell, "kind": _selected, "mask": mask})
	_after_change()

## The first orientation of `kind` that stands in `cell` and, when `need` is
## given, opens toward it.
func _first_orientation(kind: String, cell: Vector3i, need: int) -> int:
	if kind == "" or int(_tray.get(kind, 0)) <= 0:
		return 0
	if _placed.has(cell) or _fixtures.has(cell):
		return 0
	for o in Gen.kind_orientations(kind):
		var mask := int(o.mask)
		if need != 0 and mask & need == 0:
			continue
		if not _stands(cell, mask):
			continue
		return mask
	return 0

## A tap on a placed piece: the next of its orientations that still stands.
func _cycle(cell: Vector3i) -> void:
	if _locked.has(cell):
		_refuse(cell)
		return
	var kind := String(_placed[cell].kind)
	var all := Gen.kind_orientations(kind)
	var from := int(_turned.get(cell, 0))
	for step in range(1, all.size() + 1):
		var next: int = (from + step) % all.size()
		var mask := int(all[next].mask)
		if mask == int(_placed[cell].mask):
			continue
		if not _stands(cell, mask):
			continue
		_history.append({"op": "turn", "cell": cell, "mask": int(_placed[cell].mask)})
		_set_mask(cell, mask)
		_after_change()
		return
	_refuse(cell)

## A long press: the piece goes back to the tray. Whatever it was feeding
## stays where it is and goes dry.
func _lift(cell: Vector3i) -> void:
	if _locked.has(cell):
		_refuse(cell)
		return
	var kind := String(_placed[cell].kind)
	var mask := int(_placed[cell].mask)
	_history.append({"op": "lift", "cell": cell, "kind": kind, "mask": mask})
	_remove(cell, true)
	_after_change()

## A tap that cannot do anything: the cell dips and the board says no.
func _refuse(cell: Vector3i) -> void:
	var node: Node3D = _pivots.get(cell)
	if node == null:
		node = _fixtures.get(cell)
	if node != null:
		Motion.stop(_piece_tw.get(cell))
		var rest: float = node.position.y
		_piece_tw[cell] = Motion.hop(node, -DIP, DIP_TIME, 0.0, rest)
	fx.cue("locked")

func _after_change() -> void:
	_reflow(true)
	note_move()

# --- the water ---

## Recomputes the flood and moves the board to match: the pieces that just
## filled light up in a wave outward from the source, the ones that emptied
## fade back, the jets follow and the drains fill.
func _reflow(animate: bool) -> void:
	var before: Dictionary = _fed.duplicate()
	var pieces := _all_pieces()
	_fed = Gen.flow(pieces, _source).fed
	var wet_base := -1
	var dry_base := -1
	for cell in _fed:
		if not before.has(cell) and (wet_base < 0 or int(_fed[cell]) < wet_base):
			wet_base = int(_fed[cell])
	for cell in before:
		if not _fed.has(cell) and (dry_base < 0 or int(before[cell]) < dry_base):
			dry_base = int(before[cell])
	for cell in _placed:
		var now: bool = _fed.has(cell)
		if now == before.has(cell) and animate:
			continue
		var target := 1.0 if now else 0.0
		if not animate:
			_set_wet_now(cell, target)
		elif now:
			_set_wet(cell, target, minf((int(_fed[cell]) - wet_base) * FLOW_STEP, FLOW_CAP))
		else:
			_set_wet(cell, target, minf((int(before[cell]) - dry_base) * FLOW_OUT_STEP, FLOW_CAP))
	for drain in _drains:
		var filled: bool = _fed.has(drain)
		if filled != before.has(drain):
			_set_drain_fed(drain, filled)
			if filled:
				fx.sparkle(_cell_floor(drain) + Vector3(0.0, SPARKLE_LIFT, 0.0), Pal.WATER_HI)
				fx.cue("drain")
	_rebuild_buds()
	_run_jets()
	if animate:
		if wet_base >= 0:
			fx.cue("flow")
		elif dry_base >= 0:
			fx.cue("flow_out")
	check_solved()

## Applies wetness `t` to one piece: the shell and collar tints and its own
## flow material's `wet` uniform, the three surfaces that say "water".
func _apply_wet(cell: Vector3i, t: float) -> void:
	_wet[cell] = t
	var model: Node3D = _models.get(cell)
	if model == null:
		return
	Models.tint_named(model, "Steel", Pal.STEEL.lerp(Pal.PIPE_WET, t))
	Models.tint_named(model, "Collar", Pal.STEEL_HI.lerp(Pal.PIPE_WET_HI, t))
	var mat: ShaderMaterial = _flow_mats.get(cell)
	if mat != null:
		mat.set_shader_parameter("wet", t)
	# A pump that is lifting water lights its collar, which is the only way to
	# see from outside that a climb is working.
	if String(_placed[cell].kind) == "pump":
		Models.tint_named(model, "Lit", Pal.STEEL_HI.lerp(Pal.SUN, t))

func _set_wet(cell: Vector3i, target: float, delay := 0.0) -> void:
	var from: float = float(_wet.get(cell, 0.0))
	Motion.stop(_fade_tw.get(cell))
	var setter := func(t: float) -> void: _apply_wet(cell, t)
	_fade_tw[cell] = Motion.fade(_models[cell], setter, from, target, FADE_TIME, FADE_STEPS, delay)

func _set_wet_now(cell: Vector3i, target: float) -> void:
	Motion.stop(_fade_tw.get(cell))
	_fade_tw.erase(cell)
	_apply_wet(cell, target)

## Points a jet at every place water is actually leaving a pipe: the source's
## own mouth while it feeds nothing, and each fed mouth that meets nothing,
## nearest the source first. A mouth that has just been met is stopped, since
## Fx.jet only sets its position once and then runs.
func _run_jets() -> void:
	if fx == null or not is_instance_valid(fx):
		return
	var pieces := _all_pieces()
	var want: Dictionary = {}
	for leak in Gen.leaks(pieces, _fed):
		if want.size() >= MAX_LEAKS:
			break
		var cell: Vector3i = leak.cell
		if want.has(cell):
			continue   # one jet per piece, whatever it is pouring out of
		var step: Vector3i = Gen.STEP[int(leak.bit)]
		want[cell] = _hub(cell) + Vector3(step) * (Placeholders.ARM_LEN + JET_OUT) \
			+ Vector3(0.0, JET_LIFT, 0.0)
	for cell in _leak_jets.keys():
		if not want.has(cell) or want[cell] != _leak_at[cell]:
			fx.stop_jet(_leak_jets[cell])
			_leak_jets.erase(cell)
			_leak_at.erase(cell)
	var leaked := false
	for cell in want:
		if _leak_jets.has(cell):
			continue
		var handle: int = fx.jet(want[cell], Pal.WATER_HI)
		if handle < 0:
			continue
		leaked = true
		_leak_jets[cell] = handle
		_leak_at[cell] = want[cell]
		fx.puff(want[cell], Pal.WATER_HI)
	for drain in _drains:
		if _fed.has(drain) and not _drain_jets.has(drain):
			var handle: int = fx.jet(_cell_floor(drain) + Vector3(0.0, Placeholders.TUBE_Y, 0.0), Pal.WATER_HI)
			if handle >= 0:
				_drain_jets[drain] = handle
		elif not _fed.has(drain) and _drain_jets.has(drain):
			fx.stop_jet(_drain_jets[drain])
			_drain_jets.erase(drain)
	if leaked:
		fx.cue("leak")

# --- gestures ---

## Touch only, and all of it read here rather than through the base's
## board-plane hit: cells sit at many heights, so there is no one plane to
## intersect. A press remembers what it hit; the release decides what that
## meant, and a press held long enough lifts a piece before it is let go.
func _gui_input(event: InputEvent) -> void:
	if is_done():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_at = event.position
			_press_time = 0.0
			_press_live = true
			_press_used = false
			_press_hit = _pick(event.position)
		elif _press_live:
			_press_live = false
			if not _press_used:
				_release(event.position)
	elif event is InputEventScreenDrag and _press_live:
		if event.position.distance_to(_press_at) > SWIPE_MIN * 0.5:
			# A drag is a look, not a build: a long press cannot fire from it.
			_press_time = 0.0

func _process(delta: float) -> void:
	super(delta)
	if not _press_live or _press_used:
		return
	_press_time += delta
	if _press_time < LONG_PRESS:
		return
	if String(_press_hit.get("what", "")) == "piece":
		_press_used = true
		_lift(_press_hit.cell)

## What the press meant, now that it is over: a swipe across empty ground
## turns the island, a mouth places, a piece turns, a crown places flat.
func _release(at: Vector2) -> void:
	var drag := at - _press_at
	var what := String(_press_hit.get("what", ""))
	if absf(drag.x) > SWIPE_MIN and absf(drag.x) > absf(drag.y) and what != "piece":
		turn_view()
		return
	if drag.length() > SWIPE_MIN:
		return
	match what:
		"mouth":
			_place_at_mouth(_press_hit.cell, int(_press_hit.bit))
		"piece":
			_cycle(_press_hit.cell)
		"crown":
			_place_on_crown(_press_hit.cell)

## What the ray under `local` hits first: an open mouth, a placed piece, or a
## column's crown. A mouth wins a tie, because it hovers over the very crown
## it would otherwise be lost behind.
func _pick(local: Vector2) -> Dictionary:
	var ray := local_ray(local)
	if ray.is_empty():
		return {}
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var best: Dictionary = {}
	# Nothing behind the ground can be tapped, so a tap on a cliff face turns
	# no pipe hidden behind it. While peek is held the ground is see-through
	# and so is the cutoff: what the player can see, the player can reach.
	var best_t: float = _ground_distance(origin, dir)
	for bud in _bud_points:
		var t := _ray_sphere(origin, dir, bud.at, MOUTH_R)
		if t >= 0.0 and t < best_t - 0.001:
			best_t = t
			best = {"what": "mouth", "cell": bud.cell, "bit": int(bud.bit)}
	for cell in _pivots:
		var t := _ray_sphere(origin, dir, _hub(cell), PIECE_R)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"what": "piece", "cell": cell}
	for z in rows:
		for x in cols:
			var cell := Gen.crown(_heights, x, z)
			if _placed.has(cell) or _fixtures.has(cell):
				continue
			var t := _ray_square(origin, dir, _cell_floor(cell))
			if t >= 0.0 and t < best_t:
				best_t = t
				best = {"what": "crown", "cell": cell}
	return best

## How far along the ray the island's own blocks get in the way, or INF. The
## terrain is a heightfield, so marching it is exact enough and much cheaper
## than a collision shape per block; the tolerance lets a mouth hovering over
## the edge of the block in front of it still be tapped.
const GROUND_STEP := 0.2
const GROUND_REACH := 60.0
const GROUND_SLACK := 0.15

func _ground_distance(origin: Vector3, dir: Vector3) -> float:
	if _peeking:
		return INF
	var t := 0.0
	while t < GROUND_REACH:
		t += GROUND_STEP
		var p := origin + dir * t
		if p.y > float(levels) + 0.001:
			continue
		if p.y < -0.5:
			break
		var col := _column_at(p)
		if not Gen.in_bounds(col.x, col.y, cols, rows):
			continue
		if p.y < float(Gen.height_at(_heights, col.x, col.y)):
			return t + GROUND_SLACK
	return INF

## The column a board-space point stands over.
func _column_at(p: Vector3) -> Vector2i:
	var o := BoardMath.cell_origin(cols, rows)
	return Vector2i(floori(p.x - o.x), floori(p.z - o.z))

## Where the ray first meets the sphere, or -1. Only the near root matters: a
## tap comes from outside every piece.
static func _ray_sphere(origin: Vector3, dir: Vector3, centre: Vector3, radius: float) -> float:
	var to := origin - centre
	var b := to.dot(dir)
	var c := to.length_squared() - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else -1.0

## Where the ray meets the unit square lying at `centre`, or -1.
static func _ray_square(origin: Vector3, dir: Vector3, centre: Vector3) -> float:
	if absf(dir.y) < 1e-6:
		return -1.0
	var t := (centre.y - origin.y) / dir.y
	if t < 0.0:
		return -1.0
	var p := origin + dir * t
	if absf(p.x - centre.x) > 0.5 or absf(p.z - centre.z) > 0.5:
		return -1.0
	return t

# --- entrance and win ---

## The island arrives: it rises out of the water, its levels landing from the
## bottom up, then the tank and the pools pop in and the source starts
## pouring.
func _enter() -> void:
	_stop_entrance()
	_ground.position.y = -ENTER_RISE
	var rise: Tween = Motion.settle(_ground, "position:y", 0.0, ENTER_TIME)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_TIME * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for y in _level_nodes.size():
		var node: Node3D = _level_nodes[y]
		node.scale = Vector3(1.0, 0.01, 1.0)
		var pop: Tween = Motion.settle(node, "scale", Vector3.ONE, ENTER_POP,
			ENTER_TIME * 0.5 + Motion.stagger(y, ENTER_LEVEL))
		if pop != null:
			_entrance.append(pop)
	for cell in _fixtures:
		var pivot: Node3D = _fixtures[cell]
		pivot.scale = Vector3.ONE * 0.01
		var pop2: Tween = Motion.settle(pivot, "scale", Vector3.ONE, ENTER_POP,
			ENTER_TIME + Motion.stagger(_level_nodes.size(), ENTER_LEVEL))
		if pop2 != null:
			_entrance.append(pop2)
	fx.cue("enter")

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _ground != null and is_instance_valid(_ground):
		_ground.position.y = 0.0
		for node in _level_nodes:
			(node as Node3D).scale = Vector3.ONE
	for cell in _fixtures:
		var pivot: Node3D = _fixtures[cell]
		if is_instance_valid(pivot):
			pivot.scale = Vector3.ONE

## Rings the water under the island, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## The pipeline is finished: the water runs faster, the drains ripple and the
## island turns once all the way round so the route can be admired from every
## side.
func _on_solved() -> void:
	_stop_entrance()
	for cell in _flow_mats:
		var mat: ShaderMaterial = _flow_mats[cell]
		if mat != null:
			mat.set_shader_parameter("flow_speed", WIN_FLOW)
	Motion.stop(_win_tw)
	if Motion.reduce:
		fx.cue("solved")
		return
	var tw := board.create_tween()
	for _i in STOPS:
		tw.tween_interval(WIN_TURN_GAP)
		tw.tween_callback(func() -> void:
			_stop = (_stop + 1) % STOPS
			if _stage != null and is_instance_valid(_stage) and _stage.has_method("turn"):
				_stage.turn(1))
	_win_tw = tw
	fx.cue("solved")
