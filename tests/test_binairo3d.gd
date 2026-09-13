extends RefCounted

## Binairo on the stage: every cell is a three-sided prism (a trilon) on a
## pivot through its axis. The faces carry empty, sun and moon; a tap rolls
## the prism a third of a turn toward the player so the next face comes up.
## The grid changes at once, the roll is only visual, and a second tap mid-roll
## snaps the first roll home before starting the next. Needs a live tree
## (PuzzleBase3D mounts in _ready), so this runs from run_in_tree.

const Binairo3D = preload("res://puzzles/binairo3d.gd")
const Stage = preload("res://world/stage.gd")
const BoardMath = preload("res://core/board_math.gd")
const Pal = preload("res://core/palette.gd")
const Models = preload("res://core/models.gd")
const Placeholders = preload("res://core/placeholders.gd")

const THIRD := TAU / 3.0

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
	_test_prism_geometry(t, p)
	_test_faces_carry_emblems(t, p)
	_test_face_colours(t, p)
	_test_tap_rolls(t, p)
	_test_locked_cell(t, p)
	_test_reset_snaps(t, p)

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
	p.on_board_press(BoardMath.cell_center(r, c, p.n, p.n, p.plane_height()))

## Transform of `node` relative to `stop` (exclusive), whatever the depth of
## the imported scene.
static func _chain(node: Node3D, stop: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != stop:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

static func _test_platform_under_board(t, p) -> void:
	var platform: Node = p.board.get_node_or_null("Platform")
	t.check(platform != null and platform.get_node_or_null("Slab") != null, "board carries a Platform with a Slab")
	t.check(platform != null and platform.get_child_count() == 1 + 4 * p.n + 4, "platform has a full moss rim")

static func _test_prism_geometry(t, p) -> void:
	# At rest the flat face sits TILE_RISE above the platform (the tap plane)
	# and the prism's axis, the pivot, is one apothem below it. The rest of the
	# prism hangs inside the platform.
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
	t.check(absf(hi - Placeholders.TILE_RISE) < 0.005, "flat face rests at y=%.2f (got %.3f)" % [Placeholders.TILE_RISE, hi])
	t.check(lo < -0.5, "the apex hangs inside the platform (min y %.3f)" % lo)
	t.check(is_equal_approx(p.plane_height(), Placeholders.TILE_RISE), "taps land on the flat face")
	var axis := BoardMath.cell_center(cell.y, cell.x, p.n, p.n, Placeholders.TILE_RISE - Placeholders.TILE_APOTHEM)
	t.check(pivot.position.is_equal_approx(axis), "pivot sits on the prism axis (%s vs %s)" % [pivot.position, axis])

static func _test_faces_carry_emblems(t, p) -> void:
	# Face 0 (up at rest) carries the empty mark, face 1 the sun on the near
	# side (+Z), face 2 the moon on the far side. Each emblem stands on its
	# face's centre and points along its normal, so all three stay visible and
	# only the pivot's angle says which one is up.
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	var apothem := Placeholders.TILE_APOTHEM
	var checks := [[p._marks[r][c], 0], [p._suns[r][c], 1], [p._moons[r][c], 2]]
	var all_ok := true
	for pair in checks:
		var emblem: Node3D = pair[0]
		var face: int = pair[1]
		var want := Basis(Vector3.RIGHT, face * THIRD) * Vector3(0.0, apothem, 0.0)
		if not emblem.position.is_equal_approx(want) or not is_equal_approx(wrapf(emblem.rotation.x - face * THIRD, -PI, PI), 0.0) or not emblem.visible:
			all_ok = false
	t.check(all_ok, "mark, sun and moon stand on faces 0, 1, 2 at one apothem from the axis")
	t.check(p._suns[r][c].position.z > 0.1, "sun face is on the near side, toward the player")

static func _face_colour(p, r: int, c: int, face: String) -> Color:
	for mi in Models.meshes(p._tiles[r][c]):
		for i in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(i).resource_name == face:
				return Color(mi.get_surface_override_material(i).get_shader_parameter("albedo"))
	return Color.MAGENTA

static func _test_face_colours(t, p) -> void:
	var free := _find_cell(p, false)
	var moon := _face_colour(p, free.y, free.x, "Face_Moon")
	var sun := _face_colour(p, free.y, free.x, "Face_Sun")
	var empty := _face_colour(p, free.y, free.x, "Face_Empty")
	var cap := _face_colour(p, free.y, free.x, "Cap")
	var blend: float = p.BAD_BLEND
	var slate_ok := moon.is_equal_approx(Pal.SLATE) or moon.is_equal_approx(Pal.SLATE.lerp(Pal.BAD, blend))
	var stone_ok := (sun.is_equal_approx(Pal.STONE) or sun.is_equal_approx(Pal.STONE.lerp(Pal.BAD, blend))) and sun.is_equal_approx(empty) and sun.is_equal_approx(cap)
	t.check(slate_ok, "moon face is slate on a free cell (got %s)" % moon.to_html(false))
	t.check(stone_ok, "sun, empty and cap faces are stone on a free cell")
	var locked := _find_cell(p, true)
	var lmoon := _face_colour(p, locked.y, locked.x, "Face_Moon")
	var lcap := _face_colour(p, locked.y, locked.x, "Cap")
	t.check(lmoon.is_equal_approx(Pal.SLATE_GIVEN) or lmoon.is_equal_approx(Pal.SLATE_GIVEN.lerp(Pal.BAD, blend)), "given cell's moon face is the darker slate")
	t.check(lcap.is_equal_approx(Pal.STONE_GIVEN) or lcap.is_equal_approx(Pal.STONE_GIVEN.lerp(Pal.BAD, blend)), "given cell's caps are the darker stone")

static func _test_tap_rolls(t, p) -> void:
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	var pivot: Node3D = p._cells[r][c]
	t.check(p._grid[r][c] == -1 and is_zero_approx(pivot.rotation.x), "cell starts empty with face 0 up")
	_tap(p, r, c)
	t.eq(p._grid[r][c], 0, "tap sets the grid to sun at once")
	t.check(is_zero_approx(pivot.rotation.x), "the prism has not moved before the roll's first frame")
	var first: Tween = p._rolls[r][c]
	t.check(first != null and first.is_running(), "a roll tween is running")
	t.check(is_equal_approx(p._target_angle(r, c), -THIRD), "roll target is one third turn toward the player")

	_tap(p, r, c)
	t.eq(p._grid[r][c], 1, "second tap sets the grid to moon")
	t.check(not first.is_valid() or not first.is_running(), "first roll was killed")
	t.check(is_equal_approx(p._target_angle(r, c), -2.0 * THIRD), "second roll continues in the same direction")
	var second: Tween = p._rolls[r][c]
	t.check(second != null and second != first and second.is_running(), "a new roll tween is running")

	_tap(p, r, c)
	t.eq(p._grid[r][c], -1, "third tap empties the cell")
	t.check(is_equal_approx(p._target_angle(r, c), -TAU), "third roll completes the turn rather than unwinding")

static func _test_locked_cell(t, p) -> void:
	var cell := _find_cell(p, true)
	var r := cell.y
	var c := cell.x
	var before: int = p._grid[r][c]
	var angle: float = p._cells[r][c].rotation.x
	_tap(p, r, c)
	t.eq(p._grid[r][c], before, "tapping a given cell changes nothing")
	t.check(p._rolls[r][c] == null and is_equal_approx(p._cells[r][c].rotation.x, angle), "a given cell never rolls")

static func _test_reset_snaps(t, p) -> void:
	p.reset_board()
	var all_home := true
	var none_running := true
	for r in p.n:
		for c in p.n:
			var pivot: Node3D = p._cells[r][c]
			var state: int = p._grid[r][c]
			var want := -float(state + 1 if state >= 0 else 0) * THIRD
			if not is_equal_approx(wrapf(pivot.rotation.x - want, -PI, PI), 0.0):
				all_home = false
			var tw: Tween = p._rolls[r][c]
			if tw != null and tw.is_valid() and tw.is_running():
				none_running = false
	t.check(all_home, "reset snaps every prism to the face for its grid value")
	t.check(none_running, "reset leaves no roll running")
