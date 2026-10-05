extends Control

## One page of Untangle's tutorial: the board's wooden ring in little -- its
## holes, capped pegs and thick laid ropes (the board's own Rope, so they
## swing, knot and lie over and under as they do on the board) -- with one
## move played on a loop over a caption that says what it means. `lesson`
## picks the page (set before it enters the tree):
##
## - LIFT: a peg is carried from its hole into an empty one over the rope it
##   lies on top of; the crossing slides off, and both ropes, free, are
##   reeled in and leave the ring.
## - WRAP: the same carry, but the rope moved lies underneath: it wraps round
##   the other once more (a knot cinches in); Undo takes it back.
## - REACH: a short rope's peg is lifted (the holes it reaches glow), pulled
##   toward a far hole until the rope goes tight, and put back; then dropped
##   in a hole it reaches.
## - HINT: a peg flies to its hole by itself, and the ropes it frees leave.
## - THREAD: every move, an undo too, uses a stitch from the row of thread.
## - CAT: the kitten's yarn counts down; after the move she bats the marked
##   peg into the nearest empty hole. (THREAD's and CAT's moves cross
##   nothing, so no rope leaves in the middle of what they show.)
##
## Performance checkup, 2026-10-01: the one generic card became these pages.

const UT = preload("res://puzzles/untangle2d.gd")
const Rope = preload("res://puzzles/untangle_rope.gd")
const Face = preload("res://ui/faces/face.gd")
const KittenFace = preload("res://ui/faces/kitten_face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Lesson { LIFT, WRAP, REACH, HINT, THREAD, CAT }

const HOLES := 8
const CARRY := 1.2
const FLY := 0.42
const LIFT_RATE := 9.0
const BUDGET := 6

var lesson: int = Lesson.LIFT

var _caption: Label
var _kitten: Face
var _started := false
var _clock := 0.0
var _loop := 0.0
var _script: Array = []
var _next := 0

# geometry, as the board's _layout makes it
var _c := Vector2.ZERO
var _ro := 0.0
var _ri := 0.0
var _rh := 0.0
var _peg_r := 0.0
var _hole_r := 0.0
var _wd := 0.0
var _yarn_at := Vector2.ZERO

# pegs: 2 * rope + end
var _hole := PackedInt32Array()
var _pos := PackedVector2Array()
var _lift := PackedFloat32Array()
var _face := PackedInt32Array()          # 0 the inlay, 1 joy, 3 strain
var _fly: Array = []                     # [peg] -> {from, to, t0, dur, arc, held} or null
# ropes
var _ropes: Array = []
var _col: Array = []                     # [rope] -> colour index into UT.ROPES
var _len := PackedFloat32Array()         # [rope] -> how far it reaches, px
var _order: Array = []                   # ropes bottom to top
var _glow := -10.0                       # when the ropes were last set free
var _reeled := false                     # ...and whether they have been reeled in since
## Pairs that cross: Vector2i(a, b) -> {"n", "t" (1: a on top at the first
## crossing along a)}.
var _pairs := {}
## The knot of a pair wrapped twice round or more, as last laid.
var _knots := {}
var _marked := -1
var _cat_in := 0
var _paw_t := -10.0
var _spent := 0
var _stitch_t: Array = []
var _hint_t := -10.0
var _preview := ""
var _preview_hole := -1
var _taut := false
var _far := -1
## Kept until the next draw replaces them: a canvas holds a mesh's RID only.
var _ring_mesh: ArrayMesh
var _mesh: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(func() -> void: call_deferred("_start"))
	call_deferred("_start")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _started:
		call_deferred("_start")

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	_started = true
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	var top := 46.0 if lesson == Lesson.THREAD else 8.0
	var room := size.y - 100.0 - top
	var wide := size.x * (0.6 if lesson == Lesson.CAT else 0.8)
	_ro = minf(wide, room) * 0.5
	_ri = _ro * UT.RING_IN
	_rh = (_ro + _ri) * 0.5
	_c = Vector2(size.x * (0.4 if lesson == Lesson.CAT else 0.5), top + room * 0.5)
	_peg_r = minf((_ro - _ri) * UT.PEG_OF_RING, TAU * _rh / HOLES * 0.36)
	_hole_r = _peg_r * UT.HOLE_OF_PEG
	_wd = _peg_r * UT.ROPE_OF_PEG
	_ring_mesh = _build_ring()
	if lesson == Lesson.CAT:
		if _kitten == null:
			_kitten = KittenFace.new()
			_kitten.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_kitten)
		var k := _ro * 0.95
		_kitten.size = Vector2.ONE * k
		_kitten.position = Vector2(size.x - k - 14.0, _c.y - _ro * 0.95)
		_kitten.pivot_offset = _kitten.size * 0.5
		_kitten.set_idle(not Motion.reduce)
		_yarn_at = _kitten.position + Vector2(-_ro * 0.08, k * 0.95)
	_scene()
	if Motion.reduce:
		_still()
		set_process(false)
		_settle(60)
		_rebuild()
		queue_redraw()
		return
	set_process(true)

# --- the scene and its script ---

## Ropes A (coral, holes 1 and 5) and B (yellow, holes 2 and 6) cross in
## the middle of every page but REACH's; which lies on top is the page's.
func _scene() -> void:
	_clock = 0.0
	_next = 0
	_script = []
	_pairs = {}
	_knots = {}
	_reeled = false
	_marked = -1
	_cat_in = 0
	_paw_t = -10.0
	_spent = 0
	_stitch_t = []
	_hint_t = -10.0
	_glow = -10.0
	_preview = ""
	_preview_hole = -1
	_taut = false
	_far = -1
	match lesson:
		Lesson.REACH:
			_deal([[2, 1, 5, 4], [1, 7, 0, 2]])
			_say(0.0, "HTP_UT_GLOW_CAP")
			_at(0.6, func() -> void: _carry(3, 4, 1.4, true))
			_at(1.3, func() -> void: _say_now("HTP_UT_TAUT_CAP"))
			_at(2.6, func() -> void: _carry(3, 6, 0.9))
			_at(3.6, func() -> void: _say_now("HTP_UT_REACHED_CAP"))
			_loop = 5.6
		_:
			# A on top in LIFT and HINT (a move off the top slides it off);
			# underneath in WRAP (it wraps tighter); THREAD and CAT play LIFT's.
			_deal([[2, 1, 5, 4], [1, 2, 6, 4]])
			_pairs[Vector2i(0, 1)] = {"n": 1, "t": 0 if lesson == Lesson.WRAP else 1}
			_order = [0, 1] if lesson == Lesson.WRAP else [1, 0]
	match lesson:
		Lesson.LIFT:
			_say(0.0, "HTP_UT_LIFT_CAP")
			_at(0.6, func() -> void: _carry(1, 7, CARRY))
			_at(0.6 + CARRY * 0.55, func() -> void: _cross_off())
			_at(0.6 + CARRY + 0.1, func() -> void:
				_free()
				_say_now("HTP_UT_FREE_CAP"))
			_at(0.6 + CARRY + 1.3, func() -> void: _say_now("HTP_UT_GONE_CAP"))
			_loop = 5.4
		Lesson.WRAP:
			_say(0.0, "HTP_UT_UNDER_CAP")
			_at(0.6, func() -> void: _carry(1, 7, CARRY))
			_at(0.6 + CARRY * 0.55, func() -> void: _wrap_on(2))
			_at(0.6 + CARRY + 0.2, func() -> void: _say_now("HTP_UT_WRAPPED_CAP"))
			_at(3.9, func() -> void:
				_say_now("HTP_UT_UNDO_CAP")
				_fly_to(1, 5, 0.32, 0.0))
			_at(3.9 + 0.16, func() -> void: _wrap_on(1))
			_loop = 6.4
		Lesson.HINT:
			_say(0.0, "HTP_UT_HINT_CAP")
			_at(0.7, func() -> void: _hint_t = _clock)
			_at(1.3, func() -> void: _fly_to(1, 7, FLY * 1.6, _peg_r * UT.FLY_ARC))
			_at(1.3 + FLY * 0.8, func() -> void: _cross_off())
			_at(1.3 + FLY * 1.6 + 0.05, func() -> void: _free())
			_loop = 4.4
		Lesson.THREAD:
			_say(0.0, "HTP_UT_STITCH_CAP")
			_at(0.6, func() -> void: _carry(1, 4, CARRY))
			_at(0.6 + CARRY * 0.5, func() -> void: _stitch())
			_at(2.6, func() -> void:
				_say_now("HTP_UT_UNDO_STITCH_CAP")
				_fly_to(1, 5, 0.32, 0.0)
				_stitch())
			_at(4.4, func() -> void: _say_now("HTP_UT_OUT_CAP"))
			_loop = 6.6
		Lesson.CAT:
			_marked = 2
			_cat_in = 1
			_say(0.0, "HTP_UT_CAT_CAP")
			_at(0.8, func() -> void: _carry(1, 4, CARRY))
			_at(2.5, func() -> void:
				_say_now("HTP_UT_SWAT_CAP")
				_paw_t = _clock
				_kitten.expression = Face.Expr.JOY)
			_at(2.5 + UT.POUNCE_LEAD, func() -> void:
				_fly_to(2, 3, UT.POUNCE_FLY, _peg_r * 1.2)
				_cat_in = 3)
			_at(4.3, func() -> void: _kitten.expression = Face.Expr.HAPPY)
			_loop = 6.0
	if _kitten != null:
		_kitten.expression = Face.Expr.HAPPY
	_settle(70)
	_rebuild()

## The lesson's end, standing still, for reduce motion.
func _still() -> void:
	var cap := ""
	match lesson:
		Lesson.LIFT, Lesson.HINT:
			_place(1, 7)
			_pairs = {}
			cap = "HTP_UT_FREE_CAP" if lesson == Lesson.LIFT else "HTP_UT_HINT_CAP"
		Lesson.WRAP:
			_place(1, 7)
			_pairs[Vector2i(0, 1)] = {"n": 2, "t": 0}
			cap = "HTP_UT_WRAPPED_CAP"
		Lesson.REACH:
			_place(3, 6)
			cap = "HTP_UT_REACHED_CAP"
		Lesson.THREAD:
			_spent = 2
			cap = "HTP_UT_STITCH_CAP"
		Lesson.CAT:
			_place(1, 4)
			cap = "HTP_UT_CAT_CAP"
	_caption.text = tr(cap)
	# Laid again from where the pegs now sit, straight, as the board lays a
	# restored day.
	for r in _ropes.size():
		(_ropes[r] as Rope).setup(_pos[2 * r], _pos[2 * r + 1], _len[r], _wd)

## Ropes as [colour, hole, hole, reach in holes], one after another.
func _deal(ropes: Array) -> void:
	var n := ropes.size()
	_hole = PackedInt32Array(); _hole.resize(2 * n)
	_pos = PackedVector2Array(); _pos.resize(2 * n)
	_lift = PackedFloat32Array(); _lift.resize(2 * n)
	_face = PackedInt32Array(); _face.resize(2 * n)
	_fly = []
	_fly.resize(2 * n)
	_ropes = []
	_col = []
	_len = PackedFloat32Array(); _len.resize(n)
	_order = range(n)
	for r in n:
		var d: Array = ropes[r]
		_col.append(int(d[0]))
		for e in 2:
			_hole[2 * r + e] = int(d[1 + e])
			_pos[2 * r + e] = _hole_px(int(d[1 + e]))
		_len[r] = 2.0 * _rh * sin(PI * float(d[3]) / HOLES) * UT.LENGTH_OVER
		var rope := Rope.new()
		rope.setup(_pos[2 * r], _pos[2 * r + 1], _len[r], _wd)
		_ropes.append(rope)

func _place(p: int, h: int) -> void:
	_hole[p] = h
	_pos[p] = _hole_px(h)

func _at(t: float, what: Callable) -> void:
	_script.append([t, what])
	_script.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])

func _say(t: float, key: String) -> void:
	_at(t, func() -> void: _say_now(key))

func _say_now(key: String) -> void:
	_caption.text = tr(key)

## Peg `p` lifted and carried by a finger toward hole `h` over `dur`; let go
## there (or, when `back`, put back where it was: too far for its rope).
func _carry(p: int, h: int, dur: float, back := false) -> void:
	_fly[p] = {"from": _pos[p], "to": _hole_px(h), "t0": _clock, "dur": dur, "arc": 0.0,
		"held": true, "hole": h, "back": back}

## Peg `p` on a flight to hole `h`, no finger: an undo, a hint, a swat.
func _fly_to(p: int, h: int, dur: float, arc: float) -> void:
	_fly[p] = {"from": _pos[p], "to": _hole_px(h), "t0": _clock, "dur": dur, "arc": arc,
		"held": false, "hole": h, "back": false}
	_hole[p] = h

## The rope on top carried off the other: the crossing slides off.
func _cross_off() -> void:
	_pairs.erase(Vector2i(0, 1))

## The rope underneath carried over the other: it wraps round once more.
func _wrap_on(n: int) -> void:
	var e: Dictionary = _pairs.get(Vector2i(0, 1), {"n": 1, "t": 0})
	e.n = n
	_pairs[Vector2i(0, 1)] = e

## No rope crosses another: they light up, the pegs grin, and each is reeled
## in and leaves the ring (`_leaving`).
func _free() -> void:
	_glow = _clock
	_reeled = false
	for p in _face.size():
		_face[p] = 1

## How much of the ropes and pegs is there: 1 until the free ropes have been
## reeled in, then falling to 0 as they pop away.
func _left() -> float:
	if _glow < 0.0:
		return 1.0
	return 1.0 - clampf((_clock - _glow - UT.LEAVE_WAIT * 2.0 - UT.LEAVE_REEL) / UT.LEAVE_POP, 0.0, 1.0)

## The free ropes' leaving: after the grin, each rope's second peg is reeled
## across to its first.
func _leaving() -> void:
	if _glow < 0.0 or _reeled or _clock < _glow + UT.LEAVE_WAIT * 2.0:
		return
	_reeled = true
	for r in _ropes.size():
		_fly[2 * r + 1] = {"from": _pos[2 * r + 1], "to": _pos[2 * r], "t0": _clock, "dur": UT.LEAVE_REEL,
			"arc": _peg_r * 0.35, "held": false, "hole": _hole[2 * r], "back": false}

func _stitch() -> void:
	_stitch_t.append(_clock)
	_spent += 1

func _hole_px(h: int) -> Vector2:
	return _c + Vector2.from_angle(TAU * float(h) / HOLES - PI * 0.5) * _rh

# --- the frame ---

func _process(delta: float) -> void:
	_clock += delta
	while _next < _script.size() and _clock >= float(_script[_next][0]):
		(_script[_next][1] as Callable).call()
		_next += 1
	if _clock >= _loop:
		_scene()
		return
	_leaving()
	_move_pegs(delta)
	_lay()
	for r in _ropes.size():
		(_ropes[r] as Rope).step(delta)
	_rebuild()
	queue_redraw()

func _move_pegs(delta: float) -> void:
	_preview = ""
	_preview_hole = -1
	_taut = false
	for p in _pos.size():
		var f = _fly[p]
		var held := false
		if f != null:
			var u := clampf((_clock - float(f.t0)) / float(f.dur), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 3.0) if not f.held else smoothstep(0.0, 1.0, u)
			var want: Vector2 = (f.from as Vector2).lerp(f.to, e)
			held = f.held
			if held:
				# The peg rides the finger, but no further from its twin than
				# its rope reaches.
				var other := _pos[p ^ 1]
				var most := _len[p >> 1] * 0.995
				if want.distance_to(other) > most:
					want = other + (want - other).normalized() * most
					_taut = true
					_far = int(f.hole)
				_preview_for(p, want)
			_pos[p] = want
			if u >= 1.0:
				_fly[p] = null
				if held and bool(f.back):
					_fly_to(p, _hole[p], 0.24, 0.0)
				elif held:
					_hole[p] = int(f.hole)
					_pos[p] = _hole_px(_hole[p])
				held = false
		_lift[p] = move_toward(_lift[p], 1.0 if held else 0.0, delta * LIFT_RATE)
		if held:
			_face[p] = 3 if _taut else (1 if _face[p] == 1 else 0)
		elif _face[p] == 3:
			_face[p] = 0
	if not _taut and _far >= 0 and _fly.all(func(f) -> bool: return f == null):
		_far = -1

## What dropping held peg `p` at `at` would do, as the board's number over
## the hole: -1 when its rope lies on top of the one it crosses, +1 under.
func _preview_for(p: int, at: Vector2) -> void:
	for h in HOLES:
		if _hole_px(h).distance_to(at) < _peg_r * UT.SNAP_R and h != _hole[p] and not _hole.has(h):
			_preview_hole = h
	if _preview_hole < 0 or lesson == Lesson.REACH:
		return
	_preview = "−1" if lesson != Lesson.WRAP else "+1"

func _settle(_steps: int) -> void:
	_lay()
	for r in _ropes.size():
		(_ropes[r] as Rope).rest()

# --- knots, as the board lays them (untangle2d.gd _lay_all) ---

## Each rope laid through the knot it is in, or straight.
func _lay() -> void:
	var stops := {}
	var laid := {}
	for k: Vector2i in _pairs:
		var n: int = _pairs[k].n
		if n < 2:
			continue
		var a0 := _pos[2 * k.x]
		var a1 := _pos[2 * k.x + 1]
		var b0 := _pos[2 * k.y]
		var b1 := _pos[2 * k.y + 1]
		var half := Rope.knot_half(n, _wd)
		var c := UT.knot_centre(a0, a1, b0, b1)
		var clear := half + _peg_r * UT.KNOT_OFF_PEG
		for e: Vector2 in [a0, a1, b0, b1]:
			if c.distance_to(e) < clear:
				c = e + ((a0 + a1 + b0 + b1 - e) / 3.0 - e).limit_length(clear)
		c = _c + (c - _c).limit_length(maxf(_ri - _wd * 1.1 - half, 0.0))
		# No further off a rope's line than that rope reaches.
		for r in [k.x, k.y]:
			var p0 := _pos[2 * r]
			var p1 := _pos[2 * r + 1]
			var most: float = _len[r] * UT.KNOT_WAY - half * 0.7
			var near := Geometry2D.get_closest_point_to_segment(c, p0, p1)
			var lo := 0.0
			var hi := 0.0 if p0.distance_to(c) + c.distance_to(p1) <= most else 1.0
			for it in 12 if hi > 0.0 else 0:
				var f := (lo + hi) * 0.5
				var q := c.lerp(near, f)
				if p0.distance_to(q) + q.distance_to(p1) > most:
					lo = f
				else:
					hi = f
			c = c.lerp(near, hi)
		var kn := Rope.lay_knot(k, c, n, _wd, a0, a1, b0, b1, _knots.get(k, {}))
		laid[k] = kn
		stops[k.x] = [[kn, 0]]
		stops[k.y] = [[kn, 1]]
	_knots = laid
	for r in _ropes.size():
		(_ropes[r] as Rope).lay(_pos[2 * r], _pos[2 * r + 1], stops.get(r, []), _wd)

## Where each crossing pair crosses as drawn, and which lies on top there:
## [over, under, s on over, s on under] (untangle2d.gd _pair_crossings).
func _crossings() -> Array:
	var out: Array = []
	for k: Vector2i in _pairs:
		var e: Dictionary = _pairs[k]
		var ra: Rope = _ropes[k.x]
		var rb: Rope = _ropes[k.y]
		var t0: int = e.t
		var hs: Array = []
		if _knots.has(k):
			var ia: PackedInt32Array = ra.marks.get(k, PackedInt32Array())
			var ib: PackedInt32Array = rb.marks.get(k, PackedInt32Array())
			if ia.size() != ib.size():
				continue
			var same := int(_knots[k].dir_b) > 0
			for i in ia.size():
				hs.append([ra.cum()[ia[i]], rb.cum()[ib[i if same else ia.size() - 1 - i]]])
		else:
			var hit = Geometry2D.segment_intersects_segment(_pos[2 * k.x], _pos[2 * k.x + 1], _pos[2 * k.y], _pos[2 * k.y + 1])
			if hit == null:
				continue
			hs = ra.hits(rb, hit, _wd * 1.8).slice(0, 1)
		for i in hs.size():
			var top := t0 if i % 2 == 0 else 1 - t0
			var h: Array = hs[i]
			if top == 1:
				out.append([k.x, k.y, h[0], h[1]])
			else:
				out.append([k.y, k.x, h[1], h[0]])
	return out

# --- the picture ---

func _build_ring() -> ArrayMesh:
	var b := Face.Builder.new()
	var soft := _ro - _ri
	b.stroke(Face.Builder.arc_points(_c + Vector2(0.012, 0.03) * _ro, _rh, 0.0, TAU), soft + 16.0, Color(Pal.TEXT, 0.05), true)
	b.stroke(Face.Builder.arc_points(_c + Vector2(0.01, 0.022) * _ro, _rh, 0.0, TAU), soft + 8.0, Color(Pal.TEXT, 0.09), true)
	b.stroke(Face.Builder.arc_points(_c, _rh, 0.0, TAU), soft, UT.WOOD, true)
	b.stroke(Face.Builder.arc_points(_c, _ro - 2.0, 0.0, TAU), 4.0, UT.WOOD_EDGE, true)
	b.stroke(Face.Builder.arc_points(_c, _ri + 2.0, 0.0, TAU), 4.0, UT.WOOD_EDGE, true)
	b.stroke(Face.Builder.arc_points(_c, _ro - 7.0, PI * 1.02, PI * 1.62), 3.5, Color(UT.WOOD_HI, 0.85), false, true)
	var grain := RandomNumberGenerator.new()
	grain.seed = 4471
	for k in 12:
		var rr := grain.randf_range(_ri + 6.0, _ro - 6.0)
		var a0 := grain.randf_range(0.0, TAU)
		b.stroke(Face.Builder.arc_points(_c, rr, a0, a0 + grain.randf_range(0.25, 0.9)), 1.6, Color(UT.WOOD_GRAIN, grain.randf_range(0.12, 0.26)), false, true)
	for h in HOLES:
		var at := _hole_px(h)
		b.disc(at, _hole_r * 1.14, Color(UT.HOLE_RIM, 0.7))
		b.disc(at, _hole_r, UT.HOLE)
		b.disc(at + Vector2(0.0, _hole_r * 0.16), _hole_r * 0.82, UT.HOLE_DEEP)
	return b.mesh()

func _rebuild() -> void:
	var b := Face.Builder.new()
	_draw_targets(b)
	var lift := PackedFloat32Array()
	lift.resize(_ropes.size())
	for r in _ropes.size():
		lift[r] = maxf(_lift[2 * r], _lift[2 * r + 1])
	var since := _clock - _glow
	var left := _left()
	for r in _order:
		var col: Array = UT.ROPES[_col[r]]
		var glow := Color(0, 0, 0, 0)
		if since > 0.0 and since < 1.0:
			glow = Color(Color("fff2b8"), 0.6 * sin(PI * since))
		(_ropes[r] as Rope).draw(b, _wd, col[0], col[1], col[2], lift[r], left, glow, 0.0, 1.0)
	# A piece of the rope on top laid back where it was drawn first.
	var rank := {}
	for i in _order.size():
		rank[int(_order[i])] = i
	for c in _crossings():
		var o: int = c[0]
		if int(rank[o]) > int(rank[int(c[1])]):
			continue
		var col: Array = UT.ROPES[_col[o]]
		var half := _wd * UT.PATCH_HALF
		(_ropes[o] as Rope).draw(b, _wd, col[0], col[1], col[2], lift[o], left, Color(0, 0, 0, 0), 0.0, 0.0, 0.0,
			float(c[2]) - half, float(c[2]) + half, 0.85)
	var order: Array = range(_pos.size())
	order.sort_custom(func(a: int, c: int) -> bool: return _lift[a] < _lift[c])
	if left > 0.0:
		for p in order:
			_draw_peg(b, p, left * (1.0 + 0.5 * sin(PI * left)) if left < 1.0 else 1.0)
	_draw_hand(b)
	_draw_thread(b)
	_draw_cat(b)
	_mesh = b.mesh()

## The holes the lifted peg's rope reaches, glowing; the one under it ringed.
func _draw_targets(b: Face.Builder) -> void:
	var lifted := -1
	for p in _lift.size():
		if _lift[p] > 0.05 and _fly[p] != null and bool(_fly[p].held):
			lifted = p
	if lifted < 0:
		return
	var u := _lift[lifted]
	var pulse := 0.5 + 0.5 * sin(_clock * 6.0)
	var other := _pos[lifted ^ 1]
	for h in HOLES:
		if _hole.has(h):
			continue
		var at := _hole_px(h)
		if at.distance_to(other) <= _len[lifted >> 1]:
			var r := _hole_r * (1.25 + 0.12 * pulse)
			Scenery.soft_disc(b, at, r * 1.7, r * 1.7, Color(Pal.SUN, (0.2 + 0.1 * pulse) * u))
			b.stroke(Face.Builder.arc_points(at, r, 0.0, TAU), 3.0, Color(Pal.SUN, (0.75 - 0.2 * pulse) * u), true)
		elif h == _far:
			b.stroke(Face.Builder.arc_points(at, _hole_r * 1.1, 0.0, TAU), 3.0, Color(UT.KNOT_HALO, 0.6 * u), true)
			var k := _hole_r * 0.42
			b.stroke(PackedVector2Array([at + Vector2(-k, -k), at + Vector2(k, k)]), 4.0, Color(UT.KNOT_HALO, 0.7 * u), false, true)
			b.stroke(PackedVector2Array([at + Vector2(k, -k), at + Vector2(-k, k)]), 4.0, Color(UT.KNOT_HALO, 0.7 * u), false, true)
	if _preview_hole >= 0:
		var at := _hole_px(_preview_hole)
		var r := _hole_r * (1.42 - 0.08 * pulse)
		b.stroke(Face.Builder.arc_points(at, r, 0.0, TAU), 4.0, Color(UT.KNOT_HALO, 0.95 * u), true)

func _arc(p: int) -> float:
	var f = _fly[p]
	if f == null or float(f.arc) <= 0.0:
		return 0.0
	var u := clampf((_clock - float(f.t0)) / float(f.dur), 0.0, 1.0)
	return sin(PI * u) * float(f.arc)

## A peg as the board draws one: its soft shadow, parted from it as it is
## lifted, and the cap with its inlay in the rope's colour (or a face).
func _draw_peg(b: Face.Builder, p: int, pop := 1.0) -> void:
	var R := _peg_r * pop
	var up := _lift[p] + _arc(p) / maxf(R, 1.0)
	var lift_px := UT.HOLD_LIFT * R * _lift[p] + _arc(p)
	var c := _pos[p]
	var at := c + Vector2(0.0, -lift_px)
	var spread := 1.0 + 0.5 * clampf(up, 0.0, 1.5)
	Scenery.soft_disc(b, c + Vector2(0.1, 0.26) * R + Vector2(0.14, 0.3) * lift_px, R * 1.02 * spread, R * 0.66 * spread,
		Color(Pal.TEXT, 0.24 - 0.09 * clampf(up, 0.0, 1.0)))
	var k := R * (1.0 + (UT.PEG_LIFT_SCALE - 1.0) * clampf(up, 0.0, 1.6))
	b.ellipse(at + Vector2(0.0, k * 0.1), k, k, UT.CAP_DEEP)
	b.ellipse(at, k * 0.97, k * 0.97, UT.CAP_SIDE)
	b.ellipse(at + Vector2(0.0, -k * 0.06), k * 0.8, k * 0.78, UT.CAP)
	b.ellipse(at + Vector2(-0.27, -0.32) * k, k * 0.27, k * 0.19, Color(UT.CAP_HI, 0.85))
	var col: Array = UT.ROPES[_col[p >> 1]]
	if _face[p] != 0:
		Face.face_parts(b, k * 0.82, at, Pal.TEXT, 1.0, Face.Expr.JOY if _face[p] == 1 else Face.Expr.STRAIN)
	elif p == _marked:
		_paw(b, at + Vector2(0.0, k * 0.02), k * 0.5, Color(UT.PAW, 0.95))
	else:
		b.disc(at + Vector2(0.0, -k * 0.06), k * 0.4, col[1])
		b.disc(at + Vector2(0.0, -k * 0.08), k * 0.32, col[0])
		b.disc(at + Vector2(-0.1, -0.16) * k, k * 0.1, Color(col[2], 0.9))
	if p == _marked and _cat_in == 1:
		var beat := 0.5 + 0.5 * sin(_clock * 7.0)
		b.stroke(Face.Builder.arc_points(c, R * (1.32 + 0.1 * beat), 0.0, TAU), 3.0, Color(UT.PAW, 0.85), true)
	# The bulb's glow on the peg a hint is about to move.
	var hs := _clock - _hint_t
	if p == 1 and hs >= 0.0 and hs < 1.2:
		var a := sin(PI * hs / 1.2)
		Scenery.soft_disc(b, at, R * 2.2, R * 2.2, Color(Pal.SUN, 0.35 * a))
		b.stroke(Face.Builder.arc_points(at, R * (1.3 + 0.2 * hs), 0.0, TAU), 3.0, Color(Pal.SUN, 0.9 * a), true)

func _paw(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	b.ellipse(at + Vector2(0.0, r * 0.32), r * 0.62, r * 0.5, col)
	for k in 4:
		b.ellipse(at + Vector2((k - 1.5) * r * 0.5, -r * (0.34 if k == 1 or k == 2 else 0.12)), r * 0.2, r * 0.26, col)

## The finger on a carried peg: a pale touch under it.
func _draw_hand(b: Face.Builder) -> void:
	for p in _pos.size():
		var f = _fly[p]
		if f == null or not bool(f.held):
			continue
		var u := clampf((_clock - float(f.t0)) / float(f.dur), 0.0, 1.0)
		var at: Vector2 = (f.from as Vector2).lerp(f.to, smoothstep(0.0, 1.0, u)) + Vector2(_peg_r * 0.5, _peg_r * 0.9)
		var a := minf(1.0, _lift[p] * 1.5)
		Scenery.soft_disc(b, at, _peg_r * 1.25, _peg_r * 1.25, Color(1.0, 1.0, 1.0, 0.55 * a))
		b.stroke(Face.Builder.arc_points(at, _peg_r * 0.7, 0.0, TAU), 3.0, Color(Pal.TEXT, 0.35 * a), true)

## The row of thread over the ring: a stitch a move.
func _draw_thread(b: Face.Builder) -> void:
	if lesson != Lesson.THREAD:
		return
	var w := 24.0
	var h := 9.0
	var gap := 9.0
	var y := 22.0
	var x0 := size.x * 0.5 - (BUDGET * (w + gap) - gap) * 0.5 + 16.0
	var sp := Vector2(x0 - 30.0, y)
	b.polygon(Face.Builder.round_rect(sp + Vector2(-11.0, -13.0), Vector2(22.0, 26.0), 5.0), UT.THREAD)
	b.polygon(Face.Builder.round_rect(sp + Vector2(-15.0, -16.0), Vector2(30.0, 7.0), 3.5), UT.CAP)
	b.polygon(Face.Builder.round_rect(sp + Vector2(-15.0, 9.0), Vector2(30.0, 7.0), 3.5), UT.CAP)
	var low := BUDGET - _spent <= 2
	for i in BUDGET:
		var at := Vector2(x0 + i * (w + gap) + w * 0.5, y)
		var t := float(_stitch_t[i]) if i < _stitch_t.size() else -10.0
		var since := _clock - t
		if i < _spent:
			var pop := 1.0
			if since >= 0.0 and since < 0.4:
				pop = 1.0 + 0.5 * sin(PI * since / 0.4)
			b.polygon(Face.Builder.round_rect(at - Vector2(w, h) * 0.5 * pop, Vector2(w, h) * pop, h * 0.5 * pop), Color(UT.THREAD_GONE, 0.32))
		else:
			var beat := (0.5 + 0.5 * sin(_clock * 6.0 - i)) if low and _clock > 4.4 else 0.0
			var col := UT.THREAD.lerp(UT.KNOT_HALO, beat * 0.5)
			b.polygon(Face.Builder.round_rect(at - Vector2(w, h) * 0.5, Vector2(w, h), h * 0.5), UT.THREAD_DEEP)
			b.polygon(Face.Builder.round_rect(at - Vector2(w, h) * 0.5 * 0.9 + Vector2(0.0, -1.5), Vector2(w, h) * 0.9, h * 0.45), col)

## The kitten's yarn in the marked peg's colour, and her paw on it as she
## swats.
func _draw_cat(b: Face.Builder) -> void:
	if lesson != Lesson.CAT:
		return
	var col: Array = UT.ROPES[_col[_marked >> 1]]
	var r := _ro * 0.17
	var at := _yarn_at
	Scenery.soft_disc(b, at + Vector2(r * 0.15, r * 0.95), r * 1.15, r * 0.36, Color(Pal.TEXT, 0.2))
	b.disc(at, r, col[1])
	b.disc(at + Vector2(-0.03, -0.05) * r, r * 0.93, col[0])
	for k in 3:
		var a0 := 0.5 + k * 1.05
		b.stroke(Face.Builder.arc_points(at + Vector2.from_angle(a0 + 2.2) * r * 0.5, r * 0.85, a0, a0 + 1.4), 2.4, Color(col[1], 0.75), false, false)
	var ps := _clock - _paw_t
	if ps >= 0.0 and ps < 0.9:
		var a := sin(PI * ps / 0.9)
		var p := _pos[_marked] + Vector2(-_peg_r * 0.2, -_peg_r * 1.1)
		_paw(b, p, _peg_r * (0.9 + 0.2 * a), Color(UT.PAW, 0.9 * a))

func _draw() -> void:
	if _ring_mesh == null or _mesh == null:
		return
	draw_mesh(_ring_mesh, null)
	draw_mesh(_mesh, null)
	var font: Font = CozyTheme.display(700)
	if _preview != "" and _preview_hole >= 0:
		var fs := int(_peg_r * 1.2)
		var hole := _hole_px(_preview_hole)
		var at := hole + (hole - _c).normalized() * _peg_r * 2.4
		var w := font.get_string_size(_preview, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := at + Vector2(-w * 0.5, fs * 0.36)
		var col := Pal.GOOD.darkened(0.15) if _preview.begins_with("−") else UT.KNOT_HALO
		draw_string_outline(font, base, _preview, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.34), Color("fffaf0"))
		draw_string(font, base, _preview, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if lesson == Lesson.CAT and _marked >= 0:
		var fs := int(_ro * 0.2)
		var text := str(_cat_in)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := _yarn_at + Vector2(-w * 0.5, fs * 0.36)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.3), Color(Pal.TEXT, 0.85))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fffaf0"))
