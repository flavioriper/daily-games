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

# --- a shot's events ---

func _handle(events: Array, t: float) -> void:
	var s := _s()
	for e: Dictionary in events:
		match String(e.t):
			"hit":
				var i: int = e.i
				_hit_at[i] = t
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
		_put(_pot, xf * Transform2D(0.0, _pt(Vector2(_state.pot_x, State.POT_Y))), tint, shown)
	# the seeds
	if _seed == null:
		var b := Face.Builder.new()
		Parts.bead(b, Vector2.ZERO, State.BALL_R * s)
		_seed = b.mesh()
	for ball: Dictionary in _state.balls:
		_put(_seed, xf * Transform2D(0.0, _pt(ball.p)), tint, shown)
	_draw_sun(t, xf, tint, shown)
	if _state.fever:
		_draw_pot_worths(xf, seen)
	_draw_hud(xf, tint, shown)
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
	b.ellipse(_pt(Vector2(81.0, horizon + 14.0)), 3.0 * s, 1.0 * s, Color(Pal.MG_SHINE, 0.35))
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
	b.stroke(arch, s * 1.4, Pal.MG_ARBOR_DEEP)
	b.stroke(arch, s * 0.9, Pal.MG_ARBOR)
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
		if pick >= 0.0:
			var e := t - pick
			if e >= PICK_TIME or (Motion.reduce and e >= 0.0):
				continue
			if e > 0.0:
				alpha = 1.0 - e / PICK_TIME
				sc = 1.0 + 0.35 * e / PICK_TIME
		elif _state.st[i] != State.LIT:
			continue
		var open := 1.0 if Motion.reduce else Motion.back_out(clampf((t - hit) / BLOOM_TIME, 0.0, 1.0))
		Parts.bloom(b, _pt(_state.pos[i]), r, _state.kind[i], open, sc, alpha)
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
			b.disc(_pt(tr_pts[k]), s * State.BALL_R * (0.25 + 0.55 * u), Color(Pal.MG_SEED, 0.4 * u))
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
	_put(_rays, xf * Transform2D(spin, c), tint, shown)
	_put(_spout, xf * Transform2D(State.aim_dir(_aim).angle(), c), tint, shown)
	_put(_body, xf * Transform2D(0.0, c), tint, shown)

## The band over the field: the seeds left, the score, the multiplier, and
## a row of marigold pips that fill as they bloom, gapped where the
## multiplier steps.
func _draw_hud(xf: Transform2D, tint: Color, shown: Array) -> void:
	var s := _s()
	var mult: int = _state.mult()
	var total: int = _state.orange_total
	var got: int = total - _state.oranges_left
	var key := "%d|%d|%d|%d|%d" % [_state.seeds, got, total, mult, int(size.x)]
	var pip := clampf((size.x - 2.0 * INSET - 40.0) / float(maxi(total, 1) + 4), 12.0, 30.0)
	var steps: Array = []
	for k in range(1, State.STEPS.size()):
		steps.append(int(ceil(float(State.STEPS[k]) * float(total) - 1e-6)))
	var row_w := pip * float(total) + pip * 0.5 * float(steps.size())
	var row_y := BAND - 30.0
	var row_x := (size.x - row_w) * 0.5
	if _hud == null or _hud_for != key:
		var b := Face.Builder.new()
		# the seeds, as a row of little beads
		var shown_seeds := mini(_state.seeds, 10)
		for k in shown_seeds:
			Parts.bead(b, Vector2(INSET + 22.0 + float(k) * 30.0, 38.0), 11.0)
		# the multiplier's pill
		var pill := Rect2(Vector2(size.x - INSET - 118.0, 12.0), Vector2(108.0, 54.0))
		b.fan(Face.Builder.round_rect(pill.position + Vector2(0.0, 4.0), pill.size, 27.0), Pal.MG_CARD_DEEP.darkened(0.2))
		b.fan(Face.Builder.round_rect(pill.position, pill.size, 27.0), Pal.MG_ORANGE if mult > 1 else Pal.MG_CARD_DEEP)
		# the pips
		b.fan(Face.Builder.round_rect(Vector2(row_x - 12.0, row_y - pip * 0.5 - 6.0), Vector2(row_w + 24.0, pip + 12.0), pip * 0.5 + 6.0),
			Color(Pal.MG_CARD_DEEP.darkened(0.25), 0.8))
		var x := row_x
		for k in total:
			if steps.has(k):
				x += pip * 0.5
			var at := Vector2(x + pip * 0.5, row_y)
			if k < got:
				b.disc(at, pip * 0.42, Pal.MG_ORANGE)
				b.disc(at, pip * 0.2, Pal.MG_ORANGE_HI)
			else:
				b.disc(at, pip * 0.32, Color(Pal.MG_SHINE, 0.25))
			x += pip
		_hud = b.mesh()
		_hud_for = key
	_put(_hud, xf, tint, shown)
	var font: Font = CozyTheme.body(800)
	var a := tint.a
	if _state.seeds > 10:
		draw_string(font, xf * Vector2(INSET + 322.0, 50.0), "+%d" % (_state.seeds - 10), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, a))
	elif _state.seeds == 0:
		draw_string(font, xf * Vector2(INSET + 8.0, 50.0), tr("MG_NO_SEEDS"), HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT,
			Color(Pal.PAPER, 0.7 * a))
	var shown_score: int = _state.score + (_state.shot_points if _phase == "shot" else 0)
	var sc := Locale.number(shown_score)
	var sw: float = font.get_string_size(sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT).x
	draw_string(font, xf * Vector2((size.x - sw) * 0.5, 58.0), sc, HORIZONTAL_ALIGNMENT_LEFT, -1, SCORE_FONT, Color(Pal.PAPER, a))
	var m := "×%d" % mult
	var mw: float = font.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT).x
	draw_string(font, xf * Vector2(size.x - INSET - 64.0 - mw * 0.5, 54.0), m, HORIZONTAL_ALIGNMENT_LEFT, -1, MULT_FONT, Color(Pal.PAPER, a))

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
