extends "res://core/puzzle_base.gd"

## Trestle: build a bridge over the river, then send the cart across.
##
## The day's gap has red pins on its banks (and on some days a rock in the
## river, or posts on the banks for rope). Drag from a pin or a joint to a
## point in reach to lay a member -- road, wood or rope, picked from the chips
## over the scene -- or tap a joint and then tap points to lay a chain. Tap a
## member to take it down. Every member costs, and the day has a budget.
## Press Go and the test runs: the bridge takes its own weight, the cart
## drives on, and every member shows its load, green to red. One past its
## limit snaps. The cart on the far bank is the solve; the cart in the river
## sends you back to the drawing board with the snapped members marked.
##
## The physics is puzzles/trestle_sim.gd, stepped here at its fixed DT on
## the board's clock; the rules are puzzles/trestle_state.gd; the levels are
## mined (tools/mine_trestle.gd) with a design that is proved to cross, which
## is also where a hint comes from.
##
## How it is drawn:
##   still -- sky, hills, the banks, the river's body, the rock and posts,
##            the build dots; rebuilt only on a relayout;
##   frame -- the bridge (members, bolts, pins), rebuilt when the design
##            changes while building and every frame of a test;
##   cart  -- one body mesh and one wheel mesh, moved by transform, with the
##            passengers (ui/faces/fruit.gd) riding in it;
##   front -- the water's face over anything that fell in, the ghost member
##            under the finger, the chips and the budget, the toast.
##
## After a test the bridge keeps what it learned: every member is tinted by
## the highest load it took (the stress view, carried into building), the
## member that gave way first is ringed, and the moment it goes plays slow.
## After the solve the strip offers a convoy (three carts at once, on the
## bridge you built) and a free build with no budget, and says where the
## bridge's cost stands among today's (the crowd, core/backend.gd).
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md (and its
## section 9, the second pass).

const Backend = preload("res://core/backend.gd")
const Gen = preload("res://puzzles/trestle_gen.gd")
const State = preload("res://puzzles/trestle_state.gd")
const Sim = preload("res://puzzles/trestle_sim.gd")
const Parts = preload("res://ui/faces/trestle_parts.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Locale = preload("res://core/locale.gd")

const PAD := 24.0
## The strip over the scene: the material chips and the budget.
const STRIP_H := 112.0
const CHIP := Vector2(150.0, 92.0)
const CHIP_GAP := 14.0
const CHIP_R := 26.0
const U_CAP := 124.0
## The world the scene shows, in grid units: banks either side of the gap,
## the river under it, room over it for the posts.
const VIEW_SIDE := 1.8
const VIEW_TOP := 4.3
const VIEW_BOTTOM := -5.6
const HIT_JOINT := 0.42
const HIT_MEMBER := 0.2
const HIT_MIN := 34.0
const TAP_PX := 18.0
const GROW_TIME := 0.16
const FAIL_HOLD := 2.0
const WIN_HOLD := 3.0
const HINTS := 3
const TOAST_HOLD := 3.0
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const MAX_STEPS := 8
const CREAK_AT := 0.8
const WORDS := ["TR_W_NICE", "TR_W_GREAT", "TR_W_SUPERB"]
## The convoy: this many carts, `Sim.CONVOY_GAP` apart.
const CONVOY := 3
## The first snap plays at this speed for this long.
const SLOW := 0.3
const SLOW_TIME := 0.9
## How many of the hardest-worked members carry their load in figures.
const LOAD_TAGS := 5
const LOAD_TAG_AT := 0.5
## The polish: how hard a snap and a splash shake the scene (in `_u`), how
## fast the shake dies, and the win's wave and medal.
const SHAKE_SNAP := 0.1
const SHAKE_SPLASH := 0.16
const SHAKE_DECAY := 9.0
const WAVE_TIME := 0.34
const MEDAL_AT := 0.9
const MEDAL_STEP := 0.3
const PENNANTS := [Color("ff6f61"), Color("ffd84d"), Color("5cb8ff"), Color("7fd66a"), Color("b77be6")]
const FIREWORKS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
const FIRST_KEYS :=[["TR_FIRST_ROAD_ONE", "TR_FIRST_ROAD_N"], ["TR_FIRST_WOOD_ONE", "TR_FIRST_WOOD_N"], ["TR_FIRST_ROPE_ONE", "TR_FIRST_ROPE_N"]]
## The strip after the solve and in the free build.
enum Pill { CONVOY, FREE, GO, DONE }

var state: State = State.new()
var sim: Sim = Sim.new()
var fx: Node2D
var _difficulty := 0
var _front: Control
var _rw: Rewards
var _u := 80.0
var _origin := Vector2.ZERO
var _scene := Rect2()
var _still: ArrayMesh
var _frame: ArrayMesh
var _cart_mesh: ArrayMesh
var _wheel_mesh: ArrayMesh
var _front_mesh: ArrayMesh
## The marks that pulse (a hint's gold, a snapped member's red, the first
## pin's call), built with the frame and faded by the draw's modulate, so a
## pulse never rebuilds the bridge.
var _halo: ArrayMesh
## The strip (chips and budget), rebuilt only when what it shows changes.
var _strip_mesh: ArrayMesh
var _strip_for := ""
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
var _shown: Array = []
var _front_shown: Array = []
var _faces: Array[Control] = []
var _mat := Sim.ROAD
## Building: the joint a gesture started on, where it is making for, and the
## joint a tap chose to chain from.
var _from := Vector2i(-99, -99)
var _to := Vector2i(-99, -99)
var _sel := Vector2i(-99, -99)
var _press_at := Vector2.ZERO
var _press_member := -1
var _pressing := false
var _dragging := false
var _grow := {}
var _last_broken := {}
var _testing := false
var _acc := 0.0
var _test_at := -100.0
var _fail_at := -1.0
var _crossed_at := -1.0
var _solved_at := -1.0
var _wheel_turn := 0.0
var _creaked := {}
var _creak_at := -100.0
var _toast := ""
var _toast_args: Array = []
var _toast_at := -100.0
var _opened := 0.0
var _later: Array = []
var _hint_at := -100.0
var _hint_key := Vector4i.ZERO
var _tests := 0
## This test's carts are all over (a solve, or a crossing after one).
var _run_over := false
## The cart's wheels on the planks: a looping voice whose level follows
## whether the cart is rolling (snooker's `_roll_sound`).
var _roll: AudioStreamPlayer
## The stress view carried into building: member key -> the highest share
## of its limit it reached in the last test that ran it (over 1: it snapped).
var _peak := {}
## The member that gave way first in the last test, and when (for the slow).
var _first_key := ""
var _first_at := -100.0
var _loads_told := false
## After the solve: a convoy or a free build running on the solved board.
var _convoy := false
var _free := false
var _solved_design: Array = []
var _convoy_proof := false
var _trail_faces: Array = []
var _cart2_mesh: ArrayMesh
## Today's crowd: "" until asked, "wait", "ok" or "off"; and what came back.
var _crowd_state := ""
var _crowd_pct := -1
var _crowd_count := 0
## The polish (spec section 10): the sky's sun and clouds, moved by transform.
var _sky_mesh: ArrayMesh
var _sun_mesh: ArrayMesh
var _cloud_mesh: ArrayMesh
## The budget bar's fill, eased toward the cost and drawn over the strip
## every frame so it can slide and flash.
var _bar_mesh: ArrayMesh
var _bar_shown := 0.0
var _bar_hit := -100.0
var _money_shake := -100.0
## A chip just picked bounces.
var _chip_at := -100.0
## The screen's shake (px), decaying; never under reduce motion.
var _shake := 0.0
## Members taken down tumble into the river: {p, q, mat, vel, spin, rot, splashed}.
var _falling: Array = []
## Cost figures floating up off a member just laid: {text, at, t, col}.
var _floats: Array = []
## Bolts that just took a member pop: joint -> when.
var _pops := {}
## A dunked cart's passengers float where it went in.
var _splash_at := -100.0
var _splash_x := 0.0
## The win: the wave along the bridge, and when the medal's stars stamp in.
var _wave_at := -100.0
var _dust_at := 0.0

func puzzle_id() -> String: return "trestle"
func title() -> String: return "Trestle"

func rules() -> String:
	return tr("TR_RULES")

## Undo, Hint and Go (the Check button, relabelled); Reset is the host's.
func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func check_label() -> String:
	return "TR_STOP" if _testing else "TR_GO"

func check_icon() -> String:
	return "reset" if _testing else "play"

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
	_rw = Rewards.new()
	_rw.z_index = 4
	add_child(_rw)
	_roll = AudioStreamPlayer.new()
	_roll.volume_db = -80.0
	var roll_path := "res://assets/sfx/trestle/roll.ogg"
	if ResourceLoader.exists(roll_path):
		var stream: AudioStreamOggVorbis = (load(roll_path) as AudioStreamOggVorbis).duplicate()
		stream.loop = true
		_roll.stream = stream
	add_child(_roll)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_difficulty = difficulty
	state.setup(Gen.deal(rng, difficulty))
	_mat = Sim.ROAD
	_testing = false
	_fail_at = -1.0
	_crossed_at = -1.0
	_solved_at = -1.0
	_last_broken = {}
	_grow = {}
	_later = []
	_sel = Vector2i(-99, -99)
	_tests = 0
	_peak = {}
	_first_key = ""
	_loads_told = false
	_convoy = false
	_free = false
	_convoy_proof = false
	_crowd_state = ""
	state.free = false
	_falling = []
	_floats = []
	_pops = {}
	_shake = 0.0
	_splash_at = -100.0
	_wave_at = -100.0
	_bar_shown = 0.0
	_clear_trail()
	if _rw != null:
		_rw.clear()
	for f in _faces:
		f.queue_free()
	_faces = []
	var n := clampi(difficulty + 1, 1, 4)
	for i in n:
		var face := Fruit.make([0, 2, 1, 3][i], 60.0, Vector2.ZERO)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.shadowless = true
		face.set_idle(true)
		add_child(face)
		move_child(face, _front.get_index())
		_faces.append(face)
	sim.setup(state.level, [])
	_opened = _now()
	_layout()
	fx.cue("enter")
	_tell("TR_TIP_START")

# --- layout ---

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return false

func _layout() -> void:
	if size.x <= 0.0 or state.level.is_empty():
		return
	var w := float(state.level.w)
	_scene = Rect2(Vector2(0.0, STRIP_H + PAD), Vector2(size.x, size.y - STRIP_H - PAD))
	var span_x := w + 2.0 * VIEW_SIDE
	var span_y := VIEW_TOP - VIEW_BOTTOM
	_u = minf(U_CAP, minf((_scene.size.x - 2.0 * PAD) / span_x, _scene.size.y / span_y))
	var mid_x := size.x * 0.5
	# the view's middle row sits at the scene's middle
	var mid_y := _scene.position.y + _scene.size.y * 0.5
	_origin = Vector2(mid_x - w * 0.5 * _u, mid_y + (VIEW_TOP + VIEW_BOTTOM) * 0.5 * _u)
	_still = null
	_sun_mesh = null
	_cloud_mesh = null
	_frame = null
	_cart_mesh = null
	_wheel_mesh = null
	for f in _faces:
		Fruit.resize(f, _u * 0.62, Vector2.ZERO)
	for cart in _trail_faces:
		for f in cart:
			Fruit.resize(f, _u * 0.62, Vector2.ZERO)
	_place_cart()
	queue_redraw()
	_front.queue_redraw()

func px(g: Vector2) -> Vector2:
	return _origin + Vector2(g.x, -g.y) * _u

func grid(p: Vector2) -> Vector2:
	var d := (p - _origin) / _u
	return Vector2(d.x, -d.y)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if state.level.is_empty() or size.x <= 0.0:
		return
	var t := _now()
	_run_later(t)
	if _testing:
		_acc += minf(delta, 0.1) * (SLOW if t - _first_at < SLOW_TIME and not Motion.reduce else 1.0)
		var steps := 0
		while _acc >= Sim.DT and steps < MAX_STEPS:
			_acc -= Sim.DT
			steps += 1
			sim.step()
			_events(t)
		if steps == MAX_STEPS:
			_acc = 0.0
		_wheel_turn += (Sim.CART_V * delta) / (Parts.wheel_r(1.0)) if sim.cart != Sim.CART_AIR and sim.cart != Sim.CART_WATER else delta * 2.0
		if sim.done() and _fail_at < 0.0 and not _run_over:
			_failed(t)
	elif _solved_at >= 0.0:
		# the cart rolls on off the card after the win
		sim.cart_pos.x += Sim.CART_V * delta
		_wheel_turn += (Sim.CART_V * delta) / Parts.wheel_r(1.0)
	_roll_sound(delta)
	# the bridge bends while testing and a member grows in as it is laid;
	# otherwise it stands still and its mesh is kept
	for key in _grow.keys():
		if t - float(_grow[key]) > GROW_TIME * 2.0:
			_grow.erase(key)
	if _testing or not _grow.is_empty() or _waving(t):
		_frame = null
	_step_polish(t, delta)
	_place_cart()
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	queue_redraw()
	_front.queue_redraw()

func _roll_sound(delta: float) -> void:
	if _roll == null or _roll.stream == null:
		return
	var rolling := (_testing and sim.cart in [Sim.CART_BANK_L, Sim.CART_ROAD, Sim.CART_BANK_R]) \
		or (_solved_at >= 0.0 and _now() - _solved_at < 1.2)
	var want := 1.0 if rolling else 0.0
	var now := db_to_linear(_roll.volume_db)
	now = move_toward(now, want, delta * (5.0 if want > now else 3.0))
	_roll.volume_db = linear_to_db(maxf(now, 0.0001))
	_roll.pitch_scale = lerpf(1.1, 0.85, clampf((sim.cart_mass - 1.2) / 1.2, 0.0, 1.0))
	if now > 0.002 and not _roll.playing:
		_roll.play()
	elif now <= 0.002 and _roll.playing:
		_roll.stop()

## The polish's own clock: the shake dying away, members taken down falling
## into the river, cost figures rising, bolts popping, dust off the wheels,
## the budget bar sliding to the cost.
func _step_polish(t: float, delta: float) -> void:
	_shake *= exp(-delta * SHAKE_DECAY)
	if _shake < 0.3:
		_shake = 0.0
	var water := px(Vector2(0.0, Sim.WATER)).y
	if not _falling.is_empty():
		var keep: Array = []
		for f: Dictionary in _falling:
			f.age += delta
			var v: Vector2 = f.vel
			v.y += _u * (3.0 if f.splashed else 16.0) * delta
			if f.splashed:
				v *= exp(-delta * 4.0)
			f.vel = v
			f.mid += v * delta
			f.rot += float(f.spin) * delta * (0.3 if f.splashed else 1.0)
			if not f.splashed and (f.mid as Vector2).y > water:
				f.splashed = true
				f.vel = Vector2(v.x * 0.3, _u * 0.6)
				fx.cue("splash", randf_range(1.3, 1.6), -9.0)
				_rw.spray(Vector2((f.mid as Vector2).x, water), Color("cfeefc"), 7, 520.0, "clod", 0.7)
				_rw.ring(Vector2((f.mid as Vector2).x, water), _u * 0.6, Color(1, 1, 1, 0.7))
			if f.age < 4.0 and (f.mid as Vector2).y < water + _u * 3.0:
				keep.append(f)
		_falling = keep
	if not _floats.is_empty():
		for f: Dictionary in _floats:
			f.t += delta
		_floats = _floats.filter(func(f: Dictionary) -> bool: return f.t < 1.1)
	for j in _pops.keys():
		if t - float(_pops[j]) > 0.4:
			_pops.erase(j)
	# dust off the back wheel while the cart rolls
	if _testing and not Motion.reduce and sim.cart in [Sim.CART_BANK_L, Sim.CART_ROAD, Sim.CART_BANK_R] and t - _dust_at > 0.08:
		_dust_at = t
		var xf := _cart_xf()
		var back: Vector2 = Parts.wheel_at(_u, _faces.size())[0]
		_rw.spray(xf * (back + Vector2(-Parts.wheel_r(_u) * 0.6, Parts.wheel_r(_u))), Color("e9dcc4"), 1, 70.0, "mote", 0.8)
	var target := clampf(float(state.cost()) / maxf(1.0, float(state.budget)), 0.0, 1.2)
	_bar_shown = target if Motion.reduce else lerpf(_bar_shown, target, 1.0 - exp(-delta * 9.0))

## A shake of `amount` grid units, adding to one already under way.
func _kick(amount: float) -> void:
	if Motion.reduce:
		return
	_shake = minf(_shake + amount * _u, _u * 0.3)

func _shake_off() -> Vector2:
	if _shake <= 0.0:
		return Vector2.ZERO
	var t := _now()
	return Vector2(sin(t * 71.0) * _shake, cos(t * 53.0) * _shake * 0.8)

## The win's wave along the bridge is running.
func _waving(t: float) -> bool:
	return not Motion.reduce and t - _wave_at < 1.6

## How far the win's wave lifts a point of the bridge: a hump running from
## the near bank to the far one.
func _wave_off(p: Vector2, t: float) -> Vector2:
	if not _waving(t):
		return Vector2.ZERO
	var x0 := px(Vector2.ZERO).x
	var span := maxf(1.0, px(Vector2(float(state.level.w), 0.0)).x - x0)
	var k := t - _wave_at - clampf((p.x - x0) / span, 0.0, 1.0) * 0.8
	if k < 0.0 or k > WAVE_TIME:
		return Vector2.ZERO
	return Vector2(0.0, -sin(k / WAVE_TIME * PI) * _u * 0.24)

## A member taken down: splinters where it was, and it tumbles into the river.
func _drop(d: Dictionary) -> void:
	_splinters(d)
	if Motion.reduce or _falling.size() > 16:
		return
	var p := px(Vector2(d.a))
	var q := px(Vector2(d.b))
	_falling.append({"mid": (p + q) * 0.5, "half": (q - p) * 0.5, "mat": int(d.m), "rot": 0.0,
		"spin": randf_range(-5.0, 5.0), "vel": Vector2(randf_range(-1.0, 1.0) * _u, -_u * randf_range(2.0, 3.5)),
		"splashed": false, "age": 0.0})

## A figure floating up off the scene: a member's price, and the like.
func _float(text: String, at: Vector2, col: Color) -> void:
	if _floats.size() > 8:
		_floats.pop_front()
	_floats.append({"text": text, "at": at, "t": 0.0, "col": col})

func _after(seconds: float, what: Callable) -> void:
	_later.append([_now() + seconds, what])

func _run_later(t: float) -> void:
	if _later.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for it in _later:
		(due if float(it[0]) <= t else keep).append(it)
	_later = keep
	for it in due:
		(it[1] as Callable).call()

## What the sim did this step, in sound and splinters.
func _events(t: float) -> void:
	for e: Dictionary in sim.events:
		match String(e.kind):
			"snap":
				var at := px(e.at)
				if _first_key == "" and int(e.m) >= 0 and int(e.m) < state.design.size():
					# the one that gave way first: ringed now and after, and
					# the moment plays slow
					_first_key = _key(state.design[int(e.m)])
					_first_at = t
					if not Motion.reduce:
						_rw.ring(at, _u * 1.1, Color(Parts.BAD, 0.9))
						_rw.ring(at, _u * 1.6, Color(1, 1, 1, 0.8), 0.08)
					_rw.sticker(tr("TR_W_CRACK"), at + Vector2(0.0, -_u * 0.9), 76, 1.4, false, Color("ff6f61"), true, "crack", _u * 0.4)
				_kick(SHAKE_SNAP)
				fx.cue("snap_rope" if int(e.mat) == Sim.ROPE else "snap", randf_range(0.9, 1.1))
				var col: Color = [Parts.ROAD, Parts.WOOD, Parts.ROPE][int(e.mat)]
				_rw.spray(at, col, 10, 520.0, "confetti", 0.9)
				_rw.spray(at, Color("fff4d8"), 5, 420.0, "spark", 0.8)
				_mood(Face.Expr.WORRIED)
			"leave":
				_mood(Face.Expr.PUZZLED)
				fx.cue("whoa")
			"land":
				fx.puff(px(e.at), Color("e9dcc4"), 6)
				fx.cue("bump")
				_mood(Face.Expr.STRAIN)
			"splash":
				var at := px(e.at)
				fx.cue("splash")
				fx.ring(at, _u * 0.9, Pal.WATER_HI)
				_rw.spray(at, Pal.WATER_HI, 14, 640.0, "spark", 1.1)
				_rw.spray(at, Color.WHITE, 8, 520.0, "spark", 0.8)
				_rw.spray(at, Color("cfeefc"), 18, 1100.0, "clod", 1.0)
				_rw.ring(at, _u * 1.3, Color(Pal.WATER_HI, 0.8))
				_rw.ring(at, _u * 2.0, Color(1, 1, 1, 0.6), 0.12, 0.6)
				_kick(SHAKE_SPLASH)
				if sim.cart == Sim.CART_WATER and _splash_at < _test_at:
					# the lead cart went in: its riders bob up where it did
					_splash_at = t
					_splash_x = at.x
					var far := clampf(sim.cart_pos.x / maxf(1.0, float(state.level.w)), 0.0, 1.0)
					_rw.sticker(tr("TR_W_ALMOST" if far > 0.6 else "TR_W_SPLASH"), Vector2(at.x, at.y - _u * 1.6), 70, 1.6,
						true, Color.WHITE, false, "splash", _u * 0.3)
			"bank":
				_mood(Face.Expr.JOY)
			"over":
				_mood(Face.Expr.JOY)
			"cross":
				var up := _cart_xf() * Vector2(0.0, -_u * 0.7)
				_rw.spray(up, Color("ff7aa2"), 6, 420.0, "heart", 1.0)
				_rw.spray(up, Pal.SUN, 4, 380.0, "note", 1.0)
				_crossed(t)
	sim.events.clear()
	# a member nearing its limit creaks, once, and not too often
	if t - _creak_at > 0.3:
		for k in sim.ma.size():
			if sim.mstub[k] == 1 or sim.malive[k] == 0 or _creaked.has(k):
				continue
			if sim.mratio[k] > CREAK_AT:
				_creaked[k] = true
				_creak_at = t
				fx.cue("creak", randf_range(0.9, 1.1))
				_mood(Face.Expr.WORRIED)
				break

func _mood(e: int) -> void:
	for f in _faces:
		f.expression = e
	for cart in _trail_faces:
		for f in cart:
			f.expression = e

# --- the test ---

## Go: the bridge takes its weight and the cart sets off. Pressed again (Stop),
## back to building.
func check() -> int:
	if is_done():
		return -1
	if _testing:
		_stop()
		fx.cue("undo")
		return -1
	checks += 1
	_start_test(1)
	return -1

## A test of the design as it stands, with `carts` carts.
func _start_test(carts: int) -> void:
	_tests += 1
	_testing = true
	_convoy = carts > 1
	_run_over = false
	_acc = 0.0
	_test_at = _now()
	_fail_at = -1.0
	_solved_at = -1.0
	_creaked = {}
	_last_broken = {}
	_first_key = ""
	_first_at = -100.0
	_sel = Vector2i(-99, -99)
	_pressing = false
	_dragging = false
	sim.setup(state.level, state.for_sim(), carts)
	_clear_trail()
	for i in carts - 1:
		var cart: Array[Control] = []
		for k in 2:
			var face := Fruit.make([1, 3, 0, 2][(2 * i + k) % 4], 60.0, Vector2.ZERO)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.shadowless = true
			face.set_idle(true)
			Fruit.resize(face, _u * 0.62, Vector2.ZERO)
			add_child(face)
			move_child(face, _front.get_index())
			cart.append(face)
		_trail_faces.append(cart)
	_mood(Face.Expr.HAPPY)
	fx.cue("go")
	_rw.sticker(tr("TR_W_GO"), Vector2(size.x * 0.5, _scene.position.y + _u * 1.1), 80, 1.0, true, Color.WHITE, false, "go", _u * 0.3)
	_toast = ""
	_strip_mesh = null
	focus_changed.emit()

func _clear_trail() -> void:
	for cart in _trail_faces:
		for f in cart:
			f.queue_free()
	_trail_faces = []

func _stop() -> void:
	_keep_peaks()
	_testing = false
	_convoy = false
	_fail_at = -1.0
	sim.setup(state.level, [])
	_clear_trail()
	_mood(Face.Expr.HAPPY)
	_frame = null
	_strip_mesh = null
	focus_changed.emit()
	if not _loads_told and not _peak.is_empty() and _last_broken.is_empty():
		_loads_told = true
		_tell("TR_LOADS")

## The highest load each member of the design took in the test just run,
## kept for building (the stress view carried back).
func _keep_peaks() -> void:
	var n := state.design.size()
	for k in sim.ma.size():
		var o := sim.morigin[k]
		if o < 0 or o >= n:
			continue
		_peak[_key(state.design[o])] = sim.mpeak[k]

## A member's name for the maps that outlive a test: its ends and material.
static func _key(d: Dictionary) -> String:
	return "%d,%d,%d,%d,%d" % [d.a.x, d.a.y, d.b.x, d.b.y, int(d.m)]

func _failed(t: float) -> void:
	_fail_at = t
	for m in sim.broken:
		if m >= 0:
			_last_broken[m] = true
	fx.cue("fail")
	_mood(Face.Expr.WORRIED)
	var snapped := _last_broken.size()
	var run := _tests
	var convoy := _convoy
	var timed_out := sim.t >= Sim.TIME_OUT and sim.in_water() == 0
	var first_mat := -1
	if not sim.broken.is_empty() and sim.broken[0] >= 0 and sim.broken[0] < state.design.size():
		first_mat = int(state.design[sim.broken[0]].m)
	_after(FAIL_HOLD, func():
		# a Stop and a new Go inside the hold make this another test's
		if not _testing or _run_over or run != _tests:
			return
		_stop()
		if timed_out:
			_tell("TR_STUCK")
		elif snapped == 0:
			_tell("TR_NO_ROAD")
		elif convoy:
			_tell("TR_CONVOY_FAIL_ONE" if snapped == 1 else "TR_CONVOY_FAIL_N", [] if snapped == 1 else [snapped])
		elif first_mat >= 0:
			_tell(FIRST_KEYS[first_mat][0 if snapped == 1 else 1], [] if snapped == 1 else [snapped - 1])
		elif snapped == 1:
			_tell("TR_SNAPPED_ONE")
		else:
			_tell("TR_SNAPPED_N", [snapped]))

func _crossed(t: float) -> void:
	_run_over = true
	fx.cue("cross")
	_mood(Face.Expr.JOY)
	if not is_done():
		_crossed_at = t
		_keep_peaks()
		check_solved()
		return
	# a crossing after the solve: the convoy, or a free build's test
	var at := Vector2(size.x * 0.5, _scene.position.y + _u * 1.2)
	var run := _tests
	if _convoy:
		var in_budget := state.cost() <= state.budget
		if in_budget:
			_convoy_proof = true
		_rw.sticker(tr("TR_CONVOY_PROOF" if in_budget else "TR_CONVOY_OVER"), at, 84, WIN_HOLD - 0.8, true, Color.WHITE, in_budget)
		if in_budget and not Motion.reduce:
			_rw.rain(1.8, ["confetti", "star"], Rewards.CONFETTI)
		if not in_budget:
			_after(0.5, func(): _rw.sticker(tr("TR_CONVOY_BUDGET"), at + Vector2(0.0, _u * 0.9), 40, WIN_HOLD - 1.3, false, Pal.SUN))
	else:
		_rw.sticker(tr("TR_W_CROSSED"), at, 84, WIN_HOLD - 0.8, true, Color.WHITE)
	_after(WIN_HOLD - 0.6, func():
		if _testing and run == _tests:
			_stop()
			if not _free:
				_rest_over())

func is_solved() -> bool:
	return _crossed_at >= 0.0

func share_glyphs() -> String:
	var stars := "⭐".repeat(_stars())
	var line := "🌉 " + tr("TR_SHARE") % [Locale.number(state.cost()), Locale.number(state.budget), _tests] + " " + stars
	if _convoy_proof:
		line += " 🚚🚚🚚"
	return line

## Three for a bridge as cheap as the day's proof, two for one inside half
## the slack over it, one for any bridge that gets over.
func _stars() -> int:
	var c := state.cost()
	var proof := int(state.level.get("proof_cost", state.budget))
	if c <= proof:
		return 3
	if c <= proof + (state.budget - proof) / 2:
		return 2
	return 1

# --- the win ---

func _on_solved() -> void:
	_solved_at = _now()
	_testing = false
	_solved_design = state.design.duplicate(true)
	_ask_crowd(true)
	_strip_mesh = null
	fx.cue("solved")
	# the medal's row sits over the words, the words over the bridge
	var at := Vector2(size.x * 0.5, _scene.position.y + 185.0)
	_rw.sticker(tr("TR_W_CROSSED"), at, 104, WIN_HOLD, true, Color.WHITE, true, "crossed")
	var left := state.left()
	var stars := _stars()
	_after(0.55, func():
		_rw.sticker(tr("TR_W_UNDER") % Locale.number(left), at + Vector2(0.0, 112.0), 44, WIN_HOLD - 0.6, false, Pal.SUN, false, "under", 0.0, true))
	if stars == 3:
		_after(1.0, func():
			_rw.sticker(tr("TR_W_MASTER"), at + Vector2(0.0, 198.0), 56, WIN_HOLD - 1.0, true, Color.WHITE, false, "master", 0.0, true))
	elif state.hints_placed() == 0:
		_after(1.0, func():
			_rw.sticker(tr(WORDS[clampi(stars - 1, 0, 2)]), at + Vector2(0.0, 198.0), 52, WIN_HOLD - 1.0, false, Color.WHITE, false, "word", 0.0, true))
	# the medal: a star stamped in for each one earned, a hollow one else
	for i in 3:
		_after(MEDAL_AT + MEDAL_STEP * i, func():
			var c := _medal_star(i)
			if i < stars:
				fx.cue("select", 1.15 + 0.2 * i)
				_rw.spray(c, Pal.SUN, 8, 520.0, "star", 0.9)
				_rw.ring(c, 70.0, Color(Pal.SUN, 0.9))
				_kick(0.03))
	if not Motion.reduce:
		_wave_at = _solved_at
		var bank := px(Vector2(float(state.level.w) + 1.0, float(state.level.dy)))
		_rw.spray(bank, Pal.SUN, 16, 900.0, "star", 1.2)
		_rw.spray(bank, Color("fffaf0"), 12, 760.0, "spark", 1.3)
		_rw.spray(bank, Color("ff7aa2"), 8, 600.0, "heart", 1.1)
		_rw.ring(bank, _u * 2.0, Color(Pal.SUN, 0.9))
		_rw.rain(2.6, ["confetti", "star", "confetti"], Rewards.CONFETTI)
		# every member of the bridge twinkles, from the near bank on, with
		# the wave
		var n := state.design.size()
		var x0 := px(Vector2.ZERO).x
		var span := maxf(1.0, px(Vector2(float(state.level.w), 0.0)).x - x0)
		for i in n:
			var d: Dictionary = state.design[i]
			var mid := px(Vector2(d.a + d.b) * 0.5)
			_after(0.1 + clampf((mid.x - x0) / span, 0.0, 1.0) * 0.8, func(): fx.sparkle(mid))
		# fireworks over the sky
		for k in 6:
			var sky := Vector2(size.x * randf_range(0.15, 0.85), _scene.position.y + _scene.size.y * randf_range(0.08, 0.3))
			var col: Color = FIREWORKS[k % FIREWORKS.size()]
			var when := 0.35 + 0.38 * k
			_rw.ring(sky, _u * randf_range(1.0, 1.5), Color(col, 0.9), when, 0.6)
			_rw.spray(sky, col, 12, 820.0, "spark", 1.1, when)
			_rw.spray(sky, col.lightened(0.4), 4, 500.0, "star", 0.8, when)
		# what was left of the budget flies home to the tally as coins
		var coins := clampi(int(left / 150), 3, 18)
		var from := px(Vector2(float(state.level.w) * 0.5, 0.5))
		_rw.spray(from, Rewards.GOLD, coins, 700.0, "coin", 1.1, 1.3, _rw.at(self, Vector2(size.x - PAD - 90.0, 50.0)))

# --- the crowd ---

## Where this bridge's cost stands among today's: the share of `score` a
## bucket of the budget, 0..100. A daily's solve sends it first
## (core/backend.gd queues it, so a solve offline is sent on a later launch);
## then the day's tally comes back and the strip says how many of today's
## bridges cost more. Nothing is asked for a board dealt from New.
func _ask_crowd(send: bool) -> void:
	if daily_key == 0 or not Backend.started():
		return
	var game := "trestle_%d" % _difficulty
	var score := _crowd_score()
	_crowd_state = "wait"
	_strip_mesh = null
	if send:
		await Backend.submit(game, daily_key, {"score": score, "locale": Locale.current()})
	var got: Dictionary = await Backend.tally(game, daily_key)
	if not is_inside_tree():
		return
	_crowd_state = "off"
	if got.get("ok", false):
		var data: Dictionary = got.data
		var hist = data.get("histogram", [])
		var count := int(data.get("count", 0))
		if hist is Array:
			var dearer := 0
			for i in range(score + 1, (hist as Array).size()):
				dearer += int(hist[i])
			_crowd_count = count
			_crowd_pct = int(round(100.0 * dearer / maxf(1.0, float(count))))
			_crowd_state = "ok"
	_strip_mesh = null
	_front.queue_redraw()

func _crowd_score() -> int:
	return clampi(int(round(100.0 * float(state.cost()) / maxf(1.0, float(state.budget)))), 0, 100)

func _crowd_line() -> String:
	match _crowd_state:
		"wait":
			return tr("TR_CROWD_WAIT")
		"ok":
			if _crowd_count < 3:
				return tr("TR_CROWD_FIRST")
			return tr("TR_CROWD_PCT") % [_crowd_pct, Locale.number(_crowd_count)]
	return ""

func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	for i in _faces.size():
		faces.append(Fruit.make([0, 2, 1, 3][i], 130.0, Vector2.ZERO))
	return {"faces": faces, "subtitle": tr("TR_WIN") % [Locale.number(state.cost()), Locale.number(state.budget), "★".repeat(_stars())]}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_HOLD

## Where the medal's star `i` stands.
func _medal_star(i: int) -> Vector2:
	return Vector2(size.x * 0.5 + (i - 1) * 118.0, _scene.position.y + 62.0)

## The medal's three stars, each stamping in on its beat and bowing out with
## the cheer: gold for one earned, a hollow paper one else.
func _draw_medal(b: Face.Builder, t: float) -> void:
	if _solved_at < 0.0 or _free:
		return
	var since := t - _solved_at
	if since > WIN_HOLD + 0.2:
		return
	var out := clampf((WIN_HOLD + 0.2 - since) / 0.3, 0.0, 1.0)
	var stars := _stars()
	for i in 3:
		var k := (since - MEDAL_AT - MEDAL_STEP * i) / 0.32
		if k <= 0.0:
			continue
		var c := _medal_star(i)
		var s := (1.0 if Motion.reduce else Motion.back_out(clampf(k, 0.0, 1.0))) * out
		# stamped from big, turning into place
		var big := 1.0 + (0.0 if Motion.reduce else 1.2 * (1.0 - clampf(k, 0.0, 1.0)))
		var turn := 0.0 if Motion.reduce else (1.0 - clampf(k, 0.0, 1.0)) * 1.4 + sin(since * 3.0 + i) * 0.06
		var r := 50.0 * s * big
		if i < stars:
			b.disc(c, r * 1.25, Color(Pal.SUN, 0.22 * out))
			Rewards.star(b, c, r * 1.1, Color(Pal.PLAQUE_DEEP, out), turn)
			Rewards.star(b, c, r, Color(Rewards.GOLD, out), turn)
		else:
			Rewards.star(b, c, r * 1.1, Color(Pal.TEXT, 0.25 * out), turn)
			Rewards.star(b, c, r, Color(Pal.SURFACE_HI, 0.9 * out), turn)

## The player's own bridge and how many tests it took, kept with the
## completion so a reopened daily shows what they built, not the proof.
func completion_record() -> Dictionary:
	var rows: Array = []
	for d in state.design:
		rows.append([d.a.x, d.a.y, d.b.x, d.b.y, int(d.m), 1 if d.get("hint", false) else 0])
	return {"design": rows, "tests": _tests}

func restore_completed_board() -> void:
	state.design = []
	var rows = completed_record.get("design", [])
	if rows is Array and not (rows as Array).is_empty():
		for r in rows:
			state.design.append({"a": Vector2i(int(r[0]), int(r[1])), "b": Vector2i(int(r[2]), int(r[3])),
				"m": int(r[4]), "hint": int(r[5]) == 1})
		_tests = int(completed_record.get("tests", 1))
	else:
		# a save from before the design was kept
		for p in state.proof:
			state.design.append({"a": p.a, "b": p.b, "m": p.m, "hint": false})
	_solved_design = state.design.duplicate(true)
	_crossed_at = _now() - 100.0
	_toast = ""
	_rest_over()
	_ask_crowd(false)

## The solved bridge standing with the cart over on the far bank: how a
## finished board rests between the post-solve runs.
func _rest_over() -> void:
	if not _solved_design.is_empty():
		state.design = _solved_design.duplicate(true)
	sim.setup(state.level, state.for_sim())
	sim.cart = Sim.CART_OVER
	sim.cart_pos = Vector2(float(state.level.w) + Sim.CART_EXIT, float(state.level.dy))
	_testing = false
	_convoy = false
	_free = false
	state.free = false
	_solved_at = -1.0
	_frame = null
	_strip_mesh = null
	queue_redraw()

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo() and not _testing and not is_done()

func undo() -> bool:
	if _testing or is_done():
		return false
	var u := state.undo()
	if u.is_empty():
		return false
	_frame = null
	_last_broken = {}
	_sel = Vector2i(-99, -99)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	if _difficulty >= 3:
		return 0
	return maxi(0, HINTS + hints_extra - hints_used)

## One member of the day's proof, laid in gold; the player's own members
## furthest from it come down if the budget will not stretch to it.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	if _testing:
		_stop()
	var h := state.apply_hint()
	if h.is_empty():
		_tell("TR_HINT_ALL")
		return false
	hints_used += 1
	_last_broken = {}
	var d: Dictionary = h.d
	_hint_at = _now()
	_hint_key = Vector4i(d.a.x, d.a.y, d.b.x, d.b.y)
	_grow[_hint_key] = _now()
	for r in h.removed:
		_drop(r)
	var mid := px(Vector2(d.a + d.b) * 0.5)
	if not Motion.reduce:
		fx.ring(mid, _u * 0.8, Pal.SUN)
		_rw.spray(mid, Pal.SUN, 10, 620.0, "star", 1.0)
	_tell("TR_HINT_MORE" if not h.removed.is_empty() else "TR_HINT")
	fx.cue("hint")
	_frame = null
	moved.emit()
	return true

func reset_board() -> void:
	if _testing:
		_stop()
	var gone := state.reset()
	for d in gone:
		_drop(d)
	if not gone.is_empty():
		_kick(0.06)
	_last_broken = {}
	_sel = Vector2i(-99, -99)
	_solved_at = -1.0
	_crossed_at = -1.0
	moves = 0
	_running = true
	_frame = null
	fx.cue("reset")
	_tell("TR_CLEARED")

func _splinters(d: Dictionary) -> void:
	if Motion.reduce:
		return
	var mid := px(Vector2(d.a + d.b) * 0.5)
	var col: Color = [Parts.ROAD, Parts.WOOD, Parts.ROPE][int(d.m)]
	_rw.spray(mid, col, 6, 380.0, "confetti", 0.8)

# --- input ---

func _gui_input(event: InputEvent) -> void:
	if state.level.is_empty():
		return
	if _done and not _free:
		# after the solve only the strip's pills answer
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
				return
			_after_press(event.position)
			accept_event()
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _pressing:
		_drag(event.position)
		accept_event()

const NONE := Vector2i(-99, -99)

func _chip_rect(i: int) -> Rect2:
	if _free:
		return _slot(i)
	return Rect2(Vector2(PAD + i * (CHIP.x + CHIP_GAP), (STRIP_H - CHIP.y) * 0.5 + 8.0), CHIP)

## The free build's strip: six even slots, three chips and three pills.
func _slot(i: int) -> Rect2:
	var w := (size.x - 2.0 * PAD - 5.0 * CHIP_GAP) / 6.0
	return Rect2(Vector2(PAD + i * (w + CHIP_GAP), (STRIP_H - CHIP.y) * 0.5 + 8.0), Vector2(w, CHIP.y))

## Where a pill stands: two wide ones after the solve, three slots in the
## free build.
func _pill_rect(p: int) -> Rect2:
	if _free:
		return _slot({Pill.GO: 3, Pill.CONVOY: 4, Pill.DONE: 5}.get(p, 5))
	var font: Font = CozyTheme.body(700)
	var x := PAD
	for q in [Pill.CONVOY, Pill.FREE]:
		var w := maxf(180.0, font.get_string_size(tr(_pill_label(q)), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 44.0)
		if q == p:
			return Rect2(Vector2(x, (STRIP_H - CHIP.y) * 0.5 + 8.0), Vector2(w, CHIP.y))
		x += w + CHIP_GAP
	return Rect2()

## The pills the strip shows now.
func _pills() -> Array:
	if _free:
		return [Pill.GO, Pill.CONVOY, Pill.DONE]
	if is_done():
		# not while the solve is still being cheered
		if _solved_at >= 0.0 and _now() - _solved_at < WIN_HOLD:
			return []
		return [Pill.CONVOY, Pill.FREE]
	return []

func _pill_label(p: int) -> String:
	match p:
		Pill.CONVOY: return "TR_CONVOY"
		Pill.FREE: return "TR_FREE"
		Pill.GO: return "TR_STOP" if _testing else "TR_GO"
	return "TR_DONE"

## A tap after the solve: the convoy or the free build.
func _after_press(p: Vector2) -> void:
	for pill in _pills():
		if _pill_rect(pill).has_point(p):
			_pill(pill)
			return

func _pill(pill: int) -> void:
	match pill:
		Pill.CONVOY:
			if _testing:
				_stop()
			_start_test(CONVOY)
			_tell("TR_CONVOY_TIP")
		Pill.FREE:
			if _testing:
				return
			_free = true
			state.free = true
			sim.setup(state.level, [])
			_solved_at = -1.0
			_frame = null
			_strip_mesh = null
			fx.cue("select")
			_tell("TR_FREE_TIP")
		Pill.GO:
			if _testing:
				_stop()
				fx.cue("undo")
			else:
				_start_test(1)
		Pill.DONE:
			if _testing:
				_stop()
			_last_broken = {}
			_rest_over()
			fx.cue("reset")

func _hit() -> float:
	return maxf(_u * HIT_JOINT, HIT_MIN)

## The joint (or pin) under a point, nearest first.
func _joint_at(p: Vector2) -> Vector2i:
	var best := NONE
	var best_d := _hit()
	for j in state.joints():
		var d := px(Vector2(j)).distance_to(p)
		if d < best_d:
			best_d = d
			best = j
	return best

func _member_at(p: Vector2) -> int:
	var best := -1
	var best_d := maxf(_u * HIT_MEMBER, HIT_MIN * 0.7)
	for i in state.design.size():
		var d: Dictionary = state.design[i]
		var q := Geometry2D.get_closest_point_to_segment(p, px(Vector2(d.a)), px(Vector2(d.b)))
		var dd := q.distance_to(p)
		if dd < best_d:
			best_d = dd
			best = i
	return best

## The point in reach of `from` nearest the finger.
func _aim(from: Vector2i, p: Vector2) -> Vector2i:
	var g := grid(p)
	var best := NONE
	var best_d := INF
	for x in range(from.x - 2, from.x + 3):
		for y in range(from.y - 2, from.y + 3):
			var q := Vector2i(x, y)
			if not Gen.fits(from, q) or not Gen.buildable(state.level, q):
				continue
			var d := Vector2(q).distance_squared_to(g)
			if d < best_d:
				best_d = d
				best = q
	return best

## The buildable point under a tap, if one is near enough.
func _point_at(p: Vector2) -> Vector2i:
	var g := grid(p)
	var q := Vector2i(roundi(g.x), roundi(g.y))
	if px(Vector2(q)).distance_to(p) > _hit() or not Gen.buildable(state.level, q):
		return NONE
	return q

func _press(p: Vector2) -> void:
	for i in 3:
		if _chip_rect(i).has_point(p):
			_pick_mat(i)
			return
	for pill in _pills():
		if _pill_rect(pill).has_point(p):
			_pill(pill)
			return
	if _testing:
		return
	_pressing = true
	_dragging = false
	_press_at = p
	_from = _joint_at(p)
	_to = NONE
	_press_member = -1 if _from != NONE else _member_at(p)

func _pick_mat(i: int) -> void:
	if not state.mats.has(i):
		_tell("TR_NO_ROPE")
		fx.cue("refused")
		return
	if _mat != i:
		_mat = i
		_chip_at = _now()
		fx.cue("select")

func _drag(p: Vector2) -> void:
	if not _dragging and p.distance_to(_press_at) < TAP_PX:
		return
	_dragging = true
	if _from != NONE:
		_to = _aim(_from, p)

func _release(p: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if _dragging:
		# a drag lays a member from the joint it began on, or does nothing
		if _from != NONE and _to != NONE:
			_lay(_from, _to)
		_from = NONE
		_to = NONE
		_dragging = false
		return
	_dragging = false
	# a tap
	if _from != NONE:
		if _sel == _from:
			_sel = NONE
		elif _sel != NONE and Gen.fits(_sel, _from):
			_lay(_sel, _from)
		else:
			_sel = _from
			fx.cue("select", 1.1)
		_from = NONE
		return
	if _sel != NONE:
		var q := _point_at(p)
		if q != NONE:
			_lay(_sel, q)
			return
	if _press_member >= 0:
		var d := state.design[_press_member] as Dictionary
		if d.get("hint", false):
			_tell("TR_HINTED")
			fx.cue("refused")
			return
		var before := state.cost()
		state.remove(_press_member)
		_drop(d)
		_float("+%s" % Locale.number(before - state.cost()), px(Vector2(d.a + d.b) * 0.5), Pal.GOOD)
		_bar_hit = _now()
		fx.cue("remove")
		_frame = null
		_last_broken = {}
		_moved()
		return
	_sel = NONE

## Lays a member of the chosen material from `a` to `b`, or says why not.
func _lay(a: Vector2i, b: Vector2i) -> void:
	var why := state.why_not(a, b, _mat)
	if why == State.Refusal.SAME:
		_sel = b
		return
	if why != State.Refusal.OK:
		fx.cue("refused")
		match why:
			State.Refusal.TOO_LONG: _tell("TR_TOO_LONG")
			State.Refusal.OFF_ZONE: _tell("TR_OFF_ZONE")
			State.Refusal.STEEP: _tell("TR_STEEP")
			State.Refusal.BUDGET:
				_tell("TR_BUDGET_OUT")
				_money_shake = _now()
			_: _tell("TR_NO_ROPE")
		return
	var before := state.cost()
	state.add(a, b, _mat)
	_last_broken = {}
	var now := _now()
	_grow[Vector4i(a.x, a.y, b.x, b.y)] = now
	# the new end lands with a pop, a puff, and its price floating off
	_pops[a] = now
	_pops[b] = now + GROW_TIME * 0.6
	var pb := px(Vector2(b))
	var col: Color = [Parts.ROAD, Parts.WOOD, Parts.ROPE][_mat]
	_after(GROW_TIME * 0.6, func(): _rw.spray(pb, col.lightened(0.2), 5, 300.0, "confetti", 0.6))
	_float("-%s" % Locale.number(state.cost() - before), (px(Vector2(a)) + pb) * 0.5 + Vector2(0.0, -_u * 0.3), Parts.PIN_DEEP)
	_bar_hit = now
	fx.cue(["place_road", "place_wood", "place_rope"][_mat], randf_range(0.95, 1.05))
	_sel = b
	_frame = null
	_moved()

## A move while building; the free build's edits are not the daily's moves.
func _moved() -> void:
	if _free:
		_strip_mesh = null
		return
	note_move()

# --- the drawing ---

func _place_cart() -> void:
	for i in _trail_faces.size():
		if i >= sim.trail.size():
			break
		var c: Dictionary = sim.trail[i]
		var txf := _xf_of(int(c.cart), c.pos, float(c.angle))
		var faces: Array = _trail_faces[i]
		for k in faces.size():
			var at := txf * Parts.seat(_u, faces.size(), k)
			faces[k].position = at - faces[k].size * 0.5
			faces[k].rotation = txf.get_rotation()
			faces[k].visible = int(c.cart) != Sim.CART_WATER or _now() - _fail_at < 0.35
	if _faces.is_empty():
		return
	var xf := _cart_xf()
	var n := _faces.size()
	var bob := 0.0
	var t := _now()
	if _testing and sim.cart != Sim.CART_AIR and not Motion.reduce:
		bob = sin(t * 18.0) * _u * 0.015
	var shake := _shake_off()
	var floating := sim.cart == Sim.CART_WATER and _splash_at >= _test_at
	var water := px(Vector2(0.0, Sim.WATER)).y
	for i in n:
		var at := xf * (Parts.seat(_u, n, i) + Vector2(0.0, bob))
		var rot := xf.get_rotation()
		if floating:
			# they bob up where the cart went in and float, spread out
			var since := t - _splash_at
			var rise := clampf((since - 0.25 - 0.12 * i) / 0.5, 0.0, 1.0)
			var spot := Vector2(_splash_x + (i - (n - 1) * 0.5) * _u * 0.62 + sin(since * 0.8 + i) * _u * 0.08,
				water - _u * 0.12 + sin(since * 3.0 + i * 1.7) * _u * 0.05)
			at = spot + Vector2(0.0, (1.0 - Motion.back_out(rise)) * _u * 0.9)
			rot = sin(since * 2.2 + i) * 0.18
		elif _solved_at >= 0.0:
			# the passengers cheer, a hop each, one after another
			at.y += Motion.hop_lift(fmod(t - _solved_at + 0.15 * i, 0.8), -_u * 0.3, 0.5)
		_faces[i].position = at + shake - _faces[i].size * 0.5
		_faces[i].rotation = rot
		_faces[i].visible = sim.cart != Sim.CART_WATER or floating or t - _fail_at < 0.35

## The cart's frame on the screen: its origin on the road's top.
func _cart_xf() -> Transform2D:
	return _xf_of(sim.cart, sim.cart_pos, sim.cart_angle)

func _xf_of(state_: int, pos: Vector2, angle: float) -> Transform2D:
	var at := px(pos)
	var ang := -angle
	var up := Vector2(0.0, -1.0).rotated(ang)
	var lift := _u * 0.1 if state_ != Sim.CART_AIR else 0.0
	if state_ == Sim.CART_WATER:
		# sinking, and bobbing back up a little
		var since := _now() - _fail_at if _fail_at >= 0.0 else 0.0
		at.y += minf(since, 0.6) * _u * 0.6
	return Transform2D(ang, at + up * lift)

func _draw() -> void:
	if state.level.is_empty() or size.x <= 0.0:
		return
	if _still == null:
		_still = _build_still()
	if _frame == null:
		_frame = _build_frame()
	if _cart_mesh == null:
		var b := Face.Builder.new()
		Parts.cart_body(b, _u, _faces.size())
		_cart_mesh = b.mesh()
		var wb := Face.Builder.new()
		Parts.wheel(wb, _u)
		_wheel_mesh = wb.mesh()
		var b2 := Face.Builder.new()
		Parts.cart_body(b2, _u, 2)
		_cart2_mesh = b2.mesh()
	if _sun_mesh == null:
		_build_sky()
	var t := _now()
	var still := 0.0 if Motion.reduce else 1.0
	var shake := Transform2D(0.0, _shake_off())
	# the sky behind everything: the sun turning, the clouds drifting by
	draw_mesh(_sky_mesh, null)
	draw_mesh(_sun_mesh, null, Transform2D(t * 0.12 * still, _sun_at()))
	var cw := _u * 2.4
	for k in 3:
		var speed := _u * (0.1 + 0.05 * k) * still
		var x := fposmod(size.x * (0.12 + 0.36 * k) + t * speed, size.x + 2.0 * cw) - cw
		var y := _scene.position.y + _scene.size.y * (0.1 + 0.07 * ((k * 2) % 3))
		var s := 0.8 + 0.25 * (k % 2)
		draw_mesh(_cloud_mesh, null, Transform2D(0.0, Vector2(s, s), 0.0, Vector2(x, y)))
	draw_mesh(_still, null, shake)
	if _halo != null:
		var beat := 0.75 + 0.25 * sin(t * 4.5) if not Motion.reduce else 1.0
		draw_mesh(_halo, null, shake, Color(1, 1, 1, beat))
	draw_mesh(_frame, null, shake)
	var xf := shake * _cart_xf()
	draw_mesh(_cart_mesh, null, xf)
	for w in Parts.wheel_at(_u, _faces.size()):
		draw_mesh(_wheel_mesh, null, xf * Transform2D(_wheel_turn, w))
	if _testing:
		for c in sim.trail:
			var txf := shake * _xf_of(int(c.cart), c.pos, float(c.angle))
			draw_mesh(_cart2_mesh, null, txf)
			for w in Parts.wheel_at(_u, 2):
				draw_mesh(_wheel_mesh, null, txf * Transform2D(_wheel_turn, w))
	_shown = [_still, _frame, _cart_mesh, _wheel_mesh, _halo, _cart2_mesh, _sun_mesh, _cloud_mesh, _sky_mesh]

func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var lv := state.level
	var w := float(lv.w)
	var dy := float(lv.dy)
	# the far hills in two bands, trees on the nearer, then the valley's
	# sides running down to the river through the gap
	var horizon := px(Vector2(0.0, 0.8)).y
	var far := PackedVector2Array()
	for k in 25:
		var x := size.x * k / 24.0
		far.append(Vector2(x, horizon - _u * (1.2 + 0.45 * sin(k * 0.7 + 1.0) + 0.2 * sin(k * 1.9))))
	far.append(Vector2(size.x, size.y))
	far.append(Vector2(0.0, size.y))
	b.polygon(far, Color("c3dcc7"))
	var hills := PackedVector2Array()
	for k in 25:
		var x := size.x * k / 24.0
		hills.append(Vector2(x, horizon - _u * (0.5 + 0.35 * sin(k * 0.9) + 0.2 * sin(k * 2.3))))
	hills.append(Vector2(size.x, size.y))
	hills.append(Vector2(0.0, size.y))
	b.polygon(hills, Color("b9d7a4"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + int(lv.w) * 13 + int(dy) * 5
	for k in 14:
		var x := size.x * (k + rng.randf_range(0.1, 0.9)) / 14.0
		var kk := x / size.x * 24.0
		var ground := horizon - _u * (0.5 + 0.35 * sin(kk * 0.9) + 0.2 * sin(kk * 2.3)) + _u * 0.12
		_tree(b, Vector2(x, ground), _u * rng.randf_range(0.26, 0.4), Color("8fb97a") if k % 3 else Color("a3c585"))
	# the valley under the hills, darker as it falls to the river
	_grad(b, Rect2(Vector2(0.0, horizon + _u * 0.2), Vector2(size.x, px(Vector2(0.0, Sim.WATER)).y - horizon)), Color("b9d7a4"), Color("93b88e"))
	# the river: from the water line down, between the banks
	var water := px(Vector2(0.0, Sim.WATER)).y
	_grad(b, Rect2(Vector2(0.0, water), Vector2(size.x, size.y - water)), Color("86cdef"), Color("3a86bd"))
	# the far bank's reflection and the light on the water
	b.fan(Face.Builder.round_rect(Vector2(0.0, water), Vector2(size.x, _u * 0.3), 0.0), Color("a9dcf2"))
	for k in 7:
		var y := water + _u * (0.45 + 0.38 * k)
		var x0 := px(Vector2(0.3 + 0.8 * (k % 3) + 0.4 * (k % 2), 0.0)).x
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + _u * (0.6 + 0.3 * (k % 2)), y)]), _u * 0.045, Color(1, 1, 1, 0.26))
	# pebbles on the bed, glimpsed deep down
	for k in 9:
		var at := Vector2(px(Vector2(rng.randf_range(0.2, w - 0.2), 0.0)).x, water + _u * rng.randf_range(0.6, 1.0))
		b.ellipse(at, _u * rng.randf_range(0.1, 0.2), _u * 0.07, Color("4f93c0"))
	# the banks: grass on top, rock faces down to the river bed
	_bank(b, true, 0.0)
	_bank(b, false, dy)
	var rock = lv.get("rock")
	if rock != null:
		var rx := float(rock[0])
		var top := float(rock[1])
		var poly := PackedVector2Array([px(Vector2(rx - 0.55, Sim.BED)), px(Vector2(rx - 0.42, top - 0.3)),
			px(Vector2(rx - 0.2, top + 0.12)), px(Vector2(rx + 0.25, top + 0.1)), px(Vector2(rx + 0.45, top - 0.35)),
			px(Vector2(rx + 0.6, Sim.BED))])
		b.polygon(poly, Parts.STONE_DEEP)
		var inner := PackedVector2Array()
		for p in poly:
			inner.append(p.lerp(px(Vector2(rx, top - 1.0)), 0.12))
		b.polygon(inner, Parts.STONE)
		b.stroke(PackedVector2Array([px(Vector2(rx - 0.3, top - 0.7)), px(Vector2(rx + 0.1, top - 1.1))]), _u * 0.04, Color(Parts.STONE_DEEP, 0.6))
	# posts on the banks for the high pins
	for a in state.anchors():
		if a.x < 0 or a.x > int(lv.w):
			var ground := 0.0 if a.x < 0 else dy
			var foot := px(Vector2(a.x, ground))
			var head := px(Vector2(a))
			b.stroke(PackedVector2Array([foot + Vector2(0, _u * 0.1), head]), _u * 0.22, Color("7d5334"))
			b.stroke(PackedVector2Array([foot + Vector2(0, _u * 0.1), head]), _u * 0.16, Color("a3794f"))
	# the build dots
	for x in range(1, int(lv.w)):
		for y in range(Gen.LO, Gen.HI + 1):
			var q := Vector2i(x, y)
			if Gen.buildable(lv, q):
				b.disc(px(Vector2(q)), _u * 0.035, Color(Pal.TEXT, 0.16))
	# the water line
	b.stroke(PackedVector2Array([Vector2(px(Vector2(0.0, 0.0)).x, water), Vector2(px(Vector2(w, 0.0)).x, water)]), _u * 0.05, Color(1, 1, 1, 0.55))
	return b.mesh()

## One bank: grass on its top, a dirt road along it, a rock face down to the
## bed, from the card's edge to the gap.
func _bank(b: Face.Builder, left: bool, top: float) -> void:
	var w := float(state.level.w)
	var edge := 0.0 if left else size.x
	var lip := px(Vector2(0.0 if left else w, top))
	var bed := size.y + 4.0
	var face := PackedVector2Array()
	var dir := 1.0 if left else -1.0
	face.append(Vector2(edge, lip.y))
	face.append(lip)
	for k in 7:
		var y := lip.y + (bed - lip.y) * (k + 1) / 7.0
		face.append(Vector2(lip.x - dir * _u * (0.08 + 0.1 * sin(k * 1.7 + (0.0 if left else 2.0))), y))
	face.append(Vector2(edge, bed))
	b.polygon(face, Color("b89a78"))
	# strata: a paler band and a darker one across the face
	for k in 3:
		var y := lip.y + _u * (0.9 + 1.25 * k)
		var band := PackedVector2Array()
		for s in 9:
			var x := lerpf(edge, lip.x - dir * _u * 0.12, s / 8.0)
			band.append(Vector2(x, y + sin(s * 1.3 + k) * _u * 0.08))
		b.stroke(band, _u * (0.28 if k % 2 == 0 else 0.16), Color("c7ab88") if k % 2 == 0 else Color("a88a68"), false, false)
	for k in 5:
		var y := lip.y + _u * (0.7 + 0.9 * k)
		var x := lip.x - dir * _u * (0.5 + 0.4 * (k % 2))
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x - dir * _u * 0.6, y + _u * 0.1)]), _u * 0.04, Color("9c7f60"))
	# stones set in the face
	for k in 4:
		var at := Vector2(lip.x - dir * _u * (0.9 + 0.55 * k), lip.y + _u * (1.4 + 0.95 * ((k * 3) % 4)))
		b.ellipse(at + Vector2(0, _u * 0.04), _u * 0.2, _u * 0.13, Color("8d7358"))
		b.ellipse(at, _u * 0.19, _u * 0.12, Color("cdb89a"))
		b.ellipse(at + Vector2(-_u * 0.05, -_u * 0.04), _u * 0.07, _u * 0.035, Color(1, 1, 1, 0.35))
	# reeds where the face meets the water
	var water := px(Vector2(0.0, Sim.WATER)).y
	for k in 5:
		var x := lip.x - dir * _u * (0.05 + 0.13 * k)
		var tall := _u * (0.35 + 0.18 * ((k * 2) % 3))
		b.stroke(PackedVector2Array([Vector2(x, water + _u * 0.1), Vector2(x + dir * _u * 0.06, water - tall)]), _u * 0.035, Color("6f9440"))
		if k % 2 == 0:
			b.ellipse(Vector2(x + dir * _u * 0.05, water - tall + _u * 0.06), _u * 0.035, _u * 0.09, Color("8a5a3a"))
	# grass and road on top
	var grass := Rect2(Vector2(minf(edge, lip.x), lip.y - _u * 0.05), Vector2(absf(lip.x - edge), _u * 0.32))
	b.fan(Face.Builder.round_rect(grass.position, grass.size, _u * 0.08), Color("8cb050"))
	b.fan(Face.Builder.round_rect(grass.position + Vector2(0, _u * 0.18), Vector2(grass.size.x, _u * 0.14), _u * 0.04), Color("6f9440"))
	var road := Rect2(Vector2(minf(edge, lip.x), lip.y - _u * 0.1), Vector2(absf(lip.x - edge), _u * 0.12))
	b.fan(Face.Builder.round_rect(road.position, road.size, _u * 0.05), Color("d9c49a"))
	# a bush and a tree back from the edge, and flowers in the grass
	var reach := absf(lip.x - edge)
	if reach > _u * 1.4:
		var bush := Vector2(lip.x - dir * minf(reach - _u * 0.3, _u * 1.5), lip.y - _u * 0.12)
		_tree(b, bush + Vector2(-dir * _u * 0.35, 0.0), _u * 0.5, Color("7fae62"))
		for s in 3:
			b.disc(bush + Vector2((s - 1) * _u * 0.2, -_u * (0.12 + 0.08 * (1 - absi(s - 1)))), _u * (0.2 + 0.05 * (1 - absi(s - 1))), Color("6f9f52"))
		b.disc(bush + Vector2(-_u * 0.06, -_u * 0.26), _u * 0.1, Color("8fc070"))
	for k in 6:
		var x := lip.x - dir * _u * (0.35 + 0.42 * k)
		if absf(x - edge) < _u * 0.2:
			continue
		var at := Vector2(x, lip.y + _u * 0.12)
		var col: Color = PENNANTS[(k + (0 if left else 2)) % PENNANTS.size()]
		for p in 4:
			b.disc(at + Vector2.from_angle(TAU * p / 4.0) * _u * 0.035, _u * 0.03, Color(col.lightened(0.3), 0.9))
		b.disc(at, _u * 0.022, Color("fff4c2"))
	# tufts
	for k in 4:
		var x := lip.x - dir * _u * (0.6 + 0.6 * k)
		var y := lip.y - _u * 0.1
		for s in 3:
			b.stroke(PackedVector2Array([Vector2(x + (s - 1) * _u * 0.05, y), Vector2(x + (s - 1) * _u * 0.09, y - _u * 0.14)]), _u * 0.03, Color("6f9440"))

## A round tree standing on `foot`, its canopy `r` across.
static func _tree(b: Face.Builder, foot: Vector2, r: float, col: Color) -> void:
	b.stroke(PackedVector2Array([foot, foot + Vector2(0.0, -r * 1.3)]), r * 0.22, Color("8a6a4a"))
	var c := foot + Vector2(0.0, -r * 1.55)
	b.disc(c + Vector2(r * 0.05, r * 0.08), r * 0.95, col.darkened(0.15))
	b.disc(c, r * 0.9, col)
	b.disc(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, col.lightened(0.18))

## Where the sun stands in the sky.
func _sun_at() -> Vector2:
	return Vector2(size.x * 0.84, _scene.position.y + _scene.size.y * 0.13)

## The sky's three meshes: the sky itself with the far mountains, the sun
## (built round its middle and turned by the transform), and one cloud
## (drawn three times, drifting).
func _build_sky() -> void:
	var b := Face.Builder.new()
	_grad(b, Rect2(Vector2.ZERO, size), Color("9fd4f0"), Color("f6ecd6"))
	# a warm glow low in the sky
	var horizon := px(Vector2(0.0, 0.8)).y
	_grad(b, Rect2(Vector2(0.0, horizon - _u * 3.0), Vector2(size.x, _u * 3.0)), Color("f6ecd6", 0.0), Color("fbe3b8", 0.8))
	# far blue mountains with snow on their heads
	var peaks := [Vector2(0.1, 2.9), Vector2(0.33, 3.6), Vector2(0.55, 2.7), Vector2(0.78, 3.3), Vector2(1.0, 2.6)]
	for p: Vector2 in peaks:
		var top := Vector2(size.x * p.x, horizon - _u * p.y)
		var half := _u * (2.2 + p.y * 0.5)
		b.polygon(PackedVector2Array([top, top + Vector2(half, _u * p.y + _u * 0.2), top + Vector2(-half, _u * p.y + _u * 0.2)]), Color("b4cfe0"))
		var cap := 0.26
		b.polygon(PackedVector2Array([top, top + Vector2(half * cap, _u * p.y * cap), top + Vector2(half * cap * 0.4, _u * p.y * cap * 0.8),
			top + Vector2(0.0, _u * p.y * cap * 1.1), top + Vector2(-half * cap * 0.5, _u * p.y * cap * 0.8), top + Vector2(-half * cap, _u * p.y * cap)]), Color("f4f8fb"))
	_sky_mesh = b.mesh()
	var s := Face.Builder.new()
	var r := _u * 0.55
	s.disc(Vector2.ZERO, r * 2.1, Color("fff4c2", 0.25))
	Rewards.sunrays(s, Vector2.ZERO, r * 1.05, r * 1.75, 12, 0.0, Color("ffe39a", 0.75))
	s.disc(Vector2.ZERO, r * 1.08, Color("f7c65a"))
	s.disc(Vector2.ZERO, r, Color("ffd96e"))
	s.disc(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.35))
	_sun_mesh = s.mesh()
	var c := Face.Builder.new()
	var ch := _u
	c.ellipse(Vector2(0.0, ch * 0.18), ch * 1.1, ch * 0.2, Color(0.55, 0.7, 0.85, 0.18))
	for k in 4:
		var at := Vector2((k - 1.5) * ch * 0.45, -ch * 0.12 * (1.0 - absf(k - 1.5) * 0.5))
		c.disc(at, ch * (0.36 + 0.1 * (1.0 - absf(k - 1.5) * 0.6)), Color("fbfdff"))
	c.fan(Face.Builder.round_rect(Vector2(-ch * 0.95, -ch * 0.05), Vector2(ch * 1.9, ch * 0.3), ch * 0.15), Color("fbfdff"))
	_cloud_mesh = c.mesh()

static func _grad(b: Face.Builder, r: Rect2, top: Color, bottom: Color) -> void:
	var i0 := b.vertex(r.position, top)
	var i1 := b.vertex(r.position + Vector2(r.size.x, 0.0), top)
	var i2 := b.vertex(r.position + r.size, bottom)
	var i3 := b.vertex(r.position + Vector2(0.0, r.size.y), bottom)
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## The bridge: the design while building (with a member just laid growing out
## of its first end), the sim's members while testing (tinted by their load),
## then the bolts and the pins over them.
func _build_frame() -> ArrayMesh:
	var b := Face.Builder.new()
	var hb := Face.Builder.new()
	var halos := 0
	var t := _now()
	var joints := {}
	if _testing or (_crossed_at >= 0.0 and sim.ma.size() > 0):
		# rope, then wood, then road, so the deck is on top
		for pass_mat in [Sim.ROPE, Sim.WOOD, Sim.ROAD]:
			for k in sim.ma.size():
				if sim.malive[k] == 0 or sim.mmat[k] != pass_mat:
					continue
				var p := px(sim.jp[sim.ma[k]])
				var q := px(sim.jp[sim.mb[k]])
				p += _wave_off(p, t)
				q += _wave_off(q, t)
				var tint := Parts.stress(sim.mratio[k]) if sim.mstub[k] == 0 else Color(Parts.BAD, 0.3)
				Parts.member(b, p, q, pass_mat, _u, tint)
				if sim.mstub[k] == 0:
					joints[sim.ma[k]] = p
					joints[sim.mb[k]] = q
		for j in joints:
			if sim.jfix[j] == 0:
				Parts.joint(b, joints[j], _u)
	else:
		var order := range(state.design.size())
		order.sort_custom(func(i: int, j: int) -> bool: return _layer(state.design[i].m) < _layer(state.design[j].m))
		for i in order:
			var d: Dictionary = state.design[i]
			var p := px(Vector2(d.a))
			var q := px(Vector2(d.b))
			var key := Vector4i(d.a.x, d.a.y, d.b.x, d.b.y)
			if _grow.has(key):
				var k := clampf((t - float(_grow[key])) / GROW_TIME, 0.0, 1.0)
				if k >= 1.0:
					_grow.erase(key)
				else:
					q = p.lerp(q, Motion.back_out(k) if not Motion.reduce else 1.0)
			var k := _key(d)
			if _last_broken.has(i):
				hb.stroke(PackedVector2Array([p, q]), _u * 0.48, Color(Parts.BAD, 0.6))
				halos += 1
				if k == _first_key:
					# the first to go: ringed at its middle
					var mid := (p + q) * 0.5
					hb.stroke(Face.Builder.arc_points(mid, _u * 0.42, 0.0, TAU), _u * 0.07, Parts.BAD, true)
					hb.stroke(Face.Builder.arc_points(mid, _u * 0.3, 0.0, TAU), _u * 0.035, Color.WHITE, true)
			if d.get("hint", false):
				hb.stroke(PackedVector2Array([p, q]), _u * 0.32, Color(Pal.SUN, 0.35))
				halos += 1
			# the load it took in the last test, a little softer than live
			var tint := Parts.stress(float(_peak.get(k, 0.0)))
			tint.a *= 0.8
			Parts.member(b, p, q, int(d.m), _u, tint)
			joints[d.a] = p
			joints[d.b] = px(Vector2(d.b))
		for j in joints:
			if not state.is_anchor(j):
				Parts.joint(b, joints[j], _u)
	for a in state.anchors():
		if not _testing and state.design.is_empty() and a == Vector2i(0, 0):
			# the first pin calls: this is where the road starts
			hb.disc(px(Vector2(a)), _u * 0.3, Color(Pal.SUN, 0.4))
			halos += 1
		Parts.anchor(b, px(Vector2(a)), _u)
	_halo = hb.mesh() if halos > 0 else null
	return b.mesh()

static func _layer(m: int) -> int:
	return [2, 1, 0][m]

func _draw_front() -> void:
	if state.level.is_empty() or size.x <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	var b := Face.Builder.new()
	var water := px(Vector2(0.0, Sim.WATER)).y
	var x0 := px(Vector2(0.0, 0.0)).x
	var x1 := px(Vector2(float(state.level.w), 0.0)).x
	var calm := not Motion.reduce
	# members taken down, tumbling in and sinking under the water's face
	for f: Dictionary in _falling:
		var half := (f.half as Vector2).rotated(f.rot)
		var fade := clampf(1.0 - ((f.mid as Vector2).y - water) / (_u * 2.5), 0.0, 1.0) if f.splashed else 1.0
		Parts.member(b, f.mid - half, f.mid + half, int(f.mat), _u, Color(0, 0, 0, 0), fade)
	# a fish leaps now and then while the river is quiet
	if calm and not _testing:
		var cycle := 6.3
		var n := floori((t + 2.0) / cycle)
		var k := (fmod(t + 2.0, cycle)) / 0.95
		if k < 1.0:
			var fx0 := lerpf(x0 + _u * 0.6, x1 - _u * 1.6, fposmod(float(n) * 0.618, 1.0))
			var dirx := 1.0 if n % 2 == 0 else -1.0
			var at := Vector2(fx0 + dirx * k * _u * 1.2, water - sin(k * PI) * _u * 1.1)
			var ang := atan2(-cos(k * PI) * PI * 1.1, dirx * 1.2)
			_fish(b, at, _u * 0.24, ang, dirx)
			for e in [0.0, 1.0]:
				var since := absf(k - e)
				if since < 0.35:
					var rr := _u * (0.15 + since * 1.4)
					b.stroke(Face.Builder.ring(Vector2(fx0 + dirx * e * _u * 1.2, water), rr, rr * 0.3), _u * 0.03, Color(1, 1, 1, 0.7 * (1.0 - since / 0.35)), true)
	# the water's face, over anything that fell in
	var wave := PackedVector2Array()
	for k in 17:
		var x := lerpf(x0 - _u * 0.2, x1 + _u * 0.2, k / 16.0)
		wave.append(Vector2(x, water + sin(k * 1.3 + (0.0 if Motion.reduce else t * 2.0)) * _u * 0.03))
	wave.append(Vector2(x1 + _u * 0.2, size.y))
	wave.append(Vector2(x0 - _u * 0.2, size.y))
	b.polygon(wave, Color(0.35, 0.62, 0.82, 0.55))
	# glints on the water, winking in and out
	for k in 9:
		var ph := sin(t * (1.3 + 0.17 * k) + k * 2.1) if calm else 0.6
		if ph <= 0.2:
			continue
		var gx := lerpf(x0, x1, fposmod(k * 0.377 + 0.05, 1.0))
		var gy := water + _u * (0.12 + 0.13 * (k % 4))
		var gl := _u * (0.12 + 0.1 * (k % 3)) * ph
		b.stroke(PackedVector2Array([Vector2(gx - gl, gy), Vector2(gx + gl, gy)]), _u * 0.035, Color(1, 1, 1, 0.55 * ph))
	# birds gliding over, now and then
	if calm:
		var fly := fmod(t + 5.0, 13.0)
		if fly < 7.0:
			for i in 2:
				var bx := lerpf(-_u, size.x + _u, fly / 7.0) - i * _u * 0.7
				var by := _scene.position.y + _scene.size.y * 0.2 + i * _u * 0.35 + sin(fly * 1.5 + i) * _u * 0.12
				var flap := sin(t * 9.0 + i * 1.3) * _u * 0.12
				b.stroke(PackedVector2Array([Vector2(bx - _u * 0.22, by - flap), Vector2(bx, by + _u * 0.04), Vector2(bx + _u * 0.22, by - flap)]),
					_u * 0.045, Color("5a6070", 0.8))
	# bunting over the solved deck, dropped in along the wave
	if _crossed_at >= 0.0 and not _testing:
		_bunting(b, t)
	# the bolts a member was just laid to pop
	for j in _pops:
		var k := (t - float(_pops[j])) / 0.3
		if k < 0.0 or k > 1.0:
			continue
		var s := 1.0 + 0.7 * sin(k * PI) if calm else 1.0
		b.disc(px(Vector2(j)), _u * 0.1 * s, Color(1, 0.95, 0.75, 0.5 * (1.0 - k)))
		Parts.joint(b, px(Vector2(j)), _u * s)
	_draw_medal(b, t)
	# building: where the finger reaches, the ghost member, the chosen joint
	if not _testing and (not is_done() or _free):
		var from := _from if _dragging and _from != NONE else _sel
		if from != NONE:
			for x in range(from.x - 2, from.x + 3):
				for y in range(from.y - 2, from.y + 3):
					var q := Vector2i(x, y)
					if Gen.fits(from, q) and Gen.buildable(state.level, q):
						b.disc(px(Vector2(q)), _u * 0.07, Color(Pal.SUN, 0.55))
			var pulse := 0.5 + 0.5 * sin(t * 6.0) if not Motion.reduce else 1.0
			b.stroke(Face.Builder.arc_points(px(Vector2(from)), _u * (0.2 + 0.03 * pulse), 0.0, TAU), _u * 0.05, Pal.SUN, true)
		if _dragging and _from != NONE and _to != NONE:
			var ok := state.why_not(_from, _to, _mat)
			var good := ok == State.Refusal.OK
			var tint := Color(0, 0, 0, 0) if good else Color(Parts.BAD, 0.7)
			Parts.member(b, px(Vector2(_from)), px(Vector2(_to)), _mat, _u, tint, 0.75)
	var tags := _load_tags() if not _testing and (not is_done() or _free or not _last_broken.is_empty()) else []
	for tag in tags:
		b.fan(Face.Builder.round_rect(tag.rect.position, tag.rect.size, tag.rect.size.y * 0.5), Color(Pal.SURFACE, 0.92))
		b.stroke(Face.Builder.round_rect(tag.rect.position, tag.rect.size, tag.rect.size.y * 0.5), 3.0, tag.col, true)
	_front_mesh = b.mesh()
	_front.draw_mesh(_front_mesh, null, Transform2D(0.0, _shake_off()))
	shown.append(_front_mesh)
	_draw_floats()
	var tag_font: Font = CozyTheme.body(700)
	for tag in tags:
		_front.draw_string(tag_font, tag.rect.position + Vector2(10.0, tag.rect.size.y * 0.5 + tag_font.get_ascent(22) * 0.36), tag.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.TEXT)
	if t - _chip_at < 0.4:
		# a chip just picked is bouncing
		_strip_mesh = null
	var strip_key := "%d|%d|%d|%s|%s|%s|%s|%s|%d" % [state.cost(), _mat, state.budget, size, _free, is_done(), _testing, _crowd_state, _pills().size()]
	if _strip_mesh == null or _strip_for != strip_key:
		_strip_mesh = _build_strip()
		_strip_for = strip_key
	_front.draw_mesh(_strip_mesh, null)
	shown.append(_strip_mesh)
	if not is_done() and not _free:
		_bar_mesh = _build_bar(t)
		_front.draw_mesh(_bar_mesh, null)
		shown.append(_bar_mesh)
	_draw_words()
	_draw_toast(t, shown)
	_front_shown = shown

## The hardest-worked members of the last test, in figures: a paper tag at
## each one's middle saying the share of its limit it reached.
func _load_tags() -> Array:
	var ranked: Array = []
	for d in state.design:
		var r := float(_peak.get(_key(d), 0.0))
		if r >= LOAD_TAG_AT:
			ranked.append([r, d])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var out: Array = []
	var font: Font = CozyTheme.body(700)
	for e in ranked:
		if out.size() >= LOAD_TAGS:
			break
		var r: float = e[0]
		var d: Dictionary = e[1]
		var text := "%d%%" % mini(999, int(round(r * 100.0)))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 20.0
		var mid := px(Vector2(d.a + d.b) * 0.5)
		var col := Parts.stress(r)
		var rect := Rect2(mid - Vector2(w, 34.0) * 0.5, Vector2(w, 34.0))
		# a tag that would sit on a harder-worked one's is left out
		var clear := true
		for o in out:
			if (o.rect as Rect2).grow(4.0).intersects(rect):
				clear = false
				break
		if clear:
			out.append({"rect": rect, "text": text, "col": Color(col, 1.0) if col.a > 0.0 else Pal.TEXT_DIM})
	return out

## The strip: a paper band, the chips, the budget bar and the proof's star.
func _build_strip() -> ArrayMesh:
	var b := Face.Builder.new()
	var strip := Rect2(Vector2(PAD * 0.5, 8.0), Vector2(size.x - PAD, STRIP_H))
	b.fan(Face.Builder.round_rect(strip.position + Vector2(0, 4), strip.size, 30.0), Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(strip.position, strip.size, 30.0), Color(Pal.SURFACE, 0.94))
	for pill in _pills():
		var r := _pill_rect(pill)
		var hot: bool = pill == Pill.CONVOY or (pill == Pill.GO and not _testing)
		b.fan(Face.Builder.round_rect(r.position + Vector2(0, 5), r.size, CHIP_R), Color(Pal.TEXT, 0.14))
		b.fan(Face.Builder.round_rect(r.position, r.size, CHIP_R), Pal.SUN_TILE if hot else Pal.SURFACE_HI)
		if hot:
			b.stroke(Face.Builder.round_rect(r.position, r.size, CHIP_R), 4.0, Pal.SUN, true)
	if is_done() and not _free:
		return b.mesh()
	for i in 3:
		var r := _chip_rect(i)
		var on := i == _mat
		var there := state.mats.has(i)
		var lift := _chip_lift(i)
		b.fan(Face.Builder.round_rect(r.position + Vector2(0, 5), r.size, CHIP_R), Color(Pal.TEXT, 0.14 if there else 0.05))
		b.fan(Face.Builder.round_rect(r.position - Vector2(0, lift), r.size, CHIP_R), Pal.SUN_TILE if on else Pal.SURFACE_HI)
		if on:
			b.stroke(Face.Builder.round_rect(r.position - Vector2(0, lift), r.size, CHIP_R), 4.0, Pal.SUN, true)
		var mid := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.36 - lift)
		Parts.member(b, mid - Vector2(r.size.x * 0.3, 0), mid + Vector2(r.size.x * 0.3, 0), i, 70.0, Color(0, 0, 0, 0), 1.0 if there else 0.3)
	if _free:
		return b.mesh()
	# the budget bar
	var bar := _budget_rect()
	b.fan(Face.Builder.round_rect(bar.position + Vector2(0, 2), bar.size, bar.size.y * 0.5), Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(bar.position, bar.size, bar.size.y * 0.5), Pal.SURFACE_HI)
	return b.mesh()

## The budget bar's fill, eased to the cost, flashing as it moves, and the
## proof's star, which shines while the bridge is as cheap as the proof.
## Built every frame over the strip.
func _build_bar(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var bar := _budget_rect()
	var spent := clampf(_bar_shown, 0.0, 1.0)
	var col := Pal.GOOD if spent < 0.8 else (Parts.WARN if spent < 0.95 else Parts.BAD)
	if spent > 0.005:
		var fill := Vector2(maxf(bar.size.y, bar.size.x * spent), bar.size.y)
		b.fan(Face.Builder.round_rect(bar.position, fill, bar.size.y * 0.5), col)
		b.fan(Face.Builder.round_rect(bar.position + Vector2(6.0, 3.0), Vector2(maxf(0.0, fill.x - 12.0), bar.size.y * 0.3), bar.size.y * 0.15), Color(1, 1, 1, 0.35))
		var hit := t - _bar_hit
		if hit < 0.4 and not Motion.reduce:
			# the leading edge flashes as the bar moves
			var edge := Vector2(bar.position.x + fill.x - bar.size.y * 0.5, bar.get_center().y)
			b.disc(edge, bar.size.y * (0.6 + 0.8 * hit), Color(1, 1, 1, 0.6 * (1.0 - hit / 0.4)))
	var proof := float(state.level.get("proof_cost", 0))
	if proof > 0.0:
		var at := Vector2(bar.position.x + bar.size.x * clampf(proof / float(state.budget), 0.0, 1.0), bar.get_center().y)
		var cheap := state.cost() > 0 and state.cost() <= int(proof)
		var turn := sin(t * 2.0) * 0.15 if cheap and not Motion.reduce else 0.0
		var r := 12.0 + (2.0 + 1.5 * sin(t * 5.0) if cheap and not Motion.reduce else 0.0)
		if cheap:
			b.disc(at, r * 1.7, Color(Pal.SUN, 0.3))
		Rewards.star(b, at, r + 3.0, Pal.PLAQUE_DEEP, turn)
		Rewards.star(b, at, r, Pal.SUN, turn)
	return b.mesh()

func _draw_words() -> void:
	var bar := _budget_rect()
	var font: Font = CozyTheme.body(700)
	for pill in _pills():
		var r := _pill_rect(pill)
		var word := tr(_pill_label(pill))
		var pfs := 28
		while pfs > 18 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x > r.size.x - 20.0:
			pfs -= 2
		var psz := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs)
		_front.draw_string(font, Vector2(r.position.x + (r.size.x - psz.x) * 0.5, r.get_center().y + font.get_ascent(pfs) * 0.36), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Pal.TEXT)
	if is_done() and not _free:
		# the bridge's cost, its stars, and where it stands today
		var right := size.x - PAD - 8.0
		var left := _pill_rect(Pill.FREE).end.x + 20.0
		var cost := "%s / %s  %s" % [Locale.number(state.cost()), Locale.number(state.budget), "★".repeat(_stars())]
		var cfs := 32
		var csz := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs)
		_front.draw_string(font, Vector2(right - csz.x, 58.0), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Pal.TEXT)
		var crowd := _crowd_line()
		if crowd != "":
			var body: Font = CozyTheme.body(600)
			var fs := 22
			while fs > 16 and body.get_string_size(crowd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > right - left:
				fs -= 1
			var sz := body.get_string_size(crowd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			_front.draw_string(body, Vector2(right - sz.x, 96.0), crowd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT_DIM)
		return
	if _free:
		var cost := tr("TR_COST") % [Locale.number(state.cost()), Locale.number(state.budget)]
		var body: Font = CozyTheme.body(600)
		var sz := body.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		_front.draw_string(body, Vector2(size.x - PAD - sz.x, STRIP_H + 44.0), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
			Pal.TEXT_DIM if state.cost() <= state.budget else Parts.BAD)
	for i in 3:
		var r := _chip_rect(i)
		var there := state.mats.has(i)
		var lift := _chip_lift(i)
		var name := tr(["TR_MAT_ROAD", "TR_MAT_WOOD", "TR_MAT_ROPE"][i])
		var fs := 24
		var sz := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_front.draw_string(font, Vector2(r.position.x + (r.size.x - sz.x) * 0.5, r.end.y - 16.0 - lift), name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, 1.0 if there else 0.35))
	if _free:
		return
	var money := "%s / %s" % [Locale.number(state.cost()), Locale.number(state.budget)]
	var mfs := 34
	var msz := font.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs)
	# the figure kicks when the cost moves and shakes red when it is out
	var now := _now()
	var shake := now - _money_shake
	var kick := now - _bar_hit
	var mcol := Pal.TEXT
	var moff := Vector2.ZERO
	if shake < 0.5:
		mcol = Parts.BAD
		if not Motion.reduce:
			moff.x = sin(shake * 60.0) * 8.0 * (1.0 - shake / 0.5)
	elif kick < 0.25 and not Motion.reduce:
		moff.y = -sin(kick / 0.25 * PI) * 7.0
	_front.draw_string(font, Vector2(bar.end.x - msz.x, bar.position.y - 18.0) + moff, money, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, mcol)
	var lbl := tr("TR_BUDGET")
	_front.draw_string(CozyTheme.body(600), Vector2(bar.position.x, bar.position.y - 18.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.TEXT_DIM)

## How high chip `i` stands: the chosen one lifted, bouncing when just picked.
func _chip_lift(i: int) -> float:
	if i != _mat:
		return 0.0
	var k := (_now() - _chip_at) / 0.35
	if Motion.reduce or k >= 1.0 or k < 0.0:
		return 4.0
	return 4.0 + sin(k * PI) * 12.0 * (1.0 - k * 0.5)

## The cost figures rising off the scene and fading.
func _draw_floats() -> void:
	if _floats.is_empty():
		return
	var font: Font = CozyTheme.display(700)
	for f: Dictionary in _floats:
		var k := float(f.t) / 1.1
		var a := clampf((1.0 - k) / 0.4, 0.0, 1.0)
		var pop := Motion.back_out(clampf(k / 0.25, 0.0, 1.0)) if not Motion.reduce else 1.0
		var fs := int(40 * maxf(0.3, pop))
		var text: String = f.text
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at: Vector2 = (f.at as Vector2) + Vector2(-sz.x * 0.5, -_u * 0.9 * k + fs * 0.35)
		_front.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(Color("fffaf0"), a))
		_front.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f.col, a))

## A leaping fish, facing `dirx`, turned by `ang`.
static func _fish(b: Face.Builder, at: Vector2, r: float, ang: float, dirx: float) -> void:
	# facing left the turn is near a half, so y is flipped back: belly down
	var t := Transform2D(ang, Vector2(1.0, signf(dirx)), 0.0, at)
	var body := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		body.append(t * Vector2(cos(a) * r, sin(a) * r * 0.48))
	var back := -1.0
	b.polygon(PackedVector2Array([t * Vector2(back * r * 0.8, 0.0), t * Vector2(back * r * 1.45, -r * 0.45), t * Vector2(back * r * 1.3, 0.0), t * Vector2(back * r * 1.45, r * 0.45)]), Color("e0764f"))
	b.polygon(body, Color("f2995f"))
	b.ellipse(t * Vector2(-r * 0.1, r * 0.18), r * 0.55, r * 0.16, Color("fbd6a8"))
	b.disc(t * Vector2(r * 0.52, -r * 0.1), r * 0.13, Color("3a2a22"))
	b.disc(t * Vector2(r * 0.49, -r * 0.14), r * 0.05, Color.WHITE)

## Bunting strung along the solved deck: a pole at every road joint, a
## sagging cord between them and pennants waving on it, dropped in along the
## win's wave.
func _bunting(b: Face.Builder, t: float) -> void:
	var calm := not Motion.reduce
	var since := t - _solved_at if _solved_at >= 0.0 else 100.0
	var x0 := px(Vector2.ZERO).x
	var span := maxf(1.0, px(Vector2(float(state.level.w), 0.0)).x - x0)
	# the deck where it stands: the sim's, bent under its weight, when it ran
	var decks: Array = []
	if sim.ma.size() > 0:
		for k in sim.ma.size():
			if sim.mmat[k] == Sim.ROAD and sim.malive[k] == 1 and sim.mstub[k] == 0:
				decks.append([px(sim.jp[sim.ma[k]]), px(sim.jp[sim.mb[k]])])
	else:
		for d in state.design:
			if int(d.m) == Sim.ROAD:
				decks.append([px(Vector2(d.a)), px(Vector2(d.b))])
	var n := 0
	for pq in decks:
		var p: Vector2 = pq[0]
		var q: Vector2 = pq[1]
		p += _wave_off(p, t)
		q += _wave_off(q, t)
		if p.x > q.x:
			var s := p
			p = q
			q = s
		var drop := clampf((since - 0.2 - clampf((p.x - x0) / span, 0.0, 1.0) * 0.8) / 0.35, 0.0, 1.0) if calm else 1.0
		if drop <= 0.0:
			continue
		var h := _u * 0.62 * Motion.back_out(drop)
		var up := Vector2(0.0, -h)
		for e in [p, q]:
			b.stroke(PackedVector2Array([e, e + up]), _u * 0.035, Color("8a6a4a"))
		var sag := _u * 0.16
		var cord := PackedVector2Array()
		for k in 7:
			var f := k / 6.0
			cord.append(p.lerp(q, f) + up + Vector2(0.0, sin(f * PI) * sag))
		b.stroke(cord, _u * 0.018, Color("7a6048"), false, false)
		for k in 3:
			var f := (k + 0.5) / 3.0
			var top := p.lerp(q, f) + up + Vector2(0.0, sin(f * PI) * sag)
			var sway := sin(t * 3.5 + n * 0.9 + k * 1.3) * _u * 0.05 if calm else 0.0
			var col: Color = PENNANTS[(n * 3 + k) % PENNANTS.size()]
			b.polygon(PackedVector2Array([top + Vector2(-_u * 0.1, 0.0), top + Vector2(_u * 0.1, 0.0), top + Vector2(sway, _u * 0.24 * drop)]), col)
		n += 1

func _budget_rect() -> Rect2:
	var x := PAD + 3.0 * (CHIP.x + CHIP_GAP) + 16.0
	var w := size.x - PAD - x - 12.0
	return Rect2(Vector2(x, STRIP_H - 34.0), Vector2(w, 22.0))

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
	if not _toast_args.is_empty():
		line = line % _toast_args
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
	var mid := Vector2(size.x * 0.5, STRIP_H + 30.0 + h * 0.5)
	_front.draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		_front.draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		_front.draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _tell(key: String, args: Array = []) -> void:
	_toast = key
	_toast_args = args
	_toast_at = _now()
	_front.queue_redraw()

# --- for harnesses ---

func point_to_local(p: Vector2i) -> Vector2:
	return px(Vector2(p))

func chip_to_local(i: int) -> Vector2:
	return _chip_rect(i).get_center()

## Runs a test that is under way to its end at once, for the win harness,
## which cannot wait out a cart's crossing in its frame slot.
func run_test_now() -> void:
	while _testing and not sim.done() and _crossed_at < 0.0:
		sim.step()
		_events(_now())

## A drawing of one layer over the bridge, painted by the board.
class Layer extends Control:
	var painter: Callable

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if painter.is_valid():
			painter.call()
