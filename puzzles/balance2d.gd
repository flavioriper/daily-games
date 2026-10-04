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
##
## **Sunset** (Hard and Insane, spec 2026-09-29-balance-sunset-design.md):
## every move sinks the sun a step; when it is down the fruit nod off and
## the card offers One more hour (a video, once) or Show the answer, which
## ends the day unsolved. **Insane's bales are springs**: a beam that
## bottoms out bounces every loose fruit on its low side home, so the glass
## is the only safe window to weigh in.

const Gen = preload("res://puzzles/balance_gen.gd")
const State = preload("res://puzzles/balance_state.gd")
const Sim = preload("res://puzzles/balance_sim.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Haptics = preload("res://core/haptics.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Seal = preload("res://ui/flat/seal.gd")
const OUT_OF_SUN := "res://ui/hud/out_of_rows.gd"
## The sunset card's words (ui/hud/out_of_rows.gd, Code Break's card).
const OUT_WORDS := {"title": "BAL_OUT_TITLE", "body": "BAL_OUT_BODY", "body_rest": "BAL_OUT_BODY_REST",
	"more": "BAL_ONE_HOUR", "show": "BAL_SHOW_ANSWER", "placement": "hour"}

## What the phone does under each cue (docs/agents/haptics.md). The knock
## for a fruit set down is not a cue: `land` and `step` fire for every fruit
## the board moves too (a hint, Undo, Reset, a bounce, the shown answer), so
## `_by_hand` marks the one the hand let go and `_after_physics` knocks as
## it lands (a tap) or gets home (a tick). A far toss that lands is a small
## yes over that tap. The beam level knocks; the beam at rest anywhere else
## (`tock`, the cheers) says nothing, and neither does the plank on its bale
## (`thud`), which every uneven move would make a heavy knock of. Insane's
## bounce is the mistake that costs. A pinned fruit touched, a fruit lifted,
## the sun tapped and the sun getting low say nothing. The seal thuds as it
## lands (`_stamp_down`).
const HAPTICS := {
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"level": Haptics.BUMP,
	"toss": Haptics.GOOD,
	"hint": Haptics.GOOD,
	"hour_back": Haptics.GOOD,
	"boing": Haptics.BAD,
	"sunset": Haptics.LOSE,
	"solved": Haptics.WIN,
}

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
const BASKET_H := 1.45
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
const WIN_HOLD := 2.8
## Hints per band: Easy, Medium, Hard, Insane.
const HINTS_BY_BAND := [3, 3, 1, 0]
const TOAST_HOLD := 2.8
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32

# --- the loud bits (the spec's polish amendment) ---
## The plank's gold flash on a level, and how long the fruit on it cheer.
const GOLD_TIME := 1.1
const CHEER_TIME := 0.5
## A landing jolts the fruit already on the plank up by this, in cups.
const JOLT := 0.14
const JOLT_TIME := 0.3
## A fruit stretches up out of the basket when it is lifted.
const STRETCH := 0.16
## A flight's trail, in frames.
const TRAIL_N := 9
const SIGN_POP := 0.32
const RAINBOW_TIME := 1.4
## The words a run of moves toward level earns, one step each.
const WORDS := ["BAL_W_CLOSER", "BAL_W_NICE", "BAL_W_GREAT", "BAL_W_SUPERB"]
const RAINBOW := [Color("f4a7a0"), Color("f7c98b"), Color("f7e39c"), Color("a8d8a0"), Color("9cc9ec"), Color("b9a6e0")]
const SUN_R := 0.42

# --- the sunset pass (2026-09-29) ---
## How fast the drawn sun follows the day, and the pill that counts it.
const SUN_EASE := 2.6
const PILL_W := 132.0
const PILL_H := 64.0
const PILL_FONT := 38
## From this many moves left the pill warms and the toast says so.
const SUN_LOW := 3
## The card waits for the sunset to be seen.
const CARD_AFTER := 1.8
## A springy bale's bounce: how high and how long the fruit fly, and how
## long they see stars in the basket after.
const BOING_HIGH := 2.3
const BOING_LONG := 1.7
const BOING_TIME := 0.7
const DIZZY_TIME := 2.6
## A fruit let go at this speed (cups a second) from this far away (cups)
## is a toss; landing in its cup earns sunglasses.
const TOSS_V := 3.2
const TOSS_FAR := 1.6
const GLASSES_HOLD := 1.7
## The solve: hats pop from the middle out, the stamp drops on the basket,
## and weight tags swing down under the plank.
const HAT_AT := 0.9
const HAT_STAGGER := 0.07
const STAMP_AT := 1.5
const STAMP_R := 0.62
const STAMP_DROP := 0.28
const STAMP_FROM := 2.4
const STAMP_TILT := -0.16
const TAGS_AT := 1.1
const TAG_STAGGER := 0.08
const TAG_DROP := 0.28
## Easy/Medium's stamp word by moves beyond one per loose fruit.
const STAMP_STEPS := [0, 3, 7, 12]

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
## The loud rewards over the card (arcade/rewards.gd).
var _rw: Rewards
## The sky behind everything (turning sun, drifting clouds, bunting, the
## rainbow) and the air over the fruit (trails, sweat, butterflies): both
## redrawn every frame, both small.
var _sky: Control
var _air: Control
var _sky_mesh: ArrayMesh
var _sun_mesh: ArrayMesh
var _rays_mesh: ArrayMesh
var _cloud_meshes: Array = []
var _bunting_mesh: ArrayMesh
var _rainbow_mesh: ArrayMesh
var _air_mesh: ArrayMesh
var _plank_gold: ArrayMesh
var _sky_shown: Array = []
var _stretch_at: Array[float] = []
var _trails: Array = []
var _jolt_at := -100.0
var _jolt_f := -1
var _jolt_k := 1.0
var _cheer_at := -100.0
var _gold_at := -100.0
var _sun_kick_at := -100.0
var _rainbow_at := -100.0
var _fx_until := 0.0
var _last_abs := -1
var _closer := 0
var _sign_text := ""
var _sign_pop_at := -100.0
var _sign_a := 0.0
var _sign_av := 0.0
var _bubble_v := 0.0
var _hint_f := -1
var _hint_until := -1.0
## Things to do later, on the board's own clock: [when, Callable].
var _later: Array = []
## The sunset: out of moves, the card over the host, the drawn sun's
## day (0 morning .. 1 set), and when night fell (for the stars).
## The host's Back ends a board that says this unsolved: true from the step
## that spent the last of the sun (the fruit may still be flying and the
## card not up yet), not only once the card is.
var out_of_hearts: bool:
	get:
		return _out_card or (state.out_of_sun() and not state.is_solved() and not _done)
	set(v):
		_out_card = v
## The sunset has been run (night, sleepy fruit, the card).
var _out_card := false
var _card: Control
var _sun_day := 0.0
var _sun_pop_at := -100.0
var _night_at := -1.0
var _night := 0.0
var _dusk_mesh: ArrayMesh
var _stars_mesh: ArrayMesh
var _stars_slot := -1
var _pill_mesh: ArrayMesh
## The day ended by Show the answer.
var _shown_answer := false
## Insane's bales: when each side last bounced (-1 left, +1 right).
var _boing_l := -100.0
var _boing_r := -100.0
var _bale_mesh: ArrayMesh
var _dizzy_until: Array[float] = []
## Glances: where each face looks until when.
var _look_dir: Array[Vector2] = []
var _look_until: Array[float] = []
## Tosses: the fruit let go as a toss and not landed yet, and the run.
var _tossed: Array[bool] = []
## Per fruit: let go by the hand and not yet down, so its landing knocks
## (a hop the board made -- a hint, Undo, Reset, a bounce -- lands silent).
var _by_hand: Array[bool] = []
var _toss_run := 0
var _glasses_tw: Array = []
## The cup a held fruit would drop into, and its glow's level.
var _aim_x := 0
var _aim_a := 0.0
var _aim_mesh: ArrayMesh
## A tap on the sun: it giggles.
var _giggle_at := -100.0
## Every move this board, whatever Reset did to `moves`.
var _all_moves := 0
## The solve's weight tags under the plank, and the stamp on the basket.
var _tags_at := -1.0
var _tag_mesh: ArrayMesh
var _stamp: Control
var _party := false

func puzzle_id() -> String: return "balance"
func title() -> String: return "Balance"

func rules() -> String:
	var out := tr("BAL_RULES")
	if _difficulty >= 3:
		out += "\n\n" + tr("BAL_RULES_SUN")
	if _difficulty >= 3:
		out += "\n\n" + tr("BAL_RULES_BOING")
	return out

## The tutorial, a page a rule (ui/hud/balance_tutorial_diagram.gd): drag
## and send home, read the level, dead level; then the hint where the band
## has one, the sunset on Hard and Insane, and Insane's springy bales.
func tutorial_pages() -> Array:
	const Diagram = preload("res://ui/hud/balance_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.DRAG, "HTP_BAL_DRAG", tr("HTP_BAL_DRAG_BODY")],
		[Diagram.Lesson.WEIGH, "HTP_BAL_WEIGH", tr("HTP_BAL_WEIGH_BODY")],
		[Diagram.Lesson.LEVEL, "HTP_BAL_LEVEL", tr("HTP_BAL_LEVEL_BODY")]]
	var hints: int = HINTS_BY_BAND[clampi(_difficulty, 0, 3)]
	if hints > 0:
		var body := tr("HTP_BAL_HINT_BODY_ONE") if hints == 1 else tr("HTP_BAL_HINT_BODY_N") % hints
		if _difficulty >= 3:
			body += " " + tr("HTP_BAL_HINT_SUN")
		steps.append([Diagram.Lesson.HINT, "HTP_BAL_HINT", body])
	if _difficulty >= 3:
		steps.append([Diagram.Lesson.SUN, "HTP_BAL_SUN", tr("HTP_BAL_SUN_BODY")])
	if _difficulty >= 3:
		steps.append([Diagram.Lesson.BALES, "HTP_BAL_BALES", tr("HTP_BAL_BALES_BODY")])
	var pages := []
	for step in steps:
		var d := Diagram.new()
		d.lesson = step[0]
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and Hint (Hard has one hint); Insane has Undo only (since the
## 2026-10-01 checkup: a bounce is kept in the move's history entry, so one
## undo puts the bounced fruit back too, at a step of the sun like any
## move). Reset is the host's. No Check: the beam is its own.
func capabilities() -> Array[String]:
	if _difficulty >= 3:
		return ["undo"]
	# no bulb once the sun is down: a video hint then would be for nothing
	if _out_card or state.out_of_sun():
		return ["undo"]
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_sky = Layer.new()
	_sky.name = "Sky"
	_sky.painter = _draw_sky
	_sky.show_behind_parent = true
	add_child(_sky)
	_air = Layer.new()
	_air.name = "Air"
	_air.painter = _draw_air
	_air.z_index = 1
	add_child(_air)
	_front = Layer.new()
	_front.name = "Front"
	_front.painter = _draw_front
	_front.z_index = 1
	add_child(_front)
	fx = Fx2D.new()
	fx.haptics = HAPTICS
	fx.name = "Fx"
	fx.z_index = 3
	add_child(fx)
	_rw = Rewards.new()
	_rw.z_index = 4
	add_child(_rw)
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
	_stretch_at = []
	_trails = []
	_later = []
	_last_abs = -1
	_closer = 0
	_rainbow_at = -100.0
	_rainbow_mesh = null
	_hint_f = -1
	if _rw != null:
		_rw.clear()
	_close_card()
	out_of_hearts = false
	_sun_day = 0.0
	_night_at = -1.0
	_shown_answer = false
	_boing_l = -100.0
	_boing_r = -100.0
	_dizzy_until = []
	_look_dir = []
	_look_until = []
	_tossed = []
	_by_hand = []
	_toss_run = 0
	_glasses_tw = []
	_aim_a = 0.0
	_all_moves = 0
	_tags_at = -1.0
	_party = false
	if is_instance_valid(_stamp):
		_stamp.queue_free()
	_stamp = null
	for f in state.fruit.size():
		var face := Fruit.make(state.fruit[f], 100.0, Vector2.ZERO)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.shadowless = true
		face.set_idle(true)
		add_child(face)
		move_child(face, _front.get_index())
		_faces.append(face)
		_squash_at.append(-100.0)
		_stretch_at.append(-100.0)
		_trails.append([])
		_dizzy_until.append(-100.0)
		_look_dir.append(Vector2.ZERO)
		_look_until.append(-100.0)
		_tossed.append(false)
		_by_hand.append(false)
		_glasses_tw.append(null)
	_held = -1
	_solved_at = -1.0
	_level_at = -100.0
	_was_level = false
	_toast = ""
	_opened = _now()
	_layout()
	_enter()
	fx.cue("enter")
	_tell("BAL_TIP_BOING" if state.boing else ("BAL_TIP_SUN" if state.has_sunset() else "BAL_TIP_DRAG"))

## Pinned fruit drop into their cups one after another -- the beam catching
## each one is the first thing on the screen, and the first lesson -- while
## the basket's fruit pop in.
func _enter() -> void:
	_after(Motion.ENTER_DELAY + 1.2, _warm_words)
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

## The words this board letters loud, rasterised ahead (Rewards.warm), the
## solve's first: drawn cold, "Balanced!" alone cost a 30-45 ms frame.
func _warm_words() -> void:
	_rw.warm(tr("BAL_W_BALANCED"), 112)
	_rw.warm(tr("BAL_W_LEVEL"), 88)
	if not state.hinted.has(true):
		_rw.warm(tr("BAL_W_NO_HINTS"), 46)
	for n in range(1, 5):
		_rw.warm(tr(WORDS[mini(n - 1, WORDS.size() - 1)]), 50 + 6 * n)
	_rw.warm(tr("BAL_W_SO_CLOSE"), 56)
	if state.boing:
		_rw.warm(tr("BAL_W_BOING"), 58)

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
	var hub_y := maxf(room_top, (size.y - basket_h - PAD) * 0.54 - _cup * 0.2)
	hub_y = minf(hub_y, size.y - PAD - basket_h - _cup * (HUB_H + 0.5))
	_pivot = Vector2(size.x * 0.5, hub_y)
	_ground = hub_y + HUB_H * _cup
	var lawn := size.y - PAD - _ground
	var basket_top := _ground + maxf(_cup * 0.5, (lawn - basket_h) * 0.5)
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
		slots[loose[i]] = Vector2(x0 + pitch * i, _basket.position.y - _cup * 0.1)
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
	_sky_mesh = null
	_sun_mesh = null
	_rays_mesh = null
	_cloud_meshes = []
	_rainbow_mesh = null
	_plank_gold = null
	_dusk_mesh = null
	_pill_mesh = null
	_bale_mesh = null
	_aim_mesh = null
	_tag_mesh = null
	_place_stamp()
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
		elif mode == Sim.AIR:
			# a thrown fruit leans into its flight
			var vel: Vector2 = sim.bodies[f].vel
			rot += clampf(vel.x * 0.0007, -0.5, 0.5)
		var q := (t - _squash_at[f]) / SQUASH_TIME
		if q >= 0.0 and q < 1.0 and not Motion.reduce:
			var s := SQUASH * sin(PI * q) * (1.0 - q)
			sc *= Vector2(1.0 + s, 1.0 - s)
		# lifted out of the basket: a stretch up, then the squash back
		var u := (t - _stretch_at[f]) / (SQUASH_TIME * 1.3)
		if u >= 0.0 and u < 1.0 and not Motion.reduce:
			var s := STRETCH * sin(PI * u) * (1.0 - u * 0.6)
			sc *= Vector2(1.0 - s, 1.0 + s)
		if not Motion.reduce and mode == Sim.PLANK and _solved_at < 0.0:
			# a landing jolts its neighbours; a level makes them all cheer
			var j := (t - _jolt_at) / JOLT_TIME
			if f != _jolt_f and j >= 0.0 and j < 1.0:
				pos.y -= sin(PI * j) * _cup * JOLT * _jolt_k
			var c := t - _cheer_at - Motion.stagger(absi(int(sim.bodies[f].cup)), 0.07)
			if c >= 0.0 and c < CHEER_TIME * 2.0:
				pos.y += Motion.hop_lift(c, Motion.SOLVE_HOP * 3.0, Motion.SOLVE_TIME) + Motion.hop_lift(c - Motion.SOLVE_TIME, Motion.SOLVE_HOP * 1.6, Motion.SOLVE_TIME * 0.8)
		if solve_t >= 0.0 and not Motion.reduce:
			# the solve: a wave out of the middle, twice, then a third, higher
			var d := solve_t - Motion.stagger(absi(int(sim.bodies[f].cup)), 0.09)
			pos.y += Motion.hop_lift(d, Motion.SOLVE_HOP * 4.0, Motion.SOLVE_TIME) \
				+ Motion.hop_lift(d - 0.55, Motion.SOLVE_HOP * 3.0, Motion.SOLVE_TIME) \
				+ Motion.hop_lift(d - 1.1, Motion.SOLVE_HOP * 5.0, Motion.SOLVE_TIME * 1.2)
			if d > 0.0 and d < 1.6:
				rot += sin(d * 9.0) * 0.12 * (1.0 - d / 1.6)
		Fruit.resize(face, _seat, pos)
		# each kind fills its seat differently: stand its drawn bottom where
		# the sim's round body touches down
		var sink: float = sim.r - _drawn_r(face)
		var down := Vector2(0.0, sink).rotated(sim.a if mode == Sim.PLANK else 0.0)
		face.position += down
		face.rotation = rot
		if face.scale != Vector2.ZERO and not _popping(face):
			face.scale = sc
		if not Motion.reduce and t < _dizzy_until[f] and mode == Sim.BASKET:
			# seeing stars after a bale's bounce: a slow woozy sway
			var d := _dizzy_until[f] - t
			face.rotation += sin(t * 7.0 + f) * 0.14 * minf(1.0, d)
		face.z_index = 2 if (f == _held or mode == Sim.AIR or mode == Sim.GROUND or mode == Sim.ARC) else 0
		var mood := _mood(f, mode)
		if face.expression != mood:
			face.expression = mood
		var look := _look_for(f, mode, pos, t)
		if face.look != look:
			face.look = look

## Where a face looks: basket fruit follow a fruit in the hand; a fruit on
## the plank glances at one that just landed by it; else straight ahead.
func _look_for(f: int, mode: int, pos: Vector2, t: float) -> Vector2:
	if Motion.reduce or _solved_at >= 0.0 or _out_card:
		return Vector2.ZERO
	if _held >= 0 and f != _held and mode == Sim.BASKET:
		var d: Vector2 = sim.position(_held) - pos
		return d.normalized() if d.length() > sim.r else Vector2.ZERO
	if t < _look_until[f]:
		return _look_dir[f]
	return Vector2.ZERO

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
	if _shown_answer:
		return Face.Expr.HAPPY
	if _out_card:
		return Face.Expr.SLEEPY
	if _now() < _dizzy_until[f]:
		return Face.Expr.PUZZLED
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
	_bubble_v = lerpf(_bubble_v, (_bubble_x - was) / maxf(delta, 1e-3), 0.3)
	_run_later(t)
	_step_sign(delta)
	_step_trails(t)
	var day := _day_target()
	var day_was := _sun_day
	_sun_day = day if Motion.reduce else lerpf(_sun_day, day, 1.0 - exp(-delta * SUN_EASE))
	var aim_was := _aim_a
	_step_aim(delta)
	var night_to := 1.0 if (_out_card or _shown_answer) else 0.0
	_night = night_to if Motion.reduce else move_toward(_night, night_to, delta / 1.6)
	_rw.bounds = Rect2(Vector2.ZERO, size)
	_rw.step(delta)
	if not Motion.reduce:
		_sky.queue_redraw()
		_air.queue_redraw()
	var busy := not sim.calm() or _held >= 0 or absf(_bubble_x - was) > 0.001 or t - _level_at < GLOW_TIME \
		or (_solved_at >= 0.0 and t - _solved_at < 3.0) or t - _opened < 1.5 or _squashing(t) or t < _fx_until \
		or absf(_sign_av) > 0.002 or absf(_sign_a - sim.a * 0.5) > 0.002 \
		or (_night > 0.0 and _night < 1.0) or absf(_sun_day - day_was) > 0.0005 or absf(_aim_a - aim_was) > 0.002 or _dizzy(t) \
		or (_tags_at >= 0.0 and t - _tags_at < 3.0) \
		or (state.has_sunset() and state.sun_left() <= SUN_LOW and not _out_card and not _done)
	if busy or _moving:
		_place_faces()
		_redraw()
		if Motion.reduce:
			# the sky and the air only redraw on their own when things move;
			# still, a step of the sun or nightfall has to show
			_sky.queue_redraw()
			_air.queue_redraw()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		_front.queue_redraw()
	_moving = busy

## How far the day has gone: 0 all morning, 1 the sun down. Easy and
## Medium never see an evening.
func _day_target() -> float:
	if not state.has_sunset():
		return 0.0
	if state.out_of_sun() and not state.is_solved():
		return 1.0
	return clampf(float(state.spent) / float(state.budget), 0.0, 1.0) * 0.92

func _dizzy(t: float) -> bool:
	for u in _dizzy_until:
		if t < u:
			return true
	return false

## The cup under a held fruit glows while it would drop there.
func _step_aim(delta: float) -> void:
	var want := 0.0
	if _held >= 0:
		var x := _aim(_held, sim.position(_held))
		if x != State.BASKET:
			_aim_x = x
			want = 1.0
	_aim_a = want if Motion.reduce else move_toward(_aim_a, want, delta * 6.0)

func _squashing(t: float) -> bool:
	for at in _squash_at:
		if t - at < SQUASH_TIME:
			return true
	for at in _stretch_at:
		if t - at < SQUASH_TIME * 1.3:
			return true
	return false

## Keeps the board redrawing for `seconds` more.
func _busy_for(seconds: float) -> void:
	_fx_until = maxf(_fx_until, _now() + seconds)

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

## The sign hangs from two ropes and swings after the beam, lagging it.
func _step_sign(delta: float) -> void:
	if Motion.reduce:
		_sign_a = 0.0
		_sign_av = 0.0
		return
	var dt := minf(delta, 1.0 / 30.0)
	_sign_av += (60.0 * (sim.a * 0.5 - _sign_a) - 3.2 * _sign_av) * dt
	_sign_a += _sign_av * dt

## The last few places of anything flying, for its trail.
func _step_trails(_t: float) -> void:
	for f in _trails.size():
		var mode := int(sim.bodies[f].mode)
		var tr_: Array = _trails[f]
		if not Motion.reduce and (mode == Sim.AIR or mode == Sim.ARC or (f == _held and (sim.bodies[f].vel as Vector2).length() > _cup * 2.0)):
			tr_.append(sim.position(f))
			if tr_.size() > TRAIL_N:
				tr_.pop_front()
			if f == _hint_f and mode == Sim.ARC and Engine.get_process_frames() % 2 == 0:
				_rw.spray(sim.position(f), Pal.SUN, 1, 90.0, "star", 0.55)
				_rw.spray(sim.position(f), Color("fffaf0"), 1, 70.0, "spark", 0.6)
		elif not tr_.is_empty():
			tr_.pop_front()

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
				_landed(f, clampf(speed / (_cup * 8.0), 0.3, 1.0))
				_glance_at(f, t)
				if _tossed[f]:
					_tossed[f] = false
					_nice_toss(f)
				if _by_hand[f]:
					_by_hand[f] = false
					Haptics.play(Haptics.TAP)
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
				_tossed[int(e.f)] = false
				if _by_hand[int(e.f)]:
					_by_hand[int(e.f)] = false
					Haptics.play(Haptics.TICK)
				fx.cue("step", 0.85)
	sim.events.clear()
	var calm: bool = sim.calm() and _held < 0
	if calm and not _was_calm:
		_on_rest()
	elif calm and not _done and is_solved():
		# solved without the beam ever being seen to move (a snap)
		check_solved()
	elif calm and not _done and state.boing and _bale_hit():
		# a snapped board that ended on a bale (a harness) still bounces
		_boing()
	if not _done and not _out_card and state.out_of_sun() and sim.calm() and _held < 0 and not is_solved():
		_run_out()
	_was_calm = calm

## A fruit touching down on the plank: dust and a few leaves off it, and
## the fruit already there jolt up.
func _landed(f: int, k: float) -> void:
	_jolt_at = _now()
	_jolt_f = f
	_jolt_k = k
	_busy_for(JOLT_TIME)
	if Motion.reduce:
		return
	var foot: Vector2 = sim.position(f) + Vector2(0.0, sim.r * 0.9).rotated(sim.a)
	fx.puff(foot, Pal.STRAW.lerp(Pal.PAPER, 0.4), 4)
	_rw.spray(foot, Pal.LEAF_LIGHT, int(2 + 3 * k), 380.0 * k + 120.0, "confetti", 0.6)
	_rw.spray(foot, Pal.FLOWER, int(1 + 2 * k), 360.0 * k + 120.0, "confetti", 0.55)
	_rw.spray(foot, Color("fffaf0"), 2, 300.0, "spark", 0.6)

## The fruit on the plank near one that just landed turn to look at it.
func _glance_at(f: int, t: float) -> void:
	var at: Vector2 = sim.position(f)
	for o in state.fruit.size():
		if o == f or int(sim.bodies[o].mode) != Sim.PLANK:
			continue
		var d: Vector2 = at - sim.position(o)
		if d.length() < _cup * 3.2:
			_look_dir[o] = d.normalized()
			_look_until[o] = t + 0.9
	_busy_for(1.0)

## A fruit tossed from afar into its cup: sunglasses, and a word -- a
## trick shot on the third in a row.
func _nice_toss(f: int) -> void:
	_toss_run += 1
	var trick := _toss_run >= 3
	fx.cue("toss", 1.0 + 0.06 * mini(_toss_run - 1, 4))
	var at: Vector2 = sim.position(f) + Vector2(0.0, -sim.r * 2.2)
	_rw.sticker(tr("BAL_W_TRICK" if trick else "BAL_W_TOSS"), at, 40 if trick else 34, 1.1, trick, Pal.SUN if not trick else Color.WHITE, trick, "toss", 18.0)
	_rw.spray(sim.position(f), Pal.SUN, 4 if not trick else 9, 420.0, "star", 0.7)
	if trick:
		_toss_run = 0
		_sun_kick_at = _now()
	if Motion.reduce:
		return
	var face: Control = _faces[f]
	Motion.stop(_glasses_tw[f])
	var tw := face.create_tween()
	tw.tween_property(face, "glasses", 1.0, 0.22).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(GLASSES_HOLD)
	tw.tween_property(face, "glasses", 0.0, 0.3)
	_glasses_tw[f] = tw

## The beam lies on a bale (reads past the glass) with something loose on
## its low side: Insane's springy bale is about to bounce it.
func _bale_hit() -> bool:
	var tq := state.torque()
	if absi(tq) <= Gen.GLASS:
		return false
	for f in state.fruit.size():
		if state.loose(f) and state.at[f] != State.BASKET and state.at[f] * tq > 0:
			return true
	return false

## Insane: the bale under the low end springs, and every loose fruit on
## that side goes flying head over heels home to the basket, seeing stars.
func _boing() -> void:
	var side := signf(state.torque())
	var gone := state.tumble()
	if gone.is_empty():
		return
	var t := _now()
	if side < 0.0:
		_boing_l = t
	else:
		_boing_r = t
	_last_abs = -1
	_closer = 0
	_toss_run = 0
	fx.cue("boing")
	var k := 0
	for f in gone:
		if Motion.reduce:
			sim.to_basket_now(f)
		else:
			sim.hop(f, 0, k * 0.06, BOING_HIGH, -side * (1.0 + k % 2), BOING_LONG)
		_dizzy_until[f] = t + Sim.ARC_TIME * BOING_LONG + DIZZY_TIME
		k += 1
	if Motion.reduce:
		sim.snap()
	var foot := _bale_foot(side) + Vector2(0.0, -_cup * 1.2)
	_rw.sticker(tr("BAL_W_BOING"), foot + Vector2(-side * _cup * 1.7, -_cup * 1.4), 58, 1.1, true, Color.WHITE, false, "boing", 20.0)
	if not Motion.reduce:
		_rw.spray(foot, Pal.STRAW, 10, 520.0, "confetti", 0.9)
		_rw.spray(foot, Pal.STRAW.lerp(Pal.PAPER, 0.4), 6, 380.0, "confetti", 0.7)
		fx.puff(_bale_foot(side) + Vector2(0.0, -_cup * 0.4), Pal.STRAW, 6)
	_tell("BAL_BOING_SAID")
	_busy_for(Sim.ARC_TIME * BOING_LONG + DIZZY_TIME)
	_moving = true

## The beam has come to rest: the level moment, the solve, or a tock -- and
## a move that brought it nearer level is cheered, louder each time in a row.
func _on_rest() -> void:
	if not sim.calm():
		return
	var level: bool = state.torque() == 0 and state.in_basket() < state.fruit.size()
	if is_solved():
		check_solved()
		return
	if state.boing and _bale_hit():
		_boing()
		return
	var on := state.fruit.size() - state.in_basket()
	var off := absi(state.torque())
	if level and not _was_level:
		_level_at = _now()
		fx.cue("level")
		_cheer_level()
		if state.in_basket() > 0:
			_tell("BAL_LEVEL_MORE")
	elif not level and on > 0:
		if _last_abs >= 0 and off < _last_abs:
			_closer += 1
			_cheer_closer(off)
		else:
			if _last_abs >= 0 and off > _last_abs:
				_closer = 0
			fx.cue("tock", 1.0, -10.0)
	_last_abs = off if on > 0 else -1
	_was_level = level

## Where a word over the seesaw is lettered, in the card's pixels.
func _word_at() -> Vector2:
	# in the open sky between the bunting's lowest flag and the glass
	var flags := SIGN_Y + SIGN_H + _cup * (0.25 + 0.6 + 0.46)
	var glass := _pivot.y - sim.top - _cup * (VIAL_UP + VIAL_H * 0.5)
	return Vector2(size.x * 0.5, minf(lerpf(flags, glass, 0.45), glass - _cup * 0.7))

## Nearer level than the last time the beam stood still.
func _cheer_closer(off: int) -> void:
	var word: String = "BAL_W_SO_CLOSE" if off <= 2 else WORDS[mini(_closer - 1, WORDS.size() - 1)]
	var n := mini(_closer, 4)
	fx.cue("tock", 1.15 + 0.08 * n, -6.0)
	_sun_kick_at = _now()
	_busy_for(0.6)
	var at := _vial_centre()
	_rw.sticker(tr(word), _word_at(), 50 + 6 * n, 1.1 + 0.1 * n, true, Color.WHITE, n >= 3 or off <= 2, "closer", 26.0)
	_rw.spray(at, Pal.LEAF_LIGHT, 5 + 2 * n, 480.0, "spark", 0.9)
	_rw.spray(at, Pal.SUN, 2 + n, 520.0, "star", 0.7)
	_rw.ring(at, _cup * (0.9 + 0.15 * n), Color(Pal.GOOD, 0.8))

## Level, with fruit still in the basket: a sticker, confetti out of the
## glass, the plank gold, every fruit on it cheering.
func _cheer_level() -> void:
	var t := _now()
	_cheer_at = t
	_gold_at = t
	_sun_kick_at = t
	_closer = 0
	_busy_for(GOLD_TIME + CHEER_TIME)
	var at := _vial_centre()
	_rw.sticker(tr("BAL_W_LEVEL"), _word_at(), 88, 1.6, true, Color.WHITE, true, "closer", 30.0)
	_rw.spray(at, Pal.SUN, 10, 700.0, "star", 1.0)
	_rw.spray(at, Color("fffaf0"), 8, 600.0, "spark", 1.1)
	for k in 3:
		_rw.spray(at, Rewards.CONFETTI[k * 2], 7, 760.0, "confetti", 1.0)
	_rw.ring(at, _cup * 1.6, Color(Pal.SUN, 0.9))
	_rw.ring(at, _cup * 2.3, Color(Pal.GOOD, 0.6), 0.12)

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
	if _bale_mesh == null:
		_bale_mesh = _build_bale()
	if _bale_mesh != null:
		for side: float in [-1.0, 1.0]:
			var sy := _bale_scale(_boing_l if side < 0.0 else _boing_r)
			draw_mesh(_bale_mesh, null, Transform2D(0.0, Vector2(2.0 - sy, sy), 0.0, _bale_foot(side)))
		shown.append(_bale_mesh)
	draw_mesh(_keel, null, _plank_xf())
	if _live != null:
		draw_mesh(_live, null)
		shown.append(_live)
	draw_mesh(_plank, null, _plank_xf())
	var gold := _gold_level()
	if gold > 0.0:
		if _plank_gold == null:
			_plank_gold = _build_plank_gold()
		draw_mesh(_plank_gold, null, _plank_xf(), Color(1, 1, 1, gold))
		shown.append(_plank_gold)
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
	if _aim_a > 0.0:
		if _aim_mesh == null:
			var ab := Face.Builder.new()
			Scenery.soft_disc(ab, Vector2.ZERO, sim.r * 1.5, sim.r * 0.9, Color(Pal.SUN, 0.5))
			ab.stroke(Face.Builder.ring(Vector2.ZERO, sim.r * 0.95, sim.r * 0.4), 4.0, Color(Pal.PAPER, 0.9), true)
			_aim_mesh = ab.mesh()
		var pulse := 1.0 if Motion.reduce else 1.0 + 0.07 * sin(t * 9.0)
		_front.draw_mesh(_aim_mesh, null, xf * Transform2D(0.0, Vector2.ONE * pulse, 0.0, Vector2(_aim_x * _cup, -sim.top - sim.r * 0.15)),
			Color(1, 1, 1, _aim_a))
		shown.append(_aim_mesh)
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
	elif state.in_basket() < state.fruit.size():
		var near := clampf(1.0 - absf(sim.reading()) / VIAL_TICKS, 0.0, 1.0)
		glow = maxf(glow, 0.4 * near * near)
	if glow > 0.0:
		_front.draw_mesh(_glow, null, xf * Transform2D(0.0, Vector2(0.0, vial_y)), Color(1, 1, 1, glow))
	var sx := 1.0 if Motion.reduce else 1.0 + clampf(absf(_bubble_v) * 0.06, 0.0, 0.45)
	_front.draw_mesh(_bubble, null, xf * Transform2D(0.0, Vector2(sx, 1.0 / sx), 0.0, Vector2(_bubble_x * tick, vial_y)))
	# pins through the stalks
	for f in state.fruit.size():
		if state.pinned[f] or state.hinted[f]:
			var at: Vector2 = sim.position(f)
			var ang: float = _faces[f].rotation
			var head := at + Vector2(0.0, -sim.r * 1.02).rotated(ang)
			_front.draw_mesh(_gold_pin if state.hinted[f] else _pin, null, Transform2D(ang, head))
	_draw_tags(t, shown)
	_draw_pill(t, shown)
	_draw_sign(t, shown)
	_draw_toast(t, shown)
	_front_shown = shown

## How gold the plank is: a flash on a level, held once solved.
func _gold_level() -> float:
	if Motion.reduce:
		return 0.6 if _solved_at >= 0.0 else 0.0
	var g := Motion.flash_level(_now() - _gold_at, 0.12, GOLD_TIME - 0.12)
	if _solved_at >= 0.0:
		g = maxf(g, 0.55 + 0.15 * sin((_now() - _solved_at) * 5.0))
	return g

func _build_plank_gold() -> ArrayMesh:
	var b := Face.Builder.new()
	var top := sim.top
	Scenery.soft_disc(b, Vector2(0.0, 0.0), _half * 1.08, _cup * 0.55, Color(Pal.SUN, 0.35))
	b.fan(Face.Builder.round_rect(Vector2(-_half, -top), Vector2(_half * 2.0, top * 2.0), top), Color(Pal.SUN, 0.55))
	b.fan(Face.Builder.round_rect(Vector2(-_half * 0.95, -top * 0.8), Vector2(_half * 1.9, top * 0.45), top * 0.2), Color(1, 1, 0.9, 0.6))
	return b.mesh()

func _tick_px() -> float:
	return (VIAL_W * _cup * 0.5 - VIAL_H * _cup * 0.5) / (VIAL_TICKS + 0.6)

## The sky, drawn behind the board: its gradient, a sun whose rays turn and
## swell on a good move, two clouds drifting, a line of bunting fluttering
## over the seesaw, and on the solve a rainbow growing over it all.
func _draw_sky() -> void:
	if state.fruit.is_empty() or size.x <= 0.0:
		return
	var t := _now()
	var w := size.x
	var shown: Array = []
	if _sky_mesh == null:
		var b := Face.Builder.new()
		_grad(b, Rect2(0.0, 0.0, w, _ground + 4.0), Pal.SKY_TOP.lerp(Pal.PAPER, 0.35), Pal.SKY_HORIZON.lerp(Pal.PAPER, 0.25))
		_sky_mesh = b.mesh()
		_sun_mesh = _build_sun()
		_rays_mesh = _build_rays()
		_cloud_meshes = []
		for r: float in [0.32, 0.24]:
			var cb := Face.Builder.new()
			Scenery.cloud(cb, Vector2.ZERO, _cup * r, Pal.CLOUD)
			_cloud_meshes.append(cb.mesh())
	_sky.draw_mesh(_sky_mesh, null)
	shown.append(_sky_mesh)
	# evening: a warm wash from the horizon up as the sun goes, deeper at
	# night, and the stars
	var dusk := maxf(smoothstep(0.4, 1.0, _sun_day) * 0.55, _night * 0.8)
	if dusk > 0.0:
		if _dusk_mesh == null:
			var db := Face.Builder.new()
			_grad(db, Rect2(0.0, 0.0, w, _ground + 4.0), Color("6f63a8"), Color("f3a86b"))
			_dusk_mesh = db.mesh()
		_sky.draw_mesh(_dusk_mesh, null, Transform2D.IDENTITY, Color(1, 1, 1, dusk))
		shown.append(_dusk_mesh)
	if _night > 0.0:
		# the twinkle is slow: a new mesh ten times a second is plenty
		var slot := int(t * 10.0)
		if _stars_mesh == null or slot != _stars_slot or _night < 1.0:
			_stars_mesh = _build_stars(t, _night)
			_stars_slot = slot
		_sky.draw_mesh(_stars_mesh, null)
		shown.append(_stars_mesh)
	var calm := Motion.reduce
	var tt := 0.0 if calm else t
	# the rainbow, behind the sun and the clouds and under the hills
	if _rainbow_at > 0.0 or (_solved_at >= 0.0 and calm):
		var k := 1.0 if calm else clampf((t - _rainbow_at) / RAINBOW_TIME, 0.0, 1.0)
		if k > 0.0:
			if _rainbow_mesh == null or k < 1.0:
				_rainbow_mesh = _build_rainbow(1.0 - pow(1.0 - k, 3.0))
			_sky.draw_mesh(_rainbow_mesh, null)
			shown.append(_rainbow_mesh)
	var sun := _sun_at()
	var kick := 1.0 if calm else Motion.bump_scale(t - _sun_kick_at, 0.3, 0.5)
	var big := 1.25 if _solved_at >= 0.0 else 1.0
	var tint := _sun_tint()
	var giggle := 0.0 if calm else sin((t - _giggle_at) * 30.0) * 0.12 * maxf(0.0, 1.0 - (t - _giggle_at) / 0.7)
	_sky.draw_mesh(_rays_mesh, null, Transform2D(tt * 0.25 + 2.0 * maxf(0.0, 0.6 - (t - _sun_kick_at)), Vector2.ONE * kick * big, 0.0, sun), tint)
	_sky.draw_mesh(_sun_mesh, null, Transform2D(giggle, Vector2.ONE * (1.0 + (kick - 1.0) * 0.5), 0.0, sun), tint)
	shown.append_array([_rays_mesh, _sun_mesh])
	var clouds := [Vector2(w * 0.8, SIGN_Y + SIGN_H * 0.9), Vector2(w * 0.3, SIGN_Y + SIGN_H + _cup * 1.35)]
	for i in _cloud_meshes.size():
		var drift := sin(tt * 0.07 + i * 2.0) * _cup * 0.6
		_sky.draw_mesh(_cloud_meshes[i], null, Transform2D(0.0, clouds[i] + Vector2(drift, 0.0)))
		shown.append(_cloud_meshes[i])
	_bunting_mesh = _build_bunting(tt)
	_sky.draw_mesh(_bunting_mesh, null)
	shown.append(_bunting_mesh)
	_sky_shown = shown

## The sun: high in the corner all morning; on Hard and Insane it sinks a
## step a move, down behind the far hill at sunset.
func _sun_at() -> Vector2:
	var hi := Vector2(size.x * 0.13, SIGN_Y + _cup * 0.2)
	# fully behind the far hill (its top stands ~1.03 cups over the grass)
	var lo := Vector2(size.x * 0.11, _ground - _cup * 1.03 + _cup * SUN_R * 1.4)
	# the day walks it down to sitting on the hill by the last move (0.92);
	# the sunset itself is the last dip
	var d := _sun_day
	var k := d / 0.92 * 0.74 if d <= 0.92 else lerpf(0.74, 1.0, (d - 0.92) / 0.08)
	return hi.lerp(lo, k)

## The sun warms toward orange as it goes down.
func _sun_tint() -> Color:
	return Color.WHITE.lerp(Color(1.0, 0.72, 0.55), smoothstep(0.35, 1.0, _sun_day))

## A handful of twinkling stars in the evening sky, faded in by `k`.
func _build_stars(t: float, k: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var spots := [Vector2(0.08, 0.3), Vector2(0.22, 0.12), Vector2(0.36, 0.42), Vector2(0.62, 0.36), Vector2(0.72, 0.1),
		Vector2(0.9, 0.28), Vector2(0.52, 0.62), Vector2(0.14, 0.7), Vector2(0.84, 0.66), Vector2(0.3, 0.86), Vector2(0.94, 0.9)]
	var top := SIGN_Y
	var bottom := _ground - _cup * 1.4
	for i in spots.size():
		var sp: Vector2 = spots[i]
		var at := Vector2(size.x * sp.x, lerpf(top, bottom, sp.y))
		var tw := 0.6 + 0.4 * sin((0.0 if Motion.reduce else t) * (1.7 + 0.37 * i) + i * 1.9)
		Rewards.star(b, at, _cup * (0.07 + 0.03 * (i % 3)) * (0.8 + 0.2 * tw), Color(Color("fff6d8"), k * tw))
	return b.mesh()

func _build_sun() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := _cup * SUN_R
	Scenery.soft_disc(b, Vector2.ZERO, r * 1.9, r * 1.9, Color(Pal.SUN, 0.18))
	b.disc(Vector2.ZERO, r, Pal.SUN)
	b.disc(Vector2(-r * 0.08, -r * 0.1), r * 0.84, Pal.SUN.lerp(Color("ffe39a"), 0.6))
	# a sleepy smile
	var ink := Color(Pal.TEXT, 0.7)
	for side: float in [-1.0, 1.0]:
		var e := Vector2(side * r * 0.33, -r * 0.08)
		b.stroke(PackedVector2Array([e + Vector2(-r * 0.12, 0.0), e + Vector2(0.0, r * 0.08), e + Vector2(r * 0.12, 0.0)]), maxf(2.5, r * 0.07), ink)
		b.ellipse(Vector2(side * r * 0.52, r * 0.2), r * 0.13, r * 0.08, Color(Pal.BERRY, 0.3))
	b.stroke(PackedVector2Array([Vector2(-r * 0.18, r * 0.22), Vector2(0.0, r * 0.34), Vector2(r * 0.18, r * 0.22)]), maxf(2.5, r * 0.07), ink)
	return b.mesh()

func _build_rays() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := _cup * SUN_R
	Rewards.sunrays(b, Vector2.ZERO, r * 1.1, r * 1.75, 12, 0.0, Color(Pal.SUN, 0.5))
	return b.mesh()

## A rainbow over the seesaw, grown to `k` of its sweep, left foot first.
func _build_rainbow(k: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var c := Vector2(_pivot.x, _ground + _cup * 0.3)
	var band := _cup * 0.13
	var r0 := _half * 1.02
	var n := 40
	for i in RAINBOW.size():
		var r := r0 + (RAINBOW.size() - 1 - i) * band
		var pts := PackedVector2Array()
		for j in n + 1:
			var ang := PI + PI * k * float(j) / n
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		b.stroke(pts, band + 1.0, Color(RAINBOW[i], 0.62), false, false)
	return b.mesh()

## A string of pennants over the scene, fluttering; livelier on a good move.
func _build_bunting(tt: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var w := size.x
	var y0 := SIGN_Y + SIGN_H + _cup * 0.25
	var sag := _cup * 0.6
	var n := 24
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(-10.0 + (w + 20.0) * u, y0 + sag * 4.0 * u * (1.0 - u)))
	b.stroke(pts, 3.0, Pal.ROPE_HEMP.darkened(0.1))
	var flags := 11
	var excite := 0.0 if Motion.reduce else clampf(1.0 - (_now() - _sun_kick_at) / 1.2, 0.0, 1.0)
	if _solved_at >= 0.0 and not Motion.reduce:
		excite = maxf(excite, 0.6)
	for i in flags:
		var u := (i + 0.5) / flags
		var top := Vector2(-10.0 + (w + 20.0) * u, y0 + sag * 4.0 * u * (1.0 - u))
		var fw := _cup * 0.34
		var fh := _cup * 0.46
		var sway := sin(tt * (2.2 + 5.0 * excite) + i * 0.9) * (0.08 + 0.22 * excite)
		var tip := top + Vector2(0.0, fh).rotated(sway)
		var col: Color = Rewards.CONFETTI[i % Rewards.CONFETTI.size()]
		b.polygon(PackedVector2Array([top + Vector2(-fw * 0.5, 0.0), top + Vector2(fw * 0.5, 0.0), tip]), col)
		b.polygon(PackedVector2Array([top + Vector2(-fw * 0.5, 0.0), top + Vector2(0.0, 0.0), tip]), Color(col.lightened(0.25), 0.6))
	return b.mesh()

## The air over the fruit: trails behind anything flying, a bead of sweat
## on a fruit at the low end, and two butterflies about the meadow.
func _draw_air() -> void:
	if state.fruit.is_empty() or size.x <= 0.0:
		return
	var t := 0.0 if Motion.reduce else _now()
	var b := Face.Builder.new()
	for f in _trails.size():
		var tr_: Array = _trails[f]
		var col: Color = Pal.SUN if f == _hint_f else Fruit.colour(state.fruit[f]).lerp(Pal.PAPER, 0.45)
		for i in tr_.size():
			var k := float(i + 1) / (TRAIL_N + 1)
			b.disc(tr_[i], sim.r * (0.2 + 0.5 * k), Color(col, 0.4 * k))
	for f in state.fruit.size():
		if _faces[f].expression == Face.Expr.WORRIED and not Motion.reduce:
			var p: Vector2 = sim.position(f)
			var fall := fmod(t * 0.9 + f * 0.37, 1.0)
			var at := p + Vector2(sim.r * 0.72, -sim.r * 0.55 + fall * sim.r * 0.6)
			var a := sin(PI * fall)
			var d := sim.r * 0.13
			b.polygon(PackedVector2Array([at + Vector2(0.0, -d * 2.0), at + Vector2(d, 0.0), at + Vector2(0.0, d), at + Vector2(-d, 0.0)]), Color(Pal.DEW.lerp(Pal.WATER, 0.3), 0.85 * a))
			b.disc(at + Vector2(0.0, d * 0.1), d, Color(Pal.DEW.lerp(Pal.WATER, 0.3), 0.85 * a))
	var now := _now()
	for f in state.fruit.size():
		var p: Vector2 = sim.position(f)
		if now < _dizzy_until[f] and int(sim.bodies[f].mode) == Sim.BASKET:
			# seeing stars: three circling over its head
			var fade := clampf(_dizzy_until[f] - now, 0.0, 1.0)
			for k in 3:
				var a := t * 5.0 + TAU * k / 3.0 + f
				var at := p + Vector2(cos(a) * sim.r * 0.75, -sim.r * 1.15 + sin(a) * sim.r * 0.22)
				Rewards.star(b, at, sim.r * 0.16, Color(Pal.SUN, fade), a)
		elif _out_card and not _shown_answer:
			# nodded off: a z floats up off every fruit, now and then
			var ph := fmod(t * 0.55 + f * 0.29, 1.0)
			var zr := sim.r * (0.14 + 0.12 * ph)
			var at := p + Vector2(sim.r * (0.6 + 0.5 * ph), -sim.r * (0.8 + 1.4 * ph))
			var za := sin(PI * ph) * 0.9
			b.stroke(PackedVector2Array([at + Vector2(-zr, -zr), at + Vector2(zr, -zr), at + Vector2(-zr, zr), at + Vector2(zr, zr)]),
				maxf(2.5, zr * 0.35), Color(Pal.PAPER, za))
	for i in 2:
		var home := Vector2(size.x * (0.22 if i == 0 else 0.8), _ground + (_basket.position.y - _ground) * 0.35 - _cup * (0.6 + 0.8 * i))
		var p := home + Vector2(sin(t * 0.43 + i * 2.1) * _cup * 1.2, sin(t * 0.71 + i) * _cup * 0.55 + sin(t * 2.3 + i) * _cup * 0.1)
		_butterfly(b, p, _cup * 0.24, absf(sin(t * 11.0 + i * 1.3)), Pal.FLOWER if i == 0 else Pal.SUN, cos(t * 0.43 + i * 2.1))
	if b.verts.is_empty():
		return
	_air_mesh = b.mesh()
	_air.draw_mesh(_air_mesh, null)

static func _butterfly(b: Face.Builder, at: Vector2, r: float, open: float, col: Color, heading: float) -> void:
	var o := 0.25 + 0.75 * open
	var lean := 0.25 * signf(heading)
	for side: float in [-1.0, 1.0]:
		var up := at + Vector2(side * r * 0.55 * o, -r * 0.3).rotated(lean)
		var dn := at + Vector2(side * r * 0.4 * o, r * 0.35).rotated(lean)
		b.ellipse(up, r * 0.6 * o, r * 0.55, col)
		b.ellipse(dn, r * 0.42 * o, r * 0.38, col.darkened(0.15))
		b.disc(up + Vector2(side * r * 0.1 * o, -r * 0.05), r * 0.16 * o, Color(Pal.PAPER, 0.8))
	b.stroke(PackedVector2Array([at + Vector2(0.0, -r * 0.5).rotated(lean), at + Vector2(0.0, r * 0.55).rotated(lean)]), maxf(2.0, r * 0.18), Pal.TEXT)

## The sky, the hills, the meadow, the trestle's legs, the bales and the
## basket's dark inside.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var w := size.x
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
	# the bales' shadows; the bales themselves are _build_bale, drawn on
	# their own so Insane's springy ones can bounce
	for side: float in [-1.0, 1.0]:
		Scenery.soft_disc(b, Vector2(_bale_x(side), _ground + _cup * 0.1), _cup * 0.95 * 0.7, _cup * 0.12, Color(Pal.TEXT, 0.14))
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
	# a gingham picnic blanket the basket stands on, running off the card
	_blanket(b)
	# the basket's ears, behind its body
	for side: float in [-1.0, 1.0]:
		var ear := Vector2(_basket.get_center().x + side * (_basket.size.x * 0.5 - _cup * 0.1), _basket.position.y + _cup * 0.3)
		b.stroke(Face.Builder.ring(ear + Vector2(side * _cup * 0.12, 0.0), _cup * 0.22, _cup * 0.26), _cup * 0.09, Pal.ACORN, true)
	# the basket's inside, behind its fruit
	var inner := Rect2(_basket.position + Vector2(_cup * 0.1, 0.0), Vector2(_basket.size.x - _cup * 0.2, _cup * 0.5))
	b.ellipse(inner.get_center(), inner.size.x * 0.5, inner.size.y * 0.5, Pal.ACORN_DEEP.lerp(Pal.WOOD_DEEP, 0.4))
	return b.mesh()

## Where a bale stands: its centre's x, and its foot on the grass.
func _bale_x(side: float) -> float:
	return _pivot.x + side * (_half - _cup * 0.35) * cos(Sim.A_MAX)

func _bale_foot(side: float) -> Vector2:
	return Vector2(_bale_x(side), _ground + _cup * 0.12)

## A bale under an end of the plank, the stop it bottoms out on, about the
## middle of its foot. On Insane a coil spring sits in its top: those are
## the bales that bounce.
func _build_bale() -> ArrayMesh:
	var b := Face.Builder.new()
	var u := _half - _cup * 0.35
	var top := _pivot.y + u * sin(Sim.A_MAX) + sim.top * cos(Sim.A_MAX) + 2.0
	var h := _ground + _cup * 0.12 - top
	if h <= 8.0:
		return null
	var bw := _cup * 0.95
	b.fan(Face.Builder.round_rect(Vector2(-bw * 0.5, -h), Vector2(bw, h), _cup * 0.14), Pal.STRAW)
	b.fan(Face.Builder.round_rect(Vector2(-bw * 0.5, -h), Vector2(bw, h * 0.3), _cup * 0.12), Pal.STRAW.lerp(Pal.PAPER, 0.35))
	for k in 2:
		var sx := -bw * 0.22 + k * bw * 0.44
		b.fan(Face.Builder.round_rect(Vector2(sx - 3.0, -h), Vector2(6.0, h), 3.0), Pal.STRAP)
	if state.boing:
		# a red coil across the bale's face, and a cap on it: this bale bounces
		var y0 := -h + h * 0.36
		var y1 := -h * 0.12
		var n := 5
		var pts := PackedVector2Array()
		for i in n * 2 + 1:
			var yy := lerpf(y0, y1, float(i) / (n * 2))
			pts.append(Vector2((-1.0 if i % 2 == 0 else 1.0) * bw * 0.3, yy))
		b.stroke(pts, maxf(5.0, _cup * 0.09), Pal.BERRY_DEEP)
		b.stroke(pts, maxf(2.5, _cup * 0.04), Pal.BERRY.lerp(Pal.PAPER, 0.25))
		b.fan(Face.Builder.round_rect(Vector2(-bw * 0.4, y0 - _cup * 0.07), Vector2(bw * 0.8, _cup * 0.09), _cup * 0.04), Pal.BRASS)
	return b.mesh()

## A bale's squash and spring after it bounced, as a vertical scale.
func _bale_scale(at: float) -> float:
	var u := _now() - at
	if Motion.reduce or u < 0.0 or u > BOING_TIME:
		return 1.0
	return 1.0 - 0.28 * sin(u * 22.0) * exp(-u * 5.5)

## Red gingham under the basket, a little in perspective: wider at the foot.
func _blanket(b: Face.Builder) -> void:
	var top := _basket.position.y + _cup * 0.55
	var bottom := size.y + 4.0
	var cx := size.x * 0.5
	var wt := size.x * 0.46
	var wb := size.x * 0.56
	var quad := func(t0: float, t1: float, x0: float, x1: float, col: Color) -> void:
		# x0, x1 in -1..1 across the blanket, t0, t1 down it
		var y0 := lerpf(top, bottom, t0)
		var y1 := lerpf(top, bottom, t1)
		var h0 := lerpf(wt, wb, t0)
		var h1 := lerpf(wt, wb, t1)
		b.fan(PackedVector2Array([Vector2(cx + x0 * h0, y0), Vector2(cx + x1 * h0, y0), Vector2(cx + x1 * h1, y1), Vector2(cx + x0 * h1, y1)]), col)
	Scenery.soft_disc(b, Vector2(cx, bottom), wb * 1.02, _cup * 0.2, Color(Pal.TEXT, 0.12))
	quad.call(0.0, 1.0, -1.0, 1.0, Pal.PAPER)
	var n := 11
	var stripe := Color(Pal.BERRY, 0.32)
	for i in n:
		if i % 2 == 0:
			var x0 := -1.0 + 2.0 * i / n
			quad.call(0.0, 1.0, x0, x0 + 2.0 / n, stripe)
	var rows := 4
	for j in rows:
		if j % 2 == 0:
			quad.call(float(j) / rows, float(j + 1) / rows, -1.0, 1.0, stripe)
	# the hem
	quad.call(0.0, 0.035, -1.0, 1.0, Color(Pal.BERRY_DEEP, 0.35))

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

## The reading sign: what the beam says, once it has stopped to say it. It
## hangs on two ropes from the top of the card and swings after the beam,
## and the number pops whenever it changes.
func _draw_sign(t: float, shown: Array) -> void:
	var on := false
	for f in state.fruit.size():
		if int(sim.bodies[f].mode) == Sim.PLANK:
			on = true
			break
	if not on:
		_sign_text = ""
		return
	if _sign_mesh == null:
		var b := Face.Builder.new()
		var w := SIGN_W
		var h := SIGN_H
		var top := SIGN_Y - 30.0
		# the ropes, up out of the card
		for side: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([Vector2(side * w * 0.3, -top - 20.0), Vector2(side * w * 0.36, 10.0)]), 5.0, Pal.ROPE_HEMP)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, 4.0), Vector2(w, h), 20.0), Color(Pal.TEXT, 0.16))
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5, 0.0), Vector2(w, h), 20.0), Pal.SCALE_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(-w * 0.5 + 6.0, 6.0), Vector2(w - 12.0, h - 12.0), 15.0), Pal.SCALE_WOOD.lerp(Pal.PAPER, 0.55))
		b.stroke(PackedVector2Array([Vector2(-w * 0.4, h * 0.3), Vector2(-w * 0.1, h * 0.26)]), 2.0, Color(Pal.SCALE_DEEP, 0.25))
		b.stroke(PackedVector2Array([Vector2(w * 0.12, h * 0.78), Vector2(w * 0.4, h * 0.74)]), 2.0, Color(Pal.SCALE_DEEP, 0.25))
		for side: float in [-1.0, 1.0]:
			b.disc(Vector2(side * w * 0.36, 14.0), 5.5, Pal.BRASS_DEEP)
			b.disc(Vector2(side * w * 0.36 - 1.0, 13.0), 3.5, Pal.BRASS)
		_sign_mesh = b.mesh()
	var hang := Vector2(size.x * 0.5, SIGN_Y - 30.0)
	var rest := sim.beam_at_rest() and _held < 0
	var value := sim.reading() if not rest else float(state.torque())
	var over := absf(value) > VIAL_TICKS + 0.4
	var n := int(roundf(absf(value)))
	var text := ("%d+" % VIAL_TICKS) if over else str(mini(n, VIAL_TICKS))
	if rest and text != _sign_text:
		if _sign_text != "":
			_sign_pop_at = t
			_sign_av += 0.8 * (1.0 if randf() < 0.5 else -1.0)
			_busy_for(SIGN_POP)
		_sign_text = text
	var swing := Transform2D(_sign_a, hang)
	_front.draw_set_transform_matrix(swing)
	if n == 0 and rest and not over:
		# level: the sign glows
		if _glow != null:
			_front.draw_mesh(_glow, null, Transform2D(0.0, Vector2(2.2, 2.2), 0.0, Vector2(0.0, SIGN_H * 0.5)), Color(1, 1, 1, 0.7))
	_front.draw_mesh(_sign_mesh, null)
	shown.append(_sign_mesh)
	var alpha := 1.0 if rest else 0.45
	var font: Font = CozyTheme.display(700)
	var pop := 1.0 if Motion.reduce else Motion.bump_scale(t - _sign_pop_at, 0.45, SIGN_POP)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT).x
	var mid := Vector2(26.0, SIGN_H * 0.5)
	var ink := Pal.GOOD.lerp(Pal.TEXT, 0.25) if n == 0 and rest else Pal.TEXT
	_front.draw_set_transform_matrix(swing * Transform2D(0.0, Vector2(pop, pop), 0.0, mid))
	_front.draw_string(font, Vector2(-tw * 0.5, font.get_ascent(SIGN_FONT) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT, Color(ink, alpha))
	_front.draw_set_transform_matrix(swing)
	# a little seesaw beside the number, leaning the way the big one does
	var way := 0.0 if n == 0 and not over else signf(value)
	var c := Vector2(mid.x - tw * 0.5 - 40.0, SIGN_H * 0.5 + 6.0)
	var ink_icon := Color(Pal.TEXT, alpha * 0.75)
	_front.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -6.0), c + Vector2(10.0, 12.0), c + Vector2(-10.0, 12.0)]), ink_icon)
	var d := Vector2(cos(way * 0.4), sin(way * 0.4)) * 24.0
	_front.draw_line(c - d + Vector2(0.0, -8.0), c + d + Vector2(0.0, -8.0), ink_icon, 6.0, true)
	_front.draw_circle(c - d + Vector2(0.0, -8.0) + Vector2(0.0, -7.0), 5.0, ink_icon)
	_front.draw_circle(c + d + Vector2(0.0, -8.0) + Vector2(0.0, -7.0), 5.0, ink_icon)
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)

## Hard and Insane: a paper pill in the top corner with a little sun and
## the moves left before sunset. It pops on every move and warms when the
## day is nearly gone.
func _draw_pill(t: float, shown: Array) -> void:
	if not state.has_sunset() or (is_done() and not _shown_answer):
		return
	if _pill_mesh == null:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(0.0, 4.0), Vector2(PILL_W, PILL_H), PILL_H * 0.5), Color(Pal.TEXT, 0.14))
		b.fan(Face.Builder.round_rect(Vector2.ZERO, Vector2(PILL_W, PILL_H), PILL_H * 0.5), Pal.PAPER)
		var c := Vector2(PILL_H * 0.52, PILL_H * 0.5)
		Rewards.sunrays(b, c, PILL_H * 0.2, PILL_H * 0.34, 8, 0.0, Pal.SUN)
		b.disc(c, PILL_H * 0.2, Pal.SUN_DEEP)
		b.disc(c + Vector2(-1.5, -1.5), PILL_H * 0.16, Pal.SUN)
		_pill_mesh = b.mesh()
	var left := state.sun_left()
	var at := Vector2(size.x - PAD - PILL_W, SIGN_Y - 30.0)
	var pop := 1.0 if Motion.reduce else Motion.bump_scale(t - _sun_pop_at, 0.22, 0.4)
	var low := left <= SUN_LOW
	if low and not Motion.reduce and not _out_card:
		pop *= 1.0 + 0.04 * sin(t * 6.0)
	var mid := Vector2(PILL_W, PILL_H) * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * pop, 0.0, at + mid) * Transform2D(0.0, -mid)
	_front.draw_mesh(_pill_mesh, null, xf)
	shown.append(_pill_mesh)
	var font: Font = CozyTheme.display(700)
	var text := str(left)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PILL_FONT).x
	var ink := Pal.BERRY_DEEP if low else Pal.TEXT
	_front.draw_set_transform_matrix(xf)
	_front.draw_string(font, Vector2(PILL_H + (PILL_W - PILL_H - tw) * 0.5 - 4.0, PILL_H * 0.5 + font.get_ascent(PILL_FONT) * 0.36),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, PILL_FONT, ink)
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)

## Once the day is over -- solved or shown -- every fruit's weight swings
## down on a paper tag under its cup, from the middle out: the reveal.
func _draw_tags(t: float, shown: Array) -> void:
	if _tags_at < 0.0 or t < _tags_at:
		return
	var string_l := _cup * 0.34
	var tw_ := _cup * 0.5
	var th := _cup * 0.4
	if _tag_mesh == null:
		var b := Face.Builder.new()
		b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0.0, string_l)]), 2.5, Pal.ROPE_HEMP.darkened(0.15))
		b.fan(Face.Builder.round_rect(Vector2(-tw_ * 0.5, string_l + 3.0), Vector2(tw_, th), th * 0.25), Color(Pal.TEXT, 0.14))
		b.fan(Face.Builder.round_rect(Vector2(-tw_ * 0.5, string_l), Vector2(tw_, th), th * 0.25), Pal.PAPER)
		b.disc(Vector2(0.0, string_l + th * 0.16), th * 0.07, Pal.ROPE_HEMP.darkened(0.2))
		_tag_mesh = b.mesh()
	var font: Font = CozyTheme.display(700)
	var fs := int(th * 0.62)
	var xf := _plank_xf()
	for f in state.fruit.size():
		if int(sim.bodies[f].mode) != Sim.PLANK:
			continue
		var x := int(sim.bodies[f].cup)
		var u := (t - _tags_at - Motion.stagger(absi(x), TAG_STAGGER, 1.0)) / TAG_DROP
		if u <= 0.0:
			continue
		var k := 1.0 if Motion.reduce else Motion.back_out(minf(u, 1.0))
		var anchor: Vector2 = xf * Vector2(x * _cup, sim.top * 0.6)
		var swing := 0.0 if Motion.reduce else sin(t * 2.2 + x) * 0.07 + sin(u * 5.0) * 0.25 * exp(-u * 1.6)
		var m := Transform2D(swing, Vector2(1.0, k), 0.0, anchor)
		_front.draw_set_transform_matrix(Transform2D.IDENTITY)
		_front.draw_mesh(_tag_mesh, null, m)
		var text := str(sim.weights[f])
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_front.draw_set_transform_matrix(m)
		_front.draw_string(font, Vector2(-w * 0.5, string_l + th * 0.62 + font.get_ascent(fs) * 0.3), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Fruit.colour(state.fruit[f]).darkened(0.35))
	_front.draw_set_transform_matrix(Transform2D.IDENTITY)
	shown.append(_tag_mesh)

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
		if p.distance_to(_sun_at()) < _cup * SUN_R * 1.6:
			_giggle()
		return
	if state.out_of_sun():
		_tell("BAL_SUN_SET")
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
	_stretch_at[f] = _now()
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
			_by_hand[f] = true
			_toss_run = 0
			_spend()
			note_move()
		_moving = true
		return
	var x := _aim(f, sim.position(f))
	var v: Vector2 = sim.bodies[f].vel
	var start: Vector2 = sim.position(f)
	if x == State.BASKET and _basket.grow(_cup * 0.3).has_point(sim.position(f)):
		sim.hop(f, 0, 0.0)
	else:
		sim.release(f, x)
	# a toss: let go fast from well away from the cup it lands in
	var far := x != State.BASKET and absf(start.x - (_plank_xf() * Vector2(x * _cup, 0.0)).x) > TOSS_FAR * _cup
	var toss := far and v.length() > TOSS_V * _cup
	_tossed[f] = false
	if state.place(f, x):
		_tossed[f] = toss
		_by_hand[f] = true
		if not toss:
			_toss_run = 0
		_spend()
		note_move()
	_moving = true

## The sun, tapped: it giggles, its rays spin and a few hearts float off.
func _giggle() -> void:
	var t := _now()
	if t - _giggle_at < 0.5:
		return
	_giggle_at = t
	_sun_kick_at = t
	fx.cue("giggle", randf_range(0.95, 1.1))
	if not Motion.reduce:
		_rw.spray(_sun_at(), Pal.FLOWER, 4, 260.0, "heart", 0.8)
		_rw.spray(_sun_at(), Pal.SUN, 3, 320.0, "star", 0.6)
	_busy_for(0.8)

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

# --- the sunset (Hard and Insane) ---

## A move made: counted, and on Hard and Insane a step of the sun. The
## pill pops, and from SUN_LOW moves left the toast says the day is going.
func _spend() -> void:
	_all_moves += 1
	if not state.has_sunset():
		return
	state.spend()
	_sun_pop_at = _now()
	_busy_for(0.5)
	var left := state.sun_left()
	if left > 0 and left <= SUN_LOW:
		fx.cue("sun_low", 1.0 + 0.08 * (SUN_LOW - left), -4.0)
		if left == SUN_LOW:
			_tell("BAL_SUN_LOW")

## The last move is spent and the beam has settled short of level: the sun
## sinks behind the hill, the stars come out, the fruit nod off, and the
## card asks.
func _run_out() -> void:
	out_of_hearts = true
	_running = false
	_held = -1
	_night_at = _now()
	fx.cue("sunset")
	_tell("BAL_SUN_SET")
	_busy_for(CARD_AFTER + 0.5)
	_after(0.3 if Motion.reduce else CARD_AFTER, _open_card)
	_moving = true

## The card, over the whole screen: on the host so it covers the chrome, or
## on the root when there is none (a probe).
func _open_card() -> void:
	if not _out_card or is_done() or is_instance_valid(_card):
		return
	var card: Control = load(OUT_OF_SUN).new(state.bought, OUT_WORDS)
	_card = card
	card.one_more_row.connect(hour_back)
	card.show_code.connect(show_answer)
	var host := get_tree().get_first_node_in_group("puzzle_host")
	if host != null and host.is_ancestor_of(self):
		host.add_child(card)
	else:
		get_tree().root.add_child(card)

func _close_card() -> void:
	if is_instance_valid(_card) and not _card.is_queued_for_deletion():
		_card.queue_free()
	_card = null

## One more hour (the card's video), once a board: the sun climbs back a
## little, the stars go, the fruit wake.
func hour_back() -> void:
	if is_done() or not _out_card:
		return
	_close_card()
	state.buy_hour()
	out_of_hearts = false
	_running = true
	_night_at = -1.0
	fx.cue("hour_back")
	_sun_kick_at = _now()
	_rw.sticker(tr("BAL_W_HOUR"), _word_at(), 64, 1.4, true, Color.WHITE, true, "hour", 24.0)
	if not Motion.reduce:
		_rw.spray(_sun_at(), Pal.SUN, 10, 520.0, "star", 0.9)
	_busy_for(1.5)
	_moving = true
	moved.emit()

## Show the answer: every loose fruit hops to its answer cup, the weights
## swing down on tags under the plank, and the day ends unsolved.
func show_answer() -> void:
	if is_done():
		return
	_close_card()
	out_of_hearts = false
	_shown_answer = true
	var before := state.at.duplicate()
	state.show_answer()
	var k := 0
	for f in state.fruit.size():
		if state.loose(f) and int(before[f]) != state.at[f]:
			_hop(f, state.at[f], Motion.stagger(k, 0.12, 1.2))
			k += 1
	fx.cue("reveal")
	_tell("BAL_SHOWN")
	_tags_at = _now() + (0.0 if Motion.reduce else 0.9 + k * 0.12)
	_busy_for(3.5)
	_moving = true
	# ends through finish_unsolved, so the host logs puzzle_complete
	# {solved: false}; the check in _after_physics stays shut behind _done
	finish_unsolved()

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo() and not is_done() and not out_of_hearts and not state.out_of_sun()

## The last move taken back: the fruit hop to where they were. On Hard it is
## a move like any other, so it costs the sun a step.
func undo() -> bool:
	if not can_undo():
		return false
	_drop_held()
	var back: Array = state.undo()
	if back.is_empty():
		return false
	for mv in back:
		_hop(int(mv[0]), int(mv[1]), 0.0)
	_toss_run = 0
	_last_abs = -1
	_spend()
	fx.cue("undo")
	_moving = true
	moved.emit()
	return true

## A fruit in the hand when a HUD button takes over goes back where the
## rules say it is, so nothing is left held (and the beam can come to rest).
func _drop_held() -> void:
	if _held < 0:
		return
	var f := _held
	_held = -1
	_hop(f, state.at[f], 0.0)

func _hop(f: int, x: int, delay: float) -> void:
	_by_hand[f] = false
	sim.hop(f, x, delay)
	if Motion.reduce:
		sim.snap()

func hints_left() -> int:
	var budget: int = HINTS_BY_BAND[clampi(_difficulty, 0, 3)]
	if budget <= 0 or out_of_hearts or state.out_of_sun():
		return 0
	return maxi(0, budget + hints_extra - hints_used)

## One fruit flies to its answer cup and is pinned there in gold; whatever
## was in that cup goes home first.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or out_of_hearts or state.out_of_sun():
		return false
	_drop_held()
	var m: Dictionary = state.apply_hint()
	if m.is_empty():
		return false
	hints_used += 1
	# on Hard a hint is a move too: the sun goes down a step for it, so
	# video hints can not outlast the day
	_spend()
	var b: int = m.bumped
	if b >= 0:
		_hop(b, 0, 0.0)
	var f: int = m.f
	_hop(f, int(m.cup), 0.12 if b >= 0 else 0.0)
	_hint_f = f
	_busy_for(Sim.ARC_TIME + 0.8)
	if not Motion.reduce:
		var cup := int(m.cup)
		_after(Sim.ARC_TIME + (0.12 if b >= 0 else 0.0) + 0.05, func():
			var at := _plank_xf() * Vector2(cup * _cup, -sim.top - sim.r)
			fx.ring(at, sim.r * 1.8, Pal.SUN)
			_rw.spray(at, Pal.SUN, 10, 620.0, "star", 1.0)
			_rw.spray(at, Color("fffaf0"), 6, 520.0, "spark", 1.0)
			_rw.ring(at, sim.r * 2.4, Color(Pal.SUN, 0.9)))
	_tell("BAL_HINT")
	fx.cue("hint")
	_moving = true
	moved.emit()
	return true

## Reset sends the loose fruit home, and costs no sun (it shows nothing new
## and every fruit it sends home costs a move to bring back). Once the sun
## is down or the day ended there is nothing to reset.
func can_reset() -> bool:
	return not (out_of_hearts or state.out_of_sun() or (is_done() and not state.is_solved()))

func reset_board() -> void:
	if not can_reset():
		return
	_drop_held()
	var moved_fs := state.reset()
	var k := 0
	for f in moved_fs:
		_hop(f, 0, Motion.stagger(k, 0.06))
		k += 1
	_solved_at = -1.0
	_was_level = false
	_last_abs = -1
	_closer = 0
	_toss_run = 0
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
	var out := "⚖️ " + tr("BAL_SHARE") % [state.fruit.size(), state.cups().size()]
	if state.is_solved() and not _shown_answer and stamp_key() != "":
		var word: String = tr(stamp_key())
		out += "\n" + (("🌙 %s · %s" % [tr("BAL_BOING_SEAL"), word]) if state.boing else ("🏅 " + word))
	return out

# --- the stamp and the party ---

## The stamp's word: by moves beyond one per loose fruit (BAL_STAMP_1..5),
## or BAL_STAMP_MORE when the day needed One more hour. A restored daily
## reads it back from its record.
func stamp_key() -> String:
	if completed_record.has("stamp") and _all_moves == 0:
		return String(completed_record.stamp)
	if _all_moves == 0 and is_done():
		# a daily solved before stamps: no word to give back
		return ""
	if state.bought:
		return "BAL_STAMP_MORE"
	# a hinted fruit needed no move of the player's, and a hint is worth a
	# step on the stamp as well
	var loose := 0
	for f in state.fruit.size():
		if state.loose(f):
			loose += 1
	var extra := _all_moves - loose - hints_used
	for i in STAMP_STEPS.size():
		if extra <= int(STAMP_STEPS[i]):
			return "BAL_STAMP_%d" % (i + 1)
	return "BAL_STAMP_5"

func completion_record() -> Dictionary:
	return {"stamp": stamp_key()} if stamp_key() != "" else {}

## The seal drops onto the empty basket: gold with the word, or on Insane
## the night-blue seal with "Boing Bales" over it. It is the result, so it
## shows under reduce-motion too, standing still.
func _stamp_down(quiet := false) -> void:
	if is_instance_valid(_stamp) or not state.is_solved() or _shown_answer or stamp_key() == "":
		return
	var rad := STAMP_R * _cup
	var insane := state.boing
	var stamp := Control.new()
	stamp.name = "Stamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 3
	stamp.size = Vector2.ONE * rad * 2.0
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation = STAMP_TILT
	var mesh := Seal.mesh(rad, insane)
	var word: String = tr(stamp_key())
	var lines := [[Seal.tr_static("BAL_BOING_SEAL"), 0.24, 0.02], [word, 0.22, 0.36]] if insane \
		else [[word, 0.28, 0.12]]
	stamp.draw.connect(func() -> void:
		stamp.draw_mesh(mesh, null, Transform2D(0.0, stamp.pivot_offset))
		Seal.text(stamp, rad, lines))
	add_child(stamp)
	_stamp = stamp
	_place_stamp()
	if quiet or Motion.reduce:
		return
	fx.cue("stamp")
	stamp.scale = Vector2.ONE * STAMP_FROM
	stamp.modulate.a = 0.0
	var tw := stamp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stamp, "scale", Vector2.ONE, STAMP_DROP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp, "modulate:a", 1.0, STAMP_DROP * 0.6)
	tw.chain().tween_callback(func() -> void:
		Motion.squash(stamp, 0.22, 0.26)
		Haptics.play(Haptics.THUD)
		fx.ring(stamp.position + stamp.pivot_offset, rad * 0.9, Pal.MOON_INK if insane else Pal.SUN)
		fx.puff(stamp.position + stamp.pivot_offset + Vector2(0.0, rad * 0.8), Pal.WHEAT, 5))

## The seal sits on the basket's right, over its weave.
func _place_stamp() -> void:
	if not is_instance_valid(_stamp):
		return
	var rad := STAMP_R * _cup
	_stamp.size = Vector2.ONE * rad * 2.0
	_stamp.pivot_offset = _stamp.size * 0.5
	var centre := Vector2(_basket.end.x - rad * 1.25, _basket.get_center().y + _cup * 0.1)
	_stamp.position = centre - _stamp.pivot_offset
	_stamp.queue_redraw()

## After the hops: a party hat pops onto every fruit, from the middle out,
## and confetti flies off the plank.
func _party_on(quiet := false) -> void:
	if _party or not state.is_solved():
		return
	_party = true
	for f in state.fruit.size():
		var face: Control = _faces[f]
		face.hat_style = posmod(state.fruit[f] * 7 + f, 3)
		if quiet or Motion.reduce:
			face.hat = 1.0
			continue
		var tw := face.create_tween()
		tw.tween_property(face, "hat", 1.0, 0.32).from(0.0) \
			.set_delay(Motion.stagger(absi(state.at[f]), HAT_STAGGER, 0.8)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if quiet:
		return
	fx.cue("party")
	if not Motion.reduce:
		fx.confetti(_pivot + Vector2(0.0, -_cup), 44, _half * 1.6)
		_after(0.25, fx.cue.bind("confetti"))

# --- the win ---

func _on_solved() -> void:
	_solved_at = _now()
	_held = -1
	fx.cue("solved")
	_gold_at = _solved_at
	_sun_kick_at = _solved_at
	_rainbow_at = _solved_at + 0.35
	_rainbow_mesh = null
	_busy_for(WIN_HOLD + 0.5)
	_after(0.0 if Motion.reduce else HAT_AT, _party_on)
	_after(0.0 if Motion.reduce else STAMP_AT, _stamp_down)
	_tags_at = _now() + (0.0 if Motion.reduce else TAGS_AT)
	var at := _vial_centre()
	_rw.sticker(tr("BAL_W_BALANCED"), _word_at() + Vector2(0.0, -_cup * 0.15), 112, WIN_HOLD + 0.3, true, Color.WHITE, true, "closer")
	if not state.hinted.has(true):
		_after(0.5, func():
			_rw.sticker(tr("BAL_W_NO_HINTS"), _word_at() + Vector2(0.0, _cup * 0.62), 46, WIN_HOLD - 0.3, false, Pal.SUN, false, "nohints"))
	if not Motion.reduce:
		fx.ring(at, _cup * 1.6, Pal.SUN)
		_rw.ring(at, _cup * 2.6, Color(Pal.SUN, 0.9))
		_rw.ring(at, _cup * 3.6, Color(Pal.GOOD, 0.6), 0.15)
		_rw.spray(at, Pal.SUN, 16, 900.0, "star", 1.2)
		_rw.spray(at, Color("fffaf0"), 12, 760.0, "spark", 1.3)
		_rw.rain(2.6, ["confetti", "star", "confetti"], Rewards.CONFETTI)
		# every cup bursts, from the middle outwards
		for f in state.fruit.size():
			var cup := int(sim.bodies[f].cup)
			var kind: int = state.fruit[f]
			_after(0.12 + 0.11 * absi(cup), func():
				var p: Vector2 = sim.position(f)
				_rw.spray(p, Fruit.colour(kind), 8, 620.0, "confetti", 1.0)
				_rw.spray(p, Pal.SUN, 3, 560.0, "star", 0.8)
				_rw.ring(p, sim.r * 1.9, Color(Fruit.colour(kind), 0.8))
				fx.sparkle(p + Vector2(0.0, -sim.r)))
	_moving = true

func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	var labels: Array[String] = []
	for k in state.kinds():
		faces.append(Fruit.make(k, 140.0, Vector2.ZERO))
		labels.append(str(state.weights[k]))
	return {"faces": faces, "labels": labels, "subtitle": tr("BAL_WIN")}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_HOLD + 0.6

func restore_completed_board() -> void:
	state.show_answer()
	for f in state.fruit.size():
		sim.to_cup_now(f, state.at[f])
	sim.snap()
	_bubble_x = 0.0
	_solved_at = _now() - 100.0
	_rainbow_at = _solved_at
	_rainbow_mesh = null
	_held = -1
	_toast = ""
	_tags_at = _solved_at
	_party_on(true)
	_stamp_down(true)
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
