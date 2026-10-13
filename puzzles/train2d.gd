extends "res://core/puzzle_base.gd"
## Toy Cannons: a picture of toy blocks on the playroom rug, a loop of
## wooden track round it, and little cannons that ride it and shoot the
## picture away with corks (docs/agents/boards/train.md). The rules are
## puzzles/train_state.gd's; this draws them and keeps the loop's clock.
##
## The board was built as Toy Train on 2026-10-12 and turned into a shooter
## the day after: its id, its files and its names in code are the train's
## still. An `engine` is a cannon, its `room` the corks it has left, the
## `siding` the tray it waits in and the `shed` the toy box.
##
## A `bleed` board (ui/flat/flat_host.gd): the floor is the whole screen, the
## rug and its loop as big as the room between the pill and the yard allows,
## the tray and the toy box at the foot. Tap a cannon at the front of a
## column of the box, or one waiting in the tray, and it goes round and
## round while a lap hits anything.
##
## Drawn as `_bg` (the floor), `_yard` (the siding and the shed), `_ring`
## (the rug and the track), the blocks as one mesh rebuilt when one is taken,
## and the engines as one mesh a frame while anything moves; a number an
## engine and the pill, the toast and the run's bubble on a layer of their
## own. No character: the pieces are toys.

const State = preload("res://puzzles/train_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Face = preload("res://ui/faces/face.gd")
const Art = preload("res://ui/faces/train_art.gd")
const Seal = preload("res://ui/flat/seal.gd")
const CozyTheme = preload("res://ui/theme.gd")
const OUT_OF_HEARTS := "res://ui/hud/out_of_hearts.gd"

const PAD := 22.0
const HUD_ROW := 76.0
const GAP := 18.0
## From the picture to the rug's edge, and to the track's centre, in lanes:
## a lane is a square, but never under LANE_MIN pixels, so the track and the
## cannons on it keep their size when the squares are small.
const EDGE := 1.85
const REACH := 0.95
const LANE_MIN := 34.0
## The track's gauge and a cannon's length on the loop, in lanes.
const GAUGE := 0.62
const ENGINE := 1.45
## A cannon on the loop is never shorter than this: on the small pictures it
## stands from the rug's edge to the picture's, its wheels astride the track.
const LOOP_MIN := 60.0
const CELL_MAX := 62.0
## The blocks are kept as a mesh a patch of this many squares a side, so a
## block shot rebuilds its patch and not the picture.
const CHUNK := 8
## An engine's length at rest in the yard, and the unit its mesh is built at.
const REST := 92.0
const UNIT := 100.0
## Rows of a column of the shed that are seen; the rest are a count.
const ROWS := 3
const BURIED := 0.84
## Seconds a stop, a band, and a shot a stop: a lap is about two seconds on
## every one, forty to fifty corks a second past Easy.
const TICKS := [0.045, 0.024, 0.02, 0.02]

## This board's own motion (the rest is core/motion.gd's).
const SEND_FLY := 0.24
const PARK_FLY := 0.34
const SHIFT := 0.22
## A cork's flight to its block, the block's burst where it stands, and the
## cannon's kick back from the shot.
const PICK_FLY := 0.06
const BURST := 0.14
const BURST_GROW := 0.45
const RECOIL := 0.07
const RECOIL_PX := 0.12
const POP := 0.24
const WIN_WAIT := 1.5
const PARTY_EXTRA := 0.6
const WIN_SLIDE := 0.5
const WIN_STAGGER := 0.035
const STAMP_AT := 0.9
const STAMP_FROM := 1.8
const STAMP_DROP := 0.18
const STAMP_R := 0.15
const STAMP_TILT := -0.22
const CARD_AFTER := 1.0
const CARD_AFTER_STILL := 0.3
const HINT_BEAT := 0.5

## A run: the stops in a row one cannon hits a block at. Its tick climbs a
## step of this scale every RUN_STEP blocks (semitones, an octave at the
## most: the take sits five steps low so the top is still a tock), and is
## heard and felt once in PICK_GAP however many are shot; the bubble counts
## the run from COMBO_FROM, and a long one ends on two notes.
const RUN_SCALE := [0, 2, 4, 5, 7, 9, 11, 12]
const RUN_STEP := [1, 3, 4, 4]
const PICK_GAP := 0.06
const TICK_VARY := Vector2(0.985, 1.015)
const COMBO_FROM := 5
const BIG_RUN := 12
const RUN_CONFETTI := [20, 40, 60]
const COMBO_DEFLATE := 0.25
const COMBO_HOLD := 0.9
const COMBO_FONT := 44
## Engines sent home full one after another, none parked between: a note a
## step up for each.
const STREAK_STEPS := [0, 2, 4, 5, 7]
const STREAK_DB := -3.0

const PILL_FONT := 30
const PILL_H := 48.0
const TOAST_HOLD := 2.6
const TOAST_H := 66.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 24.0

## What the phone does under each cue (docs/agents/haptics.md). An engine
## sent is a tap and a block taken a tick; an engine home full is a small
## yes, a long run and a colour whole firmer ones.
const HAPTICS := {
	"send": Haptics.TAP,
	"pick": Haptics.TICK,
	"run": Haptics.GOOD,
	"full": Haptics.BUMP,
	"combo": Haptics.TICK,
	"park": Haptics.TAP,
	"home": Haptics.TAP,
	"whole": Haptics.GOOD,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"heart_back": Haptics.GOOD,
	"locked": Haptics.WARN,
	"out_of_hearts": Haptics.LOSE,
	"solved": Haptics.WIN,
}

var state = State.new()

signal leave

var fx: Node2D

## The host reads these off every board; this one has neither hearts nor a
## move counter, and `out_of_hearts` is Insane's full siding.
var hearts := 0
var max_hearts := 0
var moves_left := 0
var max_moves := 0
var out_of_hearts := false
var _heart_used := false
var _asleep := false
var _heart_card: Control

# layout
var _clear := Vector2.ZERO
var _won := false
var _cell := 0.0
## The lane (LANE_MIN), and the rug's edge and the track's reach in squares.
var _lane := 0.0
var _edge := EDGE
var _reach := REACH
var _grid := Vector2.ZERO
var _rug := Rect2()
var _siding_rect := Rect2()
var _shed_rect := Rect2()
var _rest := REST
## What the tutorial's small board changes: an engine's most at rest, the
## rows of the shed that are seen, and whether there is a pill.
var _rest_max := REST
var _rows := ROWS
var _pill := true
## The tutorial's page is wide and short: the yard stands beside the rug.
var _beside := false
var _step := REST
var _shed_step := REST
var _row := REST
var _loop_px := REST
var _from_cell := 0.0
var _from_grid := Vector2.ZERO
var _slid_at := -INF
var _gen := 0

# meshes
var _bg: ArrayMesh
var _yard: ArrayMesh
var _ring: ArrayMesh
var _blocks: ArrayMesh
var _blocks_stale := true
## The blocks at rest, a mesh a patch (CHUNK), and the patches to rebuild.
var _chunks := {}
var _chunk_stale := {}
var _cork: ArrayMesh
var _blk := {}
var _eng := {}
var _plate: ArrayMesh
var _flat_cache := {}
var _shown: Array = []
var _hud_layer: Control
var _hud_shown: ArrayMesh
var _hud_wide := -1.0
var _combo_shown: ArrayMesh
var _seal_mesh: ArrayMesh
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

# the loop's clock
var _tick_time := 0.08
var _next_tick := 0.0
var _tick_from := 0.0
var _frac := 0.0

# engines as they are seen
var _seen := {}
var _from := {}
var _pops := {}
var _bump_at := {}
var _shiver_at := {}
var _flights: Array = []

var _pressed := -1
var _pick_cue_at := -INF
var _streak := 0
var _combo_n := 0
var _combo_e := -1
var _combo_at := -INF
var _combo_out_at := -INF
var _combo_popped := false
var _combo_pos := Vector2.ZERO
var _pill_bump := -INF
var _tag_bump := -INF
var _opened := -1.0e9
var _solved_at := -INF
var _win_pop_at := INF
var _stamp_at := INF
var _anim_until := 0.0
var _toast := ""
var _toast_at := -100.0
var _told_home := false
var _final_taps := 0

func puzzle_id() -> String: return "train"
func title() -> String: return "Toy Cannons"

func rules() -> String:
	var out := tr("TT_RULES") % [State.ON_LOOP, State.SIDING]
	out += "\n\n" + tr("TT_RULES_JAM" if state.band >= State.INSANE else "TT_RULES_HOME")
	return out

## The tutorial: each page is the board itself on a small hand-made rug
## (ui/hud/train_tutorial_diagram.gd). Loaded, not preloaded: the page's
## board extends this script.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/train_tutorial_diagram.gd")
	var hints: int = State.hints_for(state.band)
	var steps := [
		[Diagram.Lesson.SEND, "HTP_TT_SEND", tr("HTP_TT_SEND_BODY")],
		[Diagram.Lesson.LINE, "HTP_TT_LINE", tr("HTP_TT_LINE_BODY")],
		[Diagram.Lesson.SIDING, "HTP_TT_SIDING", tr("HTP_TT_SIDING_BODY") % State.SIDING]]
	if state.band >= State.INSANE:
		steps.append([Diagram.Lesson.JAM, "HTP_TT_JAM", tr("HTP_TT_JAM_BODY")])
	elif hints > 0:
		steps.append([Diagram.Lesson.HINT, "HTP_TT_HINT",
			tr("HTP_TT_HINT_BODY_ONE") if hints == 1 else tr("HTP_TT_HINT_BODY_N") % hints])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## The bulb up to Hard. No Undo on any band (the loop runs on a clock, and a
## block an engine took is taken) and no Check: Reset is the way back.
func capabilities() -> Array[String]:
	if state.band >= State.INSANE:
		return []
	return ["hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_hud_layer = Control.new()
	_hud_layer.name = "Hud"
	_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.z_index = 3
	_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_layer.draw.connect(_draw_hud)
	add_child(_hud_layer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_gen += 1
	state.setup(rng, difficulty)
	_begin()

## The rug as `state` has it, from the top.
func _begin() -> void:
	_heart_used = false
	_won = false
	_solved_at = -INF
	_win_pop_at = INF
	_slid_at = -INF
	_stamp_at = INF
	_seal_mesh = null
	_tick_time = TICKS[clampi(state.band, 0, TICKS.size() - 1)]
	_deal()
	_layout()
	_enter()

func _deal() -> void:
	out_of_hearts = false
	_asleep = false
	_pressed = -1
	_toast = ""
	_told_home = false
	_flights = []
	_seen = {}
	_from = {}
	_pops = {}
	_bump_at = {}
	_shiver_at = {}
	_streak = 0
	_combo_n = 0
	_combo_e = -1
	_frac = 0.0
	_blocks_stale = true
	if _hud_layer != null:
		_hud_layer.queue_redraw()

# --- layout ---

## The host's rows over this board (ui/flat/flat_host.gd, a `bleed` board):
## what they cover at the top and the foot, and on the win the span the win
## screen leaves, which the picture slides to the middle of.
func set_clear(top: float, bottom: float, won := false) -> void:
	_clear = Vector2(top, bottom)
	if won and not _won and _cell > 0.0:
		_from_cell = _cell
		_from_grid = _grid
		_slid_at = _now() if is_inside_tree() and _solved_at > _now() - 5.0 else -INF
	_won = won
	_layout()

## The rug as big as the room between the pill and the yard allows, and the
## siding and the shed under it.
func _layout() -> void:
	if state.w <= 0 or size.x <= 0.0:
		return
	var top := _clear.x
	var foot := size.y - _clear.y
	var columns: int = maxi(1, state.sheds.size())
	_rest = clampf((size.x - 2.0 * PAD - 24.0) / State.SIDING - 14.0, 40.0, _rest_max)
	_step = _rest + 14.0
	_row = _rest * 0.9
	_shed_step = minf(_rest * 1.3, (size.x - 2.0 * PAD - 24.0) / columns)
	var siding_size := Vector2(State.SIDING * _step + 24.0, _rest + 22.0)
	var shed_size := Vector2(columns * _shed_step + 24.0, _rows * _row + 54.0)
	var head := top if _won or not _pill else top + HUD_ROW
	var below := 0.0 if _won else siding_size.y + shed_size.y + 2.0 * GAP + 12.0
	var room := Vector2(size.x - 2.0 * PAD, foot - head - below)
	if _beside and not _won:
		room = Vector2(size.x - siding_size.x - 3.0 * PAD, foot - head - 2.0 * GAP)
	var span := Vector2(state.w + 2.0 * EDGE, state.h + 2.0 * EDGE)
	_cell = minf(CELL_MAX, minf(room.x / span.x, room.y / span.y))
	_lane = _cell
	if _cell < LANE_MIN:
		# small squares: the rug's border keeps its size and the picture has
		# what is left
		_lane = LANE_MIN
		_cell = minf((room.x - 2.0 * EDGE * _lane) / state.w, (room.y - 2.0 * EDGE * _lane) / state.h)
	if _cell <= 0.0:
		return
	_edge = EDGE * _lane / _cell
	_reach = REACH * _lane / _cell
	span = Vector2(state.w + 2.0 * _edge, state.h + 2.0 * _edge)
	var ring := span * _cell
	_rug = Rect2(Vector2((size.x - ring.x) * 0.5, head + (room.y - ring.y) * 0.5), ring)
	_siding_rect = Rect2(Vector2((size.x - siding_size.x) * 0.5, _rug.end.y + GAP), siding_size)
	_shed_rect = Rect2(Vector2((size.x - shed_size.x) * 0.5, _siding_rect.end.y + GAP), shed_size)
	if _beside and not _won:
		var left := (size.x - ring.x - siding_size.x - PAD) * 0.5
		var mid_y := (head + foot) * 0.5
		_rug.position = Vector2(left, mid_y - ring.y * 0.5)
		var yard_x := left + ring.x + PAD + siding_size.x * 0.5
		var yard_h := siding_size.y + GAP + shed_size.y
		_siding_rect.position = Vector2(yard_x - siding_size.x * 0.5, mid_y - yard_h * 0.5)
		_shed_rect.position = Vector2(yard_x - shed_size.x * 0.5, _siding_rect.end.y + GAP)
	_grid = _rug.position + Vector2(_edge, _edge) * _cell
	_loop_px = maxf(ENGINE * _lane, LOOP_MIN)
	_flat_cache = {}
	_blk = {}
	_eng = {}
	for c in state.colours.size():
		var col: Color = Art.colour(state.colours[c])
		var bb := Face.Builder.new()
		Art.block(bb, Vector2.ZERO, _cell, col)
		_blk[c] = bb.mesh()
		var eb := Face.Builder.new()
		Art.engine(eb, UNIT, col)
		Art.plate(eb, UNIT)
		_eng[c] = eb.mesh()
	var cb := Face.Builder.new()
	Art.cork(cb, UNIT)
	_cork = cb.mesh()
	var b := Face.Builder.new()
	Art.floor_boards(b, size)
	_bg = b.mesh()
	_yard = _build_yard()
	_ring = _build_ring()
	_blocks_stale = true
	_seal_mesh = null
	_from = {}
	_seen = {}
	_hud_layer.queue_redraw()
	_request()

func _field_px() -> Rect2:
	return Rect2(_grid, Vector2(state.w, state.h) * _cell)

func cell_centre(i: int) -> Vector2:
	return _grid + (Vector2(state.xy(i)) + Vector2(0.5, 0.5)) * _cell

## Where a stop is, in squares off the picture's corner.
func _stop_at(s: int) -> Vector2:
	var w: int = state.w
	var h: int = state.h
	if s < w:
		return Vector2(s + 0.5, h + _reach)
	s -= w
	if s < h:
		return Vector2(w + _reach, h - 0.5 - s)
	s -= h
	if s < w:
		return Vector2(w - 0.5 - s, -_reach)
	s -= w
	return Vector2(-_reach, s + 0.5)

func _side(s: int) -> int:
	var w: int = state.w
	var h: int = state.h
	if s < w:
		return 0
	if s < w + h:
		return 1
	if s < 2 * w + h:
		return 2
	return 3

## The point of the loop at `u` stops along: -1 is the gate, in the bend at
## the lower left, and a whole number a stop. Between the last stop of a
## side and the first of the next it goes round the bend.
func loop_at(u: float) -> Vector2:
	var w: int = state.w
	var h: int = state.h
	var n: int = state.stops()
	var r := _reach + 0.5
	var p: Vector2
	if u < 0.0:
		p = Vector2(0.5, h - 0.5) + Vector2.from_angle(lerpf(PI * 0.75, PI * 0.5, clampf(u + 1.0, 0.0, 1.0))) * r
	elif u >= n - 1:
		p = Vector2(0.5, h - 0.5) + Vector2.from_angle(lerpf(PI, PI * 0.75, clampf(u - (n - 1), 0.0, 1.0))) * r
	else:
		var s := int(floor(u))
		var f := u - s
		var side := _side(s)
		if side == _side(s + 1):
			p = _stop_at(s).lerp(_stop_at(s + 1), f)
		else:
			var centre := [Vector2(w - 0.5, h - 0.5), Vector2(w - 0.5, 0.5), Vector2(0.5, 0.5)][side] as Vector2
			var a0 := PI * 0.5 - side * PI * 0.5
			p = centre + Vector2.from_angle(lerpf(a0, a0 - PI * 0.5, f)) * r
	return _grid + p * _cell

## The way a cannon at `u` points, as its mesh is turned (muzzle up at 0):
## across the rug, square to the way it rolls.
func _heading(u: float) -> float:
	return (loop_at(u + 0.08) - loop_at(u - 0.08)).angle()

func siding_pos(place: int) -> Vector2:
	return Art.siding_place(_siding_rect, place, State.SIDING, _step)

func shed_pos(column: int, row: int) -> Vector2:
	var columns: int = maxi(1, state.sheds.size())
	return Vector2(_shed_rect.get_center().x + (column - (columns - 1) * 0.5) * _shed_step,
		_shed_rect.position.y + 14.0 + _row * (row + 0.5))

func _build_yard() -> ArrayMesh:
	var b := Face.Builder.new()
	Art.siding(b, _siding_rect, State.SIDING, _step)
	Art.shed(b, _shed_rect, maxi(1, state.sheds.size()), _shed_step)
	return b.mesh()

## The rug, the mat and the loop of track round it, with its stub of a
## siding line at the gate.
func _build_ring() -> ArrayMesh:
	var b := Face.Builder.new()
	Art.rug(b, _rug, _field_px(), _lane)
	var seam := _rug.grow(-_lane * 0.34)
	Art.stitches(b, seam, _lane * 0.9, 16.0, Art.RUG_STITCH)
	var pts := PackedVector2Array()
	var n: int = state.stops()
	var u := 0.0
	while u < n - 1:
		pts.append(loop_at(u))
		u += 0.25
	for k in 8:
		pts.append(loop_at(n - 1 + k / 8.0))
	for k in 8:
		pts.append(loop_at(-1.0 + k / 8.0))
	Art.track(b, pts, GAUGE * _lane, true)
	return b.mesh()

# --- the engines as they are seen ---

## Where engine `e` belongs now: [point, turn, length, how much seen].
func _target(e: int) -> Array:
	match state.where[e]:
		State.SHED:
			var column: PackedInt32Array = state.sheds[state.col[e]]
			var r := column.find(e)
			return [shed_pos(state.col[e], mini(r, _rows)), 0.0, _rest * (1.0 if r == 0 else BURIED), 1.0 if r < _rows else 0.0]
		State.PARKED:
			return [siding_pos(state.at[e]), 0.0, _rest, 1.0]
		State.LOOP:
			# the tick has it at its stop; it is drawn rolling up to it
			var u: float = state.at[e] + _frac - 1.0
			return [loop_at(u), _heading(u), _loop_px, 1.0]
	return [loop_at(-1.0), _heading(-1.0), _loop_px, 1.0]

## Engine `e` as it is drawn now: on its way from where it was (`_glide`) to
## where it belongs, with its bump and its shiver.
func _seat(e: int, now: float) -> Array:
	var t := _target(e)
	if _from.has(e):
		var f: Dictionary = _from[e]
		var u: float = (now - float(f.at)) / float(f.time)
		if u >= 1.0 or Motion.reduce:
			_from.erase(e)
		else:
			u = clampf(u, 0.0, 1.0)
			var s := u * u * (3.0 - 2.0 * u)
			t = [(f.pos as Vector2).lerp(t[0], s) + Vector2(0.0, -sin(PI * s) * float(f.arc)),
				lerp_angle(float(f.ang), float(t[1]), s), lerpf(float(f.px), float(t[2]), s),
				lerpf(float(f.seen), float(t[3]), s)]
	return t

## Engine `e` is about to belong somewhere else: it goes there from where it
## was last drawn, in `time`, hopping `arc` high.
func _glide(e: int, time: float, arc := 0.0) -> void:
	if Motion.reduce:
		return
	var was: Array = _seen.get(e, [])
	if was.is_empty():
		return
	_from[e] = {"pos": was[0], "ang": was[1], "px": was[2], "seen": was[3], "at": _now(), "time": time, "arc": arc}

## Control-local point over engine `e` where it stands. The harnesses press
## these.
func engine_screen(e: int) -> Vector2:
	return _target(e)[0]

## The engine under a finger: one standing in the shed (seen) or the siding.
func _engine_at(at: Vector2) -> int:
	var best := -1
	var best_d := INF
	for e in state.colour.size():
		var where: int = state.where[e]
		if where != State.SHED and where != State.PARKED:
			continue
		var t := _target(e)
		if float(t[3]) <= 0.0:
			continue
		var d := (t[0] as Vector2).distance_to(at)
		if d < float(t[2]) * 0.6 and d < best_d:
			best_d = d
			best = e
	return best

# --- the drawing ---

## Where the picture's own pixels are on the screen now: itself, but for the
## win's slide from where it was played to the middle of what is left.
func _slide_xf(now: float) -> Transform2D:
	var e := now - _slid_at
	if Motion.reduce or e >= WIN_SLIDE or _from_cell <= 0.0 or _cell <= 0.0:
		return Transform2D.IDENTITY
	var u := clampf(e / WIN_SLIDE, 0.0, 1.0)
	var s := u * u * (3.0 - 2.0 * u)
	var k0 := _from_cell / _cell
	var k := lerpf(k0, 1.0, s)
	return Transform2D(0.0, Vector2(k, k), 0.0, (_from_grid - _grid * k0).lerp(Vector2.ZERO, s))

func _draw() -> void:
	if _cell <= 0.0 or _bg == null:
		return
	var now := _now()
	var shown: Array = [_bg]
	draw_mesh(_bg, null)
	var since := now - _opened - Motion.ENTER_DELAY
	# the yard goes with the win: the picture has the floor
	var yard := 1.0 if Motion.reduce else Motion.appear_level(since)
	if _solved_at > -INF:
		yard = 0.0 if Motion.reduce else clampf(1.0 - (now - _solved_at - 0.3) / 0.3, 0.0, 1.0)
		if _won and _slid_at == -INF:
			yard = 0.0
	if yard > 0.0 and _yard != null:
		draw_mesh(_yard, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, yard))
		shown.append(_yard)
	var slide := _slide_xf(now)
	draw_set_transform_matrix(slide)
	var ring_k := 1.0
	if not Motion.reduce and since < Motion.ENTER_POP:
		ring_k = Motion.wide_pop_scale(maxf(0.0, since))
	if ring_k != 1.0:
		var mid := _rug.get_center()
		draw_set_transform_matrix(slide * Transform2D(0.0, Vector2(ring_k, ring_k), 0.0, mid - mid * ring_k))
	draw_mesh(_ring, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, 1.0 if Motion.reduce else Motion.appear_level(since + Motion.ENTER_DELAY)))
	shown.append(_ring)
	draw_set_transform_matrix(slide)
	_draw_blocks(now, shown)
	if _stamp_at <= now:
		_draw_stamp(now, shown, slide)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if yard > 0.0:
		_draw_engines(now, shown, yard)
	_shown = shown

## The blocks on the rug. At rest and in play a mesh a patch, and only the
## patch a cork lands in rebuilt (a picture is a thousand blocks and loses
## fifty a second); while they pop in, one mesh a frame (`_blocks_now`).
func _draw_blocks(now: float, shown: Array) -> void:
	var opening := not Motion.reduce and now < _opened + Motion.ENTER_DELAY + Motion.ENTER_POP * 0.5 \
			+ Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER, 1.0) + Motion.POP_IN + 0.05
	if _solved_at > -INF or opening:
		var blocks := _blocks_now(now)
		if blocks != null:
			draw_mesh(blocks, null)
			shown.append(blocks)
		return
	if _blocks_stale:
		_blocks_stale = false
		_blocks = null
		_chunks = {}
		_chunk_stale = {}
	var w: int = state.w
	var h: int = state.h
	var across := ceili(float(w) / CHUNK)
	for cy in ceili(float(h) / CHUNK):
		for cx in across:
			var key := cy * across + cx
			if _chunk_stale.has(key) or not _chunks.has(key):
				var fb := Face.FlatBuilder.new(_flat_cache)
				for y in range(cy * CHUNK, mini(h, (cy + 1) * CHUNK)):
					for x in range(cx * CHUNK, mini(w, (cx + 1) * CHUNK)):
						var c: int = state.grid[y * w + x]
						if c >= 0:
							fb.append(_blk[c], Transform2D(0.0, cell_centre(y * w + x)))
				_chunks[key] = fb.mesh()
			var m: ArrayMesh = _chunks[key]
			if m != null:
				draw_mesh(m, null)
				shown.append(m)
	_chunk_stale = {}

## The blocks as one mesh, built a frame at a time while they pop in (the
## opening, and the picture put back whole for the win) and kept once the
## whole picture stands.
func _blocks_now(now: float) -> ArrayMesh:
	var whole: bool = _solved_at > -INF
	var cells: PackedInt32Array = state.picture if whole else state.grid
	var from := (_win_pop_at if whole else _opened + Motion.ENTER_DELAY + Motion.ENTER_POP * 0.5)
	var w: int = state.w
	var h: int = state.h
	var per := WIN_STAGGER if whole else Motion.ENTER_STAGGER
	var popping := not Motion.reduce and now < from + Motion.stagger(w + h, per, 1.0) + Motion.POP_IN + 0.05
	if whole and now < from and not Motion.reduce:
		return null
	if not popping and not _blocks_stale and _blocks != null:
		return _blocks
	var fb := Face.FlatBuilder.new(_flat_cache)
	for i in cells.size():
		var c := cells[i]
		if c < 0:
			continue
		var at := cell_centre(i)
		if popping:
			var x := i % w
			var y := i / w
			# the win's picture grows from its middle, the opening along the
			# diagonals
			var order := (absi(2 * x - w + 1) + absi(2 * y - h + 1)) / 2 if whole else x + y
			var e := now - from - Motion.stagger(order, per, 1.0)
			if e <= 0.0:
				continue
			var k := Motion.pop_in_scale(e)
			fb.append(_blk[c], Transform2D(0.0, k, 0.0, at))
		else:
			fb.append(_blk[c], Transform2D(0.0, at))
	var m := fb.mesh()
	if popping:
		_busy_for(0.1)
		return m
	_blocks = m
	_blocks_stale = false
	return m

## The shots in the air (a block stands until its cork lands, then bursts
## where it stood), then every cannon with its number: the ones at rest
## first, the ones on the loop over them.
func _draw_engines(now: float, shown: Array, alpha: float) -> void:
	var fb := Face.FlatBuilder.new(_flat_cache)
	var live: Array = []
	for f: Dictionary in _flights:
		var e := now - float(f.at)
		if e >= PICK_FLY + BURST:
			continue
		live.append(f)
		var to: Vector2 = f.to
		if e < PICK_FLY:
			fb.append(_blk[int(f.c)], Transform2D(0.0, to))
			var from: Vector2 = f.from
			var ck := float(f.px) / UNIT
			fb.append(_cork, Transform2D((to - from).angle() + PI * 0.5, Vector2(ck, ck), 0.0, from.lerp(to, e / PICK_FLY)))
		else:
			var v := (e - PICK_FLY) / BURST
			var k := 1.0 + BURST_GROW * v
			fb.append(_blk[int(f.c)], Transform2D(0.0, Vector2(k, k), 0.0, to), Color(1.0, 1.0, 1.0, 1.0 - v * v))
	_flights = live
	var labels: Array = []
	var order: Array = []
	for e in state.colour.size():
		if state.where[e] != State.GONE and state.where[e] != State.LOOP:
			order.append(e)
	for e in state.loop:
		order.append(e)
	for e: int in order:
		var t := _seat(e, now)
		_seen[e] = t
		if float(t[3]) <= 0.01:
			continue
		var px := float(t[2])
		var pos: Vector2 = t[0]
		if not Motion.reduce:
			# the kick of a shot, back from the way it points
			var shot := now - float(_bump_at.get(e, -INF))
			if shot >= 0.0 and shot < RECOIL:
				pos -= Vector2.UP.rotated(float(t[1])) * px * RECOIL_PX * (1.0 - shot / RECOIL)
			var shook := now - float(_shiver_at.get(e, -INF))
			if shook < Motion.SHIVER_TIME:
				pos.x += Motion.shiver_offset(shook, 5.0)
		var k := px / UNIT
		fb.append(_eng[state.colour[e]], Transform2D(float(t[1]), Vector2(k, k), 0.0, pos), Color(1.0, 1.0, 1.0, float(t[3])))
		labels.append([pos, px, state.room[e], float(t[3])])
	# an engine full: it pops off the track where it filled
	for e: int in _pops.keys():
		var p: Dictionary = _pops[e]
		var gone := now - float(p.at)
		if gone >= POP or Motion.reduce:
			_pops.erase(e)
			continue
		var k := float(p.px) / UNIT * (1.0 + 0.5 * sin(PI * gone / POP)) * Motion.pop_out_scale(maxf(0.0, gone - POP * 0.5), POP * 0.5)
		fb.append(_eng[state.colour[e]], Transform2D(float(p.ang), Vector2(k, k), 0.0, p.pos))
	var m := fb.mesh()
	if m != null:
		draw_mesh(m, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		shown.append(m)
	var font: Font = CozyTheme.display(700)
	for l: Array in labels:
		var fs := maxi(12, int(float(l[1]) * 0.27))
		var text := str(int(l[2]))
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		var rise := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, (l[0] as Vector2) + Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
			Color(Art.ink(), alpha * float(l[3])))
	# what the shed holds past the rows that are seen
	var small: Font = CozyTheme.body(600)
	for c in state.sheds.size():
		var more: int = (state.sheds[c] as PackedInt32Array).size() - _rows
		if more <= 0:
			continue
		var text := "+%d" % more
		var wide := small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x
		draw_string(small, Vector2(shed_pos(c, 0).x - wide * 0.5, _shed_rect.end.y - 16.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(Pal.TEXT_DIM, alpha))
	# the loop's count, on a little post by the gate
	var post := _rug.position + Vector2(0.5 * _lane, _rug.size.y - 0.5 * _lane)
	var on: int = state.loop.size() + state.gate.size()
	var pk := 1.0 if Motion.reduce else Motion.bump_scale(now - _tag_bump, 0.2)
	var pr := maxf(20.0, _lane * 0.52) * pk
	draw_circle(post + Vector2(0.0, 2.0), pr + 2.0, Color(Pal.OUTLINE, 0.2 * alpha))
	draw_circle(post, pr, Color(Pal.SURFACE, alpha))
	var tag := "%d/%d" % [on, State.ON_LOOP]
	var tfs := int(pr * 0.78)
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tfs).x
	draw_string(font, post + Vector2(-tw * 0.5, (font.get_ascent(tfs) - font.get_descent(tfs)) * 0.5), tag,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, tfs, Color(Pal.BAD if on >= State.ON_LOOP else Pal.TEXT, alpha))

# --- the pill, the toast and the run ---

func _draw_hud() -> void:
	if _cell <= 0.0 or state.w <= 0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < 0.0 and not Motion.reduce:
		return
	if not _won and _pill:
		var font: Font = CozyTheme.display(700)
		var text := pill_text()
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT).x
		var box := Vector2(wide + 52.0, PILL_H)
		# the count changes with every cork: the plate only with its width
		if _hud_shown == null or not is_equal_approx(_hud_wide, box.x):
			var b := Face.Builder.new()
			b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2.ONE * 2.0, box + Vector2.ONE * 4.0, box.y * 0.5 + 2.0), Pal.LINE)
			b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
			_hud_shown = b.mesh()
			_hud_wide = box.x
		var alpha := 1.0 if Motion.reduce else Motion.appear_level(since)
		var k := 1.0 if Motion.reduce else Motion.bump_scale(now - _pill_bump, 0.12)
		_hud_layer.draw_set_transform(Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5), 0.0, Vector2(k, k))
		_hud_layer.draw_mesh(_hud_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
		var rise := (font.get_ascent(PILL_FONT) - font.get_descent(PILL_FONT)) * 0.5
		_hud_layer.draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT, Color(Pal.TEXT, alpha))
		_hud_layer.draw_set_transform(Vector2.ZERO)
	_draw_combo(now)
	_draw_toast(now)

## What the pill reads: the blocks still on the rug.
func pill_text() -> String:
	return tr("TT_LEFT_ONE") if state.left == 1 else tr("TT_LEFT_N") % state.left

func _bump_pill() -> void:
	_pill_bump = _now()
	_hud_layer.queue_redraw()

## The run's bubble, over the engine that is on it.
func _draw_combo(now: float) -> void:
	if _combo_n < COMBO_FROM:
		return
	var k := 1.0
	var alpha := 1.0
	if _combo_out_at == -INF and now - _combo_at >= COMBO_HOLD:
		_combo_out_at = now
	if _combo_out_at > -INF:
		var u := (now - _combo_out_at) / COMBO_DEFLATE
		if u >= 1.0 or Motion.reduce:
			_combo_n = 0
			return
		k = 1.0 - 0.75 * u * u
		alpha = 1.0 - u
	elif not Motion.reduce:
		var e := now - _combo_at
		k = Motion.pop_in_scale(e).x if _combo_popped else Motion.bump_scale(e)
	if k <= 0.01:
		return
	var seen: Array = _seen.get(_combo_e, [])
	if not seen.is_empty() and state.where[_combo_e] == State.LOOP:
		_combo_pos = seen[0]
	var font: Font = CozyTheme.display(700)
	var text := "x%d" % _combo_n
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT).x
	var box := Vector2(tw + 30.0, COMBO_FONT + 16.0)
	var tail := _combo_pos + Vector2(0.0, -_loop_px * 0.45)
	var centre := tail + Vector2(box.x * 0.35, -box.y * 0.75)
	centre.x = clampf(centre.x, box.x * 0.5 + 4.0, size.x - box.x * 0.5 - 4.0)
	centre.y = maxf(centre.y, box.y * 0.5 + 4.0)
	var b := Face.Builder.new()
	var tip := tail - centre
	var root := Vector2(clampf(tip.x, -box.x * 0.3, box.x * 0.3), box.y * 0.3)
	b.polygon(PackedVector2Array([root + Vector2(-9.0, 0.0), tip, root + Vector2(9.0, 0.0)]), Pal.LINE)
	b.polygon(Face.Builder.round_rect(-box * 0.5 - Vector2(2.0, 2.0), box + Vector2(4.0, 4.0), box.y * 0.5 + 2.0), Pal.LINE)
	b.polygon(PackedVector2Array([root + Vector2(-6.5, -2.0), tip + (root - tip).normalized() * 3.0, root + Vector2(6.5, -2.0)]), Pal.SURFACE)
	b.polygon(Face.Builder.round_rect(-box * 0.5, box, box.y * 0.5), Pal.SURFACE)
	_combo_shown = b.mesh()
	_hud_layer.draw_set_transform(centre, 0.0, Vector2.ONE * k)
	_hud_layer.draw_mesh(_combo_shown, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	_hud_layer.draw_string(font, Vector2(-tw * 0.5, (font.get_ascent(COMBO_FONT) - font.get_descent(COMBO_FONT)) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, COMBO_FONT, Color(Pal.LEAF_DEEP, alpha))
	_hud_layer.draw_set_transform(Vector2.ZERO)

func _draw_toast(now: float) -> void:
	if _toast == "":
		return
	var since := now - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(_toast, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var wide := minf(room, text_w + TOAST_PAD)
	var tall := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [_toast, int(wide), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-wide, -tall) * 0.5, Vector2(wide, tall), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	# over the pill: the rug, the loop and the yard stay in sight
	var mid := Vector2(size.x * 0.5, _clear.x + HUD_ROW * 0.5)
	_hud_layer.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha * 0.94))
	var top := mid.y - tall * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - wide * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_hud_layer.draw_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_hud_layer.draw_multiline_string(font, Vector2(left, top), _toast, HORIZONTAL_ALIGNMENT_CENTER,
			wide - TOAST_PAD, TOAST_FONT, lines, Color(Pal.PAPER, alpha))

## A line the player has to see now, on the toast.
func _tell(text: String) -> void:
	_toast = text
	_toast_at = _now()
	_hud_layer.queue_redraw()

# --- the taps ---

## Touch and mouse, as every flat board takes them (touch is not mouse here:
## emulate_mouse_from_touch is off). A tap is a press and a release on one
## engine.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		var over := _engine_at(event.position)
		if event.pressed:
			_pressed = over
		else:
			if over >= 0 and over == _pressed:
				tap(over)
			_pressed = -1

func _can_play() -> bool:
	return not (is_done() or out_of_hearts or _solved_at > -INF)

## A tap on engine `e`: the front of a column of the shed, or one in the
## siding, goes to the loop. The harnesses and the tutorial call this too.
func tap(e: int) -> void:
	if not _can_play() or e < 0:
		return
	var why: int = state.judge(e)
	if why != State.OK:
		_refuse(e, why)
		return
	var now := _now()
	var was_idle: bool = state.idle()
	var column: int = state.col[e]
	var from_shed: bool = state.where[e] == State.SHED
	state.send(e)
	_glide(e, SEND_FLY, _rest * 0.35)
	if from_shed:
		for m in state.sheds[column]:
			_glide(m, SHIFT)
	if was_idle:
		# the loop's clock starts as the engine reaches the gate
		_next_tick = now + (0.0 if Motion.reduce else SEND_FLY)
		_tick_from = _next_tick - _tick_time
		_frac = 0.0
	_tag_bump = now
	fx.cue("send", randf_range(0.96, 1.04))
	_busy_for(SEND_FLY + 0.1)
	_request()
	note_move()

## A tap that does nothing says so with the sound and the shiver; a full
## loop says why, since nothing else on the screen does.
func _refuse(e: int, why: int) -> void:
	if why == State.REFUSED_BUSY or why == State.REFUSED_OVER:
		return
	fx.cue("locked")
	if not Motion.reduce:
		_shiver_at[e] = _now()
		_busy_for(Motion.SHIVER_TIME)
	if why == State.REFUSED_FULL:
		_tag_bump = _now()
		_tell(tr("TT_FULL") % State.ON_LOOP)
	_request()

# --- the loop's clock ---

func _ticking() -> bool:
	return not state.idle() and not state.jammed and not is_done()

## One tick of the loop: every engine a stop on, and what came of it.
func _tick() -> void:
	var now := _now()
	for ev: Array in state.tick():
		var e := int(ev[1])
		match int(ev[0]):
			State.PICK:
				_on_pick(e, int(ev[2]), int(ev[3]), now)
			State.RUN_END:
				_on_run_end(e, int(ev[2]))
			State.FULL:
				_on_full(e, now)
			State.PARK:
				_streak = 0
				_glide(e, PARK_FLY, _rest * 0.5)
				_after(0.0 if Motion.reduce else PARK_FLY, fx.cue.bind("park", randf_range(0.95, 1.05)))
				_busy_for(PARK_FLY + 0.1)
			State.HOME:
				_streak = 0
				_glide(e, PARK_FLY, _rest * 0.5)
				for m in state.sheds[state.col[e]]:
					if m != e:
						_glide(m, SHIFT)
				_after(0.0 if Motion.reduce else PARK_FLY, fx.cue.bind("home"))
				if not _told_home:
					_told_home = true
					_tell(tr("TT_HOME"))
				_busy_for(PARK_FLY + 0.1)
			State.JAM:
				_jam(e)
			State.WHOLE:
				_on_whole(int(ev[2]))
	if state.idle():
		_tag_bump = now
	check_solved()

## A cannon shoots the block it sees: the cork flies to it, the block
## bursts where it stands and the cannon kicks back; the tick climbs the
## run's scale.
func _on_pick(e: int, cell: int, n: int, now: float) -> void:
	var w: int = state.w
	_chunk_stale[(cell / w / CHUNK) * ceili(float(w) / CHUNK) + (cell % w) / CHUNK] = true
	if not Motion.reduce:
		var seen: Array = _seen.get(e, _target(e))
		var px := float(seen[2])
		_flights.append({"c": state.colour[e], "to": cell_centre(cell), "px": px, "at": now,
			"from": (seen[0] as Vector2) + Vector2.UP.rotated(float(seen[1])) * px * 0.5})
		_bump_at[e] = now
	# forty corks a second are one tick and one knock in PICK_GAP (fx.cue
	# holds the sound but knocks every time it is asked)
	if now - _pick_cue_at >= PICK_GAP:
		_pick_cue_at = now
		var step: int = RUN_STEP[clampi(state.band, 0, RUN_STEP.size() - 1)]
		var semis: int = RUN_SCALE[mini((n - 1) / step, RUN_SCALE.size() - 1)]
		fx.cue("pick", pow(2.0, semis / 12.0) * randf_range(TICK_VARY.x, TICK_VARY.y))
	_bump_pill()
	if n >= COMBO_FROM:
		_combo_popped = _combo_n < COMBO_FROM or _combo_out_at > -INF or _combo_e != e
		_combo_n = n
		_combo_e = e
		var where: Array = _seen.get(e, [])
		if not where.is_empty():
			_combo_pos = where[0]
		_combo_at = now
		_combo_out_at = -INF
		if RUN_CONFETTI.has(n) and not Motion.reduce:
			var seen: Array = _seen.get(e, [])
			if not seen.is_empty():
				fx.confetti(seen[0], 12, _lane * 3.0)
	_busy_for(PICK_FLY + BURST + 0.1)

## A run is over: a long one ends on its two notes and a sparkle.
func _on_run_end(e: int, n: int) -> void:
	if _combo_e == e and _combo_n >= COMBO_FROM and _combo_out_at == -INF:
		_combo_at = minf(_combo_at, _now() - COMBO_HOLD * 0.5)
	if n < BIG_RUN:
		return
	fx.cue("run")
	var seen: Array = _seen.get(e, [])
	if not seen.is_empty() and not Motion.reduce:
		fx.sparkle(seen[0], Pal.SUN)

## An engine with no room left: it pops off the track with a puff, and the
## ones that go home full one after another climb a note each.
func _on_full(e: int, now: float) -> void:
	var seen: Array = _seen.get(e, _target(e))
	var pos: Vector2 = seen[0]
	_from.erase(e)
	if not Motion.reduce:
		_pops[e] = {"pos": pos, "ang": seen[1], "px": seen[2], "at": now + PICK_FLY}
	var col: Color = Art.colour(state.colours[state.colour[e]])
	_after(0.0 if Motion.reduce else PICK_FLY, func() -> void:
		fx.cue("full", randf_range(0.97, 1.03))
		fx.puff(pos, col.lightened(0.3), 6)
		fx.ring(pos, _loop_px * 0.6, col))
	_streak += 1
	if _streak >= 2:
		var semis: int = STREAK_STEPS[mini(_streak - 2, STREAK_STEPS.size() - 1)]
		_after(PICK_FLY + 0.09, func() -> void:
			if not is_done():
				fx.cue("combo", pow(2.0, semis / 12.0), STREAK_DB))
	_busy_for(PICK_FLY + POP + 0.2)

## A colour is off the rug: its three notes and sparkles round the loop (no
## toast: it happens once a colour, and the pill is what is left).
func _on_whole(_c: int) -> void:
	if state.left <= 0:
		return
	_after(0.12, func() -> void:
		if is_done():
			return
		fx.cue("whole")
		if not Motion.reduce:
			var n: int = state.stops()
			for k in 6:
				fx.sparkle(loop_at(n * (k + 0.5) / 6.0 - 1.0), Pal.SUN))

func tip_line() -> Dictionary:
	return {"text": "", "mood": Face.Expr.HAPPY}

# --- the HUD's actions ---

func hints_left() -> int:
	return State.hints_for(state.band) + hints_extra - hints_used

## Sends the engine the state's own hand would, as the player sends it: a
## ring round it, a beat, then the tap.
func hint() -> bool:
	if not _can_play() or hints_left() <= 0:
		return false
	var e: int = state.hint()
	if e < 0 or state.judge(e) != State.OK:
		if e >= 0:
			_refuse(e, state.judge(e))
		return false
	hints_used += 1
	var at := engine_screen(e)
	fx.ring(at, _rest * 0.7, Pal.SUN)
	fx.sparkle(at, Pal.SUN)
	fx.cue("hint")
	_tell(tr("TT_HINTED"))
	_after(0.0 if Motion.reduce else HINT_BEAT, func() -> void:
		tap(e)
		_request())
	return true

## The rug as the day opened it: every block back, every engine in the shed.
## The hints a player spent are not refunded.
func reset_board() -> void:
	if is_done() or out_of_hearts:
		return
	_restart()
	_tell(tr("TT_RESET"))
	fx.cue("reset")

func _restart() -> void:
	_gen += 1
	state.reset()
	moves = 0
	_running = true
	_deal()
	_opened = _now() - Motion.ENTER_DELAY
	_busy_for(Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER, 1.0) + 0.1)
	_bump_pill()
	_request()

func is_solved() -> bool:
	return state.is_solved()

func completion_record() -> Dictionary:
	return {"taps": state.taps}

## A completed daily is rebuilt from its seed, so the rug opens full: every
## block is taken, the taps it took are put back and the picture stands
## whole, as the win left it.
func restore_completed_board() -> void:
	var now := _now()
	_gen += 1
	state.finish(int(completed_record.get("taps", state.par)))
	_deal()
	_opened = now - 10.0
	_solved_at = now - 10.0
	_win_pop_at = now - 10.0
	_slid_at = -INF
	_final_taps = state.taps
	_anim_until = 0.0
	_stamp_at = now - 10.0 if _stamped() else INF
	_seal_mesh = null
	_hud_layer.queue_redraw()
	_request()

func share_glyphs() -> String:
	return "%s\n🎯 %d" % [state.share_glyphs(), _final_taps]

# --- the win ---

## Whether the day earned the seal: any Insane rug, or one cleared in no
## more engines sent than the deal's own line.
func _stamped() -> bool:
	return state.band >= State.INSANE or _final_taps <= state.par

func flat_win() -> Dictionary:
	var what := tr(state.name_key) if state.name_key != "" else title()
	var sub := tr("TT_WIN_SUB_ONE") % what if _final_taps == 1 else tr("TT_WIN_SUB_N") % [what, _final_taps]
	return {"faces": [], "subtitle": sub}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT + PARTY_EXTRA

## The last engine goes home, the yard is put away, and the picture is put
## back whole from its middle outward: what all the tidying was of.
func _on_solved() -> void:
	var now := _now()
	_pressed = -1
	_toast = ""
	_combo_n = 0
	_solved_at = now
	_final_taps = state.taps
	var lag := 0.0 if Motion.reduce else PICK_FLY + BURST + POP + 0.25
	_win_pop_at = now + lag
	_blocks_stale = true
	_after(lag, fx.cue.bind("solved"))
	_hud_layer.queue_redraw()
	_party(lag)
	_busy_for(lag + Motion.stagger(state.w + state.h, WIN_STAGGER, 1.0) + 1.0 + WIN_SLIDE + 0.3)
	_request()

func _party(lag: float) -> void:
	var now := _now()
	if _stamped():
		_stamp_at = now if Motion.reduce else now + lag + STAMP_AT
		_seal_mesh = null
		_after(_stamp_at - now, func() -> void:
			fx.cue("stamp")
			_request())
		if not Motion.reduce:
			_after(_stamp_at - now + STAMP_DROP, fx.buzz.bind(Haptics.THUD))
			_busy_for(lag + STAMP_AT + STAMP_DROP * 3.0)
	if Motion.reduce:
		return
	_after(lag + 0.25, func() -> void:
		var field := _field_px()
		fx.confetti(Vector2(field.get_center().x, field.position.y + _cell), 30, field.size.x * 0.8)
		fx.cue("party"))
	_after(lag + 0.7, func() -> void:
		var field := _field_px()
		fx.confetti(field.get_center(), 24, field.size.x * 0.6))

## The seal on the picture's lower right, dropping in and settling.
func _draw_stamp(now: float, shown: Array, slide: Transform2D) -> void:
	var field := _field_px()
	var rad := maxf(field.size.x, 420.0) * STAMP_R
	var insane: bool = state.band >= State.INSANE
	if _seal_mesh == null:
		_seal_mesh = Seal.mesh(rad, insane)
	shown.append(_seal_mesh)
	var e := now - _stamp_at
	var k := 1.0
	if not Motion.reduce and e < STAMP_DROP * 2.0:
		var u := clampf(e / STAMP_DROP, 0.0, 1.0)
		k = lerpf(STAMP_FROM, 1.0, u * u) if e < STAMP_DROP else Motion.bump_scale(e - STAMP_DROP, 0.08, STAMP_DROP)
	var alpha := clampf(e / 0.08, 0.0, 1.0) if not Motion.reduce else 1.0
	var centre := field.end - Vector2(rad, rad) * 0.6
	var xf := slide * Transform2D(STAMP_TILT, Vector2(k, k), 0.0, centre)
	draw_set_transform_matrix(xf)
	draw_mesh(_seal_mesh, null, Transform2D.IDENTITY, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform_matrix(xf * Transform2D(0.0, -Vector2(rad, rad)))
	var neat: bool = _final_taps <= state.par
	var lines: Array
	if insane:
		lines = [[tr("BN_INSANE_SEAL"), 0.27, 0.02], [tr("TT_SEAL_NEAT") if neat else tr("TT_SEAL_INSANE"), 0.17, 0.36]]
	else:
		lines = [[tr("TT_SEAL_NEAT"), 0.24, 0.12]]
	Seal.text(self, rad, lines)
	draw_set_transform_matrix(slide)

# --- Insane's full siding ---

## An engine came round with room and the siding had no place: the loop
## stops and the day is lost, once the player has seen why.
func _jam(e: int) -> void:
	out_of_hearts = true
	_running = false
	if not Motion.reduce:
		_shiver_at[e] = _now()
	_after(0.0 if Motion.reduce else 0.5, _run_out)

func _run_out() -> void:
	if _asleep:
		return
	_asleep = true
	_pressed = -1
	fx.cue("out_of_hearts")
	_tell(tr("TT_JAM"))
	_request()
	_after(CARD_AFTER_STILL if Motion.reduce else CARD_AFTER, _open_card)

## The card, over the whole screen: on the host so it covers the chrome, or
## on the board's own viewport when there is none (a probe).
func _open_card() -> void:
	if not out_of_hearts or is_done() or is_instance_valid(_heart_card):
		return
	var card: Control = load(OUT_OF_HEARTS).new(_heart_used, ["TT_OUT_BODY", "TT_OUT_REST"], 0,
		{"title": "TT_OUT_TITLE", "more": "TT_OUT_MORE"})
	_heart_card = card
	card.try_again.connect(try_again)
	card.one_more_heart.connect(heart_back)
	card.leave.connect(_leave)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

## Try again: the same rug from the top, the clock from zero.
func try_again() -> void:
	if is_done():
		return
	_close_card()
	elapsed = 0.0
	_restart()
	fx.cue("reset")
	moved.emit()

## The card's video, once a board: the siding is cleared back to the shed and
## the loop runs again.
func heart_back() -> void:
	if is_done() or not out_of_hearts:
		return
	_close_card()
	_heart_used = true
	state.rescue()
	for e in state.colour.size():
		if state.where[e] == State.SHED:
			_glide(e, PARK_FLY, _rest * 0.4)
	out_of_hearts = false
	_asleep = false
	_running = true
	_next_tick = _now() + _tick_time
	_tick_from = _now()
	fx.cue("heart_back")
	_busy_for(PARK_FLY + 0.2)
	_request()
	moved.emit()

func _leave() -> void:
	_close_card()
	finish_unsolved()
	leave.emit()

func _close_card() -> void:
	if is_instance_valid(_heart_card) and not _heart_card.is_queued_for_deletion():
		_heart_card.queue_free()
	_heart_card = null

# --- entrance ---

## The chrome is the host's; here the rug pops in wide and the blocks pop
## onto it along the diagonals.
func _enter() -> void:
	_opened = _now()
	_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.POP_IN + Motion.stagger(state.w + state.h, Motion.ENTER_STAGGER, 1.0) + 0.1)
	fx.cue("enter")

# --- odds and ends ---

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	if delay <= 0.0:
		what.call()
		return
	var gen := _gen
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0:
		return
	var now := _now()
	if _ticking():
		var n := 0
		while now >= _next_tick and n < 4 and _ticking():
			_tick_from = _next_tick
			_next_tick += _tick_time
			_tick()
			n += 1
		if now >= _next_tick:
			# a long frame: the loop does not sprint to catch up
			_tick_from = now
			_next_tick = now + _tick_time
		_frac = clampf((now - _tick_from) / _tick_time, 0.0, 1.0)
		_request()
	elif now < _anim_until or now - _slid_at < WIN_SLIDE + 0.1 or not _from.is_empty() \
			or not _flights.is_empty() or not _pops.is_empty():
		_request()
	var since := now - _opened - Motion.ENTER_DELAY
	if since < Motion.DROP_FADE + 0.1 or now - _pill_bump < Motion.BUMP_TIME + 0.1 \
			or (_toast != "" and now - _toast_at < TOAST_HOLD + 0.1) \
			or (_combo_n >= COMBO_FROM and (now - _combo_at < COMBO_HOLD + 0.1 or _combo_out_at > -INF or _ticking())):
		_hud_layer.queue_redraw()

func _request() -> void:
	queue_redraw()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
