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
const Motion = preload("res://core/motion.gd")

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
	_test_neighbour_bob(t, p)
	_test_focus_ring(t, p)
	_test_blush_pulse(t, p)
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
		if not emblem.position.is_equal_approx(want) or not is_equal_approx(wrapf(emblem.rotation.x - face * THIRD, -PI, PI), 0.0):
			all_ok = false
	t.check(all_ok, "mark, sun and moon stand on faces 0, 1, 2 at one apothem from the axis")
	t.check(p._suns[r][c].position.z > 0.1, "sun face is on the near side, toward the player")
	# The two faces inside the platform are hidden at rest: they cannot be
	# seen and would only cost draw calls.
	t.check(p._marks[r][c].visible and not p._suns[r][c].visible and not p._moons[r][c].visible,
		"at rest only the face-up emblem is visible")

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
	t.check(p._marks[r][c].visible and p._suns[r][c].visible, "both faces in motion are visible during the roll")

	var lift: Tween = p._hops[r][c]
	t.check(Motion.running(lift), "a lift rides along the roll")
	# Drive the roll to its end. The back ease is already overshooting at the
	# half, so the between-faces check steps a quarter.
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.rotation.x < -0.2 and pivot.rotation.x > -THIRD, "a quarter in, the prism is between faces (%.3f)" % pivot.rotation.x)
	lift.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.position.y > p._rest_y + 0.01, "the prism has lifted off its axis (%.3f)" % (pivot.position.y - p._rest_y))
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.rotation.x < -THIRD, "halfway, the prism has rolled past the face and is springing back (%.3f)" % pivot.rotation.x)
	first.custom_step(p.ROLL_TIME)
	lift.custom_step(p.ROLL_TIME)
	t.check(is_equal_approx(pivot.rotation.x, -THIRD), "the roll lands exactly on the sun face (%.3f)" % pivot.rotation.x)
	t.check(is_equal_approx(pivot.position.y, p._rest_y), "the lift lands back on the axis (%.4f)" % pivot.position.y)
	t.check(not first.is_running(), "the roll tween finished")
	t.check(p._suns[r][c].visible and not p._marks[r][c].visible and not p._moons[r][c].visible,
		"after the roll only the sun emblem is visible")
	t.eq(p.fx.last_cue, "land", "landing fires the land cue and its dust")

	_tap(p, r, c)
	t.eq(p._grid[r][c], 1, "second tap sets the grid to moon")
	t.check(is_equal_approx(p._rolls[r][c].get_total_elapsed_time(), 0.0) or p._rolls[r][c] != first, "a finished roll is left alone by settle")
	t.check(not first.is_valid() or not first.is_running(), "first roll is no longer running")
	t.check(is_equal_approx(p._target_angle(r, c), -2.0 * THIRD), "second roll continues in the same direction")
	var second: Tween = p._rolls[r][c]
	t.check(second != null and second != first and second.is_running(), "a new roll tween is running")

	_tap(p, r, c)
	t.eq(p._grid[r][c], -1, "third tap empties the cell")
	t.check(is_equal_approx(p._target_angle(r, c), -TAU), "third roll completes the turn rather than unwinding")

## A tap ripples through the neighbours: the side cells dip and return a
## beat later, the diagonals half as deep and later still. A rolling cell is
## skipped, so no cell ever runs two height tweens.
static func _test_neighbour_bob(t, p) -> void:
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	var side := Vector2i(c + 1, r) if c + 1 < p.n else Vector2i(c - 1, r)
	var diag := Vector2i(side.x, r + 1) if r + 1 < p.n else Vector2i(side.x, r - 1)
	_tap(p, r, c)
	var sb: Tween = p._bobs[side.y][side.x]
	var db: Tween = p._bobs[diag.y][diag.x]
	t.check(Motion.running(sb), "a side neighbour bobs")
	t.check(Motion.running(db), "a diagonal neighbour bobs")
	t.check(p._bobs[r][c] == null, "the tapped cell itself does not bob; it rolls")
	sb.custom_step(p.BOB_LAG + p.BOB_TIME * 0.5)
	db.custom_step(p.BOB_LAG_DIAG + p.BOB_TIME * 0.5)
	var side_y: float = p._cells[side.y][side.x].position.y
	var diag_y: float = p._cells[diag.y][diag.x].position.y
	t.check(side_y < p._rest_y - 0.015, "at its deepest the side neighbour is down %.3f" % (p._rest_y - side_y))
	t.check(diag_y < p._rest_y and diag_y > side_y, "the diagonal dips, but half as far (%.3f)" % (p._rest_y - diag_y))
	sb.custom_step(p.BOB_TIME)
	db.custom_step(p.BOB_TIME)
	t.check(is_equal_approx(p._cells[side.y][side.x].position.y, p._rest_y), "the side neighbour returns to rest")
	t.check(is_equal_approx(p._cells[diag.y][diag.x].position.y, p._rest_y), "the diagonal returns to rest")
	# Tidy: land the roll so later tests start from a resting board.
	p._settle(r, c)
	# Tidy: this test and _test_tap_rolls both tap _find_cell(p, false), the
	# same deterministic cell, so the focus ring is left shown (mid-pop) on
	# it. Put it back to its unshown, freshly-built state so the focus-ring
	# test below starts from "no tap yet".
	Motion.stop(p._ring_tw)
	Motion.stop(p._ring_pulse)
	Motion.stop(p._ring_hold)
	p._ring.visible = false
	p._ring.scale = Vector3.ONE
	p._ring_mat.albedo_color.a = p.FOCUS_ALPHA
	p.focus_cell = Vector2i(-1, -1)

## The focus ring (polish spec, section 2): it pops onto the first tapped
## cell, slides to the next, pulses while shown, and fades after a pause.
## Given cells take the focus too, since "look at this line" is a gesture.
static func _test_focus_ring(t, p) -> void:
	var a := _find_cell(p, false)
	var g := _find_cell(p, true)
	var ring: Node3D = p._ring
	t.check(ring != null and ring.get_parent() == p.board and not ring.visible, "the ring exists, under the board, hidden at first")
	t.check(p.focus_cell == Vector2i(-1, -1), "no focus before the first tap")
	_tap(p, a.y, a.x)
	t.check(p.focus_cell == Vector2i(a.x, a.y), "focus_cell is the tapped cell as (col, row)")
	var want := BoardMath.cell_center(a.y, a.x, p.n, p.n, Placeholders.TILE_RISE + 0.005)
	t.check(ring.visible and ring.position.is_equal_approx(want), "the ring shows on the tapped cell (%s)" % ring.position)
	t.check(Motion.running(p._ring_tw), "the ring pops in")
	p._ring_tw.custom_step(p.FOCUS_POP)
	t.check(ring.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(p._ring_mat.albedo_color.a, p.FOCUS_ALPHA), "the pop ends at full size and alpha")
	t.check(Motion.running(p._ring_pulse), "the ring pulses once shown")
	t.check(Motion.running(p._ring_hold), "the hold timer is running")
	_tap(p, g.y, g.x)
	t.check(p.focus_cell == Vector2i(g.x, g.y), "a tap on a given cell takes the focus")
	t.check(p._grid[g.y][g.x] != -1 and p._rolls[g.y][g.x] == null, "and rolls nothing")
	t.check(Motion.running(p._ring_tw), "the ring slides")
	p._ring_tw.custom_step(p.FOCUS_MOVE)
	var want_g := BoardMath.cell_center(g.y, g.x, p.n, p.n, Placeholders.TILE_RISE + 0.005)
	t.check(ring.position.is_equal_approx(want_g), "the slide lands on the given cell")
	t.check(Motion.running(p._ring_pulse), "the pulse keeps going through a slide")
	p._ring_hold.custom_step(p.FOCUS_HOLD + 0.01)
	t.check(Motion.running(p._ring_tw) and not Motion.running(p._ring_pulse), "after the hold the ring fades and stops pulsing")
	p._ring_tw.custom_step(p.FOCUS_FADE + 0.01)
	t.check(not ring.visible, "the faded ring hides")
	t.check(is_zero_approx(p._ring_mat.albedo_color.a), "the fade ends fully clear")
	# Tidy for later tests.
	p._settle(a.y, a.x)
	p._focus_clear()

## Blush (polish spec, section 2): a newly broken line fades to the rose
## blend with two heartbeats past it, a fixed line fades back, and every
## level sits on the 16-step grid so the material cache stays bounded.
static func _test_blush_pulse(t, p) -> void:
	var saved: Array = (p._grid[0] as Array).duplicate()
	for c in 3:
		p._grid[0][c] = 0
	p._recolour()
	var base := Pal.STONE_GIVEN if p._given[0][0] else Pal.STONE
	var fade: Tween = p._fades[0][0]
	t.check(Motion.running(fade), "a broken row starts a blush fade on its cells")
	t.check(is_equal_approx(p._blend_target[0][0], p.BAD_BLEND), "the cell heads for BAD_BLEND")
	fade.custom_step(p.BLUSH_IN)
	t.check(is_equal_approx(p._blend[0][0], p.BAD_BLEND), "after the fade in the cell sits on BAD_BLEND (%.3f)" % p._blend[0][0])
	fade.custom_step(p.BLUSH_BEATS * 0.25)
	t.check(p._blend[0][0] > p.BAD_BLEND, "a heartbeat pushes past the blend (%.3f)" % p._blend[0][0])
	t.check(is_equal_approx(p._blend[0][0] * p.BLUSH_STEPS, roundf(p._blend[0][0] * p.BLUSH_STEPS)), "mid-beat the blend is on the 16-step grid")
	fade.custom_step(p.BLUSH_BEATS)
	t.check(not Motion.running(fade), "the blush comes to rest")
	var blushed := _face_colour(p, 0, 0, "Face_Empty")
	t.check(blushed.is_equal_approx(base.lerp(Pal.BAD, p.BAD_BLEND)), "at rest the face is exactly the blushed stone (%s)" % blushed.to_html(false))
	for c in p.n:
		if Motion.running(p._fades[0][c]):
			p._fades[0][c].custom_step(5.0)
	p._grid[0] = saved
	p._recolour()
	var out: Tween = p._fades[0][0]
	t.check(Motion.running(out), "fixing the row fades the blush out")
	out.custom_step(p.BLUSH_OUT * 0.5)
	t.check(p._blend[0][0] > 0.0 and p._blend[0][0] < p.BAD_BLEND, "halfway out the blush is partway (%.3f)" % p._blend[0][0])
	out.custom_step(p.BLUSH_OUT)
	t.check(is_zero_approx(p._blend[0][0]), "the fade out ends at no blush")
	t.check(_face_colour(p, 0, 0, "Face_Empty").is_equal_approx(base), "the face is exactly its stone again")
	for r in p.n:
		for c in p.n:
			if Motion.running(p._fades[r][c]):
				p._fades[r][c].custom_step(5.0)

static func _test_locked_cell(t, p) -> void:
	var cell := _find_cell(p, true)
	var r := cell.y
	var c := cell.x
	var before: int = p._grid[r][c]
	var angle: float = p._cells[r][c].rotation.x
	_tap(p, r, c)
	t.eq(p._grid[r][c], before, "tapping a given cell changes nothing")
	t.check(p._rolls[r][c] == null and is_equal_approx(p._cells[r][c].rotation.x, angle), "a given cell never rolls")
	t.check(Motion.running(p._bobs[r][c]), "a given cell answers a tap with a dip")
	p._bobs[r][c].custom_step(p.BOB_TIME * 0.5)
	t.check(p._cells[r][c].position.y < p._rest_y, "the dip goes down")
	p._bobs[r][c].custom_step(p.BOB_TIME)
	t.check(is_equal_approx(p._cells[r][c].position.y, p._rest_y), "the dip returns to rest")

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
