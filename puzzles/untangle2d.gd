extends "res://core/puzzle_base.gd"

## Untangle as a flat board: paper lanterns hung on cords over the host's
## parchment card, dragged until no two cords cross. The rules live in
## puzzles/untangle_state.gd, which this only draws.
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
## How it is drawn. Every shadow, every cord, every ring and arm go into one
## ArrayMesh through Face.Builder, rebuilt only on the frames something is
## actually moving, so a hard board of twenty-four cords costs one draw command
## rather than fifty strokes -- gl_compatibility pays per command (see
## CLAUDE.md). The knots are one cached mesh drawn once per crossing with its
## own turn, the scenery is one mesh behind everything, and the lanterns are
## the only nodes: fourteen Face subclasses, each one cached mesh a layer.
##
## How it moves, in two hands. What the *point* does -- the drag, the two
## springs, a scripted walk to a peg or home -- is integrated in _process
## against a clock, never tweened, because the picture of a lantern moves
## under a finger that is still moving it and a tween would be fighting the
## drag. What the *paper* does -- pop in, lift under the finger, hop on a
## landing, the solve wave -- is the flat boards' vocabulary in core/motion.gd
## (docs/art/flat-motion.md), and it can be, because every lantern stands in
## a slot the board owns: the slot takes the ring's place and the swing, and
## the face moves inside it where the recipes tween it without the per-frame
## placement writing over them. The springs are this board's signature; the
## rest is the family's.
## Spec: docs/superpowers/specs/2026-09-18-untangle-flat-design.md, sections 2
## to 7 and the amendment at its end; the mock it was ported from is
## docs/brainstorm/concepts.html#untangle.

const State = preload("res://puzzles/untangle_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

# --- the field ---
## The card's insets. The bottom one is the deep one, because the ring is the
## node and the lantern hangs below it.
const PAD_X := 104.0
const PAD_TOP := 84.0
const PAD_BOTTOM := 176.0
## A lantern's radius per difficulty, and the field width they were drawn at;
## a narrower card takes them down with it.
## Insane's provisional band, replaced by the bank in batch 2.
const R_OF := [54.0, 48.0, 42.0, 38.0]
const R_WIDTH := 780.0

# --- the cord ---
const CORD_WIDTH := 11.0
const CORD_LIGHT := 6.0
## The drawn sag is twice the spring's, which is what the mock's curve took.
const SAG_DRAW := 2.0
## How far a lit cord goes toward the sun behind the light.
const LIT_MIX := 0.55
## The rope's twist: a groove across the cord every TWIST_STEP along it, at
## forty-five degrees, in the cord's own shade. The grooves are what make a
## cord read as rope rather than as a ruled line.
const TWIST_STEP := 15.0
const TWIST_WIDTH := 2.2
const TWIST_ALPHA := 0.5
## The shadow a cord throws on the card, the lanterns' own light: down and a
## little right, in R, faint.
const CORD_SHADOW := Vector2(0.06, 0.2)
const CORD_SHADOW_ALPHA := 0.07
## A cord takes the crossing colour, and gives it back, over this rather
## than on the frame the lines meet.
const HEAT_TIME := 0.14
## While a lantern is in the hand its own cords go this far toward paper, so
## the player can see which lines they are moving.
const HELD_MIX := 0.3
## The light's front as it runs along a cord at the win: a bead of lit paper
## and its halo, in cord widths.
const BEAD_R := 0.8
const BEAD_GLOW := 2.6

# --- the lantern, in R ---
const RING_R := 0.16
const RING_PIP := 0.06
## The bead's sheen, up and left on the ring, in ring radii.
const RING_SHINE := 0.42
## The ring swells this much under the finger, with a warm glow round it
## GRIP_GLOW rings wide: the point being moved is the point the rule is about.
const GRIP_SWELL := 0.45
const GRIP_GLOW := 2.4
const GRIP_ALPHA := 0.3
const ARM_WIDTH := 0.09
## A tap grabs the nearest lantern within this of its ring or its body.
const GRAB_R := 1.9
## A crowded lantern squashes against its neighbour.
const CROWD_SQUASH := Vector2(1.1, 0.9)

# --- the shadow, in R ---
## The shadow a lantern throws on the parchment behind it: the family's soft
## disc (Scenery.soft_disc), a little below the paper, and further below,
## wider and fainter while the lantern is lifted toward the finger -- which is
## what makes the lift read as a lift and a hop as a hop, since the paper
## moves and the shadow stays.
const SHADOW_AT := Vector2(0.1, 1.2)
const SHADOW_RX := 0.9
const SHADOW_RY := 0.28
const SHADOW_NEAR := 0.16
const SHADOW_FAR := 0.08
const SHADOW_LIFT := Vector2(0.14, 0.34)
const SHADOW_SPREAD := 0.18

# --- the knot ---
const KNOT_R := 0.62
const KNOT_MIN := 22.0
## Forty markers is a rash, not a signal: the knots fade in as the board comes
## down past KNOT_FADE crossings and are at full strength KNOT_SPAN below it.
const KNOT_FADE := 16.0
const KNOT_SPAN := 4.0
const KNOT_SPIN := 0.14
const KNOT_TURN := 1.7

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
## The twang: a cord that comes free of its last crossing is plucked, and
## rings sideways on a stiff spring for about half a second. It is sub-stepped
## at PLUCK_HZ because a spring this stiff is not stable at a frame's step.
const PLUCK_K := 2600.0
const PLUCK_DAMP := 9.0
const PLUCK_KICK := 520.0
const PLUCK_REST := 0.08
const PLUCK_REST_V := 2.0
const PLUCK_HZ := 240.0
## How far a drag has to travel before it counts as a move, in field pixels.
const DRAG_SLOP := 0.4

# --- motion: what is this board's own ---
## The string is hung Motion.ENTER_DELAY after the board opens, behind the
## chrome, like every board's pieces.
## A scripted walk -- a hint's to its peg, an undo's back, reset's home --
## takes this long, with the family's overshoot drawn as a curve.
const SLIDE_TIME := 0.3
## Reset walks the lanterns home one per this, so the tangle visibly
## re-forms rather than snapping back.
const HOME_STEP := 0.04
## The light runs out from one lantern along the cords: one hop of the graph
## per LIGHT_STEP (a hop is a row, not a cell, so it is paced like one), and a
## lantern warms over LIGHT_TIME as it arrives.
const LIGHT_STEP := 0.12
const LIGHT_TIME := 0.4
## How long the host waits before the win screen: the light has to reach the
## far end of the string first.
const WIN_WAIT := 2.0

# --- the scenery ---
## Two clouds in the card's top corners and tufts along its bottom edge,
## where the lanterns never quite reach: the lowest ring hangs its paper to
## about 130 above the card's foot, and the tufts stand in the last 30.
const CLOUD_R := 34.0
const CLOUD_X := 118.0
const CLOUD_Y := 58.0
const TUFT_H := 30.0
const TUFT_INSET := 24.0
const TUFT_X: Array[float] = [0.09, 0.27, 0.5, 0.71, 0.9]

const HINTS := State.HINTS
const TIP_CYCLE := 9.0
## The three lines that teach the board, cycled while there is nothing better
## to say.
const TIPS := [
	"UT_TIP_DRAG",
	"UT_TIP_KNOT",
	"UT_TIP_APART",
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
var _scenery: Control
var _slots: Array[Control] = []   # [i] -> the ring's place and the swing
var _lanterns: Array = []          # [i] -> LanternFace, hung inside its slot
var _scale_tw: Array = []          # [i] -> the pop in, the lift or the settle
var _hop_tw: Array = []            # [i] -> the hop
## Bumped on every rebuild; a pending callback from the last board checks it.
var _gen := 0
var _field := Rect2()
var _r := 0.0
var _difficulty := 0

# --- the drag ---
var _held := -1
var _grab := Vector2.ZERO
var _dragged := false

# --- the point's own clock ---
## [i] -> {"from": Vector2 (where it was drawn), "at": float}: a walk the
## board scripted. A held lantern has none; it is on the finger.
var _mv: Array = []
var _swing := PackedFloat32Array()
var _swing_v := PackedFloat32Array()
var _sag := PackedFloat32Array()
var _sag_v := PackedFloat32Array()
var _lit_at := PackedFloat32Array()
## [e] -> the cord's crossing colour, 0 to 1, easing toward _bad_drawn.
var _heat := PackedFloat32Array()
## [e] -> the sideways twang, in pixels, and its velocity.
var _pluck := PackedFloat32Array()
var _pluck_v := PackedFloat32Array()
## [i] -> how far the ring is in the hand, 0 to 1.
var _grip := PackedFloat32Array()
## The cords the last drawn scan found crossed.
var _bad_drawn: Dictionary = {}
## Queued walks home, oldest first: {"node": int, "at": float}.
var _walk: Array = []
var _opened := 0.0
var _solved_at := -1.0
var _last := -1.0

# --- what is drawn ---
var _cord_mesh: ArrayMesh
## The mesh the last _draw handed over, kept until the next one replaces it:
## a canvas command holds a mesh by RID, and a frame rendered before the
## queued redraw is flushed would otherwise draw a freed one (see CLAUDE.md).
var _shown: ArrayMesh
var _knot_mesh: ArrayMesh
var _knots_px: Array = []
var _knot_alpha := 0.0
## The crossings the last scan found, so the next one can say what went.
var _knot_keys: Dictionary = {}
## The knots that rang during this hold: a knot a fast drag flickers rings
## once, not once a frame.
var _rang: Dictionary = {}
## The lanterns the last scan found piled up, so a change can be settled.
var _crowded_was: Dictionary = {}

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "untangle"
func title() -> String: return "Untangle"

func rules() -> String:
	return tr("UT_RULES")

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	# The scenery draws behind this Control's own drawing, so the clouds and
	# the grass sit under the cords and not over them.
	_scenery = Scenery.new()
	_scenery.name = "Scenery"
	_scenery.show_behind_parent = true
	add_child(_scenery)
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
	_stop_all()
	_held = -1
	_dragged = false
	_walk = []
	_solved_at = -1.0
	_last = -1.0
	_opened = _now()
	_remember_knots()
	_crowded_was = state.crowded.duplicate()
	_build_lanterns()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()
	fx.cue("enter")

# --- the cast ---

func _build_lanterns() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots = []
	_lanterns = []
	_mv = []
	_scale_tw = []
	_hop_tw = []
	_swing = PackedFloat32Array(); _swing.resize(state.nodes)
	_swing_v = PackedFloat32Array(); _swing_v.resize(state.nodes)
	_lit_at = PackedFloat32Array(); _lit_at.resize(state.nodes)
	_sag = PackedFloat32Array(); _sag.resize(state.edges.size())
	_sag_v = PackedFloat32Array(); _sag_v.resize(state.edges.size())
	_heat = PackedFloat32Array(); _heat.resize(state.edges.size())
	_pluck = PackedFloat32Array(); _pluck.resize(state.edges.size())
	_pluck_v = PackedFloat32Array(); _pluck_v.resize(state.edges.size())
	_grip = PackedFloat32Array(); _grip.resize(state.nodes)
	# The opening tangle is already red when the string is hung: the heat
	# starts where the state's own scan says, not easing in from rope.
	_bad_drawn = {}
	for knot in state.knots:
		for part in String(knot.key).split("_"):
			_bad_drawn[int(part)] = true
	for e in _bad_drawn:
		_heat[e] = 1.0
	for i in state.nodes:
		_lit_at[i] = 1.0e9
		_mv.append({"from": Vector2.ZERO, "at": -100.0})
		_scale_tw.append(null)
		_hop_tw.append(null)
		var slot := Control.new()
		slot.name = "slot_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var lantern := LanternFace.new()
		lantern.name = "lantern_%d" % i
		lantern.hue = i
		lantern.casts = false
		lantern.pleats = true
		lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Nothing until the string is hung; _enter pops each one in.
		lantern.scale = Vector2.ZERO
		slot.add_child(lantern)
		lantern.set_idle(true)
		_slots.append(slot)
		_lanterns.append(lantern)

## The entrance: the rings pop and the cords fade in along the family's
## stagger (drawn, in _build_cords), and each lantern pops in on its ring a
## beat later with the squash -- the string is hung first, then the paper.
func _enter() -> void:
	for i in state.nodes:
		Motion.stop(_scale_tw[i])
		_scale_tw[i] = Motion.pop_in(_lanterns[i], Motion.POP_IN,
			Motion.ENTER_DELAY + Motion.stagger(i, Motion.ENTER_STAGGER) + Motion.ENTER_FACE_LAG, _rest_scale(i))

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
	for i in state.nodes:
		var lantern: Control = _lanterns[i]
		lantern.size = Vector2(seat, seat)
		lantern.pivot_offset = lantern.size * 0.5
		# A mover owns its place until it lands: a hop mid-flight is left
		# where it is, and puts itself back here when it comes down.
		if not Motion.running(_hop_tw[i]):
			lantern.position = _hang_rest(i)
	_knot_mesh = _build_knot()
	_dress()
	_refresh(_now())

## The scenery's anchors, in this Control's pixels.
func _dress() -> void:
	_scenery.size = size
	var clouds: Array[Vector3] = [
		Vector3(CLOUD_X, CLOUD_Y, CLOUD_R),
		Vector3(size.x - CLOUD_X, CLOUD_Y * 1.15, CLOUD_R * 0.85),
	]
	var tufts: Array[Vector3] = []
	for k in TUFT_X.size():
		tufts.append(Vector3(size.x * TUFT_X[k], size.y - TUFT_INSET, TUFT_H * (1.0 if k % 2 == 0 else 0.8)))
	_scenery.clouds = clouds
	_scenery.tufts = tufts
	_scenery.rebuild()

func _to_px(p: Vector2) -> Vector2:
	return _field.position + p * _field.size

func _to_norm(px: Vector2) -> Vector2:
	if _field.size.x <= 0.0 or _field.size.y <= 0.0:
		return Vector2.ZERO
	return (px - _field.position) / _field.size

## Where lantern `i` is drawn, in the square: on the finger while it is held,
## on its way while a scripted walk is in flight, otherwise where it is.
func _disp(i: int, t: float) -> Vector2:
	if i == _held:
		return state.pos[i]
	var m: Dictionary = _mv[i]
	var u := _dec((t - float(m.at)) / SLIDE_TIME)
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

## Where the paper rests inside its slot: its centre an arm and a hang below
## the ring. The hop tweens it from here and back.
func _hang_rest(i: int) -> Vector2:
	var lantern: Control = _lanterns[i]
	return Vector2(0.0, (LanternFace.ARM + LanternFace.HANG) * _r) - lantern.size * 0.5

## The scale a lantern rests at: squashed against a neighbour when piled up,
## otherwise one. The lift and the pop ride on it.
func _rest_scale(i: int) -> Vector2:
	return CROWD_SQUASH if state.crowded.has(i) else Vector2.ONE

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
	if _animating(t):
		_refresh(t)
	elif _knot_alpha > 0.0 and not Motion.reduce:
		# The knots turn gently while the board rests: a redraw with the
		# mesh it already has, no rebuild.
		queue_redraw()

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
	for e in _heat.size():
		var hot := 1.0 if _bad_drawn.has(e) else 0.0
		_heat[e] = hot if Motion.reduce else move_toward(_heat[e], hot, dt / HEAT_TIME)
	for i in _grip.size():
		var held := 1.0 if i == _held else 0.0
		if Motion.reduce:
			_grip[i] = held
		else:
			_grip[i] = move_toward(_grip[i], held, dt / (Motion.LIFT_TIME if held > 0.0 else Motion.RELEASE_TIME))
	_twang(dt)

## The plucked cords, on their stiff spring, sub-stepped. A cord at rest is
## skipped, so a settled board does no work here.
func _twang(dt: float) -> void:
	var steps := maxi(1, ceili(dt * PLUCK_HZ))
	var h := dt / steps
	for e in _pluck.size():
		if _pluck[e] == 0.0 and _pluck_v[e] == 0.0:
			continue
		if Motion.reduce:
			_pluck[e] = 0.0
			_pluck_v[e] = 0.0
			continue
		for k in steps:
			_pluck_v[e] += (-PLUCK_K * _pluck[e] - PLUCK_DAMP * _pluck_v[e]) * h
			_pluck[e] += _pluck_v[e] * h
		if absf(_pluck[e]) < PLUCK_REST and absf(_pluck_v[e]) < PLUCK_REST_V:
			_pluck[e] = 0.0
			_pluck_v[e] = 0.0

## Reset's walk home, one lantern per HOME_STEP, so the tangle visibly
## re-forms rather than snapping back.
func _fire_walks(t: float) -> void:
	while not _walk.is_empty() and float(_walk[0].at) <= t:
		var step: Dictionary = _walk.pop_front()
		var i := int(step.node)
		if state.locked[i]:
			continue
		_slide(i, _disp(i, t), t)
		state.place(i, state.start[i])
		_after_scan(t)

## True while anything on the board is still moving. Nothing is rebuilt or
## redrawn on a frame this says no to, which is most of them: a board sitting
## still costs its lanterns' blinks and nothing else.
func _animating(t: float) -> bool:
	if _held >= 0 or not _walk.is_empty():
		return true
	if t < _opened + Motion.ENTER_DELAY + Motion.stagger(state.nodes - 1, Motion.ENTER_STAGGER) \
			+ Motion.ENTER_FACE_LAG + Motion.POP_IN:
		return true
	if _solved_at >= 0.0 and t < _solved_at + WIN_WAIT:
		return true
	for i in state.nodes:
		var m: Dictionary = _mv[i]
		if t < float(m.at) + SLIDE_TIME:
			return true
		# The shadow follows the paper, so the mesh keeps up with its tweens.
		if Motion.running(_scale_tw[i]) or Motion.running(_hop_tw[i]):
			return true
		if _swing[i] != 0.0 or _swing_v[i] != 0.0:
			return true
	for e in _sag.size():
		if _sag[e] != 0.0 or _sag_v[e] != 0.0:
			return true
		if _pluck[e] != 0.0 or _pluck_v[e] != 0.0:
			return true
		if _heat[e] != (1.0 if _bad_drawn.has(e) else 0.0):
			return true
	for i in _grip.size():
		if _grip[i] != (1.0 if i == _held else 0.0):
			return true
	return false

func _refresh(t: float) -> void:
	if _r <= 0.0 or _lanterns.size() != state.nodes:
		return
	_place_lanterns(t)
	_cord_mesh = _build_cords(t)
	queue_redraw()

## Every lantern hangs off its ring: the slot stands on the ring and turns
## with the swing, and the paper inside it turns with the slot, so a flung
## lantern lags behind the point the rule is about. A face is written only
## when its look changes -- a written face redraws.
func _place_lanterns(t: float) -> void:
	for i in state.nodes:
		var slot: Control = _slots[i]
		var lantern: LanternFace = _lanterns[i]
		slot.position = _ring_px(i, t)
		slot.rotation = _swing[i]
		var glow := 0.0
		if _solved_at >= 0.0:
			glow = roundf(clampf((t - _lit_at[i]) / LIGHT_TIME, 0.0, 1.0) * 4.0) / 4.0
		if lantern.lit != glow:
			lantern.lit = glow
		var expr := Face.Expr.HAPPY
		if _solved_at >= 0.0 and t >= _lit_at[i]:
			expr = Face.Expr.JOY
		elif state.crowded.has(i):
			expr = Face.Expr.STRAIN
		if lantern.expression != expr:
			lantern.expression = expr

## The ring's own place on screen.
func _ring_px(i: int, t: float) -> Vector2:
	return _to_px(_disp(i, t))

## How far in lantern `i`'s ring and cords are, 0 to 1, along the family's
## entrance: one per ENTER_STAGGER, each over ENTER_POP.
func _enter_u(i: int, t: float) -> float:
	return _dec((t - _opened - Motion.ENTER_DELAY - Motion.stagger(i, Motion.ENTER_STAGGER)) / Motion.ENTER_POP)

## A landing: the paper hops on its cord.
func _hop(i: int, height := Motion.HOP, time := Motion.HOP_TIME, delay := 0.0) -> void:
	Motion.stop(_hop_tw[i])
	var lantern: Control = _lanterns[i]
	var rest := _hang_rest(i)
	lantern.position = rest
	_hop_tw[i] = Motion.hop(lantern, height, time, delay, rest.y)

## The paper's scale, settled to where it now belongs: lifted while it is in
## the hand, squashed while it is piled up, one otherwise. The lift is the
## family's press for a dragged thing.
func _settle_scale(i: int) -> void:
	Motion.stop(_scale_tw[i])
	_scale_tw[i] = Motion.lift(_lanterns[i], i == _held, _rest_scale(i))

# --- the drawing ---

func _draw() -> void:
	if _cord_mesh != null:
		draw_mesh(_cord_mesh, null)
	_shown = _cord_mesh
	if _knot_mesh == null or _knot_alpha <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, _knot_alpha)
	var t := _now()
	for k in _knots_px.size():
		var spin := 0.0 if Motion.reduce else sin(t * KNOT_TURN + k * 1.9) * KNOT_SPIN
		draw_mesh(_knot_mesh, null, Transform2D(PI * 0.25 + spin, _knots_px[k]), tint)

## Every shadow, every cord, every ring and arm, in one mesh, in that order,
## so the shadows lie under the cords. The crossings are read off the *drawn*
## points rather than the logical ones, so a cord does not redden before the
## lantern sliding off it has arrived.
func _build_cords(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var px := PackedVector2Array()
	for i in state.nodes:
		px.append(_ring_px(i, t))
	var shown := _scan_px(px)
	var bad: Dictionary = shown.bad
	# A cord that has just come free of its last crossing twangs.
	if not Motion.reduce:
		for e in _bad_drawn:
			if not bad.has(e) and absf(_pluck[e]) < 1.0:
				_pluck_v[e] = PLUCK_KICK * (1.0 if e % 2 == 0 else -1.0)
	_bad_drawn = bad
	_knots_px = shown.pts
	_knot_alpha = clampf((KNOT_FADE - _knots_px.size()) / KNOT_SPAN, 0.0, 1.0)
	for i in state.nodes:
		_shadow(b, i, px[i])
	var curves: Array = []
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		var run := px[edge.y] - px[edge.x]
		var side := run.orthogonal().normalized() if run.length_squared() > 1.0 else Vector2.ZERO
		var mid := (px[edge.x] + px[edge.y]) * 0.5 \
			+ (Vector2(0.0, _sag[e]) + side * _pluck[e]) * SAG_DRAW
		var curve := Face.Builder.bezier2(px[edge.x], mid, px[edge.y])
		curve.append(px[edge.y])
		curves.append(curve)
		var alpha := minf(_enter_u(edge.x, t), _enter_u(edge.y, t))
		if alpha > 0.0:
			var off := CORD_SHADOW * _r
			var dark := PackedVector2Array()
			for p in curve:
				dark.append(p + off)
			b.stroke(dark, CORD_WIDTH, Color(Pal.TEXT, CORD_SHADOW_ALPHA * alpha))
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		var alpha := minf(_enter_u(edge.x, t), _enter_u(edge.y, t))
		if alpha <= 0.0:
			continue
		var curve: PackedVector2Array = curves[e]
		var heat := _heat[e]
		var deep := Pal.CORD_DEEP.lerp(Pal.KNOT_DEEP, heat)
		var light := Pal.CORD.lerp(Pal.KNOT, heat)
		var held := maxf(_grip[edge.x], _grip[edge.y])
		if held > 0.0:
			light = light.lerp(Pal.PAPER, HELD_MIX * held)
		b.stroke(curve, CORD_WIDTH, Color(deep, alpha))
		b.stroke(curve, CORD_LIGHT, Color(light, alpha))
		var cum := _lengths(curve)
		if _solved_at >= 0.0:
			_light_run(b, curve, cum, e, t)
		_twists(b, curve, cum, Color(deep, TWIST_ALPHA * alpha))
	for i in state.nodes:
		var u := _enter_u(i, t)
		if u <= 0.0:
			continue
		# The ring and its arm pop in with the family's overshoot, drawn.
		var grown := _back_out(u)
		var ring := px[i]
		var arm := ring + Vector2(0.0, LanternFace.ARM * _r * grown).rotated(_swing[i])
		b.stroke(PackedVector2Array([ring, arm]), ARM_WIDTH * _r * grown, Pal.CORD_DEEP)
		# The ring is the node the rule is about, so it stays a point: a bead
		# with a sheen, swelling under the finger; a peg turns it green and
		# puts a hole through it.
		var grip := _grip[i]
		var rr := RING_R * _r * grown * (1.0 + GRIP_SWELL * _back_out(grip))
		if grip > 0.0:
			Scenery.soft_disc(b, ring, rr * GRIP_GLOW, rr * GRIP_GLOW, Color(Pal.SUN, GRIP_ALPHA * grip))
		if state.locked[i]:
			b.disc(ring, rr, Pal.GOOD)
			b.disc(ring, RING_PIP * _r * grown, Pal.PARCHMENT)
		else:
			b.disc(ring, rr, Pal.CORD_DEEP)
			b.disc(ring + Vector2(-0.3, -0.3) * rr, rr * RING_SHINE, Pal.CORD.lerp(Pal.PAPER, 0.45))
	if b.verts.is_empty():
		return null
	return b.mesh()

## The win's light along cord `e`: it leaves each end as that end's lantern
## lights and runs the cord's length in one LIGHT_STEP, so on a tree edge it
## arrives at the far lantern exactly as that one lights, and on a cord
## between two lanterns lit together the two fronts meet in the middle. The
## lit part is drawn over the cord's light strip, and each moving front
## carries a bead of lit paper with a halo.
func _light_run(b: Face.Builder, curve: PackedVector2Array, cum: PackedFloat32Array, e: int, t: float) -> void:
	var edge: Vector2i = state.edges[e]
	var total := cum[cum.size() - 1]
	if total <= 0.0:
		return
	var fa := _dec((t - _lit_at[edge.x]) / LIGHT_STEP)
	var fb := _dec((t - _lit_at[edge.y]) / LIGHT_STEP)
	if t < _lit_at[edge.x]:
		fa = 0.0
	if t < _lit_at[edge.y]:
		fb = 0.0
	var lit := Pal.CORD.lerp(Pal.SUN, LIT_MIX)
	if fa + fb >= 1.0:
		b.stroke(curve, CORD_LIGHT, lit)
		return
	if fa > 0.0:
		b.stroke(_sub(curve, cum, 0.0, fa * total), CORD_LIGHT, lit)
		_bead(b, _at(curve, cum, fa * total))
	if fb > 0.0:
		b.stroke(_sub(curve, cum, (1.0 - fb) * total, total), CORD_LIGHT, lit)
		_bead(b, _at(curve, cum, (1.0 - fb) * total))

func _bead(b: Face.Builder, at: Vector2) -> void:
	var r := CORD_WIDTH * BEAD_R
	Scenery.soft_disc(b, at, r * BEAD_GLOW, r * BEAD_GLOW, Color(Pal.SUN, 0.45))
	b.disc(at, r, Pal.LANTERN_LIT)

## The rope's grooves, one every TWIST_STEP along the curve, each a short
## stroke across the cord at forty-five degrees to it.
func _twists(b: Face.Builder, curve: PackedVector2Array, cum: PackedFloat32Array, colour: Color) -> void:
	var total := cum[cum.size() - 1]
	var half := CORD_WIDTH * 0.5
	var clear := Color(colour, 0.0)
	var s := TWIST_STEP * 0.5
	var k := 1
	while s < total:
		while k < cum.size() - 1 and cum[k] < s:
			k += 1
		var p0 := curve[k - 1]
		var p1 := curve[k]
		var seg := cum[k] - cum[k - 1]
		var p := p0.lerp(p1, (s - cum[k - 1]) / seg if seg > 0.0 else 0.0)
		var tn := (p1 - p0).normalized()
		var d := (tn + tn.orthogonal()) * 0.5 * half
		# The stroke's own four-across quad, written out: a groove is two
		# points, and this runs a thousand times a frame on a hard board.
		var nrm := d.normalized().orthogonal()
		var w := nrm * (TWIST_WIDTH * 0.5)
		var f := nrm * (TWIST_WIDTH * 0.5 + Face.FEATHER)
		var base := b.verts.size()
		for end in [p - d, p + d]:
			b.verts.append(end - f); b.cols.append(clear)
			b.verts.append(end - w); b.cols.append(colour)
			b.verts.append(end + w); b.cols.append(colour)
			b.verts.append(end + f); b.cols.append(clear)
		for k2 in 3:
			b.idx.append_array([base + k2, base + 4 + k2, base + 5 + k2,
				base + k2, base + 5 + k2, base + k2 + 1])
		s += TWIST_STEP

## The running length along a polyline, from its first point.
func _lengths(curve: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array()
	cum.resize(curve.size())
	for i in range(1, curve.size()):
		cum[i] = cum[i - 1] + curve[i - 1].distance_to(curve[i])
	return cum

## The point `s` along a polyline.
func _at(curve: PackedVector2Array, cum: PackedFloat32Array, s: float) -> Vector2:
	for i in range(1, curve.size()):
		if cum[i] >= s:
			var seg := cum[i] - cum[i - 1]
			return curve[i - 1].lerp(curve[i], (s - cum[i - 1]) / seg if seg > 0.0 else 0.0)
	return curve[curve.size() - 1]

## The part of a polyline from `s0` to `s1` along it.
func _sub(curve: PackedVector2Array, cum: PackedFloat32Array, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array([_at(curve, cum, s0)])
	for i in curve.size():
		if cum[i] > s0 and cum[i] < s1:
			out.append(curve[i])
	out.append(_at(curve, cum, s1))
	return out

## Lantern `i`'s shadow on the parchment behind it. It arrives with the paper
## (read off the paper's own scale, which the pop-in drives from nothing) and
## parts from it while it is lifted: further below, wider and fainter, so the
## lift reads as height. Anchored at the paper's rest, so a hop leaves it
## behind.
func _shadow(b: Face.Builder, i: int, ring: Vector2) -> void:
	var lantern: Control = _lanterns[i]
	var rest := _rest_scale(i)
	# Read off the height, not the width: the pop-in's squash is wider than
	# tall for a beat, and a shadow that parted for it would call that a lift.
	var grown := lantern.scale.y / rest.y
	var seen := clampf(grown, 0.0, 1.0)
	if seen <= 0.0:
		return
	var lift := clampf((grown - 1.0) / (Motion.LIFT_SCALE - 1.0), 0.0, 1.0)
	var body := ring + Vector2(0.0, (LanternFace.ARM + LanternFace.HANG) * _r).rotated(_swing[i])
	var at := body + (SHADOW_AT + SHADOW_LIFT * lift) * _r
	var spread := 1.0 + SHADOW_SPREAD * lift
	Scenery.soft_disc(b, at, SHADOW_RX * _r * spread * rest.x, SHADOW_RY * _r * spread,
		Color(Pal.TEXT, lerpf(SHADOW_NEAR, SHADOW_FAR, lift) * seen))

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
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _held >= 0:
		_drag(event.position)

## The pick-up: the paper lifts toward the finger and its cords wake.
func _press(at: Vector2) -> void:
	if is_done():
		return
	var i := _nearest(at)
	if i < 0:
		return
	var t := _now()
	_held = i
	_dragged = false
	_rang = {}
	_grab = _to_px(_disp(i, t)) - at
	state.begin(i)
	_settle_scale(i)
	_wake(i)
	fx.cue("pick")
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

## The drop: the paper springs back to its size and hops on its cord, and
## the cords straighten. A drag that moved nothing is not a move and is not
## undoable.
func _release() -> void:
	if _held < 0:
		return
	var i := _held
	var t := _now()
	_held = -1
	_settle_scale(i)
	if _dragged:
		_hop(i)
		_after_scan(t)
		fx.cue("drop")
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

## Everything a change to the positions drives: a ring where a knot came
## undone, the squash of a lantern that got piled up or freed, the sprout's
## line and the redraw.
func _after_scan(t: float) -> void:
	var was: Dictionary = _knot_keys
	_remember_knots()
	var gone := 0
	for key in was:
		if _knot_keys.has(key):
			continue
		gone += 1
		# Under a rash of them a ring each is noise; they only show once the
		# knots themselves do, and once a hold.
		if state.knots.size() < int(KNOT_FADE) and not _rang.has(key):
			_rang[key] = true
			fx.ring(_to_px(was[key]), _r, Pal.KNOT)
	for i in state.nodes:
		if state.crowded.has(i) != _crowded_was.has(i):
			_settle_scale(i)
	_crowded_was = state.crowded.duplicate()
	_speak(gone)
	_refresh(t)

## Kicks every cord on lantern `i`, so a lantern that starts moving takes
## its cords' slack with it.
func _wake(i: int) -> void:
	if Motion.reduce:
		return
	for e in state.edges.size():
		var edge: Vector2i = state.edges[e]
		if edge.x == i or edge.y == i:
			_sag_v[e] = minf(SAG_MAX, _sag_v[e] + WAKE_KICK)

## A scripted walk for lantern `i` from where it is drawn to where the state
## now has it, over SLIDE_TIME with the family's overshoot; its cords wake
## and it hops as it lands.
func _slide(i: int, from: Vector2, t: float) -> void:
	_mv[i] = {"from": from, "at": t}
	_wake(i)
	_after(SLIDE_TIME, func() -> void: _hop(i))

# --- the sprout's line ---

func _speak(gone: int) -> void:
	if is_done():
		return
	var left: int = state.crossings()
	if left == 0 and not state.crowded.is_empty():
		_say(tr("UT_CROWDED"), Face.Expr.STRAIN)
		return
	if gone <= 0 or left <= 0:
		return
	if left == 1:
		_say(tr("UT_ONE_KNOT_LEFT"), Face.Expr.HAPPY)
		return
	_say(tr("UT_GONE_ONE") % left if gone == 1
		else tr("UT_GONE_N") % [gone, left], Face.Expr.HAPPY)

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
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not is_done() and not state.history.is_empty()

## Walks the last dragged lantern back to where it was picked up. Counts no
## move.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var t := _now()
	var i := int(state.history[-1].node)
	var from := _disp(i, t)
	state.undo()
	_slide(i, from, t)
	_after_scan(t)
	fx.cue("undo")
	moved.emit()
	check_solved()
	return true

func hints_left() -> int:
	return HINTS - hints_used

## Hangs one lantern on its peg: it walks to the place the generator's own
## untangled drawing put it, and as it lands a green ring pulses out of the
## peg and sparkles rise; it can never be dragged again. Counts no move.
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
	_slide(pick, before[pick], t)
	hints_used += 1
	_after(SLIDE_TIME, func() -> void:
		var peg := _to_px(state.pos[pick])
		fx.ring(peg, _r, Pal.GOOD)
		fx.sparkle(peg, Pal.GOOD))
	fx.cue("hint")
	_after_scan(t)
	_say(tr("UT_PINNED"), Face.Expr.HAPPY)
	moved.emit()
	check_solved()
	return true

func reset_board() -> void:
	var t := _now()
	_held = -1
	_walk = []
	var walking: Array[int] = state.reset()
	for k in walking.size():
		_walk.append({"node": walking[k], "at": t + Motion.stagger(k, HOME_STEP)})
	moves = 0
	_running = true
	if not walking.is_empty():
		_say(tr("UT_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_after_scan(t)

## A completed daily is rebuilt from its seed, so its transient node positions
## start tangled when the player opens it again. Restore the generator's
## canonical planar arrangement and settle every visible lantern immediately;
## this does not emit `solved` a second time because the host owns the win
## presentation for an already-completed daily.
func restore_completed_board() -> void:
	var t := _now()
	_stop_all()
	_held = -1
	_walk = []
	_solved_at = t
	_opened = t - 10.0
	_last = t
	state.pos = state.planar.duplicate()
	state.history.clear()
	state.scan()
	_crowded_was = state.crowded.duplicate()
	_bad_drawn = {}
	for e in state.edges.size():
		_heat[e] = 0.0
		_pluck[e] = 0.0
		_pluck_v[e] = 0.0
	for i in state.nodes:
		_mv[i] = {"from": state.pos[i], "at": t - SLIDE_TIME}
		_swing[i] = 0.0
		_swing_v[i] = 0.0
		# Lit long ago, so the light does not run along the cords again.
		_lit_at[i] = t - 10.0
		_grip[i] = 0.0
		Motion.stop(_hop_tw[i])
		_hop_tw[i] = null
		_lanterns[i].position = _hang_rest(i)
		_lanterns[i].scale = Vector2.ONE
	_refresh(t)

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The board is the answer, so the win screen shows no cast: the drawing the
## player made stays on the card under it, lit.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("UT_WIN_SUB")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## The light runs out from one lantern along the cords, hop by hop, so the
## board finishes by proving it is one connected string -- the one thing about
## the graph the player never sees while playing. Each lantern hops the
## solve wave's hop as its light arrives, and sparkles.
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
			_lit_at[i] = t if Motion.reduce else t + Motion.SOLVE_DELAY + depth * LIGHT_STEP
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
		var wait := _lit_at[i] - t
		_hop(i, Motion.SOLVE_HOP, Motion.SOLVE_TIME, wait)
		_after(wait, _spark_at.bind(i))
	_say(tr("UT_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh(t)

## A spark as lantern `i` lights. The two pools are used in turn: a run of
## fourteen staggered by an eighth of a second would otherwise recycle one
## pool fast enough to cut each burst in half.
func _spark_at(i: int) -> void:
	var at := _to_px(state.pos[i])
	if i % 2 == 0:
		fx.sparkle(at, Pal.SUN)
	else:
		fx.puff(at, Pal.SUN, 4)

# --- odds and ends ---

## Kills every tween the previous board still tracks and retires its pending
## callbacks, so a rebuild never inherits a hop aimed at a lantern that is
## gone.
func _stop_all() -> void:
	_gen += 1
	for tw in _scale_tw:
		Motion.stop(tw)
	for tw in _hop_tw:
		Motion.stop(tw)

## Runs `what` after `delay`, unless the board has been rebuilt meanwhile.
func _after(delay: float, what: Callable) -> void:
	var gen := _gen
	get_tree().create_timer(maxf(delay, 0.0)).timeout.connect(func() -> void:
		if gen == _gen and is_inside_tree():
			what.call())

## Seconds since the scene started, the clock every animation here reads.
func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## 0 to 1, and 1 at once under reduce-motion.
func _dec(u: float) -> float:
	return 1.0 if Motion.reduce else clampf(u, 0.0, 1.0)

## The overshoot the whole family's pops use, as a curve rather than a tween,
## because the rings and the walks are drawn rather than tweened. It is the
## vocabulary's own (Motion.back_out); this is the short name the maths reads.
func _back_out(u: float) -> float:
	return Motion.back_out(u)
