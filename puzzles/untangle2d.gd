extends "res://core/puzzle_base.gd"

## Untangle as a flat board: paper lanterns hung on cords over the host's
## parchment card, dragged until no two cords cross. Built beside the island
## version (puzzles/untangle3d.gd) so the two can be judged against each other
## on the phone; the rules live in puzzles/untangle_state.gd, which this only
## draws.
##
## This is the screen with the strongest case for going flat, and it is a case
## about honesty rather than polish. The island strings a Verlet rope between
## its posts -- the best piece of motion in the game -- but the rule is tested
## on the *straight segment* between two posts, so what the player reads is a
## curve standing in for a line. Here the cord is drawn taut and the line read
## is the line tested. The weight is kept where it costs nothing: a cord takes
## slack while the lantern it hangs off is in the player's hand, and springs
## straight again within about half a second of the drop.
##
## How it is drawn. Every cord, every ring and arm and every fading puff go
## into one ArrayMesh through Face.Builder, rebuilt only on the frames
## something is actually moving, so a hard board of twenty-four cords costs
## one draw command rather than fifty strokes -- gl_compatibility pays per
## command (see CLAUDE.md). The knots are one cached mesh drawn once per
## crossing with its own turn, and the lanterns are the only nodes: fourteen
## Face subclasses, each one cached mesh a layer.
##
## The frame is the mock's, kept deliberately: positions, springs and
## entrances are integrated and interpolated in _process against a clock,
## never tweened, because the picture of a lantern moves under a finger that
## is still moving it and a tween would be fighting the drag.
## Spec: docs/superpowers/specs/2026-09-18-untangle-flat-design.md, sections 2
## to 7, and the mock it is ported from
## (docs/brainstorm/concepts.html#untangle).

const State = preload("res://puzzles/untangle_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")

# --- the field ---
## The card's insets. The bottom one is the deep one, because the ring is the
## node and the lantern hangs below it.
const PAD_X := 104.0
const PAD_TOP := 84.0
const PAD_BOTTOM := 176.0
## A lantern's radius per difficulty, and the field width they were drawn at;
## a narrower card takes them down with it.
const R_OF := [54.0, 48.0, 42.0]
const R_WIDTH := 780.0

# --- the cord ---
const CORD_WIDTH := 11.0
const CORD_LIGHT := 6.0
## The drawn sag is twice the spring's, which is what the mock's curve took.
const SAG_DRAW := 2.0
## How far a lit cord goes toward the sun behind the light.
const LIT_MIX := 0.55

# --- the lantern, in R ---
const RING_R := 0.16
const RING_PIP := 0.06
const ARM_WIDTH := 0.09
## A tap grabs the nearest lantern within this of its ring or its body.
const GRAB_R := 1.9
const GRAB_SCALE := 0.09
## A crowded lantern squashes against its neighbour.
const CROWD_SQUASH := Vector2(1.1, 0.9)

# --- the knot ---
const KNOT_R := 0.62
const KNOT_MIN := 22.0
## Forty markers is a rash, not a signal: the knots fade in as the board comes
## down past KNOT_FADE crossings and are at full strength KNOT_SPAN below it.
const KNOT_FADE := 16.0
const KNOT_SPAN := 4.0
const KNOT_SPIN := 0.14
const KNOT_TURN := 1.7
const PUFF_TIME := 0.45
const PUFF_FROM := 18.0
const PUFF_GROW := 70.0
const PUFF_WIDTH := 7.0

# --- the two springs ---
const SAG_K := 46.0
const SAG_DAMP := 7.4
const SAG_KICK := 2.6
const SAG_MAX := 300.0
const SAG_REST := 0.05
const SAG_REST_V := 0.5
const WAKE_KICK := 150.0
const SWING_K := 70.0
const SWING_DAMP := 7.0
const SWING_KICK := 0.1
const SWING_MAX := 4.0
const SWING_REST := 0.002
const SWING_REST_V := 0.02
## How far a drag has to travel before it counts as a move, in field pixels.
const DRAG_SLOP := 0.4

# --- motion ---
const ENTER_DELAY := 0.18
const ENTER_STAGGER := 0.035
const ENTER_TIME := 0.42
const ENTER_DROP := 60.0
const HOP := 10.0
const HOP_TIME := 0.36
const SLIDE_TIME := 0.3
const UNDO_TIME := 0.26
const HINT_TIME := 0.35
const HOME_STEP := 0.04
const LOCK_RING := 0.6
const LOCK_RING_R := 0.3
const LOCK_RING_GROW := 1.4
const LOCK_RING_WIDTH := 6.0
## The light runs out from one lantern along the cords, hop by hop.
const LIGHT_DELAY := 0.16
const LIGHT_STEP := 0.12
const LIGHT_TIME := 0.4
## How long the host waits before the win screen: the light has to reach the
## far end of the string first.
const WIN_WAIT := 2.0

const HINTS := State.HINTS
const TIP_CYCLE := 9.0
## The three lines that teach the board, cycled while there is nothing better
## to say.
const TIPS := [
	"Drag a lantern. No two cords may cross.",
	"A knot is drawn exactly where two cords meet. Pull one of them off it.",
	"Keep the lanterns apart. A heap in one corner is not an answer.",
]

var state = State.new()
## The names the win harness and the island board share, under one roof: they
## are the state's own.
var nodes: int:
	get: return state.nodes
var _pos: PackedVector2Array:
	get: return state.pos
var _locked: Array[bool]:
	get: return state.locked
var _crossings: int:
	get: return state.crossings()

var fx: Node2D
var _lanterns: Array = []      # [i] -> LanternFace
var _field := Rect2()
var _r := 0.0
var _difficulty := 0

# --- the drag ---
var _held := -1
var _grab := Vector2.ZERO
var _dragged := false

# --- the picture's own clock ---
## [i] -> {"from": Vector2 (where it was drawn), "at": float, "dur": float}:
## a slide the board scripted. A held lantern has none; it is on the finger.
var _mv: Array = []
var _swing := PackedFloat32Array()
var _swing_v := PackedFloat32Array()
var _sag := PackedFloat32Array()
var _sag_v := PackedFloat32Array()
var _hop_at := PackedFloat32Array()
var _lock_at := PackedFloat32Array()
var _lit_at := PackedFloat32Array()
## Rings where a knot came undone: {"at": Vector2 (in the square), "t": float}.
var _puffs: Array = []
## Queued walks home, oldest first: {"node": int, "at": float}.
var _walk: Array = []
var _opened := 0.0
var _solved_at := -1.0
var _last := -1.0

# --- what is drawn ---
var _cord_mesh: ArrayMesh
var _knot_mesh: ArrayMesh
var _knots_px: Array = []
var _knot_alpha := 0.0
## The crossings the last scan found, so the next one can say what went.
var _knot_keys: Dictionary = {}

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "untangle"
func title() -> String: return "Untangle"

func rules() -> String:
	return "Drag the lanterns until no two cords cross. A knot is drawn wherever two of them do. Keep the lanterns apart -- a heap in one corner does not count."

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
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
	_difficulty = clampi(difficulty, 0, R_OF.size() - 1)
	state.setup(rng, difficulty)
	_held = -1
	_dragged = false
	_puffs = []
	_walk = []
	_solved_at = -1.0
	_last = -1.0
	_opened = _now()
	_remember_knots()
	_build_lanterns()
	_layout()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("enter")

# --- the cast ---

func _build_lanterns() -> void:
	for lantern in _lanterns:
		lantern.queue_free()
	_lanterns = []
	_mv = []
	_swing = PackedFloat32Array(); _swing.resize(state.nodes)
	_swing_v = PackedFloat32Array(); _swing_v.resize(state.nodes)
	_hop_at = PackedFloat32Array(); _hop_at.resize(state.nodes)
	_lock_at = PackedFloat32Array(); _lock_at.resize(state.nodes)
	_lit_at = PackedFloat32Array(); _lit_at.resize(state.nodes)
	_sag = PackedFloat32Array(); _sag.resize(state.edges.size())
	_sag_v = PackedFloat32Array(); _sag_v.resize(state.edges.size())
	for i in state.nodes:
		_hop_at[i] = -100.0
		_lock_at[i] = -100.0
		_lit_at[i] = 1.0e9
		_mv.append({"from": Vector2.ZERO, "at": -100.0, "dur": SLIDE_TIME})
		var lantern := LanternFace.new()
		lantern.name = "lantern_%d" % i
		lantern.hue = i
		lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lantern)
		lantern.set_idle(true)
		_lanterns.append(lantern)

# --- layout ---

## The field fills the card rather than sitting square inside it: the
## generator works in a unit square and a crossing survives any affine map,
## so the stretch is the identical puzzle with bigger lanterns and more room
## between them.
func _layout() -> void:
	_field = Rect2(PAD_X, PAD_TOP,
		size.x - 2.0 * PAD_X, size.y - PAD_TOP - PAD_BOTTOM)
	if _field.size.x <= 0.0 or _field.size.y <= 0.0:
		_r = 0.0
		return
	_r = R_OF[_difficulty] * minf(1.0, _field.size.x / R_WIDTH)
	var seat := _r * LanternFace.SEAT
	for lantern in _lanterns:
		lantern.size = Vector2(seat, seat)
		lantern.pivot_offset = lantern.size * 0.5
	_knot_mesh = _build_knot()
	_refresh(_now())

func _to_px(p: Vector2) -> Vector2:
	return _field.position + p * _field.size

func _to_norm(px: Vector2) -> Vector2:
	if _field.size.x <= 0.0 or _field.size.y <= 0.0:
		return Vector2.ZERO
	return (px - _field.position) / _field.size

## Where lantern `i` is drawn, in the square: on the finger while it is held,
## on its way while a scripted slide is in flight, otherwise where it is.
func _disp(i: int, t: float) -> Vector2:
	if i == _held:
		return state.pos[i]
	var m: Dictionary = _mv[i]
	var u := _dec((t - float(m.at)) / float(m.dur))
	if u >= 1.0:
		return state.pos[i]
	return Vector2(m.from).lerp(state.pos[i], _back_out(u))

## The ring lantern `i` hangs from, in this Control's pixels. The win harness
## drags between these, exactly as it does on the island board.
func node_to_local(i: int) -> Vector2:
	return _to_px(state.pos[i])

## The place the generator's untangled drawing put it, likewise.
func planar_to_local(i: int) -> Vector2:
	return _to_px(state.planar[i])

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	# The engine runs this from the moment the node enters the tree; the board
	# only exists once build() has been through.
	if _lanterns.size() != state.nodes:
		return
	var t := _now()
	var dt := 0.0 if _last < 0.0 else minf(0.05, t - _last)
	_last = t
	_fire_walks(t)
	_springs(dt)
	for k in range(_puffs.size() - 1, -1, -1):
		if t - float(_puffs[k].t) >= PUFF_TIME:
			_puffs.remove_at(k)
	if _animating(t):
		_refresh(t)

## The cords' slack and the lanterns' swing, both springs, both still under
## reduce motion.
func _springs(dt: float) -> void:
	for e in _sag.size():
		if Motion.reduce:
			_sag[e] = 0.0
			_sag_v[e] = 0.0
			continue
		_sag_v[e] += (-SAG_K * _sag[e] - SAG_DAMP * _sag_v[e]) * dt
		_sag[e] += _sag_v[e] * dt
		if absf(_sag[e]) < SAG_REST and absf(_sag_v[e]) < SAG_REST_V:
			_sag[e] = 0.0
			_sag_v[e] = 0.0
	for i in _swing.size():
		if Motion.reduce:
			_swing[i] = 0.0
			_swing_v[i] = 0.0
			continue
		_swing_v[i] += (-SWING_K * _swing[i] - SWING_DAMP * _swing_v[i]) * dt
		_swing[i] += _swing_v[i] * dt
		if absf(_swing[i]) < SWING_REST and absf(_swing_v[i]) < SWING_REST_V:
			_swing[i] = 0.0
			_swing_v[i] = 0.0

## Reset's walk home, one lantern per HOME_STEP, so the tangle visibly
## re-forms rather than snapping back.
func _fire_walks(t: float) -> void:
	while not _walk.is_empty() and float(_walk[0].at) <= t:
		var step: Dictionary = _walk.pop_front()
		var i := int(step.node)
		if state.locked[i]:
			continue
		_slide(i, _disp(i, t), SLIDE_TIME, t)
		state.place(i, state.start[i])
		_wake(i, t)
		_after_scan(t)

## True while anything on the board is still moving. Nothing is rebuilt or
## redrawn on a frame this says no to, which is most of them: a board sitting
## still costs its lanterns' blinks and nothing else.
func _animating(t: float) -> bool:
	if _held >= 0 or not _walk.is_empty() or not _puffs.is_empty():
		return true
	if t < _opened + ENTER_DELAY + state.nodes * ENTER_STAGGER + ENTER_TIME:
		return true
	if _solved_at >= 0.0 and t < _solved_at + WIN_WAIT:
		return true
	for i in state.nodes:
		var m: Dictionary = _mv[i]
		if t < float(m.at) + float(m.dur):
			return true
		if t < _hop_at[i] + HOP_TIME or t < _lock_at[i] + LOCK_RING:
			return true
		if _swing[i] != 0.0 or _swing_v[i] != 0.0:
			return true
	for e in _sag.size():
		if _sag[e] != 0.0 or _sag_v[e] != 0.0:
			return true
	return false

func _refresh(t: float) -> void:
	if _r <= 0.0 or _lanterns.size() != state.nodes:
		return
	_place_lanterns(t)
	_cord_mesh = _build_cords(t)
	queue_redraw()

## Every lantern hangs off its ring: the arm turns with the swing and the body
## with it, so a flung lantern lags behind the point the rule is about.
func _place_lanterns(t: float) -> void:
	for i in state.nodes:
		var lantern: LanternFace = _lanterns[i]
		var u := _enter_u(i, t)
		if u <= 0.0:
			lantern.visible = false
			continue
		lantern.visible = true
		lantern.modulate.a = u
		var hang := (LanternFace.ARM + LanternFace.HANG) * _r + _hop(i, t)
		var centre := _ring_px(i, t) + Vector2(0.0, hang).rotated(_swing[i])
		lantern.position = centre - lantern.size * 0.5
		lantern.rotation = _swing[i]
		var grow := 1.0 + (GRAB_SCALE if i == _held else 0.0)
		lantern.scale = (CROWD_SQUASH if state.crowded.has(i) else Vector2.ONE) * grow
		var glow := 0.0 if _solved_at < 0.0 else clampf((t - _lit_at[i]) / LIGHT_TIME, 0.0, 1.0)
		lantern.lit = glow
		if _solved_at >= 0.0 and t >= _lit_at[i]:
			lantern.expression = Face.Expr.JOY
		elif state.crowded.has(i):
			lantern.expression = Face.Expr.STRAIN
		else:
			lantern.expression = Face.Expr.HAPPY

## The ring's own place on screen, entrance drop included: the whole lantern
## falls in, ring and all.
func _ring_px(i: int, t: float) -> Vector2:
	var drop := 0.0
	if not Motion.reduce:
		drop = -ENTER_DROP * (1.0 - _back_out(_enter_u(i, t)))
	return _to_px(_disp(i, t)) + Vector2(0.0, drop)

func _enter_u(i: int, t: float) -> float:
	return _dec((t - _opened - ENTER_DELAY - i * ENTER_STAGGER) / ENTER_TIME)

func _hop(i: int, t: float) -> float:
	if Motion.reduce:
		return 0.0
	var u := (t - _hop_at[i]) / HOP_TIME
	if u < 0.0 or u >= 1.0:
		return 0.0
	return -HOP * sin(PI * u)

# --- the drawing ---

func _draw() -> void:
	if _cord_mesh != null:
		draw_mesh(_cord_mesh, null)
	if _knot_mesh == null or _knot_alpha <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, _knot_alpha)
	var t := _now()
	for k in _knots_px.size():
		var spin := 0.0 if Motion.reduce else sin(t * KNOT_TURN + k * 1.9) * KNOT_SPIN
		draw_mesh(_knot_mesh, null, Transform2D(PI * 0.25 + spin, _knots_px[k]), tint)

## Every cord, every ring and arm and every fading puff, in one mesh. The
## crossings are read off the *drawn* points rather than the logical ones, so
## a cord does not redden before the lantern sliding off it has arrived.
func _build_cords(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var px := PackedVector2Array()
	for i in state.nodes:
		px.append(_ring_px(i, t))
	var shown := _scan_px(px)
	var bad: Dictionary = shown.bad
	_knots_px = shown.pts
	_knot_alpha = clampf((KNOT_FADE - _knots_px.size()) / KNOT_SPAN, 0.0, 1.0)
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		var alpha := minf(_enter_u(edge.x, t), _enter_u(edge.y, t))
		if alpha <= 0.0:
			continue
		var mid := (px[edge.x] + px[edge.y]) * 0.5 + Vector2(0.0, _sag[e] * SAG_DRAW)
		var curve := Face.Builder.bezier2(px[edge.x], mid, px[edge.y])
		curve.append(px[edge.y])
		var caught: bool = bad.has(e)
		var lit_now: bool = _solved_at >= 0.0 and t >= maxf(_lit_at[edge.x], _lit_at[edge.y])
		var light := Pal.CORD
		if caught:
			light = Pal.KNOT
		elif lit_now:
			light = Pal.CORD.lerp(Pal.SUN, LIT_MIX)
		b.stroke(curve, CORD_WIDTH, Color(Pal.KNOT_DEEP if caught else Pal.CORD_DEEP, alpha))
		b.stroke(curve, CORD_LIGHT, Color(light, alpha))
	for i in state.nodes:
		var alpha := _enter_u(i, t)
		if alpha <= 0.0:
			continue
		var ring := px[i]
		var arm := ring + Vector2(0.0, LanternFace.ARM * _r).rotated(_swing[i])
		b.stroke(PackedVector2Array([ring, arm]), ARM_WIDTH * _r, Color(Pal.CORD_DEEP, alpha))
		# The ring is the node the rule is about, so it stays a point; a peg
		# turns it green and puts a hole through it.
		b.disc(ring, RING_R * _r, Color(Pal.GOOD if state.locked[i] else Pal.CORD_DEEP, alpha))
		if state.locked[i]:
			b.disc(ring, RING_PIP * _r, Color(Pal.PARCHMENT, alpha))
			var lock_u := (t - _lock_at[i]) / LOCK_RING
			if lock_u >= 0.0 and lock_u < 1.0:
				var rad := _r * (LOCK_RING_R + LOCK_RING_GROW * lock_u)
				b.stroke(Face.Builder.ring(ring, rad, rad), LOCK_RING_WIDTH,
					Color(Pal.GOOD, 0.7 * (1.0 - lock_u)), true)
	for puff in _puffs:
		var u := (t - float(puff.t)) / PUFF_TIME
		if u < 0.0 or u >= 1.0:
			continue
		var at := _to_px(puff.at)
		var rad := PUFF_FROM + PUFF_GROW * u
		b.stroke(Face.Builder.ring(at, rad, rad), PUFF_WIDTH,
			Color(Pal.KNOT, 0.7 * (1.0 - u)), true)
	if b.verts.is_empty():
		return null
	return b.mesh()

## The knot, drawn once and turned per crossing: a clean patch of parchment so
## the two cords run into the lump rather than under it, then the lump.
func _build_knot() -> ArrayMesh:
	if _r <= 0.0:
		return null
	var b := Face.Builder.new()
	var r := maxf(KNOT_MIN, _r * KNOT_R)
	b.disc(Vector2.ZERO, r * 1.12, Pal.PARCHMENT)
	b.fan(Face.Builder.round_rect(Vector2(-0.74, -0.7) * r, Vector2(1.48, 1.48) * r, 0.52 * r),
		Pal.KNOT_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-0.74, -0.82) * r, Vector2(1.48, 1.48) * r, 0.52 * r),
		Pal.KNOT)
	for band in [[-0.52, -0.42, -0.02, 0.52, -0.44], [-0.34, 0.3, 0.02, 0.34, 0.32]]:
		var curve := Face.Builder.bezier2(Vector2(band[0], band[1]) * r,
			Vector2(0.0, band[2]) * r, Vector2(band[3], band[4]) * r)
		curve.append(Vector2(band[3], band[4]) * r)
		b.stroke(curve, 0.2 * r, Color(Pal.KNOT_DEEP, 0.8))
	return b.mesh()

## The rule, on a set of drawn points: which cords cross and where each pair
## meets. The state runs the same scan on the logical ones.
func _scan_px(px: PackedVector2Array) -> Dictionary:
	var bad := {}
	var pts: Array = []
	for i in state.edges.size():
		for j in range(i + 1, state.edges.size()):
			var e: Vector2i = state.edges[i]
			var f: Vector2i = state.edges[j]
			if e.x == f.x or e.x == f.y or e.y == f.x or e.y == f.y:
				continue
			var at = Geometry2D.segment_intersects_segment(px[e.x], px[e.y], px[f.x], px[f.y])
			if at == null:
				continue
			bad[i] = true
			bad[j] = true
			pts.append(at)
	return {"bad": bad, "pts": pts}

# --- input ---

## Touch and drag only, as every flat board takes them: the viewport hands a
## Control both the mouse event and the emulated touch, and two would fire
## twice.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventScreenDrag and _held >= 0:
		_drag(event.position)

func _press(at: Vector2) -> void:
	if is_done():
		return
	var i := _nearest(at)
	if i < 0:
		return
	var t := _now()
	_held = i
	_dragged = false
	_grab = _to_px(_disp(i, t)) - at
	state.begin(i)
	_hop_at[i] = t
	_wake(i, t)
	_refresh(t)

## The nearest lantern within a thumb of its ring or of its body, which hangs
## below it. Both are grabbable: the point that matters is the ring and the
## thing the player is looking at is the paper.
func _nearest(at: Vector2) -> int:
	if _r <= 0.0:
		return -1
	var t := _now()
	var best := -1
	var closest := _r * GRAB_R
	for i in state.nodes:
		if state.locked[i]:
			continue
		var ring := _to_px(_disp(i, t))
		var body := ring + Vector2(0.0, (LanternFace.ARM + LanternFace.HANG) * _r)
		var d := minf(at.distance_to(ring), at.distance_to(body))
		if d < closest:
			closest = d
			best = i
	return best

func _drag(at: Vector2) -> void:
	var i := _held
	var t := _now()
	var before: Vector2 = state.pos[i]
	var wanted := _to_norm(at + _grab)
	wanted = Vector2(clampf(wanted.x, 0.0, 1.0), clampf(wanted.y, 0.0, 1.0))
	var travel: Vector2 = (wanted - before) * _field.size
	if Motion.reduce:
		if absf(wanted.x - before.x) + absf(wanted.y - before.y) > 0.002:
			_dragged = true
	else:
		_swing_v[i] = clampf(_swing_v[i] - travel.x * SWING_KICK, -SWING_MAX, SWING_MAX)
		for e in state.edges.size():
			var edge: Vector2i = state.edges[e]
			if edge.x == i or edge.y == i:
				_sag_v[e] = minf(SAG_MAX, _sag_v[e] + travel.length() * SAG_KICK)
		if absf(travel.x) > DRAG_SLOP or absf(travel.y) > DRAG_SLOP:
			_dragged = true
	state.drag_to(i, wanted)
	_after_scan(t)

## A drag that moved nothing is not a move and is not undoable.
func _release() -> void:
	if _held < 0:
		return
	var i := _held
	var t := _now()
	_held = -1
	if _dragged:
		_hop_at[i] = t
		_after_scan(t)
		note_move()
	else:
		state.forget()
		_after_scan(t)
	_refresh(t)

# --- what a scan changed ---

func _remember_knots() -> void:
	_knot_keys = {}
	for knot in state.knots:
		_knot_keys[knot.key] = knot.at

## Everything a change to the positions drives: the rings where knots came
## undone, the sprout's line and the redraw.
func _after_scan(t: float) -> void:
	var was: Dictionary = _knot_keys
	_remember_knots()
	var gone := 0
	for key in was:
		if _knot_keys.has(key):
			continue
		gone += 1
		# Under a rash of them a puff each is noise; they only show once the
		# knots themselves do.
		if not Motion.reduce and state.knots.size() < int(KNOT_FADE):
			_puffs.append({"at": was[key], "t": t})
	_speak(gone)
	_refresh(t)

func _wake(i: int, t: float) -> void:
	_hop_at[i] = t
	if Motion.reduce:
		return
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		if edge.x == i or edge.y == i:
			_sag_v[e] = minf(SAG_MAX, _sag_v[e] + WAKE_KICK)

func _slide(i: int, from: Vector2, dur: float, t: float) -> void:
	_mv[i] = {"from": from, "at": t, "dur": dur}

# --- the sprout's line ---

func _speak(gone: int) -> void:
	if is_done():
		return
	var left: int = state.crossings()
	if left == 0 and not state.crowded.is_empty():
		_say("No cords cross, but give them room. A pile is not a solution.", Face.Expr.STRAIN)
		return
	if gone <= 0 or left <= 0:
		return
	if left == 1:
		_say("One knot left. Nearly there.", Face.Expr.HAPPY)
		return
	_say("%s %d still to go." % [
		"One knot gone." if gone == 1 else "%d knots gone." % gone, left], Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal; nothing else on this screen has a focus.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _tip_mood == Face.Expr.JOY:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Slides the last dragged lantern back to where it was picked up. Counts no
## move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var t := _now()
	var i := int(state.history[-1].node)
	var from := _disp(i, t)
	state.undo()
	_slide(i, from, UNDO_TIME, t)
	_wake(i, t)
	_after_scan(t)
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Hangs one lantern on its peg: it walks to the place the generator's own
## untangled drawing put it, a green ring pulses out, and it can never be
## dragged again. Counts no move.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var t := _now()
	var before := PackedVector2Array()
	for i in state.nodes:
		before.append(_disp(i, t))
	var pick: int = state.hint()
	if pick < 0:
		return false
	_slide(pick, before[pick], HINT_TIME, t)
	_lock_at[pick] = t
	_wake(pick, t)
	hints_used += 1
	fx.sparkle(_to_px(state.planar[pick]), Pal.GOOD)
	fx.cue("hint")
	_after_scan(t)
	_say("That one is on its peg now. It will not move again.", Face.Expr.HAPPY)
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	var t := _now()
	_held = -1
	_walk = []
	var walking: Array[int] = state.reset()
	for k in walking.size():
		_walk.append({"node": walking[k], "at": t + k * HOME_STEP})
	moves = 0
	_running = true
	if not walking.is_empty():
		_say("Back to the tangle you were given.", Face.Expr.HAPPY)
	fx.cue("reset")
	_after_scan(t)

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the drawing the
## player made stays on the card under it, lit.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "Not a knot left."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The light runs out from one lantern along the cords, hop by hop, so the
## board finishes by proving it is one connected string -- the one thing about
## the graph the player never sees while playing.
func _on_solved() -> void:
	var t := _now()
	_held = -1
	_walk = []
	_solved_at = t
	_tip_timer.stop()
	var adj := {}
	for edge in state.edges:
		if not adj.has(edge.x):
			adj[edge.x] = []
		if not adj.has(edge.y):
			adj[edge.y] = []
		adj[edge.x].append(edge.y)
		adj[edge.y].append(edge.x)
	var seen := {0: true}
	var ring: Array = [0]
	var depth := 0
	while not ring.is_empty():
		for i in ring:
			_lit_at[i] = t if Motion.reduce else t + LIGHT_DELAY + depth * LIGHT_STEP
			_hop_at[i] = _lit_at[i]
		var next: Array = []
		for i in ring:
			for q in adj.get(i, []):
				if not seen.has(q):
					seen[q] = true
					next.append(q)
		ring = next
		depth += 1
	for i in state.nodes:
		if _lit_at[i] > 1.0e8:
			_lit_at[i] = t
		_spark_at(i)
	_say("Not a knot left. The lights go on.", Face.Expr.JOY)
	fx.cue("solved")
	_refresh(t)

## A spark as lantern `i` lights. The two pools are used in turn: a run of
## fourteen staggered by an eighth of a second would otherwise recycle one
## pool fast enough to cut each burst in half.
func _spark_at(i: int) -> void:
	if Motion.reduce:
		return
	var wait := maxf(0.0, _lit_at[i] - _now())
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var at := _to_px(state.pos[i])
		if i % 2 == 0:
			fx.sparkle(at, Pal.SUN)
		else:
			fx.puff(at, Pal.SUN, 4))

# --- odds and ends ---

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 0 to 1, and 1 at once under reduce-motion.
func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## The overshoot the whole family's pops use, as a curve rather than a tween,
## because these are drawn rather than tweened.
func _back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	const C := 1.70158
	return 1.0 + (C + 1.0) * pow(u - 1.0, 3.0) + C * pow(u - 1.0, 2.0)
