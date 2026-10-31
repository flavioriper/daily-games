extends Control

## Toy Boats' harbour (the concept is docs/brainstorm/toy-boats-harbour.html).
## The player's own water fills the screen, full rect, with their five boats
## floating on it as real boats: a Barge with crates, a Ferry with a cabin and
## a funnel, a red Tugboat, a Sailboat and a Rowboat, each bobbing in its wake.
## One toy cannon stands on a jetty at the foot and fires off the top of the
## screen. The other fleet is never a board: it is a paper **chart**, folded in
## the bottom-left corner, unfolding over the water to aim and folding again.
## The other player's pebbles come from above the top of the screen: a shadow
## swells where one will land, then it drops.
##
## Everything is a cached mesh under a transform: the water one mesh, a boat,
## its wake and its damage one each, the chart's paper, marks and plan one each.
## Only `_air` (what is in flight) and the marks are rebuilt, and only while
## they move. The bobbing is a `_process` on those transforms, which stops
## with the game's rest (core/power.gd).
##
## Input (a touch is not a mouse here, so both are read). Laying out: drag a
## boat to move it, tap it to turn it. Playing: the crosshair slides over the
## chart, its row and column light and the coordinate reads above the thumb,
## and letting go throws. The tray beside the chart holds the plan tools,
## pencil, flag, stencil and eraser: the player's own marks, never sent and
## never judged. A touch on the water folds the chart, a touch on the folded
## chart opens it.

## The player let go on an untried square of the chart.
signal aimed(c: int)
## What was being shown has finished: the boats are in, a pebble's answer is
## on the chart, a pebble has landed on the water.
signal settled
## A boat was moved or turned while laying out.
signal moved
## A boat could not go there, or the square was tried already.
signal refused(reason: String)
## The chart unfolded or folded by hand.
signal chart_moved(open: bool)
## A pebble of theirs landed: {r, boat}. For the screen's stickers and quips.
signal landed(r: int, boat: int)

const Rules = preload("res://versus/boats_rules.gd")
const Tricks = preload("res://versus/boats_tricks.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Power = preload("res://core/power.gd")

## A square's side in the meshes' own space, and the margin round a grid in
## squares (the letters stand in it).
const U := 100.0
const BORDER := 0.5
## A grid's side in the meshes' space, and the band of the chart under its
## grid that holds the fleet strip.
const SIDE := (Rules.N + 2.0 * BORDER) * U
const STRIP := 1.0 * U
## Pixels: the water's margin, what the foot needs, the tray's width and gap,
## the folded chart's side.
const MARGIN := 40.0
const FOOT := 300.0
const TRAY_W := 104.0
const TRAY_GAP := 16.0
const FOLDED := 250.0
const FOLD_TILT := -0.07
## The two grids side by side, for a picture.
const GAP := 18.0

const WATER := Color("4f9fd0")
const WATER_DEEP := Color("3d86b8")
const WATER_LINE := Color(1, 1, 1, 0.2)
const FOAM := Color(1, 1, 1, 0.55)
const PAPER := Color("f4ead6")
const PAPER_DEEP := Color("dcc9a8")
const PAPER_FOLD := Color(0.45, 0.32, 0.18, 0.14)
const INK := Color("47607a")
const INK_LINE := Color(0.28, 0.38, 0.5, 0.26)
const PENCIL_INK := Color(0.32, 0.32, 0.36, 0.85)
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
const HULL := Color("e6c79b")
const HULL_RIM := Color("a57a48")
const HOLE := Color(0.3, 0.19, 0.1, 0.55)
const PEG := Color("e0574f")
const PEG_LIT := Color("f48c80")
const SCORCH := Color(0.16, 0.11, 0.09, 0.55)
const PEBBLE := Color("8f979f")
const PEBBLE_LIT := Color("b9c0c6")
const SHADE := Color(0.08, 0.2, 0.32, 0.28)
## Under water: what a sunk boat is tinted.
const SUNKEN := Color(0.5, 0.72, 0.9, 0.42)
## Each boat's own colour on the chart's strip and a stencil.
const PAINT := [Color("e0574f"), Color("4c9a94"), Color("f5a623"), Color("e58fb5"), Color("7d8fd9")]
const HINT := Color("f9c04a")
const IRON := Color("3f4652")
const IRON_LIT := Color("687282")
const BRASS := Color("e0a93c")

## Seconds: the fuse after the finger lifts; a pebble's climb; a pebble's fall
## onto the water; how long a landing is watched (a sinking longer); a splash;
## the chart's unfolding; how long a boat takes to go down.
const FUSE := 0.14
const CLIMB := 0.5
const FALL := 0.5
const WATCH := 0.34
const WATCH_HIT := 0.5
const WATCH_SUNK := 1.25
const SPLASH := 0.55
const UNFOLD := 0.24
const SINK_TIME := 1.5
## The cues that are pops, and how far each strays at random.
const TICK_VARY := Vector2(0.94, 1.06)
const VARIED := ["tick", "lift", "place", "turn", "refused", "miss", "hit", "splash", "knock", "throw", "fire"]
const LETTERS := "ABCDEFGHIJ"
enum Tool { AIM, PENCIL, FLAG, STENCIL, ERASE }
const TOOLS := [Tool.AIM, Tool.PENCIL, Tool.FLAG, Tool.STENCIL, Tool.ERASE]

var pond: RefCounted
var slate: RefCounted
## True while the boats are being laid out.
var laying := false
var interactive := false
## True on the player's throw: the crosshair may fire.
var can_fire := false
## A picture, not a game (a tutorial page): the water and the chart side by
## side, drawn when asked, no input.
var still := false
## The trick in hand (Tricks.SCATTER and so on), 0 for a plain pebble.
var armed := 0
## The rectangle the field takes.
var used_rect := Rect2()

## 0 folded, 1 unfolded.
var _open := 0.0
var _open_tw: Tween
var _open_want := false
var _tool: int = Tool.AIM
## From the screen: where the field may start and the screen's usable foot.
var _top := 340.0
var _bottom := -1.0
## Where the field is, and in a picture where the chart is.
var _field := Rect2()
var _chart_open := Rect2()
var _chart_shut := Rect2()
var _cannon_at := Vector2.ZERO
var _water: ArrayMesh
var _ripples: ArrayMesh
var _tile: ArrayMesh
var _paper: ArrayMesh
var _tray: ArrayMesh
var _boats: Array = []
var _wakes: Array = []
var _hurts: Array = [null, null, null, null, null]
var _barrel: ArrayMesh
var _carriage: ArrayMesh
var _chart_live: ArrayMesh
var _plan_mesh: ArrayMesh
var _pond_live: ArrayMesh
var _air: ArrayMesh
## Every mesh issued this frame stays alive until the next is (see CLAUDE.md).
var _shown: Array = []
var _dirty := true
var _plan_dirty := true
var _t := 0.0
## Something on the live meshes moves until then.
var _busy_until := 0.0
var _font: Font
var _fx: Node2D
var _run := 0
## When each mark appeared, by square: the water's and the chart's.
var _born := [{}, {}]
## When each boat went under, the player's and each outline on the chart.
var _sank := [{}, {}]
var _enter_at := -1.0
## Pebbles coming down: {c, at, fall, r, boat}. `_due` holds the squares
## answered by the rules and not landed yet, a run's later ones included.
var _pebbles: Array = []
var _due := {}
## The player's pebble climbing: {at, from, to}; empty when none.
var _climb := {}
## The square thrown at and not answered yet, -1 none.
var _aim := -1
var _hint := -1
## The square under the finger on the chart, -1 none.
var _over := -1
## The boat held while laying out: {i, k, from, at, slid, ok}.
var _drag := {}
## A boat shaking its head: [index, when].
var _shake := [-1, -10.0]
## The other player's boats shown at the end.
var _fleet: Array = []
var _outcome := ""
## The cannon's bearing and how far it is back on its spring.
var _bearing := 0.0
var _bearing_want := 0.0
var _kick := 0.0
var _quake := 0.0
## The press belongs to the tray or a fold, not to the chart under it.
var _swallow := false
var _pressed := false
## The player's own plan, in the chart's space: strokes, flags by square, and
## stencils {i, b}. The one being drawn is the last stroke.
var _strokes: Array = []
var _flags := {}
var _stencils: Array = []
var _held_stencil := -1
var _stencil_moved := false
## The Spyglass's look, {c, n}; empty until it is used.
var _glass := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still else Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	resized.connect(_layout)
	if not still:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## Two fresh grids. `lay` opens with the boats movable; `enter` sets them on
## the water and says `settled` once they are down.
func setup(the_pond: RefCounted, the_slate: RefCounted, lay := false, enter := false) -> void:
	_run += 1
	pond = the_pond
	slate = the_slate
	laying = lay
	can_fire = false
	armed = 0
	_tool = Tool.AIM
	Motion.stop(_open_tw)
	_open = 0.0
	_open_want = false
	_born = [{}, {}]
	_sank = [{}, {}]
	_pebbles = []
	_due = {}
	_climb = {}
	_aim = -1
	_hint = -1
	_over = -1
	_drag = {}
	_fleet = []
	_outcome = ""
	_enter_at = -1.0
	_strokes = []
	_flags = {}
	_stencils = []
	_held_stencil = -1
	_glass = {}
	_hurts = [null, null, null, null, null]
	_plan_dirty = true
	_tray = null
	_bearing_want = 0.0
	if enter and not Motion.reduce and not still:
		_enter_at = _t
		_busy(0.8)
		_cue("enter")
		_after(0.6, func() -> void: settled.emit())
	elif enter:
		_after(0.05, func() -> void: settled.emit())
	_touch()

## The boats are laid: `settled` follows at once, nothing changes places.
func begin_play() -> void:
	laying = false
	_drag = {}
	_after(0.05, func() -> void: settled.emit())
	_touch()

## The chart unfolds or folds. The player's turn, a look, the end.
func open_chart(on: bool) -> void:
	if on == _open_want and (_open == (1.0 if on else 0.0) or _open_tw != null):
		return
	_open_want = on
	if not on:
		_over = -1
	Motion.stop(_open_tw)
	if Motion.reduce or still:
		_open = 1.0 if on else 0.0
		_open_tw = null
		_touch()
		return
	_cue("lift", 1.1 if on else 0.9)
	_open_tw = create_tween()
	_open_tw.tween_method(func(v: float) -> void:
		_open = v
		_touch(), _open, 1.0 if on else 0.0, UNFOLD).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tw.tween_callback(func() -> void: _open_tw = null)

func chart_open() -> bool:
	return _open_want

## The player's pebble is on its way to `c` of the other water: the chart
## folds, the cannon bears on the column, a fuse, a pop, and the pebble goes
## off the top of the screen.
func aim(c: int) -> void:
	_aim = c
	_hint = -1
	_over = -1
	_busy(60.0)
	open_chart(false)
	if still:
		_cue("throw")
		return
	var at := Rules.xy(c)
	var to := Vector2(_field.position.x + (at.x + 0.5) * _unit(0), -80.0)
	_bearing_want = (to - _cannon_at).angle() + PI * 0.5
	_bearing_want = clampf(_bearing_want, -0.7, 0.7)
	_after(0.0 if Motion.reduce else FUSE, func() -> void:
		_bearing = _bearing_want
		_kick = 1.0
		_cue("fire")
		var muzzle := _muzzle()
		if not Motion.reduce:
			_puff(muzzle, Color(1, 1, 1, 0.8), 7)
		_climb = {"at": _t, "from": muzzle, "to": to})

## The answer to a pebble at `c`, already written on the chart: the mark goes
## on, and with `last` `settled` follows. `pitch` climbs a run of hits.
func answer(c: int, r: int, boat := -1, last := true, pitch := 1.0) -> void:
	_aim = -1
	_climb = {}
	_busy_until = _t
	_born[1][c] = _t
	if r == Rules.SUNK:
		_sank[1][boat] = _t
	_busy(1.2)
	var at := point_of(1, c)
	if r == Rules.MISS:
		_cue("miss")
		_puff(at, INK, 4)
	else:
		_cue("sunk" if r == Rules.SUNK else "hit", pitch)
		_puff(at, PEG, 8 if r == Rules.SUNK else 5)
		if r == Rules.SUNK and _fx != null:
			_fx.sparkle(at, HINT)
	_touch()
	if last:
		_after(_watch(r), func() -> void: settled.emit())

## A pebble of theirs at `c` of the water, already answered by the rules: the
## shadow swells, it drops, and with `last` `settled` follows. `wait` holds it
## back, for a run of them.
func strike(c: int, r: int, boat := -1, last := true, wait := 0.0) -> void:
	var fall := 0.0 if Motion.reduce else FALL
	var whole := wait + fall
	_due[c] = true
	_after(wait, func() -> void:
		_pebbles.append({"c": c, "at": _t, "r": r, "boat": boat, "fall": fall}))
	_busy(whole + SINK_TIME + 0.4)
	open_chart(false)
	if wait <= 0.0:
		_cue("lob")
	_after(whole, func() -> void:
		for p: Dictionary in _pebbles:
			if int(p.c) == c:
				_pebbles.erase(p)
				break
		_due.erase(c)
		_born[0][c] = _t
		var at := point_of(0, c)
		if r == Rules.MISS:
			_cue("splash")
			_puff(at, Pal.WATER_HI, 7)
			_ring(at, _unit(0) * 0.7, Color(1, 1, 1, 0.8))
		else:
			_cue("glug" if r == Rules.SUNK else "knock")
			_puff(at, Color(0.3, 0.3, 0.32), 9)
			_puff(at, PEG, 6)
			_shake = [boat, _t]
			_quake = 1.0 if r == Rules.SUNK else 0.5
			if boat >= 0:
				_hurts[boat] = null
			if r == Rules.SUNK:
				_sank[0][boat] = _t
		landed.emit(r, boat)
		_touch())
	if last:
		_after(whole + _watch(r), func() -> void: settled.emit())

func _watch(r: int) -> float:
	if Motion.reduce:
		return 0.12
	if r == Rules.SUNK:
		return WATCH_SUNK
	return WATCH_HIT if r == Rules.HIT else WATCH

## The bulb's square on the chart, -1 to take it away.
func set_hint(c: int) -> void:
	_hint = c
	if c >= 0 and _fx != null:
		_fx.ring(point_of(1, c), _unit(1) * 0.6, HINT)
		_fx.sparkle(point_of(1, c), HINT)
	_touch()

## The Spyglass's answer, kept on the chart for the rest of the game.
func show_glass(c: int, n: int) -> void:
	_glass = {"c": c, "n": n, "at": _t}
	_busy(0.6)
	_touch()

## The end: the chart opens, and the other player's boats still afloat are
## drawn on it (`fleet` empty when they are not known).
func finish(outcome: String, fleet: Array = []) -> void:
	_outcome = outcome
	_fleet = fleet
	_aim = -1
	_hint = -1
	_over = -1
	armed = 0
	can_fire = false
	_busy(1.0)
	open_chart(true)
	_touch()

## What the player drew is theirs; nothing here is ever sent.
func has_plan() -> bool:
	return not _strokes.is_empty() or not _flags.is_empty() or not _stencils.is_empty()

## The middle of square `c` of the water (0) or the chart (1), in this control:
## where the board's own effects go, and a harness's finger.
func point_of(grid: int, c: int) -> Vector2:
	var at := Rules.xy(c)
	return _xf(grid) * (Vector2(at.x + 0.5 + BORDER, at.y + 0.5 + BORDER) * U)

## Where the field may run: `top` under the screen's rows, `bottom` over the
## safe area, both in this control.
func set_frame(top: float, bottom: float) -> void:
	_top = top
	_bottom = bottom
	_layout()

## The foot's free band, to the right of the folded chart: the screen's toast.
func foot_rect() -> Rect2:
	var y := _field.end.y + 8.0
	return Rect2(_chart_shut.end.x + 24.0, y, size.x - _chart_shut.end.x - 24.0 - MARGIN, 70.0)

## The field in this control, for the screen's stickers.
func field_rect() -> Rect2:
	return _field

# --- layout ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if still:
		# Side by side, the water first.
		var h := floorf(minf(size.y * SIDE / (SIDE + STRIP), (size.x - GAP) * 0.5))
		var left := (size.x - 2.0 * h - GAP) * 0.5
		var y0 := (size.y - h * (SIDE + STRIP) / SIDE) * 0.5
		_field = Rect2(left + h * BORDER * U / SIDE, y0 + h * BORDER * U / SIDE, h * Rules.N * U / SIDE, h * Rules.N * U / SIDE)
		_chart_open = Rect2(left + h + GAP, y0, h, h * (SIDE + STRIP) / SIDE)
		_chart_shut = _chart_open
		used_rect = Rect2(left, y0, 2.0 * h + GAP, _chart_open.size.y)
	else:
		var bottom := _bottom if _bottom > 0.0 else size.y - MARGIN
		var s := floorf(minf((size.x - 2.0 * MARGIN) / Rules.N, (bottom - _top - FOOT) / Rules.N))
		var side := s * Rules.N
		_field = Rect2(floorf((size.x - side) * 0.5), _top, side, side)
		used_rect = _field
		var wide := size.x - 2.0 * MARGIN - TRAY_W - TRAY_GAP
		var tall := wide * (SIDE + STRIP) / SIDE
		var limit := bottom - _top - 100.0
		if tall > limit:
			tall = limit
			wide = tall * SIDE / (SIDE + STRIP)
		_chart_open = Rect2(MARGIN + TRAY_W + TRAY_GAP, _top, wide, tall)
		var shut_h := FOLDED * (SIDE + STRIP) / SIDE
		_chart_shut = Rect2(MARGIN, bottom - shut_h - 6.0, FOLDED, shut_h)
		_cannon_at = Vector2(size.x * 0.62, bottom - 112.0)
		_water = null
		_ripples = null
		_tray = null
	_dirty = true
	queue_redraw()

## Where grid `g` (0 the water, 1 the chart) is drawn now, from the meshes'
## space to this control's.
func _xf(g: int) -> Transform2D:
	if g == 0:
		var k := _field.size.x / (Rules.N * U)
		return Transform2D(0.0, Vector2.ONE * k, 0.0, _field.position - Vector2.ONE * BORDER * U * k)
	var k := _open if not still else 1.0
	var at := _chart_shut.get_center().lerp(_chart_open.get_center(), k)
	var side := lerpf(_chart_shut.size.x, _chart_open.size.x, k)
	var scale_by := side / SIDE
	var tilt := lerpf(FOLD_TILT, 0.0, k)
	var half := Vector2(SIDE, SIDE + STRIP) * 0.5
	return Transform2D(tilt, Vector2.ONE * scale_by, 0.0, at) * Transform2D(0.0, -half)

## A square's side on the screen for grid `g`.
func _unit(g: int) -> float:
	return _xf(g).get_scale().x * U

## The square of grid `g` under `p`, as a point (off the grid allowed).
func _square_at(g: int, p: Vector2) -> Vector2i:
	var q := _xf(g).affine_inverse() * p / U - Vector2.ONE * BORDER
	return Vector2i(floori(q.x), floori(q.y))

static func _on_grid(q: Vector2i) -> bool:
	return q.x >= 0 and q.y >= 0 and q.x < Rules.N and q.y < Rules.N

func _muzzle() -> Vector2:
	return _cannon_at + Vector2(0.0, -96.0).rotated(_bearing)

# --- time ---

func _process(delta: float) -> void:
	_t += delta
	var moving := _t < _busy_until or not _drag.is_empty() or _kick > 0.0 or _quake > 0.0
	_bearing = lerp_angle(_bearing, _bearing_want, clampf(delta * 16.0, 0.0, 1.0))
	if _kick > 0.0:
		_kick = maxf(_kick - delta * 3.6, 0.0)
	if _quake > 0.0:
		_quake = maxf(_quake - delta * 2.6, 0.0)
	if moving:
		_dirty = true
	# The water breathes unless the game is resting or moves are off.
	if moving or (not Power.resting and not Motion.reduce):
		queue_redraw()

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _touch() -> void:
	_dirty = true
	queue_redraw()

## The builder's mesh, or none when nothing was drawn into it (a mesh with no
## vertices is an error, and a chart begins empty).
static func _mesh_of(b: Face.Builder) -> ArrayMesh:
	return null if b.verts.is_empty() else b.mesh()

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	if seconds <= 0.0:
		what.call()
		return
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0) -> void:
	if _fx != null:
		if cue_name in VARIED:
			pitch *= randf_range(TICK_VARY.x, TICK_VARY.y)
		_fx.cue(cue_name, pitch)

func _puff(at: Vector2, colour: Color, n: int) -> void:
	if _fx != null and not Motion.reduce:
		_fx.puff(at, colour, n)

func _ring(at: Vector2, r: float, colour: Color) -> void:
	if _fx != null and not Motion.reduce:
		_fx.ring(at, r, colour)

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if still or not interactive:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if laying:
		if press:
			_lift(at)
		elif release:
			_drop()
		else:
			_carry(at)
		return
	if press:
		_pressed = true
		_swallow = _press_chrome(at)
		if _swallow:
			return
	if _swallow or not _pressed:
		if release:
			_swallow = false
			_pressed = false
		return
	if release:
		_pressed = false
	match _tool:
		Tool.AIM:
			_crosshair(at, press, release)
		Tool.PENCIL:
			_pencil(at, press, release)
		Tool.FLAG:
			if press:
				_toggle_flag(at)
		Tool.STENCIL:
			_stencil(at, press, release)
		Tool.ERASE:
			_erase(at)
	_touch()

## A press on the tray, on the folded chart or on open water: true when it was
## one of those and the chart under it is not to hear it.
func _press_chrome(at: Vector2) -> bool:
	if _open < 0.5:
		if _chart_shut.grow(16.0).has_point(at):
			open_chart(true)
			chart_moved.emit(true)
			return true
		return true
	for k in TOOLS.size():
		if at.distance_to(_tray_at(k)) <= TRAY_W * 0.5 + 6.0:
			pick_tool(TOOLS[k])
			return true
	if not _chart_open.has_point(at):
		open_chart(false)
		chart_moved.emit(false)
		return true
	return false

func pick_tool(which: int) -> void:
	_tool = which
	_tray = null
	_over = -1
	_cue("tick")
	_touch()

func _crosshair(at: Vector2, press: bool, release: bool) -> void:
	if _aim >= 0:
		return
	var q := _square_at(1, at)
	var c := Rules.cell(q.x, q.y) if _on_grid(q) else -1
	if release:
		if c < 0 and _over >= 0 and slate.marks[_over] == Rules.UNKNOWN:
			# let go off the grid: the square that was held is given up
			_cue("tick", 0.84)
		_over = -1
		if c >= 0 and can_fire:
			if _reachable(c):
				aimed.emit(c)
			else:
				refused.emit("tried")
				_cue("refused")
	elif c != _over or press:
		_over = c
		if c >= 0 and slate.marks[c] == Rules.UNKNOWN:
			_cue("tick")

## Whether a pebble (or the trick in hand) can do anything at `c`. A look
## through the Spyglass may fall on squares already tried.
func _reachable(c: int) -> bool:
	if armed == Tricks.GLASS:
		return true
	if armed != 0:
		return not Tricks.fresh(armed, c, slate.marks).is_empty()
	return slate.marks[c] == Rules.UNKNOWN

func _pencil(at: Vector2, press: bool, release: bool) -> void:
	var p := _xf(1).affine_inverse() * at
	if press:
		_strokes.append(PackedVector2Array([p]))
		_cue("lift")
	elif not release and not _strokes.is_empty():
		var line: PackedVector2Array = _strokes[-1]
		if line[-1].distance_to(p) >= 8.0:
			line.append(p)
			_strokes[-1] = line
	if release and not _strokes.is_empty() and (_strokes[-1] as PackedVector2Array).size() < 2:
		var line: PackedVector2Array = _strokes[-1]
		line.append(line[0] + Vector2(2.0, 2.0))
		_strokes[-1] = line
	_plan_dirty = true

func _toggle_flag(at: Vector2) -> void:
	var q := _square_at(1, at)
	if not _on_grid(q):
		return
	var c := Rules.cell(q.x, q.y)
	if _flags.has(c):
		_flags.erase(c)
		_cue("lift")
	elif slate.marks[c] == Rules.UNKNOWN:
		_flags[c] = true
		_cue("place")
	else:
		_cue("refused")
		return
	_plan_dirty = true

## Tap a square for the longest boat afloat without a stencil, tap a stencil
## to turn it, drag one to move it.
func _stencil(at: Vector2, press: bool, release: bool) -> void:
	var q := _square_at(1, at)
	if press:
		_stencil_moved = false
		_held_stencil = _stencil_under(q)
		if _held_stencil < 0 and _on_grid(q):
			var i := _next_stencil()
			if i >= 0:
				_stencils.append({"i": i, "b": _fit(i, Vector3i(q.x, q.y, 0))})
				_cue("place")
				_stencil_moved = true
				_held_stencil = _stencils.size() - 1
		_plan_dirty = true
		return
	if _held_stencil < 0:
		return
	var s: Dictionary = _stencils[_held_stencil]
	if release:
		if not _stencil_moved:
			var b: Vector3i = s.b
			s.b = _fit(int(s.i), Vector3i(b.x, b.y, 1 - b.z))
			_cue("turn")
		_held_stencil = -1
	elif _on_grid(q):
		var b: Vector3i = s.b
		var to := _fit(int(s.i), Vector3i(q.x, q.y, b.z))
		if to != b:
			s.b = to
			_stencil_moved = true
			_cue("tick")
	_plan_dirty = true

static func _fit(i: int, b: Vector3i) -> Vector3i:
	var n: int = Rules.FLEET[i]
	var d := Rules.step(b.z)
	return Vector3i(clampi(b.x, 0, Rules.N - 1 - (n - 1) * d.x), clampi(b.y, 0, Rules.N - 1 - (n - 1) * d.y), b.z)

func _stencil_under(q: Vector2i) -> int:
	if not _on_grid(q):
		return -1
	var c := Rules.cell(q.x, q.y)
	for k in range(_stencils.size() - 1, -1, -1):
		var s: Dictionary = _stencils[k]
		if Rules.cells_of(int(s.i), s.b).has(c):
			return k
	return -1

func _next_stencil() -> int:
	for i in Rules.FLEET.size():
		if slate.sunk[i]:
			continue
		var used := false
		for s: Dictionary in _stencils:
			used = used or int(s.i) == i
		if not used:
			return i
	return -1

func _erase(at: Vector2) -> void:
	var p := _xf(1).affine_inverse() * at
	var q := _square_at(1, at)
	var kept := []
	for line: PackedVector2Array in _strokes:
		var hit := false
		for v in line:
			if v.distance_to(p) < U * 0.45:
				hit = true
				break
		if not hit:
			kept.append(line)
	var changed := kept.size() != _strokes.size()
	_strokes = kept
	if _on_grid(q):
		var c := Rules.cell(q.x, q.y)
		if _flags.erase(c):
			changed = true
		var k := _stencil_under(q)
		if k >= 0:
			_stencils.remove_at(k)
			changed = true
	if changed:
		_plan_dirty = true
		_cue("lift")

func _lift(p: Vector2) -> void:
	var q := _square_at(0, p)
	if not _on_grid(q):
		return
	var i: int = pond.boat_at(Rules.cell(q.x, q.y))
	if i < 0:
		return
	var b: Vector3i = pond.boats[i]
	var k := (q.x - b.x) + (q.y - b.y)
	_drag = {"i": i, "k": k, "from": b, "at": b, "slid": false, "ok": true, "sq": q}
	_cue("lift")
	_touch()

func _carry(p: Vector2) -> void:
	if _drag.is_empty():
		return
	var q := _square_at(0, p)
	if q == _drag.sq:
		return
	_drag.sq = q
	var i: int = _drag.i
	var from: Vector3i = _drag.from
	var d := Rules.step(from.z)
	var n: int = Rules.FLEET[i]
	var bow := q - d * int(_drag.k)
	# Held to the pond: a boat carried past the edge stops at it.
	bow.x = clampi(bow.x, 0, Rules.N - 1 - (n - 1) * d.x)
	bow.y = clampi(bow.y, 0, Rules.N - 1 - (n - 1) * d.y)
	var to := Vector3i(bow.x, bow.y, from.z)
	if to == _drag.at:
		return
	_drag.at = to
	_drag.slid = true
	_drag.ok = Rules.free_for(pond.boats, i, to)
	_cue("tick")
	_touch()

func _drop() -> void:
	if _drag.is_empty():
		return
	var i: int = _drag.i
	var from: Vector3i = _drag.from
	var to: Vector3i = _drag.at
	if not bool(_drag.slid):
		to = _turned(i, from, int(_drag.k))
	_drag = {}
	if to == from or to.x < 0 or not Rules.free_for(pond.boats, i, to):
		_shake = [i, _t]
		_busy(0.4)
		_cue("refused")
		refused.emit("room")
	else:
		pond.boats[i] = to
		_cue("turn" if to.z != from.z else "place")
		_ring(_xf(0) * (_boat_xf(to) * Vector2((Rules.FLEET[i] - 1) * U * 0.5, 0.0)), _unit(0) * 0.8, Color(1, 1, 1, 0.5))
		moved.emit()
	_touch()

## Boat `i` turned a quarter about the square it was touched on (`k` squares
## from its bow), or about the nearest square of it that leaves it room; x < 0
## when there is none.
func _turned(i: int, b: Vector3i, k: int) -> Vector3i:
	var n: int = Rules.FLEET[i]
	var d := Rules.step(b.z)
	var pivot := Vector2i(b.x, b.y) + d * k
	var nd := Rules.step(1 - b.z)
	# Try the turn with each of its squares on the pivot, the touched one first.
	var order := [k]
	for j in n:
		if j != k:
			order.append(j)
	for clamped: bool in [false, true]:
		for j: int in order:
			var bow := pivot - nd * j
			if clamped:
				bow.x = clampi(bow.x, 0, Rules.N - 1 - (n - 1) * nd.x)
				bow.y = clampi(bow.y, 0, Rules.N - 1 - (n - 1) * nd.y)
			var to := Vector3i(bow.x, bow.y, 1 - b.z)
			if Rules.free_for(pond.boats, i, to):
				return to
	return Rules.HIDDEN

# --- drawing ---

func _draw() -> void:
	if pond == null or _field.size.x <= 0.0:
		return
	if _boats.is_empty():
		for i in Rules.FLEET.size():
			_boats.append(boat_mesh(i))
			_wakes.append(_build_wake(i))
		_tile = _build_tile()
		_paper = _build_paper()
		_barrel = _build_barrel()
		_carriage = _build_carriage()
	if not still and _water == null:
		_water = _build_water()
		_ripples = _build_ripples()
	if _dirty:
		_dirty = false
		_pond_live = _build_pond_live()
		_chart_live = _build_chart_live()
		_air = _build_air()
	if _plan_dirty:
		_plan_dirty = false
		_plan_mesh = _build_plan()
	if not still and _tray == null:
		_tray = _build_tray()
	_shown = [_water, _ripples, _tile, _paper, _tray, _pond_live, _chart_live, _plan_mesh, _air, _hurts.duplicate()]
	var shake := Vector2.ZERO
	if _quake > 0.0:
		shake = Vector2(sin(_t * 61.0), cos(_t * 47.0)) * 14.0 * _quake * _quake
	var world := Transform2D(0.0, shake)
	if still:
		draw_mesh(_tile, null, _xf(0))
	else:
		draw_mesh(_water, null, world)
		var drift := Vector2(sin(_t * 0.5) * 12.0, cos(_t * 0.37) * 7.0)
		draw_mesh(_ripples, null, Transform2D(0.0, shake + drift), Color(1, 1, 1, 0.75 + 0.25 * sin(_t * 0.9)))
		draw_mesh(_ripples, null, Transform2D(PI, size * Vector2(1.0, 1.0) - drift * 0.7 + shake), Color(1, 1, 1, 0.5 - 0.25 * sin(_t * 0.9)))
	_draw_letters(world * _xf(0), Color(1, 1, 1, 0.62))
	_draw_boats(world * _xf(0))
	if _pond_live != null:
		draw_mesh(_pond_live, null, world * _xf(0))
	if not still:
		_draw_cannon(world)
	_draw_chart()
	if _air != null:
		draw_mesh(_air, null, world)

## The chart's paper, what is known and what the player planned. The tray
## stands beside it while it is open.
func _draw_chart() -> void:
	var xf := _xf(1)
	if not still and _open > 0.02:
		draw_mesh(_tray, null, Transform2D.IDENTITY, Color(1, 1, 1, _open))
	draw_mesh(_paper, null, xf)
	if xf.get_scale().x * U >= 34.0:
		_draw_letters(xf, Color(INK, 0.85))
	if _chart_live != null:
		draw_mesh(_chart_live, null, xf)
	if _plan_mesh != null:
		draw_mesh(_plan_mesh, null, xf)
	if not _glass.is_empty() and _open > 0.5:
		var m: Vector2 = xf * _mid(int(_glass.c))
		var text := str(int(_glass.n))
		var fs := int(_unit(1) * 0.86)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, m + Vector2(-w * 0.5, fs * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("2f6d6a"))
	if _over >= 0 and _open > 0.5 and not still:
		_draw_tag()

## The coordinate, above the thumb.
func _draw_tag() -> void:
	var at := Rules.xy(_over)
	var text := "%s%d" % [LETTERS[at.y], at.x + 1]
	var fs := 46
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var m := point_of(1, _over) + Vector2(0.0, -_unit(1) * 2.2)
	if m.y < _chart_open.position.y + 40.0:
		m.y = point_of(1, _over).y + _unit(1) * 2.2
	var r := Rect2(m - Vector2(w * 0.5 + 18.0, 36.0), Vector2(w + 36.0, 66.0))
	draw_rect(r, Color(INK, 0.92), true)
	draw_string(_font, Vector2(m.x - w * 0.5, m.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw_cannon(world: Transform2D) -> void:
	var back := Vector2(0.0, 26.0 * _kick * _kick).rotated(_bearing)
	draw_mesh(_carriage, null, world * Transform2D(0.0, _cannon_at))
	draw_mesh(_barrel, null, world * Transform2D(_bearing, _cannon_at + back))

## Each boat under its bob: its wake, the boat and what has hit it.
func _draw_boats(xf: Transform2D) -> void:
	var held: int = _drag.i if not _drag.is_empty() else -1
	var order := range(Rules.FLEET.size())
	if held >= 0:
		order.erase(held)
		order.append(held)
	# The ones gone down are drawn first, under the rest.
	for i: int in order:
		if pond.sunk[i] and _sank[0].has(i):
			_draw_sunk(xf, i)
	for i: int in order:
		if pond.sunk[i] and _sank[0].has(i):
			continue
		var boat: Vector3i = pond.boats[i]
		if boat.x < 0:
			continue
		var grow := 1.0
		var slip := Vector2.ZERO
		if _enter_at >= 0.0:
			var e := _t - _enter_at - 0.07 * i
			if e <= 0.0:
				continue
			grow = Motion.pop_in_scale(e).x if e < Motion.POP_IN else 1.0
		if i == held:
			boat = _drag.at
			grow = Motion.LIFT_SCALE
		if int(_shake[0]) == i:
			slip = Vector2(Motion.shiver_offset(_t - float(_shake[1]), U * 0.1, 0.4), 0.0)
		var phase := float(i) * 1.7
		var rock := sin(_t * 1.25 + phase) * 0.012
		if int(_shake[0]) == i:
			rock += sin((_t - float(_shake[1])) * 15.0) * 0.05 * maxf(1.0 - (_t - float(_shake[1])) / 0.9, 0.0)
		var bob := Vector2(0.0, sin(_t * 1.6 + phase) * 2.2)
		var mid := Vector2((int(Rules.FLEET[i]) - 1) * U * 0.5, 0.0)
		var at := xf * _boat_xf(boat, grow, slip + bob)
		var hull := at * Transform2D(rock, mid) * Transform2D(0.0, -mid)
		draw_mesh(_wakes[i], null, at, Color(1, 1, 1, 0.65 + 0.35 * sin(_t * 1.1 + phase)))
		draw_mesh(_boats[i], null, hull)
		if _hurts[i] == null:
			_hurts[i] = _build_hurt(i)
		if _hurts[i] is ArrayMesh:
			draw_mesh(_hurts[i], null, hull)

func _draw_sunk(xf: Transform2D, i: int) -> void:
	var u := clampf((_t - float(_sank[0][i])) / SINK_TIME, 0.0, 1.0)
	var fall := u * u
	var mid := Vector2((int(Rules.FLEET[i]) - 1) * U * 0.5, 0.0)
	var tip := 0.24 * fall * (1.0 if i % 2 == 0 else -1.0)
	var at := xf * _boat_xf(pond.boats[i], lerpf(1.0, 0.92, fall))
	var hull := at * Transform2D(tip, mid) * Transform2D(0.0, -mid)
	var tint := Color.WHITE.lerp(SUNKEN, fall)
	draw_mesh(_boats[i], null, hull, tint)
	if _hurts[i] == null:
		_hurts[i] = _build_hurt(i)
	if _hurts[i] is ArrayMesh:
		draw_mesh(_hurts[i], null, hull, tint)

## The letters down a grid's side and numbers across its top.
func _draw_letters(xf: Transform2D, ink: Color) -> void:
	var fs := int(U * 0.28)
	if xf.get_scale().x * fs < 11.0:
		return
	draw_set_transform_matrix(xf)
	var edge := BORDER * U * 0.6
	for i in Rules.N:
		var mid := (BORDER + i + 0.5) * U
		var num := str(i + 1)
		var w := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(mid - w * 0.5, edge + fs * 0.36), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		var letter := LETTERS[i]
		var w2 := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, Vector2(edge - w2 * 0.5, mid + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The whole screen's water, the field's lines on it and the jetty at the foot.
func _build_water() -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bands := 22
	for k in bands:
		var y0 := size.y * k / bands
		var y1 := size.y * (k + 1) / bands + 1.0
		var col := Color("5dacd8").lerp(WATER_DEEP, absf(float(k) / bands - 0.35) * 1.3)
		b.fan(PackedVector2Array([Vector2(0.0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0.0, y1)]), col)
	for k in 7:
		Scenery.soft_disc(b, Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(180.0, 420.0), rng.randf_range(90.0, 200.0), Color(1, 1, 1, 0.05))
	var f := _field
	var s := f.size.x / Rules.N
	b.stroke(Face.Builder.round_rect(f.position - Vector2.ONE * 3.0, f.size + Vector2.ONE * 6.0, 14.0), 3.0, Color(1, 1, 1, 0.32), true)
	for i in range(1, Rules.N):
		var p := i * s
		b.stroke(PackedVector2Array([f.position + Vector2(p, 2.0), f.position + Vector2(p, f.size.y - 2.0)]), 2.0, WATER_LINE)
		b.stroke(PackedVector2Array([f.position + Vector2(2.0, p), f.position + Vector2(f.size.x - 2.0, p)]), 2.0, WATER_LINE)
	# Four buoys hold the field's corners.
	for corner: Vector2 in [f.position, f.position + Vector2(f.size.x, 0.0), f.position + Vector2(0.0, f.size.y), f.end]:
		b.disc(corner + Vector2(1.0, 3.0), 12.0, Color(0.05, 0.15, 0.25, 0.3))
		b.disc(corner, 11.0, PEG)
		b.disc(corner + Vector2(-3.0, -3.0), 5.0, Color("ffd9d3"))
	_jetty(b)
	return b.mesh()

## The jetty the cannon stands on, its planks running out from under the foot.
func _jetty(b: Face.Builder) -> void:
	var c := _cannon_at
	var at := Vector2(c.x - 170.0, c.y - 58.0)
	var sz := Vector2(340.0, size.y - at.y + 20.0)
	b.fan(Face.Builder.round_rect(at + Vector2(10.0, 14.0), sz, 16.0), Color(0.05, 0.15, 0.25, 0.3))
	b.fan(Face.Builder.round_rect(at, sz, 16.0), WOOD_DEEP)
	var x := at.x + 8.0
	var n := 6
	var w := (sz.x - 16.0) / n
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in n:
		b.fan(Face.Builder.round_rect(Vector2(x, at.y + 8.0 + rng.randf() * 6.0), Vector2(w - 6.0, sz.y), 6.0), WOOD.lerp(WOOD_LIT, rng.randf()))
		x += w
	for k: float in [0.0, 1.0]:
		var post := at + Vector2(k * sz.x, 0.0)
		b.disc(post + Vector2(2.0, 5.0), 21.0, Color(0.05, 0.1, 0.15, 0.4))
		b.disc(post, 20.0, WOOD_DEEP)
		b.disc(post, 13.0, WOOD_LIT)

## Short lit lines lying across the water; drawn twice, drifting.
func _build_ripples() -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for k in 70:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var len := rng.randf_range(40.0, 110.0)
		var pts := PackedVector2Array()
		for s in 7:
			pts.append(at + Vector2(len * s / 6.0, sin(s * 1.1) * 3.5))
		b.stroke(pts, 3.0, Color(1, 1, 1, rng.randf_range(0.08, 0.22)))
	return b.mesh()

## The picture's water: a tile of the field.
func _build_tile() -> ArrayMesh:
	var b := Face.Builder.new()
	var all := Vector2.ONE * SIDE
	b.fan(Face.Builder.round_rect(Vector2.ZERO, all, U * 0.3), WATER_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(0.0, U * 0.06), all - Vector2(0.0, U * 0.06), U * 0.3), WATER)
	var o := BORDER * U
	for i in Rules.N + 1:
		var p := o + i * U
		b.stroke(PackedVector2Array([Vector2(p, o), Vector2(p, SIDE - o)]), U * 0.022, WATER_LINE)
		b.stroke(PackedVector2Array([Vector2(o, p), Vector2(SIDE - o, p)]), U * 0.022, WATER_LINE)
	return b.mesh()

## The chart: old paper with its folds, its grid and room for the fleet strip.
func _build_paper() -> ArrayMesh:
	var b := Face.Builder.new()
	var all := Vector2(SIDE, SIDE + STRIP)
	b.fan(Face.Builder.round_rect(Vector2(U * 0.1, U * 0.14), all, U * 0.16), Color(0.05, 0.12, 0.2, 0.34))
	b.fan(Face.Builder.round_rect(Vector2.ZERO, all + Vector2(0.0, U * 0.05), U * 0.16), PAPER_DEEP)
	b.fan(Face.Builder.round_rect(Vector2.ZERO, all, U * 0.16), PAPER)
	for k in range(1, 4):
		var x := all.x * k / 4.0
		var y := all.y * k / 4.0
		b.stroke(PackedVector2Array([Vector2(x, U * 0.1), Vector2(x, all.y - U * 0.1)]), U * 0.05, PAPER_FOLD)
		b.stroke(PackedVector2Array([Vector2(U * 0.1, y), Vector2(all.x - U * 0.1, y)]), U * 0.05, PAPER_FOLD)
	var o := BORDER * U
	for i in Rules.N + 1:
		var p := o + i * U
		var wide := U * (0.035 if i == 0 or i == Rules.N else 0.02)
		b.stroke(PackedVector2Array([Vector2(p, o), Vector2(p, SIDE - o)]), wide, INK_LINE)
		b.stroke(PackedVector2Array([Vector2(o, p), Vector2(SIDE - o, p)]), wide, INK_LINE)
	return b.mesh()

## A boat's outline, its bow's square at the origin and the rest along +x.
static func hull_points(i: int, grow := 0.0) -> PackedVector2Array:
	var n: int = Rules.FLEET[i]
	var x0 := -0.4 * U - grow
	var x1 := (n - 1) * U + 0.44 * U + grow
	var w := 0.32 * U + grow
	var turn := 0.16 * U
	var nose := 0.62 * U
	var pts := PackedVector2Array()
	pts.append_array(Face.Builder.bezier2(Vector2(x0, 0.0), Vector2(x0, -w), Vector2(x0 + turn, -w), 6))
	pts.append_array(Face.Builder.bezier2(Vector2(x1 - nose, -w), Vector2(x1 - 0.14 * U, -w), Vector2(x1, 0.0), 10))
	pts.append_array(Face.Builder.bezier2(Vector2(x1, 0.0), Vector2(x1 - 0.14 * U, w), Vector2(x1 - nose, w), 10).slice(1))
	pts.append_array(Face.Builder.bezier2(Vector2(x0 + turn, w), Vector2(x0, w), Vector2(x0, 0.0), 6).slice(0, 6))
	return pts

## What a boat sits in: a dark shape under it and a line of foam round it.
func _build_wake(i: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var shade := PackedVector2Array()
	for p in hull_points(i, 0.02 * U):
		shade.append(p + Vector2(0.05, 0.09) * U)
	b.fan(shade, SHADE)
	b.stroke(hull_points(i, 0.075 * U), U * 0.032, FOAM, true)
	var n: int = Rules.FLEET[i]
	for k in 3:
		var x := -0.5 * U - k * 0.17 * U
		b.stroke(PackedVector2Array([Vector2(x, -0.2 * U + k * 0.04 * U), Vector2(x - 0.1 * U, 0.0), Vector2(x, 0.2 * U - k * 0.04 * U)]), U * 0.024, Color(1, 1, 1, 0.34 - 0.1 * k))
	var bow := (n - 1) * U + 0.56 * U
	b.stroke(PackedVector2Array([Vector2(bow - 0.14 * U, -0.3 * U), Vector2(bow, 0.0), Vector2(bow - 0.14 * U, 0.3 * U)]), U * 0.026, Color(1, 1, 1, 0.4))
	return b.mesh()

## A hull in `side`, with `deck` lit inside it and a rail of `rail`.
static func _hull_body(b: Face.Builder, i: int, side: Color, deck: Color, rail: Color) -> void:
	b.fan(hull_points(i), side.darkened(0.25))
	var up := PackedVector2Array()
	for p in hull_points(i, -0.03 * U):
		up.append(p + Vector2(0.0, -0.03) * U)
	b.fan(up, side)
	var top := PackedVector2Array()
	for p in hull_points(i, -0.09 * U):
		top.append(p + Vector2(-0.01, -0.03) * U)
	b.fan(top, deck)
	b.stroke(top, U * 0.025, rail, true)

static func _box(b: Face.Builder, at: Vector2, sz: Vector2, col: Color, r := 6.0) -> void:
	b.fan(Face.Builder.round_rect(at + Vector2(U * 0.025, U * 0.035), sz, r), Color(0.1, 0.08, 0.06, 0.28))
	b.fan(Face.Builder.round_rect(at, sz, r), col)
	b.stroke(PackedVector2Array([at + Vector2(sz.x * 0.08, sz.y * 0.16), at + Vector2(sz.x * 0.92, sz.y * 0.16)]), U * 0.02, Color(1, 1, 1, 0.3))

## Each boat is its own kind, as the concept drew them. All in the same space
## as `hull_points`: along +x, the sharp end ahead, a square `U` long.
static func boat_mesh(i: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var n: int = Rules.FLEET[i]
	match i:
		0:
			# The Barge: a long flat iron hull and a deck of crates under tarps.
			_hull_body(b, i, Color("5b7a6a"), Color("a9a08a"), Color("3f5a4d"))
			var crates := [Color("c99a5e"), Color("b98250"), Color("d3a273"), Color("6f93a8")]
			for k in 4:
				var x := (-0.2 + k * 0.92) * U
				_box(b, Vector2(x, -0.2 * U), Vector2(0.68 * U, 0.4 * U), crates[k], 7.0)
				b.stroke(PackedVector2Array([Vector2(x + 0.34 * U, -0.2 * U), Vector2(x + 0.34 * U, 0.2 * U)]), U * 0.022, Color(0.3, 0.2, 0.1, 0.45))
				b.stroke(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 0.68 * U, 0.0)]), U * 0.022, Color(0.3, 0.2, 0.1, 0.45))
		1:
			# The Ferry: white over a blue line, a long cabin of windows, a funnel.
			_hull_body(b, i, Color("f4f1ea"), Color("d9d3c6"), Color("3e7cb1"))
			var cabin := Vector2(2.5 * U, 0.4 * U)
			_box(b, Vector2(-0.12 * U, -0.2 * U), cabin, Color("fbfaf6"), 10.0)
			for k in 7:
				b.fan(Face.Builder.round_rect(Vector2((-0.02 + k * 0.34) * U, -0.15 * U), Vector2(0.2 * U, 0.1 * U), 3.0), Color("6fb0d3"))
				b.fan(Face.Builder.round_rect(Vector2((-0.02 + k * 0.34) * U, 0.05 * U), Vector2(0.2 * U, 0.1 * U), 3.0), Color("6fb0d3"))
			b.disc(Vector2(1.02, 0.03) * U, 0.17 * U, Color(0.1, 0.1, 0.1, 0.22))
			b.disc(Vector2(1.0, 0.0) * U, 0.16 * U, Color("e0574f"))
			b.disc(Vector2(1.0, 0.0) * U, 0.09 * U, Color("37322f"))
			_box(b, Vector2(2.56 * U, -0.14 * U), Vector2(0.3 * U, 0.28 * U), Color("3e7cb1"), 6.0)
		2:
			# The Tugboat: red, tyres on its sides, a wheelhouse and a black funnel.
			_hull_body(b, i, Color("d4503f"), Color("e8c9a0"), Color("8f2f24"))
			for k in 4:
				var x := (-0.1 + k * 0.72) * U
				for y: float in [-0.31, 0.31]:
					b.disc(Vector2(x, y * U), 0.075 * U, Color("2c2c30"))
					b.disc(Vector2(x, y * U), 0.03 * U, Color("55555c"))
			_box(b, Vector2(0.72 * U, -0.17 * U), Vector2(0.62 * U, 0.34 * U), Color("fbf4e6"), 8.0)
			b.fan(Face.Builder.round_rect(Vector2(1.14 * U, -0.13 * U), Vector2(0.14 * U, 0.26 * U), 3.0), Color("6fb0d3"))
			b.disc(Vector2(0.28, 0.03) * U, 0.16 * U, Color(0.1, 0.1, 0.1, 0.22))
			b.disc(Vector2(0.26, 0.0) * U, 0.15 * U, Color("2c2c30"))
			b.disc(Vector2(0.26, 0.0) * U, 0.1 * U, Color("e0574f"))
			b.disc(Vector2(0.26, 0.0) * U, 0.05 * U, Color("111114"))
		3:
			# The Sailboat: a slim white hull and a sail full of the wind.
			_hull_body(b, i, Color("fdfbf6"), Color("cfa877"), Color("2f8f8a"))
			var mast := Vector2(1.08 * U, 0.0)
			var sail := PackedVector2Array()
			sail.append(mast)
			sail.append_array(Face.Builder.bezier2(mast, Vector2(0.9 * U, 0.9 * U), Vector2(-0.2 * U, 0.04 * U), 12))
			var shade := PackedVector2Array()
			for p in sail:
				shade.append(p + Vector2(0.03, 0.06) * U)
			b.polygon(shade, Color(0.1, 0.2, 0.3, 0.24))
			b.polygon(sail, Color("fff7e8"))
			b.stroke(Face.Builder.bezier2(Vector2(0.84 * U, 0.08 * U), Vector2(0.7 * U, 0.44 * U), Vector2(0.28 * U, 0.08 * U), 8), U * 0.03, Color("e0574f"))
			b.stroke(PackedVector2Array([mast, Vector2(-0.22 * U, 0.03 * U)]), U * 0.035, WOOD_DEEP)
			b.disc(mast, 0.06 * U, WOOD_DEEP)
		_:
			# The Rowboat: planks, two thwarts and a pair of oars.
			for side: float in [-1.0, 1.0]:
				var tip := Vector2(0.26 * U, side * 0.62 * U)
				b.stroke(PackedVector2Array([Vector2(0.42 * U, side * 0.22 * U), tip]), U * 0.04, WOOD_DEEP)
				b.ellipse(tip + Vector2(-0.03, side * 0.06) * U, 0.075 * U, 0.14 * U, WOOD_LIT)
			_hull_body(b, i, Color("b98457"), Color("7d5334"), Color("d3a273"))
			for x: float in [0.08, 0.62]:
				b.fan(Face.Builder.round_rect(Vector2(x * U, -0.21 * U), Vector2(0.15 * U, 0.42 * U), 3.0), WOOD_LIT)
			for y: float in [-0.08, 0.08]:
				b.stroke(PackedVector2Array([Vector2(-0.24 * U, y * U), Vector2((n - 1) * U + 0.1 * U, y * U)]), U * 0.012, Color(0.2, 0.1, 0.05, 0.35))
	return b.mesh()

## The damage on a boat, in its own space: a scorch and a red peg a square hit.
## `false` when there is none, so a clean boat is not asked again.
func _build_hurt(i: int) -> Variant:
	var b := Face.Builder.new()
	var boat: Vector3i = pond.boats[i]
	var cells := Rules.cells_of(i, boat)
	for k in cells.size():
		if pond.marks[cells[k]] != Rules.HIT:
			continue
		var m := Vector2(k * U, 0.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + cells[k]
		for s in 5:
			var d := Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.18, 0.18)) * U
			Scenery.soft_disc(b, m + d, rng.randf_range(0.14, 0.26) * U, rng.randf_range(0.1, 0.2) * U, SCORCH)
		b.disc(m + Vector2(0.03, 0.06) * U, U * 0.17, Color(0.1, 0.05, 0.03, 0.4))
		b.disc(m, U * 0.17, PEG)
		b.disc(m + Vector2(-0.05, -0.05) * U, U * 0.08, PEG_LIT)
	return false if b.verts.is_empty() else b.mesh()

## The cannon's carriage, wheels and the spring, centred on its pivot.
func _build_carriage() -> ArrayMesh:
	var b := Face.Builder.new()
	b.fan(Face.Builder.round_rect(Vector2(-76.0, -30.0), Vector2(152.0, 88.0), 18.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-70.0, -32.0), Vector2(140.0, 80.0), 16.0), WOOD)
	for side: float in [-1.0, 1.0]:
		var at := Vector2(side * 86.0, 26.0)
		b.disc(at + Vector2(2.0, 4.0), 37.0, Color(0.1, 0.06, 0.03, 0.4))
		b.disc(at, 35.0, WOOD_DEEP)
		b.disc(at, 26.0, WOOD_LIT)
		b.disc(at, 9.0, BRASS)
	return b.mesh()

## The barrel, pointing up from its pivot: stout, brass-bound, a toy.
func _build_barrel() -> ArrayMesh:
	var b := Face.Builder.new()
	var body := PackedVector2Array([Vector2(-40.0, 26.0), Vector2(-30.0, -82.0), Vector2(30.0, -82.0), Vector2(40.0, 26.0)])
	b.fan(Face.Builder.round_rect(Vector2(-41.0, -8.0), Vector2(82.0, 44.0), 20.0), IRON)
	b.polygon(body, IRON)
	b.polygon(PackedVector2Array([Vector2(-26.0, 20.0), Vector2(-19.0, -78.0), Vector2(-5.0, -78.0), Vector2(-8.0, 20.0)]), IRON_LIT)
	b.fan(Face.Builder.round_rect(Vector2(-38.0, -98.0), Vector2(76.0, 24.0), 9.0), BRASS)
	b.fan(Face.Builder.round_rect(Vector2(-37.0, -38.0), Vector2(74.0, 14.0), 6.0), BRASS)
	b.ellipse(Vector2(0.0, -96.0), 24.0, 7.0, Color("20242b"))
	return b.mesh()

## The tray beside the open chart: five round buttons, the tool in hand lit.
func _build_tray() -> ArrayMesh:
	var b := Face.Builder.new()
	for k in TOOLS.size():
		var at := _tray_at(k)
		var on: bool = TOOLS[k] == _tool
		var r := TRAY_W * 0.5
		b.disc(at + Vector2(0.0, 6.0), r, Color(0.05, 0.12, 0.2, 0.4))
		b.disc(at, r, Color("fff1c9") if on else Pal.SURFACE)
		if on:
			b.stroke(Face.Builder.ring(at, r - 3.0, r - 3.0), 6.0, Pal.ACCENT_2, true)
		paint_tool(b, TOOLS[k], at, r * 0.62)
	return b.mesh()

func _tray_at(k: int) -> Vector2:
	return Vector2(MARGIN + TRAY_W * 0.5, _chart_open.position.y + TRAY_W * 0.5 + k * (TRAY_W + 14.0))

static func paint_tool(b: Face.Builder, which: int, c: Vector2, r: float) -> void:
	match which:
		Tool.AIM:
			b.stroke(Face.Builder.ring(c, r * 0.66, r * 0.66), r * 0.15, PEG, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				b.stroke(PackedVector2Array([c + d * r * 0.42, c + d * r]), r * 0.15, PEG)
		Tool.PENCIL:
			var d := Vector2(1.0, -1.0).normalized()
			var n := Vector2(d.y, -d.x)
			var tip := c - d * r
			var top := c + d * r
			b.stroke(PackedVector2Array([tip + d * r * 0.5, top]), r * 0.46, Color("f2b53f"), false, false)
			b.polygon(PackedVector2Array([tip, tip + d * r * 0.52 + n * r * 0.23, tip + d * r * 0.52 - n * r * 0.23]), Color("e6c79b"))
			b.polygon(PackedVector2Array([tip, tip + d * r * 0.2 + n * r * 0.09, tip + d * r * 0.2 - n * r * 0.09]), Color("37322f"))
			b.stroke(PackedVector2Array([top - d * r * 0.1, top + d * r * 0.12]), r * 0.46, Color("e58fb5"), false, false)
		Tool.FLAG:
			b.stroke(PackedVector2Array([c + Vector2(-r * 0.4, r), c + Vector2(-r * 0.4, -r)]), r * 0.13, WOOD_DEEP)
			b.polygon(PackedVector2Array([c + Vector2(-r * 0.36, -r), c + Vector2(r * 0.9, -r * 0.55), c + Vector2(-r * 0.36, -r * 0.08)]), PEG)
		Tool.STENCIL:
			var pts := PackedVector2Array()
			for p in Face.Builder.round_rect(c - Vector2(r, r * 0.46), Vector2(r * 2.0, r * 0.92), r * 0.42):
				pts.append(p)
			for k in range(0, pts.size() - 1, 2):
				b.stroke(PackedVector2Array([pts[k], pts[k + 1]]), r * 0.13, INK)
		_:
			var tilt := -0.6
			var body := Transform2D(tilt, c)
			b.polygon(_xf_pts(body, Face.Builder.round_rect(Vector2(-r * 0.84, -r * 0.42), Vector2(r * 1.68, r * 0.84), r * 0.18)), Color("e58fb5"))
			b.polygon(_xf_pts(body, Face.Builder.round_rect(Vector2(-r * 0.84, -r * 0.42), Vector2(r * 0.72, r * 0.84), r * 0.18)), Color("f4efe4"))

static func _xf_pts(xf: Transform2D, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * p)
	return out

## From a boat's own space to a grid's: its bow's square, turned south when
## it runs down the pond.
static func _boat_xf(boat: Vector3i, scale_by := 1.0, slip := Vector2.ZERO) -> Transform2D:
	var at := Vector2(boat.x + 0.5 + BORDER, boat.y + 0.5 + BORDER) * U + slip
	return Transform2D(PI * 0.5 if boat.z == 1 else 0.0, Vector2.ONE * scale_by, 0.0, at)

static func _mid(c: int) -> Vector2:
	var at := Rules.xy(c)
	return Vector2(at.x + 0.5 + BORDER, at.y + 0.5 + BORDER) * U

## What is on the water: rings where a pebble found nothing, the no-room mark
## over a held boat, the bubbles of one going down and the shadows coming.
func _build_pond_live() -> ArrayMesh:
	var b := Face.Builder.new()
	if not _drag.is_empty() and not bool(_drag.ok):
		var i: int = _drag.i
		var xf := _boat_xf(_drag.at, Motion.LIFT_SCALE)
		b.stroke(_xf_pts(xf, hull_points(i, 0.09 * U)), U * 0.06, Pal.BAD, true)
		for k in Rules.FLEET[i]:
			var m := xf * Vector2(k * U, 0.0)
			b.stroke(PackedVector2Array([m + Vector2(-0.2, -0.2) * U, m + Vector2(0.2, 0.2) * U]), U * 0.07, Pal.BAD)
			b.stroke(PackedVector2Array([m + Vector2(0.2, -0.2) * U, m + Vector2(-0.2, 0.2) * U]), U * 0.07, Pal.BAD)
	for c in Rules.CELLS:
		var mark: int = pond.marks[c]
		if mark == Rules.UNKNOWN or _due.has(c):
			continue
		var m := _mid(c)
		var age := _t - float(_born[0].get(c, -10.0))
		if mark == Rules.MISS:
			var pop := Motion.pop_in_scale(age).x if age < Motion.POP_IN else 1.0
			b.stroke(Face.Builder.ring(m, U * 0.2 * pop, U * 0.2 * pop), U * 0.04, Color(1, 1, 1, 0.72), true)
			b.disc(m, U * 0.05 * pop, Color(1, 1, 1, 0.72))
			if age < SPLASH:
				var u := age / SPLASH
				b.stroke(Face.Builder.ring(m, U * (0.2 + 0.6 * u), U * (0.2 + 0.6 * u)), U * 0.05, Color(1, 1, 1, 0.8 * (1.0 - u)), true)
		elif age < SPLASH:
			var u := age / SPLASH
			b.stroke(Face.Builder.ring(m, U * (0.25 + 0.5 * u), U * (0.25 + 0.5 * u)), U * 0.06, Color(PEG_LIT, 0.8 * (1.0 - u)), true)
	for i in Rules.FLEET.size():
		if not _sank[0].has(i):
			continue
		var u := (_t - float(_sank[0][i])) / SINK_TIME
		if u >= 1.0 or u < 0.0:
			continue
		var cells := Rules.cells_of(i, pond.boats[i])
		for k in cells.size():
			var at := _mid(cells[k]) + Vector2(sin(u * 9.0 + k) * 16.0, -u * 30.0)
			var r := U * (0.08 + 0.1 * fmod(u * 3.0 + k * 0.4, 1.0))
			b.stroke(Face.Builder.ring(at, r, r), U * 0.02, Color(1, 1, 1, 0.75 * (1.0 - u)), true)
	return _mesh_of(b)

## The chart's marks: a blue ring for a miss, a red pin for a hit, a sunk
## boat's hull, the row and column under the finger, the square thrown at.
func _build_chart_live() -> ArrayMesh:
	var b := Face.Builder.new()
	if not _glass.is_empty():
		var o := BORDER * U
		var at := Rules.xy(int(_glass.c))
		var x0 := maxi(at.x - 1, 0)
		var y0 := maxi(at.y - 1, 0)
		var x1 := mini(at.x + 2, Rules.N)
		var y1 := mini(at.y + 2, Rules.N)
		b.stroke(Face.Builder.round_rect(Vector2(o + x0 * U, o + y0 * U) + Vector2.ONE * U * 0.04, Vector2((x1 - x0) * U, (y1 - y0) * U) - Vector2.ONE * U * 0.08, U * 0.16), U * 0.05, Color("2f6d6a"), true)
	if _over >= 0:
		var at := Rules.xy(_over)
		var o := BORDER * U
		var open: bool = _reachable(_over)
		var band := Color(INK, 0.16 if open else 0.07)
		b.fan(PackedVector2Array([Vector2(o, o + at.y * U), Vector2(SIDE - o, o + at.y * U), Vector2(SIDE - o, o + (at.y + 1) * U), Vector2(o, o + (at.y + 1) * U)]), band)
		b.fan(PackedVector2Array([Vector2(o + at.x * U, o), Vector2(o + (at.x + 1) * U, o), Vector2(o + (at.x + 1) * U, SIDE - o), Vector2(o + at.x * U, SIDE - o)]), band)
		if armed != 0:
			for q in Tricks.cover(armed, _over):
				var p := Rules.xy(q)
				b.stroke(Face.Builder.round_rect(Vector2(o + p.x * U, o + p.y * U) + Vector2.ONE * U * 0.08, Vector2.ONE * U * 0.84, U * 0.14), U * 0.07, HINT.darkened(0.15), true)
		elif open:
			b.stroke(Face.Builder.round_rect(Vector2(o + at.x * U, o + at.y * U) + Vector2.ONE * U * 0.06, Vector2.ONE * U * 0.88, U * 0.14), U * 0.08, PEG, true)
	for i in Rules.FLEET.size():
		var boat: Vector3i = slate.boats[i]
		var found := boat.x >= 0
		if not found and i < _fleet.size():
			boat = _fleet[i]
		if boat.x < 0:
			continue
		var age := _t - float(_sank[1].get(i, -10.0))
		var grow := 1.0 + 0.12 * Motion.flash_level(age) if found else 1.0
		var xf := _boat_xf(boat, grow)
		var pts := _xf_pts(xf, hull_points(i))
		if found:
			b.fan(pts, Color(PAINT[i], 0.4))
			b.stroke(pts, U * 0.055, INK, true)
		else:
			# Never found: dashed, so it is not read as one that was sunk.
			for k in range(0, pts.size() - 1, 2):
				b.stroke(PackedVector2Array([pts[k], pts[k + 1]]), U * 0.05, INK)
	for c in Rules.CELLS:
		var mark: int = slate.marks[c]
		if mark == Rules.UNKNOWN:
			continue
		var m := _mid(c)
		var age := _t - float(_born[1].get(c, -10.0))
		var pop := Motion.pop_in_scale(age).x if age < Motion.POP_IN else 1.0
		if mark == Rules.MISS:
			b.stroke(Face.Builder.ring(m, U * 0.22 * pop, U * 0.22 * pop), U * 0.075, Color(INK, 0.85), true)
		else:
			# A pin; on a hatch as well as a colour, so it reads in the folded corner.
			b.disc(m + Vector2(0.05, 0.08) * U, U * 0.26 * pop, Color(0.2, 0.1, 0.05, 0.28))
			b.disc(m, U * 0.28 * pop, PEG)
			b.disc(m + Vector2(-0.08, -0.08) * U, U * 0.11 * pop, PEG_LIT)
	if _aim >= 0:
		var m := _mid(_aim)
		var beat := 0.5 + 0.5 * sin(_t * 9.0)
		b.disc(m, U * (0.12 + 0.05 * beat), INK)
	if _hint >= 0 and slate.marks[_hint] == Rules.UNKNOWN:
		var m := _mid(_hint)
		b.stroke(Face.Builder.ring(m, U * 0.36, U * 0.36), U * 0.09, HINT.darkened(0.08), true)
		b.disc(m, U * 0.1, HINT.darkened(0.08))
	# The fleet strip: the five to sink, crossed out as they go.
	var y := SIDE + STRIP * 0.32
	var scale_by := 0.42
	var x := BORDER * U + 0.2 * U
	for i in Rules.FLEET.size():
		var n: int = Rules.FLEET[i]
		var xf := Transform2D(0.0, Vector2.ONE * scale_by, 0.0, Vector2(x, y))
		var pts := _xf_pts(xf, hull_points(i))
		if slate.sunk[i]:
			b.fan(pts, Color(INK, 0.22))
			b.stroke(PackedVector2Array([xf * Vector2(-0.6 * U, 0.0), xf * Vector2((n - 1) * U + 0.6 * U, 0.0)]), U * 0.07, PEG)
		else:
			b.fan(pts, Color(PAINT[i], 0.75))
			b.stroke(pts, U * 0.03, INK, true)
		x += (n + 0.6) * U * scale_by + 0.12 * U
	return _mesh_of(b)

## The player's own marks. Rebuilt when one changes, never otherwise.
func _build_plan() -> ArrayMesh:
	var b := Face.Builder.new()
	for s: Dictionary in _stencils:
		var i: int = s.i
		var boat: Vector3i = s.b
		var xf := _boat_xf(boat)
		var pts := _xf_pts(xf, hull_points(i))
		var ok := true
		for c in Rules.cells_of(i, boat):
			if slate.marks[c] == Rules.MISS or slate.boat_at(c) >= 0:
				ok = false
		var ink: Color = PAINT[i].darkened(0.2)
		for k in range(0, pts.size() - 1, 2):
			b.stroke(PackedVector2Array([pts[k], pts[k + 1]]), U * 0.05, ink)
		if not ok:
			for c in Rules.cells_of(i, boat):
				var m := _mid(c)
				for d in 3:
					var o := (d - 1) * 0.22 * U
					b.stroke(PackedVector2Array([m + Vector2(-0.2 * U + o, 0.2 * U), m + Vector2(0.2 * U + o, -0.2 * U)]), U * 0.03, Color(Pal.BAD, 0.8))
	for c: int in _flags:
		var m := _mid(c)
		b.stroke(PackedVector2Array([m + Vector2(-0.12, 0.32) * U, m + Vector2(-0.12, -0.32) * U]), U * 0.05, WOOD_DEEP)
		b.polygon(PackedVector2Array([m + Vector2(-0.1, -0.34) * U, m + Vector2(0.3, -0.18) * U, m + Vector2(-0.1, -0.02) * U]), PEG)
	for line: PackedVector2Array in _strokes:
		if line.size() >= 2:
			b.stroke(line, U * 0.05, PENCIL_INK)
	return _mesh_of(b)

## What is in the air, in the control's own space, over everything.
func _build_air() -> ArrayMesh:
	var b := Face.Builder.new()
	if not _climb.is_empty():
		var u := clampf((_t - float(_climb.at) - 0.0) / CLIMB, 0.0, 1.0)
		if u < 1.0:
			var at: Vector2 = (_climb.from as Vector2).lerp(_climb.to, u * (2.0 - u))
			var r := lerpf(24.0, 9.0, u)
			b.disc(at, r, PEBBLE)
			b.disc(at + Vector2(-0.25, -0.3) * r, r * 0.5, PEBBLE_LIT)
	for p: Dictionary in _pebbles:
		var u := clampf((_t - float(p.at)) / maxf(float(p.fall), 0.001), 0.0, 1.0)
		var m := point_of(0, int(p.c))
		var e := u * u
		var s := _unit(0)
		Scenery.soft_disc(b, m + Vector2(4.0, 8.0), s * lerpf(0.75, 0.3, e), s * lerpf(0.55, 0.24, e), Color(0.03, 0.1, 0.2, lerpf(0.12, 0.5, u)))
		var from := Vector2(m.x - 30.0, -60.0)
		var at := from.lerp(m, e)
		var r := s * lerpf(0.46, 0.2, e)
		b.disc(at, r, PEBBLE)
		b.disc(at + Vector2(-0.25, -0.3) * r, r * 0.5, PEBBLE_LIT)
	return _mesh_of(b)
