extends "res://core/puzzle_base_3d.gd"

## Enclose the Horse, played on a meadow rather than on a board. Grass runs
## off every edge of the screen; the field the puzzle is played on is a
## lighter patch of it, cut up by water channels with earth banks, with
## boulders lying on it, a cream horse standing somewhere on it and apples
## about. Tap grass to drop a hay bale, tap the bale to lift it again. The
## horse walks up, down, left and right, never through a bale, a boulder or
## water; the pen is closed once it can no longer reach the edge of the field.
## Every cell it can still reach is penned and worth a point, an apple in the
## pen three more.
##
## The meadow the horse can reach is always shown: wheat stands up out of the
## turf and the turf itself goes a trampled pale. Drop a bale and the wheat
## sinks back to what the horse can still get to; lift one and it grows out
## again. So the player reads the pen off the ground, the way the original
## enclose.horse shows it, and the status card keeps the count.
##
## The daily framing: the bales come from a limited stock, and the day sets a
## target -- the score of a pen the generator itself managed to close within
## that stock. When the horse is penned with at least that much meadow the
## player submits (the Check button, relabelled), which ends the day; until
## then they may keep rebuilding for a bigger pen. Submitting an open pen
## flashes the edge cells the horse can still reach.
##
## Design: agreed in chat on 2026-09-15 (no spec file by request), revised the
## same day against a screenshot of the original, then polished against it in
## docs/brainstorm/concepts.html (the Horse Pen tab) -- the plate became the
## meadow, the see-through fence became a hay bale, the ponds became cut
## channels and the reach grew standing wheat.

const Gen = preload("res://puzzles/horse_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://world/scenery.gd")
const Toon = preload("res://core/toon.gd")
const Fx = preload("res://world/fx.gd")

## A bale arriving on a cell, and one being lifted away. It falls from a cell
## above and settles, so it reads as something dropped rather than grown.
const POP_TIME := 0.22
const DROP_FROM := 1.0
const SQUASH := 0.18
const VANISH_LIFT := 0.12
const VANISH_TIME := 0.16
## A refused tap (water, a boulder, an apple, a hinted bale, an empty stock).
const DIP := 0.04
const DIP_TIME := 0.3
const HINTS := 3
const SPARKLE_LIFT := 0.3
## The trampled meadow following the horse's reach as bales go up and come
## down. One tween moves every changing cell at once, quantised so the toon
## material cache stays bounded; the wheat rises and sinks on the same blend.
const REACH_STEPS := 16
const REACH_TIME := 0.35
## Submitting an open pen: the edge cells the horse reaches blush and fade.
const GAP_IN := 0.15
const GAP_HOLD := 0.6
const GAP_OUT := 0.45
## The entrance: the field grows from the horse outward, then the horse lands.
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.02
const ENTER_CAP := 0.8
const ENTER_WATER := 0.14
const ENTER_TREE := 0.03
const HORSE_DROP := 1.4
const HORSE_LAND := 0.4
const SOLVE_HOP := 0.18
const SOLVE_TIME := 0.5
const SOLVE_STAGGER := 0.04
## The flowers opening over a closed pen, from the horse outward.
const BLOOM_TIME := 1.1
const BLOOM_STEPS := 14
const BLOOM_PER_CELL := 2

## Steeper than the island's own 68: the reference reads as a field seen from
## nearly above, and a bale, a boulder and the horse all keep a front face at
## 72. Straight down would flatten them to squares, which pixel art can afford
## and a toon scene cannot.
const PITCH := 72.0

## The meadow around the field. Four slabs of turf, a shade darker than the
## field and flush with its top, so the boundary is a change of colour and a
## hairline seam -- no wall and no lip, because an edge cell is open and open
## is the point of the game. One more slab lies under the field at the
## channels' floor: what shows in the 0.04 seams between two turf pads, which
## is the field's faint garden-plot grid.
const RING_TOP := Placeholders.TURF_H
const RING_OUT := 40.0
const RING_DEPTH := 2.0
const BED_TOP := 0.0
const BED_DEPTH := 1.0
const TUFT_COUNT := 260
const TUFT_BAND := 12.0
const TREE_COUNT := 8
const TREE_OUT_MIN := 1.2
const TREE_OUT_MAX := 2.6
const TREE_SCALE_MIN := 1.3
const TREE_SCALE_MAX := 1.9
## Fixed, so the meadow around the field is the same every day: the ring is
## scenery, not part of the puzzle.
const RING_SEED := 20260915

## Wheat: three tufts per cell, standing where the horse can still walk. One
## MultiMesh for the whole field, so the meadow costs one draw call.
const STALKS_PER_CELL := 3
## A boulder is Code Break's rounded rock, squatter than a cell so fixed stone
## never reads as a piece the player put there.
const ROCK_SCALE := 0.8
const APPLE_SCALE := 1.15
const APPLE_BOB := 0.05
const APPLE_BOB_TIME := 2.6
## The horse fills nine tenths of its cell, measured off the model so the
## export and the placeholder come out the same size.
const HORSE_FILL := 0.9

var w: int = 8
var h: int = 10
var _water: Dictionary = {}          # Vector2i -> true
var _stones: Dictionary = {}         # Vector2i -> true, a boulder on the grass
var _blocked: Dictionary = {}        # water and stones together
var _horse := Vector2i(-1, -1)
var _apples: Dictionary = {}         # Vector2i -> true
var _budget: int = 8
var _target: int = 0
var _solution_walls: Array = []
var _walls: Dictionary = {}          # Vector2i -> true, a bale standing
var _locked: Dictionary = {}         # Vector2i -> true, a bale a hint dropped
var _submitted := false

var fx: Node3D
var _pads: Array = []                # [r][c] -> Node3D pivot
var _pad_models: Array = []          # [r][c] -> turf model, or null on water
var _water_nodes: Dictionary = {}    # Vector2i -> the channel's water mesh
var _horse_pivot: Node3D
var _horse_model: Node3D
var _apple_nodes: Dictionary = {}    # Vector2i -> Node3D
var _apple_tw: Dictionary = {}       # Vector2i -> the bob, looping
var _stone_nodes: Dictionary = {}    # Vector2i -> Node3D
var _trees: Array = []               # Node3D pivots in the ring
var _bales: Dictionary = {}          # Vector2i -> Node3D pivot
var _bale_tw: Dictionary = {}        # Vector2i -> a dip, drop or hop in flight
var _pad_tw: Dictionary = {}         # Vector2i -> a dip in flight
## The wheat and the trampling on every turf cell, 0 green to 1 reached: where
## it is painted now, where it is heading, and where it started its move.
var _reach_now: Dictionary = {}
var _reach_target: Dictionary = {}
var _reach_from: Dictionary = {}
var _reach_tw: Tween
var _gap_tw: Tween
var _gap_cells: Array = []
var _horse_tw: Tween
var _entrance: Array = []
var _first_paint := true
## The wheat: one MultiMesh over the field, with the instance range each cell
## owns and the transform each stalk stands at when the cell is fully reached.
var _stalks: MultiMeshInstance3D
var _stalk_at: Dictionary = {}       # Vector2i -> first instance index
var _stalk_rest: Array[Transform3D] = []
## The flowers that open over a closed pen, and how far from the horse each
## one stands, so the bloom runs outward.
var _blooms: MultiMeshInstance3D
var _bloom_rest: Array[Transform3D] = []
var _bloom_dist: Array[int] = []
var _bloom_front := -1.0
var _bloom_tw: Tween
## One entry per tap that can be taken back: the cell and whether it held a
## bale before the tap.
var _history: Array[Vector3i] = []

func _ready() -> void:
	super()
	solved.connect(_on_solved)

func puzzle_id() -> String: return "horse"
func title() -> String: return "Horse Pen"

func rules() -> String:
	return ("Tap grass to drop a hay bale. "
		+ "The horse walks up, down, left and right, never through bales, boulders or water. "
		+ "The pale wheat is where it can still go: cut it off from every edge, "
		+ "keep the target, and submit. Grass counts one, an apple three.")

func board_size() -> Vector2i: return Vector2i(w, h)
func board_height() -> float: return Placeholders.TURF_H + Placeholders.HORSE_H
func plane_height() -> float: return Placeholders.TURF_H
## The field is framed on its own: there is no plate to leave room for, and
## the meadow beyond it is scenery that fills out to the corners.
func board_margin() -> float: return 0.0
func board_depth() -> float: return 0.0
func board_pitch() -> float: return PITCH

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var streams := 3
	var pools := 1
	var stones := 2
	var apples := 2
	match difficulty:
		0: w = 8; h = 10; _budget = 7; streams = 3; pools = 1; stones = 2; apples = 2
		1: w = 9; h = 12; _budget = 9; streams = 3; pools = 2; stones = 3; apples = 3
		_: w = 10; h = 13; _budget = 10; streams = 4; pools = 2; stones = 4; apples = 3
	var out: Dictionary = Gen.generate(rng, w, h, _budget, streams, pools, stones, apples)
	_water = {}
	for c in out.water:
		_water[c] = true
	_stones = {}
	for c in out.stones:
		_stones[c] = true
	_blocked = _water.duplicate()
	for c in _stones:
		_blocked[c] = true
	_apples = {}
	for c in out.apples:
		_apples[c] = true
	_horse = out.horse
	_target = int(out.target)
	_solution_walls = out.solution_walls
	_walls = {}
	_locked = {}
	_submitted = false
	_history = []
	_first_paint = true
	_build_scene()
	_recolour()
	_refit()
	_enter()

## Every bale comes down at once. Hints are unpinned but not refunded.
func reset_board() -> void:
	_stop_entrance()
	_end_gaps()
	for cell in _walls.keys():
		_drop_bale(cell)
	_walls = {}
	_locked = {}
	_submitted = false
	_history = []
	moves = 0
	_recolour()
	fx.cue("reset")

## Solved means submitted with a closed pen worth the target. Closing the pen
## alone does not end the day: the player may keep building for more meadow.
func is_solved() -> bool:
	if _horse.x < 0 or not _submitted:
		return false
	return Gen.is_valid_solution(_horse, w, h, _blocked, _walls, _apples, _budget, _target)

func share_glyphs() -> String:
	var reach: Dictionary = _reach().cells
	var out := ""
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if c == _horse:
				out += "🐴"
			elif _water.has(c):
				out += "🟦"
			elif _stones.has(c):
				out += "⬜"
			elif _walls.has(c):
				out += "🟫"
			elif _apples.has(c):
				out += "🍎"
			elif reach.has(c):
				out += "🟨"
			else:
				out += "🟩"
		out += "\n"
	return out

# --- the rules, as the board reads them ---

## Where the horse can get to right now.
func _reach() -> Dictionary:
	return Gen.reach(_horse, w, h, _blocked, _walls)

## The score of everything the horse can reach, apples counting extra. Read
## by the status card and the win harness.
func score() -> int:
	return Gen.score_of(_reach().cells, _apples)

## Two lines for the status card: the stock and the target, then how much the
## horse can reach and whether it is penned.
func status_text() -> String:
	var r := _reach()
	var reach := Gen.score_of(r.cells, _apples)
	var state := "horse loose" if r.escaped else ("penned, submit" if reach >= _target else "penned, too small")
	return "Bales %d / %d  ·  Target %d\nMeadow %d  ·  %s" % [_walls.size(), _budget, _target, reach, state]

func check_label() -> String:
	return "Submit"

# --- scene ---

func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for store in [_bale_tw, _pad_tw, _apple_tw]:
		for key in store:
			Motion.stop(store[key])
	Motion.stop(_reach_tw)
	Motion.stop(_gap_tw)
	Motion.stop(_horse_tw)
	Motion.stop(_bloom_tw)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_pads = []
	_pad_models = []
	_water_nodes = {}
	_apple_nodes = {}
	_apple_tw = {}
	_stone_nodes = {}
	_trees = []
	_bales = {}
	_bale_tw = {}
	_pad_tw = {}
	_reach_now = {}
	_reach_target = {}
	_reach_from = {}
	_gap_cells = []
	_stalk_at = {}
	_stalk_rest = []
	_bloom_rest = []
	_bloom_dist = []
	_bloom_front = -1.0

	board.add_child(_ring())
	fx = Fx.new()
	board.add_child(fx)

	for r in h:
		var pad_row := []
		var model_row := []
		for c in w:
			var cell := Vector2i(c, r)
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, w, h)
			board.add_child(pivot)
			if _water.has(cell):
				pivot.add_child(_channel(cell))
				model_row.append(null)
			else:
				var pad := Models.instance("turf_pad")
				# The board's own grid is the seam between two pads over the
				# darker turf below, not a line drawn round every cell: this
				# is a meadow, and a hard outline per cell is the look of a
				# board (concepts.html, the Horse Pen tab, section 4).
				_hide_outline(pad)
				pivot.add_child(pad)
				model_row.append(pad)
				_reach_now[cell] = 0.0
				if _stones.has(cell):
					var stone := Models.instance("boulder")
					stone.name = "boulder"
					stone.scale = Vector3.ONE * ROCK_SCALE
					stone.position.y = Placeholders.TURF_H
					pivot.add_child(stone)
					_stone_nodes[cell] = stone
				elif _apples.has(cell):
					var apple := Models.instance("apple")
					apple.scale = Vector3.ONE * APPLE_SCALE
					apple.position.y = Placeholders.TURF_H
					pivot.add_child(apple)
					_apple_nodes[cell] = apple
			pad_row.append(pivot)
		_pads.append(pad_row)
		_pad_models.append(model_row)

	_build_stalks()

	_horse_pivot = Node3D.new()
	_horse_pivot.name = "horse"
	_horse_pivot.position = BoardMath.cell_center(_horse.y, _horse.x, w, h, Placeholders.TURF_H)
	board.add_child(_horse_pivot)
	_horse_model = Models.instance("horse")
	# Cream coat, dark mane: tints on the layers the model already carries.
	# Brown on pale wheat is what made the eye find the boulders first.
	Models.tint_named(_horse_model, "Hide", Pal.HIDE)
	Models.tint_named(_horse_model, "Mane", Pal.MANE)
	_horse_model.scale = Vector3.ONE * _fill_scale(_horse_model, HORSE_FILL)
	_horse_pivot.add_child(_horse_model)

	for cell in _apple_nodes:
		var rest: float = Placeholders.TURF_H
		_apple_tw[cell] = Motion.pulse(_apple_nodes[cell], "position:y", rest, rest + APPLE_BOB, APPLE_BOB_TIME)

## The meadow the field is a patch of: turf out to the corners of the screen
## on all four sides, flush with the field's own top, plus one slab under the
## field at the channels' floor. Tufts as one MultiMesh and a handful of
## Tents' conifers stand in it, none of them on the near side where a tree
## would lean over the field.
func _ring() -> Node3D:
	var root := Node3D.new()
	root.name = "Ring"
	var hx := w * 0.5
	var hz := h * 0.5
	var ring_y := RING_TOP - RING_DEPTH * 0.5
	var far := RING_OUT
	# Near and far bands run the full width; the two side bands fill between.
	for band in [[Vector3(hx * 2.0 + far * 2.0, RING_DEPTH, far), Vector3(0.0, ring_y, -hz - far * 0.5)],
			[Vector3(hx * 2.0 + far * 2.0, RING_DEPTH, far), Vector3(0.0, ring_y, hz + far * 0.5)],
			[Vector3(far, RING_DEPTH, hz * 2.0), Vector3(-hx - far * 0.5, ring_y, 0.0)],
			[Vector3(far, RING_DEPTH, hz * 2.0), Vector3(hx + far * 0.5, ring_y, 0.0)]]:
		root.add_child(Scenery.ground(band[0], band[1], Pal.TURF_RING))
	var bed := Scenery.ground(Vector3(w, BED_DEPTH, h),
		Vector3(0.0, BED_TOP - BED_DEPTH * 0.5, 0.0), Pal.TURF_RING)
	bed.name = "Bed"
	root.add_child(bed)

	var rng := RandomNumberGenerator.new()
	rng.seed = RING_SEED
	root.add_child(Scenery.scatter("tuft", _tuft_transforms(rng)))
	for i in TREE_COUNT:
		var out := rng.randf_range(TREE_OUT_MIN, TREE_OUT_MAX)
		var at: Vector3
		if i % 3 == 0:
			# The far side, anywhere along it.
			at = Vector3(rng.randf_range(-hx - 1.0, hx + 1.0), RING_TOP, -hz - out)
		else:
			# A long side, never past the field's near edge.
			var side := 1.0 if i % 2 == 0 else -1.0
			at = Vector3(side * (hx + out), RING_TOP, rng.randf_range(-hz - 0.5, hz - 1.0))
		var tree := Scenery.prop("camp_tree", at, rng.randf_range(0.0, TAU),
			Vector3.ONE * rng.randf_range(TREE_SCALE_MIN, TREE_SCALE_MAX))
		root.add_child(tree)
		_trees.append(tree)
	return root

## Where the ring's tufts stand: a seeded scatter in a band around the field,
## never on it, thinning out with distance.
func _tuft_transforms(rng: RandomNumberGenerator) -> Array[Transform3D]:
	var hx := w * 0.5
	var hz := h * 0.5
	var out: Array[Transform3D] = []
	var guard := 0
	while out.size() < TUFT_COUNT and guard < TUFT_COUNT * 12:
		guard += 1
		var x := rng.randf_range(-hx - TUFT_BAND, hx + TUFT_BAND)
		var z := rng.randf_range(-hz - TUFT_BAND, hz + TUFT_BAND)
		if absf(x) < hx + 0.1 and absf(z) < hz + 0.1:
			continue
		# Thicker near the field, thin further out, so the eye reads the band
		# as meadow rather than as a fringe with a hard end.
		var edge := maxf(absf(x) - hx, absf(z) - hz)
		if rng.randf() > 1.0 - edge / (TUFT_BAND * 1.4):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4))
		out.append(Transform3D(basis, Vector3(x, RING_TOP, z)))
	return out

## One cell of water channel. A bank lip shows only on a side whose
## neighbour is not water, so a stream reads as one cut with continuous banks
## and two streams that meet read as one. A side facing off the field shows
## none: the stream runs off the meadow, and the ring's own turf face is the
## bank there.
func _channel(cell: Vector2i) -> Node3D:
	var node := Models.instance("channel")
	node.name = "channel"
	for side in [["N", Vector2i(0, -1)], ["S", Vector2i(0, 1)],
			["E", Vector2i(1, 0)], ["W", Vector2i(-1, 0)]]:
		var n: Vector2i = cell + side[1]
		var show := Gen.in_bounds(n, w, h) and not _water.has(n)
		Models.set_layer_visible(node, "Channel_Bank_%s" % side[0], show)
	for mi in Models.meshes(node):
		if mi.name.begins_with("Channel_Water"):
			_water_nodes[cell] = mi
	return node

## The wheat: three tufts on every turf cell, laid out once and then scaled
## per cell as the reach moves. Built from one throwaway `stalk`, so the
## whole field is one draw call and the export and the placeholder scatter
## identically.
func _build_stalks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RING_SEED + 1
	var cells: Array = []
	for r in h:
		for c in w:
			var cell := Vector2i(c, r)
			if _water.has(cell) or _stones.has(cell):
				continue
			cells.append(cell)
	for cell in cells:
		_stalk_at[cell] = _stalk_rest.size()
		var centre := BoardMath.cell_center(cell.y, cell.x, w, h, Placeholders.TURF_H)
		for _i in STALKS_PER_CELL:
			var at := centre + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2))
			_stalk_rest.append(Transform3D(basis, at))
	_stalks = Scenery.scatter("stalk", _stalk_rest)
	_stalks.name = "Wheat"
	board.add_child(_stalks)
	# Nothing is reached until the first paint says so.
	for i in _stalk_rest.size():
		_stalks.multimesh.set_instance_transform(i, _stalk_scaled(i, 0.0))

## The i-th stalk at blend `t`: it grows out of the turf as the reach arrives
## and sinks back into it as the reach leaves.
func _stalk_scaled(i: int, t: float) -> Transform3D:
	var rest := _stalk_rest[i]
	# Uniformly, not in height alone: from the board's own steep pitch a
	# blade flattened to nothing keeps its whole footprint and the wheat
	# never leaves the cell it was cut off from.
	return Transform3D(rest.basis.scaled(Vector3.ONE * maxf(t, 0.001)), rest.origin)

## Hides the outline shell on every mesh under `root`, leaving the toon
## shading alone.
static func _hide_outline(root: Node) -> void:
	for mi in Models.meshes(root):
		var shell := mi.get_node_or_null(Toon.OUTLINE_NODE)
		if shell != null:
			(shell as MeshInstance3D).visible = false

## The scale that makes `node` span `fill` of a cell across its widest
## horizontal axis. Measured off the meshes, so a BlenderKit-cut export and
## the primitive placeholder end up the same size on the meadow.
static func _fill_scale(node: Node3D, fill: float) -> float:
	var span := 0.0
	for mi in Models.meshes(node):
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		span = maxf(span, maxf(box.size.x, box.size.z))
	return fill / span if span > 0.0 else 1.0

# --- bales ---

## Puts the bale cell `cell` should be carrying on the board, or takes the one
## there away. A bale drops from a cell above and squashes as it lands; one
## that has gone lifts, fades and is freed. No orientation: a run of bales is
## a row of the same piece.
func _set_bale(cell: Vector2i) -> void:
	if _walls.has(cell) and not _bales.has(cell):
		var pivot := Node3D.new()
		pivot.name = "bale_%d_%d" % [cell.y, cell.x]
		pivot.position = BoardMath.cell_center(cell.y, cell.x, w, h, Placeholders.TURF_H)
		board.add_child(pivot)
		pivot.add_child(Models.instance("bale"))
		_bales[cell] = pivot
		Motion.stop(_bale_tw.get(cell))
		pivot.position.y = Placeholders.TURF_H + DROP_FROM
		_bale_tw[cell] = Motion.settle(pivot, "position:y", Placeholders.TURF_H, POP_TIME)
		if _bale_tw[cell] == null:
			pivot.position.y = Placeholders.TURF_H
		else:
			Motion.squash(pivot.get_child(0), SQUASH, POP_TIME, POP_TIME * 0.8)
		fx.cue("bale")
	elif not _walls.has(cell) and _bales.has(cell):
		_drop_bale(cell)
		fx.cue("unbale")

func _drop_bale(cell: Vector2i) -> void:
	if not _bales.has(cell):
		return
	var gone: Node3D = _bales[cell]
	_bales.erase(cell)
	Motion.stop(_bale_tw.get(cell))
	_bale_tw.erase(cell)
	var tw: Tween = Motion.vanish(gone, VANISH_LIFT, VANISH_TIME)
	if tw == null:
		gone.queue_free()
	else:
		tw.finished.connect(gone.queue_free)

# --- colour ---

## Repaints everything the state has moved under: the bales by whether a hint
## dropped them, and the meadow by where the horse can now get to.
func _recolour() -> void:
	for cell in _bales:
		Models.tint_named(_bales[cell], "Straw", Pal.STRAW_LOCK if _locked.has(cell) else Pal.STRAW)
	var reach: Dictionary = _reach().cells
	var moving := false
	for cell in _reach_now:
		var target := 1.0 if reach.has(cell) else 0.0
		_reach_target[cell] = target
		if not is_equal_approx(float(_reach_now[cell]), target):
			moving = true
	if not moving:
		return
	# Every changing cell moves together from where it is painted now; a cell
	# that changes its mind mid-fade simply starts again from where it got to.
	# The first paint of a day waits for the entrance's wave to pass, so the
	# wheat rises on ground that has already arrived.
	Motion.stop(_reach_tw)
	_reach_from = _reach_now.duplicate()
	var delay := (ENTER_CAP + ENTER_POP) if _first_paint else 0.0
	_first_paint = false
	_reach_tw = Motion.fade(board, _paint_reach, 0.0, 1.0, REACH_TIME, REACH_STEPS, delay)

## Progress `t` of the current move: every cell sits at the matching point
## between where it started and where it is heading.
func _paint_reach(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	for cell in _reach_now:
		var from: float = _reach_from.get(cell, _reach_now[cell])
		var to: float = _reach_target.get(cell, from)
		var blend := lerpf(from, to, t)
		blend = roundf(blend * REACH_STEPS) / REACH_STEPS
		if is_equal_approx(blend, float(_reach_now[cell])):
			continue
		_reach_now[cell] = blend
		_paint_cell(cell, blend)

## One turf cell at a wheat blend: the turf tint between green and trampled,
## and the cell's stalks standing up out of it by the same amount.
func _paint_cell(cell: Vector2i, blend: float) -> void:
	var pad = _pad_models[cell.y][cell.x]
	if pad == null:
		return
	var base: Color = Pal.TURF_TREE if _stones.has(cell) else Pal.TURF
	var wheat: Color = Pal.TURF_REACH
	if _gap_cells.has(cell):
		# A flashing gap: rose over the wheat, by the gap tween's own blend.
		wheat = wheat.lerp(Pal.BAD, _gap_blend)
	Models.tint_named(pad, "Turf", base.lerp(wheat, blend))
	if _stalks != null and _stalk_at.has(cell):
		var first: int = _stalk_at[cell]
		for k in STALKS_PER_CELL:
			_stalks.multimesh.set_instance_transform(first + k, _stalk_scaled(first + k, blend))

var _gap_blend := 0.0

## Submitting an open pen: the edge cells the horse can still reach blush
## rose over their wheat, hold, and fade back.
func _flash_gaps(gaps: Array) -> void:
	_end_gaps()
	_gap_cells = gaps.duplicate()
	var tw := board.create_tween()
	tw.tween_method(_paint_gaps, 0.0, 1.0, GAP_IN)
	tw.tween_interval(GAP_HOLD)
	tw.tween_method(_paint_gaps, 1.0, 0.0, GAP_OUT)
	tw.finished.connect(_end_gaps)
	_gap_tw = tw

func _end_gaps() -> void:
	Motion.stop(_gap_tw)
	_gap_tw = null
	if _gap_cells.is_empty():
		return
	_gap_blend = 0.0
	var cells := _gap_cells
	_gap_cells = []
	for cell in cells:
		if _reach_now.has(cell):
			_paint_cell(cell, _reach_now[cell])

func _paint_gaps(blend: float) -> void:
	_gap_blend = roundf(blend * REACH_STEPS) / REACH_STEPS
	for cell in _gap_cells:
		if _reach_now.has(cell):
			_paint_cell(cell, _reach_now[cell])

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, w, h)
	if not Gen.in_bounds(cell, w, h):
		return
	if cell == _horse:
		_wobble_horse()
		fx.cue("horse")
		return
	if _blocked.has(cell) or _apples.has(cell):
		_dip_pad(cell)
		fx.cue("locked")
		return
	if _locked.has(cell):
		_dip_bale(cell)
		fx.cue("locked")
		return
	if _walls.has(cell):
		_history.append(Vector3i(cell.x, cell.y, 1))
		_walls.erase(cell)
	else:
		if _walls.size() >= _budget:
			# The stock is spent: take one down first.
			_dip_pad(cell)
			fx.cue("locked")
			return
		_history.append(Vector3i(cell.x, cell.y, 0))
		_walls[cell] = true
	_end_gaps()
	_set_bale(cell)
	_recolour()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, w, h, plane_height()))

# --- capabilities ---

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "status"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Takes back the last tap. Counts no move.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Vector3i = _history.pop_back()
	var cell := Vector2i(last.x, last.y)
	if last.z == 1:
		_walls[cell] = true
	else:
		_walls.erase(cell)
	_end_gaps()
	_set_bale(cell)
	_recolour()
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Drops one bale of the generator's own pen and pins it: the first of them
## not already standing. Refused when the stock is spent. Three per puzzle;
## reset unpins them but does not refund them. Counts no move; the day still
## ends only on submit.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	if _walls.size() >= _budget:
		return false
	var target := Vector2i(-1, -1)
	for c in _solution_walls:
		if not _walls.has(c):
			target = c
			break
	if target.x < 0:
		return false
	var kept: Array[Vector3i] = []
	for entry in _history:
		if entry.x != target.x or entry.y != target.y:
			kept.append(entry)
	_history = kept
	_walls[target] = true
	_locked[target] = true
	_end_gaps()
	_set_bale(target)
	fx.sparkle(BoardMath.cell_center(target.y, target.x, w, h, Placeholders.TURF_H + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_recolour()
	moved.emit()
	return true

## Submit. An open pen flashes the edge cells the horse still reaches and
## counts them; a closed pen short of the target counts as one thing wrong
## and the horse shakes its head; a closed pen worth the target ends the day.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var r := _reach()
	if r.escaped:
		_flash_gaps(r.gaps)
		_wobble_horse()
		fx.cue("check")
		return r.gaps.size()
	if Gen.score_of(r.cells, _apples) < _target:
		_wobble_horse()
		fx.cue("check")
		return 1
	_submitted = true
	fx.cue("check_ok")
	check_solved()
	return 0

# --- motion on one cell ---

func _dip_pad(cell: Vector2i) -> void:
	var pivot: Node3D = _pads[cell.y][cell.x]
	Motion.stop(_pad_tw.get(cell))
	pivot.position.y = 0.0
	_pad_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, 0.0)

func _dip_bale(cell: Vector2i) -> void:
	if not _bales.has(cell):
		return
	var pivot: Node3D = _bales[cell]
	Motion.stop(_bale_tw.get(cell))
	pivot.position.y = Placeholders.TURF_H
	_bale_tw[cell] = Motion.hop(pivot, -DIP, DIP_TIME, 0.0, Placeholders.TURF_H)

func _wobble_horse() -> void:
	Motion.stop(_horse_tw)
	_horse_pivot.rotation.z = 0.0
	_horse_tw = Motion.wobble(_horse_pivot)

# --- entrance and solve ---

## The board arrives. The meadow around it is already there -- it is the
## world, not the puzzle; the field grows out of it from the horse, a step of
## cells at a time, the streams filling behind the wave. Then the trees
## settle, the horse lands, and the apples and boulders pop.
func _enter() -> void:
	_stop_entrance()
	for r in h:
		for c in w:
			var cell := Vector2i(c, r)
			var delay := Motion.stagger(_steps_from_horse(cell), ENTER_STAGGER, ENTER_CAP)
			_pop_in(_pads[r][c], delay)
			if _water_nodes.has(cell):
				_fill_water(cell, delay + ENTER_WATER)
	for i in _trees.size():
		_pop_in(_trees[i], Motion.stagger(i, ENTER_TREE, ENTER_CAP))
	_land_horse(ENTER_CAP * 0.5)
	for store in [_apple_nodes, _stone_nodes]:
		for cell in store:
			_pop_in(store[cell], ENTER_CAP * 0.5 + ENTER_POP
				+ Motion.stagger(_steps_from_horse(cell), ENTER_STAGGER, ENTER_CAP))
	fx.cue("enter")

## How far cell `cell` is from the horse, in steps of the wave.
func _steps_from_horse(cell: Vector2i) -> int:
	return absi(cell.x - _horse.x) + absi(cell.y - _horse.y)

func _pop_in(node: Node3D, delay: float) -> void:
	var rest: Vector3 = node.scale
	node.scale = rest * 0.01
	var pop: Tween = Motion.settle(node, "scale", rest, ENTER_POP, delay)
	if pop != null:
		_entrance.append(pop)

## A stream fills: its water rises from the channel floor to its surface.
func _fill_water(cell: Vector2i, delay: float) -> void:
	var mi: MeshInstance3D = _water_nodes[cell]
	mi.scale.y = 0.01
	var rise: Tween = Motion.settle(mi, "scale:y", 1.0, ENTER_WATER * 2.0, delay)
	if rise != null:
		_entrance.append(rise)

## The horse lands from above with a squash, rather than popping out of the
## grass: it is the one thing on the field that is alive.
func _land_horse(delay: float) -> void:
	var rest: float = Placeholders.TURF_H
	_horse_pivot.position.y = rest + HORSE_DROP
	var drop: Tween = Motion.settle(_horse_pivot, "position:y", rest, HORSE_LAND, delay)
	if drop == null:
		_horse_pivot.position.y = rest
		return
	_entrance.append(drop)
	var squash: Tween = Motion.squash(_horse_model, SQUASH, SQUASH, delay + HORSE_LAND * 0.9)
	if squash != null:
		_entrance.append(squash)

func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for row in _pads:
		for pivot in row:
			(pivot as Node3D).scale = Vector3.ONE
	for cell in _water_nodes:
		(_water_nodes[cell] as MeshInstance3D).scale.y = 1.0
	for tree in _trees:
		(tree as Node3D).scale = Vector3.ONE
	if _horse_pivot != null and is_instance_valid(_horse_pivot):
		_horse_pivot.scale = Vector3.ONE
		_horse_pivot.position.y = Placeholders.TURF_H
	if _horse_model != null and is_instance_valid(_horse_model):
		_horse_model.scale = Vector3.ONE * _fill_scale(_horse_model, HORSE_FILL)
	for cell in _apple_nodes:
		(_apple_nodes[cell] as Node3D).scale = Vector3.ONE * APPLE_SCALE
	for cell in _stone_nodes:
		(_stone_nodes[cell] as Node3D).scale = Vector3.ONE * ROCK_SCALE

## The horse kicks up its heels, every bale hops once in the order it was
## dropped, and flowers open across the penned meadow from the horse outward:
## the pen is closed and the day is won.
func _on_solved() -> void:
	_end_gaps()
	Motion.stop(_horse_tw)
	_horse_tw = Motion.hop(_horse_pivot, SOLVE_HOP, SOLVE_TIME, 0.0, Placeholders.TURF_H)
	var i := 0
	for cell in _bales.keys():
		Motion.stop(_bale_tw.get(cell))
		_bale_tw[cell] = Motion.hop(_bales[cell], SOLVE_HOP * 0.5, SOLVE_TIME,
			Motion.stagger(i, SOLVE_STAGGER), Placeholders.TURF_H)
		i += 1
	_bloom()
	fx.sparkle(_horse_pivot.position + Vector3(0.0, Placeholders.HORSE_H, 0.0))
	fx.cue("solved")

## Flowers open over every cell of the closed pen, a step of cells at a time
## from the horse outward. One MultiMesh, built when the day is won and
## scaled in by the wave, so nothing is paid for it while the board is played.
func _bloom() -> void:
	Motion.stop(_bloom_tw)
	if _blooms != null and is_instance_valid(_blooms):
		_blooms.queue_free()
	_bloom_rest = []
	_bloom_dist = []
	var rng := RandomNumberGenerator.new()
	rng.seed = RING_SEED + 2
	var reach: Dictionary = _reach().cells
	for cell in reach:
		if _apples.has(cell) or _stones.has(cell):
			continue
		for _k in BLOOM_PER_CELL:
			var at := BoardMath.cell_center(cell.y, cell.x, w, h, Placeholders.TURF_H)
			at += Vector3(rng.randf_range(-0.32, 0.32), 0.0, rng.randf_range(-0.32, 0.32))
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3))
			_bloom_rest.append(Transform3D(basis, at))
			_bloom_dist.append(_steps_from_horse(cell))
	if _bloom_rest.is_empty():
		return
	_blooms = Scenery.scatter("flower", _bloom_rest)
	_blooms.name = "Bloom"
	board.add_child(_blooms)
	_bloom_front = -1.0
	_paint_bloom(0.0)
	_bloom_tw = Motion.fade(board, _paint_bloom, 0.0, 1.0, BLOOM_TIME, BLOOM_STEPS)

## The bloom's wave at `t`: every flower within `t` of the way out from the
## horse stands open, the rest are still shut.
func _paint_bloom(t: float) -> void:
	if _blooms == null or not is_instance_valid(_blooms):
		return
	var furthest := 0
	for d in _bloom_dist:
		furthest = maxi(furthest, d)
	var front := t * (furthest + 1)
	if is_equal_approx(front, _bloom_front):
		return
	_bloom_front = front
	for i in _bloom_rest.size():
		var rest := _bloom_rest[i]
		var open := 1.0 if float(_bloom_dist[i]) <= front else 0.001
		_blooms.multimesh.set_instance_transform(i, Transform3D(rest.basis.scaled(Vector3.ONE * open), rest.origin))
