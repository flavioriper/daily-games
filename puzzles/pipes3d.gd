extends "res://core/puzzle_base_3d.gd"

## Pipes on the island: stone pads carrying chrome pipe pieces, a bolted
## source valve at the far-left corner and a drain at the near-right one. Tap
## a piece to turn it; water runs from the source through every pipe it can
## reach and pours out of any mouth that meets nothing. Solved when no opening
## anywhere faces a wall or a closed side, which on the generator's spanning
## tree means the whole board ends up fed.
## Spec: docs/superpowers/specs/2026-09-14-pipes-3d-design.md.

const Gen = preload("res://puzzles/pipes_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")

const SOURCE := Vector2i(0, 0)
const HINTS := 3
## The orientation each shape is modelled in, as a mask. A cell's base yaw is
## however many quarter turns bring this onto the cell's own mask; the
## player's rot adds to that. Must match core/placeholders.gd and
## art/pipes.blend.
const REFERENCE := {
	"pipe_cap": Gen.UP,
	"pipe_straight": Gen.UP | Gen.DOWN,
	"pipe_elbow": Gen.UP | Gen.RIGHT,
	"pipe_tee": Gen.UP | Gen.RIGHT | Gen.DOWN,
	"pipe_cross": Gen.UP | Gen.RIGHT | Gen.DOWN | Gen.LEFT,
}
const BITS := [Gen.UP, Gen.RIGHT, Gen.DOWN, Gen.LEFT]

const TURN_TIME := 0.22
const SQUASH := 0.08
const SQUASH_TIME := 0.18
const DIP := 0.02
const DIP_TIME := 0.35
const FADE_TIME := 0.25
## Eight steps, so the toon cache holds at most nine colours per material name
## per direction.
const FADE_STEPS := 8
const FLOW_STEP := 0.045
const FLOW_OUT_STEP := 0.02
## The flood wave's own cap, applied on top of Motion.stagger's shared 0.6 s
## one (never raised here: it is shared with Binairo and Code Break). Staggers
## are measured from the shallowest newly-wet (or newly-dry) depth, not from
## zero, so a long run started deep in the board still races visibly instead
## of saturating the shared cap; see the spec's section 4 amendments.
const FLOW_CAP := 1.2
const WIN_FLOW := 2.4
const WIN_FLOW_TIME := 1.2
const WIN_HOP := 0.08
const WIN_HOP_TIME := 0.4
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.35
const ENTER_STAGGER := 0.02
const PIECE_DROP := 0.6
const PIECE_DELAY := 0.25
const SPARKLE_LIFT := 0.12
## At most this many mouths pour at once, which leaves Fx.JET_POOL one emitter
## for the source and one for the drain.
const MAX_LEAKS := 4
## How far past a leak's own arm end, and how much higher than the tube's
## own centre, its jet is born (task 4 fix round 3). A jet spawned at the
## tube's own surface sits inside the pipe's silhouette at the steep board
## camera and is swallowed by it whatever size it is drawn; born this far
## clear, the droplets fall through open air before they reach the stone.
const JET_OUT := 0.22
const JET_LIFT := 0.16
## How much higher than the source/drain's own ring height their jet spawns
## (task 4 fix round 3), for the same reason: VALVE_H alone sits inside the
## incoming pipe's curve into the ring.
const JET_VALVE_LIFT := 0.45

func _ready() -> void:
	super()
	solved.connect(_on_solved)

var w: int = 5
var h: int = 7
var _mask: Array = []        # [y][x] -> the cell's solved opening bits
var _rot: Array = []         # [y][x] -> quarter turns the player has added
var _rot0: Array = []        # [y][x] -> the scramble the player was given
var _base: Dictionary = {}   # Vector2i -> quarter turns of the model's base yaw
var _live: Dictionary = {}   # Vector2i -> BFS depth from SOURCE, fed cells only
var _wet: Dictionary = {}    # Vector2i -> the wetness the cell is showing
var _locked: Dictionary = {} # Vector2i -> true once a hint has fixed it
## Cells the player has turned, newest last. Undo pops it; a hint drops its
## own cell's entries, since that cell can no longer be turned.
var _history: Array[Vector2i] = []
var _pivots: Dictionary = {} # Vector2i -> Node3D at the cell centre; dips
var _spins: Dictionary = {}  # Vector2i -> Node3D under the pivot; turns
var _pads: Dictionary = {}
var _pieces: Dictionary = {}
var _flow: Dictionary = {}   # Vector2i -> that piece's pipe_flow ShaderMaterial
var _turn_tw: Dictionary = {}
var _dip_tw: Dictionary = {}
var _fade_tw: Dictionary = {}
var _leak_jets: Dictionary = {}  # Vector2i -> an Fx jet handle
var _leak_at: Dictionary = {}    # Vector2i -> the world point that handle is aimed at
var _source_jet: int = -1
var _drain_jet: int = -1
var _entrance: Array = []
var fx: Node3D               # pooled particles and jets, a child of the board

func puzzle_id() -> String: return "pipes"
func title() -> String: return "Pipes"

func rules() -> String:
	return "Tap a piece to turn it. The water starts at the blue valve -- fill every pipe and leave no loose ends."

func board_size() -> Vector2i: return Vector2i(w, h)
## A piece stands 0.35 over a 0.12 pad, so a collar tops out at 0.47 and
## nothing is higher at rest. The win's 0.08 hop is absorbed by the camera's
## margin, as Binairo's roll is; framing for the peak would shrink the board
## for good.
func board_height() -> float: return 0.5
func plane_height() -> float: return Placeholders.PAD_H
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

## Where the water arrives: the cell pipes_gen's flood already starts from.
func source() -> Vector2i: return SOURCE
## Where it is meant to leave, diagonally opposite. Decoration and a reward:
## on a spanning tree it runs as soon as it is reached, and the puzzle is won
## when nothing leaks anywhere.
func drain() -> Vector2i: return Vector2i(w - 1, h - 1)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	match difficulty:
		0: w = 4; h = 5
		1: w = 5; h = 7
		_: w = 6; h = 9
	var out: Dictionary = Gen.generate(rng, w, h)
	_mask = out.mask
	_rot = out.rot
	_rot0 = _copy_rot(_rot)
	_locked.clear()
	_history.clear()
	_build_scene()
	_recompute_live()
	_paint_all()
	_run_jets()
	_enter()
	# _ready framed the default 5 x 7; the difficulty may have changed it.
	_refit()

static func _copy_rot(src: Array) -> Array:
	var out: Array = []
	for row in src:
		out.append((row as Array).duplicate())
	return out

## Puts the board back to the scramble the player was given. The 2D version
## only zeroed the move count and left the board turned; this restores it.
func reset_board() -> void:
	_stop_entrance()
	moves = 0
	_rot = _copy_rot(_rot0)
	_history.clear()
	var unlocking: Array = _locked.keys()
	var was: Dictionary = {}
	for cell in unlocking:
		was[cell] = _pad_colour(cell)
	_locked.clear()
	for cell in unlocking:
		_fade_pad(cell, was[cell], _pad_colour(cell))
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			Motion.stop(_turn_tw.get(cell))
			_turn_tw[cell] = Motion.settle(_spins[cell], "rotation:y", _angle(cell),
				TURN_TIME, Motion.stagger(x + y, ENTER_STAGGER), true)
	_flood()
	fx.cue("reset")

func is_solved() -> bool:
	return Gen.is_solved(_mask, _rot, w, h)

func share_glyphs() -> String:
	return "🔧 %dx%d · %d turns" % [w, h, moves]

## No Check: the board is solved the instant the last piece lines up and the
## base class notices, so there is nothing to ask about.
func capabilities() -> Array[String]: return ["undo", "hint"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

func undo() -> bool:
	if not can_undo():
		return false
	var cell: Vector2i = _history.pop_back()
	_settle(cell)
	_rot[cell.y][cell.x] = (int(_rot[cell.y][cell.x]) + 3) % 4
	_turn(cell)
	_flood()
	moved.emit()
	fx.cue("undo")
	# Undo counts no move, so it asks the base class itself (puzzle_base.gd:
	# "hints and undos call it directly because they do not count as moves").
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var cell := _first_wrong()
	if cell.x < 0:
		return false
	_settle(cell)
	var was: Color = _pad_colour(cell)
	_rot[cell.y][cell.x] = 0
	_locked[cell] = true
	_turn(cell)
	_history = _history.filter(func(c: Vector2i) -> bool: return c != cell)
	_fade_pad(cell, was, _pad_colour(cell))
	fx.sparkle(_cell_at(cell, Placeholders.PAD_H + SPARKLE_LIFT))
	hints_used += 1
	_flood()
	moved.emit()
	fx.cue("hint")
	# Hints count no move, so they ask the base class themselves.
	check_solved()
	return true

## The first cell in reading order that is not already right. A cell whose
## rotated mask equals the mask it was modelled with is right whatever its rot
## says, which is what stops a hint being spent on a straight turned half way
## round or on a cross. While the board is unsolved one always exists, since
## rot 0 everywhere is a solution.
func _first_wrong() -> Vector2i:
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if _locked.has(cell):
				continue
			if Gen.rotate_mask(_mask[y][x], _rot[y][x]) != _mask[y][x]:
				return cell
	return Vector2i(-1, -1)

## Floods from the source through matching openings, recording each cell's
## breadth-first depth: the flow wave staggers by it, so the water races
## outward from the valve instead of appearing everywhere at once. The set of
## fed cells is the same one the 2D version found depth first.
func _recompute_live() -> void:
	_live.clear()
	_live[SOURCE] = 0
	var queue: Array[Vector2i] = [SOURCE]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		var d: int = int(_live[cur]) + 1
		var m: int = Gen.rotate_mask(_mask[cur.y][cur.x], _rot[cur.y][cur.x])
		for bit in BITS:
			if m & bit == 0:
				continue
			var n: Vector2i = cur + Gen.DELTA[bit]
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or _live.has(n):
				continue
			var nm: int = Gen.rotate_mask(_mask[n.y][n.x], _rot[n.y][n.x])
			if nm & Gen.OPPOSITE[bit] != 0:
				_live[n] = d
				queue.append(n)

## True when the opening `bit` of `cell` meets a matching opening next door.
func _meets(cell: Vector2i, bit: int) -> bool:
	var n: Vector2i = cell + Gen.DELTA[bit]
	if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
		return false
	return Gen.rotate_mask(_mask[n.y][n.x], _rot[n.y][n.x]) & Gen.OPPOSITE[bit] != 0

## Fed cells with an opening that meets nothing, as
## {"cell": Vector2i, "at": Vector3} at that mouth, nearest the source first
## and at most MAX_LEAKS of them. Water pouring onto the stone is the feedback
## that shows where the network is still broken.
func _leaks() -> Array:
	var cells: Array = _live.keys()
	cells.sort_custom(_nearer_source)
	var out: Array = []
	for cell in cells:
		var m: int = Gen.rotate_mask(_mask[cell.y][cell.x], _rot[cell.y][cell.x])
		for bit in BITS:
			if m & bit == 0 or _meets(cell, bit):
				continue
			var d: Vector2i = Gen.DELTA[bit]
			out.append({"cell": cell,
				"at": _cell_at(cell, Placeholders.PAD_H + Placeholders.TUBE_Y + JET_LIFT)
					+ Vector3(d.x, 0.0, d.y) * (Placeholders.ARM_LEN + JET_OUT)})
			break
		if out.size() >= MAX_LEAKS:
			break
	return out

func _nearer_source(a: Vector2i, b: Vector2i) -> bool:
	if int(_live[a]) != int(_live[b]):
		return int(_live[a]) < int(_live[b])
	return a.y * w + a.x < b.y * w + b.x

func _stop_all() -> void:
	_stop_entrance()
	for d in [_turn_tw, _dip_tw, _fade_tw]:
		for key in d:
			Motion.stop(d[key])
		d.clear()
	if fx != null and is_instance_valid(fx):
		for cell in _leak_jets:
			fx.stop_jet(_leak_jets[cell])
		fx.stop_jet(_source_jet)
		fx.stop_jet(_drain_jet)
	_leak_jets.clear()
	_leak_at.clear()
	_source_jet = -1
	_drain_jet = -1

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	_pivots.clear()
	_spins.clear()
	_pads.clear()
	_pieces.clear()
	_flow.clear()
	_base.clear()
	_wet.clear()

	board.add_child(Platform.build(w, h))
	fx = Fx.new()
	board.add_child(fx)

	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var m: int = int(_mask[y][x])
			var slot := _slot_for(m)
			# The pivot dips under a tap and carries the whole cell; the spin
			# under it turns, so only the pipe rotates and the pad and the
			# valve stay put however they are later modelled.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [x, y]
			pivot.position = _cell_at(cell, 0.0)
			board.add_child(pivot)
			_pivots[cell] = pivot

			var pad := Models.instance("pipe_pad")
			pivot.add_child(pad)
			_pads[cell] = pad

			var spin := Node3D.new()
			spin.name = "spin"
			spin.position.y = Placeholders.PAD_H
			pivot.add_child(spin)
			_spins[cell] = spin

			var piece := Models.instance(slot)
			spin.add_child(piece)
			_pieces[cell] = piece
			_flow[cell] = Models.material_named(piece, "Flow_flat")
			_base[cell] = _base_turns(slot, m)
			spin.rotation.y = _angle(cell)
			_wet[cell] = 0.0

	for cell in [source(), drain()]:
		var valve := Models.instance("valve")
		valve.position.y = Placeholders.PAD_H
		_pivots[cell].add_child(valve)

## The shape a mask needs: the number of openings, with two split by whether
## they face each other. A maskless cell cannot occur on a spanning tree of
## four cells or more, but a cap is the safe answer if one ever does.
static func _slot_for(m: int) -> String:
	var bits := 0
	for bit in BITS:
		if m & bit != 0:
			bits += 1
	match bits:
		0, 1: return "pipe_cap"
		3: return "pipe_tee"
		4: return "pipe_cross"
	if m == Gen.UP | Gen.DOWN or m == Gen.LEFT | Gen.RIGHT:
		return "pipe_straight"
	return "pipe_elbow"

## Quarter turns that bring the shape's modelled orientation onto `m`.
static func _base_turns(slot: String, m: int) -> int:
	var r: int = int(REFERENCE[slot])
	for k in 4:
		if Gen.rotate_mask(r, k) == m:
			return k
	return 0

## Where a cell's piece points: its base yaw plus the player's turns, negated
## because a clockwise turn on screen is a negative rotation about +Y.
func _angle(cell: Vector2i) -> float:
	return -float(int(_base[cell]) + int(_rot[cell.y][cell.x])) * PI * 0.5

## World point over `cell` at height y. Rows run along +Z, so the generator's
## y is the row and its x the column.
func _cell_at(cell: Vector2i, y: float) -> Vector3:
	return BoardMath.cell_center(cell.y, cell.x, w, h, y)

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D board's origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, w, h, plane_height()))

## A pad's resting colour: the source and the drain are water-blue whatever
## else is true of them, a hinted cell is a given, everything else plain stone.
func _pad_colour(cell: Vector2i) -> Color:
	if cell == source() or cell == drain():
		return Pal.WATER
	return Pal.STONE_GIVEN if _locked.has(cell) else Pal.STONE

## Paints every cell to the flood as it stands, with no motion: a fresh build
## starts from a settled board.
func _paint_all() -> void:
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			_set_wet_now(cell, 1.0 if _live.has(cell) else 0.0)
			Models.tint_named(_pads[cell], "Stone", _pad_colour(cell))

## Recomputes the flood and moves the board to match: the cells that just
## filled light up in a wave outward from the source, the ones that just
## emptied fade back, and the jets follow.
func _flood() -> void:
	var before: Dictionary = _live.duplicate()
	_recompute_live()
	var drain_was: bool = before.has(drain())
	# Staggered from the shallowest newly-wet (or newly-dry) depth, not from
	# absolute zero, so a run that starts deep in the board still visibly
	# races from where the water actually enters instead of the whole tail
	# saturating Motion.stagger's shared 0.6 s cap at once. FLOW_CAP is this
	# board's own, longer cap, applied on top.
	var wet_base: int = -1
	var dry_base: int = -1
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if _live.has(cell) and not before.has(cell):
				var d: int = int(_live[cell])
				if wet_base < 0 or d < wet_base:
					wet_base = d
			elif before.has(cell) and not _live.has(cell):
				var d2: int = int(before[cell])
				if dry_base < 0 or d2 < dry_base:
					dry_base = d2
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var now: bool = _live.has(cell)
			if now == before.has(cell):
				continue
			if now:
				_set_wet(cell, 1.0, minf((int(_live[cell]) - wet_base) * FLOW_STEP, FLOW_CAP))
			else:
				_set_wet(cell, 0.0, minf((int(before[cell]) - dry_base) * FLOW_OUT_STEP, FLOW_CAP))
	_run_jets()
	if _live.has(drain()) and not drain_was:
		fx.sparkle(_cell_at(drain(), Placeholders.PAD_H + SPARKLE_LIFT), Pal.WATER_HI)
		var ring: Node3D = _pivots[drain()].get_node_or_null("valve")
		if ring != null:
			Motion.squash(ring, SQUASH, SQUASH_TIME)
		fx.cue("drain")
	else:
		fx.cue("flow")

## Applies wetness `t` to cell's pipe at once: the shell and the collar tints
## and the flow material's `wet` uniform. The one place that touches those
## three surfaces, shared by the tweened fade and the instant set below.
func _apply_wet(cell: Vector2i, t: float) -> void:
	_wet[cell] = t
	var piece: Node3D = _pieces[cell]
	Models.tint_named(piece, "Steel", Pal.STEEL.lerp(Pal.PIPE_WET, t))
	Models.tint_named(piece, "Collar", Pal.STEEL_HI.lerp(Pal.PIPE_WET_HI, t))
	var mat: ShaderMaterial = _flow[cell]
	if mat != null:
		mat.set_shader_parameter("wet", t)

## Fades one cell between dry and fed: the shell and the collar tints on an
## 8-step grid, and the flow material's `wet` uniform, all on one tween.
func _set_wet(cell: Vector2i, target: float, delay := 0.0) -> void:
	var from: float = float(_wet.get(cell, 0.0))
	Motion.stop(_fade_tw.get(cell))
	var setter := func(t: float) -> void: _apply_wet(cell, t)
	_fade_tw[cell] = Motion.fade(_pieces[cell], setter, from, target, FADE_TIME, FADE_STEPS, delay)

## The same state change with no motion, for the build and for _settle.
func _set_wet_now(cell: Vector2i, target: float) -> void:
	Motion.stop(_fade_tw.get(cell))
	_fade_tw.erase(cell)
	_apply_wet(cell, target)

## Fades a pad from one stone colour to another on the same 8-step grid as the
## pipes. Both ends are passed in because `_locked` has usually already moved
## by the time this is called.
func _fade_pad(cell: Vector2i, from: Color, to: Color) -> void:
	if from == to:
		return
	var pad: Node3D = _pads[cell]
	var setter := func(t: float) -> void:
		Models.tint_named(pad, "Stone", from.lerp(to, t))
	Motion.fade(pad, setter, 0.0, 1.0, FADE_TIME, FADE_STEPS)

## Points every jet at where water is actually leaving a pipe: one at the
## source valve for the whole puzzle, and one at each fed mouth that meets
## nothing. A cell whose open mouth has moved (a neighbour's turn met or
## unmet it) is stopped and restarted at the new point, since Fx.jet only
## sets its position once and then just runs; leaving it in place would pour
## water from a mouth that no longer leaks, or one that no longer exists.
func _run_jets() -> void:
	if fx == null:
		return
	if _source_jet < 0:
		_source_jet = fx.jet(_cell_at(source(), Placeholders.PAD_H + Placeholders.VALVE_H + JET_VALVE_LIFT),
			Pal.WATER_HI)
	if _live.has(drain()):
		if _drain_jet < 0:
			_drain_jet = fx.jet(_cell_at(drain(), Placeholders.PAD_H + Placeholders.VALVE_H + JET_VALVE_LIFT),
				Pal.WATER_HI)
	elif _drain_jet >= 0:
		fx.stop_jet(_drain_jet)
		_drain_jet = -1
	var want: Dictionary = {}
	for leak in _leaks():
		want[leak["cell"]] = leak["at"]
	for cell in _leak_jets.keys():
		if not want.has(cell) or want[cell] != _leak_at[cell]:
			fx.stop_jet(_leak_jets[cell])
			_leak_jets.erase(cell)
			_leak_at.erase(cell)
	var leaked := false
	for cell in want:
		if _leak_jets.has(cell):
			continue
		leaked = true
		var handle: int = fx.jet(want[cell], Pal.WATER_HI)
		if handle < 0:
			continue
		_leak_jets[cell] = handle
		_leak_at[cell] = want[cell]
		fx.puff(want[cell], Pal.WATER_HI)
	if leaked:
		fx.cue("leak")

## Turns a cell's piece to where its rotation now says, with a squash on the
## piece and a puff of steel dust. Essential: the turn is the state change, so
## it survives reduce-motion, shortened and linear.
func _turn(cell: Vector2i) -> void:
	Motion.stop(_turn_tw.get(cell))
	_turn_tw[cell] = Motion.settle(_spins[cell], "rotation:y", _angle(cell),
		TURN_TIME, 0.0, true)
	Motion.squash(_pieces[cell], SQUASH, SQUASH_TIME)
	fx.puff(_cell_at(cell, Placeholders.PAD_H + Placeholders.TUBE_Y), Pal.STEEL)
	fx.cue("turn")

## A locked cell answers a tap by pressing down and coming back.
func _dip(cell: Vector2i) -> void:
	Motion.stop(_dip_tw.get(cell))
	_dip_tw[cell] = Motion.hop(_pivots[cell], -DIP, DIP_TIME, 0.0, 0.0)
	fx.cue("focus")

## Ends every tween on a cell where it was going, so a tap mid-motion starts
## from a settled piece. Called before `_rot` changes, so `_angle` still reads
## the rotation the piece was heading for.
func _settle(cell: Vector2i) -> void:
	Motion.stop(_turn_tw.get(cell))
	_turn_tw.erase(cell)
	Motion.stop(_dip_tw.get(cell))
	_dip_tw.erase(cell)
	_spins[cell].rotation.y = _angle(cell)
	_pivots[cell].position.y = 0.0
	_pieces[cell].scale = Vector3.ONE
	_set_wet_now(cell, 1.0 if _live.has(cell) else 0.0)

func on_board_press(hit: Vector3) -> void:
	# world_to_cell returns (col, row), which is exactly the generator's (x, y).
	var cell := BoardMath.world_to_cell(hit, w, h)
	if cell.x < 0:
		return
	if _locked.has(cell):
		_dip(cell)
		return
	_stop_entrance()
	_settle(cell)
	_rot[cell.y][cell.x] = (int(_rot[cell.y][cell.x]) + 1) % 4
	_history.append(cell)
	_turn(cell)
	_flood()
	note_move()

## The board arrives: the platform rises out of the water, the pads pop in on
## a diagonal wave and the pipes drop onto them a beat later.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var wave := Motion.stagger(x + y, ENTER_STAGGER)
			var pad: Node3D = _pads[cell]
			pad.scale = Vector3.ONE * 0.01
			var pop: Tween = Motion.settle(pad, "scale", Vector3.ONE, ENTER_POP,
				ENTER_PLATFORM + wave)
			if pop != null:
				_entrance.append(pop)
			var drop: Tween = Motion.slide(_spins[cell], "position:y",
				Placeholders.PAD_H + PIECE_DROP, Placeholders.PAD_H, ENTER_POP,
				ENTER_PLATFORM + PIECE_DELAY + wave)
			if drop != null:
				_entrance.append(drop)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for cell in _pads:
		_pads[cell].scale = Vector3.ONE
		_spins[cell].position.y = Placeholders.PAD_H
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0

func _splash() -> void:
	var stage := get_tree().get_first_node_in_group("stage")
	if stage != null:
		stage.splash(board.global_position)

## Every cell's flow speed at once; the win races the water for a moment.
func _set_flow_speed(s: float) -> void:
	for cell in _flow:
		var mat: ShaderMaterial = _flow[cell]
		if mat != null:
			mat.set_shader_parameter("flow_speed", s)

func _on_solved() -> void:
	for cell in _pivots:
		Motion.hop(_pivots[cell], WIN_HOP, WIN_HOP_TIME,
			Motion.stagger(int(_live.get(cell, 0)), 0.05), 0.0)
	if not Motion.reduce:
		var boost := board.create_tween()
		boost.tween_method(_set_flow_speed, 1.0, WIN_FLOW, WIN_FLOW_TIME * 0.3)
		boost.tween_method(_set_flow_speed, WIN_FLOW, 1.0, WIN_FLOW_TIME * 0.7)
	_splash()
	fx.cue("solved")

func _exit_tree() -> void:
	_stop_all()
	super()
