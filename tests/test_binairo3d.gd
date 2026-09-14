extends RefCounted

## Binairo on the stage: every cell is a cube on a pivot through its centre,
## standing on the platform. Its six faces carry empty, sun and moon twice
## each, on opposite pairs -- modelled into the cube, not placed on it -- so a
## tap rolls the cube a quarter turn, about X, then Z, then X, and the next
## state is always one turn away.
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

const QUARTER := TAU / 4.0

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	# A throwaway path: nothing in this suite should touch the developer's
	# real user://settings.cfg.
	Motion.settings_path = "user://_test_settings.cfg"
	var stage: Node3D = Stage.new()
	root.add_child(stage)
	# This suite steps decorative tweens by hand (bobs, fades, the ring); under
	# reduce those recipes return null, so pin it false regardless of settings.
	Motion.reduce = false
	var p = Binairo3D.new()
	root.add_child(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	p.build(rng, 0)

	_test_entrance(t, p)
	_test_platform_under_board(t, p)
	_test_cube_geometry(t, p)
	_test_faces_carry_symbols(t, p)
	_test_cube_colours(t, p)
	_test_tap_rolls(t, p)
	_test_neighbour_bob(t, p)
	_test_focus_ring(t, p)
	_test_blush_pulse(t, p)
	_test_locked_cell(t, p)
	_test_reset_wave(t, p)
	_test_solved_wave(t, p)
	_test_rebuild_kills_fades(t, p)

	root.remove_child(p)
	p.free()
	root.remove_child(stage)
	stage.free()
	Motion.settings_path = "user://settings.cfg"
	Motion.reduce = false

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

## The board arrives (polish spec, section 2): the platform rises from below,
## then the prisms pop in along a diagonal wave from the far-left corner.
## Stepping every entrance tween to its end leaves a resting board.
static func _test_entrance(t, p) -> void:
	var platform: Node3D = p.board.get_node("Platform")
	t.check(is_equal_approx(platform.position.y, -p.ENTER_DROP), "the platform starts below the surface (%.2f)" % platform.position.y)
	t.check(p._cells[0][0].scale.x < 0.05, "the prisms start tiny")
	t.check(p._entrance.size() >= p.n * p.n + 1, "one entrance tween per prism plus the platform (%d)" % p._entrance.size())
	# The far-left prism pops first, the near-right one last.
	var first_pop: float = p.ENTER_PLATFORM + Motion.stagger(0, p.ENTER_STAGGER)
	var last_pop: float = p.ENTER_PLATFORM + Motion.stagger(2 * (p.n - 1), p.ENTER_STAGGER)
	for tw in p._entrance:
		tw.custom_step(first_pop + p.ENTER_POP * 0.5)
	t.check(p._cells[0][0].scale.x > 0.5, "half a pop after the platform lands, the far-left prism is well on its way (%.2f)" % p._cells[0][0].scale.x)
	t.check(p._cells[p.n - 1][p.n - 1].scale.x < 0.05, "the near-right prism has not started (%.2f)" % p._cells[p.n - 1][p.n - 1].scale.x)
	t.check(is_equal_approx(platform.position.y, 0.0), "the platform has landed")
	for tw in p._entrance:
		tw.custom_step(last_pop + p.ENTER_POP + 1.0)
	var all_home := true
	for r in p.n:
		for c in p.n:
			if not p._cells[r][c].scale.is_equal_approx(Vector3.ONE):
				all_home = false
	t.check(all_home, "every cube ends at scale one")
	t.eq(p.fx.last_cue, "enter", "the entrance fires its cue")

static func _test_platform_under_board(t, p) -> void:
	var platform: Node = p.board.get_node_or_null("Platform")
	t.check(platform != null and platform.get_node_or_null("Slab") != null, "board carries a Platform with a Slab")
	t.check(platform != null and platform.get_child_count() == 1 + 4 * p.n + 4, "platform has a full moss rim")

static func _test_cube_geometry(t, p) -> void:
	# The cube stands on the platform: its top face is TILE_RISE (a full side)
	# above it and is the tap plane, its base sits on the platform with
	# nothing hanging below, and the pivot is its centre, half a side down.
	# This is the whole point of the cube -- a trilon buried in the stone
	# showed only its horizontal top face at the camera's 68-degree pitch.
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
	t.check(absf(hi - Placeholders.TILE_RISE) < 0.005, "top face rests at y=%.2f (got %.3f)" % [Placeholders.TILE_RISE, hi])
	t.check(absf(lo) < 0.02, "the cube stands on the platform rather than inside it (min y %.3f)" % lo)
	t.check(absf((hi - lo) - Placeholders.TILE_SIDE) < 0.02, "and shows a full side of wall (%.3f)" % (hi - lo))
	t.check(is_equal_approx(p.plane_height(), Placeholders.TILE_RISE), "taps land on the top face")
	var centre := BoardMath.cell_center(cell.y, cell.x, p.n, p.n, Placeholders.TILE_RISE - Placeholders.TILE_HALF)
	t.check(pivot.position.is_equal_approx(centre), "pivot sits at the cube's centre (%s vs %s)" % [pivot.position, centre])

## Every vertex of the layers under `root` whose imported material is `name`,
## in root space. Models.meshes leaves the outline shells out.
static func _layer_points(root: Node3D, name: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in Models.meshes(root):
		var src := mi.mesh.surface_get_material(0)
		if src == null or src.resource_name != name:
			continue
		for v in mi.mesh.get_faces():
			out.append(mi.transform * v)
	return out

## The sun and the moon are modelled into the cube itself (art/tile.blend),
## inlaid on opposite pairs of faces the way a die carries its pips: the sun on
## the near and far faces, the moon on the left and right, the top and bottom
## bare for the empty state. Face f is the one up after f quarter turns, so
## rolling the cube to _orient(f) has to bring face f's symbol out flat on top,
## and nothing else with it. That invariant is what lets every tap be a single
## quarter turn, and it is now a property of the model rather than of code.
static func _test_faces_carry_symbols(t, p) -> void:
	var cell := _find_cell(p, false)
	var tile: Node3D = p._tiles[cell.y][cell.x]
	t.eq(Models.surface_names(tile), ["Stone", "Sun", "Moon"],
		"the tile is one mesh per layer: the stone body, the sun, the moon")
	var half := Placeholders.TILE_HALF
	var centre := Vector3(0.0, half, 0.0)
	var want := half + Placeholders.EMBLEM_PROUD
	var sun := _layer_points(tile, "Sun")
	var moon := _layer_points(tile, "Moon")
	t.check(sun.size() > 0 and moon.size() > 0, "both symbols are carried by the model")
	var upright := true
	var bare := true
	for f in p.FACES:
		var orient: Basis = p._orient(f)
		var sun_top := -INF
		for v in sun:
			sun_top = maxf(sun_top, (orient * (v - centre)).y)
		var moon_top := -INF
		for v in moon:
			moon_top = maxf(moon_top, (orient * (v - centre)).y)
		var up := sun_top if posmod(f, 3) == 1 else moon_top
		var down := moon_top if posmod(f, 3) == 1 else sun_top
		if posmod(f, 3) == 0:
			# An empty face: bare stone up top, both symbols down on the walls.
			if maxf(sun_top, moon_top) > half - 0.05:
				bare = false
		elif absf(up - want) > 0.003 or down > half - 0.05:
			upright = false
	t.check(upright, "each symbol comes out flat on top, %.3f proud, when the cube rolls to its face" % Placeholders.EMBLEM_PROUD)
	t.check(bare, "and an empty face is bare stone, with both symbols down on the walls")

static func _cube_colour(p, r: int, c: int) -> Color:
	var mi: MeshInstance3D = Models.meshes(p._tiles[r][c])[0]
	return Color(mi.get_surface_override_material(0).get_shader_parameter("albedo"))

static func _test_cube_colours(t, p) -> void:
	# The whole cube takes the colour of the state that is up, not one face:
	# a cube that rotates cannot hold a colour on a face, since a moon face
	# lands on the front wall while an empty face is up (amendment C).
	var blend: float = p.BAD_BLEND
	var free := _find_cell(p, false)
	var empty := _cube_colour(p, free.y, free.x)
	t.check(p._grid[free.y][free.x] == -1, "setup: the free cell is empty")
	t.check(empty.is_equal_approx(Pal.STONE) or empty.is_equal_approx(Pal.STONE.lerp(Pal.BAD, blend)),
		"an empty cell is stone (got %s)" % empty.to_html(false))
	var locked := _find_cell(p, true)
	var given := _cube_colour(p, locked.y, locked.x)
	var moon: bool = p._grid[locked.y][locked.x] == 1
	var want: Color = (Pal.SLATE_GIVEN if moon else Pal.STONE_GIVEN)
	t.check(given.is_equal_approx(want) or given.is_equal_approx(want.lerp(Pal.BAD, blend)),
		"a given cell is the darker %s (got %s)" % ["slate" if moon else "stone", given.to_html(false)])

static func _test_tap_rolls(t, p) -> void:
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	var spin: Node3D = p._spins[r][c]
	t.check(p._grid[r][c] == -1 and spin.basis.is_equal_approx(Basis.IDENTITY), "cell starts empty with face 0 up")
	_tap(p, r, c)
	t.eq(p._grid[r][c], 0, "tap sets the grid to sun at once")
	t.check(spin.basis.is_equal_approx(Basis.IDENTITY), "the cube has not moved before the roll's first frame")
	var first: Tween = p._rolls[r][c]
	t.check(first != null and first.is_running(), "a roll tween is running")
	t.check(p._target_basis(r, c).is_equal_approx(Basis(Vector3.RIGHT, QUARTER)),
		"roll target is one quarter turn toward the player")

	# Drive the roll to its end. The back ease is already overshooting at the
	# half, so the between-faces check steps a quarter.
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(spin.basis.y.z > 0.1 and spin.basis.y.y > 0.1, "a quarter in, the cube is between faces (up %s)" % spin.basis.y)
	t.check(spin.position.y > 0.01, "and has lifted onto the edge it pivots on (%.3f)" % spin.position.y)
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(spin.basis.y.y < -0.001, "halfway, the cube has rolled past the face and is springing back (up %s)" % spin.basis.y)
	first.custom_step(p.ROLL_TIME)
	t.check(spin.basis.is_equal_approx(Basis(Vector3.RIGHT, QUARTER)), "the roll lands exactly on the sun face")
	t.check(is_equal_approx(spin.position.y, 0.0), "and back down flat on the platform (%.4f)" % spin.position.y)
	t.check(not first.is_running(), "the roll tween finished")
	t.check(_cube_colour(p, r, c).is_equal_approx(Pal.STONE), "a sun leaves the cube stone")
	t.eq(p.fx.last_cue, "land", "landing fires the land cue and its dust")

	_tap(p, r, c)
	t.eq(p._grid[r][c], 1, "second tap sets the grid to moon")
	t.check(is_equal_approx(p._rolls[r][c].get_total_elapsed_time(), 0.0) or p._rolls[r][c] != first, "a finished roll is left alone by settle")
	t.check(not first.is_valid() or not first.is_running(), "first roll is no longer running")
	t.check(p._target_basis(r, c).is_equal_approx(p._orient(2)), "the second roll turns about Z, the next axis round")
	var second: Tween = p._rolls[r][c]
	t.check(second != null and second != first and second.is_running(), "a new roll tween is running")
	second.custom_step(p.ROLL_TIME * 2.0)
	t.check(_cube_colour(p, r, c).is_equal_approx(Pal.SLATE), "a moon turns the whole cube slate")

	_tap(p, r, c)
	t.eq(p._grid[r][c], -1, "third tap empties the cell")
	t.check(p._target_basis(r, c).is_equal_approx(p._orient(3)), "the third roll rolls on rather than unwinding")
	t.check(not p._orient(3).is_equal_approx(Basis.IDENTITY), "and lands on the cube's other empty face")
	t.check(p._orient(p.FACES).is_equal_approx(Basis.IDENTITY), "six quarter turns come back to where the cube started")
	p._settle(r, c)

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
	Motion.stop(p._ring_pulse_a)
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
	var blushed := _cube_colour(p, 0, 0)
	t.check(blushed.is_equal_approx(base.lerp(Pal.BAD, p.BAD_BLEND)), "at rest the cube is exactly the blushed stone (%s)" % blushed.to_html(false))
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
	# The cell is back to whatever the puzzle gave it, so the base it returns
	# to is that state's colour, not necessarily the sun's stone.
	var moon: bool = p._grid[0][0] == 1
	var locked: bool = p._given[0][0]
	var rest: Color
	if moon:
		rest = Pal.SLATE_GIVEN if locked else Pal.SLATE
	else:
		rest = Pal.STONE_GIVEN if locked else Pal.STONE
	t.check(_cube_colour(p, 0, 0).is_equal_approx(rest), "the cube is exactly its resting stone again")
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

## Reset rolls every filled free cell forward to empty in a wave from the
## near-left corner and gives the givens a little hop; the grid clears at once.
static func _test_reset_wave(t, p) -> void:
	var free := _find_cell(p, false)
	# Earlier tests have rolled this cell an unknown number of times; tap it
	# round to a sun so the two-thirds roll is what reset has to do.
	var guard := 0
	while p._grid[free.y][free.x] != 0 and guard < 3:
		_tap(p, free.y, free.x)
		p._settle(free.y, free.x)
		guard += 1
	t.eq(p._grid[free.y][free.x], 0, "setup: a sun is placed")
	var turns_before: int = p._turns[free.y][free.x]
	var given := _find_cell(p, true)
	p.reset_board()
	t.eq(p._grid[free.y][free.x], -1, "reset clears the grid at once")
	t.eq(p.moves, 0, "reset zeroes the move count")
	t.check(p.focus_cell == Vector2i(-1, -1), "reset drops the focus")
	t.check(Motion.running(p._rolls[free.y][free.x]), "the placed cell rolls home")
	t.check(Motion.running(p._bobs[given.y][given.x]), "a given hops to say it stays")
	t.eq(p._turns[free.y][free.x], turns_before + 2, "a sun rolls two more quarters forward to reach empty, never back")
	t.eq(p._turns[free.y][free.x] % 3, 0, "and lands on an empty face")
	for r in p.n:
		for c in p.n:
			for tw in [p._rolls[r][c], p._bobs[r][c]]:
				if Motion.running(tw):
					tw.custom_step(5.0)
	var all_home := true
	var none_running := true
	for r in p.n:
		for c in p.n:
			var pivot: Node3D = p._cells[r][c]
			var spin: Node3D = p._spins[r][c]
			var state: int = p._grid[r][c]
			if posmod(p._turns[r][c], 3) != p.FACE[state]:
				all_home = false
			if not spin.basis.is_equal_approx(p._orient(p._turns[r][c])):
				all_home = false
			if not is_equal_approx(spin.position.y, 0.0) or not is_equal_approx(pivot.position.y, p._rest_y):
				all_home = false
			for tw in [p._rolls[r][c], p._bobs[r][c]]:
				if Motion.running(tw):
					none_running = false
	t.check(all_home, "after the wave every cube shows its grid face and rests flat on the platform")
	t.check(none_running, "the wave leaves nothing running")
	if Motion.running(p._ring_tw):
		p._ring_tw.custom_step(5.0)
	t.check(not p._ring.visible, "reset hides the ring")

## On a solve every prism hops once, row by row from the far edge, after the
## last roll has had time to land.
static func _test_solved_wave(t, p) -> void:
	for r in p.n:
		for c in p.n:
			p._grid[r][c] = p._solution[r][c]
	p.note_move()
	t.check(p.is_done(), "setup: the board is solved")
	t.check(Motion.running(p._bobs[0][0]) and Motion.running(p._bobs[p.n - 1][p.n - 1]), "every prism has a solve hop scheduled")
	p._bobs[0][0].custom_step(p.ROLL_TIME + p.SOLVE_TIME * 0.5)
	p._bobs[p.n - 1][0].custom_step(p.ROLL_TIME + p.SOLVE_TIME * 0.5)
	t.check(p._cells[0][0].position.y > p._rest_y + 0.05, "the far row is up first (%.3f)" % (p._cells[0][0].position.y - p._rest_y))
	t.check(p._cells[p.n - 1][0].position.y < p._cells[0][0].position.y, "the near row lags behind")
	for r in p.n:
		for c in p.n:
			if Motion.running(p._bobs[r][c]):
				p._bobs[r][c].custom_step(5.0)
	var rested := true
	for r in p.n:
		for c in p.n:
			if not is_equal_approx(p._cells[r][c].position.y, p._rest_y):
				rested = false
	t.check(rested, "after the wave every prism rests on its axis")
	t.eq(p.fx.last_cue, "solved", "the solve fires its cue")

## A second build() on the same board must not inherit the first board's
## blush fades: they used to live on `board`, which a rebuild keeps, and
## repainted the new tiles. Now they live on the tile and the rebuild kills
## everything it still tracks.
static func _test_rebuild_kills_fades(t, p) -> void:
	var saved: Array = (p._grid[0] as Array).duplicate()
	for c in 3:
		p._grid[0][c] = 0
	p._recolour()
	var old: Tween = p._fades[0][0]
	t.check(Motion.running(old), "setup: a blush fade is running on the old board")
	p._grid[0] = saved
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	p.build(rng, 0)
	t.check(not Motion.running(old), "the rebuild killed the old fade")
	for tw in p._entrance:
		tw.custom_step(5.0)
	t.check(is_zero_approx(p._blend[0][0]) and is_zero_approx(p._blend_target[0][0]), "the new board starts unblushed (%.3f)" % p._blend[0][0])
	var any_running := false
	for r in p.n:
		for c in p.n:
			if Motion.running(p._fades[r][c]):
				any_running = true
	t.check(not any_running, "no fade runs on a fresh board")
