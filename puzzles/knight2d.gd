extends "res://core/puzzle_base.gd"

## Knight as a flat board: a paper chessboard on a garden table. Your cream
## knight hops in Ls; take the rose king to win. The king never moves, but
## one to three rose knights stand guard and answer every move you make,
## hopping toward you. Land where one can reach and it takes you: the board
## shakes, holds a beat and slides back one move. The rules live in
## puzzles/knight_state.gd, which this only draws.
##
## Nothing wrong can sit on the board (a catch is undone as it happens), so
## no Check, no tray and no actions row: Undo, Reset and Hint ride in the
## top bar -- Pinwheel's shape.
##
## How it is drawn. Three meshes:
##   table -- the garden table under the board, clipped to the card and
##            drawn outside the entrance's grow;
##   still -- the frame and the squares, rebuilt only on a relayout;
##   live  -- the trail, the marks and every piece, rebuilt only while
##            something moves, or for a blink or a doze now and then. At
##            rest otherwise nothing rebuilds.
## The pieces are ui/faces/chess_piece.gd, which the menu card draws too.
##
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 7.
## Ported from the canvas mock at docs/brainstorm/concepts.html#knight, the
## reference for every measure.

const State = preload("res://puzzles/knight_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Piece = preload("res://ui/faces/chess_piece.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

const INSET := 70.0
const CELL_CAP := 170.0
const FRAME := 24.0
const FRAME_R := 30.0
## The hop: how long, and how high its arc rises at mid-flight, in cells.
const JUMP_TIME := 0.3
const HOP_ARC := 0.55
## A landing's squash: how long, and how deep.
const LAND_TIME := 0.2
const LAND_SQUASH := 0.14
## The rose side's answer: the beat after you land, then each next knight's.
const ANSWER_GAP := 0.08
const ANSWER_STEP := 0.09
## A catch: the hold before the board slides back, and the slide.
const CAUGHT_HOLD := 0.55
const SLIDE_BACK := 0.32
## The crouch before a hop, how deep it squats, and the stretch it springs
## into, which lets go over the first third of the flight.
const CROUCH := 0.08
const CROUCH_SQUASH := 0.12
const TAKEOFF_STRETCH := 0.09
## How far a piece leans into its hop (radians): nose up as it rises, nose
## down as it comes in, level at both ends.
const LEAN := 0.3
## The dust a landing kicks up at the plinth's sides.
const DUST_TIME := 0.35
## A caught knight is knocked aside this far (cells) and over this far
## (radians), with a swirl in its eye, over KNOCK_TIME.
const KNOCK := 0.28
const KNOCK_TILT := 0.45
const KNOCK_TIME := 0.18
## A taken rose knight is knocked off its square: it tumbles away on an arc,
## spinning this far, and fades over this.
const TAKE_TIME := 0.5
const TUMBLE_SPIN := 2.6
## The win: the crown pops off the king and spins to rest on the board over
## CROWN_FLY; your knight rears up; petals fall over PETAL_TIME.
const CROWN_FLY := 0.6
const CROWN_ARC := 0.9
const REAR := 0.4
const REAR_TIME := 0.55
const PETALS := 18
const PETAL_TIME := 2.0
## At rest, now and then: your knight blinks, and the king dozes off with a
## nod and a rising z. Moments, never a loop, so the board rebuilds only
## while one is on.
const BLINK_EVERY := 4.3
const BLINK_TIME := 0.14
const DOZE_EVERY := 7.0
const DOZE_TIME := 1.6
const DOZE_NOD := 0.08
## The garden table the board sits on: its planks, clipped to the card's
## rounded rect (ui/flat/flat_host.gd's stylebox, Rings' CARD_RADIUS).
const CARD_RADIUS := 32.0
const PLANK := 124.0
const TABLE := Color("e9d3b3")
const TABLE_DEEP := Color("b28a62")
## The marks fade in over this once the board is still.
const MARK_FADE := 0.2
## The win: the king tips this far (radians) over this long, then the wait.
const TOPPLE := 1.35
## How far (cells) the taken king is shoved aside as he topples.
const KING_SHOVE := 0.42
const TOPPLE_TIME := 0.45
const WIN_WAIT := 2.2
## The trail keeps only your last few hops' prints, the oldest faintest.
const TRAIL_HOPS := 3
const HINTS := 3
## Insane's moves-left line under the board.
const BUDGET_FONT := 40
const BUDGET_DROP := 64.0
const TIP_CYCLE := 8.0
const TIPS := ["KN_TIP_TAP", "KN_TIP_GOAL", "KN_TIP_ANSWER", "KN_TIP_CORNERS", "KN_TIP_TAKE"]
## The toast: the board's own line for what just happened (a catch, a take,
## a refusal, a hint, an undo), drawn over the foot of the card. The tip card
## that used to carry these is gone from every board, so without it they
## reach no screen. Rings' toast, measure for measure; a line too long for
## the card wraps and the pill grows a row a line.
const TOAST_HOLD := 2.6
const TOAST_H := 84.0
const TOAST_PAD := 80.0
const TOAST_RADIUS := 28.0
const TOAST_FONT := 32
const TOAST_MARGIN := 66.0
const STUCK_MSG := "KN_STUCK"
const REWOUND_MSG := "KN_REWOUND"

var _state = State.new()
var fx: Node2D

## How each piece is travelling: {"from", "to" (squares; -1 off the board),
## "at", "dur", "arc" (cells; 0 slides), "pop" (pops in at `to`)}.
var _you_a := {}
var _foe_a: Array = []
## Rose knights taken this turn, still fading where they stood: {"c", "at"}.
var _gone: Array = []
## A catch in progress: {"at"} when the rose knight lands on you; empty when none.
var _caught := {}
var _shake_at := -100.0
## Which turn the timers _play schedules belong to: a Reset, an Undo, a
## catch's slide-back or a new deal bumps it, and a stale timer does nothing.
var _turn := 0
## Your knight's shiver on a refused tap.
var _bump_at := -100.0
var _rings: Array = []
## Landings still kicking up dust: {"pos", "at"}.
var _dust: Array = []
## Whether the last frame at rest was drawn mid-blink or mid-doze, so the
## frame after the moment ends is rebuilt once to put the face back.
var _idle_drawn := false
var _table: ArrayMesh

var _opened := 0.0
## Input waits, and the marks hide, until this.
var _busy_until := -100.0
var _anim_until := 0.0
var _solved_at := -1.0
var _still: ArrayMesh
var _live: ArrayMesh
## The meshes the last _draw handed over: a canvas command holds a mesh by
## RID, so dropping the only reference leaves the renderer a freed one.
var _shown: Array = []
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## The toast's key (translated as it is drawn, so a language change reaches
## it) and when it went up; "" when none.
var _toast := ""
var _toast_at := -100.0
var _toast_mesh: ArrayMesh
var _toast_mesh_for := ""

func puzzle_id() -> String: return "knight"
func title() -> String: return "Knight"

func rules() -> String:
	return tr("KN_RULES")

## Undo and Hint; Reset is the host's. No Check: a catch is the check.
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
	_turn += 1
	_snap_to_state()
	_rings = []
	_shake_at = -100.0
	_bump_at = -100.0
	_solved_at = -1.0
	_toast = ""
	_toast_at = -100.0
	_opened = _now()
	# The marks wait for the pieces' entrance, then fade in.
	if not Motion.reduce:
		_busy_until = _opened + Motion.ENTER_DELAY + 0.2 \
			+ Motion.stagger(_state.foes.size() + 1, 0.07) + Motion.POP_IN
		_busy_for(_busy_until - _now() + MARK_FADE)
	_layout()
	fx.cue("enter")
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	_tip_timer.start()

static func _still_at(c: int) -> Dictionary:
	return {"from": c, "to": c, "at": -100.0, "dur": 1.0, "arc": 0.0, "pop": false}

## Every piece drawn where the state has it, nothing moving.
func _snap_to_state() -> void:
	_you_a = _still_at(_state.you)
	_foe_a = []
	for f in _state.foes:
		_foe_a.append(_still_at(f))
	_gone = []
	_caught = {}
	_dust = []
	_busy_until = -100.0
	_anim_until = 0.0
	_refresh()

# --- layout ---

func _cell() -> float:
	if _state.w <= 0:
		return 0.0
	return maxf(0.0, minf(CELL_CAP, minf(size.x - 2.0 * INSET, size.y - 2.0 * INSET) / float(_state.w)))

func _grid_size() -> Vector2:
	return Vector2.ONE * float(_state.w) * _cell()

func _origin() -> Vector2:
	return (size - _grid_size()) * 0.5

func _centre(c: int) -> Vector2:
	return _origin() + (Vector2(c % _state.w, c / _state.w) + Vector2(0.5, 0.5)) * _cell()

## Control-local point over the centre of the square at (row, column), the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(r * _state.w + c)

func card_height(available: float) -> float:
	return available

## The board is square and the slot is tall: halve the slack.
func card_centred() -> bool:
	return true

func _layout() -> void:
	_still = null
	_table = null
	_refresh()

func _square_at(local: Vector2) -> int:
	var s := _cell()
	if s <= 0.0:
		return -1
	var v := (local - _origin()) / s
	var x := int(floor(v.x))
	var y := int(floor(v.y))
	if x < 0 or y < 0 or x >= _state.w or y >= _state.w:
		return -1
	return y * _state.w + x

# --- the pieces in motion ---

## Where a travelling piece is at `t`: {"at" (px), "lift" (px), "land"
## (when it lands), "sq" (its crouch or stretch), "tilt" (its lean), "dir"
## (-1 or 1, which way a hop heads), "hopping" (crouched or in the air)};
## empty when it is off the board. A hop crouches for its "crouch" first and
## then flies for "dur"; a slide ("arc" 0) only glides, and lets go of any
## "tilt_from" it started with (a knocked knight righting itself).
func _where(a: Dictionary, t: float) -> Dictionary:
	if int(a.to) < 0:
		return {}
	var from: int = a.from if int(a.from) >= 0 else a.to
	var crouch := float(a.get("crouch", 0.0))
	var fly_at := float(a.at) + crouch
	var dur := maxf(float(a.dur), 0.001)
	var u := 1.0 if Motion.reduce else clampf((t - fly_at) / dur, 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * u)
	var start: Vector2 = a.from_px if a.has("from_px") else _centre(from)
	var end := _centre(a.to)
	var arc := float(a.arc)
	var sq := Vector2.ONE
	var tilt := float(a.get("tilt_from", 0.0)) * (1.0 - e)
	var dir := 1.0 if end.x >= start.x else -1.0
	var hopping := false
	if arc > 0.0 and not Motion.reduce and t >= float(a.at) and t < fly_at + dur:
		hopping = true
		if t < fly_at:
			var k := sin(0.5 * PI * (t - float(a.at)) / maxf(crouch, 0.001)) * CROUCH_SQUASH
			sq = Vector2(1.0 + k * 0.6, 1.0 - k)
		else:
			var st := TAKEOFF_STRETCH * maxf(0.0, 1.0 - u / 0.35)
			sq = Vector2(1.0 - st * 0.6, 1.0 + st)
			tilt = dir * LEAN * -cos(PI * u) * sin(PI * u) * 2.0
	return {"at": start.lerp(end, e), "lift": sin(PI * u) * arc * _cell(),
		"land": fly_at + float(a.dur), "sq": sq, "tilt": tilt, "dir": dir, "hopping": hopping}

func _land_squash(land: float, t: float) -> Vector2:
	var u := (t - land) / LAND_TIME
	if Motion.reduce or u < 0.0 or u >= 1.0:
		return Vector2.ONE
	var k := sin(PI * u) * LAND_SQUASH
	return Vector2(1.0 + k * 0.5, 1.0 - k)

func _jump() -> float:
	return 0.0 if Motion.reduce else JUMP_TIME

func _crouch() -> float:
	return 0.0 if Motion.reduce else CROUCH

## A hop from `from` to `to` starting at `at`: the crouch, then the flight.
func _hop(from: int, to: int, at: float) -> Dictionary:
	return {"from": from, "to": to, "at": at, "dur": maxf(_jump(), 0.001), "arc": HOP_ARC,
		"pop": false, "crouch": _crouch()}

func _kick_dust(c: int, at: float) -> void:
	if not Motion.reduce:
		_dust.append({"pos": _centre(c), "at": at})

## One hop of yours and the rose side's answer, animated. A catch holds, then
## everything slides back; the state never kept it.
func _play(to: int, from_hint := false) -> void:
	var t := _now()
	if is_done() or t < _busy_until:
		return
	if not _state.legal().has(to):
		_refuse("KN_L")
		return
	if _state.moves_left() == 0:
		_refuse("KN_NO_MOVES")
		return
	var from: int = _state.you
	var r: Dictionary = _state.play(to)
	var jt := _jump()
	var lead := _crouch()
	var land := t + lead + jt
	_you_a = _hop(from, to, t)
	_kick_dust(to, land)
	fx.cue("hop")
	var took: int = r.took
	if took >= 0:
		var away := 1.0 if _centre(to).x >= _centre(from).x else -1.0
		_gone.append({"c": to, "at": land, "dir": away})
		_foe_a[took] = _still_at(-1)
		var turn := _turn
		_later(lead + jt, func():
			if turn != _turn:
				return
			fx.puff(_centre(to), Pal.KNIGHT_ROSE, 7)
			fx.cue("take"))
	var last := land
	var k := 0
	var catcher := -1
	var moved: Array = r.moved
	for i in moved.size():
		var mv: Vector2i = moved[i]
		if i == took or mv.x < 0 or mv.y < 0 or mv.x == mv.y:
			continue
		var at := land + (0.0 if Motion.reduce else ANSWER_GAP + Motion.stagger(k, ANSWER_STEP))
		_foe_a[i] = _hop(mv.x, mv.y, at)
		last = at + lead + jt
		_kick_dust(mv.y, last)
		if mv.y == to:
			catcher = mv.x
		k += 1
	if k > 0:
		var turn := _turn
		_later(land - t + (0.0 if Motion.reduce else ANSWER_GAP), func():
			if turn == _turn:
				fx.cue("answer"))
	if bool(r.won):
		_busy_until = land
		_busy_for(land - t)
		note_move()
		return
	if int(r.caught) >= 0:
		var knock := -1.0 if catcher >= 0 and _centre(catcher).x > _centre(to).x else 1.0
		_caught = {"at": last, "dir": knock}
		_shake_at = last
		_busy_until = last + CAUGHT_HOLD + (0.0 if Motion.reduce else SLIDE_BACK)
		_busy_for(_busy_until - t + MARK_FADE)
		var turn := _turn
		_later(last - t, func():
			if turn != _turn:
				return
			fx.cue("caught")
			_tell("KN_CAUGHT", Face.Expr.STRAIN))
		_later(last - t + CAUGHT_HOLD, func():
			if turn == _turn and not _caught.is_empty():
				fx.cue("slide")
				_slide_to_state(_now(), 0.0))
		_refresh()
		return
	_busy_until = last
	_busy_for(last - t + MARK_FADE)
	note_move()
	if took >= 0:
		_tell("KN_TAKEN", Face.Expr.HAPPY)
	elif from_hint:
		_tell("KN_HINT", Face.Expr.HAPPY)
	elif _tip_mood == Face.Expr.STRAIN:
		_say(tr(TIPS[1]), Face.Expr.HAPPY)
	if _state.moves_left() == 0:
		_tell("KN_LAST_MOVE", Face.Expr.STRAIN)
	_refresh()

## How far a caught knight has been knocked at `t`: 0 to 1, 0 when none.
func _knocked(t: float) -> float:
	if _caught.is_empty() or t < float(_caught.at):
		return 0.0
	if Motion.reduce:
		return 1.0
	return Motion.back_out(clampf((t - float(_caught.at)) / KNOCK_TIME, 0.0, 1.0))

## Every piece slides from where it is drawn to where the state has it:
## after a catch, an Undo, a hint's rewind or a Reset. It starts from the
## pixel each piece is drawn at right now (`from_px`), so a Reset or an Undo
## mid-hop slides from the air rather than snapping to the hop's end first,
## and a knocked knight slides home from where it was knocked, righting
## itself on the way. A rose knight taken in the undone move pops back in
## where it stood.
func _slide_to_state(t: float, stagger: float) -> void:
	var dur := 0.001 if Motion.reduce else SLIDE_BACK
	_turn += 1
	var you_now := _where(_you_a, t)
	var kn := _knocked(t)
	var kdir := float(_caught.get("dir", 1.0))
	_caught = {}
	_shake_at = -100.0
	_you_a = {"from": int(_you_a.to), "to": _state.you, "at": t, "dur": dur, "arc": 0.0, "pop": false}
	if not you_now.is_empty():
		_you_a["from_px"] = you_now.at + Vector2(kdir * KNOCK * _cell() * kn, 0.0)
		_you_a["tilt_from"] = kdir * KNOCK_TILT * kn + float(you_now.tilt)
	var k := 0
	for i in _state.foes.size():
		var want: int = _state.foes[i]
		var shown: int = int(_foe_a[i].to)
		var drawn := _where(_foe_a[i], t)
		var at := t + Motion.stagger(k, stagger)
		if want < 0:
			_foe_a[i] = _still_at(-1)
		elif shown < 0:
			_foe_a[i] = {"from": want, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": true}
		else:
			_foe_a[i] = {"from": shown, "to": want, "at": at, "dur": dur, "arc": 0.0, "pop": false}
			if not drawn.is_empty():
				_foe_a[i]["from_px"] = drawn.at
				_foe_a[i]["tilt_from"] = drawn.tilt
		k += 1
	_gone = []
	_dust = []
	_busy_until = t + Motion.stagger(k, stagger) + dur
	_busy_for(_busy_until - t + MARK_FADE)
	_refresh()

## Runs `fn` after `delay`, unless the board has left the tree meanwhile
## (Mushroom Patch's `_after`); the turn guard inside each `fn` does the rest.
func _later(delay: float, fn: Callable) -> void:
	get_tree().create_timer(maxf(0.0, delay)).timeout.connect(func():
		if is_inside_tree():
			fn.call())

func _refuse(key: String) -> void:
	_bump_at = _now()
	_busy_for(Motion.SHIVER_TIME * 2.0)
	fx.cue("refuse")
	_tell(key, Face.Expr.STRAIN)
	_refresh()

# --- frames ---

func _process(delta: float) -> void:
	super(delta)
	if _cell() <= 0.0 or _state.size() == 0:
		return
	var t := _now()
	if _animating(t):
		_refresh()
	elif _idle_moment(t):
		_idle_drawn = true
		_refresh()
	elif _idle_drawn:
		_idle_drawn = false
		_refresh()
	elif _toast != "" and t - _toast_at < TOAST_HOLD + 0.1:
		# the toast is drawn apart from the meshes: a redraw, not a rebuild
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

## Moving while anything travels, the marks are still fading in, or the
## pieces are still entering.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY + Motion.ENTER_POP \
		+ Motion.stagger(_state.foes.size() + 2, 0.07) + Motion.POP_IN + 0.2
	return t - _opened < entrance

## Whether a blink or a doze is on at `t`: the only rebuilds at rest.
func _idle_moment(t: float) -> bool:
	return _eye(t) < 0.5 or _doze(t) >= 0.0

## Your knight's eye at rest: 0 for the length of a blink every BLINK_EVERY.
func _eye(t: float) -> float:
	if Motion.reduce or is_done():
		return 1.0
	return 0.0 if fmod(t - _opened, BLINK_EVERY) < BLINK_TIME else 1.0

## How far through a doze the king is at `t`, 0 to 1; -1 when awake.
func _doze(t: float) -> float:
	if Motion.reduce or is_done() or t < _busy_until:
		return -1.0
	var p := fmod(t - _opened + 3.0, DOZE_EVERY)
	return p / DOZE_TIME if p < DOZE_TIME else -1.0

func _busy_for(seconds: float) -> void:
	# the marks pop in over POP_IN plus their stagger after the fade starts
	_anim_until = maxf(_anim_until, _now() + seconds + Motion.POP_IN + 0.2)

func _refresh() -> void:
	_live = null
	queue_redraw()

func _entry(i: int, t: float) -> float:
	if Motion.reduce:
		return 1.0
	var e := t - _opened - Motion.ENTER_DELAY - 0.2 - Motion.stagger(i, 0.07)
	return 0.01 if e <= 0.0 else Motion.pop_in_scale(e).x

# --- the drawing ---

func _draw() -> void:
	if _state.size() == 0 or _cell() <= 0.0:
		return
	var t := _now()
	var shown: Array = []
	# the table is the card's own surface: never grown, never faded in
	if _table == null:
		_table = _build_table()
	draw_mesh(_table, null)
	shown.append(_table)
	var since := t - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		_shown = shown
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _origin() + _grid_size() * 0.5
	var shake := Motion.shiver_offset(t - _shake_at) * 3.0
	var xf := Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow) + Vector2(shake, 0.0))
	var tint := Color(1.0, 1.0, 1.0, seen)
	if _still == null:
		_still = _build_still()
	if _live == null:
		_live = _build_live(t)
	for m in [_still, _live]:
		if m != null:
			draw_mesh(m, null, xf, tint)
			shown.append(m)
	_draw_budget()
	_draw_toast(t, shown)
	_shown = shown

## The garden table under the board: planks across the card, each a shade
## apart with a butt joint, grain and now and then a knot, and a few petals
## and leaves blown onto it, never under the board. Clipped to the card's
## rounded rect, built once a layout.
func _build_table() -> ArrayMesh:
	var b := Face.Builder.new()
	var clip := Face.Builder.round_rect(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0), CARD_RADIUS - 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7127
	var n := int(ceil(size.y / PLANK))
	var y0 := (size.y - float(n) * PLANK) * 0.5
	for i in n:
		var top := y0 + float(i) * PLANK
		var tone := TABLE.lerp(TABLE_DEEP, 0.06 + 0.07 * float(i % 2) + rng.randf_range(-0.02, 0.02))
		_clipped(b, _rect(Vector2(0.0, top), Vector2(size.x, PLANK - 4.0)), tone, clip)
		_clipped(b, _rect(Vector2(0.0, top + PLANK - 4.0), Vector2(size.x, 4.0)), Color(TABLE_DEEP, 0.55), clip)
		_clipped(b, _rect(Vector2(0.0, top), Vector2(size.x, 3.0)), Color(1.0, 1.0, 1.0, 0.18), clip)
		var joint := rng.randf_range(size.x * 0.2, size.x * 0.8)
		_clipped(b, _rect(Vector2(joint, top), Vector2(3.0, PLANK - 4.0)), Color(TABLE_DEEP, 0.4), clip)
		# grain: long soft waves along the plank, kept clear of the card's corners
		for g in 3:
			var gy := top + PLANK * (0.22 + 0.26 * float(g)) + rng.randf_range(-6.0, 6.0)
			var phase := rng.randf() * TAU
			var x0 := CARD_RADIUS + rng.randf_range(0.0, size.x * 0.3)
			var x1 := minf(size.x - CARD_RADIUS, x0 + rng.randf_range(size.x * 0.35, size.x * 0.7))
			var pts := PackedVector2Array()
			var x := x0
			while x <= x1:
				pts.append(Vector2(x, gy + sin(x / 70.0 + phase) * 3.5))
				x += 18.0
			if pts.size() > 1:
				b.stroke(pts, 2.0, Color(TABLE_DEEP, 0.16))
		if rng.randf() < 0.45:
			var kp := Vector2(rng.randf_range(CARD_RADIUS * 2.0, size.x - CARD_RADIUS * 2.0), top + PLANK * 0.5)
			b.stroke(Face.Builder.ring(kp, 16.0, 7.0), 2.5, Color(TABLE_DEEP, 0.3), true)
			b.ellipse(kp, 6.0, 3.0, Color(TABLE_DEEP, 0.35))
	# petals and leaves, blown on, off the board's footprint
	var keep_out := Rect2(_origin() - Vector2.ONE * (FRAME + 30.0), _grid_size() + Vector2.ONE * (FRAME + 30.0) * 2.0)
	var placed := 0
	var tries := 0
	while placed < 9 and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(40.0, size.y - 40.0))
		if keep_out.has_point(p):
			continue
		var ang := rng.randf() * TAU
		if placed % 3 == 2:
			_leaf(b, p, rng.randf_range(20.0, 28.0), ang)
		else:
			var col: Color = Pal.FLOWER_TILE if placed % 2 == 0 else Pal.FLOWER
			_petal(b, p, rng.randf_range(17.0, 22.0), ang, col)
		placed += 1
	return b.mesh()

static func _rect(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

static func _clipped(b: Face.Builder, pts: PackedVector2Array, col: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(pts, clip):
		b.polygon(piece, col)

## A petal `r` long pointing along `ang`, with a soft shadow under it.
static func _petal(b: Face.Builder, at: Vector2, r: float, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * float(k) / 16.0
		# rounded at the tip, drawn to a notch at the base
		var rr := r * (0.55 + 0.45 * cos(a * 0.5) * cos(a * 0.5))
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.6))
	var shadow := PackedVector2Array()
	var body := PackedVector2Array()
	for q in pts:
		shadow.append(at + q.rotated(ang) + Vector2(2.0, 3.0))
		body.append(at + q.rotated(ang))
	b.polygon(shadow, Color(TABLE_DEEP, 0.25))
	b.polygon(body, col)
	b.stroke(PackedVector2Array([at - Vector2(r * 0.4, 0.0).rotated(ang), at + Vector2(r * 0.3, 0.0).rotated(ang)]),
		1.5, Color(Pal.FLOWER_DEEP, 0.35))

## A leaf `r` long along `ang`, with its vein.
static func _leaf(b: Face.Builder, at: Vector2, r: float, ang: float) -> void:
	var half := PackedVector2Array()
	var body := PackedVector2Array()
	var shadow := PackedVector2Array()
	for k in 9:
		var f := float(k) / 8.0
		half.append(Vector2(lerpf(-r, r, f), -sin(PI * f) * r * 0.42))
	for k in range(7, 0, -1):
		var f := float(k) / 8.0
		half.append(Vector2(lerpf(-r, r, f), sin(PI * f) * r * 0.42))
	for q in half:
		body.append(at + q.rotated(ang))
		shadow.append(at + q.rotated(ang) + Vector2(2.0, 3.0))
	b.polygon(shadow, Color(TABLE_DEEP, 0.25))
	b.polygon(body, Pal.LEAF)
	b.stroke(PackedVector2Array([at - Vector2(r * 1.25, 0.0).rotated(ang), at + Vector2(r * 0.8, 0.0).rotated(ang)]),
		2.0, Color(Pal.LEAF_DEEP, 0.7))

## The wooden frame, its shadow, its brass corner pegs and the squares. None
## of it ever moves.
func _build_still() -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	var o := _origin()
	var g := _grid_size()
	var out := o - Vector2.ONE * FRAME
	var out_size := g + Vector2.ONE * FRAME * 2.0
	Scenery.soft_disc(b, out + out_size * Vector2(0.5, 1.0) + Vector2(0.0, 10.0), out_size.x * 0.55, 36.0, Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(out + Vector2(0.0, 8.0), out_size, FRAME_R), Pal.CHESS_FRAME_DEEP)
	b.fan(Face.Builder.round_rect(out, out_size, FRAME_R), Pal.CHESS_FRAME)
	b.fan(Face.Builder.round_rect(out + Vector2(FRAME, 6.0), Vector2(out_size.x - FRAME * 2.0, 6.0), 3.0),
		Color(1.0, 0.925, 0.784, 0.3))
	# grain along each rail
	for side in 4:
		var along := Vector2.RIGHT if side < 2 else Vector2.DOWN
		var mid := FRAME * 0.5
		var base: Vector2 = [out + Vector2(FRAME_R, mid), out + Vector2(FRAME_R, out_size.y - mid),
			out + Vector2(mid, FRAME_R), out + Vector2(out_size.x - mid, FRAME_R)][side]
		var span := (out_size.x if side < 2 else out_size.y) - FRAME_R * 2.0
		for k in 2:
			var off := (Vector2(along.y, along.x)) * (float(k) * 7.0 - 3.5)
			b.stroke(PackedVector2Array([base + off + along * span * (0.08 + 0.3 * k), base + off + along * span * (0.55 + 0.35 * k)]),
				2.0, Color(Pal.CHESS_FRAME_DEEP, 0.28))
	# the brass pegs at the corners
	for cn: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := out + Vector2(FRAME * 0.5, FRAME * 0.5) + (out_size - Vector2.ONE * FRAME) * cn
		b.disc(p + Vector2(0.0, 2.0), FRAME * 0.34, Pal.CHESS_FRAME_DEEP)
		b.disc(p, FRAME * 0.32, Pal.CROWN_DEEP)
		b.disc(p + Vector2(-2.0, -2.0), FRAME * 0.14, Color(Pal.CROWN, 0.9))
	# the inner lip the squares are set into
	b.fan(PackedVector2Array([o - Vector2.ONE * 4.0, o + Vector2(g.x + 4.0, -4.0), o + g + Vector2.ONE * 4.0,
		o + Vector2(-4.0, g.y + 4.0)]), Pal.CHESS_FRAME_DEEP)
	b.fan(PackedVector2Array([o, o + Vector2(g.x, 0.0), o + g, o + Vector2(0.0, g.y)]), Pal.CHESS_LIGHT)
	var tile := Pal.CHESS_DARK.lerp(Pal.CHESS_LIGHT, 0.2)
	for c in _state.size():
		var x: int = c % _state.w
		var y: int = c / _state.w
		var at := o + Vector2(x, y) * s
		if (x + y) % 2 == 0:
			# a paper square's faint speckle
			var rng := RandomNumberGenerator.new()
			rng.seed = c * 31 + 5
			for k in 3:
				b.disc(at + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)) * s, s * 0.012,
					Color(Pal.CHESS_DARK_EDGE, 0.35))
			continue
		b.fan(PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2(s, s), at + Vector2(0.0, s)]), Pal.CHESS_DARK)
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * s * 0.12, Vector2.ONE * s * 0.76, s * 0.12), tile)
		b.fan(PackedVector2Array([at + Vector2(0.0, s - 5.0), at + Vector2(s, s - 5.0), at + Vector2(s, s), at + Vector2(0.0, s)]),
			Color(Pal.CHESS_DARK_EDGE, 0.5))
	# the lip's shade over the squares' top and left edges
	b.fan(PackedVector2Array([o, o + Vector2(g.x, 0.0), o + Vector2(g.x, 6.0), o + Vector2(0.0, 6.0)]), Color(Pal.CHESS_FRAME_DEEP, 0.18))
	b.fan(PackedVector2Array([o, o + Vector2(6.0, 0.0), o + Vector2(6.0, g.y), o + Vector2(0.0, g.y)]), Color(Pal.CHESS_FRAME_DEEP, 0.12))
	return b.mesh()

## The trail, the marks, every piece (lowest first, anything in the air
## over the rest), the dust, the win's crown and petals, and a hint's ring.
func _build_live(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var s := _cell()
	_draw_trail(b, s, t)
	if not is_done() and t >= _busy_until:
		var fade := 1.0 if Motion.reduce else clampf((t - _busy_until) / MARK_FADE, 0.0, 1.0)
		_draw_marks(b, s, fade, t)
	var items: Array = []
	var kc := _centre(_state.king)
	var fall := -1.0 if _state.king % _state.w >= _state.w / 2 else 1.0
	var tip := 0.0
	var won := _solved_at >= 0.0
	var king_at := kc
	if won:
		var tu := 1.0 if Motion.reduce else clampf((t - _solved_at) / TOPPLE_TIME, 0.0, 1.0)
		tip = fall * TOPPLE * (1.0 if Motion.reduce else Motion.back_out(tu))
		# knocked aside as he goes over, so he lies beside your knight, not under it
		king_at = kc + Vector2(fall * s * KING_SHOVE * (1.0 - (1.0 - tu) * (1.0 - tu)), 0.0)
	var fallen := won and t >= _solved_at
	var doze := _doze(t)
	var dozing := doze >= 0.0 and doze > 0.12 and doze < 0.9
	if doze >= 0.0 and not won:
		tip = sin(PI * doze) * DOZE_NOD * fall
	var king_e := _entry(0, t)
	var crowned := not fallen
	items.append({"air": 0, "y": kc.y - 2.0, "fn": func(): Piece.king(b, king_at, s, tip, king_e, fallen, crowned, dozing)})
	if fallen:
		var cu := 1.0 if Motion.reduce else clampf((t - _solved_at) / CROWN_FLY, 0.0, 1.0)
		var c0 := Piece.crown_seat(kc, s)
		var c1 := kc + Vector2(fall * s * 1.4, s * 0.12)
		var cp := c0.lerp(c1, cu) + Vector2(0.0, -sin(PI * cu) * CROWN_ARC * s)
		var ca := fall * (TAU + 0.5) * Motion.back_out(cu) if not Motion.reduce else fall * 0.5
		items.append({"air": 2, "y": cp.y, "fn": func(): Piece.crown(b, cp, s, ca)})
	var you_now := _where(_you_a, t)
	for i in _foe_a.size():
		var a: Dictionary = _foe_a[i]
		var w := _where(a, t)
		if w.is_empty():
			continue
		var e: Vector2 = Motion.pop_in_scale(maxf(0.0, t - float(a.at))) if bool(a.pop) else Vector2.ONE * _entry(i + 1, t)
		var sq: Vector2 = e * _land_squash(float(w.land), t) * w.sq
		var look := -1.0 if not you_now.is_empty() and you_now.at.x < w.at.x else 1.0
		if bool(w.hopping):
			look = w.dir
		items.append({"air": 1 if float(w.lift) > 0.5 else 0, "y": w.at.y,
			"fn": func(): Piece.knight(b, w.at, s, Piece.ROSE, look, w.lift, sq, false, 1.0, w.tilt)})
	for gn: Dictionary in _gone:
		var gs := t - float(gn.at)
		var gc := _centre(gn.c)
		if gs < 0.0:
			items.append({"air": 0, "y": gc.y, "fn": func(): Piece.knight(b, gc, s, Piece.ROSE, -float(gn.dir))})
		elif gs < TAKE_TIME and not Motion.reduce:
			var u := gs / TAKE_TIME
			var d := float(gn.dir)
			var pos := gc + Vector2(d * s * 0.9 * u, 0.0)
			var lift := s * (1.0 * u - 0.55 * u * u)
			var k := 1.0 - u * u
			var spin := d * TUMBLE_SPIN * u
			items.append({"air": 2, "y": pos.y,
				"fn": func(): Piece.knight(b, pos, s, Piece.ROSE, -d, lift, Vector2.ONE * (1.0 - 0.25 * u), false, k, spin, 1.0, true)})
	if not you_now.is_empty():
		var look := -1.0 if kc.x < you_now.at.x else 1.0
		if bool(you_now.hopping):
			look = you_now.dir
		var kn := _knocked(t)
		if kn > 0.0:
			var kd := float(_caught.dir)
			var pos: Vector2 = you_now.at + Vector2(kd * KNOCK * s * kn, 0.0)
			items.append({"air": 0, "y": you_now.at.y - 1.0,
				"fn": func(): Piece.knight(b, pos, s, Piece.CREAM, -kd, 0.0, Vector2.ONE, false, 1.0, kd * KNOCK_TILT * kn, 1.0, true)})
		else:
			var sh := Motion.shiver_offset(t - _bump_at) * 4.0
			var sq: Vector2 = Vector2.ONE * _entry(_foe_a.size() + 1, t) * _land_squash(float(you_now.land), t) * you_now.sq
			var lift: float = you_now.lift
			var tilt: float = you_now.tilt
			if fallen and not Motion.reduce:
				var v := (t - _solved_at - 0.05) / REAR_TIME
				if v > 0.0 and v < 1.0:
					tilt += -look * REAR * sin(PI * v)
					lift += s * 0.12 * sin(PI * v)
			var eye := _eye(t)
			items.append({"air": 1 if lift > 0.5 else 0, "y": you_now.at.y,
				"fn": func(): Piece.knight(b, you_now.at + Vector2(sh, 0.0), s, Piece.CREAM, look, lift, sq, fallen, 1.0, tilt, eye)})
	items.sort_custom(func(p, q): return p.y < q.y if p.air == q.air else p.air < q.air)
	for it: Dictionary in items:
		it.fn.call()
	_draw_dust(b, s, t)
	if doze >= 0.0 and not won:
		_draw_z(b, kc, s, doze, fall)
	if won:
		_draw_petals(b, s, t - _solved_at)
	_drop_rings(t)
	for r: Dictionary in _rings:
		var u := (t - float(r.at)) / Motion.RING_TIME
		if u >= 0.0 and u < 1.0:
			var rad := s * (0.3 + 0.4 * u)
			b.stroke(Face.Builder.ring(r.pos, rad, rad), s * 0.05 * (1.0 - u) + 1.0, Color(Pal.SUN, 1.0 - u), true)
	return b.mesh() if not b.verts.is_empty() else null

## A landing's dust: little soft clouds puffing out from both sides of the
## plinth, rising a touch and fading.
func _draw_dust(b: Face.Builder, s: float, t: float) -> void:
	var keep: Array = []
	for d: Dictionary in _dust:
		var u := (t - float(d.at)) / DUST_TIME
		if u >= 1.0:
			continue
		keep.append(d)
		if u < 0.0:
			continue
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		for side: float in [-1.0, 1.0]:
			for k in 3:
				var p: Vector2 = d.pos + Vector2(side * s * (0.26 + 0.2 * e + 0.07 * k), s * (0.32 - 0.03 * k - 0.07 * e))
				b.disc(p, s * (0.035 + 0.035 * e) * (1.0 - 0.22 * k), Color(Pal.KNIGHT_CREAM_DEEP, 0.6 * (1.0 - u)))
	_dust = keep

## The dozing king's z, two of them, drifting up and out as he nods.
func _draw_z(b: Face.Builder, kc: Vector2, s: float, doze: float, fall: float) -> void:
	for k in 2:
		var f := clampf(doze * 1.3 - float(k) * 0.3, 0.0, 1.0)
		if f <= 0.0 or f >= 1.0:
			continue
		var h := s * (0.08 + 0.05 * f) * (1.0 - 0.25 * k)
		var at := kc + Vector2(-fall * s * (0.28 + 0.12 * f), -s * (0.55 + 0.35 * f))
		var z := PackedVector2Array([at + Vector2(-h, -h), at + Vector2(h, -h), at + Vector2(-h, h), at + Vector2(h, h)])
		b.stroke(z, s * 0.022, Color(Pal.KNIGHT_ROSE_LINE, 0.75 * sin(PI * f)))

## The win's petals: drifting down over the board from above it, swaying,
## turning, fading as they go.
func _draw_petals(b: Face.Builder, s: float, since: float) -> void:
	if Motion.reduce or since < 0.0 or since >= PETAL_TIME + 0.6:
		return
	var o := _origin()
	var g := _grid_size()
	var cols := [Pal.FLOWER, Pal.FLOWER_TILE, Pal.KNIGHT_ROSE, Pal.CROWN]
	for i in PETALS:
		var h1 := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(float(i) * 78.233) * 12345.678, 1.0)
		var start := h2 * 0.6
		var u := (since - start) / PETAL_TIME
		if u <= 0.0 or u >= 1.0:
			continue
		var x := o.x + g.x * h1 + sin(u * TAU * 1.2 + float(i)) * s * 0.3
		var y := o.y - s * 0.4 + (g.y + s * 0.6) * u
		var ang := u * TAU * (0.6 + h2) + float(i)
		var r := s * (0.07 + 0.03 * h1)
		var pts := PackedVector2Array()
		for k in 12:
			var a := TAU * float(k) / 12.0
			pts.append(Vector2(x, y) + Vector2(cos(a) * r, sin(a) * r * (0.35 + 0.25 * abs(sin(u * 9.0 + float(i))))).rotated(ang))
		b.fan(pts, Color(cols[i % cols.size()], minf(1.0, (1.0 - u) * 2.5)))

## Hoofprints along the L of every hop you have kept: the long leg, then the
## short, a small horseshoe a step, alternating sides; older hops fainter.
## The hop in flight leaves its prints only once it lands.
func _draw_trail(b: Face.Builder, s: float, t: float) -> void:
	var route: PackedInt32Array = _state.route()
	var hops := route.size() - 1
	var last := route.size()
	var first_hop := maxi(1, route.size() - TRAIL_HOPS)
	var you_now := _where(_you_a, t)
	if not you_now.is_empty() and t < float(you_now.land) and float(_you_a.arc) > 0.0:
		last -= 1
	for i in range(first_hop, last):
		var a := _centre(route[i - 1])
		var z := _centre(route[i])
		var d := z - a
		var corner := a + Vector2(d.x, 0.0) if absf(d.x) > absf(d.y) else a + Vector2(0.0, d.y)
		var col := Color(Pal.KNIGHT_CREAM_LINE, 0.3 - 0.07 * float(hops - i))
		var n := 0
		for leg in [[a, corner], [corner, z]]:
			var p0: Vector2 = leg[0]
			var p1: Vector2 = leg[1]
			var ln := p0.distance_to(p1)
			if ln <= 0.0:
				continue
			var dv := (p1 - p0) / ln
			var nrm := Vector2(-dv.y, dv.x)
			var steps := maxi(1, int(round(ln / (s * 0.34))))
			var first := 1 if leg[0] == a else 0
			for k in range(first, steps):
				var p := p0 + dv * (float(k) * ln / float(steps))
				var side := 1.0 if n % 2 == 0 else -1.0
				n += 1
				var base := dv.angle()
				b.stroke(Face.Builder.arc_points(p + nrm * side * s * 0.07, s * 0.052, base - PI * 0.68, base + PI * 0.68),
					s * 0.026, col)

## Rose corners in every square a rose knight reaches right now, a sage dot
## on each square you can hop to -- a rose ring instead where that square is
## in reach, and a sage ring round a rose knight or the king you can take.
func _draw_marks(b: Face.Builder, s: float, fade: float, t: float) -> void:
	var reach: Dictionary = _state.reach()
	var reach_col := Color(Pal.KNIGHT_REACH, 0.55 * fade)
	var gap := s * 0.1
	var tick := s * 0.16
	for q: int in reach:
		if q == _state.king:
			continue
		var o := _origin() + Vector2(q % _state.w, q / _state.w) * s
		for cn: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var corner := o + Vector2(gap + cn.x * (s - 2.0 * gap), gap + cn.y * (s - 2.0 * gap))
			var dx := 1.0 if cn.x == 0.0 else -1.0
			var dy := 1.0 if cn.y == 0.0 else -1.0
			b.stroke(PackedVector2Array([corner + Vector2(0.0, dy * tick), corner, corner + Vector2(dx * tick, 0.0)]),
				s * 0.035, reach_col)
	if _state.moves_left() == 0:
		return
	var legal: PackedInt32Array = _state.legal()
	for i in legal.size():
		var q: int = legal[i]
		var at := _centre(q)
		var e := 1.0 if Motion.reduce else maxf(0.05, Motion.pop_in_scale(maxf(0.0, t - _busy_until - float(i) * 0.025)).x)
		if q == _state.king or _state.foes.has(q):
			var r := s * 0.44 * e
			b.stroke(Face.Builder.ring(at, r, r), s * 0.05, Color(Pal.KNIGHT_MOVE, 0.85 * fade), true)
		elif reach.has(q):
			var r := s * 0.13 * e
			b.stroke(Face.Builder.ring(at, r, r), s * 0.035, Color(Pal.KNIGHT_REACH, 0.7 * fade), true)
		else:
			b.disc(at, s * 0.13 * e, Color(Pal.KNIGHT_MOVE, 0.8 * fade))

## Insane's moves left, centred under the board.
func _draw_budget() -> void:
	var left: int = _state.moves_left()
	if left < 0:
		return
	var text := tr("KN_ONE_MOVE_LEFT") if left == 1 else tr("KN_MOVES_LEFT") % left
	var font: Font = CozyTheme.body(700)
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT).x
	var y := _origin().y + _grid_size().y + FRAME + BUDGET_DROP
	var ink: Color = Pal.BAD if left == 0 and not _state.is_solved() else Pal.TEXT
	draw_string(font, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUDGET_FONT, ink)

## The toast over the foot of the card, fading in and out over
## Motion.DROP_FADE -- Rings' `_draw_toast`, in the card's own pixels and
## wrapped to the card's width. Never under the board's shake or entrance.
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
	var line := tr(_toast)
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
	var mid := Vector2(size.x * 0.5, size.y - TOAST_MARGIN - h * 0.5)
	draw_mesh(_toast_mesh, null, Transform2D(0.0, mid), Color(Color.WHITE, alpha))
	shown.append(_toast_mesh)
	var top := mid.y - h * 0.5 + (TOAST_H - font.get_height(TOAST_FONT)) * 0.5 + font.get_ascent(TOAST_FONT)
	var left := mid.x - w * 0.5 + TOAST_PAD * 0.5
	if lines == 1:
		draw_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT, Color(Pal.PAPER, alpha))
	else:
		draw_multiline_string(font, Vector2(left, top), line, HORIZONTAL_ALIGNMENT_CENTER, w - TOAST_PAD,
			TOAST_FONT, lines, Color(Pal.PAPER, alpha))

func _ring_at(at: Vector2, when: float) -> void:
	if Motion.reduce:
		return
	_rings.append({"pos": at, "at": when})
	_busy_for(when - _now() + Motion.RING_TIME)

func _drop_rings(t: float) -> void:
	var keep: Array = []
	for r: Dictionary in _rings:
		if t - float(r.at) < Motion.RING_TIME:
			keep.append(r)
	_rings = keep

# --- input ---

## A tap on release: on a square your knight can reach, the hop; on your own
## knight, the first tip again; anywhere else on the board, a refusal.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if event.pressed:
			return
		var c := _square_at(event.position)
		if c < 0:
			return
		if c == _state.you:
			_bump_at = _now()
			_say(tr(TIPS[0]), Face.Expr.HAPPY)
			_refresh()
		else:
			_play(c)

# --- the sprout's line ---

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	focus_changed.emit()

## An explanation of what just happened: the sprout's line (which no screen
## shows since the tip card left every board) and the toast, which one does.
## The rotating opening tips never come through here -- they would be noise.
func _tell(key: String, mood: int) -> void:
	_say(tr(key), mood)
	_toast = key
	_toast_at = _now()
	queue_redraw()

func _cycle_tip() -> void:
	if is_done() or _state.can_undo():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return _state.can_undo() and not is_done()

## Slides everything back to before your last kept hop. Counts no move.
func undo() -> bool:
	if is_done() or _now() < _busy_until or not _state.undo():
		return false
	_slide_to_state(_now(), 0.0)
	_tell("KN_UNDONE", Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Plays the next hop of the shortest line from here for you. From a lost
## position -- no line left, or none inside Insane's moves left -- it spends
## the hint rewinding to the last position that still had one instead.
func hint() -> bool:
	if is_done() or hints_left() <= 0 or _now() < _busy_until:
		return false
	var m: int = _state.hint_move()
	if m < 0:
		if _state.rewind_to_live() > 0:
			hints_used += 1
			_slide_to_state(_now(), 0.0)
			_tell(REWOUND_MSG, Face.Expr.HAPPY)
			fx.cue("hint")
			moved.emit()
			return true
		_tell(STUCK_MSG, Face.Expr.STRAIN)
		fx.cue("refuse")
		return false
	hints_used += 1
	_ring_at(_centre(m), _now() + _jump())
	fx.cue("hint")
	_play(m, true)
	return true

func reset_board() -> void:
	_state.reset_board()
	_slide_to_state(_now(), Motion.RESET_STAGGER)
	_rings = []
	_solved_at = -1.0
	_toast = ""
	_toast_at = -100.0
	moves = 0
	_running = true
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
	fx.cue("reset")

func is_solved() -> bool:
	return _state.is_solved()

## The shape of the day and never its answer: you, a rose each, the crown.
func share_glyphs() -> String:
	return "🐴" + "🌹".repeat(_state.foes.size()) + "👑"

# --- the win ---

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("KN_WIN")}

## The win screen waits for your knight to land and the king to fall.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _solved_at - _now()) + WIN_WAIT

func _on_solved() -> void:
	var t := _now()
	_solved_at = maxf(t, float(_you_a.at) + float(_you_a.get("crouch", 0.0)) + float(_you_a.dur))
	_tip_timer.stop()
	var kc := _centre(_state.king)
	if not Motion.reduce:
		_later(_solved_at - t, func():
			fx.sparkle(kc, Pal.SUN)
			fx.ring(kc, _cell() * 0.6)
			fx.puff(kc + Vector2(0.0, _cell() * 0.25), Pal.KNIGHT_ROSE, 6)
			fx.cue("solved"))
		_later(_solved_at - t + 0.2, func(): fx.sparkle(kc, Pal.CROWN))
	else:
		fx.cue("solved")
	_busy_for(_solved_at - t + maxf(TOPPLE_TIME, PETAL_TIME + 0.6))
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_refresh()

## A reopened daily that was already solved: the day's line replayed through
## the state, your knight on the king's square and the king already fallen.
## Never check_solved(): `solved` must not fire twice.
func restore_completed_board() -> void:
	_state.reset_board()
	for m in _state.g.line:
		_state.play(m)
	_snap_to_state()
	var t := _now()
	_solved_at = t - 100.0
	_opened = t - 100.0
	_tip_timer.stop()
	_say(tr("KN_WIN"), Face.Expr.JOY)
	_refresh()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
