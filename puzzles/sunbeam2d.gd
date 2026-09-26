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
## Where the light stops short against a pot, a cup's back or the lamp, in
## cells back from the cell's centre.
const STOP_SHORT := 0.34

# --- this board's own motion ---
## The light's speed down a new stretch, in cells a second; how long a cut-off
## stretch of old beam takes to fade; and how long a let-go piece takes to
## settle onto its peg. Everything else is a recipe from core/motion.gd.
const BEAM_SPEED := 34.0
const BEAM_FADE := 0.18
const SNAP_TIME := 0.16
## The light waits for the pieces' entrance before it leaves the lamp.
const BEAM_DELAY := 0.55
## The sun's rays turn this fast at rest; motes drift down the light this
## fast and this many a cell.
const SUN_TURN := 0.35
const MOTE_SPEED := 1.6
const MOTE_DENSITY := 1.2
## The solve: the bud opens over BLOOM_TIME once the light has reached it,
## the drops sparkle WAVE_STEP apart, and the win screen waits WIN_WAIT more.
const BLOOM_TIME := 0.7
const WIN_WAIT := 2.6
const HINTS := 3

const TIP_CYCLE := 8.0
const TIPS := ["SB_TIP_DRAG", "SB_TIP_GOAL", "SB_TIP_CUP", "SB_TIP_MIRROR", "SB_TIP_STOP"]

var _state = State.new()
var fx: Node2D

## The beam as a polyline in cell units, its running length, and where along
## it each drop is.
var _pts := PackedVector2Array()
var _len := PackedFloat32Array()
var _drop_at := {}
## When the light set off down its newest stretch, and from how far along.
var _beam_at := -100.0
var _beam_from := 0.0
## The stretch a move cut off, fading: its points, how much of it was lit, when.
var _old_pts := PackedVector2Array()
var _old_upto := 0.0
var _old_at := -100.0
## Drops the drawn light has reached, so each is rung once as it arrives.
var _wet := {}
## The beam a dry-bud line was said for, so it is said once.
var _bud_told := -1.0

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
		_disp.append({"from": float(_state.pos[p]), "at": -100.0})
	_drag = {}
	_peg_press = {}
	_refused = {"at": -100.0, "p": -1}
	_rings = []
	_wet = {}
	_bud_told = -1.0
	_anim_until = 0.0
	_solved_at = -1.0
	_opened = _now()
	_old_pts = PackedVector2Array()
	_retrace(_opened + (0.0 if Motion.reduce else BEAM_DELAY), true)
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

## The beam as a polyline in cell units: every cell centre it passes, the arc
## round a cup, and the stub where it stops or leaves the floor.
func _poly(tr_: Dictionary) -> Dictionary:
	var pts := PackedVector2Array([_cv(_state.g.lamp)])
	var drop_i := {}
	var is_drop := {}
	for c in _state.drops():
		is_drop[c] = true
	var last_d: int = _state.g.dir
	for st: Dictionary in tr_.steps:
		var at := _cv(st.c)
		var d: int = st.d
		match String(st.k):
			"", "m":
				pts.append(at)
				if is_drop.has(st.c) and not drop_i.has(st.c):
					drop_i[st.c] = pts.size() - 1
				last_d = int(st.get("nd", d))
			"bud":
				pts.append(at)
			"u":
				var pc: Dictionary = _state.g.pieces[st.p]
				var o := _cv(st.o)
				var mid := (at + o) * 0.5
				var u := at - mid
				var back := (int(pc.f) + 2) % 4
				var v := Vector2(Gen.DX[back], Gen.DY[back]) * Parts.CUP_BULGE
				pts.append(at)
				for k in range(1, 11):
					var q := PI * float(k) / 10.0
					pts.append(mid + u * cos(q) + v * sin(q))
				last_d = int(st.nd)
			_:
				pts.append(at - Vector2(Gen.DX[d], Gen.DY[d]) * STOP_SHORT)
	if tr_.end == "out" or tr_.end == "loop":
		var e := pts[pts.size() - 1]
		var to := e + Vector2(Gen.DX[last_d], Gen.DY[last_d]) * (0.5 + OUT_STUB)
		pts.append(to)
	var lens := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
	var at_len := {}
	for c in drop_i:
		at_len[c] = lens[drop_i[c]]
	return {"pts": pts, "len": lens, "drop_at": at_len}

## A new arrangement: keep the stretch of light the two share, fade what the
## old beam had past the fork, and send the light down the new one from there.
func _retrace(t: float, fresh := false) -> void:
	var bp := _poly(_state.beam)
	var np: PackedVector2Array = bp.pts
	var k := 0
	if not fresh:
		while k < np.size() and k < _pts.size() and np[k].is_equal_approx(_pts[k]):
			k += 1
	var shared: float = bp.len[k - 1] if k > 0 else 0.0
	var drawn := _drawn(t)
	if not fresh and k < _pts.size() and not Motion.reduce:
		_old_pts = _pts.slice(maxi(0, k - 1))
		_old_upto = drawn - (_len[k - 1] if k > 0 else 0.0)
		_old_at = t
	_beam_from = 0.0 if fresh else minf(shared, drawn)
	_beam_at = t
	_pts = np
	_len = bp.len
	_drop_at = bp.drop_at
	var keep := {}
	for c in _wet:
		if _drop_at.has(c) and float(_drop_at[c]) <= _beam_from + 1e-4:
			keep[c] = true
	_wet = keep
	_busy_for(_arrive_in(t) + BEAM_FADE)

func _total() -> float:
	return _len[_len.size() - 1] if not _len.is_empty() else 0.0

## How much of the beam is drawn at `t`, in cells.
func _drawn(t: float) -> float:
	if _len.is_empty():
		return 0.0
	if Motion.reduce:
		return _total()
	return minf(_total(), _beam_from + maxf(0.0, t - _beam_at) * BEAM_SPEED)

## Seconds from `t` until the light reaches the end of the beam.
func _arrive_in(t: float) -> float:
	if Motion.reduce:
		return 0.0
	return maxf(0.0, _beam_at + (_total() - _beam_from) / BEAM_SPEED - t)

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
	for i in range(1, _len.size()):
		if _len[i] >= at:
			var u := (at - _len[i - 1]) / maxf(_len[i] - _len[i - 1], 1e-6)
			return _pt(_pts[i - 1].lerp(_pts[i], u))
	return _pt(_pts[_pts.size() - 1])

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	_arrivals(t)
	if _animating(t):
		_refresh()
	elif not Motion.reduce:
		# At rest only the sun's rays and the motes move, and they are their
		# own small mesh.
		_air = null
		queue_redraw()

## The light reaching things: a drop it has just wet rings and chimes, and a
## bud reached with a drop still dry says so, once a beam.
func _arrivals(t: float) -> void:
	var drawn := _drawn(t)
	for c in _drop_at:
		if not _wet.has(c) and drawn >= float(_drop_at[c]) - 1e-4:
			_wet[c] = true
			if t - _opened > BEAM_DELAY + 0.05:
				_ring_at(_centre(c), t)
				fx.cue("dew", 1.0 + 0.08 * float(_wet.size() - 1))
	var tr_: Dictionary = _state.beam
	if _drag.is_empty() and tr_.end == "bud" and not tr_.won and _arrived(t) and _bud_told != _beam_at:
		_bud_told = _beam_at
		var left: int = _state.drops().size() - _state.lit_drops()
		_say(tr("SB_BUD_DRY_ONE") if left == 1 else tr("SB_BUD_DRY_N") % left, Face.Expr.STRAIN)
		fx.cue("dry")

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
	b.fan(Face.Builder.round_rect(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0, CARD_RADIUS - 2.0), Pal.GLASSHOUSE)
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
		b.fan(Face.Builder.round_rect(o + Vector2(x, y) * s + Vector2.ONE * TILE_GAP, Vector2.ONE * (s - TILE_GAP * 2.0), s * TILE_R), tone)
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

## The cups under the light, the light, the drops, the mirrors over it, the
## bud, and a hint's ring.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var n: int = _state.pieces().size()
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "u":
			continue
		var peg := _peg_now(p, t)
		var a := _anchor(p, peg)
		var z := a + Vector2(Gen.DX[pc.s], Gen.DY[pc.s])
		var f := Vector2(Gen.DX[pc.f], Gen.DY[pc.f])
		var e := _entry(p, t)
		var sh := Vector2(_shiver(p, t), 0.0)
		var mid := _pt(_piece_mid(p, peg))
		var pts := Parts.cup_path(_pt(a) + sh, _pt(z) + sh, s, f)
		if e < 0.999:
			for i in pts.size():
				pts[i] = mid + (pts[i] - mid) * e
		Parts.cup(b, pts, s * e, f, _lift(p), _state.pinned.has(p))
	if not _old_pts.is_empty():
		var fade := 1.0 - clampf((t - _old_at) / BEAM_FADE, 0.0, 1.0)
		if fade > 0.0 and not Motion.reduce:
			Parts.beam(b, _cut(_old_pts, _old_upto), s, fade)
		else:
			_old_pts = PackedVector2Array()
	var drawn := _drawn(t)
	Parts.beam(b, _cut(_pts, drawn), s)
	if _arrived(t) and String(_state.beam.end) in ["pot", "cup", "lamp"]:
		b.disc(_pt(_pts[_pts.size() - 1]), s * 0.07, Color(Pal.BEAM, 0.8))
	for i in _state.drops().size():
		var c: int = _state.drops()[i]
		var wet: bool = _drop_at.has(c) and drawn >= float(_drop_at[c]) - 1e-4
		var sc := Vector2.ONE * _entry(i + 2, t)
		if wet and _drop_at.has(c):
			var at := _beam_at + (float(_drop_at[c]) - _beam_from) / BEAM_SPEED
			sc *= Vector2(1.0, 1.0) + Vector2(0.08, -0.16) * _pulse(t - at, 0.26)
		Parts.drop(b, _centre(c), s, wet, sc)
	for p in n:
		var pc: Dictionary = _state.g.pieces[p]
		if pc.kind != "m":
			continue
		var at := _pt(_piece_mid(p, _peg_now(p, t))) + Vector2(_shiver(p, t), 0.0)
		Parts.mirror(b, at, s, pc.t == "/", _lift(p), _state.pinned.has(p), _entry(p, t))
	# a glint on every mirror the drawn light has reached
	var along := 0.0
	for i in range(1, _pts.size()):
		along = _len[i]
		if along > drawn:
			break
		for p in n:
			if _state.g.pieces[p].kind == "m" and _pts[i].is_equal_approx(_anchor(p, float(_state.pos[p]))) and _drag.get("p", -1) != p:
				b.disc(_pt(_pts[i]), s * 0.075, Color(Pal.BEAM_CORE, 0.95))
	var open := 0.0
	if _solved_at >= 0.0:
		open = 1.0 if Motion.reduce else Motion.back_out(clampf((t - _solved_at) / BLOOM_TIME, 0.0, 1.0))
	var glow: bool = _state.beam.end == "bud" and _arrived(t) and _solved_at < 0.0
	Parts.bud(b, _centre(_state.g.bud), s * _entry(n + 1, t), open, glow)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## 0 to 1 and back over `time`, once: a drop's squash as it is wet.
func _pulse(e: float, time: float) -> float:
	if Motion.reduce or e < 0.0 or e >= time:
		return 0.0
	return sin(PI * e / time)

func _lift(p: int) -> float:
	return 1.0 if not _drag.is_empty() and int(_drag.p) == p else 0.0

func _shiver(p: int, t: float) -> float:
	if int(_refused.p) != p:
		return 0.0
	return Motion.shiver_offset(t - float(_refused.at)) * 3.0

## The sun's turning rays and the motes drifting down the light.
func _build_air(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var lamp := _centre(_state.g.lamp)
	Parts.sun(b, lamp, s * _entry(0, t), 0.0 if Motion.reduce else t * SUN_TURN)
	if not Motion.reduce:
		var tot := _drawn(t)
		var count := int(tot * MOTE_DENSITY)
		for k in count:
			var at := fmod(float(k) / MOTE_DENSITY + t * MOTE_SPEED, tot)
			var p := _along(at) + Vector2(sin(float(k) + t), cos(float(k) * 1.3 + t)) * s * 0.05
			b.disc(p, s * 0.018, Color(1.0, 1.0, 1.0, 0.5 + 0.4 * sin(float(k) * 1.7 + t * 3.0)))
	return b.mesh()

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
		_drag = {"p": p, "s": s, "off": s - _rail_s(p, local), "before": _state.pos.duplicate()}
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
		_retrace(t)
		fx.cue("step")
	_refresh()

func _release(local: Vector2) -> void:
	var t := _now()
	if not _drag.is_empty():
		var p: int = _drag.p
		_disp[p] = {"from": float(_drag.s), "at": t}
		var before: PackedInt32Array = _drag.before
		_drag = {}
		_busy_for(SNAP_TIME)
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
		_disp[p] = {"from": from, "at": t}
		_busy_for(SNAP_TIME)
		_retrace(t)
		_state.commit(before)
		fx.cue("slide")
		note_move()
		_refresh()

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
			_disp[p] = {"from": float(before[p]), "at": t + Motion.stagger(k, stagger)}
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
	_retrace(t)
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
	_retrace(t)
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
	_retrace(t)
	_rings = []
	_solved_at = -1.0
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

## The win screen waits for the light to reach the bud, then for the bloom.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _solved_at - _now()) + WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_drag = {}
	_solved_at = t + _arrive_in(t)
	_tip_timer.stop()
	if not Motion.reduce:
		var drops: PackedInt32Array = _state.drops()
		for i in drops.size():
			var c: int = drops[i]
			get_tree().create_timer(_solved_at - t + Motion.WAVE_STEP * 3.0 * float(i)).timeout.connect(
				func(): fx.sparkle(_centre(c), Pal.SUN))
		get_tree().create_timer(_solved_at - t + 0.2).timeout.connect(
			func(): fx.sparkle(_centre(_state.g.bud), Pal.FLOWER))
		get_tree().create_timer(_solved_at - t).timeout.connect(func(): fx.cue("solved"))
	else:
		fx.cue("solved")
	_busy_for(_solved_at - t + BLOOM_TIME)
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_refresh()

## A reopened daily that was already solved: every piece home, the light
## already there and the bud open. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	_state.pos = _state.home_pos()
	_state.retrace()
	var t := _now()
	_retrace(t, true)
	_beam_from = _total()
	for p in _disp.size():
		_disp[p] = {"from": float(_state.pos[p]), "at": -100.0}
	_wet = {}
	for c in _drop_at:
		_wet[c] = true
	_solved_at = t - 100.0
	_anim_until = 0.0
	_opened = t - 100.0
	_tip_timer.stop()
	_say(tr("SB_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
