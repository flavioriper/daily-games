extends "res://core/puzzle_base_3d.gd"

## Binairo on the island stage. Every cell is a trilon: a three-sided stone
## prism lying along X on a pivot through its axis, with one face per state.
## The empty face (a small diamond) is up at rest, the sun face waits on the
## near slope and the moon face on the far slope, both hidden inside the
## platform. A tap rolls the prism a third of a turn toward the player so the
## next face comes up: empty -> sun -> moon -> empty. The grid changes at
## once; the roll is only how the change is shown, with a settle, a lift and a
## puff of dust on landing, and the neighbours bob as if the stone were soft.
## The pivot's angle is the only visual state; the emblems on the two buried
## faces are merely made invisible between rolls so they cost no draw calls.
## Tiles in a line that already breaks a rule blush, so the player learns the
## rules by touching. Motion: docs/superpowers/specs/2026-09-13-binairo-polish-design.md.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")

## Roll and bob timings (polish spec, section 2).
const ROLL_TIME := 0.34        # one third of a turn, settle included
const ROLL_TIME_TWO := 0.42    # two thirds in one roll (reset)
const ROLL_LIFT := 0.04
const BOB_DIP := 0.02
const BOB_TIME := 0.35
const BOB_LAG := 0.04
const BOB_LAG_DIAG := 0.07
const THIRD := TAU / 3.0
## Blush toward BAD on a broken line: 6/16, so it and every quantised level
## of the fade land on the 16-step grid _paint uses (polish spec, section 2).
const BAD_BLEND := 0.375
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const BLUSH_BEATS := 0.8
const BLUSH_BEAT_EXTRA := 0.125
## Focus ring on the last tapped cell.
const FOCUS_HOLD := 2.5
const FOCUS_FADE := 0.5
const FOCUS_MOVE := 0.15
const FOCUS_POP := 0.15
const FOCUS_PULSE := 1.2
const FOCUS_ALPHA := 0.9
const FOCUS_ALPHA_LOW := 0.6
const FOCUS_LIFT := 0.005
## Entrance, reset wave and solved wave (polish spec, section 2).
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.03
const RESET_STAGGER := 0.02
const RESET_HOP := 0.03
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04
## Face index per cell value: empty up, then sun, then moon.
const FACE := {-1: 0, 0: 1, 1: 2}

func _ready() -> void:
	super()
	solved.connect(_on_solved)

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad: Dictionary = {"rows": {}, "cols": {}}

var _prism_h: float = Placeholders.TILE_H
var _cells: Array = []    # [r][c] -> Node3D pivot on the prism axis
var _tiles: Array = []    # [r][c] -> Node3D
var _suns: Array = []     # [r][c] -> Node3D
var _moons: Array = []    # [r][c] -> Node3D
var _marks: Array = []    # [r][c] -> Node3D
var _turns: Array = []    # [r][c] -> thirds of a turn rolled so far
var _rest_y: float = 0.0  # pivot height at rest: the prism's axis
var _rolls: Array = []    # [r][c] -> Tween or null, the roll in flight
var _hops: Array = []     # [r][c] -> the lift riding along the roll
var _bobs: Array = []     # [r][c] -> a neighbour bob or a given's dip
var fx: Node3D            # pooled one-shot particles, a child of the board
var _fades: Array = []         # [r][c] -> a blush fade in flight
var _blend: Array = []         # [r][c] -> painted blend toward BAD, on the grid
var _blend_target: Array = []  # [r][c] -> the blend the cell is heading for
var _ring: Node3D
var _ring_mat: StandardMaterial3D
var _ring_tw: Tween       # pop, slide or fade
var _ring_pulse: Tween    # the scale breath while shown
var _ring_pulse_a: Tween  # the alpha breath while shown, on the material
var _ring_hold: Tween     # the pause before the fade
## The last tapped cell as (col, row); (-1, -1) before the first tap. The
## working-line card in the HUD reads this.
var focus_cell := Vector2i(-1, -1)
var _entrance: Array = []  # tweens of the board entrance, killed by reset

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line, an equal count of each per line, and no two lines identical."

func board_size() -> Vector2i: return Vector2i(n, n)
## A rolling prism's edge rises one circumradius (two apothems) above the axis.
func board_height() -> float: return Placeholders.TILE_RISE + Placeholders.TILE_APOTHEM + Placeholders.EMBLEM_H + 0.05
func plane_height() -> float: return Placeholders.TILE_RISE
func board_margin() -> float: return Platform.LIP
func board_depth() -> float: return Placeholders.PLATFORM_H

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var min_clues := 0
	match difficulty:
		0: n = 6; min_clues = 16
		1: n = 6; min_clues = 0
		_: n = 8; min_clues = 0
	var out: Dictionary = Gen.generate(rng, n, min_clues)
	_solution = out.solution
	_grid = []
	_given = []
	for r in n:
		var row: Array = []
		var given_row: Array = []
		for c in n:
			var v = out.puzzle[r][c]
			row.append(v)
			given_row.append(v != -1)
		_grid.append(row)
		_given.append(given_row)
	_build_scene()
	_recolour()
	_refit()
	_enter()

## Reset as a wave: every filled free cell rolls forward to empty (a sun takes
## two thirds, a moon one) with a stagger from the near-left corner, and the
## givens hop a little to say they stay. The grid, the count and the blush
## change at once; only the prisms take their time.
func reset_board() -> void:
	_stop_entrance()
	_focus_clear()
	for r in n:
		for c in n:
			_settle(r, c)
			var delay := Motion.stagger((n - 1 - r) + c, RESET_STAGGER)
			if _given[r][c]:
				_bobs[r][c] = Motion.hop(_cells[r][c], RESET_HOP, BOB_TIME, delay, _rest_y)
				continue
			var v: int = _grid[r][c]
			if v == -1:
				continue
			_grid[r][c] = -1
			var thirds := 2 if v == 0 else 1
			_turns[r][c] += thirds
			_roll(r, c, thirds, delay)
	moves = 0
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	return Gen.is_valid_complete(_grid)

func share_glyphs() -> String:
	var out := ""
	for r in n:
		for c in n:
			out += "🌞" if _grid[r][c] == 0 else "🌙"
		out += "\n"
	return out

# --- scene ---

## Kills every tween the previous board still tracks, so a rebuild never
## inherits a roll, hop, bob or blush aimed at nodes that are about to go.
func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for rows in [_rolls, _hops, _bobs, _fades]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)
	Motion.stop(_ring_tw)
	Motion.stop(_ring_pulse)
	Motion.stop(_ring_pulse_a)
	Motion.stop(_ring_hold)

func _build_scene() -> void:
	_stop_all()
	for child in board.get_children():
		board.remove_child(child)
		child.free()
	_cells = []
	_tiles = []
	_suns = []
	_moons = []
	_marks = []
	_turns = []
	_rolls = []
	_hops = []
	_bobs = []
	_fades = []
	_blend = []
	_blend_target = []

	board.add_child(Platform.build(n, n))
	fx = Fx.new()
	board.add_child(fx)
	_rest_y = Placeholders.TILE_RISE - Placeholders.TILE_APOTHEM
	_ring = Models.instance("focus_ring")
	_ring.name = "FocusRing"
	_ring.visible = false
	_ring_mat = Models.meshes(_ring)[0].material_override
	board.add_child(_ring)
	focus_cell = Vector2i(-1, -1)

	for r in n:
		var cell_row := []
		var tile_row := []
		var sun_row := []
		var moon_row := []
		var mark_row := []
		var turn_row := []
		var roll_row := []
		var hop_row := []
		var bob_row := []
		var fade_row := []
		var blend_row := []
		var target_row := []
		for c in n:
			var tile := Models.instance("tile")
			if r == 0 and c == 0:
				_prism_h = Models.height(tile)
			var apothem := Placeholders.TILE_APOTHEM
			# The pivot is the prism's axis, one apothem under the flat face.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE - apothem)
			board.add_child(pivot)
			cell_row.append(pivot)
			# The model's origin is its lowest edge; its flat face is the
			# measured height above that, and the axis one apothem below the face.
			tile.position = Vector3(0.0, -(_prism_h - apothem), 0.0)
			pivot.add_child(tile)
			tile_row.append(tile)
			var mark := Models.instance("empty_mark")
			var sun := Models.instance("emblem_sun")
			var moon := Models.instance("emblem_moon")
			for pair in [[mark, 0], [sun, 1], [moon, 2]]:
				var emblem: Node3D = pair[0]
				var face: int = pair[1]
				emblem.position = Basis(Vector3.RIGHT, face * THIRD) * Vector3(0.0, apothem, 0.0)
				emblem.rotation.x = face * THIRD
				pivot.add_child(emblem)
			mark_row.append(mark)
			sun_row.append(sun)
			moon_row.append(moon)
			turn_row.append(FACE[_grid[r][c]])
			roll_row.append(null)
			hop_row.append(null)
			bob_row.append(null)
			fade_row.append(null)
			blend_row.append(0.0)
			target_row.append(0.0)
			pivot.rotation.x = -turn_row[c] * THIRD
		_cells.append(cell_row)
		_tiles.append(tile_row)
		_suns.append(sun_row)
		_moons.append(moon_row)
		_marks.append(mark_row)
		_turns.append(turn_row)
		_rolls.append(roll_row)
		_hops.append(hop_row)
		_bobs.append(bob_row)
		_fades.append(fade_row)
		_blend.append(blend_row)
		_blend_target.append(target_row)
	for r in n:
		for c in n:
			_show_faces(r, c, false)
			_paint(0.0, r, c)

## Pivot angle that puts the cell's current face up. Rolling always goes the
## same way (toward the player), so the angle keeps counting down rather than
## unwinding when a cell comes back round to empty.
func _target_angle(r: int, c: int) -> float:
	return -_turns[r][c] * THIRD

## Emblem visibility. At rest only the face-up emblem shows; the other two
## are inside the platform and would only cost draw calls (three emblems and
## their outlines per cell add up on an 8 x 8 board). While a roll is in
## motion every emblem shows, since two faces are above the platform at once.
func _show_faces(r: int, c: int, rolling: bool) -> void:
	var up: int = _turns[r][c] % 3
	_marks[r][c].visible = rolling or up == 0
	_suns[r][c].visible = rolling or up == 1
	_moons[r][c].visible = rolling or up == 2

## Ends every motion on cell (r, c) at once: the prism snaps to the face it
## was turning to and back onto its axis, buried faces hidden.
func _settle(r: int, c: int) -> void:
	Motion.stop(_rolls[r][c])
	Motion.stop(_hops[r][c])
	Motion.stop(_bobs[r][c])
	_rolls[r][c] = null
	_hops[r][c] = null
	_bobs[r][c] = null
	var pivot: Node3D = _cells[r][c]
	pivot.rotation.x = _target_angle(r, c)
	pivot.position.y = _rest_y
	_show_faces(r, c, false)

## Rolls cell (r, c) `thirds` faces toward the player after `delay`, with the
## settle and the lift that make it a hop rather than a grind. All three
## emblems show while it turns; _on_roll_landed hides the buried two again.
func _roll(r: int, c: int, thirds := 1, delay := 0.0) -> void:
	var pivot: Node3D = _cells[r][c]
	_show_faces(r, c, true)
	var time := ROLL_TIME if thirds == 1 else ROLL_TIME_TWO
	var tw: Tween = Motion.settle(pivot, "rotation:x", _target_angle(r, c), time, delay, true)
	tw.finished.connect(_on_roll_landed.bind(r, c))
	_rolls[r][c] = tw
	Motion.stop(_hops[r][c])
	_hops[r][c] = Motion.hop(pivot, ROLL_LIFT, time, delay, _rest_y)
	fx.cue("roll")

## The roll has landed: buried faces go invisible and dust rises from the
## near edge, where the arriving face touched down.
func _on_roll_landed(r: int, c: int) -> void:
	_show_faces(r, c, false)
	var pivot: Node3D = _cells[r][c]
	fx.puff(Vector3(pivot.position.x, Placeholders.TILE_RISE, pivot.position.z + Placeholders.TILE_SIDE * 0.5))
	fx.cue("land")

## The eight cells around a tapped one dip and return: the sides a beat after
## the tap, the diagonals half as deep and a beat later, like a soft surface.
## A rolling cell is left alone, so no cell ever runs two height tweens.
func _bob_neighbours(r: int, c: int) -> void:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var rr: int = r + dr
			var cc: int = c + dc
			if rr < 0 or cc < 0 or rr >= n or cc >= n:
				continue
			if Motion.running(_rolls[rr][cc]):
				continue
			var diagonal: bool = dr != 0 and dc != 0
			_dip(rr, cc, BOB_DIP * (0.5 if diagonal else 1.0), BOB_LAG_DIAG if diagonal else BOB_LAG)

## A dip and return on one cell, replacing any bob already on it.
func _dip(r: int, c: int, depth: float, delay := 0.0) -> void:
	Motion.stop(_bobs[r][c])
	_cells[r][c].position.y = _rest_y
	_bobs[r][c] = Motion.hop(_cells[r][c], -depth, BOB_TIME, delay, _rest_y)

# --- focus ring ---

## Moves the focus to cell (r, c): the ring pops in on a first tap, slides
## from the previous cell otherwise, pulses while shown, and fades after
## FOCUS_HOLD without a tap. It lives on the board, never on a pivot.
func _focus(r: int, c: int) -> void:
	var at := BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE + FOCUS_LIFT)
	var shown := _ring.visible and focus_cell.x >= 0
	focus_cell = Vector2i(c, r)
	Motion.stop(_ring_tw)
	Motion.stop(_ring_hold)
	if Motion.reduce:
		_stop_pulse()
		_ring.position = at
		_ring.scale = Vector3.ONE
		_ring_mat.albedo_color.a = FOCUS_ALPHA
		_ring.visible = true
	elif shown:
		_ring_tw = Motion.slide(_ring, "position", _ring.position, at, FOCUS_MOVE, 0.0, false)
		if not Motion.running(_ring_pulse):
			# A tap during the fade: bring the ring back up and pulse again.
			_ring_tw.parallel().tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, FOCUS_MOVE)
			_ring_tw.finished.connect(_start_pulse)
	else:
		_stop_pulse()
		_ring.position = at
		_ring.scale = Vector3(0.8, 1.0, 0.8)
		_ring_mat.albedo_color.a = 0.0
		_ring.visible = true
		_ring_tw = _ring.create_tween().set_parallel(true)
		_ring_tw.tween_property(_ring, "scale", Vector3.ONE, FOCUS_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ring_tw.tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, FOCUS_POP)
		_ring_tw.finished.connect(_start_pulse)
	_ring_hold = _ring.create_tween()
	_ring_hold.tween_interval(FOCUS_HOLD)
	_ring_hold.tween_callback(_focus_fade)
	fx.cue("focus")

## The breathing loop: a little larger and dimmer, then back, while shown.
func _start_pulse() -> void:
	_stop_pulse()
	if Motion.reduce or not _ring.visible:
		return
	_ring_pulse = Motion.pulse(_ring, "scale", Vector3.ONE, Vector3(1.04, 1.0, 1.04), FOCUS_PULSE)
	_ring_pulse_a = Motion.pulse(_ring, "albedo_color:a", FOCUS_ALPHA, FOCUS_ALPHA_LOW, FOCUS_PULSE, _ring_mat)

func _stop_pulse() -> void:
	Motion.stop(_ring_pulse)
	Motion.stop(_ring_pulse_a)
	_ring_pulse = null
	_ring_pulse_a = null

## Fades the ring out and hides it.
func _focus_fade() -> void:
	_stop_pulse()
	Motion.stop(_ring_tw)
	if Motion.reduce or not _ring.visible:
		_ring.visible = false
		_ring_mat.albedo_color.a = 0.0
		return
	_ring_tw = _ring.create_tween()
	_ring_tw.tween_property(_ring_mat, "albedo_color:a", 0.0, FOCUS_FADE)
	_ring_tw.tween_callback(func() -> void: _ring.visible = false)

## Drops the focus: reset, a new puzzle, a solve.
func _focus_clear() -> void:
	Motion.stop(_ring_hold)
	focus_cell = Vector2i(-1, -1)
	_focus_fade()

# --- entrance and solve ---

## The board arrives: the platform rises from below and rings the water, then
## the prisms pop in along a diagonal wave from the far-left corner. Taps are
## accepted throughout; scale, rotation and height are separate properties.
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
	for r in n:
		for c in n:
			var pivot: Node3D = _cells[r][c]
			pivot.scale = Vector3.ONE * 0.01
			var pop: Tween = Motion.settle(pivot, "scale", Vector3.ONE, ENTER_POP, ENTER_PLATFORM + Motion.stagger(r + c, ENTER_STAGGER))
			if pop != null:
				_entrance.append(pop)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _cells.is_empty():
		return
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for r in n:
		for c in n:
			_cells[r][c].scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every prism hops once, row by row from the far edge, once the last roll
## has landed. The celebration in sub-project 3 builds on this.
func _on_solved() -> void:
	_focus_clear()
	for r in n:
		for c in n:
			Motion.stop(_bobs[r][c])
			_bobs[r][c] = Motion.hop(_cells[r][c], SOLVE_HOP, SOLVE_TIME, ROLL_TIME + Motion.stagger(r, SOLVE_STAGGER), _rest_y)
	fx.cue("solved")

## Rule feedback. Cells whose line just broke fade toward the rose blend and
## give two heartbeats; cells whose line was fixed fade back. A cell already
## heading for the right blend is left alone, beats and all.
func _recolour() -> void:
	_bad = Gen.bad_lines(_grid)
	for r in n:
		for c in n:
			var target := BAD_BLEND if (_bad.rows.has(r) or _bad.cols.has(c)) else 0.0
			if is_equal_approx(_blend_target[r][c], target):
				continue
			_blend_target[r][c] = target
			Motion.stop(_fades[r][c])
			_fades[r][c] = _fade_blend(r, c, _blend[r][c], target)

## The fade from one blend to another. Blushing in gets two heartbeats past
## the target; fading out is plain. Under reduce-motion _paint lands at once.
func _fade_blend(r: int, c: int, from: float, to: float) -> Tween:
	var setter := _paint.bind(r, c)
	if to > from:
		var tw: Tween = Motion.fade(_tiles[r][c], setter, from, to, BLUSH_IN, BLUSH_STEPS)
		if tw == null:
			return null
		var beat := BLUSH_BEATS * 0.25
		for i in 2:
			tw.tween_method(setter, to, to + BLUSH_BEAT_EXTRA, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_method(setter, to + BLUSH_BEAT_EXTRA, to, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fx.cue("blush_in")
		return tw
	fx.cue("blush_out")
	return Motion.fade(_tiles[r][c], setter, from, to, BLUSH_OUT, BLUSH_STEPS)

## Face colours at a blend toward BAD: stone for the empty and sun faces and
## the caps, slate for the moon face, darker when the cell is a given. The
## blend snaps to the 16-step grid, so a fade never asks the toon cache for
## more than 17 colours per base.
func _paint(blend: float, r: int, c: int) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_blend[r][c] = blend
	var locked: bool = _given[r][c]
	var stone: Color = (Pal.STONE_GIVEN if locked else Pal.STONE).lerp(Pal.BAD, blend)
	var slate: Color = (Pal.SLATE_GIVEN if locked else Pal.SLATE).lerp(Pal.BAD, blend)
	var tile: Node3D = _tiles[r][c]
	Models.tint_named(tile, "Face_Empty", stone)
	Models.tint_named(tile, "Face_Sun", stone)
	Models.tint_named(tile, "Face_Moon", slate)
	Models.tint_named(tile, "Cap", stone)

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, n, n)
	if cell.x < 0:
		return
	var c := cell.x
	var r := cell.y
	if _given[r][c]:
		_focus(r, c)
		# Stone stays stone: the cell answers with a dip and nothing rolls.
		_dip(r, c, BOB_DIP)
		return
	# A tap mid-roll snaps that roll home first, so the next one starts from
	# a face, never from between two.
	_settle(r, c)
	# empty -> sun -> moon -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_turns[r][c] += 1
	_roll(r, c)
	_focus(r, c)
	_bob_neighbours(r, c)
	_recolour()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, plane_height()))
