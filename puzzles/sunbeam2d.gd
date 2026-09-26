extends "res://core/puzzle_base.gd"

## Sunbeam as a flat board: a greenhouse floor at morning, the sun coming in
## through a gap in the glass as one golden beam, and a handful of brass
## mirrors and copper cups riding wooden rails across the floor. Drag a piece
## along its rail and the light follows it live; light every dewdrop, then end
## the beam in the bud, which blooms. The rules live in
## puzzles/sunbeam_state.gd, which this only draws.
##
## **Nothing wrong can sit on this floor**: the beam is traced after every
## step of a drag and *is* the check. So no Check, no tray and no actions row:
## Undo, Reset and Hint ride in the top bar and the tip card stands alone --
## Pinwheel's shape.
##
## How it is drawn. Three meshes:
##   still -- the glass wall, the floor, the rails, the pots and the window,
##            rebuilt only on a relayout (none of them ever moves);
##   live  -- the cups, the beam, the drops, the mirrors, the bud and a
##            hint's ring, rebuilt only while something is moving;
##   air   -- the sun's turning rays and the motes drifting down the light,
##            the only thing that moves at rest, and small, so an idle floor
##            rebuilds that and nothing else (Caterpillar's lesson).
## The pieces are ui/faces/sunbeam_parts.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-sunbeam-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#sunbeam, the
## reference for every measure.

const State = preload("res://puzzles/sunbeam_state.gd")
const Gen = preload("res://puzzles/sunbeam_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Parts = preload("res://ui/faces/sunbeam_parts.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the screen, measured ---
## The card's inset round the floor, the largest cell any band asks for, the
## card's corner, the iron frame round the floor and its corner, and a tile's
## gap and corner.
const INSET := 44.0
const CELL_CAP := 180.0
const CARD_RADIUS := 32.0
const FRAME := 22.0
const FRAME_R := 30.0
const TILE_GAP := 4.0
const TILE_R := 0.08
## The glass wall's panes: how many across the card, and the mullion's width.
const PANES := 5
const MULLION := 10.0
## How far past the floor's edge light that leaves it is drawn, in cells.
const OUT_STUB := 0.3
## What the light meets, in cells: a mirror's glass reaches this far along
## each axis from its centre; a cup takes light into its mouth this far either
## side of its middle, and its body is a box that deep, sitting this far back;
## a pot, the bud and the lamp are boxes of these half-sizes; and a drop is
## wet by light passing this close. A ray bounces at most MAX_BOUNCES times.
const MIRROR_REACH := 0.35
const CUP_REACH := 0.65
const CUP_DEPTH := 0.4
const CUP_SHIFT := 0.1
const POT_HALF := 0.3
const BUD_HALF := 0.3
const LAMP_HALF := 0.42
const DROP_REACH := 0.22
const MAX_BOUNCES := 64
## The dressing: a band over or under the floor shorter than this gets none;
## the glass's light shafts as (left edge, width) fractions of the card; and
## how many grout crossings grow moss.
const BAND_MIN := 90.0
const SHAFTS := [Vector2(-0.2, 0.13), Vector2(0.02, 0.05), Vector2(0.3, 0.16), Vector2(0.55, 0.06)]
const MOSS := 0.16
## Where ivy trails over the window box's lip, as fractions of its length.
const IVY := [0.0, 0.3, 0.72, 1.0]
const EPS := 1e-4

# --- this board's own motion ---
## The light's speed on its first run out of the lamp, in cells a second;
## how long a let-go piece takes to settle onto its peg (the beam bends with
## it the whole way); and how soon a drop may chime again. Everything else is
## a recipe from core/motion.gd.
const BEAM_SPEED := 34.0
const SNAP_TIME := 0.16
const CHIME_QUIET := 0.3
## The light waits for the pieces' entrance before it leaves the lamp.
const BEAM_DELAY := 0.55
## The sun's rays turn this fast at rest; motes drift down the light this
## fast and this many a cell.
const SUN_TURN := 0.35
const MOTE_SPEED := 1.6
const MOTE_DENSITY := 1.2
## At rest bright pulses flow out of the sun along the beam's core: one every
## PULSE_GAP cells, PULSE_LEN long, at PULSE_SPEED cells a second.
const PULSE_GAP := 2.6
const PULSE_LEN := 0.55
const PULSE_SPEED := 2.4
## A let-go piece lands with a dip and a rebound of LAND over LAND_TIME, and a
## puff off the rail.
const LAND := -0.1
const LAND_TIME := 0.26
## The solve: a gold wave runs the beam from the sun to the bud at
## WAVE_SPEED cells a second (faster on a long beam, so it takes at most
## WAVE_MAX), each drop sparkling as it passes; then the bud opens over
## BLOOM_TIME, petals drift off for PETAL_LIFE, and the win screen waits
## WIN_HOLD past the bloom.
const WAVE_SPEED := 22.0
const WAVE_MAX := 1.0
const BLOOM_TIME := 1.0
const PETAL_LIFE := 2.2
const PETALS := 6
const WIN_HOLD := 1.1
const HINTS := 3

const TIP_CYCLE := 8.0
const TIPS := ["SB_TIP_DRAG", "SB_TIP_GOAL", "SB_TIP_CUP", "SB_TIP_MIRROR", "SB_TIP_STOP"]

var _state = State.new()
var fx: Node2D

## The light this frame (_trace_live's), rebuilt while anything moves.
var _tr := {}
var _tr_dirty := true
## When the light leaves the lamp on its first run.
var _beam_at := -100.0
## Drops the drawn light is wetting now, and when each last chimed.
var _wet := {}
var _chimed := {}
## The arrangement a dry-bud line was said for, so it is said once.
var _bud_told := ""

## Each piece's settle onto its peg: {"from": float peg, "at": time}.
var _disp: Array = []
## A drag: {"p", "s" (float peg), "off", "before"}; empty when none.
var _drag := {}
## A press on an empty peg, sent there on release: {"p", "q"}.
var _peg_press := {}
## The last refusal: {"at", "p"}.
var _refused := {"at": -100.0, "p": -1}
var _rings: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
## When the solve's wave reaches the bud and it starts to open.
var _bloom_at := -1.0
var _wave_speed := WAVE_SPEED
var _still: ArrayMesh
var _live: ArrayMesh
var _air: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "sunbeam"
func title() -> String: return "Sunbeam"

func rules() -> String:
	return tr("SB_RULES")

## Undo and Hint; Reset is the host's. No Check: the beam is the check.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

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
	_state.build(rng, difficulty)
	_disp = []
	for p in _state.pieces().size():
		_disp.append({"from": float(_state.pos[p]), "at": -100.0, "lift": false})
	_drag = {}
	_peg_press = {}
	_refused = {"at": -100.0, "p": -1}
	_rings = []
	_wet = {}
	_chimed = {}
	_bud_told = ""
	_anim_until = 0.0
	_solved_at = -1.0
	_bloom_at = -1.0
	_opened = _now()
	_beam_at = _opened + (0.0 if Motion.reduce else BEAM_DELAY)
	_tr = {}
	_tr_dirty = true
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

func _cell() -> float:
	if _state.cols <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf((size.x - 2.0 * INSET) / _state.cols,
		(size.y - 2.0 * INSET) / _state.rows)))

func _grid_size() -> Vector2:
	return Vector2(_state.cols, _state.rows) * _cell()

func _origin() -> Vector2:
	return (size - _grid_size()) * 0.5

func _mid() -> Vector2:
	return _origin() + _grid_size() * 0.5

## A point in cell units (a cell's centre is its column and row plus a half)
## to a Control-local one.
func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _cell()

func _centre(c: int) -> Vector2:
	return _pt(_cv(c))

func _cv(c: int) -> Vector2:
	return Vector2(c % _state.cols, c / _state.cols) + Vector2(0.5, 0.5)

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols + c)

func card_height(available: float) -> float:
	return available

## The floor is taller than wide but the slot is taller still: halve the slack.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_refresh()

# --- the pieces' geometry ---

## Where piece `p`'s anchor cell is at a float peg `s` (between two pegs
## mid-slide), in cell units.
func _anchor(p: int, s: float) -> Vector2:
	var rail: PackedInt32Array = _state.g.pieces[p].rail
	var i := clampi(int(floor(s)), 0, rail.size() - 1)
	var j := mini(rail.size() - 1, i + 1)
	return _cv(rail[i]).lerp(_cv(rail[j]), clampf(s - float(i), 0.0, 1.0))

## A piece's middle: a mirror's cell, or between a cup's two.
func _piece_mid(p: int, s: float) -> Vector2:
	var pc: Dictionary = _state.g.pieces[p]
	var a := _anchor(p, s)
	if pc.kind == "m":
		return a
	return a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s]) * 0.5

## The float peg a piece is drawn at: the finger's while dragged, else
## settling onto its peg.
func _peg_now(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return float(_drag.s)
	var d: Dictionary = _disp[p]
	var u := 1.0 if Motion.reduce else clampf((t - float(d.at)) / SNAP_TIME, 0.0, 1.0)
	if u >= 1.0:
		return float(_state.pos[p])
	return lerpf(float(d.from), float(_state.pos[p]), Motion.back_out(u))

# --- the beam ---

## The light as it looks this frame: a ray cast out of the lamp against every
## piece where it is *drawn* -- under the finger, or settling onto its peg --
## rather than where it stands in the rules, so the beam bends continuously as
## a piece slides instead of jumping a peg at a time. A mirror is its glass, a
## diagonal it can be struck anywhere along; a cup takes light into its mouth
## and hands it back mirrored about its middle, so the U-turn widens and
## narrows as the cup moves; pots, the bud and the lamp are boxes. When every
## piece stands on a peg this is exactly the grid's beam (sunbeam_gen.gd's
## trace), and only that one decides anything: the win, the proof, the dry bud.
## {pts (cell units), len (running length), drop_at {cell: length along},
##  glints [[point, length along]], end}
func _trace_live(t: float) -> Dictionary:
	var g: Dictionary = _state.g
	var mirrors: Array = []
	var cups: Array = []
	for p in _state.pieces().size():
		var pc: Dictionary = g.pieces[p]
		var peg := _peg_now(p, t)
		if pc.kind == "m":
			mirrors.append([_anchor(p, peg), pc.t == "/"])
		else:
			var sv := Vector2(Gen.DX[pc.s], Gen.DY[pc.s])
			cups.append([_anchor(p, peg) + sv * 0.5, sv, Vector2(Gen.DX[pc.f], Gen.DY[pc.f])])
	var boxes: Array = [[_cv(g.bud), BUD_HALF, "bud"], [_cv(g.lamp), LAMP_HALF, "lamp"]]
	for c in g.pots:
		boxes.append([_cv(c), POT_HALF, "pot"])
	var at := _cv(g.lamp)
	var d := Vector2(Gen.DX[g.dir], Gen.DY[g.dir])
	var pts := PackedVector2Array([at])
	var lens := PackedFloat32Array([0.0])
	var glints: Array = []
	var drop_at := {}
	var end := "loop"
	for bounce in MAX_BOUNCES:
		var run: float = lens[lens.size() - 1]
		var best := _exit_t(at, d)
		var what := "out"
		var arg: Array = []
		for bx: Array in boxes:
			var tb := _box_t(at, d, bx[0], Vector2.ONE * float(bx[1]))
			if tb < best:
				best = tb
				what = bx[2]
		for m: Array in mirrors:
			var tm := _mirror_t(at, d, m[0], m[1])
			if tm < best:
				best = tm
				what = "m"
				arg = m
		for cu: Array in cups:
			var mid: Vector2 = cu[0]
			var sv: Vector2 = cu[1]
			var f: Vector2 = cu[2]
			if d.dot(f) < -0.5:
				var e := (at - mid).dot(sv)
				var tc := (at - mid).dot(f)
				if absf(e) <= CUP_REACH and tc > EPS and tc < best:
					best = tc
					what = "u"
					arg = [mid, sv, f, e]
			else:
				var tb := _box_t(at, d, mid - f * CUP_SHIFT, sv.abs() * CUP_REACH + f.abs() * CUP_DEPTH)
				if tb < best:
					best = tb
					what = "cup"
		# the drops this straight passes close enough to wet
		for c in _state.drops():
			if drop_at.has(c):
				continue
			var dc := _cv(c) - at
			var along := dc.dot(d)
			if along >= 0.0 and along <= best and absf(dc.cross(d)) <= DROP_REACH:
				drop_at[c] = run + along
		var hit := at + d * best
		match what:
			"out":
				_push(pts, lens, at + d * (best + OUT_STUB))
				end = "out"
				break
			"bud":
				_push(pts, lens, at + d * (best + BUD_HALF))
				end = "bud"
				break
			"m":
				_push(pts, lens, hit)
				glints.append([hit, lens[lens.size() - 1]])
				d = Vector2(-d.y, -d.x) if arg[1] else Vector2(d.y, d.x)
				at = hit
			"u":
				var mid: Vector2 = arg[0]
				var sv: Vector2 = arg[1]
				var f: Vector2 = arg[2]
				var e: float = arg[3]
				var depth := Parts.CUP_BULGE * 2.0 * absf(e)
				_push(pts, lens, hit)
				for k in range(1, 11):
					var q := PI * float(k) / 10.0
					_push(pts, lens, mid + sv * e * cos(q) - f * depth * sin(q))
				at = pts[pts.size() - 1]
				d = f
			_:
				_push(pts, lens, hit)
				end = what
				break
	return {"pts": pts, "len": lens, "drop_at": drop_at, "glints": glints, "end": end}

static func _push(pts: PackedVector2Array, lens: PackedFloat32Array, p: Vector2) -> void:
	lens.append(lens[lens.size() - 1] + p.distance_to(pts[pts.size() - 1]))
	pts.append(p)

## How far an axis-aligned ray from `at` along `d` runs before leaving the floor.
func _exit_t(at: Vector2, d: Vector2) -> float:
	if d.x > 0.5:
		return float(_state.cols) - at.x
	if d.x < -0.5:
		return at.x
	if d.y > 0.5:
		return float(_state.rows) - at.y
	return at.y

## Where an axis-aligned ray meets a box of half-size `half` about `c` from
## outside, or INF. A ray that starts inside one (the lamp's, a cup's own
## body after its U-turn) passes out of it untouched.
static func _box_t(at: Vector2, d: Vector2, c: Vector2, half: Vector2) -> float:
	if absf(d.x) > 0.5:
		if absf(at.y - c.y) > half.y:
			return INF
		var tx := (c.x - half.x * signf(d.x) - at.x) * signf(d.x)
		return tx if tx > EPS else INF
	if absf(at.x - c.x) > half.x:
		return INF
	var ty := (c.y - half.y * signf(d.y) - at.y) * signf(d.y)
	return ty if ty > EPS else INF

## Where an axis-aligned ray meets a mirror's glass -- the diagonal through
## `m`, "/" or "\", reaching MIRROR_REACH along each axis -- or INF.
static func _mirror_t(at: Vector2, d: Vector2, m: Vector2, slash: bool) -> float:
	if absf(d.x) > 0.5:
		var off := at.y - m.y
		if absf(off) > MIRROR_REACH:
			return INF
		var x := m.x - off if slash else m.x + off
		var tx := (x - at.x) * signf(d.x)
		return tx if tx > EPS else INF
	var off2 := at.x - m.x
	if absf(off2) > MIRROR_REACH:
		return INF
	var y := m.y - off2 if slash else m.y + off2
	var ty := (y - at.y) * signf(d.y)
	return ty if ty > EPS else INF

func _total() -> float:
	var lens: PackedFloat32Array = _tr.get("len", PackedFloat32Array())
	return lens[lens.size() - 1] if not lens.is_empty() else 0.0

## How much of the beam is drawn at `t`, in cells: all of it, but for the
## light's first run out of the lamp as the floor opens.
func _drawn(t: float) -> float:
	if Motion.reduce:
		return _total()
	return minf(_total(), maxf(0.0, t - _beam_at) * BEAM_SPEED)

## Seconds from `t` until that first run reaches the end of the beam.
func _arrive_in(t: float) -> float:
	if Motion.reduce:
		return 0.0
	return maxf(0.0, _beam_at + _total() / BEAM_SPEED - t)

func _arrived(t: float) -> bool:
	return _drawn(t) >= _total() - 1e-4

## The first `upto` cells of `pts`, in pixels.
func _cut(pts: PackedVector2Array, upto: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.is_empty() or upto <= 0.0:
		return out
	out.append(_pt(pts[0]))
	var acc := 0.0
	for i in range(1, pts.size()):
		var sl := pts[i].distance_to(pts[i - 1])
		if acc + sl >= upto:
			out.append(_pt(pts[i - 1].lerp(pts[i], (upto - acc) / maxf(sl, 1e-6))))
			return out
		out.append(_pt(pts[i]))
		acc += sl
	return out

## The point `at` cells along the beam, in pixels.
func _along(at: float) -> Vector2:
	var pts: PackedVector2Array = _tr.pts
	var lens: PackedFloat32Array = _tr.len
	for i in range(1, lens.size()):
		if lens[i] >= at:
			var u := (at - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 1e-6)
			return _pt(pts[i - 1].lerp(pts[i], u))
	return _pt(pts[pts.size() - 1])

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	var moving := _animating(t)
	if moving or _tr_dirty or _tr.is_empty():
		_tr = _trace_live(t)
		_tr_dirty = false
	_arrivals(t)
	if moving:
		_refresh()
	elif not Motion.reduce:
		# At rest only the sun's rays and the motes move, and they are their
		# own small mesh.
		_air = null
		queue_redraw()

## The light reaching things: a drop it has just wet rings and chimes (not
## twice inside CHIME_QUIET, so a drag sweeping the light back and forth over
## one does not chatter), and a bud reached with a drop still dry says so,
## once an arrangement, only once the pieces are at rest.
func _arrivals(t: float) -> void:
	var drawn := _drawn(t)
	var now_wet := {}
	for c in _tr.drop_at:
		if drawn >= float(_tr.drop_at[c]) - 1e-4:
			now_wet[c] = true
	for c in now_wet:
		if not _wet.has(c) and t - float(_chimed.get(c, -100.0)) > CHIME_QUIET:
			_chimed[c] = t
			_ring_at(_centre(c), t)
			fx.cue("dew", 1.0 + 0.08 * float(now_wet.size() - 1))
	_wet = now_wet
	var tr_: Dictionary = _state.beam
	var key := str(_state.pos)
	if _drag.is_empty() and _settled(t) and tr_.end == "bud" and not tr_.won and _arrived(t) and _bud_told != key:
		_bud_told = key
		var left: int = _state.drops().size() - _state.lit_drops()
		_say(tr("SB_BUD_DRY_ONE") if left == 1 else tr("SB_BUD_DRY_N") % left, Face.Expr.STRAIN)
		fx.cue("dry")

## Whether every piece has landed on its peg.
func _settled(t: float) -> bool:
	for d: Dictionary in _disp:
		if t - float(d.at) < SNAP_TIME:
			return false
	return true

func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.pieces().size() + 2, Motion.ENTER_STAGGER) + Motion.POP_IN + 0.2
	return t - _opened < entrance or not _drag.is_empty()

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_tr_dirty = true
	_live = null
	_air = null
	queue_redraw()

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _mid()
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	if _air == null:
		_air = _build_air(t)
	var shown: Array = []
	for m in [_still, _live, _air]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_shown = shown

## The greenhouse: a glass wall of sage panes behind everything, the iron
## frame round the floor, its warm tiles, the rails, the pots and the window
## the sun sits in. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var card := Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0)
	b.fan(card, Pal.GLASSHOUSE)
	# The panes: white-painted mullions a few across and one rail across the
	# top third, with a long soft glint over two of them.
	var pw := (size.x - 4.0) / float(PANES)
	for k in range(1, PANES):
		var x := 2.0 + pw * float(k)
		b.fan(Face.Builder.round_rect(Vector2(x - MULLION * 0.5, 10.0), Vector2(MULLION, size.y - 20.0), MULLION * 0.5),
			Color(Pal.SURFACE, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(10.0, size.y * 0.3), Vector2(size.x - 20.0, MULLION), MULLION * 0.5),
		Color(Pal.SURFACE, 0.8))
	for k: int in [1, 3]:
		var x0 := 2.0 + pw * float(k) + pw * 0.2
		b.fan(PackedVector2Array([Vector2(x0, 24.0), Vector2(x0 + pw * 0.18, 24.0),
			Vector2(x0 - pw * 0.1, size.y * 0.3 - 8.0), Vector2(x0 - pw * 0.28, size.y * 0.3 - 8.0)]), Color(1.0, 1.0, 1.0, 0.35))
	# Hanging leaves in the two top corners, a vine along the glass.
	for side: float in [1.0, -1.0]:
		var root := Vector2(24.0 if side > 0.0 else size.x - 24.0, 12.0)
		for q in 7:
			var ang := lerpf(0.35, 1.35, float(q) / 6.0)
			ang = ang if side > 0.0 else PI - ang
			var col: Color = [Pal.LEAF_DEEP, Pal.LEAF, Pal.LEAF_LIGHT][q % 3]
			Parts.leaf(b, root + Vector2(side * float(q) * 9.0, float(q) * 5.0), 70.0 - float(q) * 4.0, ang, col)
	_shafts(b, card)
	var top := o.y - FRAME
	if top > BAND_MIN:
		_shelf(b, top)
	var bottom := o.y + g.y + FRAME + 6.0
	if size.y - bottom > BAND_MIN:
		_window_box(b, bottom, size.y - bottom)
	# The frame, its shadow, and the floor inside it.
	var out := o - Vector2.ONE * FRAME
	var out_size := g + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 8.0), out_size.x * 0.55, 36.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 6.0), out_size, FRAME_R), Pal.GLASS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.GLASS_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(30.0, 6.0), Vector2(out_size.x * 0.18, 6.0), 3.0), Color(1.0, 1.0, 1.0, 0.55))
	b.fan(Face.Builder.round_rect(out + Vector2(out_size.x * 0.62, out_size.y - 12.0), Vector2(out_size.x * 0.2, 6.0), 3.0),
		Color(1.0, 1.0, 1.0, 0.55))
	b.fan(Face.Builder.round_rect(o, g, 10.0), Pal.FLOOR_GROUT)
	for c in _state.size():
		var x: int = c % _state.cols
		var y: int = c / _state.cols
		var v := _hash(x + 7, y + 3)
		var tone := Pal.FLOOR_TILE_HI if v < 0.33 else (Pal.FLOOR_TILE if v < 0.66 else Pal.FLOOR_TILE.lerp(Pal.FLOOR_GROUT, 0.45))
		# a warmer tile now and then, as terracotta weathers unevenly
		if _hash(x + 31, y + 17) < 0.2:
			tone = tone.lerp(Pal.POT_CLAY, 0.1)
		var at := o + Vector2(x, y) * s + Vector2.ONE * TILE_GAP
		var ts := Vector2.ONE * (s - TILE_GAP * 2.0)
		# each tile a slab: its lower lip in shade, a lit edge along its top
		b.fan(Face.Builder.round_rect(at + Vector2(0.0, 3.0), ts, s * TILE_R), tone.lerp(Pal.FLOOR_GROUT, 0.6))
		b.fan(Face.Builder.round_rect(at, ts - Vector2(0.0, 3.0), s * TILE_R), tone)
		b.fan(Face.Builder.round_rect(at + Vector2(s * 0.12, 3.0), Vector2(ts.x - s * 0.24, 3.0), 1.5), Color(1.0, 1.0, 1.0, 0.28))
	# moss in the grout, where four tiles meet
	for y in range(1, _state.rows):
		for x in range(1, _state.cols):
			if _hash(x * 3 + 5, y * 7 + 11) < MOSS:
				var at := o + Vector2(x, y) * s
				var v := _hash(x + 13, y + 29)
				var r := s * (0.03 + 0.015 * v)
				b.disc(at + Vector2(-r * 0.8, r * 0.3), r, Color(Pal.LEAF_DEEP, 0.75))
				b.disc(at + Vector2(r * 0.7, r * 0.5), r * 0.85, Color(Pal.LEAF, 0.75))
				b.disc(at + Vector2(0.0, -r * 0.5), r * 0.8, Color(Pal.LEAF_LIGHT, 0.8))
	for p in _state.pieces().size():
		var rail: PackedInt32Array = _state.g.pieces[p].rail
		var pegs := PackedVector2Array()
		for q in rail.size():
			pegs.append(_pt(_piece_mid(p, float(q))))
		Parts.rail(b, pegs[0], pegs[pegs.size() - 1], s, pegs)
	for c in _state.g.pots:
		Parts.pot(b, _centre(c), s)
	Parts.window(b, _centre(_state.g.lamp), s)
	return b.mesh()

## Morning light falling slant through the glass wall: a few pale shafts,
## cut to the card. The floor is drawn over them, so they only show on the
## glass.
func _shafts(b: Face.Builder, card: PackedVector2Array) -> void:
	var drift := size.y * 0.42
	for k in SHAFTS.size():
		var sh: Vector2 = SHAFTS[k]
		var x0 := size.x * sh.x
		var w := size.x * sh.y
		var quad := PackedVector2Array([Vector2(x0, 0.0), Vector2(x0 + w, 0.0),
			Vector2(x0 + w + drift, size.y), Vector2(x0 + drift, size.y)])
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(quad, card):
			b.polygon(poly, Color(Pal.BEAM_CORE, 0.55) if k % 2 == 0 else Color(Pal.BEAM, 0.16))

## The potting shelf in the band over the floor: a plank on two brackets with
## three pots on it -- leaves, a flowering one, and a seedling.
func _shelf(b: Face.Builder, band: float) -> void:
	var y := band * 0.74
	var x0 := size.x * 0.16
	var x1 := size.x * 0.84
	for x: float in [x0 + 30.0, x1 - 30.0]:
		b.fan(PackedVector2Array([Vector2(x - 6.0, y), Vector2(x + 6.0, y), Vector2(x + 6.0, y + band * 0.16),
			Vector2(x - 6.0, y + band * 0.1)]), Pal.RAIL_DEEP)
	Scenery.soft_disc(b, Vector2((x0 + x1) * 0.5, y + 22.0), (x1 - x0) * 0.5, 12.0, Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(Vector2(x0, y + 4.0), Vector2(x1 - x0, 14.0), 6.0), Pal.RAIL_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, y), Vector2(x1 - x0, 14.0), 6.0), Pal.RAIL)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 8.0, y + 2.0), Vector2(x1 - x0 - 16.0, 3.0), 1.5), Color(Pal.BEAM_CORE, 0.4))
	var ps := minf(band * 0.72, 130.0)
	for k in 3:
		var at := Vector2(lerpf(x0, x1, 0.22 + 0.28 * float(k)), y - ps * 0.3)
		match k:
			0:
				Parts.pot(b, at, ps)
			1:
				# a pot in flower: the leaves, and three pink heads over them
				Parts.pot(b, at, ps * 0.9)
				for q in 3:
					var fh := at + Vector2((float(q) - 1.0) * ps * 0.16, -ps * (0.38 + 0.08 * float(q % 2)))
					for i in 5:
						b.disc(fh + Vector2.from_angle(float(i) * TAU / 5.0) * ps * 0.045, ps * 0.045, Pal.FLOWER)
					b.disc(fh, ps * 0.035, Pal.SUN)
			_:
				# a seedling: a low pot and two round leaves on a stalk
				Parts.pot(b, at + Vector2(0.0, ps * 0.08), ps * 0.75)
				var stem := at + Vector2(0.0, -ps * 0.1)
				b.stroke(PackedVector2Array([stem, stem + Vector2(0.0, -ps * 0.28)]), ps * 0.04, Pal.LEAF_DEEP)
				b.ellipse(stem + Vector2(-ps * 0.1, -ps * 0.32), ps * 0.1, ps * 0.06, Pal.LEAF_LIGHT)
				b.ellipse(stem + Vector2(ps * 0.1, -ps * 0.34), ps * 0.1, ps * 0.06, Pal.LEAF)

## The window box in the band under the floor: a terracotta trough brimming
## with leaves and a few flowers, ivy trailing over its lip.
func _window_box(b: Face.Builder, y0: float, band: float) -> void:
	var h := minf(band * 0.34, 64.0)
	var y := y0 + band * 0.42
	var x0 := size.x * 0.1
	var x1 := size.x * 0.9
	# the foliage behind the lip: a back row of deep mounds, a front row of
	# lit ones, a few leaves poking up out of them, and flowers on top
	var n := int((x1 - x0) / (h * 0.7))
	for row in 2:
		for i in n:
			var x := lerpf(x0 + h * 0.4, x1 - h * 0.4, (float(i) + 0.5 * float(row)) / float(n))
			var v := _hash(i + 3, 91 + row)
			var r := h * (0.42 + 0.14 * v) * (1.0 if row == 0 else 0.85)
			var c := Vector2(x, y - r * 0.35 + float(row) * h * 0.12)
			b.disc(c, r, Pal.LEAF_DEEP if row == 0 else Pal.LEAF)
			b.disc(c + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(Pal.LEAF_LIGHT, 0.55 if row == 1 else 0.3))
	for i in n / 2:
		var x := lerpf(x0 + h, x1 - h, (float(i) + 0.3) / float(maxi(n / 2, 1)))
		var v := _hash(i + 5, 57)
		Parts.leaf(b, Vector2(x, y - h * 0.3), h * (0.55 + 0.3 * v), -PI * 0.5 + (v - 0.5) * 1.2, Pal.LEAF_LIGHT if i % 2 == 0 else Pal.LEAF)
	for i in 5:
		var fh := Vector2(lerpf(x0 + 50.0, x1 - 50.0, float(i) / 4.0) + (_hash(i, 7) - 0.5) * 30.0, y - h * (0.45 + 0.3 * _hash(i, 13)))
		for q in 5:
			b.disc(fh + Vector2.from_angle(float(q) * TAU / 5.0) * h * 0.11, h * 0.11, Pal.FLOWER if i % 2 == 0 else Pal.SURFACE)
		b.disc(fh, h * 0.08, Pal.SUN)
	Scenery.soft_disc(b, Vector2((x0 + x1) * 0.5, y + h + 8.0), (x1 - x0) * 0.52, 14.0, Color(Pal.TEXT, 0.14))
	b.fan(PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1 - 16.0, y + h), Vector2(x0 + 16.0, y + h)]), Pal.POT_CLAY)
	b.fan(Face.Builder.round_rect(Vector2(x0 - 8.0, y - 6.0), Vector2(x1 - x0 + 16.0, 16.0), 6.0), Pal.POT_RIM)
	b.fan(Face.Builder.round_rect(Vector2(x0 + 30.0, y + 18.0), Vector2((x1 - x0) * 0.3, 5.0), 2.5), Color(1.0, 1.0, 1.0, 0.18))
	# ivy trailing over the lip
	for k in IVY.size():
		var at := Vector2(lerpf(x0 + 30.0, x1 - 30.0, IVY[k]), y + 6.0)
		for q in 4:
			var p := at + Vector2(sin(float(q) * 1.3 + float(k)) * 7.0, float(q) * h * 0.3)
			if q > 0:
				b.stroke(PackedVector2Array([at + Vector2(sin(float(q - 1) * 1.3 + float(k)) * 7.0, float(q - 1) * h * 0.3), p]),
					2.5, Pal.LEAF_DEEP)
			Parts.leaf(b, p, h * 0.34, PI * 0.5 + (0.8 if q % 2 == 0 else -0.8), Pal.LEAF if q % 2 == 0 else Pal.LEAF_DEEP)

## A stable hash of two ints, 0 to 1: the floor's tile tones.
static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.2 - Motion.stagger(i, 0.05)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

## The peg a held piece will land on, the cups under the light, the light, the drops, the mirrors over it,
## and a hint's ring. The bud, the glints and everything that moves at rest
## are the air's.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var n: int = _state.pieces().size()
	if _tr.is_empty():
		_tr = _trace_live(t)
	var drawn := _drawn(t)
	var bpts: PackedVector2Array = _tr.pts
	var lit := _cut(bpts, drawn)
	if not _drag.is_empty():
		# the peg the held piece lands on if let go now
		var hp: int = _drag.p
		var at := _pt(_piece_mid(hp, float(_state.pos[hp])))
		Scenery.soft_disc(b, at, s * 0.42, s * 0.42, Color(Pal.BEAM, 0.45))
		b.stroke(Face.Builder.ring(at, s * 0.2, s * 0.2), 3.0, Color(Pal.BEAM_CORE, 0.9), true)
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "u":
			continue
		var peg := _peg_now(p, t)
		var a := _anchor(p, peg)
		var z := a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s])
		var f := Vector2(Gen.DX[pc.f], Gen.DY[pc.f])
		var e := _entry(p, t) * _land(p, t)
		var sh := Vector2(_shiver(p, t), 0.0)
		var mid := _pt(_piece_mid(p, peg))
		var pts := Parts.cup_path(_pt(a) + sh, _pt(z) + sh, s, f)
		if absf(e - 1.0) > 0.001:
			for i in pts.size():
				pts[i] = mid + (pts[i] - mid) * e
		Parts.cup(b, pts, s * e, f, _lift(p, t), _state.pinned.has(p))
	Parts.beam(b, lit, s)
	if _arrived(t) and String(_tr.end) in ["pot", "cup", "lamp"]:
		b.disc(_pt(bpts[bpts.size() - 1]), s * 0.07, Color(Pal.BEAM, 0.8))
	elif not _arrived(t) and drawn > 0.0:
		# the light's leading spark on its first run out of the lamp
		var tip := _along(drawn)
		Scenery.soft_disc(b, tip, s * 0.4, s * 0.4, Color(Pal.BEAM, 0.7))
		Parts.star(b, tip, s * 0.24, Pal.BEAM_CORE, drawn * 0.4)
	for i in _state.drops().size():
		var c: int = _state.drops()[i]
		var wet: bool = _wet.has(c)
		var sc := Vector2.ONE * _entry(i + 2, t)
		var glow := 1.0
		if wet:
			var pu := _pulse(t - float(_chimed.get(c, -100.0)), 0.26)
			sc *= Vector2(1.0, 1.0) + Vector2(0.08, -0.16) * pu
			glow += 0.6 * _pulse(t - float(_chimed.get(c, -100.0)), 0.5)
		Parts.drop(b, _centre(c), s, wet, sc, glow)
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "m":
			continue
		var at := _pt(_piece_mid(p, _peg_now(p, t))) + Vector2(_shiver(p, t), 0.0)
		var lift := _lift(p, t)
		var sheen := fposmod(_peg_now(p, t) * 0.8, 1.0) if lift > 0.0 else -1.0
		Parts.mirror(b, at, s, pc.t == "/", lift, _state.pinned.has(p), _entry(p, t) * _land(p, t), sheen)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## How far the bloom has got, 0 to 1, linear (the bud eases it).
func _bloom(t: float) -> float:
	if _bloom_at < 0.0:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf((t - _bloom_at) / BLOOM_TIME, 0.0, 1.0)

## A let-go piece's scale as it lands on its peg: a dip and a rebound.
func _land(p: int, t: float) -> float:
	var d: Dictionary = _disp[p]
	if not d.get("lift", false):
		return 1.0
	return Motion.bump_scale(t - float(d.at) - SNAP_TIME, LAND, LAND_TIME)

## 0 to 1 and back over `time`, once: a drop's squash as it is wet.
func _pulse(e: float, time: float) -> float:
	if Motion.reduce or e < 0.0 or e >= time:
		return 0.0
	return sin(PI * e / time)

## How far piece `p` is raised off the floor: up over LIFT_TIME as a finger
## takes it, down again as it settles onto its peg.
func _lift(p: int, t: float) -> float:
	if not _drag.is_empty() and int(_drag.p) == p:
		return 1.0 if Motion.reduce else clampf((t - float(_drag.at)) / Motion.LIFT_TIME, 0.0, 1.0)
	var d: Dictionary = _disp[p]
	if Motion.reduce or not d.get("lift", false):
		return 0.0
	return 1.0 - clampf((t - float(d.at)) / SNAP_TIME, 0.0, 1.0)

func _shiver(p: int, t: float) -> float:
	if int(_refused.p) != p:
		return 0.0
	return Motion.shiver_offset(t - float(_refused.at)) * 3.0

## Everything that moves at rest, rebuilt every frame and nothing else: the
## sun's turning rays, the motes drifting down the light, the pulses flowing
## along its core, a twinkling glint on every mirror it strikes, the bud (it
## sways once open), and on the solve the gold wave and the drifting petals.
func _build_air(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var lamp := _centre(_state.g.lamp)
	Parts.sun(b, lamp, s * _entry(0, t), 0.0 if Motion.reduce else t * SUN_TURN)
	var tot := _drawn(t)
	if not Motion.reduce:
		var count := int(tot * MOTE_DENSITY)
		for k in count:
			var at := fmod(float(k) / MOTE_DENSITY + t * MOTE_SPEED, tot)
			var p := _along(at) + Vector2(sin(float(k) + t), cos(float(k) * 1.3 + t)) * s * 0.05
			b.disc(p, s * 0.018, Color(1.0, 1.0, 1.0, 0.5 + 0.4 * sin(float(k) * 1.7 + t * 3.0)))
		if _arrived(t) and tot > PULSE_LEN:
			var n := int(ceil(tot / PULSE_GAP))
			for k in n:
				var head := fmod(t * PULSE_SPEED + float(k) * PULSE_GAP, float(n) * PULSE_GAP)
				if head > tot:
					continue
				var fade := clampf(head / 0.8, 0.0, 1.0) * clampf((tot - head) / 0.8, 0.0, 1.0)
				Scenery.soft_disc(b, _along(head), s * 0.2, s * 0.2, Color(Pal.BEAM, 0.45 * fade))
				_stroke(b, _span(head - PULSE_LEN, head), s * 0.09, Color(Pal.BEAM_CORE, 0.9 * fade))
	# a glint where the drawn light strikes each mirror's glass
	for k in _tr.glints.size():
		var gl: Array = _tr.glints[k]
		if float(gl[1]) <= tot:
			var tw := 1.0 if Motion.reduce else 0.85 + 0.25 * sin(t * 2.2 + float(k) * 1.7)
			var at := _pt(gl[0])
			Scenery.soft_disc(b, at, s * 0.22, s * 0.22, Color(Pal.BEAM, 0.55))
			Parts.star(b, at, s * 0.21 * tw, Pal.BEAM_CORE, 0.0 if Motion.reduce else t * 0.5 + float(k))
			b.disc(at, s * 0.05, Color.WHITE)
	# the solve's wave, from the sun to the bud
	if _solved_at >= 0.0 and not Motion.reduce:
		var head := (t - _solved_at) * _wave_speed
		if head > 0.0 and head < _total() + 1.5:
			_stroke(b, _span(head - 1.8, head), s * 0.26, Color(Pal.BEAM_CORE, 0.5))
			_stroke(b, _span(head - 1.0, head), s * 0.12, Color.WHITE)
			if head < _total():
				Scenery.soft_disc(b, _along(head), s * 0.5, s * 0.5, Color(Pal.BEAM, 0.7))
	var open := _bloom(t)
	var glow: bool = _tr.end == "bud" and _arrived(t) and _solved_at < 0.0
	var sway := 0.0
	if open >= 1.0 and not Motion.reduce:
		sway = sin((t - _bloom_at) * 1.3) * 0.07
	var bud := _centre(_state.g.bud)
	Parts.bud(b, bud, s * _entry(_state.pieces().size() + 1, t), open, glow, 0.0, sway)
	if _bloom_at >= 0.0 and not Motion.reduce:
		var e := t - _bloom_at - BLOOM_TIME * 0.4
		if e > 0.0 and e < PETAL_LIFE:
			var u := e / PETAL_LIFE
			for i in PETALS:
				var ang := -PI * 0.5 + (float(i) - float(PETALS - 1) * 0.5) * 0.6
				var out := Vector2.from_angle(ang) * s * (0.3 + 1.3 * (1.0 - exp(-2.2 * e)))
				var at := bud + Vector2(0.0, -s * 0.06) + out \
					+ Vector2(sin(e * 3.0 + float(i) * 1.9) * s * 0.14, e * e * s * 0.22)
				Parts.petal(b, at, s * 0.09, e * 2.4 + float(i), 1.0 - u * u)
	return b.mesh()

## A stroke along `pts`, if there is one to draw.
static func _stroke(b: Face.Builder, pts: PackedVector2Array, w: float, col: Color) -> void:
	if pts.size() >= 2:
		b.stroke(pts, w, col)

## The beam between `a` and `z` cells along it, in pixels.
func _span(a: float, z: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _tr.pts
	var lens: PackedFloat32Array = _tr.len
	a = maxf(a, 0.0)
	z = minf(z, _total())
	var out := PackedVector2Array()
	if z <= a:
		return out
	out.append(_along(a))
	for i in range(1, lens.size() - 1):
		if lens[i] > a and lens[i] < z:
			out.append(_pt(pts[i]))
	out.append(_along(z))
	return out

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
			_release(event.position)
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _drag.is_empty():
		_move(event.position)
		accept_event()

## The piece under a local point, or -1: a mirror's cell, or either of a
## cup's two; where two rails cross, the one drawn last (a mirror) wins.
func _piece_at(local: Vector2) -> int:
	var t := _now()
	var s := _cell()
	var hit := -1
	for kind in ["u", "m"]:
		for p in _state.pieces().size():
			var pc: Dictionary = _state.g.pieces[p]
			if pc.kind != kind:
				continue
			# The box round the piece's cells: one cell for a mirror, both of a
			# cup's -- whose middle is the line between them, so testing each
			# cell on its own would miss the very point a thumb aims at.
			var a := _pt(_anchor(p, _peg_now(p, t)))
			var box := Rect2(a - Vector2.ONE * s * 0.5, Vector2.ONE * s)
			if kind == "u":
				box = box.merge(Rect2(a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s]) * s - Vector2.ONE * s * 0.5, Vector2.ONE * s))
			if box.has_point(local):
				hit = p
	return hit

## An empty peg under a local point: {"p", "q"} or {}.
func _peg_at(local: Vector2) -> Dictionary:
	var s := _cell()
	var v := (local - _origin()) / s
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.cols or y >= _state.rows:
		return {}
	var c: int = y * _state.cols + x
	for p in _state.pieces().size():
		var q: int = _state.g.pieces[p].rail.find(c)
		if q >= 0:
			return {"p": p, "q": q}
	return {}

## The float peg under the finger, projected onto piece `p`'s rail.
func _rail_s(p: int, local: Vector2) -> float:
	var n: int = _state.g.pieces[p].rail.size()
	var a := _pt(_piece_mid(p, 0.0))
	var z := _pt(_piece_mid(p, float(n - 1)))
	var d := z - a
	return clampf((local - a).dot(d) / maxf(d.length_squared(), 1e-6) * float(n - 1), 0.0, float(n - 1))

func _press(local: Vector2) -> void:
	var t := _now()
	_peg_press = {}
	var p := _piece_at(local)
	if p >= 0:
		if _state.pinned.has(p):
			_refuse(p, t)
			return
		var s := _peg_now(p, t)
		_drag = {"p": p, "s": s, "off": s - _rail_s(p, local), "before": _state.pos.duplicate(), "at": t}
		fx.cue("lift")
		_refresh()
		return
	var pg := _peg_at(local)
	if not pg.is_empty():
		_peg_press = pg

func _move(local: Vector2) -> void:
	var t := _now()
	var p: int = _drag.p
	var n: int = _state.g.pieces[p].rail.size()
	_drag.s = clampf(_rail_s(p, local) + float(_drag.off), 0.0, float(n - 1))
	var q: int = _state.snap(p, float(_drag.s))
	if q != _state.pos[p] and _state.place(p, q):
		fx.cue("step")
	_refresh()

func _release(local: Vector2) -> void:
	var t := _now()
	if not _drag.is_empty():
		var p: int = _drag.p
		_disp[p] = {"from": float(_drag.s), "at": t, "lift": true}
		var before: PackedInt32Array = _drag.before
		_drag = {}
		_busy_for(SNAP_TIME + LAND_TIME)
		_land_puff(p)
		if _state.commit(before):
			fx.cue("slide")
			note_move()
		else:
			fx.cue("drop")
		_refresh()
		return
	if _peg_press.is_empty():
		return
	var pg := _peg_at(local)
	var want := _peg_press
	_peg_press = {}
	if pg.is_empty() or int(pg.p) != int(want.p) or int(pg.q) != int(want.q):
		return
	var p: int = pg.p
	if _state.pinned.has(p):
		_refuse(p, t)
		return
	if _state.taken(p, pg.q):
		_refuse(p, t, "SB_TAKEN")
		return
	var before: PackedInt32Array = _state.pos.duplicate()
	var from := float(_state.pos[p])
	if _state.place(p, pg.q):
		_disp[p] = {"from": from, "at": t, "lift": true}
		_busy_for(SNAP_TIME + LAND_TIME)
		_land_puff(p)
		_state.commit(before)
		fx.cue("slide")
		note_move()
		_refresh()

## A little puff off the rail where piece `p` lands, as it lands.
func _land_puff(p: int) -> void:
	if Motion.reduce:
		return
	var at := _pt(_piece_mid(p, float(_state.pos[p]))) + Vector2(0.0, _cell() * 0.22)
	get_tree().create_timer(SNAP_TIME).timeout.connect(func(): fx.puff(at, Pal.SURFACE, 4))

func _refuse(p: int, t: float, line := "SB_PINNED") -> void:
	_refused = {"at": t, "p": p}
	_busy_for(Motion.SHIVER_TIME * 2.0)
	fx.cue("refuse")
	_say(tr(line), Face.Expr.STRAIN)
	_refresh()

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

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

## Every piece whose peg changed since `before` settles onto its new one.
func _settle(before: PackedInt32Array, t: float, stagger := 0.0) -> void:
	var k := 0
	for p in before.size():
		if before[p] != _state.pos[p]:
			_disp[p] = {"from": float(before[p]), "at": t + Motion.stagger(k, stagger), "lift": false}
			k += 1
	_busy_for(Motion.stagger(k, stagger) + SNAP_TIME)

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Puts the pieces back as they were before the last move. Counts no move.
func undo() -> bool:
	var before: PackedInt32Array = _state.pos.duplicate()
	if is_done() or not _state.undo():
		return false
	var t := _now()
	_settle(before, t)
	_say(tr("SB_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Slides the next piece along the answer's beam home and pins it there.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var t := _now()
	var before: PackedInt32Array = _state.pos.duplicate()
	var r: Dictionary = _state.hint()
	if r.is_empty():
		return false
	hints_used += 1
	_settle(before, t)
	var p: int = r.piece
	_ring_at(_pt(_piece_mid(p, float(_state.pos[p]))), t + SNAP_TIME)
	_say(tr("SB_HINT"), Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	var before: PackedInt32Array = _state.pos.duplicate()
	_state.reset_board()
	var t := _now()
	_drag = {}
	_settle(before, t, Motion.RESET_STAGGER)
	_rings = []
	_solved_at = -1.0
	_bloom_at = -1.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: the sun, a drop each, the bud.
func share_glyphs() -> String:
	return "☀️" + "💧".repeat(_state.drops().size()) + "🌸"

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("SB_WIN")}

## The win screen waits for the light to reach the bud, the wave to run the
## beam, and the bloom.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _bloom_at - _now()) + BLOOM_TIME + WIN_HOLD

func _on_solved() -> void:
	var t := _now()
	_drag = {}
	# The wave waits for the let-go piece to land, and on a first-run beam
	# for the light to get there; the bloom waits for the wave.
	_solved_at = t + maxf(_arrive_in(t), 0.0 if Motion.reduce else SNAP_TIME + LAND_TIME * 0.5)
	_tip_timer.stop()
	if not Motion.reduce:
		_wave_speed = maxf(WAVE_SPEED, _total() / WAVE_MAX)
		_bloom_at = _solved_at + _total() / _wave_speed
		var drops: PackedInt32Array = _state.drops()
		for c in drops:
			var along: float = _tr.drop_at.get(c, 0.0)
			get_tree().create_timer(_solved_at - t + along / _wave_speed).timeout.connect(
				func(): fx.sparkle(_centre(c), Pal.SUN))
		for gl: Array in _tr.glints:
			var gat := _pt(gl[0])
			get_tree().create_timer(_solved_at - t + float(gl[1]) / _wave_speed).timeout.connect(
				func(): fx.puff(gat, Pal.BEAM_CORE, 4))
		var bud := _centre(_state.g.bud)
		get_tree().create_timer(_bloom_at - t + 0.25).timeout.connect(func(): fx.sparkle(bud, Pal.FLOWER))
		get_tree().create_timer(_bloom_at - t + 0.4).timeout.connect(func(): fx.puff(bud, Pal.SUN, 8))
		get_tree().create_timer(_solved_at - t).timeout.connect(func(): fx.cue("solved"))
	else:
		_bloom_at = _solved_at
		fx.cue("solved")
	_busy_for(_bloom_at - t + BLOOM_TIME)
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_refresh()

## A reopened daily that was already solved: every piece home, the light
## already there and the bud open. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	_state.pos = _state.home_pos()
	_state.retrace()
	var t := _now()
	_beam_at = t - 100.0
	for p in _disp.size():
		_disp[p] = {"from": float(_state.pos[p]), "at": -100.0, "lift": false}
	# Every drop already wet, so reopening a solved day chimes nothing.
	_wet = {}
	for c in _state.drops():
		_wet[c] = true
	_tr = _trace_live(t)
	_solved_at = t - 100.0
	_bloom_at = t - 100.0
	_anim_until = 0.0
	_opened = t - 100.0
	_tip_timer.stop()
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
