extends "res://core/puzzle_base.gd"

## Balance as a garden seesaw. A plank on a trestle, cups at 1 to D either
## side of the pivot, a basket of fruit whose weights are secret. Drag a
## fruit up out of the basket and let it go over the plank: it drops, lands,
## bounces and rolls into the nearest free cup, and the beam swings with it.
## Some fruit come pinned (a brass pin through the stalk) and never move. Put
## every fruit on the plank with the beam dead level and the day is done --
## and exactly one arrangement does that.
##
## **The tilt is a reading, not a sign.** The trestle's hub carries a stone
## keel, so the beam rests at tan(angle) = torque / K like a pendulum
## balance: a spirit level on a bracket over the pivot shows one tick per
## unit of pull, and the sign over the scene says the number once the beam
## has come to rest. A lone fruit in cup 1 reads its own weight. That is how
## the player "checks the weights on the seesaw" (the user's words).
##
## The physics is puzzles/balance_sim.gd, stepped here on the board's clock;
## the rules are puzzles/balance_state.gd, in whole numbers. The win is the
## state's (every fruit on, torque zero) *and* the sim's (everything at
## rest), so the win screen never rises over a fruit still in the air.
##
## How it is drawn:
##   still  -- sky, hills, meadow, trestle, bales, the basket's inside;
##             rebuilt only on a relayout;
##   keel   -- the rod and stone under the hub, turned by the beam's angle;
##   plank  -- the plank with its cups and distance pips, the spirit level's
##             bracket and glass and the hub, turned by the beam's angle;
##   live   -- the ground shadows of anything off the plank, rebuilt while
##             something moves;
##   then the fruit (ui/faces/fruit.gd, one Control each), and over them the
##   front layer: the cups' front lips, the basket's weave, the pins, the
##   bubble, the reading sign and the toast. A fruit in the air or in the
##   hand is lifted over the front layer.
## Spec: docs/superpowers/specs/2026-09-27-balance-seesaw-design.md.

const Gen = preload("res://puzzles/balance_gen.gd")
const State = preload("res://puzzles/balance_state.gd")
const Sim = preload("res://puzzles/balance_sim.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

# --- layout, in the board card's pixels ---
const PAD := 30.0
const CUP_CAP := 132.0
## The plank runs this far past the last cup, in cups.
const PLANK_OVER := 0.55
const PLANK_T := 0.3
## A fruit's seat and radius, in cups.
const SEAT := 1.02
const R := 0.41
## The trestle: the hub's height over the grass and the legs' splay, in cups.
const HUB_H := 2.4
const LEG_SPLAY := 1.05
const LEG_W := 0.2
const KEEL_L := 1.25
const STONE_R := 0.33
## The spirit level, on a bracket over the pivot, in cups: its height over
## the plank, its length, its tube's height, and a tick's width in px per
## unit of torque (the glass shows five a side).
const VIAL_UP := 1.02
const VIAL_W := 2.3
const VIAL_H := 0.3
const VIAL_TICKS := 5
## The basket along the foot of the card.
const BASKET_H := 1.25
const BASKET_RIM := 0.5
## The reading sign, at the top of the card.
const SIGN_Y := 64.0
const SIGN_H := 92.0
const SIGN_FONT := 56
const SIGN_W := 220.0

# --- motion ---
const ENTER_STEP := 0.14
const SQUASH := 0.18
const SQUASH_TIME := 0.26
## The bubble lags the glass it floats in.
const BUBBLE_LAG := 7.0
const HOLD_SCALE := 1.1
const DANGLE := 0.00045
const DANGLE_MAX := 0.45
## A press that moves less than this and lets go this soon is a tap.
const TAP_PX := 16.0
const TAP_TIME := 0.3
const GLOW_TIME := 0.8
const WIN_HOLD := 1.4
const HINTS := 3
const TOAST_HOLD := 2.8
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32

var state: State = State.new()
var sim: Sim = Sim.new()
var fx: Node2D
var _difficulty := 0
var _faces: Array[Control] = []
var _front: Control
var _cup := 100.0
var _seat := 90.0
var _pivot := Vector2.ZERO
var _ground := 900.0
var _half := 400.0
var _basket := Rect2()
var _still: ArrayMesh
var _plank: ArrayMesh
var _keel: ArrayMesh
var _cups_front: ArrayMesh
var _basket_front: ArrayMesh
var _bubble: ArrayMesh
var _glow: ArrayMesh
var _pin: ArrayMesh
var _gold_pin: ArrayMesh
var _sign_mesh: ArrayMesh
var _live: ArrayMesh
var _shown: Array = []
var _bubble_x := 0.0
var _held := -1
var _grab := Vector2.ZERO
var _press_at := Vector2.ZERO
var _press_t := 0.0
var _squash_at: Array[float] = []
var _opened := 0.0
var _solved_at := -1.0
var _level_at := -100.0
var _was_level := false
var _was_calm := true
var _front_shown: Array = []
var _moving := true
var _toast := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "balance"
func title() -> String: return "Balance"

func rules() -> String:
	return tr("BAL_RULES")

## Undo and Hint; Reset is the host's. No Check: the beam is its own.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_front = Layer.new()
	_front.name = "Front"
	_front.painter = _draw_front
	_front.z_index = 1
	add_child(_front)
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 3
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_difficulty = difficulty
	var out := Gen.generate(rng, difficulty)
	state.setup(out)
	var ws: Array = []
	for f in state.fruit.size():
		ws.append(state.weights[state.fruit[f]])
	sim.setup(ws)
	for face in _faces:
		face.queue_free()
	_faces = []
	_squash_at = []
	for f in state.fruit.size():
		var face := Fruit.make(state.fruit[f], 100.0, Vector2.ZERO)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.shadowless = true
		face.set_idle(true)
		add_child(face)
		move_child(face, _front.get_index())
		_faces.append(face)
		_squash_at.append(-100.0)
	_held = -1
	_solved_at = -1.0
	_level_at = -100.0
	_was_level = false
	_toast = ""
	_opened = _now()
	_layout()
	_enter()
	fx.cue("enter")
	_tell("BAL_TIP_DRAG")

## Pinned fruit drop into their cups one after another -- the beam catching
## each one is the first thing on the screen, and the first lesson -- while
## the basket's fruit pop in.
func _enter() -> void:
	for f in state.fruit.size():
		if state.pinned[f]:
			sim.to_cup_now(f, state.at[f])
		else:
			sim.to_basket_now(f)
	if Motion.reduce or size.x <= 0.0:
		sim.snap()
		_place_faces()
		return
	sim.a = 0.0
	sim.av = 0.0
	var k := 0
	for f in state.fruit.size():
		if state.pinned[f]:
			var b: Dictionary = sim.bodies[f]
			b.mode = Sim.BASKET
			b.pos = Vector2(_pivot.x + state.at[f] * _cup * 0.6, -_seat)
			sim.hop(f, state.at[f], Motion.ENTER_DELAY + 0.25 + k * ENTER_STEP * 2.0)
			k += 1
	var j := 0
	for f in state.fruit.size():
		if not state.pinned[f]:
			_faces[f].scale = Vector2.ZERO
			Motion.pop_in(_faces[f], Motion.POP_IN, Motion.ENTER_DELAY + j * ENTER_STEP * 0.5)
			j += 1
	_moving = true
	_place_faces()

# --- layout ---

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	if size.x <= 0.0 or state.fruit.is_empty():
		return
	var reach := state.reach
	_cup = minf(CUP_CAP, (size.x - 2.0 * PAD) / (2.0 * (reach + PLANK_OVER) + 0.2))
	_seat = _cup * SEAT
	_half = (reach + PLANK_OVER) * _cup
	# The seesaw stands in the middle of the card and the basket sits on the
	# lawn in front of it, in the room between the grass line and the foot.
	var basket_h := _cup * BASKET_H
	var room_top := SIGN_Y + SIGN_H + _cup * (VIAL_UP + 1.1)
	var hub_y := maxf(room_top, (size.y - basket_h - PAD) * 0.5 - _cup * 0.2)
	hub_y = minf(hub_y, size.y - PAD - basket_h - _cup * (HUB_H + 0.5))
	_pivot = Vector2(size.x * 0.5, hub_y)
	_ground = hub_y + HUB_H * _cup
	var lawn := size.y - PAD - _ground
	var basket_top := _ground + maxf(_cup * 0.45, (lawn - basket_h) * 0.45)
	_basket = Rect2(PAD, basket_top, size.x - 2.0 * PAD, basket_h)
	sim.pivot = _pivot
	sim.cup = _cup
	sim.r = _cup * R
	sim.top = _cup * PLANK_T * 0.5
	sim.half = _half
	sim.ground = _ground
	sim.left_wall = 0.0
	sim.right_wall = size.x
	# the basket's seats, loose fruit in the basket's order
	var loose: Array[int] = []
	for f in state.fruit.size():
		if not state.pinned[f]:
			loose.append(f)
	var slots: Array[Vector2] = []
	slots.resize(state.fruit.size())
	var pitch := minf(_cup * 1.05, (_basket.size.x - _cup * 0.6) / maxf(1.0, loose.size()))
	var x0 := size.x * 0.5 - pitch * (loose.size() - 1) * 0.5
	for i in loose.size():
		slots[loose[i]] = Vector2(x0 + pitch * i, _basket.position.y + _cup * 0.02)
	for f in state.fruit.size():
		if state.pinned[f]:
			slots[f] = _pivot
	sim.slots = slots
	for f in state.fruit.size():
		var b: Dictionary = sim.bodies[f]
		if int(b.mode) == Sim.BASKET:
			b.pos = slots[f]
	_still = null
	_plank = null
	_keel = null
	_cups_front = null
	_basket_front = null
	_bubble = null
	_glow = null
	_pin = null
	_gold_pin = null
	_sign_mesh = null
	_live = null
	_place_faces()
	_redraw()

## The fruit where the sim says, turned and squashed.
func _place_faces() -> void:
	var t := _now()
	var n := state.fruit.size()
	var solve_t := t - _solved_at if _solved_at >= 0.0 else -1.0
	for f in n:
		var face := _faces[f]
		var pos: Vector2 = sim.position(f)
		var mode := int(sim.bodies[f].mode)
		var rot: float = sim.angle(f)
		var sc := Vector2.ONE
		if f == _held:
			var vel: Vector2 = sim.bodies[f].vel
			rot = clampf(vel.x * DANGLE, -DANGLE_MAX, DANGLE_MAX)
			sc = Vector2.ONE * HOLD_SCALE
		var q := (t - _squash_at[f]) / SQUASH_TIME
		if q >= 0.0 and q < 1.0 and not Motion.reduce:
			var s := SQUASH * sin(PI * q) * (1.0 - q)
			sc *= Vector2(1.0 + s, 1.0 - s)
		if solve_t >= 0.0 and not Motion.reduce:
			pos.y += Motion.hop_lift(solve_t - Motion.stagger(f, Motion.SOLVE_STAGGER), Motion.SOLVE_HOP * 3.0, Motion.SOLVE_TIME)
		Fruit.resize(face, _seat, pos)
		# each kind fills its seat differently: stand its drawn bottom where
		# the sim's round body touches down
		var sink: float = sim.r - _drawn_r(face)
		var down := Vector2(0.0, sink).rotated(sim.a if mode == Sim.PLANK else 0.0)
		face.position += down
		face.rotation = rot
		if face.scale != Vector2.ZERO and not _popping(face):
			face.scale = sc
		face.z_index = 2 if (f == _held or mode == Sim.AIR or mode == Sim.GROUND or mode == Sim.ARC) else 0
		face.expression = _mood(f, mode)

## How far below its centre a face's drawing reaches, cached per kind.
var _drawn := {}
func _drawn_r(face: Control) -> float:
	var key := "%s|%d" % [face.get_script().resource_path, int(_seat)]
	if not _drawn.has(key):
		_drawn[key] = face.radius()
	return _drawn[key]

func _popping(face: Control) -> bool:
	return t_since_open() < Motion.ENTER_DELAY + ENTER_STEP * 0.5 * _faces.size() + Motion.POP_IN + 0.05 and face.scale.x < 0.999

func t_since_open() -> float:
	return _now() - _opened

func _mood(f: int, mode: int) -> int:
	if _solved_at >= 0.0:
		return Face.Expr.JOY
	if f == _held:
		return Face.Expr.JOY
	match mode:
		Sim.AIR, Sim.GROUND, Sim.ARC:
			return Face.Expr.PUZZLED
		Sim.PLANK:
			var s: float = sim.bodies[f].s
			var dip := sim.a * signf(s)
			if dip > 0.06:
				return Face.Expr.WORRIED
			if dip < -0.06:
				return Face.Expr.JOY
			if dip > 0.025:
				return Face.Expr.STRAIN
	return Face.Expr.HAPPY

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if state.fruit.is_empty() or size.x <= 0.0:
		return
	if Motion.reduce:
		if not sim.calm():
			sim.snap()
		_after_physics()
	else:
		sim.advance(delta)
		_after_physics()
	var t := _now()
	# a bubble floats up to the high end of its glass
	var target := -clampf(sim.reading(), -VIAL_TICKS - 0.6, VIAL_TICKS + 0.6)
	var was := _bubble_x
	_bubble_x = target if Motion.reduce else lerpf(_bubble_x, target, 1.0 - exp(-delta * BUBBLE_LAG))
	var busy := not sim.calm() or _held >= 0 or absf(_bubble_x - was) > 0.001 or t - _level_at < GLOW_TIME \
		or (_solved_at >= 0.0 and t - _solved_at < 2.0) or t - _opened < 1.5 or _squashing(t)
	if busy or _moving:
		_place_faces()
		_redraw()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		_front.queue_redraw()
	_moving = busy

func _squashing(t: float) -> bool:
	for at in _squash_at:
		if t - at < SQUASH_TIME:
			return true
	return false

## What the sim reported this frame: sounds, puffs and the level moment.
func _after_physics() -> void:
	var t := _now()
	for e: Dictionary in sim.events:
		match String(e.e):
			"land":
				var f: int = e.f
				_squash_at[f] = t
				var w: int = sim.weights[f]
				var speed: float = e.speed
				fx.cue("land", lerpf(1.2, 0.78, clampf((w - 1.0) / 11.0, 0.0, 1.0)),
					lerpf(-12.0, 0.0, clampf(speed / (_cup * 10.0), 0.0, 1.0)))
			"bump":
				_squash_at[int(e.f)] = t
			"seat":
				fx.cue("step", randf_range(0.95, 1.08))
			"thud":
				fx.cue("thud", 1.0, lerpf(-12.0, 0.0, clampf(float(e.speed) / 0.8, 0.0, 1.0)))
				if not Motion.reduce:
					var side: float = e.side
					fx.puff(Vector2(_pivot.x + side * (_half - _cup * 0.35), _ground - _cup * 0.2), Pal.STRAW, 5)
			"grass":
				_squash_at[int(e.f)] = t
				fx.cue("land", 0.7, -8.0)
				if not Motion.reduce:
					fx.puff(sim.position(int(e.f)) + Vector2(0.0, sim.r), Pal.LEAF, 4)
			"home":
				_squash_at[int(e.f)] = t
				fx.cue("step", 0.85)
	sim.events.clear()
	var calm: bool = sim.calm() and _held < 0
	if calm and not _was_calm:
		_on_rest()
	_was_calm = calm

## The beam has come to rest: the level moment, the solve, or a tock.
func _on_rest() -> void:
	if not sim.calm():
		return
	var level: bool = state.torque() == 0 and state.in_basket() < state.fruit.size()
	if is_solved():
		check_solved()
		return
	if level and not _was_level:
		_level_at = _now()
		fx.cue("level")
		if not Motion.reduce:
			fx.ring(_vial_centre(), _cup * 1.3, Pal.SUN)
		if state.in_basket() > 0:
			_tell("BAL_LEVEL_MORE")
	elif not level and state.in_basket() < state.fruit.size():
		fx.cue("tock", 1.0, -10.0)
	_was_level = level

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _redraw() -> void:
	_live = null
	queue_redraw()
	_front.queue_redraw()

# --- the drawing ---

func _plank_xf() -> Transform2D:
	return Transform2D(sim.a, _pivot)

func _vial_centre() -> Vector2:
	return _plank_xf() * Vector2(0.0, -(sim.top + VIAL_UP * _cup))

func _draw() -> void:
	if state.fruit.is_empty() or size.x <= 0.0:
		return
	if _still == null:
		_still = _build_still()
	if _keel == null:
		_keel = _build_keel()
	if _plank == null:
		_plank = _build_plank()
	if _live == null:
		_live = _build_live()
	var shown: Array = [_still, _keel, _plank]
	draw_mesh(_still, null)
	draw_mesh(_keel, null, _plank_xf())
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	draw_mesh(_plank, null, _plank_xf())
	_shown = shown

func _draw_front() -> void:
	if state.fruit.is_empty() or size.x <= 0.0:
		return
	var t := _now()
	if _cups_front == null:
		_cups_front = _build_cups_front()
	if _basket_front == null:
		_basket_front = _build_basket_front()
	if _bubble == null:
		_bubble = _build_bubble()
	if _glow == null:
		_glow = _build_glow()
	if _pin == null:
		_pin = _build_pin(Pal.BRASS, Pal.BRASS_DEEP)
		_gold_pin = _build_pin(Pal.SUN, Pal.SUN_DEEP)
	var shown: Array = [_cups_front, _basket_front, _bubble, _glow, _pin, _gold_pin]
	var xf := _plank_xf()
	_front.draw_mesh(_cups_front, null, xf)
	_front.draw_mesh(_basket_front, null)
	# the spirit level's bubble, and its ring lit on a level
	var vial_y := -(sim.top + VIAL_UP * _cup)
	var tick := _tick_px()
	var glow := 0.0
	if state.torque() == 0 and state.in_basket() < state.fruit.size() and sim.calm():
		glow = 0.55
	if t - _level_at < GLOW_TIME:
		glow = maxf(glow, 1.0 - (t - _level_at) / GLOW_TIME)
	if _solved_at >= 0.0:
		glow = 1.0
	if glow > 0.0:
		_front.draw_mesh(_glow, null, xf * Transform2D(0.0, Vector2(0.0, vial_y)), Color(1, 1, 1, glow))
	_front.draw_mesh(_bubble, null, xf * Transform2D(0.0, Vector2(_bubble_x * tick, vial_y)))
	# pins through the stalks
	for f in state.fruit.size():
		if state.pinned[f] or state.hinted[f]:
			var at: Vector2 = sim.position(f)
			var ang: float = _faces[f].rotation
			var head := at + Vector2(0.0, -sim.r * 1.02).rotated(ang)
			_front.draw_mesh(_gold_pin if state.hinted[f] else _pin, null, Transform2D(ang, head))
	_draw_sign(t, shown)
	_draw_toast(t, shown)
	_front_shown = shown

func _tick_px() -> float:
	return (VIAL_W * _cup * 0.5 - VIAL_H * _cup * 0.5) / (VIAL_TICKS + 0.6)

## The sky, the hills, the meadow, the trestle's legs, the bales and the
## basket's dark inside.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var w := size.x
	_grad(b, Rect2(0.0, 0.0, w, _ground), Pal.SKY_TOP.lerp(Pal.PAPER, 0.35), Pal.SKY_HORIZON.lerp(Pal.PAPER, 0.25))
	Scenery.cloud(b, Vector2(w * 0.2, SIGN_Y + SIGN_H + _cup * 0.55), _cup * 0.32, Pal.CLOUD)
	Scenery.cloud(b, Vector2(w * 0.82, SIGN_Y + SIGN_H * 0.4), _cup * 0.24, Pal.CLOUD)
	# far hills
	b.ellipse(Vector2(w * 0.18, _ground + _cup * 0.2), w * 0.42, _cup * 1.25, Pal.LAWN.lerp(Pal.SKY_HORIZON, 0.45))
	b.ellipse(Vector2(w * 0.86, _ground + _cup * 0.25), w * 0.4, _cup * 1.0, Pal.LAWN.lerp(Pal.SKY_HORIZON, 0.3))
	# far trees on the hills, behind the meadow's edge
	for tree: Vector3 in [Vector3(0.09, 0.9, 0.36), Vector3(0.93, 0.8, 0.3), Vector3(0.74, 0.55, 0.22)]:
		var foot := Vector2(w * tree.x, _ground - _cup * 0.05)
		var tr_r := _cup * tree.z * 1.6
		b.fan(Face.Builder.round_rect(foot + Vector2(-tr_r * 0.12, -tr_r * 1.6), Vector2(tr_r * 0.24, tr_r * 1.6), tr_r * 0.1), Pal.BARK.lerp(Pal.SKY_HORIZON, 0.35))
		var leaf := Pal.LEAF_DEEP.lerp(Pal.SKY_HORIZON, 0.4)
		b.disc(foot + Vector2(0.0, -tr_r * 2.0), tr_r, leaf)
		b.disc(foot + Vector2(-tr_r * 0.6, -tr_r * 1.5), tr_r * 0.7, leaf)
		b.disc(foot + Vector2(tr_r * 0.62, -tr_r * 1.55), tr_r * 0.66, leaf)
	# the meadow
	_grad(b, Rect2(0.0, _ground, w, size.y - _ground), Pal.LAWN, Pal.LAWN_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(0.0, _ground - 3.0), Vector2(w, 7.0), 3.0), Pal.LAWN_DEEP.lerp(Pal.LAWN, 0.4))
	# the plank's shadow on the grass
	Scenery.soft_disc(b, Vector2(_pivot.x, _ground + _cup * 0.06), _half * 0.95, _cup * 0.2, Color(Pal.TEXT, 0.12))
	# bales under the ends: the stops the plank bottoms out on
	for side: float in [-1.0, 1.0]:
		var u := _half - _cup * 0.35
		var bottom := _pivot.y + u * sin(Sim.A_MAX) + sim.top * cos(Sim.A_MAX)
		var cx := _pivot.x + side * u * cos(Sim.A_MAX)
		var bw := _cup * 0.95
		var top := bottom + 2.0
		var h := _ground + _cup * 0.12 - top
		if h > 8.0:
			Scenery.soft_disc(b, Vector2(cx, _ground + _cup * 0.1), bw * 0.7, _cup * 0.12, Color(Pal.TEXT, 0.14))
			b.fan(Face.Builder.round_rect(Vector2(cx - bw * 0.5, top), Vector2(bw, h), _cup * 0.14), Pal.STRAW)
			b.fan(Face.Builder.round_rect(Vector2(cx - bw * 0.5, top), Vector2(bw, h * 0.3), _cup * 0.12), Pal.STRAW.lerp(Pal.PAPER, 0.35))
			for k in 2:
				var sx := cx - bw * 0.22 + k * bw * 0.44
				b.fan(Face.Builder.round_rect(Vector2(sx - 3.0, top), Vector2(6.0, h), 3.0), Pal.STRAP)
	# the trestle: two splayed legs, a cross bar, feet in the grass
	var hub := _pivot
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(hub.x + side * LEG_SPLAY * _cup, _ground + _cup * 0.08)
		Scenery.soft_disc(b, foot + Vector2(0.0, 4.0), _cup * 0.3, _cup * 0.07, Color(Pal.TEXT, 0.16))
		b.stroke(PackedVector2Array([hub, foot]), LEG_W * _cup, Pal.SCALE_DEEP)
		b.stroke(PackedVector2Array([hub.lerp(foot, 0.15), foot]), LEG_W * _cup * 0.35, Pal.SCALE_WOOD.lerp(Pal.SCALE_DEEP, 0.3))
	var bar_y := hub.y + (_ground - hub.y) * 0.62
	var bar_x := LEG_SPLAY * _cup * 0.62
	b.stroke(PackedVector2Array([Vector2(hub.x - bar_x, bar_y), Vector2(hub.x + bar_x, bar_y)]), LEG_W * _cup * 0.7, Pal.SCALE_DEEP)
	# grass tufts along the meadow, and flowers in it
	var tufts := [0.06, 0.3, 0.64, 0.93]
	for i in tufts.size():
		Scenery.tuft(b, Vector2(w * tufts[i], _ground + _cup * 0.12), _cup * 0.3)
	var lawn_h := size.y - _ground
	var flowers := [Vector3(0.1, 0.18, 0), Vector3(0.22, 0.12, 1), Vector3(0.83, 0.2, 2), Vector3(0.9, 0.1, 0),
		Vector3(0.15, 0.86, 1), Vector3(0.5, 0.9, 2), Vector3(0.8, 0.84, 0), Vector3(0.36, 0.2, 2), Vector3(0.62, 0.15, 1)]
	for fl: Vector3 in flowers:
		var at := Vector2(w * fl.x, _ground + lawn_h * fl.y)
		if _basket.grow(_cup * 0.3).has_point(at):
			continue
		_flower(b, at, _cup * 0.1, [Pal.FLOWER, Pal.PAPER, Pal.SUN][int(fl.z)])
	for tf: Vector2 in [Vector2(0.05, 0.5), Vector2(0.95, 0.45), Vector2(0.45, 0.25), Vector2(0.68, 0.6)]:
		var at := Vector2(w * tf.x, _ground + lawn_h * tf.y)
		if not _basket.grow(_cup * 0.2).has_point(at):
			Scenery.tuft(b, at, _cup * 0.22)
	# the basket's inside, behind its fruit
	var inner := Rect2(_basket.position + Vector2(_cup * 0.1, 0.0), Vector2(_basket.size.x - _cup * 0.2, _cup * 0.5))
	b.ellipse(inner.get_center(), inner.size.x * 0.5, inner.size.y * 0.5, Pal.ACORN_DEEP.lerp(Pal.WOOD_DEEP, 0.4))
	return b.mesh()

static func _flower(b: Face.Builder, at: Vector2, r: float, petal: Color) -> void:
	b.stroke(PackedVector2Array([at, at + Vector2(0.0, r * 2.2)]), maxf(2.0, r * 0.3), Pal.LEAF_DEEP)
	for k in 5:
		var ang := TAU * k / 5.0 - PI * 0.5
		b.disc(at + Vector2(cos(ang), sin(ang)) * r * 0.8, r * 0.55, petal)
	b.disc(at, r * 0.45, Pal.SUN_DEEP)

## A rect whose colour runs from `top` to `bottom`.
static func _grad(b: Face.Builder, r: Rect2, top: Color, bottom: Color) -> void:
	var i0 := b.vertex(r.position, top)
	var i1 := b.vertex(r.position + Vector2(r.size.x, 0.0), top)
	var i2 := b.vertex(r.end, bottom)
	var i3 := b.vertex(r.position + Vector2(0.0, r.size.y), bottom)
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## The keel under the hub, in the plank's frame: a rod down to a stone. It
## turns with the beam, which is what swings it back: the pendulum that makes
## the tilt a reading.
func _build_keel() -> ArrayMesh:
	var b := Face.Builder.new()
	var end := Vector2(0.0, KEEL_L * _cup)
	b.stroke(PackedVector2Array([Vector2.ZERO, end]), _cup * 0.09, Pal.SCALE_DARK)
	var sr := STONE_R * _cup
	b.ellipse(end + Vector2(0.0, sr * 0.1), sr * 1.12, sr, Pal.BOULDER)
	b.ellipse(end + Vector2(-sr * 0.2, -sr * 0.2), sr * 0.7, sr * 0.55, Pal.BOULDER.lerp(Pal.PAPER, 0.25))
	b.ellipse(end + Vector2(-sr * 0.35, -sr * 0.42), sr * 0.28, sr * 0.16, Color(Pal.PAPER, 0.5))
	# the band the rod is lashed to it with
	b.fan(Face.Builder.round_rect(end + Vector2(-sr * 0.5, -sr * 0.95), Vector2(sr, sr * 0.3), sr * 0.12), Pal.ROPE_HEMP)
	return b.mesh()

## The plank, in its own frame (x along it, y down, the pivot at the
## origin): a board with a notch at every cup, its lower edge in shade, the
## cups' distance pips on its face, the level's bracket and glass over the
## middle, and the hub.
func _build_plank() -> ArrayMesh:
	var b := Face.Builder.new()
	var top := sim.top
	var ends := _half
	var pts := PackedVector2Array()
	var steps := int(ceil(ends * 2.0 / 6.0))
	for i in steps + 1:
		var x := -ends + ends * 2.0 * float(i) / float(steps)
		var s := x / _cup
		var dip := sim._dip(s) if absf(s) > 0.5 and absf(s) < state.reach + 0.5 else 0.0
		pts.append(Vector2(x, -top + dip))
	pts.append(Vector2(ends, top))
	pts.append(Vector2(-ends, top))
	# a rounded look at the ends comes from the caps drawn over them
	b.polygon(pts, Pal.SCALE_WOOD)
	b.fan(PackedVector2Array([Vector2(-ends, top * 0.25), Vector2(ends, top * 0.25), Vector2(ends, top), Vector2(-ends, top)]), Pal.SCALE_DEEP)
	for side: float in [-1.0, 1.0]:
		b.ellipse(Vector2(side * ends, 0.0), top * 0.5, top, Pal.SCALE_DEEP)
	# a grain line
	b.stroke(PackedVector2Array([Vector2(-ends * 0.92, -top * 0.15), Vector2(-ends * 0.35, -top * 0.22)]), 2.5, Color(Pal.SCALE_DARK, 0.25))
	b.stroke(PackedVector2Array([Vector2(ends * 0.2, -top * 0.1), Vector2(ends * 0.85, -top * 0.18)]), 2.5, Color(Pal.SCALE_DARK, 0.25))
	# pips: cup x shows |x| dots on the plank's face
	var pip := maxf(2.5, _cup * 0.035)
	for x in state.cups():
		var n := absi(x)
		var gap := pip * 2.6
		for k in n:
			var px := x * _cup + (k - (n - 1) * 0.5) * gap
			b.disc(Vector2(px, top * 0.05), pip, Pal.SCALE_DARK.lerp(Pal.SCALE_DEEP, 0.2))
	# the level's bracket and glass
	var vy := -(top + VIAL_UP * _cup)
	var vw := VIAL_W * _cup
	var vh := VIAL_H * _cup
	b.fan(Face.Builder.round_rect(Vector2(-_cup * 0.06, vy), Vector2(_cup * 0.12, -vy - top * 0.5), _cup * 0.04), Pal.SCALE_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-vw * 0.5 - 6.0, vy - vh * 0.5 - 6.0), Vector2(vw + 12.0, vh + 12.0), vh * 0.5 + 6.0), Pal.BRASS_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(-vw * 0.5 - 3.0, vy - vh * 0.5 - 3.0), Vector2(vw + 6.0, vh + 6.0), vh * 0.5 + 3.0), Pal.BRASS)
	b.fan(Face.Builder.round_rect(Vector2(-vw * 0.5, vy - vh * 0.5), Vector2(vw, vh), vh * 0.5), Pal.DEW.lerp(Pal.LEAF_LIGHT, 0.35))
	b.fan(Face.Builder.round_rect(Vector2(-vw * 0.5 + vh * 0.3, vy - vh * 0.36), Vector2(vw - vh * 0.6, vh * 0.2), vh * 0.1), Color(Pal.PAPER, 0.45))
	var tick := _tick_px()
	for k in range(-VIAL_TICKS, VIAL_TICKS + 1):
		var tall := 0.62 if k == 0 else (0.42 if absi(k) == 5 else 0.3)
		var x := k * tick
		var col := Color(Pal.TEXT, 0.6 if k == 0 else 0.35)
		b.fan(Face.Builder.round_rect(Vector2(x - 1.5, vy + vh * 0.5 - vh * tall), Vector2(3.0, vh * tall), 1.5), col)
	# the hub
	b.disc(Vector2.ZERO, _cup * 0.16, Pal.SCALE_DARK)
	b.disc(Vector2.ZERO, _cup * 0.08, Pal.BRASS)
	b.disc(Vector2(-_cup * 0.02, -_cup * 0.025), _cup * 0.03, Pal.BRASS_HI)
	return b.mesh()

## The front lip of every cup, drawn over the fruit so a seated fruit sits
## *in* its cup rather than on the plank's edge.
func _build_cups_front() -> ArrayMesh:
	var b := Face.Builder.new()
	var top := sim.top
	var lip_w := _seat * 0.72
	var lip_h := sim.r * 0.24
	for x in state.cups():
		var cx := x * _cup
		b.fan(Face.Builder.round_rect(Vector2(cx - lip_w * 0.5, -top - lip_h * 0.5), Vector2(lip_w, lip_h), lip_h * 0.5), Pal.SCALE_WOOD.lerp(Pal.SCALE_DEEP, 0.45))
		b.fan(Face.Builder.round_rect(Vector2(cx - lip_w * 0.42, -top - lip_h * 0.5), Vector2(lip_w * 0.84, lip_h * 0.36), lip_h * 0.18), Pal.SCALE_WOOD.lerp(Pal.PAPER, 0.2))
	return b.mesh()

## The basket's front: a woven band with a rim, over its fruit's bottoms.
func _build_basket_front() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := _basket
	var rim_y := r.position.y + _cup * 0.28
	var body := Rect2(Vector2(r.position.x, rim_y), Vector2(r.size.x, r.end.y - rim_y))
	Scenery.soft_disc(b, Vector2(body.get_center().x, body.end.y), body.size.x * 0.52, _cup * 0.12, Color(Pal.TEXT, 0.16))
	b.fan(Face.Builder.round_rect(body.position, body.size, _cup * 0.3), Pal.WHEAT.lerp(Pal.ACORN, 0.35))
	# the weave: rows of stitches, alternating
	var rows := 3
	var row_h := (body.size.y - _cup * 0.22) / rows
	for rw in rows:
		var y := body.position.y + _cup * 0.2 + rw * row_h
		var step := _cup * 0.34
		var k := 0
		var x := body.position.x + _cup * 0.2 + (step * 0.5 if rw % 2 == 1 else 0.0)
		while x < body.end.x - _cup * 0.25:
			b.fan(Face.Builder.round_rect(Vector2(x, y), Vector2(step * 0.72, row_h * 0.62), row_h * 0.3),
				Pal.WHEAT.lerp(Pal.PAPER, 0.18) if (k + rw) % 2 == 0 else Pal.WHEAT)
			x += step
			k += 1
	b.fan(Face.Builder.round_rect(Vector2(r.position.x - 4.0, rim_y - _cup * 0.06), Vector2(r.size.x + 8.0, _cup * 0.16), _cup * 0.08), Pal.ACORN)
	b.fan(Face.Builder.round_rect(Vector2(r.position.x, rim_y - _cup * 0.05), Vector2(r.size.x, _cup * 0.06), _cup * 0.03), Pal.WHEAT.lerp(Pal.PAPER, 0.35))
	return b.mesh()

func _build_bubble() -> ArrayMesh:
	var b := Face.Builder.new()
	var vh := VIAL_H * _cup
	b.ellipse(Vector2.ZERO, vh * 0.62, vh * 0.34, Color(Pal.PAPER, 0.92))
	b.ellipse(Vector2(-vh * 0.18, -vh * 0.1), vh * 0.22, vh * 0.1, Color(1, 1, 1, 0.95))
	return b.mesh()

func _build_glow() -> ArrayMesh:
	var b := Face.Builder.new()
	var vh := VIAL_H * _cup
	Scenery.soft_disc(b, Vector2.ZERO, vh * 2.2, vh * 1.4, Color(Pal.SUN, 0.55))
	b.stroke(Face.Builder.ring(Vector2.ZERO, vh * 0.78, vh * 0.48), 3.0, Pal.GOOD, true)
	return b.mesh()

func _build_pin(head: Color, deep: Color) -> ArrayMesh:
	var b := Face.Builder.new()
	var k := _cup * 0.14
	b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0.0, k * 1.6)]), maxf(2.0, k * 0.22), Pal.STEEL)
	b.disc(Vector2.ZERO, k * 0.62, deep)
	b.disc(Vector2(-k * 0.08, -k * 0.08), k * 0.48, head)
	b.disc(Vector2(-k * 0.2, -k * 0.22), k * 0.16, Color(Pal.PAPER, 0.7))
	return b.mesh()

## Shadows on the grass under anything off the plank, fainter the higher it
## is.
func _build_live() -> ArrayMesh:
	var b := Face.Builder.new()
	var any := false
	for f in state.fruit.size():
		var mode := int(sim.bodies[f].mode)
		if mode == Sim.PLANK or mode == Sim.BASKET:
			continue
		var p: Vector2 = sim.position(f)
		var up := clampf((_ground - p.y) / (_cup * 4.0), 0.0, 1.0)
		Scenery.soft_disc(b, Vector2(p.x, _ground + _cup * 0.05), sim.r * lerpf(1.1, 0.6, up), sim.r * 0.25,
			Color(Pal.TEXT, lerpf(0.2, 0.05, up)))
		any = true
	return b.mesh() if any else null

## The reading sign: what the beam says, once it has stopped to say it.
func _draw_sign(t: float, shown: Array) -> void:
	var on := false
	for f in state.fruit.size():
		if int(sim.bodies[f].mode) == Sim.PLANK:
			on = true
			break
	if not on:
		return
	if _sign_mesh == null:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-SIGN_W * 0.5, 0.0), Vector2(SIGN_W, SIGN_H), SIGN_H * 0.5), Pal.PAPER)
		b.fan(Face.Builder.round_rect(Vector2(-SIGN_W * 0.5 + 5.0, SIGN_H - 12.0), Vector2(SIGN_W - 10.0, 7.0), 3.5), Color(Pal.TEXT, 0.06))
		_sign_mesh = b.mesh()
	var mid := Vector2(size.x * 0.5, SIGN_Y - 30.0)
	_front.draw_mesh(_sign_mesh, null, Transform2D(0.0, mid))
	shown.append(_sign_mesh)
	var rest := sim.beam_at_rest() and _held < 0
	var value := sim.reading() if not rest else float(state.torque())
	var over := absf(value) > VIAL_TICKS + 0.4
	var n := int(roundf(absf(value)))
	var text := ("%d+" % VIAL_TICKS) if over else str(mini(n, VIAL_TICKS))
	var alpha := 1.0 if rest else 0.4
	var font: Font = CozyTheme.display(700)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x
	var base := mid.y + SIGN_H * 0.5 + font.get_ascent(SIGN_FONT) * 0.36
	mid.x += 26.0
	var ink := Pal.GOOD.lerp(Pal.TEXT, 0.25) if n == 0 and rest else Pal.TEXT
	_front.draw_string(font, Vector2(mid.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT, Color(ink, alpha))
	# a little seesaw beside the number, leaning the way the big one does
	var way := 0.0 if n == 0 and not over else signf(value)
	var c := Vector2(mid.x - tw * 0.5 - 40.0, mid.y + SIGN_H * 0.5 + 6.0)
	var ink_icon := Color(Pal.TEXT, alpha * 0.75)
	_front.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -6.0), c + Vector2(10.0, 12.0), c + Vector2(-10.0, 12.0)]), ink_icon)
	var d := Vector2(cos(way * 0.4), sin(way * 0.4)) * 24.0
	_front.draw_line(c - d + Vector2(0.0, -8.0), c + d + Vector2(0.0, -8.0), ink_icon, 6.0, true)
	_front.draw_circle(c - d + Vector2(0.0, -8.0) + Vector2(0.0, -7.0), 5.0, ink_icon)
	_front.draw_circle(c + d + Vector2(0.0, -8.0) + Vector2(0.0, -7.0), 5.0, ink_icon)

## The toast under the sign -- Knight's `_draw_toast`.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE), Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
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
		lines = maxi(1, int(round(wrapped.y / font.get_height(TOAST_FONT))))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh()
		_toast_mesh_for = key
	var mid := Vector2(size.x * 0.5, SIGN_Y + SIGN_H - 10.0 + h * 0.5)
	_front.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_front.draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_front.draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _tell(key: String) -> void:
	_toast = key
	_toast_at = _now()
	_front.queue_redraw()

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if _done or state.fruit.is_empty():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _held >= 0:
		_drag(event.position)
		accept_event()

## The fruit under a point, loose or not, nearest first; -1 for none.
func _fruit_at(p: Vector2) -> int:
	var best := -1
	var best_d := sim.r * 1.35
	for f in state.fruit.size():
		var mode := int(sim.bodies[f].mode)
		if mode == Sim.ARC:
			continue
		var d := sim.position(f).distance_to(p)
		if d < best_d:
			best = f
			best_d = d
	return best

func _press(p: Vector2) -> void:
	var f := _fruit_at(p)
	if f < 0:
		return
	if not state.loose(f):
		_tell("BAL_PINNED")
		fx.cue("refused")
		if not Motion.reduce:
			Motion.shiver(_faces[f])
		return
	_held = f
	_grab = sim.position(f) - p
	_press_at = p
	_press_t = _now()
	sim.hold(f, sim.position(f))
	fx.cue("lift", randf_range(0.95, 1.05))
	_moving = true

func _drag(p: Vector2) -> void:
	var to := p + _grab.lerp(Vector2(0.0, -sim.r * 0.6), 0.5)
	sim.drag_to(_held, to, get_process_delta_time())
	_moving = true

func _release(p: Vector2) -> void:
	if _held < 0:
		return
	var f := _held
	_held = -1
	var from: int = state.at[f]
	var tapped := p.distance_to(_press_at) < TAP_PX and _now() - _press_t < TAP_TIME
	if tapped:
		if from == State.BASKET:
			# a tap in the basket: it hops where it is, and the toast says how
			sim.to_basket_now(f)
			_squash_at[f] = _now()
			_tell("BAL_TIP_DRAG")
		else:
			# a tap on the plank: home to the basket
			state.place(f, State.BASKET)
			sim.hop(f, 0)
			note_move()
		_moving = true
		return
	var x := _aim(f, sim.position(f))
	if x == State.BASKET and _basket.grow(_cup * 0.3).has_point(sim.position(f)):
		sim.hop(f, 0, 0.0)
	else:
		sim.release(f, x)
	if state.place(f, x):
		note_move()
	_moving = true

## Where a fruit let go at `p` is making for: the free cup nearest under it,
## or the basket when it is not over the plank.
func _aim(f: int, p: Vector2) -> int:
	var local := (p - _pivot).rotated(-sim.a)
	if absf(local.x) > _half + _cup * 0.3 or local.y > sim.r * 0.5:
		return State.BASKET
	var best := State.BASKET
	var best_d := INF
	for x in state.cups():
		var o := state.occupant(x)
		if o >= 0 and o != f:
			continue
		var d := absf(local.x / _cup - x)
		if d < best_d:
			best = x
			best_d = d
	return best

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo() and not is_done()

## The last move taken back: the fruit hop to where they were.
func undo() -> bool:
	if is_done():
		return false
	_held = -1
	var back: Array = state.undo()
	if back.is_empty():
		return false
	for mv in back:
		_hop(int(mv[0]), int(mv[1]), 0.0)
	fx.cue("undo")
	_moving = true
	moved.emit()
	return true

func _hop(f: int, x: int, delay: float) -> void:
	sim.hop(f, x, delay)
	if Motion.reduce:
		sim.snap()

func hints_left() -> int:
	if _difficulty >= 3:
		return 0
	return maxi(0, HINTS - hints_used)

## One fruit flies to its answer cup and is pinned there in gold; whatever
## was in that cup goes home first.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	_held = -1
	var m: Dictionary = state.apply_hint()
	if m.is_empty():
		return false
	hints_used += 1
	var b: int = m.bumped
	if b >= 0:
		_hop(b, 0, 0.0)
	var f: int = m.f
	_hop(f, int(m.cup), 0.12 if b >= 0 else 0.0)
	if not Motion.reduce:
		var at := _plank_xf() * Vector2(int(m.cup) * _cup, -sim.top - sim.r)
		get_tree().create_timer(Sim.ARC_TIME + 0.15).timeout.connect(func():
			fx.ring(at, sim.r * 1.8, Pal.SUN)
			for k in 4:
				fx.sparkle(at + Vector2(randf_range(-1, 1), randf_range(-1, 0.3)) * sim.r))
	_tell("BAL_HINT")
	fx.cue("hint")
	_moving = true
	moved.emit()
	return true

func reset_board() -> void:
	_held = -1
	var moved_fs := state.reset()
	var k := 0
	for f in moved_fs:
		_hop(f, 0, Motion.stagger(k, 0.06))
		k += 1
	_solved_at = -1.0
	_was_level = false
	moves = 0
	_running = true
	fx.cue("reset")
	_tell("BAL_CLEARED")
	_moving = true

## Every fruit on the plank, the beam level -- and at rest, so the win never
## rises over a fruit still in the air.
func is_solved() -> bool:
	return state.is_solved() and sim.calm() and _held < 0

func share_glyphs() -> String:
	return "⚖️ " + tr("BAL_SHARE") % [state.fruit.size(), state.cups().size()]

# --- the win ---

func _on_solved() -> void:
	_solved_at = _now()
	_held = -1
	fx.cue("solved")
	if not Motion.reduce:
		fx.ring(_vial_centre(), _cup * 1.6, Pal.SUN)
		for f in state.fruit.size():
			var at: Vector2 = sim.position(f)
			get_tree().create_timer(Motion.stagger(f, Motion.SOLVE_STAGGER) + 0.1).timeout.connect(func():
				fx.sparkle(at + Vector2(0.0, -sim.r)))
	_tell("BAL_SOLVED")
	_moving = true

func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	var labels: Array[String] = []
	for k in state.kinds():
		faces.append(Fruit.make(k, 140.0, Vector2.ZERO))
		labels.append(str(state.weights[k]))
	return {"faces": faces, "labels": labels, "subtitle": tr("BAL_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_HOLD

func restore_completed_board() -> void:
	state.show_answer()
	for f in state.fruit.size():
		sim.to_cup_now(f, state.at[f])
	sim.snap()
	_bubble_x = 0.0
	_solved_at = _now() - 100.0
	_held = -1
	_toast = ""
	_place_faces()
	_redraw()

# --- for harnesses ---

## Board-local centre of cup `x` at the beam's current angle.
func cup_to_local(x: int) -> Vector2:
	return _plank_xf() * Vector2(x * _cup, -sim.top - sim.r)

func fruit_to_local(f: int) -> Vector2:
	return sim.position(f)

## A drawing of one layer over the fruit, painted by the board.
class Layer extends Control:
	var painter: Callable

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if painter.is_valid():
			painter.call()
