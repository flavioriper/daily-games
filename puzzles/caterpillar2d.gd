extends "res://core/puzzle_base.gd"

## Caterpillar as a flat board: a garden of squares with numbered leaves on
## some of them and wooden fences between a few. Press leaf 1 and drag, and
## every square the finger crosses grows the caterpillar one segment; it eats
## the leaves in order, never crosses itself or a fence, and the board is done
## when its body fills every square with its head on the last leaf. The rules
## live in puzzles/caterpillar_state.gd, which this only draws.
##
## **Nothing wrong can sit on this garden.** A fence, a leaf out of turn and
## the last leaf too soon are refused at the step, with the head shivering
## and the tip card saying why, so the only way to be wrong is to be stuck:
## no Check, no tray and no actions row. The tip card stands alone and Undo,
## Reset and Hint ride in the top bar -- Pinwheel's shape.
##
## How it is drawn. Three meshes and the leaf numbers between them:
##   still -- the bare ground and its grid, rebuilt only on a relayout;
##   live  -- the hint's gold wash, the fences, the body and the leaf badges;
##   top   -- the head and, on the solve, the butterfly;
## with the numbers drawn over `live` and under `top`, because the head is the
## one thing the finger is holding and it must never sit under a badge (the
## concept page's first frame hid it under leaf 3). The caterpillar itself is
## `ui/faces/caterpillar.gd`, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-25-caterpillar-flat-design.md,
## section 7. Ported from the canvas mock at
## docs/brainstorm/concepts.html#caterpillar, the reference for every measure.

const State = preload("res://puzzles/caterpillar_state.gd")
const Gen = preload("res://puzzles/caterpillar_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Cat = preload("res://ui/faces/caterpillar.gd")

# --- the screen, measured ---
## The card's inset, the largest cell any band asks for, and how far the
## ground runs out past the grid.
const INSET := 28.0
const CELL_CAP := 180.0
const GROUND_PAD := 12.0
const GROUND_R := 26.0
const RULE_W := 3.0
const RULE_TRIM := 6.0
const RIM_W := 4.0
## While a finger is dragging, only the middle of a square counts, so a fast
## drag along one row cannot clip the corner of the next.
const DRAG_CORE := 0.1

# --- the pieces, in cells ---
## A leaf badge: its radius, the leaf on its shoulder, the gold ring an eaten
## one wears, and its number's size against the radius.
const BADGE_R := 0.27
const BADGE_LEAF := 1.05
const BADGE_LEAF_AT := Vector2(0.55, -0.7)
const BADGE_LEAF_ANGLE := -0.75
const EATEN_RING := 0.035
const EATEN_RING_W := 0.05
const NUMBER := 1.15
## A fence: its length and thickness, the lit rail's share of the width, and
## its three posts.
const FENCE_LEN := 0.98
const FENCE_TH := 0.13
const RAIL := 0.62
const POST_R := 0.78
## The gold wash under a square a hint grew.
const GIVEN_R := 0.42
const GIVEN_ALPHA := 0.4

# --- this board's own motion ---
## The head easing in from the square it left, its breath at rest (amplitude,
## rate, phase), and the munch. Only the head breathes: see _process.
const SLIDE_TIME := 0.11
const CRAWL := 0.035
const CRAWL_RATE := 4.2
const CRAWL_PHASE := 0.7
const MUNCH := 0.16
const MUNCH_TIME := 0.3
## The solve: the hop runs tail to head over SOLVE_SPAN whatever the length,
## then the butterfly rises over BUTTERFLY_TIME.
const SOLVE_SPAN := 0.7
const BUTTERFLY_LAG := 0.1
const BUTTERFLY_TIME := 1.8
## The butterfly's half-span, in cells.
const BUTTERFLY_W := 0.8
const BUTTERFLY_RISE := 900.0
const WIN_WAIT := 2.8
## A refusal repeated on the same square is not said twice inside this.
const REFUSE_QUIET := 0.5
const HINTS := 3
## A hint's segments arrive this far apart.
const HINT_STEP := 0.08

const TIP_CYCLE := 8.0
const TIPS := ["CP_TIP_START", "CP_TIP_ORDER", "CP_TIP_FILL", "CP_TIP_BACK", "CP_TIP_FENCE"]

var _state = State.new()
var fx: Node2D

## When each body segment appeared, parallel to the body.
var _seg_at: Array[float] = []
var _head_from := -1
var _head_at := -100.0
var _munch_at := -100.0
var _dragging := false
var _stroke_from := PackedInt32Array()
## The last refusal: {"at", "cell", "kind"}.
var _refused := {"at": -100.0, "cell": -1, "kind": ""}
var _rings: Array = []

var _opened := 0.0
var _anim_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
var _top: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "caterpillar"
func title() -> String: return "Caterpillar"

func rules() -> String:
	return tr("CP_RULES")

## Undo and Hint; Reset is the host's. No Check: nothing wrong can sit here.
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
	_seg_at = []
	_head_from = -1
	_dragging = false
	_refused = {"at": -100.0, "cell": -1, "kind": ""}
	_rings = []
	_anim_until = 0.0
	_solved_at = -1.0
	_layout()
	_opened = _now()
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

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.cols, c / _state.cols) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.cols + c)

## The square under a local point, or -1. While dragging only its core counts.
func _cell_at(local: Vector2, core := false) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var p := (local - _origin()) / s
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= _state.cols or y >= _state.rows:
		return -1
	if core:
		var f := p - Vector2(x, y)
		if f.x < DRAG_CORE or f.x > 1.0 - DRAG_CORE or f.y < DRAG_CORE or f.y > 1.0 - DRAG_CORE:
			return -1
	return y * _state.cols + x

func card_height(available: float) -> float:
	return available

## The grid is square and the slot is tall, so the slack is halved.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_refresh()

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	if _animating(t):
		_refresh()
	elif not Motion.reduce and not _state.body.is_empty():
		# At rest only the head moves -- its breath and its blink -- and it is
		# its own small mesh, so an idle garden rebuilds that and nothing
		# else. The first cut breathed every segment and rebuilt the whole
		# body a frame: 12 ms an idle frame on this Mac against Pinwheel's 3.
		_top = null
		queue_redraw()

## Asked wave by wave: the entrance, a slide, a pop, a refusal, a ring and
## the solve all ask for time by the clock through _busy_for.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.last_leaf(), Motion.ENTER_STAGGER) + Motion.POP_IN
	return t - _opened < entrance

func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

func _refresh() -> void:
	_live = null
	_top = null
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
	var shown: Array = []
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	if _top == null:
		_top = _build_top(t)
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_numbers(t, xf, seen)
	if _top != null:
		draw_mesh(_top, null, xf, tint)
		shown.append(_top)
	_draw_butterfly_mesh(t, shown)
	_shown = shown

## The bare ground: Shikaku's unclaimed plot, with its faint grid.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var panel := Face.Builder.round_rect(o - Vector2.ONE * GROUND_PAD, g + Vector2.ONE * GROUND_PAD * 2.0, GROUND_R)
	b.fan(panel, Pal.BED_GROUND)
	for x in range(1, _state.cols):
		b.stroke(PackedVector2Array([o + Vector2(x * s, RULE_TRIM), o + Vector2(x * s, g.y - RULE_TRIM)]), RULE_W, Pal.BED_LINE, false, false)
	for y in range(1, _state.rows):
		b.stroke(PackedVector2Array([o + Vector2(RULE_TRIM, y * s), o + Vector2(g.x - RULE_TRIM, y * s)]), RULE_W, Pal.BED_LINE, false, false)
	# A rim, as the card's picture has: BED_GROUND is only a shade off the
	# card's parchment, and without it the garden has no edge.
	b.stroke(panel, RIM_W, Pal.LINE, true)
	return b.mesh()

func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	for c in _state.given:
		if _state.body.has(c):
			b.fan(Face.Builder.round_rect(_centre(c) - Vector2.ONE * s * GIVEN_R,
				Vector2.ONE * s * GIVEN_R * 2.0, s * 0.18), Color(Pal.SUN_RAY, GIVEN_ALPHA))
	for e in _state.hedges:
		_fence(b, e, t)
	_body(b, t)
	for k in _state.leaves.size():
		_badge(b, _state.leaves[k], t)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r["at"])) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			b.stroke(Face.Builder.ring(_centre(r["cell"]), s * (0.34 + 0.3 * u), s * (0.34 + 0.3 * u)),
				s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## A fence on the edge between two squares, flashing and shivering when the
## head was just refused across it.
func _fence(b, e: int, t: float) -> void:
	var s := _cell()
	var a := e / 4096
	var z := e % 4096
	var mid := (_centre(a) + _centre(z)) * 0.5
	var vertical: bool = a / _state.cols == z / _state.cols
	var hot := String(_refused["kind"]) == "hedge" and (int(_refused["cell"]) == a or int(_refused["cell"]) == z) \
		and (_state.head() == a or _state.head() == z)
	var since := t - float(_refused["at"]) if hot else -1.0
	var fl := Motion.flash_level(since) if hot else 0.0
	var sh := Motion.shiver_offset(since) * 2.0 if hot else 0.0
	var along := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)
	var across := Vector2(1.0, 0.0) if vertical else Vector2(0.0, 1.0)
	var at := mid + across * sh
	var ln := s * FENCE_LEN
	var th := s * FENCE_TH
	var xf := Transform2D(across, along, at)
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5), Vector2(th, ln), th * 0.5),
		Pal.FENCE_DARK.lerp(Pal.BAD, fl * 0.7))
	b.fan(xf * Face.Builder.round_rect(Vector2(-th * 0.5, -ln * 0.5), Vector2(th * RAIL, ln), th * RAIL * 0.5),
		Pal.FENCE_RAIL.lerp(Pal.BAD, fl * 0.5))
	for y: float in [-ln * 0.5 + th * 0.3, 0.0, ln * 0.5 - th * 0.3]:
		b.fan(xf * Face.Builder.ring(Vector2(0.0, y), th * POST_R, th * POST_R), Pal.FENCE_POST)
		b.fan(xf * Face.Builder.ring(Vector2(-th * 0.12, y - th * 0.12), th * 0.42, th * 0.42), Pal.FENCE_RAIL)

## Every body point this frame, tail first: each square's centre, the head's
## eased in from the square it left, and the solve's hop running tail to head.
func _points(t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = _state.body.size()
	for i in n:
		var p := _centre(_state.body[i])
		if i == n - 1 and _head_from >= 0 and not Motion.reduce:
			var u := clampf((t - _head_at) / SLIDE_TIME, 0.0, 1.0)
			if u < 1.0:
				p = _centre(_head_from).lerp(p, 0.5 - 0.5 * cos(PI * u))
		if _solved_at >= 0.0:
			p.y += Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY - _wave(i, n),
				Motion.SOLVE_HOP, Motion.SOLVE_TIME)
		pts.append(p)
	return pts

## When the solve's hop reaches segment `i` of `n`: SOLVE_SPAN tail to head.
static func _wave(i: int, n: int) -> float:
	return SOLVE_SPAN * float(i) / float(maxi(n - 1, 1))

func _body(b, t: float) -> void:
	var n: int = _state.body.size()
	if n == 0:
		return
	var scales: Array = []
	var breath := PackedFloat32Array()
	for i in n:
		scales.append(Motion.pop_in_scale(t - _seg_at[i]) if i < _seg_at.size() else Vector2.ONE)
		breath.append(1.0)
	Cat.body(b, _points(t), _cell(), scales, breath)

## A leaf badge: ink disc, a leaf on its shoulder, a gold ring once eaten. It
## pops in on the entrance by its number, bumps when eaten, and flashes and
## shivers when a step onto it was refused.
func _badge(b, c: int, t: float) -> void:
	var f := _badge_frame(c, t)
	if f.scale.x <= 0.01:
		return
	var s := _cell()
	var r := s * BADGE_R
	var xf := Transform2D(0.0, f.scale, 0.0, f.at)
	var got: bool = _state.body.has(c)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(r * BADGE_LEAF * 0.55, -r * BADGE_LEAF * 0.42), Vector2(r * BADGE_LEAF, 0.0), 10)
	pts.append_array(Face.Builder.bezier2(Vector2(r * BADGE_LEAF, 0.0), Vector2(r * BADGE_LEAF * 0.55, r * BADGE_LEAF * 0.42), Vector2.ZERO, 10))
	b.polygon(xf * (Transform2D(BADGE_LEAF_ANGLE, BADGE_LEAF_AT * r) * pts), Pal.LEAF_LIGHT if got else Pal.LEAF)
	if got:
		b.fan(xf * Face.Builder.ring(Vector2.ZERO, r + s * (EATEN_RING + EATEN_RING_W * 0.5), r + s * (EATEN_RING + EATEN_RING_W * 0.5)), Pal.SUN)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, r, r), Pal.TEXT.lerp(Pal.BAD, f.flash * 0.7))

## Where a badge is and how big this frame: {at, scale, flash}.
func _badge_frame(c: int, t: float) -> Dictionary:
	var k: int = _state.clue[c]
	var hot := int(_refused["cell"]) == c and String(_refused["kind"]) in ["order", "last"]
	var since := t - float(_refused["at"]) if hot else -1.0
	var pop := Motion.pop_in_scale(t - _opened - Motion.ENTER_DELAY - Motion.ENTER_POP * 0.4
		- Motion.stagger(k, Motion.ENTER_STAGGER))
	var bump := 1.0
	for r: Dictionary in _rings:
		if int(r["cell"]) == c:
			bump = maxf(bump, Motion.bump_scale(t - float(r["at"]), 0.14, 0.3))
	return {"at": _centre(c) + Vector2(Motion.shiver_offset(since) * 3.0 if hot else 0.0, 0.0),
		"scale": pop * bump, "flash": Motion.flash_level(since) if hot else 0.0}

## The leaf numbers, over the badges and under the head.
func _draw_numbers(t: float, xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.display(700)
	var px := int(round(_cell() * BADGE_R * NUMBER))
	for k in _state.leaves.size():
		var c: int = _state.leaves[k]
		var f := _badge_frame(c, t)
		if f.scale.x <= 0.01:
			continue
		var text := str(k + 1)
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
		var rise := font.get_height(px) * 0.5 - font.get_descent(px)
		draw_set_transform_matrix(xf * Transform2D(0.0, f.scale, 0.0, f.at))
		draw_string(font, Vector2(-wide * 0.5, rise), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px,
			Color(Pal.SURFACE, seen))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## The head, over everything the finger is not holding.
func _build_top(t: float) -> ArrayMesh:
	var n: int = _state.body.size()
	if n == 0:
		return null
	var b := Face.Builder.new()
	var pts := _points(t)
	var at := pts[n - 1]
	var dir := Vector2(0.0, -1.0)
	if n > 1:
		dir = (at - pts[n - 2]).normalized() if at.distance_to(pts[n - 2]) > 0.01 else \
			(_centre(_state.body[n - 1]) - _centre(_state.body[n - 2])).normalized()
	var since := t - float(_refused["at"])
	var strain := String(_refused["kind"]) != "" and since < Motion.SHIVER_TIME * 2.0
	at.x += Motion.shiver_offset(since) * 4.0 if strain else 0.0
	var expr := Face.Expr.JOY if _solved_at >= 0.0 else (Face.Expr.STRAIN if strain else Face.Expr.HAPPY)
	var grow := 1.0 if Motion.reduce else 1.0 + CRAWL * 0.6 * sin(t * CRAWL_RATE + CRAWL_PHASE)
	var sq := Vector2.ONE
	var u := (t - _munch_at) / MUNCH_TIME
	if not Motion.reduce and u >= 0.0 and u < 1.0:
		var w := sin(PI * u)
		sq = Vector2(1.0 + MUNCH * 0.5 * w, 1.0 - MUNCH * w)
	Cat.head(b, at, dir, _cell(), grow, sq, expr, _blink(t))
	return b.mesh()

func _blink(t: float) -> float:
	if Motion.reduce:
		return 1.0
	var m := fmod(t + 0.4, 3.8)
	return 1.0 - 0.9 * sin(PI * m / 0.14) if m < 0.14 else 1.0

## The butterfly the solve ends in: out of the head once the hop has reached
## it, up and away over the top of the card. It is drawn outside the entrance
## transform and is not clipped, so it can fly over the chrome.
func _draw_butterfly_mesh(t: float, shown: Array) -> void:
	if _solved_at < 0.0 or Motion.reduce:
		return
	var u := t - _solved_at - Motion.SOLVE_DELAY - SOLVE_SPAN - BUTTERFLY_LAG
	if u < 0.0 or u > BUTTERFLY_TIME:
		return
	var s := _cell()
	var start := _centre(_state.head())
	var rise := minf(1.0, u / BUTTERFLY_TIME)
	var at := start + Vector2(sin(u * 3.0) * s * 0.8 * rise, -pow(rise, 1.5) * BUTTERFLY_RISE)
	var alpha := clampf(u / 0.2, 0.0, 1.0) * (1.0 - clampf((u - (BUTTERFLY_TIME - 0.4)) / 0.4, 0.0, 1.0))
	var beat := 0.35 + 0.65 * absf(sin(u * 11.0))
	var w := s * BUTTERFLY_W * minf(1.0, u / 0.25 + 0.2)
	var b := Face.Builder.new()
	Cat.butterfly(b, at, w, beat, sin(u * 2.2) * 0.2, alpha)
	var m := b.mesh()
	draw_mesh(m, null)
	shown.append(m)

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(_cell_at(event.position))
		else:
			_release()
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging:
		var c := _cell_at(event.position, true)
		if c >= 0:
			_step(c)
		accept_event()

func _press(c: int) -> void:
	if c < 0:
		return
	var t := _now()
	_stroke_from = _state.body.duplicate()
	if _state.body.is_empty():
		if _state.start(c):
			_busy_for(Motion.POP_IN)
			_seg_at = [t]
			_head_from = -1
			_head_at = t
			_dragging = true
			_ring_at(c, t)
			fx.cue("place")
			_refresh()
		else:
			_say(tr("CP_START"), Face.Expr.HAPPY)
		return
	if _state.body.has(c):
		_dragging = true
		if c != _state.head():
			_cut(c, t)
	else:
		_say(tr("CP_FROM_HEAD"), Face.Expr.HAPPY)

func _step(c: int) -> void:
	if c == _state.head():
		return
	var t := _now()
	if _state.body.has(c):
		_cut(c, t)
		return
	var why: String = _state.why(c)
	if why == "far":
		return
	if why != "":
		if int(_refused["cell"]) != c or t - float(_refused["at"]) > REFUSE_QUIET:
			_refuse(why, c, t)
		return
	_head_from = _state.head()
	_head_at = t
	_state.grow(c)
	_seg_at.append(t)
	_busy_for(maxf(SLIDE_TIME, Motion.POP_IN))
	if _state.clue[c] != 0:
		_munch_at = t + SLIDE_TIME
		_busy_for(SLIDE_TIME + MUNCH_TIME)
		_ring_at(c, t + SLIDE_TIME)
		fx.cue("munch")
		_speak_leaf(_state.clue[c])
	else:
		fx.cue("step")
	_refresh()
	if _state.is_solved():
		_release()

func _cut(c: int, t: float) -> void:
	_busy_for(Motion.POP_IN)
	_state.cut_to(c)
	_seg_at.resize(_state.body.size())
	_head_from = -1
	_head_at = t
	fx.cue("step")
	_refresh()

func _refuse(kind: String, c: int, t: float) -> void:
	_refused = {"at": t, "cell": c, "kind": kind}
	_busy_for(Motion.FLASH_IN + Motion.FLASH_OUT)
	fx.cue("refuse")
	match kind:
		"hedge": _say(tr("CP_NO_FENCE"), Face.Expr.STRAIN)
		"order": _say(tr("CP_NO_ORDER") % [_state.clue[c], _state.eaten() + 1], Face.Expr.STRAIN)
		"last": _say(tr("CP_NO_LAST") % _state.last_leaf(), Face.Expr.STRAIN)
	_refresh()

## The finger is up: a stroke that changed the body is one move.
func _release() -> void:
	if not _dragging:
		return
	_dragging = false
	if _state.commit(_stroke_from):
		note_move()

func _ring_at(c: int, at: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"cell": c, "at": at})
	_busy_for(at - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r["at"]) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- the sprout's line ---

func _speak_leaf(k: int) -> void:
	var left: int = _state.last_leaf() - k
	if left > 0:
		_say(tr("CP_LEAF_ONE") % k if left == 1 else tr("CP_LEAF_N") % [k, left], Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or not _state.body.is_empty():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Puts the body back as it was before the last stroke. Counts no move.
func undo() -> bool:
	if is_done() or not _state.undo():
		return false
	_restored(_now())
	_say(tr("CP_UNDONE"), Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

## A body that came back whole: the segments it has that the old one did not
## pop back in, tail first.
func _restored(t: float) -> void:
	var n: int = _state.body.size()
	var had := _seg_at.size()
	_seg_at.resize(n)
	for i in range(had, n):
		_seg_at[i] = t + Motion.stagger(i - had, Motion.RESET_STAGGER)
	_head_from = -1
	_head_at = t
	_busy_for(Motion.stagger(maxi(n - had, 0), Motion.RESET_STAGGER) + Motion.POP_IN)
	_refresh()

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Cuts back to the right stretch and grows the answer on to the next leaf.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var t := _now()
	var grown: PackedInt32Array = _state.hint()
	if grown.is_empty():
		return false
	hints_used += 1
	var n: int = _state.body.size()
	_seg_at.resize(n)
	for k in grown.size():
		_seg_at[n - grown.size() + k] = t + float(k) * HINT_STEP
	_head_from = -1
	_head_at = t
	_ring_at(grown[grown.size() - 1], t + float(grown.size() - 1) * HINT_STEP)
	_busy_for(float(grown.size()) * HINT_STEP + Motion.POP_IN)
	_say(tr("CP_HINT"), Face.Expr.HAPPY)
	fx.cue("hint")
	_refresh()
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	_state.reset_board()
	_seg_at = []
	_head_from = -1
	_dragging = false
	_rings = []
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its walk: the garden's size, the leaves.
func share_glyphs() -> String:
	return "🐛" + "🍃".repeat(_state.last_leaf()) + "🦋"

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("CP_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_dragging = false
	_solved_at = t + SLIDE_TIME
	_tip_timer.stop()
	var n: int = _state.body.size()
	for c in _state.leaves:
		var i: int = _state.body.find(c)
		var after := _solved_at - t + Motion.SOLVE_DELAY + _wave(i, n)
		if not Motion.reduce:
			get_tree().create_timer(after).timeout.connect(func(): fx.sparkle(_centre(c), Pal.SUN))
	_busy_for(_solved_at - t + Motion.SOLVE_DELAY + SOLVE_SPAN + Motion.SOLVE_TIME
		+ BUTTERFLY_LAG + BUTTERFLY_TIME)
	_say(tr("CP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()

## A reopened daily that was already solved: the whole walk laid at once,
## nothing left to run. Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_state.body = _state.path.duplicate()
	_seg_at = []
	for i in _state.body.size():
		_seg_at.append(-100.0)
	_head_from = -1
	_solved_at = -1.0
	_anim_until = 0.0
	_opened = _now() - 100.0
	_tip_timer.stop()
	_say(tr("CP_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
