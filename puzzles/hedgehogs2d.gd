extends "res://core/puzzle_base.gd"

## Hedgehogs as a flat board: an autumn lawn under leaf piles, with
## hedgehogs asleep under some of them. Rake a pile and the grass under it
## shows how many hedgehogs sleep in the eight cells around; a nought blows
## its neighbours clear. Flag the piles a hedgehog must be under. Rake every
## bare cell and the day is done. A wrong rake is never a loss: the hedgehog
## wakes, curls up grumpy on a rose cell, and the day goes on. The rules live
## in puzzles/hedgehogs_state.gd, which this only draws.
##
## **The gust is this board's signature.** A raked cell's leaves blow off
## when the gust reaches it -- its flood ring times Motion.WAVE_STEP after the
## rake -- flying away from the cell that was raked, and its number pops in
## just after.
##
## How it is drawn. Three meshes and some text:
##   lawn  -- the setting: the card's grass, fallen leaves, acorns and a
##            toadstool in the margins, and the wooden bed round the grid.
##            Built once a layout, outside the entrance's grow.
##   still -- every cell at rest: its ground, its pile, its flag, in bands
##            of BAND rows, one mesh a band. A band is rebuilt only when the
##            look of one of its cells changes (`_band_looks`), so a cell
##            settling redraws its own few rows and not a hundred piles.
##   live  -- every cell with something moving on it (a gust, a pile popping
##            back in, a flag dropping in, a refusal's shiver, the breeze),
##            the rake's stroke, the gust's wind, the hint's ring and the
##            win's swirl. Rebuilt only while something moves.
##   the numbers and the tally line are drawn text, one draw_set_transform a
##            cell (Mushroom Patch's precedent).
## The woken hedgehogs, and on the win every hedgehog, are HedgehogFace nodes
## in slots of their own (docs/art/flat-motion.md rule 2). The pile and the
## flag are ui/faces/leaf_pile.gd, which the tray and the menu card draw too.
##
## Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#hedgehogs, the
## reference for every measure.

const State = preload("res://puzzles/hedgehogs_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const HedgehogFace = preload("res://ui/faces/hedgehog_face.gd")
const Lawn = preload("res://ui/faces/leaf_pile.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Rings = preload("res://puzzles/rings2d.gd")

# --- the lawn ---
## The card's inset round the lawn, and the tally strip over it.
const PAD := 44.0
const TALLY := 72.0
const TALLY_SIZE := 34
const TALLY_GLYPH := 60.0
const TALLY_GAP := 14.0
## The numeral, as a fraction of a cell.
const NUM_SIZE := 0.54
## A flag's R, and a hint's sun dot at its foot, as fractions of a cell.
const FLAG_R := 0.46
const PIN_DOT := 0.06
## A hedgehog's seat, as a fraction of a cell.
const SEAT := 1.0
## The card's rounded corner (ui/flat/flat_host.gd's stylebox, Rings'
## CARD_RADIUS), and the wooden bed round the grid: its width, its corner,
## and the soil between the cells.
const CARD_RADIUS := 32.0
const FRAME := 14.0
const FRAME_R := 20.0
const SOIL := Color("b89a6e")
## How many leaves, acorns and toadstools the margins try to hold.
const LITTER := 22
## The still mesh is cut into bands of this many rows.
const BAND := 3

# --- the motion ---
## The gust: how long a pile's leaves take to go, and how long after they go
## the number pops in.
const LEAF_TIME := 0.45
const NUM_LAG := 0.12
## A flag shrinks out over this; one drops in from this high (in cells)
## over FLAG_DROP, and the pile under it is pressed down over the same.
const FLAG_OUT := 0.2
const FLAG_DROP := 0.26
const FLAG_FALL := 0.4
## How long the pennant shakes after the thunk.
const FLAG_FLUTTER := 0.2
## The rake's stroke across the cell it rakes, and how far into it the
## leaves go.
const RAKE_TIME := 0.3
const RAKE_LEAD := 0.12
## A flood bigger than GUST_CELLS draws this many streaks of wind out of
## the raked cell.
const STREAKS := 5
## The breeze: one row's piles rustle, a cell after another, every
## BREEZE_MIN..BREEZE_MAX seconds, and a woken hedgehog may peek meanwhile.
const BREEZE_MIN := 4.0
const BREEZE_MAX := 7.0
const BREEZE_STEP := 0.07
const RUSTLE_TIME := 0.7
const PEEK_TIME := 1.1
## The tally's sleeper breathes, and lets out a z every Z_EVERY seconds.
const BREATH := 2.6
const Z_EVERY := 3.4
const Z_TIME := 1.8
## The win's swirl of leaves across the lawn.
const SWIRL_LEAVES := 26
const SWIRL_TIME := 1.8
## An Undo re-covers its flood back to front, this apart.
const UNDO_STEP := 0.012
## How long a press must be held to do the other chip's action.
const LONG_PRESS := 0.4
## The win: the sleepers' wave starts this long after the last rake, and
## the win screen waits this long after the wave.
const WIN_LEAD := 0.3
const WIN_WAIT := 2.2
const HINTS := 3
## A flood bigger than this sounds a gust rather than a rake.
const GUST_CELLS := 6
## The toast: Knight's and Rings' measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0
const TIP_CYCLE := 8.0
const TIPS := ["HH_TIP_RAKE", "HH_TIP_NUMBER", "HH_TIP_FLAG", "HH_TIP_CHORD", "HH_TIP_WOKE"]

var _state = State.new()
var fx: Node2D
## The armed chip, read by the tray (ui/flat/tile_tray.gd's refresh).
var brush: int = State.RAKE

## Per cell: when the gust reaches it (its leaves go), the cell it blows
## from, when an Undo or a Reset re-covered it, when a flag went in or out,
## when it was refused, and when anything on it stops moving.
var _blow_at := PackedFloat64Array()
var _blow_from := PackedInt32Array()
var _cover_at := PackedFloat64Array()
var _flag_at := PackedFloat64Array()
var _unflag_at := PackedFloat64Array()
var _bump_at := PackedFloat64Array()
var _rustle_at := PackedFloat64Array()
var _until := PackedFloat64Array()
## The rake's strokes, the gust's streaks: {pos, at} and {from, dir, reach,
## at, time}.
var _rakes: Array = []
var _streaks: Array = []
## The win's swirl starts at this; below zero there is none.
var _swirl_at := -100.0
var _next_breeze := 0.0
## The still mesh's bands, and the looks each was built from.
var _bands: Array = []
var _band_looks: Array = []
var _lawn: ArrayMesh
var _z_label: Label
var _z_tw: Tween
## Cells with something moving on them: cell -> true. They are drawn in the
## live mesh and left out of the still one until they settle.
var _moving := {}
## HedgehogFace per cell, each in a slot of its own: cell -> face, face -> slot.
var _faces := {}
var _slots := {}
var _tally_face: Control
var _rings: Array = []
## The last cell raked, where the win's wave starts.
var _last := 0
## Which deal the timers belong to: a new build bumps it and a stale timer
## does nothing.
var _turn := 0

var _opened := 0.0
## Input waits for the entrance.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _cell := 0.0
var _grid := Vector2.ZERO
var _tally_y := 0.0
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
## The press in progress: its cell, and whether its long press has fired.
var _press_cell := -1
var _press_id := 0
## The finger holding the press (-1 the mouse), -2 with no press; a second
## finger neither starts a press nor ends the first's.
var _press_finger := -2
## Whether the move being shown is a hint's, which counts no move.
var _hinting := false
var _long_fired := false
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
var _toast := ""
var _toast_arg := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "hedgehogs"
func title() -> String: return "Hedgehogs"

func rules() -> String:
	return tr("HH_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.setup(rng, difficulty)
	_turn += 1
	brush = State.RAKE
	var n: int = _state.size()
	for a in [_blow_at, _cover_at, _flag_at, _unflag_at, _bump_at, _rustle_at, _until]:
		a.resize(n)
		a.fill(-100.0)
	_blow_from.resize(n)
	_blow_from.fill(-1)
	_moving = {}
	_bands = []
	_clear_faces()
	_rings = []
	_rakes = []
	_streaks = []
	_swirl_at = -100.0
	_solved_at = -1.0
	_press_cell = -1
	_press_finger = -2
	_toast = ""
	_toast_at = -100.0
	_last = int(_state.g.start)
	_opened = _now()
	# The opening's gust plays once the card has popped in.
	var gust_at := _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY + Motion.ENTER_POP)
	var opening := PackedByteArray()
	opening.resize(n)
	var flood: Array[Vector2i] = State.Gen.flood(_state.g, opening, _state.g.start)
	_gust_cells(flood, int(_state.g.start), gust_at, 0)
	_busy_until = gust_at
	_next_breeze = gust_at + randf_range(BREEZE_MIN, BREEZE_MAX)
	if _tally_face == null:
		_tally_face = HedgehogFace.new()
		_tally_face.expression = Face.Expr.SLEEPY
		_tally_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tally_face)
		Motion.pulse(_tally_face, "scale", Vector2.ONE, Vector2(1.05, 0.95), BREATH)
	_start_z()
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

func _clear_faces() -> void:
	for face in _faces.values():
		var slot: Control = _slots[face]
		slot.queue_free()
	_faces = {}
	_slots = {}

# --- layout ---

func _cell_for(available: float) -> float:
	if _state.size() == 0:
		return 0.0
	return maxf(0.0, minf((size.x - 2.0 * PAD) / float(_state.cols()),
		(available - 2.0 * PAD - TALLY) / float(_state.rows())))

func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * float(_state.rows()) + 2.0 * PAD + TALLY)

func card_centred() -> bool:
	return true

func _layout() -> void:
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field := Vector2(_state.cols(), _state.rows()) * _cell
	var tall := minf(size.y, field.y + 2.0 * PAD + TALLY)
	var top := (size.y - tall) * 0.5
	_grid = Vector2(size.x * 0.5 - field.x * 0.5, top + PAD + TALLY)
	_tally_y = top + PAD + TALLY * 0.5
	for c: int in _faces:
		_seat(_faces[c], _centre(c))
	if _tally_face != null:
		_tally_face.size = Vector2.ONE * TALLY_GLYPH
		_tally_face.pivot_offset = Vector2(TALLY_GLYPH * 0.5, TALLY_GLYPH * 0.8)
	_bands = []
	_lawn = null
	_refresh()

func _centre(c: int) -> Vector2:
	return _grid + (Vector2(c % _state.cols(), c / _state.cols()) + Vector2(0.5, 0.5)) * _cell

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols() + c)

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var v := (local - _grid) / _cell
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.cols() or y >= _state.rows():
		return -1
	return y * _state.cols() + x

## A hedgehog seated on the cell `centre`, in a slot of its own so the pop
## and the hop never fight the layout.
func _seat(face: Control, centre: Vector2) -> void:
	var seat := Vector2.ONE * _cell * SEAT
	var slot: Control = _slots[face]
	slot.size = seat
	slot.position = centre - seat * 0.5
	face.size = seat
	face.pivot_offset = seat * 0.5

func _face_at(c: int, expr: int) -> Control:
	if _faces.has(c):
		var have: Control = _faces[c]
		have.expression = expr
		return have
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	var face := HedgehogFace.new()
	face.expression = expr
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(face)
	_faces[c] = face
	_slots[face] = slot
	_seat(face, _centre(c))
	return face

# --- the moments ---

## Marks `c` as moving until `until`: drawn live, left out of the still mesh.
func _touch(c: int, until: float) -> void:
	_until[c] = maxf(_until[c], until)
	_moving[c] = true
	_busy_for(until - _now())

## A flood's gust: each cell's leaves go at its ring (offset by `ring0`)
## times WAVE_STEP after `at`, blowing away from `from`.
func _gust_cells(flood: Array, from: int, at: float, ring0: int) -> void:
	for p: Vector2i in flood:
		var when := at + (0.0 if Motion.reduce else float(p.y + ring0) * Motion.WAVE_STEP)
		_blow_at[p.x] = when
		_blow_from[p.x] = from
		_touch(p.x, when + LEAF_TIME + NUM_LAG + Motion.POP_IN)

## `lead` holds the leaves back while the rake's stroke gets into the pile.
func _gust(cells: PackedInt32Array, rings: PackedInt32Array, from: int, lead := 0.0) -> void:
	var t := _now() + lead
	var flood: Array = []
	var far := 0
	for i in cells.size():
		flood.append(Vector2i(cells[i], rings[i]))
		far = maxi(far, rings[i])
	_gust_cells(flood, from, t, 0)
	if not cells.is_empty():
		_last = cells[cells.size() - 1]
		fx.cue("gust" if cells.size() > GUST_CELLS else "rake")
	if cells.size() > GUST_CELLS and not Motion.reduce:
		_wind(from, far, t)

## Streaks of wind out of the cell `from`, as far as the flood's last ring.
func _wind(from: int, far: int, at: float) -> void:
	var turn := Lawn.h01(from, _turn) * TAU
	var time := minf(1.1, float(far) * Motion.WAVE_STEP + 0.45)
	for k in STREAKS:
		var dir := Vector2.from_angle(turn + TAU * float(k) / float(STREAKS) + (Lawn.h01(from, k) - 0.5) * 0.6)
		_streaks.append({"from": _centre(from), "dir": dir, "reach": _cell * (float(far) * 0.55 + 1.2) * (0.75 + 0.35 * Lawn.h01(k, from)),
			"at": at + float(k) * 0.03, "time": time, "bend": (Lawn.h01(k + 5, from) - 0.5) * 2.0})
	_busy_for(at - _now() + time + float(STREAKS) * 0.03)

## The rake's stroke across the cell `c`.
func _rake_stroke(c: int) -> void:
	if Motion.reduce:
		return
	_rakes.append({"pos": _centre(c), "at": _now()})
	_busy_for(RAKE_TIME)

## A hedgehog a rake woke: its cell washes rose, it pops in curled and
## shivers, and the toast says so kindly.
func _wake(c: int, lead := 0.0) -> void:
	var t := _now() + lead
	_blow_at[c] = t
	_blow_from[c] = c
	_touch(c, t + LEAF_TIME)
	var face := _face_at(c, Face.Expr.STRAIN)
	if not Motion.reduce:
		face.scale = Vector2.ZERO
	Motion.pop_in(face, Motion.POP_IN, lead)
	# Bristles once it is in, then shivers, and huffs a puff of dust.
	Motion.shiver(face, Motion.SHIVER_PX * 3.0, Motion.SHIVER_TIME * 2.0)
	if not Motion.reduce:
		# bump reads the scale it starts from, so it waits for the pop.
		_later(lead + Motion.POP_IN, func():
			Motion.bump(face, 0.16)
			fx.puff(_centre(c) + Vector2(-_cell * 0.3, -_cell * 0.1), Pal.PAPER, 4))
	fx.cue("woke")
	_tell("HH_WOKE_FIRST" if _state.woken == 1 else "HH_WOKE_AGAIN", Face.Expr.STRAIN)

func _refuse(c: int, key: String) -> void:
	_bump_at[c] = _now()
	_touch(c, _now() + Motion.SHIVER_TIME)
	fx.cue("refuse")
	_tell(key, Face.Expr.STRAIN)

## One tap's worth on cell `c`, with the rake or the flag. A raked number
## always chords.
func _act(c: int, use: int) -> void:
	if is_done() or c < 0 or _now() < _busy_until:
		return
	if _state.open[c] == 1:
		# Raked, but its gust has not reached it yet: it still looks
		# covered, so a tap there waits rather than chording.
		if _now() < float(_blow_at[c]):
			return
		_show_chord(_state.chord(c), c)
		return
	if use == State.FLAG:
		var f: Dictionary = _state.toggle_flag(c)
		match String(f.kind):
			"laid":
				_flag_at[c] = _now()
				_touch(c, _now() + FLAG_DROP + Motion.BUMP_TIME)
				fx.cue("flag")
				_after_move()
			"lifted":
				_unflag_at[c] = _now()
				_touch(c, _now() + FLAG_OUT)
				fx.cue("unflag")
				_after_move()
			"refused_pin":
				_refuse(c, "HH_PINNED")
		return
	_show_rake(_state.rake(c), c)

func _show_rake(r: Dictionary, c: int) -> void:
	match String(r.kind):
		"raked":
			_rake_stroke(c)
			_gust(r.cells, r.rings, c, 0.0 if Motion.reduce else RAKE_LEAD)
			_after_move()
		"woke":
			_last = c
			_rake_stroke(c)
			_wake(c, 0.0 if Motion.reduce else RAKE_LEAD)
			_after_move()
		"refused_flag":
			_refuse(c, "HH_FLAGGED")
		"refused_pin":
			_refuse(c, "HH_PINNED")
		"chord", "too_few", "too_many":
			_show_chord(r, c)

func _show_chord(r: Dictionary, c: int) -> void:
	match String(r.kind):
		"chord":
			_gust(r.cells, r.rings, c)
			for w: int in r.woke:
				_wake(w)
			fx.cue("chord")
			_after_move()
		"too_few":
			_refuse(c, "HH_CHORD_FEW")
		"too_many":
			_refuse(c, "HH_CHORD_MANY")

## A move counts (note_move emits `moved` and checks the solve); a hint's
## does not, so it emits and checks for itself, as PuzzleBase's contract has
## it.
func _after_move() -> void:
	if _hinting:
		moved.emit()
		check_solved()
	else:
		note_move()
	_refresh()

## Runs `fn` after `delay`, unless the board has left the tree meanwhile or
## a new deal has begun.
func _later(delay: float, fn: Callable) -> void:
	var turn := _turn
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if is_inside_tree() and turn == _turn:
			fn.call())

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	# A band a frame while the card is still hidden before its entrance, so
	# the first frame it shows does not pay for a hundred piles at once.
	if t - _opened < Motion.ENTER_DELAY and not Motion.reduce:
		_update_bands(t, 1)
	var settled := false
	for c: int in _moving.keys():
		if float(_until[c]) <= t:
			_moving.erase(c)
			settled = true
	if t >= _next_breeze:
		_breeze(t)
	if settled or _animating(t):
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		queue_redraw()

## The breeze: one row's piles rustle, a cell after another, and a woken
## hedgehog may peek out of its ball. Every covered pile takes it alike, so
## it says nothing about what sleeps under which.
func _breeze(t: float) -> void:
	_next_breeze = t + randf_range(BREEZE_MIN, BREEZE_MAX)
	if Motion.reduce or is_done() or _cell <= 0.0:
		return
	var cols: int = _state.cols()
	var row := randi() % _state.rows()
	var from_left := randf() < 0.5
	for x in cols:
		var c := row * cols + x
		if _shows_raked(c, t):
			continue
		var when := t + float(x if from_left else cols - 1 - x) * BREEZE_STEP
		_rustle_at[c] = when
		_touch(c, when + RUSTLE_TIME)
	if not _faces.is_empty() and randf() < 0.6:
		var cells := _faces.keys()
		var face: Control = _faces[cells[randi() % cells.size()]]
		if face.expression == Face.Expr.STRAIN:
			face.expression = Face.Expr.WORRIED
			_later(PEEK_TIME, func():
				if face.expression == Face.Expr.WORRIED:
					face.expression = Face.Expr.STRAIN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func _animating(t: float) -> bool:
	if not _moving.is_empty() or t < _anim_until:
		return true
	if Motion.reduce:
		return false
	return t - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP + 0.1

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds + 0.05)

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid + Vector2(_state.cols(), _state.rows()) * _cell * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _lawn == null:
		_lawn = _build_lawn()
	draw_mesh(_lawn, null)
	_update_bands(t)
	if _live == null:
		_live = _build_live(t)
	var shown: Array = [_lawn]
	for m in _bands + [_live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	_draw_tally(t, seen)
	_draw_toast(t, shown)
	_shown = shown

## The setting, built once a layout: the card's autumn grass in mown bands,
## soft shade, fallen leaves, acorns and a toadstool in the margins (never
## under the bed or behind the tally's words), and the wooden bed round the
## grid with soil showing between its cells.
func _build_lawn() -> ArrayMesh:
	var b := Face.Builder.new()
	var w := size.x
	var h := size.y
	var clip := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	var grass := Pal.LAWN.lerp(Pal.PAPER, 0.62)
	Rings._clip_polygon(b, clip, grass, clip)
	var band := 84.0
	for k in int(ceil(h / band)):
		if k % 2 == 1:
			Rings._clip_polygon(b, PackedVector2Array([Vector2(0.0, k * band), Vector2(w, k * band),
				Vector2(w, (k + 1) * band), Vector2(0.0, (k + 1) * band)]), Pal.LAWN.lerp(Pal.PAPER, 0.56), clip)
	var seed_i: int = _state.cols() * 97 + _state.rows() * 13 + int(_state.g.start)
	for d in 6:
		var at := Vector2(w * Lawn.h01(seed_i, d + 200), h * Lawn.h01(seed_i, d + 300))
		Scenery.soft_disc(b, at, 110.0, 70.0, Color(Pal.LAWN_DEEP, 0.08))
	var field := Vector2(_state.cols(), _state.rows()) * _cell
	var bed := Rect2(_grid - Vector2.ONE * (FRAME + 18.0), field + Vector2.ONE * (FRAME + 18.0) * 2.0)
	var words := Rect2(w * 0.5 - 260.0, _tally_y - 40.0, 520.0, 80.0)
	var placed := 0
	for f in LITTER * 4:
		if placed >= LITTER:
			break
		var at := Vector2(30.0 + (w - 60.0) * Lawn.h01(seed_i, f + 500), 30.0 + (h - 60.0) * Lawn.h01(seed_i, f + 600))
		if bed.has_point(at) or words.has_point(at):
			continue
		var pick := Lawn.h01(seed_i, f + 700)
		if pick < 0.08:
			Lawn.toadstool(b, at, 15.0)
		elif pick < 0.2:
			Lawn.acorn(b, at, 10.0, (Lawn.h01(f, 3) - 0.5) * 1.6)
		elif pick < 0.35:
			Scenery.tuft(b, at, 18.0 + 8.0 * Lawn.h01(f, 4))
		else:
			var colour: Color = Pal.AUTUMN_LEAVES[f % Pal.AUTUMN_LEAVES.size()]
			var rot := Lawn.h01(f, 5) * TAU
			Lawn.leaf(b, at + Vector2(2.0, 3.0), 30.0, rot, Color(Pal.TEXT, 0.1), f % 3)
			Lawn.leaf(b, at, 30.0 + 8.0 * Lawn.h01(f, 6), rot, colour.lerp(grass, 0.25), f % 3)
		placed += 1
	# The bed: a shadow, the frame with its grain, then soil.
	var out := _grid - Vector2.ONE * FRAME
	var out_size := field + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 6.0), out_size.x * 0.55, 26.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 5.0), out_size, FRAME_R), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(out + Vector2.ONE * 2.5, out_size - Vector2.ONE * 5.0, FRAME_R - 2.5), Pal.WOOD)
	var grain := Color(Pal.PLAQUE_DEEP, 0.25)
	var mid := FRAME * 0.5
	for k: float in [-1.0, 1.0]:
		var off := k * 2.5
		b.stroke(PackedVector2Array([_grid + Vector2(field.x * 0.08, -mid + off), _grid + Vector2(field.x * 0.4, -mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(field.x * 0.58, field.y + mid + off), _grid + Vector2(field.x * 0.93, field.y + mid + off)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(-mid + off, field.y * 0.3), _grid + Vector2(-mid + off, field.y * 0.7)]), 1.5, grain)
		b.stroke(PackedVector2Array([_grid + Vector2(field.x + mid + off, field.y * 0.12), _grid + Vector2(field.x + mid + off, field.y * 0.46)]), 1.5, grain)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * 2.0, field + Vector2.ONE * 4.0, FRAME_R - 8.0), Pal.PLAQUE)
	b.fan(Face.Builder.round_rect(_grid, field, FRAME_R - 10.0), SOIL)
	for c in 4:
		var corner := _grid + Vector2(float(c % 2), float(c / 2)) * field + Vector2(-1.0 if c % 2 == 0 else 1.0, -1.0 if c < 2 else 1.0) * mid
		b.disc(corner, 4.0, Pal.PLAQUE_DEEP)
	return b.mesh()

## Rebuilds each band of the still mesh whose cells' looks have changed
## since it was built: every cell with nothing moving on it. At most `limit`
## bands when it is not negative.
func _update_bands(t: float, limit := -1) -> void:
	var cols: int = _state.cols()
	var n := int(ceil(float(_state.rows()) / float(BAND)))
	if _bands.size() != n:
		_bands.resize(n)
		_bands.fill(null)
		_band_looks.resize(n)
		_band_looks.fill(PackedInt32Array())
	for k in n:
		var first := k * BAND * cols
		var last := mini(_state.size(), (k + 1) * BAND * cols)
		var looks := PackedInt32Array()
		looks.resize(last - first)
		for c in range(first, last):
			looks[c - first] = -1 if _moving.has(c) else _look(c, t)
		if _bands[k] != null and looks == _band_looks[k]:
			continue
		if limit == 0:
			return
		limit -= 1
		var b := Face.Builder.new()
		for c in range(first, last):
			if not _moving.has(c):
				_draw_cell(b, c, t)
		_bands[k] = b.mesh() if not b.verts.is_empty() else null
		_band_looks[k] = looks

## Everything a resting cell's drawing depends on.
func _look(c: int, t: float) -> int:
	var raked := 1 if _shows_raked(c, t) else 0
	var up := 1 if _flag_up(c, t) else 0
	return raked | (int(_state.woke[c]) << 1) | (up << 2) | (int(_state.wrong[c]) << 3) | (int(_state.pin[c]) << 4)

## Every moving cell, the rake's strokes, the wind, the win's swirl and the
## hint's ring.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	for c: int in _moving:
		_draw_cell(b, c, t)
	_draw_wind(b, t)
	_draw_swirl(b, t)
	_draw_rakes(b, t)
	var keep: Array = []
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u < 1.0:
			keep.append(r)
		if u >= 0.0 and u < 1.0:
			var rad := _cell * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), _cell * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	_rings = keep
	return b.mesh() if not b.verts.is_empty() else null

## Whether cell `c` shows as raked at `t`: raked (or woken, or a sleeper
## uncovered by the win) and the gust has reached it.
func _shows_raked(c: int, t: float) -> bool:
	var uncovered: bool = _state.open[c] == 1 or _state.woke[c] == 1 \
		or (_solved_at >= 0.0 and _state.is_hog(c))
	return uncovered and t >= float(_blow_at[c])

## One cell: its ground, its pile at rest, rustling or blowing off, its flag.
func _draw_cell(b: Face.Builder, c: int, t: float) -> void:
	var s := _cell
	var at := _centre(c)
	at.x += Motion.shiver_offset(t - float(_bump_at[c]), s * 0.03)
	var raked := _shows_raked(c, t)
	Lawn.ground(b, at, s, c, raked, _state.woke[c] == 1)
	var rustle := _rustle(c, t)
	if raked:
		var u := 1.0 if Motion.reduce else (t - float(_blow_at[c])) / LEAF_TIME
		if u < 1.0:
			Lawn.pile(b, at, s, c, maxf(u, 0.001), _blow_dir(c), _press(c, t))
	else:
		var cover := t - float(_cover_at[c])
		var sc := Motion.pop_in_scale(cover) if cover >= 0.0 and cover < Motion.POP_IN else Vector2.ONE
		var pressed := _press(c, t)
		# The pile sits on its foot, so a press squashes it down, not in.
		var foot := at + Vector2(0.0, s * 0.3 * (1.0 - pressed.y))
		Lawn.pile(b, foot, s, c, 0.0, Vector2.UP, sc * pressed, 1.0, rustle)
	_draw_flag(b, c, at, t, rustle)

## The breeze through cell `c` at `t`: 0 still, 0..1 while it passes.
func _rustle(c: int, t: float) -> float:
	var u := (t - float(_rustle_at[c])) / RUSTLE_TIME
	return u if u > 0.0 and u < 1.0 else 0.0

## How far a flag presses its pile down: none without one, PRESSED once it
## has landed with a squash, easing back as it is pulled out.
func _press(c: int, t: float) -> Vector2:
	if Motion.reduce:
		return Lawn.PRESSED if _flag_up(c, t) else Vector2.ONE
	if _flag_up(c, t):
		var since := t - float(_flag_at[c]) - FLAG_DROP
		if since < 0.0:
			return Vector2.ONE
		var squash := 1.0 - (Motion.bump_scale(since, 0.14) - 1.0)
		return Lawn.PRESSED * Vector2(2.0 - squash, squash)
	var out := t - float(_unflag_at[c])
	if out >= 0.0 and out < FLAG_OUT:
		return Lawn.PRESSED.lerp(Vector2.ONE, out / FLAG_OUT)
	return Vector2.ONE

## Whether cell `c` shows a flag standing in it at `t`.
func _flag_up(c: int, t: float) -> bool:
	return _state.flag[c] == 1 and _state.woke[c] == 0 and _state.open[c] == 0 \
		and not (_solved_at >= 0.0 and t >= float(_blow_at[c]))

## The rake's stroke: the rake drawn across the cell, pulled toward the
## player and turning as it goes, fading in and out.
func _draw_rakes(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rakes:
		var u := (t - float(r.at)) / RAKE_TIME
		if u >= 1.0:
			continue
		keep.append(r)
		if u < 0.0:
			continue
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		var at: Vector2 = r.pos + Vector2(lerpf(0.28, -0.22, e), lerpf(-0.18, 0.02, e)) * _cell
		var a := minf(1.0, u / 0.15) * minf(1.0, (1.0 - u) / 0.3)
		Lawn.rake(b, at, _cell * 0.8, lerpf(-0.15, -0.75, e), a)
	_rakes = keep

## The gust's wind: curved streaks running out of the raked cell, a head and
## a fading tail.
func _draw_wind(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for w: Dictionary in _streaks:
		var u := (t - float(w.at)) / float(w.time)
		if u >= 1.0:
			continue
		keep.append(w)
		if u <= 0.0:
			continue
		var dir: Vector2 = w.dir
		var side := Vector2(-dir.y, dir.x) * float(w.bend)
		var reach: float = w.reach
		var head := minf(1.0, u * 1.25)
		var tail := maxf(0.0, u * 1.25 - 0.45)
		# A soft curving streak that ends in a little curl, cut where it
		# would leave the lawn.
		var field := Rect2(_grid, Vector2(_state.cols(), _state.rows()) * _cell)
		var pts := PackedVector2Array()
		for k in 12:
			var q := lerpf(tail, head, float(k) / 11.0)
			var p: Vector2 = w.from + dir * (_cell * 0.35 + reach * q) + side * sin(q * PI * 1.2) * reach * 0.3
			if q > 0.8:
				var curl := (q - 0.8) / 0.2 * PI * 1.4
				p += (dir * sin(curl) + side.normalized() * (1.0 - cos(curl))) * _cell * 0.18
			if not field.has_point(p):
				break
			pts.append(p)
		if pts.size() > 1 and head > tail:
			b.stroke(pts, _cell * 0.065, Color(Pal.PAPER, 0.8 * (1.0 - u)), false, true)
	_streaks = keep

## The win's swirl: leaves spiralling up out of the last cell raked and
## across the lawn, tumbling and fading.
func _draw_swirl(b: Face.Builder, t: float) -> void:
	var u0 := (t - _swirl_at) / SWIRL_TIME
	if u0 <= 0.0 or u0 >= 1.0:
		return
	var from := _centre(_last)
	var span := Vector2(_state.cols(), _state.rows()) * _cell
	for i in SWIRL_LEAVES:
		var d := float(i) / float(SWIRL_LEAVES) * 0.35
		var u := clampf((u0 - d) / (1.0 - d), 0.0, 1.0)
		if u <= 0.0:
			continue
		var hv := Lawn.h01(i, 404)
		var ang := hv * TAU + u * (3.0 + 2.0 * Lawn.h01(i, 405))
		var rad := u * maxf(span.x, span.y) * (0.35 + 0.35 * Lawn.h01(i, 406))
		var at := from + Vector2(cos(ang), sin(ang) * 0.7) * rad + Vector2(0.0, -u * _cell * 1.5)
		var colour: Color = Pal.AUTUMN_LEAVES[i % Pal.AUTUMN_LEAVES.size()]
		var a := minf(1.0, u / 0.1) * (1.0 - u)
		Lawn.leaf(b, at, _cell * 0.3, ang * 1.7, Color(colour, a), i % 3, 0.3 + 0.7 * absf(cos(u * 8.0 + float(i))))

func _blow_dir(c: int) -> Vector2:
	var from: int = _blow_from[c]
	if from < 0 or from == c:
		return Vector2(Lawn.h01(c, 5) - 0.5, -0.6).normalized()
	var d := _centre(c) - _centre(from)
	return d.normalized() if d.length() > 0.001 else Vector2.UP

## A flag drops in from above and thunks into its pile; the breeze flutters
## its pennant.
func _draw_flag(b: Face.Builder, c: int, at: Vector2, t: float, rustle := 0.0) -> void:
	var s := _cell
	var foot := at + Vector2(0.0, s * 0.02)
	if _flag_up(c, t):
		var since := t - float(_flag_at[c])
		var fall := Motion.drop_in_lift(since, s * FLAG_FALL, FLAG_DROP)
		var a := Motion.appear_level(since, Motion.DROP_FADE)
		var wave := sin(rustle * TAU * 1.5) * (1.0 - rustle)
		var landed := since - FLAG_DROP
		if landed > 0.0 and landed < FLAG_FLUTTER and not Motion.reduce:
			# The pennant still shaking from the thunk.
			wave += sin(landed * 30.0) * 0.6 * (1.0 - landed / FLAG_FLUTTER)
		Lawn.flag(b, foot - Vector2(0.0, fall), s * FLAG_R, _state.wrong[c] == 1, Vector2.ONE, a, wave)
		if _state.pin[c] == 1:
			b.disc(at + Vector2(0.3, 0.3) * s, s * PIN_DOT, Pal.SUN)
		return
	var out := t - float(_unflag_at[c])
	if out >= 0.0 and out < FLAG_OUT and not Motion.reduce:
		var k := 1.0 - out / FLAG_OUT
		Lawn.flag(b, foot, s * FLAG_R, false, Vector2(k, k))

## The numerals, over the meshes and inside the entrance pop: one
## draw_set_transform a cell, so each pops in just after its leaves go. A
## nought draws nothing.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(_cell * NUM_SIZE))
	if px <= 0:
		return
	var rise := font.get_ascent(px) * 0.5
	for c in _state.size():
		if _state.open[c] == 0:
			continue
		var v: int = _state.number(c)
		if v <= 0:
			continue
		var since := t - float(_blow_at[c]) - NUM_LAG
		if since < 0.0 and not Motion.reduce:
			continue
		var sc: Vector2 = Motion.pop_in_scale(since) if not Motion.reduce else Vector2.ONE
		var at := _centre(c) + Vector2(Motion.shiver_offset(t - float(_bump_at[c]), _cell * 0.03), _cell * 0.02)
		draw_set_transform_matrix(xf * Transform2D(0.0, sc, 0.0, at))
		var text := str(v)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.NUM_INK[mini(v, Pal.NUM_INK.size() - 1)], seen))
	draw_set_transform(Vector2.ZERO)

## The tally strip: a sleeping hedgehog and how many are still asleep and
## unflagged -- the global count the proof uses, given free. BAD when there
## are more flags than hedgehogs.
func _tally_line() -> String:
	var left: int = _state.flags_left()
	if _solved_at >= 0.0:
		return tr("HH_TALLY_DONE")
	if left < 0:
		return tr("HH_TALLY_OVER_ONE") if left == -1 else tr("HH_TALLY_OVER_N") % -left
	return tr("HH_TALLY_ONE") if left == 1 else tr("HH_TALLY_N") % left

func _draw_tally(t: float, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var line := _tally_line()
	var wide := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE).x
	var run := TALLY_GLYPH + TALLY_GAP + wide
	var start := size.x * 0.5 - run * 0.5
	var ink: Color = Pal.BAD if _state.flags_left() < 0 and _solved_at < 0.0 else Pal.TEXT
	draw_string(font, Vector2(start + TALLY_GLYPH + TALLY_GAP, _tally_y + font.get_ascent(TALLY_SIZE) * 0.4),
		line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TALLY_SIZE, Color(ink, seen))
	if _tally_face != null:
		var want := Vector2(start, _tally_y - TALLY_GLYPH * 0.5)
		if _tally_face.position != want:
			_tally_face.position = want
		_tally_face.modulate.a = seen

## The tally sleeper's z: a Label under its face that drifts up and fades
## every Z_EVERY seconds on a tween of its own, so it never redraws the board.
func _start_z() -> void:
	if _z_label == null:
		_z_label = Label.new()
		_z_label.text = "z"
		_z_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_z_label.add_theme_font_override("font", CozyTheme.display(700))
		_z_label.add_theme_font_size_override("font_size", 24)
		_z_label.add_theme_color_override("font_color", Color(Pal.TEXT, 0.55))
		_tally_face.add_child(_z_label)
	Motion.stop(_z_tw)
	_z_label.visible = not Motion.reduce
	if Motion.reduce:
		return
	var from := Vector2(TALLY_GLYPH * 0.8, -TALLY_GLYPH * 0.1)
	_z_label.position = from
	_z_label.modulate.a = 0.0
	_z_tw = _z_label.create_tween().set_loops()
	_z_tw.tween_interval(Z_EVERY - Z_TIME)
	_z_tw.tween_callback(func():
		_z_label.position = from
		_z_label.scale = Vector2.ONE * 0.8)
	_z_tw.tween_property(_z_label, "modulate:a", 1.0, Z_TIME * 0.2)
	_z_tw.parallel().tween_property(_z_label, "position", from + Vector2(16.0, -30.0), Z_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_z_tw.parallel().tween_property(_z_label, "scale", Vector2.ONE * 1.15, Z_TIME)
	_z_tw.parallel().tween_property(_z_label, "modulate:a", 0.0, Z_TIME * 0.3).set_delay(Z_TIME * 0.7)

func _stop_z() -> void:
	Motion.stop(_z_tw)
	if _z_label != null:
		_z_label.visible = false

## The toast over the foot of the card, fading in and out over
## Motion.DROP_FADE -- Knight's `_draw_toast`, in the card's own pixels and
## wrapped to the card's width.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := tr(_toast)
	if _toast_arg != "":
		line = line % _toast_arg
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _ring_at(c: int) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": _centre(c), "at": _now()})
	_busy_for(Motion.RING_TIME)

# --- input ---

## A touch resolves on release; a press held LONG_PRESS fires the other
## chip's action at once and the release is then ignored. One finger holds
## the press: another landing meanwhile is ignored, press and release.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		var c := _cell_at(event.position)
		if event.pressed:
			if _press_finger != -2 and finger != _press_finger:
				return
			_press_finger = finger
			_press_cell = c
			_long_fired = false
			_press_id += 1
			var id := _press_id
			if c >= 0:
				_later(LONG_PRESS, func():
					if id == _press_id and _press_cell == c and not _long_fired:
						_long_fired = true
						_act(c, State.FLAG if brush == State.RAKE else State.RAKE))
			return
		if finger != _press_finger:
			return
		var was := _press_cell
		_press_cell = -1
		_press_finger = -2
		_press_id += 1
		if _long_fired or c < 0 or c != was:
			return
		if event is InputEventScreenTouch and event.canceled:
			return
		_act(c, brush)

## The tray armed a chip.
func set_brush(v: int) -> void:
	brush = v

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line (which no screen
## shows since the tip card left every board) and the toast, which one does.
func _tell(key: String, mood: int, arg := "") -> void:
	_say(tr(key) % arg if arg != "" else tr(key), mood)
	_toast = key
	_toast_arg = arg
	_toast_at = _now()
	queue_redraw()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Takes back the last gesture: its cells' piles pop back in, back to front;
## its flag pops in or out. A woken hedgehog stays awake.
func undo() -> bool:
	if is_done():
		return false
	var u: Dictionary = _state.undo()
	if u.is_empty():
		return false
	var t := _now()
	var raked: PackedInt32Array = u.raked
	for i in raked.size():
		var c := raked[i]
		var at := t + (0.0 if Motion.reduce else float(raked.size() - 1 - i) * UNDO_STEP)
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for f: Array in u.flags:
		var c: int = f[0]
		if int(f[1]) == 1:
			_flag_at[c] = t
			_touch(c, t + FLAG_DROP + Motion.BUMP_TIME)
		else:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	fx.cue("undo")
	_tell("HH_UNDONE", Face.Expr.HAPPY)
	moved.emit()
	_refresh()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## The next thing logic can prove from what the player can see: a bare cell
## raked, else a hedgehog flagged and pinned.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _now() < _busy_until:
		return false
	var step: Dictionary = _state.hint_step()
	if step.is_empty():
		return false
	hints_used += 1
	var c: int = step.cell
	if step.kind == "rake" and _state.flag[c] == 1:
		_unflag_at[c] = _now()
	var r: Dictionary = _state.apply_hint(step)
	_ring_at(c)
	fx.cue("hint")
	_hinting = true
	if String(r.kind) == "pinned":
		_flag_at[c] = _now()
		_touch(c, _now() + FLAG_DROP + Motion.BUMP_TIME)
		_tell("HH_HINT_FLAG", Face.Expr.HAPPY)
		_after_move()
	else:
		_show_rake(r, c)
		# A rake that finished the lawn has the win's line; leave it.
		if not is_done():
			_tell("HH_HINT_RAKE", Face.Expr.HAPPY)
	_hinting = false
	return true

## Every wrong flag's pennant turns rose and shivers, and holds until the
## next move. Counts a check.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: PackedInt32Array = _state.check()
	var t := _now()
	for c in wrong:
		_bump_at[c] = t
		_touch(c, t + Motion.SHIVER_TIME)
	if wrong.is_empty():
		_tell("HH_CHECK_OK", Face.Expr.JOY)
		fx.cue("check_ok")
	else:
		_tell("HH_CHECK_ONE" if wrong.size() == 1 else "HH_CHECK_N", Face.Expr.STRAIN,
			"" if wrong.size() == 1 else str(wrong.size()))
		fx.cue("check")
	_refresh()
	return wrong.size()

## Back to the opening, the piles popping back in out from it; woken
## hedgehogs and a hint's flags stay.
func reset_board() -> void:
	var before: PackedByteArray = _state.flag.duplicate()
	var covered: PackedInt32Array = _state.reset_board()
	var t := _now()
	var start: int = _state.g.start
	var cols: int = _state.cols()
	for c in covered:
		var d := absi(c % cols - start % cols) + absi(c / cols - start / cols)
		var at := t + (0.0 if Motion.reduce else Motion.stagger(d, Motion.RESET_STAGGER))
		_cover_at[c] = at
		_blow_at[c] = -100.0
		_touch(c, at + Motion.POP_IN)
	for c in _state.size():
		if before[c] == 1 and _state.flag[c] == 0:
			_unflag_at[c] = t
			_touch(c, t + FLAG_OUT)
	_last = start
	moves = 0
	_running = true
	_tell("HH_RESET", Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The day's shape, never its answer, and how many woke.
func share_glyphs() -> String:
	var tail := tr("HH_SHARE_NONE") if _state.woken == 0 else (tr("HH_SHARE_ONE") if _state.woken == 1
		else tr("HH_SHARE_N") % _state.woken)
	return _state.share_glyphs() + "\n" + tail

# --- the win ---

func flat_win() -> Dictionary:
	var faces: Array = []
	for i in 3:
		faces.append(HedgehogFace.new())
	var sub := tr("HH_WIN_NONE") if _state.woken == 0 else (tr("HH_WIN_WOKE_ONE") if _state.woken == 1
		else tr("HH_WIN_WOKE_N") % _state.woken)
	return {"faces": faces, "subtitle": sub}

## The wave's length: the farthest sleeper from the last rake.
func _wave_span() -> float:
	var cols: int = _state.cols()
	var far := 0
	for c in _state.size():
		if _state.is_hog(c) and _state.woke[c] == 0:
			far = maxi(far, maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols)))
	return Motion.stagger(far, Motion.WAVE_STEP * 2.0)

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_LEAD + _wave_span() + WIN_WAIT

## Every sleeper's leaves blow off in a wave out of the last cell raked, and
## each hedgehog pops up awake and hops; the woken ones cheer up too.
func _on_solved() -> void:
	var t := _now()
	_solved_at = t
	_tip_timer.stop()
	_stop_z()
	var cols: int = _state.cols()
	for c in _state.size():
		if not _state.is_hog(c):
			continue
		var d := maxi(absi(c % cols - _last % cols), absi(c / cols - _last / cols))
		var delay := 0.0 if Motion.reduce else WIN_LEAD + Motion.stagger(d, Motion.WAVE_STEP * 2.0)
		if _state.woke[c] == 1:
			var woken_face: Control = _faces.get(c)
			if woken_face != null:
				woken_face.expression = Face.Expr.JOY
				Motion.hop(woken_face, -_cell * 0.16, 0.4, delay + 0.3)
			continue
		_blow_at[c] = t + delay
		_blow_from[c] = _last
		_touch(c, t + delay + LEAF_TIME)
		_wake_up(_face_at(c, Face.Expr.SLEEPY), delay)
	if not Motion.reduce:
		_swirl_at = t + WIN_LEAD
		_busy_for(WIN_LEAD + SWIRL_TIME)
		_later(WIN_LEAD, func():
			fx.sparkle(_centre(_last), Pal.SUN)
			fx.cue("solved"))
	else:
		fx.cue("solved")
	_say(tr("HH_WIN_NONE") if _state.woken == 0 else tr("HH_TIP_WOKE"), Face.Expr.JOY)
	_refresh()

## A sleeper the win uncovers: it pops up still asleep, stretches tall with
## its eyes screwed shut and mouth open (the yawn, which is JOY's face), and
## hops awake.
func _wake_up(face: Control, delay: float) -> void:
	if Motion.reduce:
		face.expression = Face.Expr.JOY
		return
	face.scale = Vector2.ZERO
	Motion.pop_in(face, Motion.POP_IN, delay)
	var tw := face.create_tween()
	tw.tween_interval(delay + Motion.POP_IN + 0.12)
	tw.tween_callback(func(): face.expression = Face.Expr.JOY)
	tw.tween_property(face, "scale", Vector2(0.88, 1.16), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(face, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Motion.hop(face, -_cell * 0.14, 0.4, delay + Motion.POP_IN + 0.5)

## The hedgehogs a rake woke, so a reopened daily can say how many and wash
## the same cells rose. Plain ints, because it goes through a ConfigFile.
func completion_record() -> Dictionary:
	var out: Array = []
	for c in _state.size():
		if _state.woke[c] == 1:
			out.append(c)
	return {"woke": out}

## A reopened daily that was already solved: every bare cell raked and every
## hedgehog awake on it, the ones a rake woke back on their rose cells from
## `completed_record` (a save from before completion_record() existed has
## none, and reads as a day nobody woke). Never check_solved(): `solved`
## must not fire twice.
func restore_completed_board() -> void:
	for c in _state.size():
		if not _state.is_hog(c):
			_state.open[c] = 1
	_state.woke.fill(0)
	_state.woken = 0
	for w in _recorded_woke():
		_state.woke[w] = 1
		_state.woken += 1
	_state.history = []
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_blow_at.fill(-100.0)
	_moving = {}
	_stop_z()
	for c in _state.size():
		if _state.is_hog(c):
			_face_at(c, Face.Expr.JOY)
	_tip_timer.stop()
	_say(tr("HH_WIN_NONE") if _state.woken == 0 else tr("HH_TIP_WOKE"), Face.Expr.JOY)
	_bands = []
	_refresh()

## The record's woken cells if every one is a hedgehog on today's lawn, each
## once, and none otherwise.
func _recorded_woke() -> PackedInt32Array:
	var out := PackedInt32Array()
	var raw = completed_record.get("woke", [])
	if not raw is Array:
		return out
	for v in raw:
		var c := int(v)
		if c < 0 or c >= _state.size() or not _state.is_hog(c) or out.has(c):
			return PackedInt32Array()
		out.append(c)
	return out

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
