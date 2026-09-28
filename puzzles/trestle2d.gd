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
## Spec: docs/superpowers/specs/2026-09-28-trestle-flat-design.md.

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
## The cart's wheels on the planks: a looping voice whose level follows
## whether the cart is rolling (snooker's `_roll_sound`).
var _roll: AudioStreamPlayer

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
	_frame = null
	_cart_mesh = null
	_wheel_mesh = null
	for f in _faces:
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
		_acc += minf(delta, 0.1)
		var steps := 0
		while _acc >= Sim.DT and steps < MAX_STEPS:
			_acc -= Sim.DT
			steps += 1
			sim.step()
			_events(t)
		if steps == MAX_STEPS:
			_acc = 0.0
		_wheel_turn += (Sim.CART_V * delta) / (Parts.wheel_r(1.0)) if sim.cart != Sim.CART_AIR and sim.cart != Sim.CART_WATER else delta * 2.0
		if sim.done() and _fail_at < 0.0 and _crossed_at < 0.0:
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
	if _testing or not _grow.is_empty():
		_frame = null
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
				_rw.ring(at, _u * 1.3, Color(Pal.WATER_HI, 0.8))
			"bank":
				_mood(Face.Expr.JOY)
			"cross":
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
	_tests += 1
	_testing = true
	_acc = 0.0
	_test_at = _now()
	_fail_at = -1.0
	_crossed_at = -1.0
	_creaked = {}
	_last_broken = {}
	_sel = Vector2i(-99, -99)
	_pressing = false
	_dragging = false
	sim.setup(state.level, state.for_sim())
	_mood(Face.Expr.HAPPY)
	fx.cue("go")
	_toast = ""
	focus_changed.emit()
	return -1

func _stop() -> void:
	_testing = false
	_fail_at = -1.0
	sim.setup(state.level, [])
	_mood(Face.Expr.HAPPY)
	_frame = null
	focus_changed.emit()

func _failed(t: float) -> void:
	_fail_at = t
	for m in sim.broken:
		if m >= 0:
			_last_broken[m] = true
	fx.cue("fail")
	_mood(Face.Expr.WORRIED)
	var snapped := _last_broken.size()
	var run := _tests
	var timed_out := sim.t >= Sim.TIME_OUT and sim.cart != Sim.CART_WATER
	_after(FAIL_HOLD, func():
		# a Stop and a new Go inside the hold make this another test's
		if not _testing or _crossed_at >= 0.0 or run != _tests:
			return
		_stop()
		if timed_out:
			_tell("TR_STUCK")
		elif snapped == 0:
			_tell("TR_NO_ROAD")
		elif snapped == 1:
			_tell("TR_SNAPPED_ONE")
		else:
			_tell("TR_SNAPPED_N", [snapped]))

func _crossed(t: float) -> void:
	_crossed_at = t
	fx.cue("cross")
	_mood(Face.Expr.JOY)
	check_solved()

func is_solved() -> bool:
	return _crossed_at >= 0.0

func share_glyphs() -> String:
	var stars := "⭐".repeat(_stars())
	return "🌉 " + tr("TR_SHARE") % [Locale.number(state.cost()), Locale.number(state.budget), _tests] + " " + stars

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
	fx.cue("solved")
	var at := Vector2(size.x * 0.5, _scene.position.y + _u * 1.2)
	_rw.sticker(tr("TR_W_CROSSED"), at, 104, WIN_HOLD, true, Color.WHITE, true, "crossed")
	var left := state.left()
	var stars := _stars()
	_after(0.55, func():
		_rw.sticker(tr("TR_W_UNDER") % Locale.number(left), at + Vector2(0.0, _u * 0.95), 44, WIN_HOLD - 0.6, false, Pal.SUN, false, "under"))
	if stars == 3:
		_after(1.0, func():
			_rw.sticker(tr("TR_W_MASTER"), at + Vector2(0.0, _u * 1.7), 52, WIN_HOLD - 1.0, true, Color.WHITE, false, "master"))
	elif state.hints_placed() == 0:
		_after(1.0, func():
			_rw.sticker(tr(WORDS[clampi(stars - 1, 0, 2)]), at + Vector2(0.0, _u * 1.7), 50, WIN_HOLD - 1.0, false, Color.WHITE, false, "word"))
	if not Motion.reduce:
		var bank := px(Vector2(float(state.level.w) + 1.0, float(state.level.dy)))
		_rw.spray(bank, Pal.SUN, 16, 900.0, "star", 1.2)
		_rw.spray(bank, Color("fffaf0"), 12, 760.0, "spark", 1.3)
		_rw.ring(bank, _u * 2.0, Color(Pal.SUN, 0.9))
		_rw.rain(2.6, ["confetti", "star", "confetti"], Rewards.CONFETTI)
		# every member of the bridge twinkles, from the far bank back
		var n := state.design.size()
		for i in n:
			var d: Dictionary = state.design[i]
			var mid := px(Vector2(d.a + d.b) * 0.5)
			_after(0.1 + 0.05 * (n - i), func(): fx.sparkle(mid))

func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	for i in _faces.size():
		faces.append(Fruit.make([0, 2, 1, 3][i], 130.0, Vector2.ZERO))
	return {"faces": faces, "subtitle": tr("TR_WIN") % [Locale.number(state.cost()), Locale.number(state.budget), "★".repeat(_stars())]}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_HOLD

func restore_completed_board() -> void:
	state.design = []
	for p in state.proof:
		state.design.append({"a": p.a, "b": p.b, "m": p.m, "hint": false})
	sim.setup(state.level, state.for_sim())
	sim.cart = Sim.CART_OVER
	sim.cart_pos = Vector2(float(state.level.w) + Sim.CART_EXIT, float(state.level.dy))
	_testing = false
	_crossed_at = _now() - 100.0
	_solved_at = -1.0
	_toast = ""
	_frame = null
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
	return maxi(0, HINTS - hints_used)

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
		_splinters(r)
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
		_splinters(d)
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
	if _done or state.level.is_empty():
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
	return Rect2(Vector2(PAD + i * (CHIP.x + CHIP_GAP), (STRIP_H - CHIP.y) * 0.5 + 8.0), CHIP)

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
		state.remove(_press_member)
		_splinters(d)
		fx.cue("remove")
		_frame = null
		_last_broken = {}
		note_move()
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
			State.Refusal.BUDGET: _tell("TR_BUDGET_OUT")
			_: _tell("TR_NO_ROPE")
		return
	state.add(a, b, _mat)
	_last_broken = {}
	_grow[Vector4i(a.x, a.y, b.x, b.y)] = _now()
	fx.cue(["place_road", "place_wood", "place_rope"][_mat], randf_range(0.95, 1.05))
	_sel = b
	_frame = null
	note_move()

# --- the drawing ---

func _place_cart() -> void:
	if _faces.is_empty():
		return
	var xf := _cart_xf()
	var n := _faces.size()
	var bob := 0.0
	if _testing and sim.cart != Sim.CART_AIR and not Motion.reduce:
		bob = sin(_now() * 18.0) * _u * 0.015
	for i in n:
		var at := xf * (Parts.seat(_u, n, i) + Vector2(0.0, bob))
		if _solved_at >= 0.0:
			# the passengers cheer, a hop each, one after another
			at.y += Motion.hop_lift(fmod(_now() - _solved_at + 0.15 * i, 0.8), -_u * 0.3, 0.5)
		_faces[i].position = at - _faces[i].size * 0.5
		_faces[i].rotation = xf.get_rotation()
		_faces[i].visible = sim.cart != Sim.CART_WATER or _now() - _fail_at < 0.35

## The cart's frame on the screen: its origin on the road's top.
func _cart_xf() -> Transform2D:
	var at := px(sim.cart_pos)
	var ang := -sim.cart_angle
	var up := Vector2(0.0, -1.0).rotated(ang)
	var lift := _u * 0.1 if sim.cart != Sim.CART_AIR else 0.0
	if sim.cart == Sim.CART_WATER:
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
	draw_mesh(_still, null)
	if _halo != null:
		var beat := 0.75 + 0.25 * sin(_now() * 4.5) if not Motion.reduce else 1.0
		draw_mesh(_halo, null, Transform2D(), Color(1, 1, 1, beat))
	draw_mesh(_frame, null)
	var xf := _cart_xf()
	draw_mesh(_cart_mesh, null, xf)
	for w in Parts.wheel_at(_u, _faces.size()):
		draw_mesh(_wheel_mesh, null, xf * Transform2D(_wheel_turn, w))
	_shown = [_still, _frame, _cart_mesh, _wheel_mesh, _halo]

func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var lv := state.level
	var w := float(lv.w)
	var dy := float(lv.dy)
	var full := Rect2(Vector2.ZERO, size)
	# the sky over the whole card, and the far hills
	_grad(b, full, Color("bfe3f5"), Color("f3ecd9"))
	var horizon := px(Vector2(0.0, 0.8)).y
	var hills := PackedVector2Array()
	for k in 25:
		var x := size.x * k / 24.0
		hills.append(Vector2(x, horizon - _u * (0.5 + 0.35 * sin(k * 0.9) + 0.2 * sin(k * 2.3))))
	hills.append(Vector2(size.x, size.y))
	hills.append(Vector2(0.0, size.y))
	b.polygon(hills, Color("cfe2c0"))
	for c in [Vector2(0.18, 0.23), Vector2(0.72, 0.16)]:
		var at := Vector2(size.x * c.x, _scene.position.y + _scene.size.y * c.y)
		for k in 3:
			b.disc(at + Vector2((k - 1) * _u * 0.45, -_u * 0.1 * (1 - absi(k - 1))), _u * (0.35 + 0.12 * (1 - absi(k - 1))), Color(1, 1, 1, 0.85))
	# the river: from the water line down, between the banks
	var water := px(Vector2(0.0, Sim.WATER)).y
	_grad(b, Rect2(Vector2(0.0, water), Vector2(size.x, size.y - water)), Color("7cc3e8"), Color("3f8fc4"))
	for k in 6:
		var y := water + _u * (0.3 + 0.35 * k)
		var x0 := px(Vector2(0.4 + 0.7 * (k % 3), 0.0)).x
		b.stroke(PackedVector2Array([Vector2(x0, y), Vector2(x0 + _u * 0.9, y)]), _u * 0.04, Color(1, 1, 1, 0.3))
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
	for k in 5:
		var y := lip.y + _u * (0.7 + 0.9 * k)
		var x := lip.x - dir * _u * (0.5 + 0.4 * (k % 2))
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x - dir * _u * 0.6, y + _u * 0.1)]), _u * 0.04, Color("9c7f60"))
	# grass and road on top
	var grass := Rect2(Vector2(minf(edge, lip.x), lip.y - _u * 0.05), Vector2(absf(lip.x - edge), _u * 0.32))
	b.fan(Face.Builder.round_rect(grass.position, grass.size, _u * 0.08), Color("8cb050"))
	b.fan(Face.Builder.round_rect(grass.position + Vector2(0, _u * 0.18), Vector2(grass.size.x, _u * 0.14), _u * 0.04), Color("6f9440"))
	var road := Rect2(Vector2(minf(edge, lip.x), lip.y - _u * 0.1), Vector2(absf(lip.x - edge), _u * 0.12))
	b.fan(Face.Builder.round_rect(road.position, road.size, _u * 0.05), Color("d9c49a"))
	# tufts
	for k in 4:
		var x := lip.x - dir * _u * (0.6 + 0.6 * k)
		var y := lip.y - _u * 0.1
		for s in 3:
			b.stroke(PackedVector2Array([Vector2(x + (s - 1) * _u * 0.05, y), Vector2(x + (s - 1) * _u * 0.09, y - _u * 0.14)]), _u * 0.03, Color("6f9440"))

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
			if _last_broken.has(i):
				hb.stroke(PackedVector2Array([p, q]), _u * 0.48, Color(Parts.BAD, 0.6))
				halos += 1
			if d.get("hint", false):
				hb.stroke(PackedVector2Array([p, q]), _u * 0.32, Color(Pal.SUN, 0.35))
				halos += 1
			Parts.member(b, p, q, int(d.m), _u)
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
	# the water's face, over anything that fell in
	var water := px(Vector2(0.0, Sim.WATER)).y
	var x0 := px(Vector2(0.0, 0.0)).x
	var x1 := px(Vector2(float(state.level.w), 0.0)).x
	var wave := PackedVector2Array()
	for k in 17:
		var x := lerpf(x0 - _u * 0.2, x1 + _u * 0.2, k / 16.0)
		wave.append(Vector2(x, water + sin(k * 1.3 + (0.0 if Motion.reduce else t * 2.0)) * _u * 0.03))
	wave.append(Vector2(x1 + _u * 0.2, size.y))
	wave.append(Vector2(x0 - _u * 0.2, size.y))
	b.polygon(wave, Color(0.35, 0.62, 0.82, 0.55))
	# building: where the finger reaches, the ghost member, the chosen joint
	if not _testing and not is_done():
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
	_front_mesh = b.mesh()
	_front.draw_mesh(_front_mesh, null)
	shown.append(_front_mesh)
	var strip_key := "%d|%d|%d|%s" % [state.cost(), _mat, state.budget, size]
	if _strip_mesh == null or _strip_for != strip_key:
		_strip_mesh = _build_strip()
		_strip_for = strip_key
	_front.draw_mesh(_strip_mesh, null)
	shown.append(_strip_mesh)
	_draw_words()
	_draw_toast(t, shown)
	_front_shown = shown

## The strip: a paper band, the chips, the budget bar and the proof's star.
func _build_strip() -> ArrayMesh:
	var b := Face.Builder.new()
	var strip := Rect2(Vector2(PAD * 0.5, 8.0), Vector2(size.x - PAD, STRIP_H))
	b.fan(Face.Builder.round_rect(strip.position + Vector2(0, 4), strip.size, 30.0), Color(Pal.TEXT, 0.12))
	b.fan(Face.Builder.round_rect(strip.position, strip.size, 30.0), Color(Pal.SURFACE, 0.94))
	for i in 3:
		var r := _chip_rect(i)
		var on := i == _mat
		var there := state.mats.has(i)
		var lift := 4.0 if on else 0.0
		b.fan(Face.Builder.round_rect(r.position + Vector2(0, 5), r.size, CHIP_R), Color(Pal.TEXT, 0.14 if there else 0.05))
		b.fan(Face.Builder.round_rect(r.position - Vector2(0, lift), r.size, CHIP_R), Pal.SUN_TILE if on else Pal.SURFACE_HI)
		if on:
			b.stroke(Face.Builder.round_rect(r.position - Vector2(0, lift), r.size, CHIP_R), 4.0, Pal.SUN, true)
		var mid := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.36 - lift)
		Parts.member(b, mid - Vector2(r.size.x * 0.3, 0), mid + Vector2(r.size.x * 0.3, 0), i, 70.0, Color(0, 0, 0, 0), 1.0 if there else 0.3)
	# the budget bar
	var bar := _budget_rect()
	var spent := clampf(float(state.cost()) / maxf(1.0, float(state.budget)), 0.0, 1.0)
	var left_col := Pal.GOOD if spent < 0.8 else (Parts.WARN if spent < 0.95 else Parts.BAD)
	b.fan(Face.Builder.round_rect(bar.position, bar.size, bar.size.y * 0.5), Pal.SURFACE_HI)
	if spent > 0.0:
		b.fan(Face.Builder.round_rect(bar.position, Vector2(maxf(bar.size.y, bar.size.x * spent), bar.size.y), bar.size.y * 0.5), left_col)
	var proof := float(state.level.get("proof_cost", 0))
	if proof > 0.0:
		var px_x := bar.position.x + bar.size.x * clampf(proof / float(state.budget), 0.0, 1.0)
		Rewards.star(b, Vector2(px_x, bar.position.y + bar.size.y * 0.5), 15.0, Pal.PLAQUE_DEEP)
		Rewards.star(b, Vector2(px_x, bar.position.y + bar.size.y * 0.5), 12.0, Pal.SUN)
	return b.mesh()

func _draw_words() -> void:
	var bar := _budget_rect()
	var font: Font = CozyTheme.body(700)
	for i in 3:
		var r := _chip_rect(i)
		var there := state.mats.has(i)
		var lift := 4.0 if i == _mat else 0.0
		var name := tr(["TR_MAT_ROAD", "TR_MAT_WOOD", "TR_MAT_ROPE"][i])
		var fs := 24
		var sz := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_front.draw_string(font, Vector2(r.position.x + (r.size.x - sz.x) * 0.5, r.end.y - 16.0 - lift), name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.TEXT, 1.0 if there else 0.35))
	var money := "%s / %s" % [Locale.number(state.cost()), Locale.number(state.budget)]
	var mfs := 34
	var msz := font.get_string_size(money, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs)
	_front.draw_string(font, Vector2(bar.end.x - msz.x, bar.position.y - 18.0), money, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Pal.TEXT)
	var lbl := tr("TR_BUDGET")
	_front.draw_string(CozyTheme.body(600), Vector2(bar.position.x, bar.position.y - 18.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.TEXT_DIM)

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
