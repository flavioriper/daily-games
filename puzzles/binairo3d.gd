extends "res://core/puzzle_base_3d.gd"

## Binairo on the island stage. Every cell is a trilon: a three-sided stone
## prism lying along X on a pivot through its axis, with one face per state.
## The empty face (a small diamond) is up at rest, the sun face waits on the
## near slope and the moon face on the far slope, both hidden inside the
## platform. A tap rolls the prism a third of a turn toward the player so the
## next face comes up: empty -> sun -> moon -> empty. The grid changes at
## once; the roll is only how the change is shown. Tiles in a line that
## already breaks a rule blush, so the player learns the rules by touching.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")

const ROLL_TIME := 0.3
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
var _rolls: Array = []    # [r][c] -> Tween or null

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

	board.add_child(Platform.build(n, n))

	for r in n:
		var cell_row := []
		var tile_row := []
		var sun_row := []
		var moon_row := []
		var mark_row := []
		var turn_row := []
		var roll_row := []
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
			pivot.rotation.x = -turn_row[c] * THIRD
		_cells.append(cell_row)
		_tiles.append(tile_row)
		_suns.append(sun_row)
		_moons.append(moon_row)
		_marks.append(mark_row)
		_turns.append(turn_row)
		_rolls.append(roll_row)

## Pivot angle that puts the cell's current face up. Rolling always goes the
## same way (toward the player), so the angle keeps counting down rather than
## unwinding when a cell comes back round to empty.
func _target_angle(r: int, c: int) -> float:
	return -_turns[r][c] * THIRD

## Ends a roll in progress at once, snapping to the face it was turning to.
func _settle(r: int, c: int) -> void:
	var tw: Tween = _rolls[r][c]
	if tw == null or not tw.is_valid() or not tw.is_running():
		return
	tw.kill()
	_rolls[r][c] = null
	_cells[r][c].rotation.x = _target_angle(r, c)

func _roll(r: int, c: int) -> void:
	var pivot: Node3D = _cells[r][c]
	var tw := pivot.create_tween()
	tw.tween_method(func(a: float): pivot.rotation.x = a, pivot.rotation.x, _target_angle(r, c), ROLL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rolls[r][c] = tw

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
		return
	# A tap mid-roll snaps that roll home first, so the next one starts from
	# a face, never from between two.
	_settle(r, c)
	# empty -> sun -> moon -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_turns[r][c] += 1
	_roll(r, c)
	_recolour()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, plane_height()))
