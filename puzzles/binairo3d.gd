extends "res://core/puzzle_base_3d.gd"

## Binairo on the island stage. Every cell is a stone cube standing on the
## platform on a pivot through its centre, carrying one state per face: the
## empty mark on the top and bottom faces, the sun on the near and far ones,
## the moon on the left and right. A tap rolls the cube a quarter turn so the
## next state comes up: empty -> sun -> moon -> empty. Three states on six
## faces is what the two-faces-per-state layout buys: the roll axis has to
## alternate (a cube has only four faces around one axis, and the cycle is
## three long), and with each state on an opposite pair the next one is always
## a single quarter turn away. Six taps walk all six faces and land back on
## the orientation they started from. The grid changes at once; the roll is
## only how the change is shown, with a settle, the pivot-on-the-edge lift and
## a puff of dust on landing, and the neighbours bob as if the stone were
## soft. The cube's orientation is the only visual state: the sun and the moon
## are modelled into art/tile.blend, inlaid on their opposite pairs of faces
## like the pips of a die, and the empty state is a bare stone face. Nothing is
## placed or hidden at run time -- the cube shows whatever it is turned to.
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
const ROLL_TIME := 0.34        # one quarter turn, settle included
const ROLL_TIME_TWO := 0.42    # two quarter turns in one roll (reset)
const BOB_DIP := 0.02
const BOB_TIME := 0.35
const BOB_LAG := 0.04
const BOB_LAG_DIAG := 0.07
const QUARTER := TAU / 4.0
## Faces on a cube, and so the length of the roll cycle: six quarter turns
## bring every face up once and end on the starting orientation.
const FACES := 6
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
## Hint and check (HUD spec, section 3).
const HINTS := 3
const CHECK_BLEND := 0.5     # 8/16: the flash a wrong cell gives on Check
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const SPARKLE_LIFT := 0.1
## Face index per cell value: empty up, then sun, then moon. Face f shows
## state `f % 3`, so faces 0 and 3 are the bare empty pair, 1 and 4 carry the
## sun and 2 and 5 the moon -- the pairing the tile model is built around.
const FACE := {-1: 0, 0: 1, 1: 2}

func _ready() -> void:
	super()
	solved.connect(_on_solved)

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad: Dictionary = {"rows": {}, "cols": {}}

var _cube_h: float = Placeholders.TILE_SIDE
var _cells: Array = []    # [r][c] -> Node3D pivot at the cube's centre
var _spins: Array = []    # [r][c] -> Node3D under the pivot, holds the roll
var _tiles: Array = []    # [r][c] -> Node3D
var _turns: Array = []    # [r][c] -> quarter turns rolled so far
var _rest_y: float = 0.0  # pivot height at rest: the cube's centre
var _rolls: Array = []    # [r][c] -> Tween or null, the roll in flight
var _bobs: Array = []     # [r][c] -> a neighbour bob or a given's dip
var fx: Node3D            # pooled one-shot particles, a child of the board
var _fades: Array = []         # [r][c] -> a blush fade in flight
var _blend: Array = []         # [r][c] -> painted blend toward BAD, on the grid
var _blend_target: Array = []  # [r][c] -> the blend the cell is heading for
var _hinted: Array = []        # [r][c] -> filled by a hint, so locked like a given
var _wobbles: Array = []       # [r][c] -> the Check shake in flight
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
## Taps on free cells as (r, c, previous value), newest last. Undo pops it.
var _history: Array[Vector3i] = []

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line. Every line has an equal count of each, and no two lines are identical."

func board_size() -> Vector2i: return Vector2i(n, n)
## The resting cube. Its top face is bare stone, so nothing stands above
## TILE_RISE; a roll lifts the cube by about 0.17 for the length of a tap,
## which the camera's margin absorbs. Framing for the peak instead would
## shrink the board for good.
func board_height() -> float: return Placeholders.TILE_RISE + 0.05
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
	_history = []
	_build_scene()
	_recolour()
	_refit()
	_enter()

## Reset as a wave: every filled free cell rolls forward to empty (a sun takes
## two quarter turns, a moon one) with a stagger from the near-left corner,
## and the givens hop a little to say they stay. The grid, the count and the blush
## change at once; only the prisms take their time.
func reset_board() -> void:
	_stop_entrance()
	_focus_clear()
	for r in n:
		for c in n:
			_settle(r, c)
			if _hinted[r][c]:
				# A hint is not a clue: reset gives the cell back to the player.
				_hinted[r][c] = false
				_given[r][c] = false
				_paint(_blend[r][c], r, c)
			var delay := Motion.stagger((n - 1 - r) + c, RESET_STAGGER)
			if _given[r][c]:
				_bobs[r][c] = Motion.hop(_cells[r][c], RESET_HOP, BOB_TIME, delay, _rest_y)
				continue
			var v: int = _grid[r][c]
			if v == -1:
				continue
			_grid[r][c] = -1
			var steps := 2 if v == 0 else 1
			_turns[r][c] += steps
			_roll(r, c, steps, delay)
	_history = []
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

func capabilities() -> Array[String]:
	return ["undo", "hint", "check", "lines"]

func can_undo() -> bool:
	return not is_done() and not _history.is_empty()

## Reverts the last tap: the cube rolls one quarter turn back the way it came,
## the only unwinding roll in the game (HUD spec, section 3). Counts no move; no
## state in the history was solved, or the game would have ended there.
func undo() -> bool:
	if is_done() or _history.is_empty():
		return false
	var last: Vector3i = _history.pop_back()
	var r := last.x
	var c := last.y
	_settle(r, c)
	_grid[r][c] = last.z
	_turns[r][c] -= 1
	_roll(r, c, -1)
	fx.cue("undo")
	_focus(r, c)
	_bob_neighbours(r, c)
	_recolour()
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Fills one cell from the solution with a sparkle and locks it (HUD spec,
## section 3): a wrong filled cell first, else the empty cell with the most
## filled cells in its row and column. Three per puzzle; reset does not
## refund them. Counts no move but can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var cell := _hint_cell()
	if cell.x < 0:
		return false
	var r := cell.y
	var c := cell.x
	_settle(r, c)
	var kept: Array[Vector3i] = []
	for h in _history:
		if h.x != r or h.y != c:
			kept.append(h)
	_history = kept
	var old: int = _grid[r][c]
	var target: int = _solution[r][c]
	_grid[r][c] = target
	var steps: int = posmod(FACE[target] - FACE[old], 3)
	_turns[r][c] += steps
	_roll(r, c, steps)
	_given[r][c] = true
	_hinted[r][c] = true
	_paint(_blend[r][c], r, c)
	fx.sparkle(BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE + SPARKLE_LIFT))
	fx.cue("hint")
	hints_used += 1
	_focus(r, c)
	_recolour()
	moved.emit()
	check_solved()
	return true

## The cell a hint fills, as (col, row); (-1, -1) when nothing qualifies.
func _hint_cell() -> Vector2i:
	for r in n:
		for c in n:
			if not _given[r][c] and _grid[r][c] != -1 and _grid[r][c] != _solution[r][c]:
				return Vector2i(c, r)
	var best := Vector2i(-1, -1)
	var best_score := -1
	for r in n:
		for c in n:
			if _grid[r][c] != -1:
				continue
			var score := 0
			for j in n:
				if _grid[r][j] != -1:
					score += 1
				if _grid[j][c] != -1:
					score += 1
			if score > best_score:
				best_score = score
				best = Vector2i(c, r)
	return best

## Marks every filled free cell that differs from the solution with a wobble
## and a flash (HUD spec, section 3). Returns how many; the press is counted
## in `checks`. Solving stays automatic; this only points.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong := 0
	for r in n:
		for c in n:
			if _given[r][c] or _grid[r][c] == -1 or _grid[r][c] == _solution[r][c]:
				continue
			wrong += 1
			Motion.stop(_wobbles[r][c])
			_cells[r][c].rotation.z = 0.0
			_wobbles[r][c] = Motion.wobble(_cells[r][c])
			_flash(r, c)
	fx.cue("check" if wrong > 0 else "check_ok")
	return wrong

## A quick blush to CHECK_BLEND and back to whatever blend the cell's line
## is heading for. Replaces the cell's running fade; _blend_target is not
## touched, so a later _recolour does not restart it.
func _flash(r: int, c: int) -> void:
	Motion.stop(_fades[r][c])
	var setter := _paint.bind(r, c)
	var back: float = _blend_target[r][c]
	var tw: Tween = Motion.fade(_tiles[r][c], setter, _blend[r][c], CHECK_BLEND, CHECK_IN, BLUSH_STEPS)
	if tw == null:
		setter.call(back)
		_fades[r][c] = null
		return
	tw.tween_method(setter, CHECK_BLEND, back, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fades[r][c] = tw

## The focused row and column for the working-line card, or {} without a focus.
func line_state() -> Dictionary:
	if focus_cell.x < 0:
		return {}
	var r := focus_cell.y
	var c := focus_cell.x
	var col := []
	for i in n:
		col.append(_grid[i][c])
	return {"row": {"index": r, "cells": (_grid[r] as Array).duplicate()}, "col": {"index": c, "cells": col}}

# --- scene ---

## Kills every tween the previous board still tracks, so a rebuild never
## inherits a roll, hop, bob or blush aimed at nodes that are about to go.
func _stop_all() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for rows in [_rolls, _bobs, _fades, _wobbles]:
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
	_spins = []
	_tiles = []
	_turns = []
	_rolls = []
	_bobs = []
	_fades = []
	_blend = []
	_blend_target = []
	_hinted = []
	_wobbles = []

	board.add_child(Platform.build(n, n))
	fx = Fx.new()
	board.add_child(fx)
	_rest_y = Placeholders.TILE_RISE - Placeholders.TILE_HALF
	_ring = Models.instance("focus_ring")
	_ring.name = "FocusRing"
	_ring.visible = false
	_ring_mat = Models.meshes(_ring)[0].material_override
	board.add_child(_ring)
	focus_cell = Vector2i(-1, -1)

	for r in n:
		var cell_row := []
		var spin_row := []
		var tile_row := []
		var turn_row := []
		var roll_row := []
		var bob_row := []
		var fade_row := []
		var blend_row := []
		var target_row := []
		var hinted_row := []
		var wobble_row := []
		for c in n:
			var tile := Models.instance("tile")
			if r == 0 and c == 0:
				_cube_h = Models.height(tile)
			var half := Placeholders.TILE_HALF
			# The pivot sits at the cube's centre, half a side under its top
			# face, and carries the cell's hop, dip and Check wobble. The roll
			# goes on the spin under it, so a wobble on the pivot never
			# clobbers the orientation the roll left behind.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE - half)
			board.add_child(pivot)
			cell_row.append(pivot)
			var spin := Node3D.new()
			spin.name = "spin"
			pivot.add_child(spin)
			spin_row.append(spin)
			# The model's origin is the centre of its base, so lifting it by
			# the measured height less a half puts the cube's centre on the
			# spin's origin, which is what it turns about.
			tile.position = Vector3(0.0, -(_cube_h - half), 0.0)
			spin.add_child(tile)
			tile_row.append(tile)
			turn_row.append(FACE[_grid[r][c]])
			roll_row.append(null)
			bob_row.append(null)
			fade_row.append(null)
			blend_row.append(0.0)
			target_row.append(0.0)
			hinted_row.append(false)
			wobble_row.append(null)
			spin.basis = _orient(turn_row[c])
		_cells.append(cell_row)
		_spins.append(spin_row)
		_tiles.append(tile_row)
		_turns.append(turn_row)
		_rolls.append(roll_row)
		_bobs.append(bob_row)
		_fades.append(fade_row)
		_blend.append(blend_row)
		_blend_target.append(target_row)
		_hinted.append(hinted_row)
		_wobbles.append(wobble_row)
	for r in n:
		for c in n:
			_paint(0.0, r, c)

## The axis of the `step`-th quarter turn, in the board's space. It alternates
## because three states will not fit in the four faces around one axis: an
## even step rolls the cube toward the player (about X), an odd step rolls it
## to the left (about Z). Following that pattern from the identity, the face
## up after k steps is `k % FACES` and the state it shows is `k % 3`, and six
## steps compose back to the identity exactly.
static func _roll_axis(step: int) -> Vector3:
	return Vector3.RIGHT if posmod(step, 2) == 0 else Vector3.BACK

## Orientation of a cube that has rolled `steps` quarter turns, built from the
## canonical table rather than from the cube's current basis, so a thousand
## rolls accumulate no drift. Negative steps (undo) wrap the same way.
static func _orient(steps: int) -> Basis:
	var b := Basis.IDENTITY
	for i in posmod(steps, FACES):
		b = Basis(_roll_axis(i), QUARTER) * b
	return b

## Orientation the cell's roll is heading for: the face it is about to show.
func _target_basis(r: int, c: int) -> Basis:
	return _orient(_turns[r][c])

## Ends every motion on cell (r, c) at once: the cube snaps to the face it was
## turning to and back down onto the platform, its colour caught up with the
## state.
func _settle(r: int, c: int) -> void:
	Motion.stop(_rolls[r][c])
	Motion.stop(_bobs[r][c])
	Motion.stop(_wobbles[r][c])
	_rolls[r][c] = null
	_bobs[r][c] = null
	_wobbles[r][c] = null
	var spin: Node3D = _spins[r][c]
	spin.basis = _target_basis(r, c)
	spin.position.y = 0.0
	var pivot: Node3D = _cells[r][c]
	pivot.rotation.z = 0.0
	pivot.position.y = _rest_y
	_paint(_blend[r][c], r, c)

## Rolls cell (r, c) on by `steps` quarter turns after `delay`, one tumble per
## step, with the settle and the pivot-on-the-edge lift that make it a roll
## rather than a spin in place. Negative `steps` roll back the way the cube
## came (undo). `_turns` is already at the destination when this is called, so
## the roll starts from `_turns - steps`.
func _roll(r: int, c: int, steps := 1, delay := 0.0) -> void:
	var spin: Node3D = _spins[r][c]
	var d := signi(steps)
	var count := absi(steps)
	var turns := []
	for i in count:
		# The step this tumble leaves from, and the axis of the turn between
		# it and the next: going forward that is the step's own axis, coming
		# back it is the axis of the step being undone.
		var from: int = _turns[r][c] - steps + d * i
		turns.append([_orient(from), _roll_axis(mini(from, from + d)), d * QUARTER])
	var time := ROLL_TIME if count == 1 else ROLL_TIME_TWO
	var tw: Tween = Motion.roll(spin, turns, Placeholders.TILE_HALF, 0.0, time, delay)
	tw.finished.connect(_on_roll_landed.bind(r, c, steps))
	_rolls[r][c] = tw
	fx.cue("roll")

## The roll has landed: the cube takes the colour of its new state, and dust
## rises from the bottom edge it rolled over -- the near edge rolling toward
## the player, the left edge rolling left, the opposite one when an undo takes
## it back.
func _on_roll_landed(r: int, c: int, steps := 1) -> void:
	_paint(_blend[r][c], r, c)
	var d := signi(steps)
	var last: int = _turns[r][c] - (1 if d > 0 else 0)
	var half := Placeholders.TILE_HALF * d
	var edge := Vector3(0.0, 0.0, half) if _roll_axis(last) == Vector3.RIGHT else Vector3(-half, 0.0, 0.0)
	var pivot: Node3D = _cells[r][c]
	fx.puff(Vector3(pivot.position.x, 0.0, pivot.position.z) + edge)
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
	focus_changed.emit()

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
	focus_changed.emit()

# --- entrance and solve ---

## The board arrives: the platform rises from below and rings the water, then
## the cubes pop in along a diagonal wave from the far-left corner. Taps are
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

## Every cube hops once, row by row from the far edge, once the last roll
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

## The cube's colour at a blend toward BAD: slate once a moon is up, stone
## otherwise, darker when the cell is a given. The whole cube takes the
## colour, not the face: a cube that rotates cannot hold a colour on one face,
## since a moon face lands on the front wall while an empty face is up. The
## blend snaps to the 16-step grid, so a fade never asks the toon cache for
## more than 17 colours per base.
func _paint(blend: float, r: int, c: int) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_blend[r][c] = blend
	var locked: bool = _given[r][c]
	var moon: bool = _grid[r][c] == 1
	var base: Color
	if moon:
		base = Pal.SLATE_GIVEN if locked else Pal.SLATE
	else:
		base = Pal.STONE_GIVEN if locked else Pal.STONE
	# By name, not Models.tint: only the stone body takes the state colour and
	# the blush. The sun and the moon are inlaid layers of the same model and
	# keep the colours they were modelled with, or a moon cell would paint its
	# own crescent slate and show nothing.
	Models.tint_named(_tiles[r][c], "Stone", base.lerp(Pal.BAD, blend))

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
	_history.append(Vector3i(r, c, v))
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
