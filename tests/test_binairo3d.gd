extends RefCounted

## Binairo on the stage: tapping a cell changes the grid at once but the tile
## flips like a card, so what the cell shows lags until the midpoint; a second
## tap mid-flip settles the first flip before starting the next. Needs a live
## tree (PuzzleBase3D mounts in _ready), so this runs from run_in_tree.

const Binairo3D = preload("res://puzzles/binairo3d.gd")
const Stage = preload("res://world/stage.gd")
const BoardMath = preload("res://core/board_math.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var stage: Node3D = Stage.new()
	root.add_child(stage)
	var p = Binairo3D.new()
	root.add_child(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	p.build(rng, 0)

	_test_platform_under_board(t, p)
	_test_pivot_geometry(t, p)
	_test_tap_flips(t, p)
	_test_locked_cell(t, p)
	_test_reset_settles(t, p)

	root.remove_child(p)
	p.free()
	root.remove_child(stage)
	stage.free()

static func _find_cell(p, locked: bool) -> Vector2i:
	for r in p.n:
		for c in p.n:
			if p._given[r][c] == locked:
				return Vector2i(c, r)
	return Vector2i(-1, -1)

static func _tap(p, r: int, c: int) -> void:
	p.on_board_press(BoardMath.cell_center(r, c, p.n, p.n, p._tile_h))

static func _test_platform_under_board(t, p) -> void:
	var platform: Node = p.board.get_node_or_null("Platform")
	t.check(platform != null and platform.get_node_or_null("Slab") != null, "board carries a Platform with a Slab")
	t.check(platform != null and platform.get_child_count() == 1 + 4 * p.n + 4, "platform has a full moss rim")

static func _test_pivot_geometry(t, p) -> void:
	# The tile is hung under a pivot at half its height, so the top face must
	# still land at _tile_h in board space: that is the plane taps hit.
	var cell := _find_cell(p, false)
	var pivot: Node3D = p._cells[cell.y][cell.x]
	var lo := INF
	var hi := -INF
	for mi in Models.meshes(p._tiles[cell.y][cell.x]):
		var xf: Transform3D = pivot.transform * _chain(mi, pivot)
		for v in mi.mesh.get_faces():
			var y: float = (xf * v).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	t.check(is_zero_approx(lo) and is_equal_approx(hi, p._tile_h), "tile spans y=0..%.2f under its pivot (got %.3f..%.3f)" % [p._tile_h, lo, hi])
	var centre := BoardMath.cell_center(cell.y, cell.x, p.n, p.n, p._tile_h * 0.5)
	t.check(pivot.position.is_equal_approx(centre), "pivot sits at the cell centre, half a tile up")

## Transform of `node` relative to `stop` (exclusive), whatever the depth of
## the imported scene.
static func _chain(node: Node3D, stop: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != stop:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

static func _test_tap_flips(t, p) -> void:
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	t.check(p._grid[r][c] == -1 and p._shown[r][c] == -1, "cell starts empty and shows empty")
	_tap(p, r, c)
	t.eq(p._grid[r][c], 0, "tap sets the grid to sun at once")
	t.eq(p._shown[r][c], -1, "the face waits for the flip midpoint")
	t.check(p._marks[r][c].visible and not p._suns[r][c].visible, "empty mark still showing during the flip")
	var first: Tween = p._flips[r][c]
	t.check(first != null and first.is_running(), "a flip tween is running")

	_tap(p, r, c)
	t.eq(p._grid[r][c], 1, "second tap sets the grid to moon")
	t.eq(p._shown[r][c], 0, "second tap settles the first flip, showing sun")
	t.check(p._suns[r][c].visible and not p._moons[r][c].visible, "sun emblem visible after settling")
	t.check(not first.is_valid() or not first.is_running(), "first tween was killed")
	var second: Tween = p._flips[r][c]
	t.check(second != null and second != first and second.is_running(), "a new flip tween is running")
	var tint: Color = Models.meshes(p._tiles[r][c])[0].get_surface_override_material(0).get_shader_parameter("albedo")
	t.check(tint.is_equal_approx(Pal.STONE), "tile keeps the shown face's colour until the midpoint")

static func _test_locked_cell(t, p) -> void:
	var cell := _find_cell(p, true)
	var r := cell.y
	var c := cell.x
	var before: int = p._grid[r][c]
	_tap(p, r, c)
	t.eq(p._grid[r][c], before, "tapping a given cell changes nothing")
	t.check(p._flips[r][c] == null, "a given cell never flips")

static func _test_reset_settles(t, p) -> void:
	p.reset_board()
	var all_shown := true
	var all_flat := true
	var none_running := true
	for r in p.n:
		for c in p.n:
			if p._shown[r][c] != p._grid[r][c]:
				all_shown = false
			if not is_zero_approx(p._cells[r][c].rotation.x):
				all_flat = false
			var tw: Tween = p._flips[r][c]
			if tw != null and tw.is_valid() and tw.is_running():
				none_running = false
	t.check(all_shown, "reset shows every cell's grid value at once")
	t.check(all_flat, "reset leaves every pivot flat")
	t.check(none_running, "reset leaves no flip running")
