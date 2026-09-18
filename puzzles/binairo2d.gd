extends "res://core/puzzle_base.gd"

## Binairo as a flat board: a square of rounded tiles on the host's parchment
## card, each carrying an illustrated sun or moon with a face. Built beside
## the island version (puzzles/binairo3d.gd) so the two can be judged against
## each other on the phone; the rules live in puzzles/binairo_state.gd, which
## this only draws. A tap cycles empty, sun, moon; the host's palette arms a
## brush through set_brush() and cells then take that symbol. Every motion
## goes through core/motion.gd, so reduce-motion stills the decoration and
## keeps the change of symbol.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, sections
## 4 to 6 and 9.2, as amended after the mock (docs/brainstorm/concepts.html#binairo).

const Gen = preload("res://puzzles/binairo_gen.gd")
const State = preload("res://puzzles/binairo_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

## Layout, in the board card's inner pixels (spec section 4).
const PAD := 28.0
const GAP := 12.0
const TILE_RADIUS := 18
const TILE_EDGE := 4
## Face sizes as a fraction of the tile: the sun's rays reach 1.55 R, so its
## Control is 2 * 1.55 * 0.26 of the tile; the moon's disc is its own radius.
const SUN_SIZE := 0.26 * 2.0 * 1.55
const MOON_SIZE := 0.34 * 2.0
## Hint count, not refunded by reset (HUD spec, section 3).
const HINTS := 3
## Timings (spec section 6).
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.03
const ENTER_FACE_LAG := 0.12
const PRESS_SCALE := 0.94
const PRESS_TIME := 0.08
const RELEASE_TIME := 0.25
const FACE_OUT := 0.12
const FACE_IN_LAG := 0.08
const FACE_IN := 0.22
const FACE_SQUASH := 0.15
const HOP := -6.0
const HOP_TIME := 0.3
const DIP := 4.0
const NUDGE := 3.0
const NUDGE_TIME := 0.3
const NUDGE_LAG := 0.04
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const BLUSH_BEAT := 0.2
const BLUSH_BEAT_EXTRA := 0.33
const LINE_HOP := -8.0
const LINE_HOP_TIME := 0.35
const LINE_STAGGER := 0.03
const JOY_TIME := 0.6
const HINT_DROP := 40.0
const HINT_DROP_TIME := 0.3
const RING_TIME := 0.5
const CHECK_FLASH := 0.6
const CHECK_IN := 0.15
const CHECK_OUT := 0.45
const RESET_STAGGER := 0.02
const RESET_HOP := -4.0
const SOLVE_HOP := -10.0
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04
const SOLVE_DELAY := 0.25
const FOCUS_IN := 0.12
const FOCUS_HOLD := 1.5
const FOCUS_OUT := 0.4
const FOCUS_ALPHA := 0.12
## About a third of the moons rock; which ones is fixed per cell.
const ROCK_SHARE := 0.34

## The armed brush: -2 none (taps cycle), -1 clear, 0 sun, 1 moon.
var brush: int = -2
signal brush_changed
## The last tapped cell as (col, row); (-1, -1) before the first tap.
var focus_cell := Vector2i(-1, -1)

var state = State.new()
var n: int:
	get: return state.n
## The win harness and the animation probe read these off the island board;
## they are the state's arrays under the same names.
var _given: Array:
	get: return state.given
var _solution: Array:
	get: return state.solution

var fx: Node2D
var _tiles: Array = []      # [r][c] -> Panel
var _styles: Array = []     # [r][c] -> its StyleBoxFlat
var _tints: Array = []      # [r][c] -> the focus tint Panel over the tile
var _faces: Array = []      # [r][c] -> Face or null
var _blend: Array = []      # [r][c] -> painted blend toward BAD_TILE
var _blend_target: Array = []
var _fades: Array = []
var _hops: Array = []
var _scales: Array = []     # [r][c] -> the press or release tween
var _joy_until: Array = []  # [r][c] -> msec until which the face beams
var _entrance: Array = []
var _focus_tw: Tween
var _touch := Vector2i(-1, -1)
var _tile := 0.0
var _origin := Vector2.ZERO

func puzzle_id() -> String: return "binairo"
func title() -> String: return "Binairo"

func rules() -> String:
	return "Fill every cell with a sun or a moon. Never three alike in a line. Every line has an equal count of each, and no two lines are identical."

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	# Over the tiles, which are added after it: stars land on the board, not under it.
	fx.z_index = 1
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var size := 6
	var min_clues := 0
	match difficulty:
		0: size = 6; min_clues = 16
		1: size = 6; min_clues = 0
		_: size = 8; min_clues = 0
	state.setup(Gen.generate(rng, size, min_clues))
	brush = -2
	focus_cell = Vector2i(-1, -1)
	_build_tiles()
	_layout()
	_recolour(false)
	_enter()

# --- the grid ---

func _build_tiles() -> void:
	_stop_all()
	for row in _tiles:
		for t in row:
			t.queue_free()
	_tiles = []
	_styles = []
	_tints = []
	_faces = []
	_blend = []
	_blend_target = []
	_fades = []
	_hops = []
	_scales = []
	_joy_until = []
	for r in n:
		var tiles := []
		var styles := []
		var tints := []
		var faces := []
		for c in n:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(TILE_RADIUS)
			sb.border_width_bottom = TILE_EDGE
			var tile := Panel.new()
			tile.name = "tile_%d_%d" % [r, c]
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_theme_stylebox_override("panel", sb)
			add_child(tile)
			# CozyTheme.dress() hands every Panel the HUD's paper wash as it enters
			# the tree; on a tile that small the wash reads as a blotch, and a
			# board of them as a stain. The tiles stay flat.
			tile.material = null
			# The focus tint over the tile, the symbol's colour at a few percent,
			# shown for a moment on the tapped cell's row and column.
			var tint := Panel.new()
			tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tsb := StyleBoxFlat.new()
			tsb.set_corner_radius_all(TILE_RADIUS)
			tsb.bg_color = Pal.LINE
			tint.add_theme_stylebox_override("panel", tsb)
			tint.modulate.a = 0.0
			tile.add_child(tint)
			tint.material = null
			tiles.append(tile)
			styles.append(sb)
			tints.append(tint)
			faces.append(null)
		_tiles.append(tiles)
		_styles.append(styles)
		_tints.append(tints)
		_faces.append(faces)
		_blend.append(_zeros())
		_blend_target.append(_zeros())
		_fades.append(_nulls())
		_hops.append(_nulls())
		_scales.append(_nulls())
		_joy_until.append(_zeros())
	for r in n:
		for c in n:
			_paint(0.0, r, c)
			if state.grid[r][c] != -1:
				_faces[r][c] = _make_face(r, c, state.grid[r][c])

func _zeros() -> Array:
	var row := []
	for c in n:
		row.append(0.0)
	return row

func _nulls() -> Array:
	var row := []
	for c in n:
		row.append(null)
	return row

## The grid is the square of the shorter side less the padding, centred.
func _layout() -> void:
	if _tiles.is_empty():
		return
	var g := minf(size.x, size.y) - 2.0 * PAD
	_tile = (g - (n - 1) * GAP) / n
	if _tile <= 0.0:
		return
	_origin = (size - Vector2(g, g)) * 0.5
	for r in n:
		for c in n:
			var tile: Panel = _tiles[r][c]
			tile.position = _origin + Vector2(c, r) * (_tile + GAP)
			tile.size = Vector2(_tile, _tile)
			tile.pivot_offset = tile.size * 0.5
			var tint: Panel = _tints[r][c]
			tint.position = Vector2.ZERO
			tint.size = Vector2(_tile, _tile - TILE_EDGE)
			var face: Control = _faces[r][c]
			if face != null:
				_fit_face(face, state.grid[r][c])

## Sizes a face for the current tile and centres it, a touch high so the
## tile's bottom edge does not crowd it.
func _fit_face(face: Control, v: int) -> void:
	var s := _tile * (SUN_SIZE if v == 0 else MOON_SIZE)
	face.size = Vector2(s, s)
	face.pivot_offset = face.size * 0.5
	face.position = (Vector2(_tile, _tile - TILE_EDGE) - face.size) * 0.5

## A new face for cell (r, c) showing `v`, parented to its tile, idling.
func _make_face(r: int, c: int, v: int) -> Control:
	var face: Control
	if v == 0:
		face = SunFace.new()
	else:
		face = MoonFace.new()
		face.rocks = _hash(r, c) < ROCK_SHARE
	face.name = "face"
	_tiles[r][c].add_child(face)
	if _tile > 0.0:
		_fit_face(face, v)
	face.expression = _expression(r, c)
	face.set_idle(true)
	return face

## A fixed pseudo-random number per cell, for which moons rock.
static func _hash(r: int, c: int) -> float:
	return float(posmod(hash(Vector2i(r, c)), 1000)) / 1000.0

## Control-local point over the centre of cell (r, c). The win harness taps
## this; it is the flat counterpart of the island board's.
func cell_to_local(r: int, c: int) -> Vector2:
	return _origin + Vector2(c, r) * (_tile + GAP) + Vector2(_tile, _tile) * 0.5

## The cell under a control-local point, as (col, row), or (-1, -1) between
## tiles and off the grid.
func _cell_at(local: Vector2) -> Vector2i:
	if _tile <= 0.0:
		return Vector2i(-1, -1)
	var p := local - _origin
	var step := _tile + GAP
	var c := int(floor(p.x / step))
	var r := int(floor(p.y / step))
	if c < 0 or r < 0 or c >= n or r >= n:
		return Vector2i(-1, -1)
	# The gap belongs to the nearer tile: a thumb is never that precise.
	return Vector2i(c, r)

# --- colour ---

## The tile's fill at a blend toward BAD_TILE: white for a free cell (the
## user dropped the mock's checker, 2026-09-18), sand for a given, and past 1
## the heartbeat pushes on toward BAD.
func _paint(blend: float, r: int, c: int) -> void:
	_blend[r][c] = blend
	var locked: bool = state.given[r][c]
	var base: Color = Pal.STONE_GIVEN if locked else Pal.SURFACE
	var fill: Color
	if blend <= 1.0:
		fill = base.lerp(Pal.BAD_TILE, blend)
	else:
		fill = Pal.BAD_TILE.lerp(Pal.BAD, minf(1.0, (blend - 1.0) * 0.5))
	var sb: StyleBoxFlat = _styles[r][c]
	sb.bg_color = fill
	sb.border_color = Pal.LINE if locked else Color(Pal.LINE, 0.5)

## Rule feedback. Cells whose line just broke blush with two heartbeats and
## shiver once, and their faces worry; cells whose line was fixed fade back.
## A cell already heading for the right blend is left alone.
func _recolour(animate := true) -> void:
	state.refresh_bad()
	for r in n:
		for c in n:
			var target := 1.0 if state.is_bad(r, c) else 0.0
			var face: Control = _faces[r][c]
			if face != null:
				face.expression = _expression(r, c)
			if is_equal_approx(_blend_target[r][c], target):
				continue
			_blend_target[r][c] = target
			Motion.stop(_fades[r][c])
			if not animate:
				_paint(target, r, c)
				_fades[r][c] = null
				continue
			var setter := _paint.bind(r, c)
			if target > _blend[r][c]:
				var tw: Tween = Motion.fade(self, setter, _blend[r][c], target, BLUSH_IN, 16)
				if tw != null:
					for i in 2:
						tw.tween_method(setter, target, target + BLUSH_BEAT_EXTRA, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
						tw.tween_method(setter, target + BLUSH_BEAT_EXTRA, target, BLUSH_BEAT * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_fades[r][c] = tw
				Motion.shiver(_tiles[r][c])
				fx.cue("blush_in")
			else:
				_fades[r][c] = Motion.fade(self, setter, _blend[r][c], target, BLUSH_OUT, 16)
				fx.cue("blush_out")

## What a face should show: joy while its celebration lasts, worry on a
## broken line, otherwise content.
func _expression(r: int, c: int) -> int:
	if Time.get_ticks_msec() < _joy_until[r][c]:
		return Face.Expr.JOY
	if state.is_bad(r, c):
		return Face.Expr.WORRIED
	return Face.Expr.HAPPY

## The faces of a completed clean line hop in a wave from the tapped cell and
## beam for a moment.
func _celebrate(cells: Array, r: int, c: int) -> void:
	if cells.is_empty():
		return
	for cell in cells:
		var rr: int = cell.y
		var cc: int = cell.x
		var delay := 0.1 + Motion.stagger(absi(rr - r) + absi(cc - c), LINE_STAGGER)
		_hop(rr, cc, LINE_HOP, LINE_HOP_TIME, delay)
		_beam(rr, cc, delay, JOY_TIME)
	fx.cue("line")

## Sets the face at (r, c) to JOY after `delay` for `time` seconds (INF to
## keep it), then back to what the state says.
func _beam(r: int, c: int, delay: float, time: float) -> void:
	var until := INF if is_inf(time) else float(Time.get_ticks_msec()) + (delay + time) * 1000.0
	_joy_until[r][c] = until
	var show := func() -> void:
		var face: Control = _faces[r][c]
		if face != null:
			face.expression = _expression(r, c)
	if delay <= 0.0:
		show.call()
	else:
		get_tree().create_timer(delay).timeout.connect(show)
	if not is_inf(time):
		get_tree().create_timer(delay + time).timeout.connect(show)

# --- faces coming and going ---

## The face at (r, c) leaves (shrinks with a quarter turn) and the face for
## `v` arrives (pops with squash and stretch), or drops from above when
## `drop` is set (a hint). Under reduce-motion both happen at once.
func _swap_face(r: int, c: int, v: int, delay := 0.0, drop := false) -> void:
	var old: Control = _faces[r][c]
	_faces[r][c] = null
	if old != null:
		old.set_idle(false)
		if Motion.reduce:
			old.queue_free()
		else:
			var out := old.create_tween().set_parallel(true)
			out.tween_property(old, "scale", Vector2.ZERO, FACE_OUT).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			out.tween_property(old, "rotation", PI * 0.5, FACE_OUT).set_delay(delay)
			out.chain().tween_callback(old.queue_free)
	if v == -1:
		return
	var face := _make_face(r, c, v)
	_faces[r][c] = face
	if Motion.reduce:
		return
	var rest := face.position
	var start := delay + FACE_IN_LAG
	if drop:
		face.position.y = rest.y - HINT_DROP
		face.modulate.a = 0.0
		var tw := face.create_tween().set_parallel(true)
		tw.tween_property(face, "position:y", rest.y, HINT_DROP_TIME).set_delay(start).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(face, "modulate:a", 1.0, 0.1).set_delay(start)
		return
	face.scale = Vector2.ZERO
	var tw := face.create_tween()
	tw.tween_property(face, "scale", Vector2(1.0 + FACE_SQUASH, 1.0 - FACE_SQUASH), FACE_IN * 0.6).set_delay(start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2.ONE, FACE_IN * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A hop (negative height lifts) on the tile, replacing any hop already on it.
func _hop(r: int, c: int, height: float, time: float, delay := 0.0) -> void:
	Motion.stop(_hops[r][c])
	var tile: Panel = _tiles[r][c]
	var rest := (_origin + Vector2(c, r) * (_tile + GAP)).y
	tile.position.y = rest
	_hops[r][c] = Motion.hop(tile, height, time, delay, rest)

## The four side neighbours nudge away from a tapped cell and come back.
func _nudge_neighbours(r: int, c: int) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var rr: int = r + d.y
		var cc: int = c + d.x
		if rr < 0 or cc < 0 or rr >= n or cc >= n:
			continue
		if Motion.reduce or Motion.running(_hops[rr][cc]):
			continue
		var tile: Panel = _tiles[rr][cc]
		var rest := _origin + Vector2(cc, rr) * (_tile + GAP)
		tile.position = rest
		var tw := tile.create_tween()
		tw.tween_property(tile, "position", rest + Vector2(d) * NUDGE, NUDGE_TIME * 0.5).set_delay(NUDGE_LAG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "position", rest, NUDGE_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_hops[rr][cc] = tw

## The press: the tile sinks under the finger and springs back on release.
func _press(r: int, c: int, down: bool) -> void:
	var tile: Panel = _tiles[r][c]
	Motion.stop(_scales[r][c])
	var tw := tile.create_tween()
	if down:
		tw.tween_property(tile, "scale", Vector2.ONE * PRESS_SCALE, PRESS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(tile, "scale", Vector2.ONE, RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scales[r][c] = tw

# --- focus ---

## The tapped cell's row and column take a tint of its symbol's colour for a
## moment, so the eye finds the lines a tap changed. Replaces the working-line
## card; line_state() still answers for anything that reads it.
func _focus(r: int, c: int) -> void:
	Motion.stop(_focus_tw)
	_set_focus_alpha(0.0)
	focus_cell = Vector2i(c, r)
	var v: int = state.grid[r][c]
	var colour: Color = Pal.SUN if v == 0 else (Pal.MOON_INK if v == 1 else Pal.LINE)
	for i in n:
		(_tints[r][i].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = colour
		(_tints[i][c].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = colour
	fx.cue("focus")
	focus_changed.emit()
	if Motion.reduce:
		return
	_focus_tw = create_tween()
	_focus_tw.tween_method(_set_focus_alpha, 0.0, FOCUS_ALPHA, FOCUS_IN)
	_focus_tw.tween_interval(FOCUS_HOLD)
	_focus_tw.tween_method(_set_focus_alpha, FOCUS_ALPHA, 0.0, FOCUS_OUT)

func _set_focus_alpha(a: float) -> void:
	if focus_cell.x < 0:
		return
	for i in n:
		_tints[focus_cell.y][i].modulate.a = a
		_tints[i][focus_cell.x].modulate.a = a

func _focus_clear() -> void:
	Motion.stop(_focus_tw)
	_set_focus_alpha(0.0)
	focus_cell = Vector2i(-1, -1)
	focus_changed.emit()

func line_state() -> Dictionary:
	return state.line_state(focus_cell)

## Which rule a line on the board breaks right now (0 none, 1 three alike, 2
## an uneven count, 3 two lines alike); the tip card names it.
func broken_rule() -> int:
	return state.broken_rule()

# --- input ---

## Touch events only, as StageView takes them: the viewport hands a control
## both the mouse event and the emulated touch, and two would fire twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var cell := _cell_at(event.position)
		if event.pressed:
			if is_done() or cell.x < 0:
				return
			_touch = cell
			_press(cell.y, cell.x, true)
		elif _touch.x >= 0:
			var was := _touch
			_touch = Vector2i(-1, -1)
			_press(was.y, was.x, false)
			if cell == was and not is_done():
				_tap(was.y, was.x)

## A tap on (r, c): cycles, or paints the armed brush. A given only dips.
func _tap(r: int, c: int) -> void:
	if state.given[r][c]:
		_hop(r, c, DIP, HOP_TIME)
		_focus(r, c)
		return
	var changed: bool
	if brush == -2:
		changed = state.cycle(r, c)
	else:
		changed = state.place(r, c, brush)
	if not changed:
		return
	var v: int = state.grid[r][c]
	_swap_face(r, c, v)
	_hop(r, c, HOP, HOP_TIME)
	_nudge_neighbours(r, c)
	if v != -1:
		fx.puff(cell_to_local(r, c), Pal.SUN if v == 0 else Pal.MOON_INK, 5)
	fx.cue("place" if v != -1 else "clear")
	_focus(r, c)
	_after_change(r, c)
	note_move()

## After any change at (r, c): the blush, the worried faces, a completed
## line's wave.
func _after_change(r: int, c: int) -> void:
	_recolour()
	if r >= 0:
		_celebrate(state.line_just_completed(r, c), r, c)

## The host's palette arms a brush; the same value again lets it go.
func set_brush(v: int) -> void:
	if is_done():
		return
	brush = -2 if brush == v else v
	fx.cue("brush")
	brush_changed.emit()

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Reverts the last tap: the current face leaves and the previous one pops
## back. Counts no move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var got: Vector3i = state.undo()
	var r := got.x
	var c := got.y
	_swap_face(r, c, got.z)
	_hop(r, c, HOP, HOP_TIME)
	fx.cue("undo")
	_focus(r, c)
	_after_change(r, c)
	moved.emit()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Fills one cell from the solution: a ring pulses, the face drops in with a
## bounce and sparkles, and the tile takes the given look. Counts no move but
## can finish the puzzle.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var cell: Vector2i = state.apply_hint()
	if cell.x < 0:
		return false
	var r := cell.y
	var c := cell.x
	_swap_face(r, c, state.grid[r][c], 0.0, true)
	_paint(_blend[r][c], r, c)
	_ring(r, c)
	var at := cell_to_local(r, c)
	for i in 6:
		fx.sparkle(at + Vector2(_hash(i, r) - 0.5, _hash(c, i) - 0.5) * _tile * 0.7)
	fx.cue("hint")
	hints_used += 1
	_focus(r, c)
	_after_change(r, c)
	moved.emit()
	check_solved()
	return true

## A ring that grows and fades over the hinted tile.
func _ring(r: int, c: int) -> void:
	if Motion.reduce:
		return
	var ring := Ring.new()
	ring.radius = _tile * 0.55
	ring.position = cell_to_local(r, c)
	add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "t", 1.0, RING_TIME)
	tw.tween_callback(ring.queue_free)

## Marks every filled free cell that differs from the solution with a wobble
## and a flash. Returns how many; solving stays automatic.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_cells()
	for cell in wrong:
		var r: int = cell.y
		var c: int = cell.x
		var tile: Panel = _tiles[r][c]
		tile.rotation = 0.0
		Motion.wobble2d(tile)
		_flash(r, c)
	fx.cue("check" if not wrong.is_empty() else "check_ok")
	return wrong.size()

## A quick blush toward the flash level and back to whatever the cell's line
## is heading for.
func _flash(r: int, c: int) -> void:
	Motion.stop(_fades[r][c])
	var setter := _paint.bind(r, c)
	var back: float = _blend_target[r][c]
	var tw: Tween = Motion.fade(self, setter, _blend[r][c], CHECK_FLASH, CHECK_IN, 16)
	if tw == null:
		setter.call(back)
		_fades[r][c] = null
		return
	tw.tween_method(setter, CHECK_FLASH, back, CHECK_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fades[r][c] = tw

## Reset as a wave from the bottom left: free faces shrink out, givens hop,
## a hint's cell goes back to the player, the brush is dropped.
func reset_board() -> void:
	_stop_entrance()
	_focus_clear()
	var unlocked := []
	for r in n:
		for c in n:
			if state.hinted[r][c]:
				unlocked.append(Vector2i(c, r))
	state.reset()
	for r in n:
		for c in n:
			var delay := Motion.stagger((n - 1 - r) + c, RESET_STAGGER)
			if state.given[r][c]:
				_hop(r, c, RESET_HOP, HOP_TIME, delay)
				continue
			if _faces[r][c] != null:
				_swap_face(r, c, -1, delay)
	for cell in unlocked:
		_paint(_blend[cell.y][cell.x], cell.y, cell.x)
	brush = -2
	brush_changed.emit()
	moves = 0
	_recolour()
	fx.cue("reset")

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

## Every face hops along the diagonal and beams for good, with sparkles over
## the board. The host brings the win screen in after this wave.
func _on_solved() -> void:
	_focus_clear()
	brush = -2
	brush_changed.emit()
	for r in n:
		for c in n:
			var delay := SOLVE_DELAY + Motion.stagger(r + c, SOLVE_STAGGER)
			_hop(r, c, SOLVE_HOP, SOLVE_TIME, delay)
			_beam(r, c, delay, INF)
	if not Motion.reduce:
		var g := _tile * n + GAP * (n - 1)
		for i in 16:
			var at := _origin + Vector2(_hash(i, 1), _hash(i, 2)) * g
			get_tree().create_timer(0.2 + _hash(i, 3) * 0.7).timeout.connect(func() -> void:
				if is_instance_valid(fx):
					fx.sparkle(at))
	fx.cue("solved")

# --- entrance ---

## The board arrives: tiles pop in along the diagonal from the top left, and
## a given's face lands a beat after its tile with a squash.
func _enter() -> void:
	_stop_entrance()
	for r in n:
		for c in n:
			var tile: Panel = _tiles[r][c]
			var delay := Motion.stagger(r + c, ENTER_STAGGER)
			var pop: Tween = Motion.slide(tile, "scale", Vector2.ONE * 0.01, Vector2.ONE, ENTER_POP, delay)
			if pop != null:
				_entrance.append(pop)
			var face: Control = _faces[r][c]
			if face != null and not Motion.reduce:
				face.scale = Vector2.ZERO
				var tw := face.create_tween()
				tw.tween_property(face, "scale", Vector2(1.0 + FACE_SQUASH, 1.0 - FACE_SQUASH), FACE_IN * 0.6).set_delay(delay + ENTER_FACE_LAG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(face, "scale", Vector2.ONE, FACE_IN * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_entrance.append(tw)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	for r in _tiles.size():
		for c in _tiles[r].size():
			_tiles[r][c].scale = Vector2.ONE
			var face: Control = _faces[r][c]
			if face != null:
				face.scale = Vector2.ONE

## Kills every tween the previous board still tracks, so a rebuild never
## inherits a hop or a blush aimed at tiles that are about to go.
func _stop_all() -> void:
	_stop_entrance()
	Motion.stop(_focus_tw)
	for rows in [_fades, _hops, _scales]:
		for row in rows:
			for tw in row:
				Motion.stop(tw)

## The hint's ring: a circle in sun that grows and fades as `t` runs 0 to 1.
class Ring extends Control:
	var radius := 40.0
	var t := 0.0:
		set(v):
			t = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius * (0.9 + 0.6 * t), 0.0, TAU, 48, Color(Pal.SUN, 1.0 - t), 6.0, true)
