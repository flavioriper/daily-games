extends "res://core/puzzle_base_3d.gd"

## Binairo on the island stage. Tap a tile to cycle empty -> sun -> moon ->
## empty. Sun cells are cream stone with an orange sun; moon cells turn slate
## with an ivory crescent. Tiles in a line that already breaks a rule blush,
## so the player learns the rules by touching rather than by reading them.

const Gen = preload("res://puzzles/binairo_gen.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")

const POP_TIME := 0.18
const BAD_BLEND := 0.35
const PLATFORM_LIP := 0.5

var n: int = 6
var _grid: Array = []
var _given: Array = []
var _solution: Array = []
var _bad: Dictionary = {"rows": {}, "cols": {}}

var _tile_h: float = Placeholders.TILE_H
var _platform: Node3D
var _tiles: Array = []    # [r][c] -> Node3D
var _suns: Array = []     # [r][c] -> Node3D
var _moons: Array = []    # [r][c] -> Node3D
var _marks: Array = []    # [r][c] -> Node3D

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line, an equal count of each per line, and no two lines identical."

func board_size() -> Vector2i: return Vector2i(n, n)
func board_height() -> float: return _tile_h + Placeholders.EMBLEM_H + 0.1
func plane_height() -> float: return _tile_h
func board_margin() -> float: return PLATFORM_LIP
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
			if not _given[r][c]:
				_grid[r][c] = -1
			_show_cell(r, c, false)
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
	_tiles = []
	_suns = []
	_moons = []
	_marks = []

	_platform = Models.instance("platform")
	_platform.scale = Vector3(n + 2.0 * PLATFORM_LIP, 1.0, n + 2.0 * PLATFORM_LIP)
	_platform.position = Vector3(0.0, -Placeholders.PLATFORM_H, 0.0)
	board.add_child(_platform)

	for r in n:
		var tile_row := []
		var sun_row := []
		var moon_row := []
		var mark_row := []
		for c in n:
			var at := BoardMath.cell_center(r, c, n, n, 0.0)
			var tile := Models.instance("tile")
			tile.position = at
			board.add_child(tile)
			tile_row.append(tile)
			if r == 0 and c == 0:
				_tile_h = Models.height(tile)
			var top := at + Vector3(0.0, _tile_h, 0.0)
			var sun := Models.instance("emblem_sun")
			sun.position = top
			board.add_child(sun)
			sun_row.append(sun)
			var moon := Models.instance("emblem_moon")
			moon.position = top
			board.add_child(moon)
			moon_row.append(moon)
			var mark := Models.instance("empty_mark")
			mark.position = top
			board.add_child(mark)
			mark_row.append(mark)
		_tiles.append(tile_row)
		_suns.append(sun_row)
		_moons.append(moon_row)
		_marks.append(mark_row)
	for r in n:
		for c in n:
			_show_cell(r, c, false)

func _show_cell(r: int, c: int, pop: bool) -> void:
	var v: int = _grid[r][c]
	var sun: Node3D = _suns[r][c]
	var moon: Node3D = _moons[r][c]
	var mark: Node3D = _marks[r][c]
	sun.visible = v == 0
	moon.visible = v == 1
	mark.visible = v == -1
	sun.scale = Vector3.ONE
	moon.scale = Vector3.ONE
	if pop and v != -1:
		var emblem: Node3D = sun if v == 0 else moon
		emblem.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_property(emblem, "scale", Vector3.ONE, POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tile_colour(r: int, c: int) -> Color:
	var moon: bool = _grid[r][c] == 1
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
	# empty -> sun -> moon -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_show_cell(r, c, true)
	_recheck()
	note_move()

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the 3D counterpart of the 2D boards' origin + (c+.5, r+.5) * cell.
func cell_to_local(r: int, c: int) -> Vector2:
	return board_to_local(BoardMath.cell_center(r, c, n, n, _tile_h))
