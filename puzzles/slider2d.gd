extends "res://core/puzzle_base.gd"

## Super Slider as a flat board: a walnut tray of painted wooden blocks on a
## lawn, after the handheld the user brought (a red big block, blue bars,
## yellow squares, and a green mat at the gate). Drag a block and it follows
## the finger through the empty cells, round corners too, never over another;
## bring the big block down onto the mat in the gate and the doors swing open
## and it walks out. The rules live in puzzles/slider_state.gd, which this
## only draws.
##
## **Nothing wrong can sit in the tray**, so there is no Check, no tray row
## and no actions row: Undo, Reset and Hint ride in the top bar -- Pinwheel's
## shape. A line over the tray keeps the count against the day's shortest.
##
## How it is drawn. Two meshes:
##   still -- the lawn, the path out of the gate and the tray, rebuilt only on
##            a relayout;
##   live  -- the mat's glow, the blocks and the gate's doors, rebuilt only
##            while something moves. An idle tray costs nothing.
## The blocks are ui/faces/slider_block.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-super-slider-flat-design.md.

const State = preload("res://puzzles/slider_state.gd")
const Gen = preload("res://puzzles/slider_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Block = preload("res://ui/faces/slider_block.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- the screen, measured ---
## The card's inset round the tray, the largest cell, the card's corner, the
## band over the tray the count line takes, and how far the path out of the
## gate runs below the frame, in cells.
const INSET := 44.0
const CELL_CAP := 230.0
const CARD_RADIUS := 32.0
const COUNT_BAND := 90.0
const COUNT_FONT := 38
const PATH := 0.9

# --- this board's own motion ---
## A let-go block settles onto its cell over SNAP_TIME; a hint's or an undo's
## block slides its path at SLIDE_SPEED cells a second. A block pushed at a
## wall gives RUBBER of a cell and no more. A landing is a dip of LAND over
## LAND_TIME.
const SNAP_TIME := 0.16
const SLIDE_SPEED := 7.0
const RUBBER := 0.07
const LAND := 0.08
const LAND_TIME := 0.22
## The win: the big block lands, the mat lights over GLOW_TIME, the doors
## swing open over DOOR_TIME, and the big block walks EXIT cells out of the
## gate over EXIT_TIME while the others hop in a wave from the gate; the win
## screen waits WIN_HOLD past that.
const GLOW_TIME := 0.3
const DOOR_TIME := 0.35
const EXIT := 1.8
const EXIT_TIME := 0.85
const WIN_HOLD := 0.9
const HINTS := 3
## The polish (the spec's section 8). A held block leans along its travel by
## LEAN_PER a cell a second, at most LEAN_MAX a side; the drawn anchor chases
## the finger's at FOLLOW a second so a step glides rather than snaps. A
## knocked block shivers KNOCK of a cell over KNOCK_TIME and the block in its
## way flinches FLINCH. The big block watches the held one, its face moving
## up to GAZE of a cell, and blinks every BLINK_MIN to BLINK_MAX seconds. The
## hint leaves a trail of dots that fades over TRAIL_FADE. The big block
## walks out in EXIT_STEPS hops.
const LEAN_PER := 0.012
const LEAN_MAX := 0.07
const FOLLOW := 28.0
const KNOCK := 0.035
const KNOCK_TIME := 0.24
const FLINCH := 0.03
const GAZE := 0.07
const BLINK_MIN := 2.8
const BLINK_MAX := 5.5
const TRAIL_FADE := 0.6
const EXIT_STEPS := 3
const ENTER_DROP := 0.35
## The toast: Knight's, measure for measure.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0

const TIP_CYCLE := 8.0
const TIPS := ["SL_TIP_DRAG", "SL_TIP_GOAL", "SL_TIP_CORNER"]

var _state = State.new()
var fx: Node2D

## How each block is travelling: {"pts" (anchors in cells, float), "at",
## "dur", "land" (dips as it arrives)}.
var _disp: Array = []
## A drag: {"p", "grab" (finger less anchor, cells), "before", "at", "v"
## (the anchor as drawn), "bumped"}; empty when none.
var _drag := {}
var _rings: Array = []
## Knocks and flinches: {"p", "at", "dir" (unit, cells), "amp"}.
var _knocks: Array = []
## The hint's trail: {"pts" (centres, cells), "at", "dur"}; empty when none.
var _trail := {}
## Where the big block's face is looking (fraction of a cell), eased.
var _gaze := Vector2.ZERO
var _blink_at := 0.0
var _last_dust := 0.0
var _opened := 0.0
var _anim_until := 0.0
## When the big block stood on the mat, and the gate starts to open.
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _toast := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "slider"
func title() -> String: return "Super Slider"

func rules() -> String:
	return tr("SL_RULES")

## Undo and Hint; Reset is the host's. No Check: nothing wrong can sit here.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
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

func _exit_tree() -> void:
	_state.abandon()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_disp = []
	for p in _state.blocks.size():
		_disp.append(_still_at(p))
	_drag = {}
	_rings = []
	_knocks = []
	_trail = {}
	_gaze = Vector2.ZERO
	_blink_at = _now() + 2.0
	_toast = ""
	_toast_at = -100.0
	_anim_until = 0.0
	_solved_at = -1.0
	_opened = _now()
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

func _still_at(p: int) -> Dictionary:
	return {"pts": PackedVector2Array([_xy(_state.at(p))]), "at": -100.0, "dur": 0.0, "land": false}

# --- layout ---

func _cell() -> float:
	var w := float(Gen.COLS) + 2.0 * Block.FRAME
	var h := float(Gen.ROWS) + 2.0 * Block.FRAME + PATH
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * INSET) / w, (size.y - 2.0 * INSET - COUNT_BAND) / h)))

func _grid_size() -> Vector2:
	return Vector2(Gen.COLS, Gen.ROWS) * _cell()

## The floor's top-left: the tray, its frame and the path below it centred
## in the room under the count line.
func _origin() -> Vector2:
	var s := _cell()
	var tall := (float(Gen.ROWS) + 2.0 * Block.FRAME + PATH) * s
	var top := COUNT_BAND + (size.y - COUNT_BAND - tall) * 0.5
	return Vector2((size.x - _grid_size().x) * 0.5, top + Block.FRAME * s)

## A cell index as its column and row.
static func _xy(c: int) -> Vector2:
	return Vector2(c % Gen.COLS, c / Gen.COLS)

func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _cell()

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _pt(Vector2(c, r) + Vector2(0.5, 0.5))

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_refresh()

# --- where a block is drawn ---

## Block `p`'s anchor as drawn at `t`, in cells: the finger's while dragged,
## else along its travel.
func _vis(p: int, t: float) -> Vector2:
	if not _drag.is_empty() and int(_drag.p) == p:
		return _drag.v
	var d: Dictionary = _disp[p]
	var pts: PackedVector2Array = d.pts
	var home := _xy(_state.at(p))
	var dur: float = d.dur
	if Motion.reduce or pts.size() < 2 or dur <= 0.0:
		return home
	var u := (t - float(d.at)) / dur
	if u >= 1.0:
		return home
	if u <= 0.0:
		return pts[0]
	# a short settle springs onto its cell; a path eases along its length
	var e := Motion.back_out(u) if pts.size() == 2 else u * u * (3.0 - 2.0 * u)
	return _along(pts, e)

static func _along(pts: PackedVector2Array, e: float) -> Vector2:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	if total <= 0.0:
		return pts[pts.size() - 1]
	var want := total * e
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if want <= seg or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], want / maxf(seg, 1e-6))
		want -= seg
	return pts[pts.size() - 1]

## A block's lift off the floor: up as a finger takes it, down as it lands.
func _lift(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return 1.0 if Motion.reduce else clampf((t - float(_drag.at)) / Motion.LIFT_TIME, 0.0, 1.0)
	var d: Dictionary = _disp[p]
	if Motion.reduce or not d.land:
		return 0.0
	return 1.0 - clampf((t - float(d.at)) / maxf(float(d.dur), 1e-3), 0.0, 1.0)

## A landing block's dip as it arrives on its cell.
func _squash(p: int, t: float) -> float:
	var d: Dictionary = _disp[p]
	if Motion.reduce or not d.land:
		return 0.0
	var e := t - float(d.at) - float(d.dur)
	if e < 0.0 or e >= LAND_TIME:
		return 0.0
	return LAND * sin(PI * e / LAND_TIME)

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.15 - Motion.stagger(i, 0.05)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

## How far block `i` still has to fall into the tray as it enters, in cells:
## the blocks drop in down the reading order as they pop.
func _entry_drop(i: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.15 - Motion.stagger(i, 0.05)
	return ENTER_DROP * (1.0 if e <= 0.0 else Motion.drop_in_lift(e, 1.0, Motion.DROP_TIME))

## The big block's eyes: shut for a blink, else open.
func _eye(t: float) -> float:
	if Motion.reduce or _solved_at >= 0.0:
		return 1.0
	var e := t - _blink_at
	if e < 0.0 or e > Face.BLINK_TIME:
		return 1.0
	return absf(cos(PI * e / Face.BLINK_TIME))

## A knock's or a flinch's offset on block `p`, in cells.
func _knock(p: int, t: float) -> Vector2:
	if Motion.reduce:
		return Vector2.ZERO
	var off := Vector2.ZERO
	for k: Dictionary in _knocks:
		if int(k.p) != p:
			continue
		var e := t - float(k.at)
		if e < 0.0 or e >= KNOCK_TIME:
			continue
		# a damped wobble along the push: out, back past, and still
		off += Vector2(k.dir) * float(k.amp) * sin(TAU * 1.5 * e / KNOCK_TIME) * (1.0 - e / KNOCK_TIME)
	return off

# --- the win's clock ---

func _glow(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf((t - _solved_at) / GLOW_TIME, 0.0, 1.0)

func _door(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((t - _solved_at - GLOW_TIME) / DOOR_TIME, 0.0, 1.0))

## How far the big block has walked out of the gate, in cells.
func _exit(t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	if Motion.reduce:
		return EXIT
	var u := clampf((t - _solved_at - GLOW_TIME - DOOR_TIME * 0.6) / EXIT_TIME, 0.0, 1.0)
	# EXIT_STEPS hops: each one eases its own share of the way
	var n := float(EXIT_STEPS)
	var k := minf(floorf(u * n), n - 1.0)
	var f := u * n - k
	return EXIT * (k + f * f * (3.0 - 2.0 * f)) / n

## The big block's hop as it walks out: up and down once a step, in cells.
func _exit_hop(t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var u := (t - _solved_at - GLOW_TIME - DOOR_TIME * 0.6) / EXIT_TIME
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return 0.22 * sin(PI * fmod(u * float(EXIT_STEPS), 1.0))

## The others' hop as the big block leaves: a wave out from the gate.
func _cheer(p: int, t: float) -> float:
	if _solved_at < 0.0 or Motion.reduce:
		return 0.0
	var c := _xy(_state.at(p)) + Vector2(_state.size_of(p)) * 0.5
	var far := c.distance_to(_xy(Gen.GOAL) + Vector2.ONE)
	var e := t - _solved_at - GLOW_TIME - DOOR_TIME - far * 0.08
	return Motion.hop_lift(e, Motion.SOLVE_HOP, Motion.SOLVE_TIME) * 0.012

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.blocks.is_empty():
		return
	var t := _now()
	_ease_gaze(t, delta)
	if not Motion.reduce and _solved_at < 0.0 and t > _blink_at + Face.BLINK_TIME:
		_blink_at = t + randf_range(BLINK_MIN, BLINK_MAX)
	if not _drag.is_empty():
		_chase(delta)
	if _animating(t) or _blinking(t):
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		# the toast is drawn apart from the meshes: a redraw, not a rebuild
		queue_redraw()

func _animating(t: float) -> bool:
	if t < _anim_until or not _drag.is_empty():
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + 0.15 + Motion.stagger(_state.blocks.size(), 0.05) + Motion.POP_IN + 0.1
	return t - _opened < entrance

func _blinking(t: float) -> bool:
	return not Motion.reduce and t >= _blink_at and t <= _blink_at + Face.BLINK_TIME + 0.05

## Where the big block wants to look: at the held block, else at the gate
## when it stands over the mat, else ahead. Eased toward it; while it is still
## turning its eyes the tray keeps drawing.
func _ease_gaze(t: float, delta: float) -> void:
	var want := Vector2.ZERO
	var big: int = _state.big()
	if big < 0:
		return
	var me := _xy(_state.at(big)) + Vector2.ONE
	if not _drag.is_empty() and int(_drag.p) != big:
		var p: int = _drag.p
		var there: Vector2 = Vector2(_drag.v) + Vector2(_state.size_of(p)) * 0.5
		want = (there - me).limit_length(1.0) * GAZE
	elif _solved_at >= 0.0:
		want = Vector2(0.0, GAZE)
	if Motion.reduce:
		_gaze = want
		return
	var was := _gaze
	_gaze = _gaze.lerp(want, 1.0 - exp(-delta * 10.0))
	if _gaze.distance_to(was) > 0.0005:
		_busy_for(0.05)

## The drawn anchor of the held block chases the finger's, so a step between
## cells glides, and its speed leans the block.
func _chase(delta: float) -> void:
	var want: Vector2 = _drag.want
	var was: Vector2 = _drag.v
	var v := want if Motion.reduce else was.lerp(want, 1.0 - exp(-delta * FOLLOW))
	if v.distance_to(want) < 0.002:
		v = want
	var vel := (v - was) / maxf(delta, 1e-3)
	_drag.vel = Vector2(_drag.vel).lerp(vel, 0.5)
	_drag.v = v

## The held block's lean, signed along its travel, in cells.
func _lean(p: int) -> Vector2:
	if Motion.reduce or _drag.is_empty() or int(_drag.p) != p:
		return Vector2.ZERO
	var vel: Vector2 = _drag.vel
	var l := Vector2(clampf(vel.x * LEAN_PER, -LEAN_MAX, LEAN_MAX), clampf(vel.y * LEAN_PER, -LEAN_MAX, LEAN_MAX))
	if absf(l.x) >= absf(l.y):
		l.y = 0.0
	else:
		l.x = 0.0
	return l if l.length() > 0.004 else Vector2.ZERO

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_live = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.blocks.is_empty() or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var mid := size * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	var shown: Array = []
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_count(seen)
	_draw_toast(t, shown)
	_shown = shown

## The lawn round the tray, a few tufts, the stepping stones out of the gate,
## and the tray itself. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	b.fan(Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0), Pal.SLIDE_LAWN)
	# mown stripes, very faint
	var stripe := s * 0.9
	var k := 0
	var x0 := 2.0
	while x0 < size.x - 2.0:
		if k % 2 == 0:
			b.fan(PackedVector2Array([Vector2(x0, 12.0), Vector2(minf(x0 + stripe, size.x - 2.0), 12.0),
				Vector2(minf(x0 + stripe, size.x - 2.0), size.y - 12.0), Vector2(x0, size.y - 12.0)]), Color(1.0, 1.0, 1.0, 0.07))
		x0 += stripe
		k += 1
	var inside := Rect2(o - Vector2.ONE * s * 0.45, g + Vector2(s * 0.9, s * (0.45 + PATH + 0.45)))
	var gx := o.x + s * float(Gen.GOAL % Gen.COLS)
	var path := Rect2(Vector2(gx - s * 0.3, o.y + g.y), Vector2(s * 2.6, size.y))
	# bushes tucked into the card's corners, clipped by its edge
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := Vector2(corner.x * size.x, corner.y * size.y) + (Vector2.ONE - corner * 2.0) * s * 0.42
		_bush(b, at, s * 0.3, int(corner.x + corner.y * 2.0))
	# clover and tufts, and daisies here and there, off the tray and the path
	for i in 120:
		var at := Vector2(_hash(i, 3) * size.x, 14.0 + _hash(i, 11) * (size.y - 28.0))
		if inside.has_point(at) or path.has_point(at):
			continue
		match i % 4:
			0, 1:
				_tuft(b, at, s * (0.13 + 0.08 * _hash(i, 17)))
			2:
				_clover(b, at, s * (0.07 + 0.03 * _hash(i, 19)), _hash(i, 23) * TAU)
			3:
				_daisy(b, at, s * (0.06 + 0.02 * _hash(i, 29)))
	# the path out of the gate: flat stones down to the card's hem, a tuft
	# beside every other one
	var y := o.y + g.y + Block.FRAME * s + s * 0.18
	var n := 0
	while y < size.y + s * 0.3 and n < 7:
		var w := s * (1.3 - 0.06 * float(n))
		var c := Vector2(gx + s + (s * 0.12 if n % 2 == 0 else -s * 0.12), y + s * 0.2)
		b.ellipse(c + Vector2(0.0, s * 0.05), w * 0.52, s * 0.21, Pal.SLIDE_LAWN_DEEP)
		b.ellipse(c, w * 0.5, s * 0.18, Pal.SLIDE_STONE)
		b.ellipse(c + Vector2(-w * 0.08, -s * 0.05), w * 0.3, s * 0.07, Pal.SLIDE_STONE_HI)
		if n % 2 == 1:
			_tuft(b, c + Vector2(w * 0.62, s * 0.12), s * 0.14)
		else:
			_tuft(b, c + Vector2(-w * 0.62, s * 0.12), s * 0.12)
		y += s * 0.5
		n += 1
	Block.tray(b, o, s)
	return b.mesh()

static func _tuft(b: Face.Builder, at: Vector2, h: float) -> void:
	for k in 3:
		var ang := -PI * 0.5 + (float(k) - 1.0) * 0.45
		var tip := at + Vector2(cos(ang), sin(ang)) * h
		b.fan(PackedVector2Array([at + Vector2(-h * 0.12, 0.0), tip, at + Vector2(h * 0.12, 0.0)]), Pal.SLIDE_LAWN_DEEP)

## A round bush of three lobes in two greens, a few leaves lit on top.
static func _bush(b: Face.Builder, at: Vector2, r: float, k: int) -> void:
	var lobes := [Vector2(-0.7, 0.15), Vector2(0.7, 0.2), Vector2(0.0, -0.25)]
	for l: Vector2 in lobes:
		b.disc(at + l * r + Vector2(0.0, r * 0.12), r * 0.75, Pal.SLIDE_BUSH_DEEP)
	for l: Vector2 in lobes:
		b.disc(at + l * r, r * 0.7, Pal.SLIDE_BUSH)
	for i in 4:
		var a := -PI * 0.5 + (_hash(k, i) - 0.5) * 2.4
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.75, r * 0.14, r * 0.08, Pal.SLIDE_BUSH_HI)

## A three-leaf clover at `at`, leaves `r` across, turned `turn`.
static func _clover(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for k in 3:
		var a := turn + TAU * float(k) / 3.0
		b.disc(at + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.55, Pal.SLIDE_CLOVER)
	b.disc(at, r * 0.18, Pal.SLIDE_LAWN_DEEP)

## A small daisy: five white petals and a yellow eye.
static func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 5:
		var a := TAU * float(k) / 5.0
		b.ellipse(at + Vector2(cos(a), sin(a)) * r * 0.6, r * 0.42, r * 0.42, Pal.PAPER)
	b.disc(at, r * 0.36, Pal.SLIDE_SQ)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## The mat's glow, a hint's ring, every block where it is drawn (the held
## one last, over the rest), and the gate's doors.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var glow := _glow(t)
	if glow > 0.0:
		Block.mat(b, o, s, glow)
	for c in Gen.N:
		if _state.block_at(c) < 0:
			Block.hollow(b, _pt(_xy(c)), s)
	_draw_trail(b, t)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.5 + 0.5 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.06 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	var order: Array = range(_state.blocks.size())
	var held: int = int(_drag.p) if not _drag.is_empty() else -1
	var big: int = _state.big()
	# the big block walks out over the frame, so it is drawn after the doors
	order.sort_custom(func(a, z): return _rank(a, held, big) < _rank(z, held, big))
	var doors_drawn := false
	for p: int in order:
		if p == big and _solved_at >= 0.0 and not doors_drawn:
			Block.doors(b, o, s, _door(t))
			doors_drawn = true
		_block(b, p, t)
	if not doors_drawn:
		Block.doors(b, o, s, _door(t))
	return b.mesh() if not b.verts.is_empty() else null

## The hint's trail: a dotted line down the way the block goes, drawn ahead
## of it as it slides and fading once it has landed.
func _draw_trail(b: Face.Builder, t: float) -> void:
	if _trail.is_empty() or Motion.reduce:
		return
	var e := t - float(_trail.at)
	var dur: float = _trail.dur
	var fade := 1.0 - clampf((e - dur) / TRAIL_FADE, 0.0, 1.0)
	if e < 0.0 or fade <= 0.0:
		if e >= dur + TRAIL_FADE:
			_trail = {}
		return
	var pts: PackedVector2Array = _trail.pts
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var s := _cell()
	var n := int(total / 0.22)
	for k in range(1, n):
		var u := float(k) / float(n)
		var at := _pt(_along(pts, u))
		# dots pop in down the way, a beat ahead of the block
		var shown := clampf((e / maxf(dur, 1e-3) + 0.25 - u) * 5.0, 0.0, 1.0)
		if shown <= 0.0:
			continue
		b.disc(at, s * 0.045 * shown, Color(Pal.SUN, 0.8 * fade))

static func _rank(p: int, held: int, big: int) -> int:
	if p == held:
		return 2
	if p == big:
		return 1
	return 0

func _block(b: Face.Builder, p: int, t: float) -> void:
	var s := _cell()
	var cells := _state.size_of(p)
	var v := _vis(p, t)
	var lift := _lift(p, t)
	var expr := Face.Expr.HAPPY
	var squash := _squash(p, t)
	var look := Vector2.ZERO
	var eye := 1.0
	if p == _state.big():
		v.y += _exit(t)
		look = _gaze
		eye = _eye(t)
		if _solved_at >= 0.0:
			expr = Face.Expr.JOY
			var hop := _exit_hop(t)
			v.y -= hop
			lift = maxf(lift, hop * 3.0)
			# each hop lands with a small squash
			if hop > 0.0 and hop < 0.05:
				squash = maxf(squash, 0.05 - hop)
		elif _knocked(p, t):
			expr = Face.Expr.WORRIED
	else:
		v.y += _cheer(p, t)
	v += _knock(p, t)
	v.y -= _entry_drop(p, t)
	var at := _pt(v)
	var e := _entry(p, t)
	var cell := s
	if absf(e - 1.0) > 0.001:
		var mid := at + Vector2(cells) * s * 0.5
		cell = s * e
		at = mid - Vector2(cells) * cell * 0.5
	Block.block(b, at, cells, cell, _state.kind(p), lift, squash, expr, _lean(p), look, eye)

func _knocked(p: int, t: float) -> bool:
	for k: Dictionary in _knocks:
		if int(k.p) == p and t - float(k.at) < KNOCK_TIME * 2.0:
			return true
	return false

## The count over the tray: moves so far against the day's shortest.
func _draw_count(alpha: float) -> void:
	var font: Font = CozyTheme.body(700)
	var text: String = tr("SL_COUNT_ONE") % _state.par if moves == 1 else tr("SL_COUNT") % [moves, _state.par]
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT).x
	var top := _origin().y - Block.FRAME * _cell()
	var y := minf(COUNT_BAND, top) * 0.5 + font.get_ascent(COUNT_FONT) * 0.5 + 8.0
	draw_string(font, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
		Color(Pal.TEXT, 0.75 * alpha))

## The toast over the foot of the card -- Knight's `_draw_toast`.
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

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_move(event.position)
		accept_event()

## A local point in cells (a cell's top-left is its column and row).
func _to_cells(local: Vector2) -> Vector2:
	return (local - _origin()) / maxf(_cell(), 1e-3)

func _press(local: Vector2) -> void:
	var v := _to_cells(local)
	if v.x < 0.0 or v.y < 0.0 or v.x >= Gen.COLS or v.y >= Gen.ROWS:
		return
	var p: int = _state.block_at(int(v.y) * Gen.COLS + int(v.x))
	if p < 0:
		return
	var t := _now()
	var a := _xy(_state.at(p))
	_drag = {"p": p, "grab": v - a, "before": _state.snapshot(), "at": t, "v": a, "want": a, "vel": Vector2.ZERO, "bumped": {}}
	fx.cue("lift")
	_refresh()

## The block under the finger steps a cell at a time toward where the finger
## would carry it, the longer way first, and round a corner when that way is
## shut; what is left over is drawn as an offset, half a cell toward an open
## way and RUBBER toward a shut one.
func _move(local: Vector2) -> void:
	var p: int = _drag.p
	var target := _to_cells(local) - Vector2(_drag.grab)
	for i in 12:
		var a := _xy(_state.at(p))
		var d := target - a
		var axes: Array = [0, 1] if absf(d.x) >= absf(d.y) else [1, 0]
		var stepped := false
		for axis: int in axes:
			var comp: float = d.x if axis == 0 else d.y
			if absf(comp) < 0.5:
				continue
			var dx := int(signf(comp)) if axis == 0 else 0
			var dy := int(signf(comp)) if axis == 1 else 0
			if _state.step(p, dx, dy):
				fx.cue("step", 1.0 + 0.04 * float(randi() % 3))
				_dust(p, Vector2(dx, dy))
				stepped = true
				break
			_bump(p, dx, dy)
		if not stepped:
			break
	var a := _xy(_state.at(p))
	var d := target - a
	var off := Vector2(_give(p, d.x, 1, 0), _give(p, d.y, 0, 1))
	if absf(off.x) >= absf(off.y):
		off.y = 0.0
	else:
		off.x = 0.0
	_drag.want = a + off
	if Motion.reduce:
		_drag.v = _drag.want
	_refresh()

## How far a block drawn under the finger may lean off its cell along one
## axis: toward an open cell up to half of one, toward a shut one RUBBER.
func _give(p: int, comp: float, ux: int, uy: int) -> float:
	if absf(comp) < 1e-4:
		return 0.0
	var dir := int(signf(comp))
	var open := _can_step(p, ux * dir, uy * dir)
	var lim := 0.5 if open else RUBBER
	return clampf(comp, -lim, lim)

func _can_step(p: int, dx: int, dy: int) -> bool:
	if _state.step(p, dx, dy):
		_state.step(p, -dx, -dy)
		return true
	return false

## A block pushed into a wall or another block knocks once, the first time
## the finger drags it half a cell that way from a cell.
func _bump(p: int, dx: int, dy: int) -> void:
	var key := "%d|%d|%d" % [_state.at(p), dx, dy]
	if _drag.bumped.has(key):
		return
	_drag.bumped[key] = true
	fx.cue("bump")
	var t := _now()
	var dir := Vector2(dx, dy)
	_knocks.append({"p": p, "at": t, "dir": dir, "amp": KNOCK})
	# whatever stands just past the leading edge flinches away from the knock,
	# one cell per row or column the block spans
	var here := _xy(_state.at(p))
	var sz := Vector2(_state.size_of(p))
	var edge := here + (Vector2(sz.x, 0.0) if dx > 0 else Vector2(0.0, sz.y) if dy > 0 else dir)
	var along := Vector2(0.0, 1.0) if dx != 0 else Vector2(1.0, 0.0)
	var hit := {}
	for i in int(sz.y if dx != 0 else sz.x):
		var ahead := edge + along * float(i)
		if ahead.x < 0 or ahead.y < 0 or ahead.x >= Gen.COLS or ahead.y >= Gen.ROWS:
			continue
		var q: int = _state.block_at(int(ahead.y) * Gen.COLS + int(ahead.x))
		if q >= 0 and q != p and not hit.has(q):
			hit[q] = true
			_knocks.append({"p": q, "at": t + 0.03, "dir": dir, "amp": FLINCH})
	_drop_knocks(t)
	_busy_for(KNOCK_TIME * 2.0 + 0.05)

func _drop_knocks(t: float) -> void:
	var keep: Array = []
	for k: Dictionary in _knocks:
		if t - float(k.at) < KNOCK_TIME * 2.0:
			keep.append(k)
	_knocks = keep

## A wisp of dust off the trailing edge of block `p` as it steps `dir`.
func _dust(p: int, dir: Vector2) -> void:
	if Motion.reduce:
		return
	var t := _now()
	if t - _last_dust < 0.07:
		return
	_last_dust = t
	var sz := Vector2(_state.size_of(p))
	var mid := _xy(_state.at(p)) + sz * 0.5
	var back := mid - dir * (sz * 0.5 + Vector2.ONE * 0.1)
	fx.puff(_pt(back), Pal.SLIDE_GROOVE, 3)

func _release() -> void:
	if _drag.is_empty():
		return
	var t := _now()
	var p: int = _drag.p
	var from: Vector2 = _drag.v
	var before: Array = _drag.before
	_drag = {}
	_disp[p] = {"pts": PackedVector2Array([from, _xy(_state.at(p))]), "at": t, "dur": SNAP_TIME, "land": true}
	_busy_for(SNAP_TIME + LAND_TIME)
	if _state.commit(before):
		_land_puff(p, SNAP_TIME)
		fx.cue("slide")
		note_move()
	else:
		fx.cue("drop")
	_refresh()

## A little puff where block `p` lands, as it lands.
func _land_puff(p: int, after: float) -> void:
	if Motion.reduce:
		return
	var s := _cell()
	var at := _pt(_xy(_state.at(p)) + Vector2(_state.size_of(p)) * Vector2(0.5, 1.0)) - Vector2(0.0, s * 0.08)
	get_tree().create_timer(after).timeout.connect(func(): fx.puff(at, Pal.SURFACE, 4))

func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": at, "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line and the toast.
func _tell(key: String, mood: int) -> void:
	_say(tr(key), mood)
	_toast = key
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

## Every block whose cell changed since `before` travels to its new one:
## along the way it could slide when only it moved (an undo), straight and
## staggered when several did (a reset).
func _settle(before: Array, t: float, stagger := 0.0) -> void:
	var moved_ps: Array = []
	for p in before.size():
		if int(before[p][1]) != _state.at(p):
			moved_ps.append(p)
	var k := 0
	var longest := 0.0
	for p: int in moved_ps:
		var from := _xy(int(before[p][1]))
		var pts := PackedVector2Array()
		if moved_ps.size() == 1:
			var back: PackedInt32Array = _state.path(p, int(before[p][1]))
			for i in range(back.size() - 1, -1, -1):
				pts.append(_xy(back[i]))
		if pts.size() < 2:
			pts = PackedVector2Array([from, _xy(_state.at(p))])
		var dur := _travel(pts)
		var at := t + Motion.stagger(k, stagger)
		_disp[p] = {"pts": pts, "at": at, "dur": dur, "land": true}
		longest = maxf(longest, at - t + dur)
		k += 1
	_busy_for(longest + LAND_TIME)

static func _travel(pts: PackedVector2Array) -> float:
	var len := 0.0
	for i in range(1, pts.size()):
		len += pts[i].distance_to(pts[i - 1])
	return maxf(SNAP_TIME, len / SLIDE_SPEED)

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Puts the blocks back as they were before the last move. Counts no move.
func undo() -> bool:
	var before: Array = _state.snapshot()
	if is_done() or not _state.undo():
		return false
	_drag = {}
	_settle(before, _now())
	_tell("SL_UNDONE", Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS + hints_extra - hints_used)

## Plays the next move of a shortest way out, sliding its block along the
## way it goes.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var m: Dictionary = _state.hint_move()
	if m.is_empty():
		return false
	var p: int = m.p
	var pts := PackedVector2Array()
	for c in m.path:
		pts.append(_xy(c))
	if not _state.play(p, m.to):
		return false
	_drag = {}
	hints_used += 1
	var t := _now()
	var dur := _travel(pts)
	_disp[p] = {"pts": pts, "at": t, "dur": dur, "land": true}
	var centres := PackedVector2Array()
	for q in pts:
		centres.append(q + Vector2(_state.size_of(p)) * 0.5)
	_trail = {"pts": centres, "at": t, "dur": dur}
	_busy_for(dur + LAND_TIME + TRAIL_FADE)
	_ring_at(_pt(_xy(m.to) + Vector2(_state.size_of(p)) * 0.5), t + dur)
	_land_puff(p, dur)
	_tell("SL_HINT", Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	var before: Array = _state.snapshot()
	_drag = {}
	_trail = {}
	_knocks = []
	if _state.reset_board():
		_settle(before, _now(), Motion.RESET_STAGGER)
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: the day's blocks by colour.
func share_glyphs() -> String:
	var bars := 0
	var squares := 0
	for p in _state.blocks.size():
		match _state.kind(p):
			Gen.SQ: squares += 1
			Gen.V0, Gen.H0: bars += 1
	return "🟥" + "🟦".repeat(bars) + "🟨".repeat(squares)

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SL_WIN") % [moves, _state.par]}

## The win screen waits for the landing, the mat, the doors and the walk out.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _solved_at - _now()) + GLOW_TIME + DOOR_TIME * 0.6 + EXIT_TIME + WIN_HOLD

func _on_solved() -> void:
	var t := _now()
	_drag = {}
	var big: int = _state.big()
	var d: Dictionary = _disp[big]
	# the gate waits for the big block to land on the mat
	_solved_at = t + (0.0 if Motion.reduce else maxf(0.0, float(d.at) + float(d.dur) - t) + LAND_TIME * 0.5)
	_tip_timer.stop()
	var total := _solved_at - t + GLOW_TIME + DOOR_TIME + EXIT_TIME + Motion.SOLVE_TIME + 0.6
	_busy_for(total)
	if not Motion.reduce:
		var s := _cell()
		var gate := _pt(_xy(Gen.GOAL) + Vector2(1.0, 2.0)) + Vector2(0.0, Block.FRAME * s * 0.5)
		get_tree().create_timer(_solved_at - t).timeout.connect(func():
			fx.ring(_pt(_xy(Gen.GOAL) + Vector2.ONE), s * 1.1, Pal.GOOD))
		get_tree().create_timer(_solved_at - t + GLOW_TIME).timeout.connect(func(): fx.cue("gate"))
		get_tree().create_timer(_solved_at - t + GLOW_TIME + DOOR_TIME * 0.6).timeout.connect(func():
			fx.puff(gate, Pal.SURFACE, 6))
		var walk := _solved_at - t + GLOW_TIME + DOOR_TIME * 0.6
		for k in EXIT_STEPS:
			var y := EXIT * float(k + 1) / float(EXIT_STEPS)
			get_tree().create_timer(walk + EXIT_TIME * float(k + 1) / float(EXIT_STEPS)).timeout.connect(func():
				fx.puff(_pt(_xy(Gen.GOAL) + Vector2(1.0, 2.0 + y)), Pal.SLIDE_STONE, 4))
		get_tree().create_timer(_solved_at - t + GLOW_TIME + DOOR_TIME + EXIT_TIME * 0.5).timeout.connect(func():
			fx.sparkle(gate + Vector2(0.0, s * 0.6), Pal.SUN)
			fx.cue("solved"))
		# the others cheer: a sparkle over each as its hop comes round
		for p in _state.blocks.size():
			if p == big:
				continue
			var c := _xy(_state.at(p)) + Vector2(_state.size_of(p)) * 0.5
			var far := c.distance_to(_xy(Gen.GOAL) + Vector2.ONE)
			var col: Color = Pal.SLIDE_SQ_HI if _state.kind(p) == Gen.SQ else Pal.SLIDE_BAR_HI
			get_tree().create_timer(_solved_at - t + GLOW_TIME + DOOR_TIME + far * 0.08 + Motion.SOLVE_TIME * 0.4).timeout.connect(func():
				fx.sparkle(_pt(c), col))
	else:
		fx.cue("solved")
	_say(tr("SL_WIN") % [moves, _state.par], Face.Expr.JOY)
	_refresh()

## The tray as it was solved, kept with the day's completion, so a reopened
## day shows the player's own ending without searching for one.
func completion_record() -> Dictionary:
	return {"key": Gen.encode(_state.key), "moves": moves}

## A reopened daily that was already solved: the tray as it was solved (or,
## with no record, the opening played down its shortest way) and the big
## block already out of the gate. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	var k := String(completed_record.get("key", ""))
	if k.length() == Gen.N and Gen.is_goal(Gen.decode(k)):
		_state.restore_key(Gen.decode(k))
		moves = int(completed_record.get("moves", moves))
	else:
		_state.play_out()
	var t := _now()
	for p in _disp.size():
		_disp[p] = _still_at(p)
	_drag = {}
	_solved_at = t - 100.0
	_anim_until = 0.0
	_opened = t - 100.0
	_tip_timer.stop()
	_say(tr("SL_DONE"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
