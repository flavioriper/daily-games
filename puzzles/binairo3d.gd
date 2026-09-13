extends "res://core/puzzle_base_3d.gd"

## Binairo on the island stage. Tap a tile to cycle empty -> sun -> moon ->
## empty. Sun cells are cream stone with an orange sun; moon cells turn slate
## with an ivory crescent. Each cell hangs under a pivot and flips like a card
## on a tap: the grid changes at once, the face it shows swaps at the flip's
## midpoint. Tiles in a line that already breaks a rule blush, so the player
## learns the rules by touching rather than by reading them.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")
const Platform = preload("res://core/platform.gd")
const Flip = preload("res://core/flip.gd")

const FLIP_TIME := 0.32
const BAD_BLEND := 0.35

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad: Dictionary = {"rows": {}, "cols": {}}

var _tile_h: float = Placeholders.TILE_H
var _cells: Array = []    # [r][c] -> Node3D pivot at half tile height
var _tiles: Array = []    # [r][c] -> Node3D
var _suns: Array = []     # [r][c] -> Node3D
var _moons: Array = []    # [r][c] -> Node3D
var _marks: Array = []    # [r][c] -> Node3D
var _shown: Array = []    # [r][c] -> value the cell currently displays
var _flips: Array = []    # [r][c] -> Tween or null

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line, an equal count of each per line, and no two lines identical."

func board_size() -> Vector2i: return Vector2i(n, n)
func board_height() -> float: return _tile_h + Placeholders.EMBLEM_H + 0.1
func plane_height() -> float: return _tile_h
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
	_recheck()
	_refit()

func reset_board() -> void:
	for r in n:
		for c in n:
			_settle(r, c)
			if not _given[r][c]:
				_grid[r][c] = -1
			_apply_face(r, c)
	moves = 0
	_recheck()

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
	_shown = []
	_flips = []

	board.add_child(Platform.build(n, n))

	for r in n:
		var cell_row := []
		var tile_row := []
		var sun_row := []
		var moon_row := []
		var mark_row := []
		var shown_row := []
		var flip_row := []
		for c in n:
			var tile := Models.instance("tile")
			if r == 0 and c == 0:
				_tile_h = Models.height(tile)
			# The pivot sits at half tile height so a flip turns the tile about
			# its own centre; the tile hangs below it, the emblems rest on top.
			var pivot := Node3D.new()
			pivot.name = "cell_%d_%d" % [r, c]
			pivot.position = _rest(r, c)
			board.add_child(pivot)
			cell_row.append(pivot)
			tile.position = Vector3(0.0, -_tile_h * 0.5, 0.0)
			pivot.add_child(tile)
			tile_row.append(tile)
			var top := Vector3(0.0, _tile_h * 0.5, 0.0)
			var sun := Models.instance("emblem_sun")
			sun.position = top
			pivot.add_child(sun)
			sun_row.append(sun)
			var moon := Models.instance("emblem_moon")
			moon.position = top
			pivot.add_child(moon)
			moon_row.append(moon)
			var mark := Models.instance("empty_mark")
			mark.position = top
			pivot.add_child(mark)
			mark_row.append(mark)
			shown_row.append(-1)
			flip_row.append(null)
		_cells.append(cell_row)
		_tiles.append(tile_row)
		_suns.append(sun_row)
		_moons.append(moon_row)
		_marks.append(mark_row)
		_shown.append(shown_row)
		_flips.append(flip_row)
	for r in n:
		for c in n:
			_apply_face(r, c)

## Makes the cell show its grid value: emblem visibility and tile colour.
func _apply_face(r: int, c: int) -> void:
	var v: int = _grid[r][c]
	_shown[r][c] = v
	_suns[r][c].visible = v == 0
	_moons[r][c].visible = v == 1
	_marks[r][c].visible = v == -1
	Models.tint(_tiles[r][c], _tile_colour(r, c))

## Where a cell's pivot rests: the cell centre, half a tile up.
func _rest(r: int, c: int) -> Vector3:
	return BoardMath.cell_center(r, c, n, n, _tile_h * 0.5)

## Ends a flip in progress at once, showing the face it was turning to.
func _settle(r: int, c: int) -> void:
	var tw: Tween = _flips[r][c]
	if tw == null or not tw.is_valid() or not tw.is_running():
		return
	tw.kill()
	_flips[r][c] = null
	_cells[r][c].rotation.x = 0.0
	_cells[r][c].position = _rest(r, c)
	_apply_face(r, c)

## Colour for the face the tile is showing (not the grid: mid-flip the tile
## still wears its old face) with the blush of a broken line on top.
func _tile_colour(r: int, c: int) -> Color:
	var moon: bool = _shown[r][c] == 1
	var locked: bool = _given[r][c]
	var base: Color
	if moon:
		base = Pal.SLATE_GIVEN if locked else Pal.SLATE
	else:
		base = Pal.STONE_GIVEN if locked else Pal.STONE
	if _bad.rows.has(r) or _bad.cols.has(c):
		return base.lerp(Pal.BAD, BAD_BLEND)
	return base

func _recheck() -> void:
	_bad = Gen.bad_lines(_grid)
	for r in n:
		for c in n:
			Models.tint(_tiles[r][c], _tile_colour(r, c))

# --- input ---

func on_board_press(hit: Vector3) -> void:
	var cell := BoardMath.world_to_cell(hit, n, n)
	if cell.x < 0:
		return
	var c := cell.x
	var r := cell.y
	if _given[r][c]:
		return
	# A tap mid-flip finishes that flip first, so the card never turns from
	# a face it never showed.
	_settle(r, c)
	# empty -> sun -> moon -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_flips[r][c] = Flip.start(_cells[r][c], _apply_face.bind(r, c), FLIP_TIME)
	_recheck()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, _tile_h))
