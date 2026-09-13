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
const BAD_BLEND := 0.35
## Face index per cell value: empty up, then sun, then moon.
const FACE := {-1: 0, 0: 1, 1: 2}

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

func reset_board() -> void:
	for r in n:
		for c in n:
			_settle(r, c)
			if not _given[r][c]:
				_grid[r][c] = -1
			_turns[r][c] = FACE[_grid[r][c]]
			_cells[r][c].rotation.x = _target_angle(r, c)
			_show_faces(r, c, false)
	moves = 0
	_recolour()

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

func _build_scene() -> void:
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

	board.add_child(Platform.build(n, n))
	fx = Fx.new()
	board.add_child(fx)
	_rest_y = Placeholders.TILE_RISE - Placeholders.TILE_APOTHEM

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
	for r in n:
		for c in n:
			_show_faces(r, c, false)

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

## Face colours: stone for the empty and sun faces and the caps, slate for
## the moon face, darker when the cell is a given, blushed on a broken line.
func _recolour() -> void:
	_bad = Gen.bad_lines(_grid)
	for r in n:
		for c in n:
			var locked: bool = _given[r][c]
			var stone: Color = Pal.STONE_GIVEN if locked else Pal.STONE
			var slate: Color = Pal.SLATE_GIVEN if locked else Pal.SLATE
			if _bad.rows.has(r) or _bad.cols.has(c):
				stone = stone.lerp(Pal.BAD, BAD_BLEND)
				slate = slate.lerp(Pal.BAD, BAD_BLEND)
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
	_bob_neighbours(r, c)
	_recolour()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, plane_height()))
