extends "res://core/puzzle_base.gd"

## Marigold as a flat board: a pond garden at dusk under an arbor, a field of
## flower buds, the family's sun at the top with a leaf spout, and a
## terracotta pot sliding along the bank at the foot. Drag to aim, let go and
## the sun shoots a seed; every bud it touches blooms, and the blooms are
## picked when the seed has gone. Bloom every marigold. The rules and the
## physics live in puzzles/marigold_state.gd, which this only draws.
##
## After the reference the user asked for (the Xbox classic of pegs, a
## launcher and a sliding bucket), re-dressed as a garden. Out of seeds with
## a marigold left, the garden grows back and the day goes on: a try, never
## a loss.
##
## How it is drawn. Meshes, most of them cached:
##   still -- the card, the dusk garden and the arbor, on a relayout only;
##   buds  -- every closed bud, rebuilt when one blooms or the garden grows;
##   lit   -- the blooms and the ones being picked, while any of them moves;
##   guide -- the dotted aim, when the aim moves;
##   trail -- the seed's wake, while a seed is out;
##   live  -- the garden's small breath, every frame, in two: under the
##            buds, fireflies, twinkling stars, drifting glints, the
##            lanterns' flicker and the ripples round every bloom; over
##            everything, a glint on a marigold now and then, the marigolds
##            flying up to their pips and the full bloom's petals;
##   pill  -- the multiplier's tag, rebuilt when it steps and popped by
##            transform;
##   the pot, the seed and the sun's three parts are built once and moved by
##   transform, so an idle garden rebuilds nothing.
##
## Spec: docs/superpowers/specs/2026-09-26-marigold-flat-design.md.

const State = preload("res://puzzles/marigold_state.gd")
const Parts = preload("res://ui/faces/marigold_parts.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Locale = preload("res://core/locale.gd")

# --- the screen, measured ---
## The card's inset round the field, the band over it the counts take, the
## card's corner, and the room under the field.
const INSET := 22.0
const BAND := 112.0
const CARD_RADIUS := 32.0
const FOOT := 10.0
## The sun's radius, in field units.
const SUN_R := 3.4
const SCORE_FONT := 52
const MULT_FONT := 40
const COUNT_FONT := 30
const FLOAT_FONT := 40
const BANNER_FONT := 104

# --- this board's own motion ---
## A bud opens over BLOOM_TIME when touched. The blooms are picked one after
## another, PICK_STEP apart (the whole shot's inside PICK_ALL), each fading
## over PICK_TIME with a petal puff.
const BLOOM_TIME := 0.24
const PICK_STEP := 0.07
const PICK_ALL := 1.3
const PICK_TIME := 0.2
## The aim's dots, GUIDE_GAP units apart, up to GUIDE_LEN of the way.
const GUIDE_GAP := 2.3
const GUIDE_LEN := 30.0
## The seed's wake: TRAIL points.
const TRAIL := 14
## The last marigold slows the garden to SLOW for SLOW_TIME of real time.
const SLOW := 0.25
const SLOW_TIME := 1.5
const BANNER_TIME := 2.4
const FLOAT_TIME := 1.1
const POT_GLOW_TIME := 0.5
const OUT_WAIT := 2.4
const WIN_HOLD := 1.2
const HINTS := 3
## A bloom rings the water RIPPLE_TIME; a picked bloom rises PICK_RISE units
## and turns as it fades; a bloomed marigold flies up to its pip over
## FLY_TIME. The sun recoils over RECOIL_TIME, the pot wobbles WOBBLE_TIME
## after it turns at an end and squashes CATCH_TIME when it catches a seed,
## the tag pops TAG_TIME when the multiplier steps. A marigold glints every
## GLINT_EVERY; the full bloom's petals fall for PETAL_TIME.
const RIPPLE_TIME := 0.5
const PICK_RISE := 2.6
const FLY_TIME := 0.6
const RECOIL_TIME := 0.32
const WOBBLE_TIME := 0.9
const CATCH_TIME := 0.34
const TAG_TIME := 0.4
const GLINT_EVERY := 1.7
const GLINT_TIME := 0.6
const PETAL_TIME := 4.5
const FIREFLIES := 8
## The reference's rising scale, one step a bloom within a shot: a major
## scale up an octave and a fifth, then held at the top.
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 40.0
const TIPS := ["MG_TIP_AIM", "MG_TIP_GOAL", "MG_TIP_POT"]
const BUD_BANDS := 6

var _state = State.new()
var fx: Node2D

## "aim", "shot" (a seed is out), "pick" (the blooms are picked), "out" (no
## seeds left, the garden about to grow back), "won".
var _phase := "aim"
var _aim := PI * 0.5
var _aiming := false
## The hint's long guide is shown for this aim until the aim moves.
var _super := false
var _acc := 0.0
var _slow_until := -100.0
## Per bud: when it bloomed and when it is picked (-1: not).
var _hit_at := PackedFloat32Array()
var _pick_at := PackedFloat32Array()
## The buds bloomed this shot, in the order they bloomed.
var _order := PackedInt32Array()
var _picking: Array = []
var _pick_done := 0.0
var _pick_result := {}
var _trails: Array = []
var _floats: Array = []
var _pot_glow_at := -100.0
var _fever_at := -100.0
var _fever_from := Vector2.ZERO
var _fever_pot := -1
var _fever_pot_at := -100.0
var _out_at := -100.0
var _grown_at := 0.0
var _opened := 0.0
var _solved_at := -1.0
var _blink_at := 0.0
var _expr := Face.Expr.HAPPY
var _expr_until := 0.0
var _log := ""
## The hint's search, on a worker thread: {"id", "box", "at"}; empty when none.
var _think := {}
var _shot_oranges := 0
var _shot_pot := false
var _shot_at := -100.0
var _pot_turn_at := -100.0
var _pot_last_dir := 1.0
## Ripples on the water: {"at" (field units), "t", "col"}.
var _ripples: Array = []
## Marigolds flying up to their pips: {"from" (px), "t"}.
var _flies: Array = []
var _mult_shown := 1
var _mult_at := -100.0
var _score_shown := 0.0
var _glint_i := -1
var _glint_at := -100.0
## The trough holds this many seeds: the try's first handful.
var _seeds_start := 10

var _still: ArrayMesh
## The closed buds in BUD_BANDS strips down the field, so a bloom rebuilds
## only its own strip.
var _buds: Array = []
var _lit: ArrayMesh
var _guide: ArrayMesh
var _trail: ArrayMesh
var _pot: ArrayMesh
var _pot_for := -1
var _seed: ArrayMesh
var _rays: ArrayMesh
var _body: ArrayMesh
var _body_for := ""
var _spout: ArrayMesh
var _spout_for := -1
var _back: ArrayMesh
var _live: ArrayMesh
var _live_back: ArrayMesh
var _pill: ArrayMesh
var _pill_for := -1
var _hud: ArrayMesh
var _hud_for := ""
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _toast := ""
var _toast_at := -100.0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "marigold"
func title() -> String: return "Marigold"

func rules() -> String:
	return tr("MG_RULES")

## Hint only: nothing to take back once a seed has flown. Reset is the host's.
func capabilities() -> Array[String]:
	return ["hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	resized.connect(_layout)
	solved.connect(_on_solved)

func _exit_tree() -> void:
	if not _think.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		_think = {}

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_opened = _now()
	_fresh(_opened)
	_log = ""
	_layout()
	fx.cue("enter")
	_say(tr(TIPS[0]), Face.Expr.HAPPY)

## Everything a new try starts from.
func _fresh(t: float) -> void:
	var n: int = _state.pos.size()
	_hit_at = PackedFloat32Array()
	_hit_at.resize(n)
	_hit_at.fill(-1.0)
	_pick_at = PackedFloat32Array()
	_pick_at.resize(n)
	_pick_at.fill(-1.0)
	_order = PackedInt32Array()
	_picking = []
	_trails = []
	_floats = []
	_phase = "aim"
	_aiming = false
	_super = false
	_aim = PI * 0.5
	_acc = 0.0
	_slow_until = -100.0
	_fever_at = -100.0
	_fever_pot = -1
	_fever_pot_at = -100.0
	_out_at = -100.0
	_solved_at = -1.0
	_grown_at = t
	_blink_at = t + 2.5
	_buds = []
	_lit = null
	_guide = null
	_back = null
	_hud = null
	_buds = []
	_ripples = []
	_flies = []
	_mult_shown = _state.mult()
	_mult_at = -100.0
	_pill = null
	_score_shown = float(_state.score)
	_shot_at = -100.0
	_seeds_start = _state.seeds

# --- layout ---

## Pixels a field unit.
func _s() -> float:
	var w := (size.x - 2.0 * INSET) / State.W
	var h := (size.y - BAND - INSET - FOOT) / State.H
	return maxf(0.0, minf(w, h))

## The field's top-left.
func _origin() -> Vector2:
	var s := _s()
	var room := size.y - BAND - FOOT
	return Vector2((size.x - State.W * s) * 0.5, BAND + maxf(0.0, (room - State.H * s) * 0.5))

func _pt(v: Vector2) -> Vector2:
	return _origin() + v * _s()

func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_buds = []
	_lit = null
	_guide = null
	_trail = null
	_pot = null
	_seed = null
	_rays = null
	_body = null
	_spout = null
	_back = null
	_hud = null
	_pill = null
	queue_redraw()

# --- the frame loop ---

func _process(delta: float) -> void:
	super(delta)
	if _s() <= 0.0 or _state.pos.is_empty():
		return
	var t := _now()
	var sd := delta * _time_scale(t)
	if _phase == "shot":
		_acc += sd
		var events: Array = []
		var n := 0
		while _acc >= State.DT and n < 60:
			_state.step(events)
			_acc -= State.DT
			n += 1
			if _state.balls.is_empty():
				break
		_handle(events, t)
		_follow_trails()
		if _state.balls.is_empty():
			_end_shot(t)
	elif not _done:
		_state.step_pot(sd)
	if _state.pot_dir != _pot_last_dir:
		_pot_last_dir = _state.pot_dir
		_pot_turn_at = t
	_tick_garden(t, delta)
	if not _think.is_empty() and WorkerThreadPool.is_task_completed(int(_think.id)):
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		var box: Dictionary = _think.box
		_think = {}
		if _phase == "aim" and not _done:
			_aim = float(box.a)
			_super = true
			_guide = null
			fx.ring(_pt(State.SUN_C), SUN_R * _s() * 1.6, Pal.SUN)
			fx.cue("hint")
			_tell("MG_HINT", Face.Expr.HAPPY)
	if _phase == "pick" and t >= _pick_done:
		_after_pick(t)
	if _phase == "out" and t - _out_at >= OUT_WAIT:
		_regrow(t)
	if not Motion.reduce and t > _blink_at + Face.BLINK_TIME:
		_blink_at = t + randf_range(2.8, 5.5)
	if _lit_moving(t):
		_lit = null
	if _buds_moving(t):
		_buds = []
	queue_redraw()

func _time_scale(t: float) -> float:
	if Motion.reduce:
		return 1.0
	return SLOW if t < _slow_until else 1.0

## Every seed's wake: the last TRAIL places it was drawn at.
func _follow_trails() -> void:
	while _trails.size() < _state.balls.size():
		_trails.append(PackedVector2Array())
	for k in _state.balls.size():
		var tr_pts: PackedVector2Array = _trails[k]
		tr_pts.append(Vector2(_state.balls[k].p))
		if tr_pts.size() > TRAIL:
			tr_pts.remove_at(0)
		_trails[k] = tr_pts
	_trail = null

func _lit_moving(t: float) -> bool:
	if not _picking.is_empty():
		return true
	for i in _order:
		if t - _hit_at[i] < BLOOM_TIME + 0.05:
			return true
	return false

func _buds_moving(t: float) -> bool:
	if Motion.reduce:
		return false
	return t - _grown_at < _entrance_time()

func _entrance_time() -> float:
	return Motion.ENTER_DELAY + 0.1 + 0.9 + Motion.POP_IN + 0.05

## The small things that run on the frame clock: the score rolling up to
## what it is, the tag stepping, the flying marigolds landing on their pips,
## the ripples dying, and the next marigold to glint.
func _tick_garden(t: float, delta: float) -> void:
	var target := float(_state.score + (_state.shot_points if _phase == "shot" else 0))
	if Motion.reduce or target < _score_shown:
		_score_shown = target
	else:
		_score_shown = minf(target, _score_shown + maxf((target - _score_shown) * minf(1.0, delta * 9.0), 60.0 * delta))
	var m: int = _state.mult()
	if m != _mult_shown:
		if m > _mult_shown and not Motion.reduce:
			_mult_at = t
			fx.ring(_tag_centre(), 70.0, Pal.MG_ORANGE_HI, 0.5)
			fx.sparkle(_tag_centre(), Pal.SUN_RAY)
		_mult_shown = m
		_pill = null
	var keep: Array = []
	for f: Dictionary in _flies:
		if t - float(f.t) >= FLY_TIME:
			fx.sparkle(_pip_at(_pips_filled(t)), Pal.SUN_RAY)
		else:
			keep.append(f)
	if keep.size() != _flies.size():
		_flies = keep
		_hud = null
	var alive: Array = []
	for r: Dictionary in _ripples:
		if t - float(r.t) < RIPPLE_TIME:
			alive.append(r)
	_ripples = alive
	if t - _glint_at > GLINT_EVERY and not Motion.reduce and _phase != "won":
		_glint_at = t
		_glint_i = -1
		var up: Array = []
		for i in _state.pos.size():
			if _state.kind[i] == State.ORANGE and _state.st[i] == State.UP:
				up.append(i)
		if not up.is_empty():
			_glint_i = up[randi() % up.size()]

## The pips lit: every marigold bloomed, less the ones still flying up.
func _pips_filled(t: float) -> int:
	var n: int = _state.orange_total - _state.oranges_left
	for f: Dictionary in _flies:
		if t - float(f.t) < FLY_TIME:
			n -= 1
	return maxi(0, n)

# --- a shot's events ---

func _handle(events: Array, t: float) -> void:
	var s := _s()
	for e: Dictionary in events:
		match String(e.t):
			"hit":
				var i: int = e.i
				_hit_at[i] = t
				if not Motion.reduce:
					_ripples.append({"at": _state.pos[i], "t": t, "col": Parts.colours(_state.kind[i])[1]})
					if _state.kind[i] == State.ORANGE:
						_flies.append({"from": _pt(_state.pos[i]), "t": t + BLOOM_TIME * 0.6})
						_hud = null
				_order.append(i)
				_dirty_bud(i)
				var step: int = SCALE[mini(int(e.n) - 1, SCALE.size() - 1)]
				fx.cue("hit", pow(2.0, float(step) / 12.0))
				match _state.kind[i]:
					State.ORANGE:
						_shot_oranges += 1
						_mood(Face.Expr.JOY, 0.8)
						fx.puff(_pt(_state.pos[i]), Pal.MG_ORANGE_HI, 4)
					State.PURPLE:
						fx.cue("violet")
						fx.sparkle(_pt(_state.pos[i]), Pal.MG_PURPLE_HI)
						_float(_pt(_state.pos[i]), "+%s" % Locale.number(500 * _state.mult()), Pal.MG_PURPLE_HI)
					State.GREEN:
						fx.cue("clover")
						fx.sparkle(_pt(_state.pos[i]), Pal.MG_GREEN_HI)
			"split":
				_tell("MG_SPLIT", Face.Expr.JOY)
			"wall":
				if float(e.speed) > 20.0:
					fx.cue("wall", 1.0, -4.0)
			"pot":
				_pot_glow_at = t
				_ripples.append({"at": Vector2(e.at), "t": t, "col": Pal.SUN_RAY})
				_shot_pot = true
				fx.cue("pot")
				fx.sparkle(_pt(e.at), Pal.SUN)
				_float(_pt(e.at) - Vector2(0.0, s * 3.0), tr("MG_SEED_BACK"), Pal.SUN_RAY)
				_mood(Face.Expr.JOY, 1.0)
			"fever":
				_fever_at = t
				_fever_from = _pt(e.at)
				_slow_until = t + SLOW_TIME
				_back = null
				fx.cue("fever")
				fx.ring(_pt(e.at), s * 6.0, Pal.SUN, 0.9)
				_mood(Face.Expr.JOY, 30.0)
			"fever_pot":
				_fever_pot = int(e.k)
				_fever_pot_at = t
				fx.cue("fever_pot")
				var at := _pt(Vector2((float(e.k) + 0.5) * State.W / float(State.FEVER_POTS.size()), State.POT_Y))
				fx.sparkle(at, Pal.SUN)
				fx.puff(at, Pal.MG_ORANGE_HI, 8)
				_float(at - Vector2(0.0, s * 5.0), "+%s" % Locale.number(State.FEVER_POTS[e.k]), Pal.SUN_RAY)
			"drain":
				fx.cue("drain", 1.0, -6.0)
			"unstick":
				for i: int in e.list:
					_pick_at[i] = t
					_picking.append(i)
					fx.puff(_pt(_state.pos[i]), Parts.colours(_state.kind[i])[1], 3)
				fx.cue("pop")

## The last seed is gone: pick the blooms, one after another.
func _end_shot(t: float) -> void:
	_pick_result = _state.end_shot(_order)
	var cleared: PackedInt32Array = _pick_result.cleared
	var step := minf(PICK_STEP, PICK_ALL / maxf(1.0, float(cleared.size())))
	if Motion.reduce:
		step = 0.0
	for k in cleared.size():
		var i := cleared[k]
		var at := t + 0.15 + step * float(k)
		_pick_at[i] = at
		_picking.append(i)
		var pitch := pow(2.0, float(SCALE[mini(k, SCALE.size() - 1)]) / 12.0)
		var where := _pt(_state.pos[i])
		var col: Color = Parts.colours(_state.kind[i])[1]
		get_tree().create_timer(at - t).timeout.connect(func():
			fx.cue("pop", pitch)
			fx.puff(where, col, 3))
	_pick_done = t + 0.15 + step * float(cleared.size()) + PICK_TIME
	_phase = "pick"
	_trails = []
	_trail = null
	_log += ("🟠" if _shot_oranges > 0 else "🔵") + ("🪴" if _shot_pot else "")
	if _state.oranges_left <= 0:
		_log += "🌈"
	var pts: int = _pick_result.points
	if pts > 0:
		var foot := _pt(Vector2(State.W * 0.5, State.POT_Y - 8.0))
		get_tree().create_timer(_pick_done - t).timeout.connect(func():
			_float(foot, "+%s" % Locale.number(pts), Pal.PAPER))

## The blooms are picked: bank the shot and go on -- the next aim, the
## garden growing back, or the win.
func _after_pick(t: float) -> void:
	_picking = []
	_lit = null
	# the violet has moved
	_buds = []
	var free: int = _pick_result.get("free", 0)
	if free > 0:
		_tell("MG_FREE_ONE" if free == 1 else "MG_FREE", Face.Expr.JOY, [free])
		fx.cue("free")
	if _state.oranges_left <= 0:
		_phase = "won"
		if _state.left_bonus > 0:
			_float(_pt(Vector2(State.W * 0.5, 60.0)), tr("MG_LEFT") % [Locale.number(_state.left_bonus)], Pal.SUN_RAY)
		check_solved()
		return
	if _state.is_out():
		_phase = "out"
		_out_at = t
		_tell("MG_OUT", Face.Expr.WORRIED)
		fx.cue("out")
		_mood(Face.Expr.WORRIED, OUT_WAIT)
		return
	_phase = "aim"
	_shot_oranges = 0
	_shot_pot = false
	_guide = null
	if _state.seeds == 1:
		_tell("MG_LAST", Face.Expr.WORRIED)
	else:
		_cycle_tip()

## Out of seeds: the same garden grows back, a try later.
func _regrow(t: float) -> void:
	_state.regrow()
	_fresh(t)
	_log += "·"
	fx.cue("reset")
	_say(tr("MG_TRY") % [_state.tries], Face.Expr.HAPPY)

func _float(at: Vector2, text: String, col: Color) -> void:
	_floats.append({"at": at, "text": text, "col": col, "t": _now()})

func _mood(expr: int, seconds: float) -> void:
	_expr = expr
	_expr_until = _now() + seconds

# --- the drawing ---

func _draw() -> void:
	if _state.pos.is_empty() or _s() <= 0.0:
		return
	var t := _now()
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := 1.0 if Motion.reduce else Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	var grow := 1.0 if Motion.reduce else Motion.wide_pop_scale(since)
	var mid := size * 0.5
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow))
	var tint := Color(1.0, 1.0, 1.0, seen)
	var s := _s()
	var shown: Array = []
	if _still == null:
		_still = _build_still()
	_put(_still, xf, tint, shown)
	if _state.fever:
		if _back == null or t - _fever_at < 2.0:
			_back = _build_back(t)
		_put(_back, xf, tint, shown)
	if not Motion.reduce:
		_live_back = _build_live_back(t)
		_put(_live_back, xf, tint, shown)
	if _buds.size() != BUD_BANDS:
		_buds = []
		for k in BUD_BANDS:
			_buds.append(_build_buds(t, k))
	for k in BUD_BANDS:
		if _buds[k] == null:
			_buds[k] = _build_buds(t, k)
		_put(_buds[k], xf, tint, shown)
	if _lit == null:
		_lit = _build_lit(t)
	_put(_lit, xf, tint, shown)
	if _phase == "aim" and not _done:
		if _guide == null:
			_guide = _build_guide()
		_put(_guide, xf, tint, shown)
	if _phase == "shot":
		if _trail == null:
			_trail = _build_trail()
		_put(_trail, xf, tint, shown)
	# the pot, or the full bloom's five
	if not _state.fever:
		var glow := 0.0 if Motion.reduce else clampf(1.0 - (t - _pot_glow_at) / POT_GLOW_TIME, 0.0, 1.0)
		var gk := int(glow * 8.0)
		if _pot == null or _pot_for != gk:
			var b := Face.Builder.new()
			Parts.pot(b, _state.pot_w * s, float(gk) / 8.0)
			_pot = b.mesh()
			_pot_for = gk
		_put(_pot, xf * _pot_xf(t), tint, shown)
	# the seeds
	if _seed == null:
		var b := Face.Builder.new()
		Parts.kernel(b, Vector2.ZERO, State.BALL_R * s)
		_seed = b.mesh()
	for ball: Dictionary in _state.balls:
		var v: Vector2 = ball.v
		_put(_seed, xf * Transform2D(v.angle() if v.length() > 1.0 else PI * 0.5, _pt(ball.p)), tint, shown)
	_draw_sun(t, xf, tint, shown)
	if _state.fever:
		_draw_pot_worths(xf, seen)
	_draw_hud(t, xf, tint, shown)
	if not Motion.reduce:
		_live = _build_live(t)
		_put(_live, xf, tint, shown)
	_draw_floats(t, seen)
	_draw_banner(t, seen)
	_draw_toast(t, shown)
	_shown = shown

func _put(m: ArrayMesh, xf: Transform2D, tint: Color, shown: Array) -> void:
	if m == null:
		return
	draw_mesh(m, null, xf, tint)
	shown.append(m)

## The card, the dusk garden in the field, the bank along the foot, and the
## arbor round it. None of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var o := _origin()
	var fw := State.W * s
	var fh := State.H * s
	_vgrad(b, Rect2(Vector2.ZERO, size), Pal.MG_CARD, Pal.MG_CARD_DEEP)
	# the sky, then the ranges, then the pond
	var horizon := 58.0
	_vgrad(b, Rect2(o, Vector2(fw, horizon * s)), Pal.MG_SKY_TOP, Pal.MG_SKY_LOW)
	# the moon, with a soft halo
	var moon := _pt(Vector2(81.0, 15.0))
	b.disc(moon, 9.0 * s, Color(Pal.MG_SHINE, 0.18))
	b.disc(moon, 6.2 * s, Color(Pal.MG_SHINE, 0.25))
	b.disc(moon, 4.2 * s, Pal.MOON)
	b.disc(moon + Vector2(1.6, -1.0) * s, 3.4 * s, Color(Pal.MG_SKY_TOP, 0.35))
	# a few stars
	for k in 14:
		var at := _pt(Vector2(4.0 + _hash(k, 3) * 92.0, 3.0 + _hash(k, 7) * 30.0))
		if at.distance_to(moon) < 9.0 * s:
			continue
		b.disc(at, s * (0.18 + 0.2 * _hash(k, 9)), Color(Pal.MG_SHINE, 0.8))
	_range(b, horizon, 17.0, 0.07, 1.3, Pal.MG_HILL_FAR, true)
	_range(b, horizon, 10.0, 0.11, 4.1, Pal.MG_HILL_NEAR, false)
	# a little castle on the far shore, as in the reference, in the near range's lilac
	var ca := Vector2(18.0, horizon - 6.0)
	for r: Rect2 in [Rect2(ca, Vector2(8.0, 6.0)), Rect2(ca + Vector2(-1.2, -4.0), Vector2(2.6, 10.0)),
			Rect2(ca + Vector2(6.6, -5.0), Vector2(2.6, 11.0)), Rect2(ca + Vector2(3.0, -2.5), Vector2(2.2, 8.5))]:
		b.fan(PackedVector2Array([_pt(r.position), _pt(r.position + Vector2(r.size.x, 0.0)),
			_pt(r.end), _pt(r.position + Vector2(0.0, r.size.y))]), Pal.MG_HILL_NEAR.darkened(0.08))
	for tip: Vector2 in [ca + Vector2(0.1, -4.0), ca + Vector2(7.9, -5.0), ca + Vector2(4.1, -2.5)]:
		b.fan(PackedVector2Array([_pt(tip + Vector2(-1.7, 0.0)), _pt(tip + Vector2(0.0, -2.8)), _pt(tip + Vector2(1.7, 0.0))]),
			Pal.MG_HILL_NEAR.darkened(0.16))
	b.disc(_pt(ca + Vector2(4.1, 1.5)), s * 0.5, Color(Pal.SUN_RAY, 0.9))
	# the pond, its far shore's reflection and its glints
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, fh - horizon * s)), Pal.MG_POND, Pal.MG_POND_DEEP)
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, 7.0 * s)), Color(Pal.MG_HILL_NEAR, 0.45), Color(Pal.MG_HILL_NEAR, 0.0))
	# the near range and the castle upside down in the water, faint
	var mirror := PackedVector2Array()
	for k in 41:
		var x := State.W * float(k) / 40.0
		var y := horizon - 10.0 * absf(sin(x * 0.11 + 4.1)) - 3.5 * sin(x * 0.11 * 2.3 + 8.2)
		mirror.append(_pt(Vector2(x, horizon + (horizon - y) * 0.55)))
	mirror.append(_pt(Vector2(State.W, horizon)))
	mirror.append(_pt(Vector2(0.0, horizon)))
	b.polygon(mirror, Color(Pal.MG_HILL_NEAR, 0.22))
	for r: Rect2 in [Rect2(ca + Vector2(0.0, 6.0), Vector2(8.0, 3.3)), Rect2(ca + Vector2(-1.2, 6.0), Vector2(2.6, 5.5)),
			Rect2(ca + Vector2(6.6, 6.0), Vector2(2.6, 6.0))]:
		b.fan(PackedVector2Array([_pt(r.position), _pt(r.position + Vector2(r.size.x, 0.0)),
			_pt(r.end), _pt(r.position + Vector2(0.0, r.size.y))]), Color(Pal.MG_HILL_NEAR.darkened(0.1), 0.25))
	# the moon's road across the water, breaking up as it comes near
	for k in 10:
		var y := horizon + 2.0 + float(k) * 3.6
		var half := (3.4 - float(k) * 0.22) * (0.55 + 0.45 * _hash(k, 81))
		var dx := (_hash(k, 83) - 0.5) * 1.6
		b.stroke(PackedVector2Array([_pt(Vector2(81.0 + dx - half, y)), _pt(Vector2(81.0 + dx + half, y))]), s * 0.5,
			Color(Pal.MG_SHINE, 0.5 - 0.04 * float(k)))
	# mist lying along the far shore
	_vgrad(b, Rect2(o + Vector2(0.0, (horizon - 4.0) * s), Vector2(fw, 4.0 * s)), Color(Pal.MG_SNOW, 0.0), Color(Pal.MG_SNOW, 0.35))
	_vgrad(b, Rect2(o + Vector2(0.0, horizon * s), Vector2(fw, 3.5 * s)), Color(Pal.MG_SNOW, 0.3), Color(Pal.MG_SNOW, 0.0))
	for k in 22:
		var y := horizon + 3.0 + _hash(k, 13) * 70.0
		var x := 6.0 + _hash(k, 17) * 88.0
		var w := 2.0 + _hash(k, 19) * 5.0
		b.stroke(PackedVector2Array([_pt(Vector2(x, y)), _pt(Vector2(x + w, y))]), s * 0.35, Color(Pal.MG_SHINE, 0.35))
	# lily pads, low and flat, and reeds in the corners
	for p: Vector3 in [Vector3(12.0, 118.0, 4.0), Vector3(88.0, 112.0, 3.4), Vector3(22.0, 128.0, 2.8), Vector3(74.0, 127.0, 3.0)]:
		var c := _pt(Vector2(p.x, p.y))
		b.ellipse(c + Vector2(0.0, s * 0.3), p.z * s, p.z * 0.42 * s, Color(Pal.MG_POND_DEEP.darkened(0.1), 0.6))
		b.ellipse(c, p.z * s, p.z * 0.4 * s, Color(Pal.MG_BANK_DEEP, 0.55))
		# the pad's notch
		b.fan(PackedVector2Array([c, c + Vector2(p.z * 0.9, -p.z * 0.12) * s, c + Vector2(p.z * 0.9, p.z * 0.2) * s]),
			Color(Pal.MG_POND_DEEP, 0.9))
	# a water lily open on the first pad
	var lily := _pt(Vector2(11.0, 117.2))
	for k in 7:
		var a := PI + PI * float(k) / 6.0
		b.ellipse(lily + Vector2(cos(a) * 1.3, sin(a) * 0.55) * s, s * 0.75, s * 0.42, Color("f3c9d6"))
	for k in 4:
		var a := PI + PI * (float(k) + 0.5) / 4.0
		b.ellipse(lily + Vector2(cos(a) * 0.7, sin(a) * 0.5 - 0.3) * s, s * 0.6, s * 0.38, Color("fbe3ea"))
	b.disc(lily + Vector2(0.0, -0.3) * s, s * 0.4, Pal.SUN_RAY)
	# the bank the pot slides on
	var bank := State.POT_Y + 3.2
	var pts := PackedVector2Array([o + Vector2(0.0, bank * s)])
	for k in 21:
		var x := State.W * float(k) / 20.0
		pts.append(_pt(Vector2(x, bank - 0.6 - 0.5 * sin(x * 0.4))))
	pts.append(o + Vector2(fw, fh + FOOT))
	pts.append(o + Vector2(0.0, fh + FOOT))
	b.polygon(pts, Pal.MG_BANK)
	b.fan(PackedVector2Array([_pt(Vector2(0.0, bank + 1.2)), _pt(Vector2(State.W, bank + 1.2)),
		o + Vector2(fw, fh + FOOT), o + Vector2(0.0, fh + FOOT)]), Pal.MG_BANK_DEEP)
	# the bank's lit lip, and clover and daisies along it
	b.stroke(pts.slice(1, 22), s * 0.4, Color(Pal.MG_VINE_HI, 0.7))
	for k in 13:
		var x := 9.0 + float(k) * 6.8 + (_hash(k, 91) - 0.5) * 2.0
		var foot := Vector2(x, bank + 0.6 + _hash(k, 93) * 0.8)
		for j in 3:
			var d := Vector2.from_angle(-PI * 0.5 + (float(j) - 1.0) * 0.6)
			Parts.leaf(b, _pt(foot), d, s * 1.1, s * 0.4, Pal.MG_GREEN_DEEP if j != 1 else Pal.MG_VINE)
		if k % 2 == 0:
			var head := _pt(foot + Vector2(0.4, -1.3))
			for j in 6:
				b.disc(head + Vector2.from_angle(TAU * float(j) / 6.0) * s * 0.42, s * 0.3, Color("fbf7ee"))
			b.disc(head, s * 0.26, Pal.SUN_RAY)
	for side: float in [0.0, 1.0]:
		for k in 5:
			var x := 1.5 + float(k) * 1.3 if side == 0.0 else State.W - 1.5 - float(k) * 1.3
			var top := bank - 9.0 - 4.0 * _hash(k, int(side) + 5)
			var foot := _pt(Vector2(x, bank + 0.5))
			var tip := _pt(Vector2(x + (0.8 if side == 0.0 else -0.8), top))
			b.stroke(PackedVector2Array([foot, tip]), s * 0.45, Pal.MG_BANK_DEEP)
			if k % 2 == 0:
				b.ellipse(tip + Vector2(0.0, s * 1.6), s * 0.5, s * 1.4, Pal.MG_ARBOR_DEEP)
	# the arbor: a post down each side and an arch over the sun
	var post := minf(3.0 * s, maxf(0.0, o.x - 4.0))
	if post > 4.0:
		for x: float in [o.x - post, o.x + fw]:
			b.fan(PackedVector2Array([Vector2(x, o.y - s * 2.0), Vector2(x + post, o.y - s * 2.0),
				Vector2(x + post, o.y + fh + FOOT), Vector2(x, o.y + fh + FOOT)]), Pal.MG_ARBOR)
			b.fan(PackedVector2Array([Vector2(x + post * 0.68, o.y - s * 2.0), Vector2(x + post, o.y - s * 2.0),
				Vector2(x + post, o.y + fh + FOOT), Vector2(x + post * 0.68, o.y + fh + FOOT)]), Pal.MG_ARBOR_DEEP)
			b.fan(PackedVector2Array([Vector2(x + post * 0.08, o.y - s * 2.0), Vector2(x + post * 0.26, o.y - s * 2.0),
				Vector2(x + post * 0.26, o.y + fh + FOOT), Vector2(x + post * 0.08, o.y + fh + FOOT)]), Color(Pal.MG_ARBOR_HI, 0.8))
			# a vine winding up it
			var vine := PackedVector2Array()
			for k in 60:
				var y := o.y + fh + FOOT - float(k) * (fh + FOOT) / 59.0
				vine.append(Vector2(x + post * 0.5 + sin(float(k) * 0.55) * post * 0.55, y))
			b.stroke(vine, s * 0.35, Pal.MG_VINE)
			for k in range(2, 58, 5):
				var at := vine[k]
				var side := 1.0 if k % 2 == 0 else -1.0
				b.ellipse(at + Vector2(side * s * 0.9, 0.0), s * 0.9, s * 0.5, Pal.MG_VINE if k % 3 else Pal.MG_VINE_HI)
				if k % 15 == 2:
					b.disc(at + Vector2(-side * s * 0.6, -s * 0.4), s * 0.55, Pal.MG_ORANGE_HI)
					b.disc(at + Vector2(-side * s * 0.6, -s * 0.4), s * 0.22, Pal.MG_ORANGE_DEEP)
	# the arch behind the sun
	var arch := PackedVector2Array()
	for k in 41:
		var u := float(k) / 40.0
		arch.append(o + Vector2(u * fw, s * (2.0 - 2.4 * sin(PI * u)) - s * 1.2))
	b.stroke(arch, s * 2.2, Pal.MG_ARBOR_DEEP)
	b.stroke(arch, s * 1.6, Pal.MG_ARBOR)
	var lit := PackedVector2Array()
	for p in arch:
		lit.append(p + Vector2(0.0, -s * 0.45))
	b.stroke(lit, s * 0.35, Color(Pal.MG_ARBOR_HI, 0.8))
	# the lanterns, hanging from the arch with a warm glow
	for k in 2:
		var cap := _pt(_lantern_at(k))
		var hook := cap - Vector2(0.0, s * 1.8)
		b.stroke(PackedVector2Array([hook, cap]), s * 0.16, Pal.MG_ARBOR_DEEP)
		b.disc(cap + Vector2(0.0, s * 1.5), s * 2.8, Color(Pal.SUN_RAY, 0.16))
		b.fan(Face.Builder.round_rect(cap + Vector2(-1.1, 0.0) * s, Vector2(2.2, 3.0) * s, s * 0.8), Color("f6d28b"))
		b.fan(Face.Builder.round_rect(cap + Vector2(-0.5, 0.45) * s, Vector2(1.0, 2.1) * s, s * 0.45), Color("fff1c4"))
		for side: float in [-1.0, 1.0]:
			b.stroke(PackedVector2Array([cap + Vector2(side * 0.55, 0.2) * s, cap + Vector2(side * 0.55, 2.8) * s]), s * 0.12,
				Color(Pal.MG_ARBOR_DEEP, 0.5))
		b.fan(Face.Builder.round_rect(cap + Vector2(-1.3, -0.35) * s, Vector2(2.6, 0.7) * s, s * 0.3), Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(cap + Vector2(-0.9, 2.8) * s, Vector2(1.8, 0.55) * s, s * 0.25), Pal.MG_ARBOR_DEEP)
	# a garland swagged along the arch: leaves, and a marigold in each swag
	var swag := PackedVector2Array()
	for k in 81:
		var u := float(k) / 80.0
		var p := arch[mini(40, int(round(u * 40.0)))]
		swag.append(Vector2(o.x + u * fw, p.y + s * (0.7 + 1.5 * absf(sin(PI * u * 4.0)))))
	b.stroke(swag, s * 0.3, Pal.MG_VINE)
	for k in range(2, 79, 3):
		var side := 1.0 if k % 2 == 0 else -1.0
		var d := (swag[k + 1] - swag[k - 1]).normalized()
		Parts.leaf(b, swag[k], (d.rotated(side * 1.1)).normalized(), s * 1.0, s * 0.34, Pal.MG_VINE if k % 4 else Pal.MG_VINE_HI)
	for k in 4:
		var at := swag[10 + 20 * k] + Vector2(0.0, s * 0.3)
		Parts.bloom(b, at, s * 1.0, State.ORANGE, 1.0)
	# a soft light round the sun
	b.disc(_pt(State.SUN_C), s * 7.0, Color(Pal.SUN_RAY, 0.12))
	b.disc(_pt(State.SUN_C), s * 5.2, Color(Pal.SUN_RAY, 0.14))
	return b.mesh()

## A range of hills along `base`, `amp` high, rolling at `freq`; the far
## one carries snow on its peaks.
func _range(b: Face.Builder, base: float, amp: float, freq: float, phase: float, col: Color, snow: bool) -> void:
	var pts := PackedVector2Array()
	var ridge := PackedVector2Array()
	for k in 41:
		var x := State.W * float(k) / 40.0
		var y := base - amp * absf(sin(x * freq + phase)) - amp * 0.35 * sin(x * freq * 2.3 + phase * 2.0)
		ridge.append(Vector2(x, y))
		pts.append(_pt(Vector2(x, y)))
	pts.append(_pt(Vector2(State.W, base + 0.2)))
	pts.append(_pt(Vector2(0.0, base + 0.2)))
	b.polygon(pts, col)
	if snow:
		for k in range(1, 40):
			var p := ridge[k]
			if p.y < ridge[k - 1].y and p.y < ridge[k + 1].y and p.y < base - amp * 0.8:
				var cap := PackedVector2Array([_pt(p + Vector2(-2.2, 2.0)), _pt(p + Vector2(0.0, -0.1)), _pt(p + Vector2(2.2, 2.0)),
					_pt(p + Vector2(0.8, 1.4)), _pt(p + Vector2(0.0, 2.2)), _pt(p + Vector2(-0.9, 1.3))])
				b.polygon(cap, Pal.MG_SNOW)

## A rectangle shaded from `top` to `bottom`.
static func _vgrad(b: Face.Builder, r: Rect2, top: Color, bottom: Color) -> void:
	var a := b.vertex(r.position, top)
	var c := b.vertex(r.position + Vector2(r.size.x, 0.0), top)
	var d := b.vertex(r.end, bottom)
	var e := b.vertex(r.position + Vector2(0.0, r.size.y), bottom)
	b.tri(a, c, d)
	b.tri(a, d, e)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) ^ (a * b * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / float(0x7fffffff)

## The full bloom behind the field: a rainbow across the sky and the sun's
## rays out of the last marigold, and the five pots along the foot.
func _build_back(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var e := 1.0 if Motion.reduce else clampf((t - _fever_at) / 1.4, 0.0, 1.0)
	var bands := [Color("f4a3a0"), Color("f7c58f"), Color("f6e39a"), Color("b9dfa0"), Color("a9c9ee"), Color("c6b0ea")]
	var c := _pt(Vector2(State.W * 0.5, 70.0))
	for k in bands.size():
		var r := (46.0 - float(k) * 2.6) * s
		b.stroke(Face.Builder.arc_points(c, r, PI, PI + PI * e), 2.6 * s, Color(bands[k], 0.55))
	if not Motion.reduce and t - _fever_at < 1.8:
		var a := 1.0 - clampf((t - _fever_at) / 1.8, 0.0, 1.0)
		for k in 12:
			var ang := TAU * float(k) / 12.0 + (t - _fever_at) * 0.6
			var d := Vector2.from_angle(ang)
			var side := Vector2(-d.y, d.x)
			var far := 90.0 * s * (0.3 + 0.7 * e)
			b.fan(PackedVector2Array([_fever_from, _fever_from + d * far + side * far * 0.08, _fever_from + d * far - side * far * 0.08]),
				Color(Pal.SUN_RAY, 0.35 * a))
	# the five pots, each with its worth
	var n := State.FEVER_POTS.size()
	var w := State.W / float(n)
	for k in n:
		var x := (float(k) + 0.5) * w
		var lit := 1.0 if k == _fever_pot else 0.0
		var rim := _pt(Vector2(x, State.POT_Y))
		var pb := Face.Builder.new()
		Parts.pot(pb, (w - 2.2) * s, lit)
		# fold the small builder into this one at the pot's place
		var base := b.verts.size()
		for i in pb.verts.size():
			b.verts.append(pb.verts[i] + rim)
			b.cols.append(pb.cols[i])
		for i in pb.idx:
			b.idx.append(base + i)
	for k in range(1, n):
		b.disc(_pt(Vector2(State.W * float(k) / float(n), State.POT_Y)), (State.POT_RIM + 0.4) * s, Pal.MG_ARBOR)
	return b.mesh()

## Every closed bud, popping in top to bottom as the garden grows.
func _band_of(i: int) -> int:
	var y: float = (_state.pos[i].y - State.TOP) / (State.BOTTOM - State.TOP + 1.0)
	return clampi(int(y * float(BUD_BANDS)), 0, BUD_BANDS - 1)

func _dirty_bud(i: int) -> void:
	if _buds.size() == BUD_BANDS:
		_buds[_band_of(i)] = null

func _build_buds(t: float, band: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r := State.PEG_R * s
	for i in _state.pos.size():
		if _state.st[i] != State.UP or _band_of(i) != band:
			continue
		var sc := _grow(i, t)
		if sc <= 0.01:
			continue
		Parts.bud(b, _pt(_state.pos[i]), r, _state.kind[i], sc)
	return b.mesh() if not b.verts.is_empty() else null

func _grow(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var y: float = (_state.pos[i].y - State.TOP) / (State.BOTTOM - State.TOP)
	var e := t - _grown_at - Motion.ENTER_DELAY - 0.1 - y * 0.8 - _hash(i, 31) * 0.1
	return 0.0 if e <= 0.0 else Motion.pop_in_scale(e).x

## The blooms, opening as they are touched and fading as they are picked.
func _build_lit(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r := State.PEG_R * s
	for i in _state.pos.size():
		var hit := _hit_at[i]
		if hit < 0.0:
			continue
		var pick := _pick_at[i]
		var alpha := 1.0
		var sc := 1.0
		var lift := 0.0
		var spin := 0.0
		if pick >= 0.0:
			var e := t - pick
			if e >= PICK_TIME or (Motion.reduce and e >= 0.0):
				continue
			if e > 0.0:
				var u := e / PICK_TIME
				alpha = 1.0 - u * u
				sc = 1.0 + 0.35 * u
				lift = PICK_RISE * s * u
				spin = 1.4 * u
		elif _state.st[i] != State.LIT:
			continue
		var open := 1.0 if Motion.reduce else Motion.back_out(clampf((t - hit) / BLOOM_TIME, 0.0, 1.0))
		Parts.bloom(b, _pt(_state.pos[i]) - Vector2(0.0, lift), r, _state.kind[i], open, sc, alpha, spin)
	return b.mesh() if not b.verts.is_empty() else null

## The aim: dots down the seed's way to the first bud it will touch (the
## hint's long guide: through three), fading as they go.
func _build_guide() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var r: Dictionary = _state.trace(_aim, 3 if _super else 1, 3.0 if _super else 1.2, 2)
	var pts: PackedVector2Array = r.path
	var limit := 1e9 if _super else GUIDE_LEN
	var walked := 0.0
	var next := 0.0
	for k in range(1, pts.size()):
		var a := pts[k - 1]
		var z := pts[k]
		var seg := a.distance_to(z)
		while next <= walked + seg and next <= limit:
			var at := a.lerp(z, (next - walked) / maxf(seg, 1e-5))
			var u := next / (limit if not _super else maxf(1.0, _path_len(pts)))
			var col := Pal.SUN_RAY if _super else Pal.MG_SHINE
			b.disc(_pt(at), s * (0.55 - 0.25 * u), Color(col, 0.95 - 0.55 * u))
			next += GUIDE_GAP
		walked += seg
		if walked > limit:
			break
	return b.mesh() if not b.verts.is_empty() else null

static func _path_len(pts: PackedVector2Array) -> float:
	var n := 0.0
	for k in range(1, pts.size()):
		n += pts[k].distance_to(pts[k - 1])
	return n

func _build_trail() -> ArrayMesh:
	if Motion.reduce:
		return null
	var b := Face.Builder.new()
	var s := _s()
	for tr_pts: PackedVector2Array in _trails:
		var n := tr_pts.size()
		for k in n:
			var u := float(k + 1) / float(n + 1)
			b.disc(_pt(tr_pts[k]), s * State.BALL_R * (0.2 + 0.6 * u), Color(Pal.SUN_RAY, 0.32 * u))
			if k % 3 == 1:
				var off := Vector2(_hash(k, n) - 0.5, _hash(n, k) - 0.5) * s * 1.6
				b.disc(_pt(tr_pts[k]) + off, s * 0.2, Color(1.0, 1.0, 1.0, 0.7 * u))
	return b.mesh() if not b.verts.is_empty() else null

## The sun: rays turning slowly, the body and face looking down the aim,
## and the spout turned to it with a seed waiting when one is ready.
func _draw_sun(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var s := _s()
	var R := SUN_R * s
	var c := _pt(State.SUN_C)
	if _rays == null:
		var b := Face.Builder.new()
		Parts.sun_rays(b, R)
		_rays = b.mesh()
	var spin := 0.0 if Motion.reduce else t * TAU / 40.0
	if t < _slow_until:
		spin *= 3.0
	if not _think.is_empty() and not Motion.reduce:
		spin += (t - float(_think.at)) * TAU * 1.5
	var loaded: bool = _phase == "aim" and _state.seeds > 0 and not _done
	var lk := 1 if loaded else 0
	if _spout == null or _spout_for != lk:
		var b := Face.Builder.new()
		Parts.spout(b, R, loaded, State.MUZZLE / SUN_R)
		_spout = b.mesh()
		_spout_for = lk
	var expr := _expr if t < _expr_until else (Face.Expr.WORRIED if _state.seeds <= 1 and _phase == "aim" and not _done else Face.Expr.HAPPY)
	if _solved_at >= 0.0:
		expr = Face.Expr.JOY
	var eye := 1.0
	if not Motion.reduce and t >= _blink_at and t <= _blink_at + Face.BLINK_TIME:
		eye = absf(cos(PI * (t - _blink_at) / Face.BLINK_TIME))
	var look := State.aim_dir(_aim) * 0.07 if _phase == "aim" else Vector2(0.0, 0.06)
	var key := "%d|%d|%d|%d" % [expr, int(eye * 6.0), int(look.x * 100.0), int(look.y * 100.0)]
	if _body == null or _body_for != key:
		var b := Face.Builder.new()
		Parts.sun_body(b, R, maxf(0.05, float(int(eye * 6.0)) / 6.0), expr, look)
		_body = b.mesh()
		_body_for = key
	# a shot kicks the sun back up its aim and squashes it; at rest it bobs
	var q := 0.0
	var bob := Vector2.ZERO
	if not Motion.reduce:
		var e := t - _shot_at
		if e < RECOIL_TIME:
			q = sin(PI * e / RECOIL_TIME) * (1.0 - 0.5 * e / RECOIL_TIME)
		bob = Vector2(0.0, sin(t * 1.7) * 0.22 * s)
	var back := -State.aim_dir(_aim) * q * s
	_put(_rays, xf * Transform2D(spin, Vector2.ONE * (1.0 + 0.1 * q), 0.0, c + bob), tint, shown)
	_put(_spout, xf * Transform2D(State.aim_dir(_aim).angle(), c + bob + back * 1.2), tint, shown)
	_put(_body, xf * Transform2D(0.0, Vector2(1.0 + 0.12 * q, 1.0 - 0.1 * q), 0.0, c + bob + back * 0.5), tint, shown)

## The band over the field: the seeds left in a wooden trough, the score
## rolling up, the multiplier on a tag, and a groove of marigold pips that
## fill as the marigolds fly up to them, gapped where the multiplier steps.
func _draw_hud(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
	var mult: int = _state.mult()
	var total: int = _state.orange_total
	var got := _pips_filled(t)
	var key := "%d|%d|%d|%d|%d" % [_state.seeds, got, total, _seeds_start, int(size.x)]
	if _hud == null or _hud_for != key:
		var b := Face.Builder.new()
		# the trough, the seeds lying in it and the dents of the ones shot
		var slots := clampi(maxi(_seeds_start, _state.seeds), 1, 10)
		var tw := 30.0 * float(slots) + 14.0
		b.fan(Face.Builder.round_rect(Vector2(INSET + 5.0, 20.0), Vector2(tw, 40.0), 20.0), Pal.MG_ARBOR_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(Vector2(INSET + 5.0, 17.0), Vector2(tw, 40.0), 20.0), Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(INSET + 10.0, 22.0), Vector2(tw - 10.0, 30.0), 15.0), Pal.MG_ARBOR_DEEP.darkened(0.3))
		b.stroke(PackedVector2Array([Vector2(INSET + 22.0, 19.5), Vector2(INSET + tw - 12.0, 19.5)]), 2.0, Color(Pal.MG_ARBOR_HI, 0.6))
		var shown_seeds := mini(_state.seeds, 10)
		for k in slots:
			var at := Vector2(INSET + 22.0 + float(k) * 30.0, 38.0)
			if k < shown_seeds:
				Parts.kernel(b, at, 9.5, -PI * 0.5 + (0.2 if k % 2 == 0 else -0.2))
			else:
				b.ellipse(at + Vector2(0.0, 3.0), 7.0, 4.0, Color(Pal.TEXT, 0.25))
		# the pips' groove
		var g := _pip_geom()
		var pip: float = g.pip
		var row_x: float = g.x
		var row_w: float = g.w
		var row_y: float = g.y
		b.fan(Face.Builder.round_rect(Vector2(row_x - 12.0, row_y - pip * 0.5 - 4.0), Vector2(row_w + 24.0, pip + 12.0), pip * 0.5 + 6.0),
			Pal.MG_ARBOR_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(Vector2(row_x - 12.0, row_y - pip * 0.5 - 6.0), Vector2(row_w + 24.0, pip + 12.0), pip * 0.5 + 6.0),
			Pal.MG_ARBOR_DEEP)
		b.fan(Face.Builder.round_rect(Vector2(row_x - 8.0, row_y - pip * 0.5 - 2.0), Vector2(row_w + 16.0, pip + 4.0), pip * 0.5 + 2.0),
			Pal.MG_ARBOR_DEEP.darkened(0.3))
		for k in total:
			var at := _pip_at(k)
			if k < got:
				Parts.bloom(b, at, pip * 0.3, State.ORANGE, 1.0)
			else:
				b.disc(at, pip * 0.27, Color(Pal.MG_ARBOR, 0.9))
				b.disc(at + Vector2(0.0, pip * 0.04), pip * 0.2, Pal.MG_ARBOR_DEEP.darkened(0.15))
		_hud = b.mesh()
		_hud_for = key
	_put(_hud, xf, tint, shown)
	# the tag, popping when the multiplier steps
	if _pill == null or _pill_for != mult:
		var b := Face.Builder.new()
		var sz := Vector2(108.0, 54.0)
		var face := Pal.MG_ORANGE if mult > 1 else Pal.MG_ARBOR
		b.fan(Face.Builder.round_rect(-sz * 0.5 + Vector2(0.0, 4.0), sz, 27.0), face.darkened(0.35))
		b.fan(Face.Builder.round_rect(-sz * 0.5, sz, 27.0), face)
		b.stroke(Face.Builder.arc_points(Vector2(-sz.x * 0.5 + 27.0, 0.0), 21.0, PI * 1.05, PI * 1.5), 3.0, Color(1.0, 1.0, 1.0, 0.3), false, false)
		b.disc(Vector2(-sz.x * 0.5 + 15.0, 0.0), 5.0, face.darkened(0.45))
		_pill = b.mesh()
		_pill_for = mult
	var pop := 1.0
	if not Motion.reduce and t - _mult_at < TAG_TIME:
		var u := (t - _mult_at) / TAG_TIME
		pop = 1.0 + 0.4 * sin(PI * u) * (1.0 - 0.4 * u)
	var tag := xf * Transform2D(0.0, Vector2.ONE * pop, 0.0, _tag_centre())
	_put(_pill, tag, tint, shown)
	var font: Font = CozyTheme.body(800)
	var a := tint.a
	if _state.seeds > 10:
		draw_string(font, xf * Vector2(INSET + 336.0, 50.0), "+%d" % (_state.seeds - 10), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, a))
	elif _state.seeds == 0:
		draw_string(font, xf * Vector2(INSET + 20.0, 50.0), tr("MG_NO_SEEDS"), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, 0.8 * a))
	var sc := Locale.number(int(_score_shown))
	var sw: float = font.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT).x
	var sat := xf * Vector2((size.x - sw) * 0.5, 58.0)
	draw_string_outline(font, sat, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT, 8, Color(Pal.MG_CARD_DEEP.darkened(0.3), 0.6 * a))
	draw_string(font, sat, sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT, Color(Pal.PAPER, a))
	var m := "×%d" % mult
	var mw: float = font.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT).x
	draw_set_transform_matrix(tag)
	draw_string(font, Vector2(-mw * 0.5 + 6.0, 15.0), m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT, Color(Pal.PAPER, a))
	draw_set_transform(Vector2.ZERO)

## Where the multiplier's tag sits, its middle.
func _tag_centre() -> Vector2:
	return Vector2(size.x - INSET - 64.0, 39.0)

## The pips' row: the pip's pitch, where it starts, how wide, its line.
func _pip_geom() -> Dictionary:
	var total: int = _state.orange_total
	var pip := clampf((size.x - 2.0 * INSET - 40.0) / float(maxi(total, 1) + 4), 12.0, 30.0)
	var gaps := State.STEPS.size() - 1
	var w := pip * float(total) + pip * 0.5 * float(gaps)
	return {"pip": pip, "x": (size.x - w) * 0.5, "w": w, "y": BAND - 30.0}

## The middle of the `k`th pip, the gaps where the multiplier steps counted.
func _pip_at(k: int) -> Vector2:
	var g := _pip_geom()
	var total: int = _state.orange_total
	var pip: float = g.pip
	var x: float = g.x + pip * float(k)
	for j in range(1, State.STEPS.size()):
		if int(ceil(float(State.STEPS[j]) * float(total) - 1e-6)) <= k:
			x += pip * 0.5
	return Vector2(x + pip * 0.5, g.y)

## The pot's place, with its wobble after it turns at an end and its squash
## when it catches a seed, both about its foot.
func _pot_xf(t: float) -> Transform2D:
	var at := _pt(Vector2(_state.pot_x, State.POT_Y))
	if Motion.reduce:
		return Transform2D(0.0, at)
	var foot: float = _state.pot_w * _s() * 0.62
	var e := t - _pot_turn_at
	var ang := 0.0
	if e < WOBBLE_TIME:
		ang = -0.12 * _state.pot_dir * sin(e * 15.0) * exp(-e * 4.5)
	var sc := Vector2.ONE
	var c := t - _pot_glow_at
	if c < CATCH_TIME:
		var q := sin(PI * c / CATCH_TIME) * (1.0 - 0.4 * c / CATCH_TIME)
		sc = Vector2(1.0 + 0.16 * q, 1.0 - 0.18 * q)
	return Transform2D(0.0, at + Vector2(0.0, foot)) * Transform2D(ang, sc, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0.0, -foot))

## Under the buds, every frame: fireflies, the stars twinkling, glints
## drifting across the pond, the lanterns' flicker, and the ripples round
## every bud that bloomed.
func _build_live_back(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	var horizon := 58.0
	for k in 5:
		var j := k * 3 + 1
		var at := Vector2(4.0 + _hash(j, 3) * 92.0, 3.0 + _hash(j, 7) * 30.0)
		if at.distance_to(Vector2(81.0, 15.0)) < 9.0:
			continue
		var a := pow(maxf(0.0, sin(t * (1.1 + 0.3 * _hash(j, 11)) + float(j) * 1.9)), 6.0)
		if a > 0.05:
			_twinkle(b, _pt(at), s * 1.3 * a, Color(Pal.MG_SHINE, 0.9 * a), 0.0)
	for k in 7:
		var y := horizon + 5.0 + _hash(k, 61) * 62.0
		var span := 110.0
		var x := fmod(_hash(k, 63) * span + t * (0.8 + 0.8 * _hash(k, 65)), span) - 5.0
		var w := 2.0 + 2.5 * _hash(k, 67)
		var a := 0.4 * sin(PI * clampf((x + 5.0) / span, 0.0, 1.0))
		var x0 := clampf(x, 1.0, State.W - 1.0)
		var x1 := clampf(x + w, 1.0, State.W - 1.0)
		if x1 - x0 > 0.3:
			b.stroke(PackedVector2Array([_pt(Vector2(x0, y)), _pt(Vector2(x1, y))]), s * 0.32, Color(Pal.MG_SHINE, a))
	for k in FIREFLIES:
		var low := k % 2 == 0
		var base := Vector2(6.0 + _hash(k, 51) * 88.0, (108.0 + _hash(k, 53) * 18.0) if low else (10.0 + _hash(k, 53) * 12.0))
		var p := base + Vector2(sin(t * 0.37 + float(k) * 1.7) * 4.0, sin(t * 0.53 + float(k) * 2.3) * 2.2)
		var glow := pow(maxf(0.0, sin(t * (0.8 + 0.5 * _hash(k, 57)) + float(k) * 2.1)), 3.0)
		if glow < 0.03:
			continue
		b.disc(_pt(p), s * 1.4, Color(Pal.SUN_RAY, 0.2 * glow))
		b.disc(_pt(p), s * 0.36, Color(Color("fff6c8"), 0.95 * glow))
	for k in 2:
		var at := _lantern_at(k) + Vector2(0.0, 1.5)
		var f := 0.5 + 0.3 * sin(t * 6.3 + float(k) * 2.0) + 0.2 * sin(t * 10.7 + float(k))
		b.disc(_pt(at), s * (2.3 + 0.35 * f), Color(Pal.SUN_RAY, 0.12 + 0.1 * f))
	for r: Dictionary in _ripples:
		var u := clampf((t - float(r.t)) / RIPPLE_TIME, 0.0, 1.0)
		var rad := State.PEG_R * s * (1.1 + 2.4 * Motion.back_out(u) * 0.8 + 0.4 * u)
		b.stroke(Face.Builder.arc_points(_pt(r.at), rad, 0.0, TAU), s * 0.3 * (1.0 - 0.5 * u), Color(Color(r.col), 0.6 * (1.0 - u)),
			true, false)
	return b.mesh() if not b.verts.is_empty() else null

## Over everything, every frame: a glint on a marigold now and then, the
## marigolds flying up to their pips, and the full bloom's falling petals.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _s()
	if _glint_i >= 0 and _glint_i < _state.pos.size() and _state.st[_glint_i] == State.UP:
		var e := t - _glint_at
		if e < GLINT_TIME:
			var a := sin(PI * e / GLINT_TIME)
			var at := _pt(_state.pos[_glint_i] + Vector2(-0.7, -0.8) * State.PEG_R)
			_twinkle(b, at, s * 1.5 * a, Color(1.0, 1.0, 0.95, 0.95 * a), e * 2.0)
	var in_air := 0
	var filled := _pips_filled(t)
	var g := _pip_geom()
	for f: Dictionary in _flies:
		var e := t - float(f.t)
		if e >= FLY_TIME:
			continue
		var k := filled + in_air
		in_air += 1
		if e < 0.0:
			continue
		var u := e / FLY_TIME
		var ease := u * u * (3.0 - 2.0 * u)
		var from: Vector2 = f.from
		var to := _pip_at(k)
		var side := -1.0 if from.x > size.x * 0.5 else 1.0
		var ctrl := from.lerp(to, 0.35) + Vector2(side * 160.0, -40.0)
		var p := from.lerp(ctrl, ease).lerp(ctrl.lerp(to, ease), ease)
		var r := lerpf(State.PEG_R * s * 1.1, float(g.pip) * 0.3, ease)
		for j in 3:
			var ub := maxf(0.0, ease - 0.06 * float(j + 1))
			var pb := from.lerp(ctrl, ub).lerp(ctrl.lerp(to, ub), ub)
			b.disc(pb, r * (0.4 - 0.1 * float(j)), Color(Pal.SUN_RAY, 0.5 - 0.12 * float(j)))
		Parts.bloom(b, p, r, State.ORANGE, 1.0, 1.0 + 0.25 * sin(PI * u), 1.0, u * TAU)
	if _state.fever and t - _fever_at < PETAL_TIME:
		var cols := [Pal.MG_ORANGE, Pal.MG_ORANGE_HI, Pal.SUN_RAY, Color("f4a3a0"), Pal.MG_PURPLE_HI]
		for k in 26:
			var e := t - _fever_at - _hash(k, 71) * 1.8
			var fall := 2.4 + _hash(k, 75)
			if e < 0.0 or e > fall:
				continue
			var u := e / fall
			var at := Vector2(_hash(k, 73) * State.W + sin(e * 2.2 + float(k)) * 4.0, -3.0 + u * (State.H * 0.9))
			var col: Color = cols[k % cols.size()]
			col.a = minf(1.0, (1.0 - u) * 4.0)
			Parts.leaf(b, _pt(at), Vector2.from_angle(e * 3.0 + float(k)), s * 1.5, s * 0.5, col)
	return b.mesh() if not b.verts.is_empty() else null

## A four-pointed glint at `at`, `r` to a point.
static func _twinkle(b: Face.Builder, at: Vector2, r: float, col: Color, turn: float) -> void:
	if r <= 0.3:
		return
	for k in 2:
		var d := Vector2.from_angle(turn + PI * 0.5 * float(k))
		var n := Vector2(-d.y, d.x)
		b.fan(PackedVector2Array([at - d * r, at - n * r * 0.18, at + d * r, at + n * r * 0.18]), col)
	b.disc(at, r * 0.2, col)

## Where the `k`th lantern hangs from the arch, its cap.
func _lantern_at(k: int) -> Vector2:
	var u := 0.25 if k == 0 else 0.75
	return Vector2(u * State.W, 2.0 - 2.4 * sin(PI * u) - 1.2 + 1.8)

## Each of the full bloom's pots carries what it is worth on its belly.
func _draw_pot_worths(xf: Transform2D, seen: float) -> void:
	var font: Font = CozyTheme.body(800)
	var n := State.FEVER_POTS.size()
	var w := State.W / float(n)
	var px := int(clampf(w * _s() * 0.17, 16.0, 30.0))
	for k in n:
		var text := Locale.number(State.FEVER_POTS[k])
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := xf * (_pt(Vector2((float(k) + 0.5) * w, State.POT_Y + 4.2)) - Vector2(tw * 0.5, 0.0))
		var col := Pal.SUN_RAY.lightened(0.4) if k == _fever_pot else Pal.PAPER
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 8, Color(Pal.MG_POT_DEEP, seen))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col, seen))

func _draw_floats(t: float, seen: float) -> void:
	var font: Font = CozyTheme.body(800)
	var keep: Array = []
	for f: Dictionary in _floats:
		var e := t - float(f.t)
		if e >= FLOAT_TIME:
			continue
		keep.append(f)
		var u := e / FLOAT_TIME
		var alpha := minf(1.0, (1.0 - u) * 2.5) * seen
		var text: String = f.text
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT).x
		var at: Vector2 = Vector2(f.at) - Vector2(w * 0.5, 50.0 * u if not Motion.reduce else 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT, 10, Color(Pal.TEXT, 0.45 * alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT, Color(f.col, alpha))
	_floats = keep

## FULL BLOOM, big across the field, as the last marigold opens.
func _draw_banner(t: float, seen: float) -> void:
	var e := t - _fever_at
	if e < 0.0 or e >= BANNER_TIME:
		return
	var text := tr("MG_FEVER")
	var font: Font = CozyTheme.display(700)
	var size_px := BANNER_FONT
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	if w > size.x - 60.0:
		size_px = int(float(size_px) * (size.x - 60.0) / w)
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var alpha := minf(Motion.appear_level(e, 0.2), clampf((BANNER_TIME - e) / 0.4, 0.0, 1.0)) * seen
	var pop := 1.0 if Motion.reduce else Motion.pop_in_scale(e, 0.35).x
	var mid := _pt(Vector2(State.W * 0.5, 48.0))
	draw_set_transform(mid, 0.0, Vector2.ONE * pop)
	var at := Vector2(-w * 0.5, size_px * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 18, Color(Pal.MG_ORANGE_DEEP, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(Pal.SUN_RAY.lightened(0.3), alpha))
	draw_set_transform(Vector2.ZERO)

## The toast over the foot of the card -- Super Slider's.
func _draw_toast(t: float, shown: Array) -> void:
	if _toast == "":
		return
	var since := t - _toast_at
	if since < 0.0 or since >= TOAST_HOLD:
		return
	var alpha := minf(Motion.appear_level(since, Motion.DROP_FADE),
		Motion.appear_level(TOAST_HOLD - since, Motion.DROP_FADE))
	if alpha <= 0.0:
		return
	var line := _toast
	var font: Font = CozyTheme.body(600)
	var room := maxf(TOAST_PAD, size.x - 120.0)
	var text_room := room - TOAST_PAD
	var one: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT).x
	var lines := 1
	var text_w := one
	if one > text_room:
		var wrapped: Vector2 = font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, text_room, TOAST_FONT)
		var lh := font.get_height(TOAST_FONT)
		lines = maxi(1, int(round(wrapped.y / lh)))
		text_w = minf(text_room, wrapped.x)
	var w := minf(room, text_w + TOAST_PAD)
	var h := TOAST_H + float(lines - 1) * font.get_height(TOAST_FONT)
	var key := "%s|%d|%d" % [line, int(w), lines]
	if _toast_mesh == null or _toast_mesh_for != key:
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(Vector2(-w, -h) * 0.5, Vector2(w, h), TOAST_RADIUS), Pal.TEXT)
		_toast_mesh = b.mesh() if not b.verts.is_empty() else null
		_toast_mesh_for = key
	if _toast_mesh == null:
		return
	# over the pond, clear of the pot's bank
	var mid := Vector2(size.x * 0.5, _pt(Vector2(0.0, State.POT_Y - 14.0)).y - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

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
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _aiming:
		_aim_at(event.position)
		accept_event()

func _press(local: Vector2) -> void:
	if _phase != "aim" or _state.seeds <= 0 or not _think.is_empty():
		return
	_aiming = true
	_aim_at(local)

## The aim turns toward the finger; above the sun it lies nearly level.
func _aim_at(local: Vector2) -> void:
	var f := (local - _origin()) / maxf(_s(), 1e-3)
	var d := f - State.SUN_C
	if d.length() < 1.0:
		return
	var a := atan2(d.y, d.x)
	if a < 0.0:
		a = State.AIM_MIN if d.x > 0.0 else PI - State.AIM_MIN
	a = clampf(a, State.AIM_MIN, PI - State.AIM_MIN)
	if absf(a - _aim) < 0.002:
		return
	if absf(a - _aim) > 0.01:
		_super = false
	_aim = a
	_guide = null
	queue_redraw()

## Let go to shoot; let go over the band at the top to put the aim down.
func _release(local: Vector2) -> void:
	if not _aiming:
		return
	_aiming = false
	if local.y < BAND * 0.8:
		return
	_shoot()

func _shoot() -> void:
	if not _state.fire(_aim):
		return
	_phase = "shot"
	_order = PackedInt32Array()
	_shot_oranges = 0
	_shot_pot = false
	_acc = 0.0
	_super = false
	_trails = []
	_shot_at = _now()
	fx.cue("shoot")
	fx.puff(_pt(State.SUN_C + State.aim_dir(_aim) * State.MUZZLE), Pal.MG_GREEN_HI, 3)
	note_move()

# --- the sprout's line and the toast ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

func _tell(key: String, mood: int, args: Array = []) -> void:
	var line := tr(key) % args if not args.is_empty() else tr(key)
	_say(line, mood)
	_toast = line
	_toast_at = _now()
	queue_redraw()

var _tip_idx := 0

func _cycle_tip() -> void:
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## The sun finds the best line it can from here -- every angle played out on
## a copy of the garden -- turns to it, and shows the long guide.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _phase != "aim" or _state.seeds <= 0 or not _think.is_empty():
		return false
	# a third of a second on this Mac, so off the frame: the sun spins while
	# it looks, and the aim turns when it has found the line
	var c = _state.clone()
	var box := {"a": _aim}
	var id := WorkerThreadPool.add_task(func(): box.a = c.best_angle())
	_think = {"id": id, "box": box, "at": _now()}
	_aiming = false
	hints_used += 1
	_mood(Face.Expr.PUZZLED, 0.6)
	moved.emit()
	queue_redraw()
	return true

func reset_board() -> void:
	if not _think.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_think.id))
		_think = {}
	_state.balls = []
	_state.regrow()
	_fresh(_now())
	_log += "·"
	moves = 0
	_running = true
	fx.cue("reset")
	_say(tr("MG_TRY") % [_state.tries], Face.Expr.HAPPY)

func is_solved() -> bool:
	return _state.is_solved()

## The day's shots, never its garden: a marigold shot, a plain one, a seed in
## the pot, a new try, and the rainbow at the end.
func share_glyphs() -> String:
	return _log

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("MG_WIN") % [Locale.number(_state.score), _state.shots]}

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func _on_solved() -> void:
	_solved_at = _now()
	_mood(Face.Expr.JOY, 100.0)
	fx.cue("solved")
	if not Motion.reduce:
		var s := _s()
		for k in 6:
			var at := _pt(Vector2(12.0 + float(k) * 15.2, 40.0 + _hash(k, 41) * 50.0))
			get_tree().create_timer(0.08 * float(k)).timeout.connect(func():
				fx.sparkle(at, Pal.SUN_RAY)
				fx.puff(at, Pal.MG_ORANGE_HI, 5))
		fx.ring(_pt(State.SUN_C), SUN_R * s * 2.0, Pal.SUN, 0.8)
	_say(tr("MG_WIN") % [Locale.number(_state.score), _state.shots], Face.Expr.JOY)

func completion_record() -> Dictionary:
	return {"score": _state.score, "shots": _state.shots, "tries": _state.tries, "log": _log}

## A reopened daily that was already solved: every marigold picked, the
## rainbow up, the score as it was. Never check_solved(): `solved` must not
## fire twice.
func restore_completed_board() -> void:
	for i in _state.pos.size():
		if _state.kind[i] == State.ORANGE:
			_state.st[i] = State.GONE
	_state.oranges_left = 0
	_state.fever = true
	_state.score = int(completed_record.get("score", 0))
	_state.shots = int(completed_record.get("shots", 0))
	_log = String(completed_record.get("log", ""))
	var t := _now()
	_fever_at = t - 100.0
	_opened = t - 100.0
	_grown_at = t - 100.0
	_solved_at = t - 100.0
	_phase = "won"
	_layout()
	_say(tr("MG_DONE"), Face.Expr.JOY)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
