extends "res://core/puzzle_base.gd"

## Birdsong (spec docs/superpowers/specs/2026-10-22-birdsong-design.md, the
## woodpecker amendment): a memory board. A woodpecker clinging to the old
## tree's trunk knocks a rhythm inside one bar of four beats; the player
## knocks the same rhythm back on one drum on the lawn. Each round the
## woodpecker adds one knock somewhere in the bar, and the day's whole
## rhythm knocked back is the solve. The rules are
## puzzles/birdsong_state.gd's (the old songbird and its four drums went on
## 2026-10-22's evening, at the user's word, for this).
##
## **The garden is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/birdsong_world.gd) is the board's first child, its trunk
## at the left. From the top of the span down: the woodpecker on the trunk
## with the words beside it; the **knock card**, the bar's four beats with
## the woodpecker's row of holes in bark over the player's row, where each
## knock lands where in the bar it was struck (a red berry ringed green when
## good, gold when fine); "Round n of N"; and the drum, the big drum of
## Drumbeat's band (ui/faces/drumbeat_parts.gd's `band_drum`), tapped
## anywhere under the card.
##
## The woodpecker (ui/faces/woodpecker.gd) is a body and a head: a peck is
## the head carried to the bark and back, with chips off the trunk and the
## token's pop. Its bar has a quiet pebble on each beat to set the tempo;
## the player's has none -- the first knock starts it, and the rest are
## judged by the gaps after it, so a phone's sound delay never counts.
## Insane's feints are the head drawn half way and a soft lip, no chips.
##
## A slip (a knock missed, an extra one, one too far off) puzzles the
## woodpecker, shows where the knocks were as dashed rings, and it knocks
## the round again: nothing is ever lost. The bulb has it knock the round
## again. No Undo -- a knock heard cannot be unheard -- and the bin starts
## the day over.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/birdsong_tutorial_diagram.gd plays it with `demo_knock`.

const State = preload("res://puzzles/birdsong_state.gd")
const World = preload("res://puzzles/birdsong_world.gd")
const Bird = preload("res://ui/faces/woodpecker.gd")
const Parts = preload("res://ui/faces/drumbeat_parts.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const StarLine = preload("res://ui/flat/star_line.gd")
const Toast = preload("res://ui/flat/toast_card.gd")

enum Phase { WAIT, LISTEN, PLAY, PAUSE, DONE }

const HAPTICS := {
	"knock": Haptics.TAP,
	"round": Haptics.GOOD,
	"slip": Haptics.WARN,
	"hush": Haptics.TICK,
	"hint": Haptics.GOOD,
	"reset": Haptics.TAP,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## Before the first bar (once nothing lies over the board), before each
## bar the woodpecker knocks, after a round knocked back and after a slip.
const FIRST_LEAD := 1.1
const LEAD := 0.5
const AFTER_ROUND := 1.1
const AFTER_SLIP := 1.2
## A peck: the head's way in before the strike and its way back after; a
## feint goes this share of the way.
const PECK_IN := 0.07
const PECK_OUT := 0.16
const FEINT_REACH := 0.45
## Chips off the bark: how long they fly, how many a peck.
const CHIP_TIME := 0.7
const CHIPS := 5
## How long the holes take to fade on Medium's turn; a mood's time.
const FADE := 0.4
const PUZZLED_TIME := 1.0
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.13
## The win: the knocks' wave, how long the board's own win plays.
const WIN_HOLD := 1.3
const WAVE_STEP := 0.08
## The encore on the win: the woodpecker knocks the day's whole rhythm
## once more at twice the pace, the player's berries hopping to each knock,
## then the flourish. It starts this long after the last knock.
const ENCORE_LEAD := 0.35
## The new knock of a round: its peck a little higher, its chips gold.
const NEW_PITCH := 1.12
## Stars by slips and bulbs: three at no more than the first, two at no
## more than the second.
const STARS_CUT := [1, 3]
## How long the woodpecker beams at a good knock; its nod on a beat of the
## player's bar.
const GLAD_TIME := 0.3
const NOD_TIME := 0.18
## The words beside the woodpecker and the round under the card, at W.
const SAY_SIZE := 54
const SUB_SIZE := 28
const COUNT_SIZE := 30
const BEAT_SIZE := 24

const CARD := Color("fffaf0")
const LANE := Color("f4e8d2")
const BARK := Color("c79a6b")
const BARK_DEEP := Color("8a5a38")
const HOLE := Color("3e2818")
const GOOD_RING := Color("7cb06b")
const OK_RING := Color("f2c14e")

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _phase := Phase.WAIT
## The board's own clock: it stands while a sheet lies over the board. The
## real time of its last step, so a knock between two frames is timed true.
var _t := 0.0
var _t_us := 0
## [time, Callable] run when the clock reaches them, in order.
var _queue: Array = []
## The bar the woodpecker is knocking: when it began, and its pecks
## ({at, slot, feint}).
var _call_at := -INF
var _pecks: Array = []
var _turn_at := -INF
## The player's knocks on the card: {slot, grade (0 good, 1 fine, 2 off), at}.
var _marks: Array = []
## The knocks of the round the dashed rings show after a slip.
var _missed: Array[int] = []
var _slip_at := -INF
var _drum_at := -INF
var _beat_at := -INF
var _round_at := -INF
## The knocks the card shows after a round knocked back (its whole rhythm).
var _shown_knocks: Array[int] = []
var _won_at := -INF
var _enter_at := 0.0
var _say := ""
var _sub := ""
var _say_at := -INF
var _pressing := -2
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
var _card: ArrayMesh
var _card_key := ""
var _rings := {}
## The board's sounds and sparks; none on the tutorial's silent board.
var fx: Node
## Why a slip was a slip, under the card; the stars over it.
var _toast := Toast.new()
var _stars := StarLine.new()
## The bulb was pressed this round: its holes stay on the card through the
## turns until it is knocked back, on every band.
var _peek := false
## The knock this round adds (-1 on the first), and the beat lit last: the
## woodpecker's on its bar, the player's from their first knock (seen only,
## never heard -- a sound would come late by the phone's delay).
var _new_slot := -1
var _beat_k := -1
var _glad_at := -INF
var _encore_at := -INF

func puzzle_id() -> String: return "birdsong"
func title() -> String: return "Birdsong"

func rules() -> String:
	var out := tr("BS_RULES") % int(State.KNOCKS[_band])
	out += "\n\n" + tr("BS_RULES_SLIP")
	if int(State.FEINTS[_band]) > 0:
		out += "\n\n" + tr("BS_RULES_FEINT")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/birdsong_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LISTEN, "HTP_BS_LISTEN", tr("HTP_BS_LISTEN_BODY")],
		[Diagram.Lesson.PLAY, "HTP_BS_PLAY", tr("HTP_BS_PLAY_BODY")],
		[Diagram.Lesson.SLIP, "HTP_BS_SLIP", tr("HTP_BS_SLIP_BODY")],
	]
	if int(State.FEINTS[_band]) > 0:
		steps.append([Diagram.Lesson.FEINT, "HTP_BS_FEINT", tr("HTP_BS_FEINT_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_BS_HINT", tr("HTP_BS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a knock heard cannot be unknocked, and nothing on the
## board is ever wrong for a Check to find.
func capabilities() -> Array[String]:
	return ["hint"]

func hints_left() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_fresh()
	_enter_at = _t
	_cue("enter")
	_after(FIRST_LEAD, _first_bar)

## Nothing knocked, the bar not begun.
func _fresh() -> void:
	_queue.clear()
	_pecks.clear()
	_marks.clear()
	_missed.clear()
	_shown_knocks.clear()
	_call_at = -INF
	_phase = Phase.WAIT
	_say = ""
	_sub = ""
	_peek = false
	_new_slot = -1
	_beat_k = -1
	_encore_at = -INF
	_toast.clear()
	_stars.clear(3)
	_relayout()

func day_dict() -> Dictionary:
	if _st.order.is_empty():
		return {}
	return {
		"source": "generator", "kind": "text",
		"payload": {"bpm": _st.bpm(), "grid": _st.grid(), "knocks": _st.order.size(),
			"start": int(State.START[_band]), "feints": int(State.FEINTS[_band]), "show": _show()},
		"solution": {"order": Array(_st.order), "feints": _st.feints.duplicate(true)},
		"metrics": {"knocks": _st.order.size(), "rounds": _st.rounds(), "bpm": _st.bpm(),
			"grid": _st.grid(), "quick": _quick_knocks(), "bar": snappedf(_st.bar(), 0.01)},
	}

## How many of the day's knocks sit on a sixteenth.
func _quick_knocks() -> int:
	var n := 0
	for s in _st.order:
		if _st.grid() == 16 and s % 2 == 1:
			n += 1
	return n

# --- the woodpecker's bar ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _first_bar() -> void:
	if _phase != Phase.WAIT or is_done():
		return
	_knock_bar()

## The woodpecker knocks the round's bar, a pebble on each beat under it.
func _knock_bar() -> void:
	_queue.clear()
	_phase = Phase.LISTEN
	_st.begin_turn()
	_marks.clear()
	_missed.clear()
	_shown_knocks.clear()
	_say_now("BS_LISTEN")
	_new_slot = _st.new_slot()
	_beat_k = -1
	var at := _t + LEAD
	_call_at = at
	_pecks.clear()
	var step: float = _st.slot_time()
	for s in _st.knocks:
		_pecks.append({"at": at + s * step, "slot": s, "feint": false, "new": s == _new_slot})
	for s in _st.round_feints():
		_pecks.append({"at": at + s * step, "slot": s, "feint": true, "new": false})
	_pecks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	for p: Dictionary in _pecks:
		var feint: bool = p.feint
		var fresh: bool = p.new
		_after(float(p.at) - _t, func() -> void: _peck(feint, fresh))
	for k in 4:
		_after(LEAD + k * _st.beat(), func() -> void: _tick(k))
	_after(LEAD + _st.bar(), _your_turn)

func _peck(feint: bool, fresh := false) -> void:
	if feint:
		_cue("feint", randf_range(0.98, 1.02), 0.0, 0)
	else:
		_cue("peck", NEW_PITCH if fresh else randf_range(0.98, 1.02), 1.5 if fresh else 0.0, 0)

func _tick(k: int) -> void:
	_beat_at = _t
	_beat_k = k
	_cue("tick", 1.06 if k == 0 else 1.0, 0.0, 0)

func _your_turn() -> void:
	if _phase != Phase.LISTEN:
		return
	_phase = Phase.PLAY
	_turn_at = _t
	_beat_k = -1
	_say_now("BS_YOUR_TURN", "BS_TURN_SUB")

## Now, between two of the clock's steps: a knock is timed to the touch.
func _now() -> float:
	if demo or clock_held or _t_us == 0:
		return _t
	return _t + minf(float(Time.get_ticks_usec() - _t_us) / 1000000.0, 0.05)

## The player knocked the drum.
func _knock() -> void:
	if is_done() or _won:
		return
	var t := _now()
	_drum_at = t
	# the player's knock: wood, kin to the peck and a little deeper (the
	# user, 2026-10-29: players hated the drum's sound)
	_cue("knock", randf_range(0.98, 1.02), 0.0, 0)
	match _phase:
		Phase.WAIT:
			# a knock before the first bar starts it now
			if not clock_held:
				_knock_bar()
			return
		Phase.LISTEN:
			# the woodpecker is knocking: a little shush
			_cue("hush")
			return
		Phase.PAUSE, Phase.DONE:
			return
	moves += 1
	moved.emit()
	var heard: int = _st.heard(t)
	_marks.append({"slot": _st.last_slot, "grade": _st.last_grade, "at": t})
	if _st.last_grade == 0 and heard != State.Heard.SLIP:
		_glad_at = _t
		if not demo:
			var c := Vector2(_slot_x(clampf(_st.last_slot, 0.0, _st.grid() - 1.0)), _lane(1).get_center().y)
			fx.ring(c, _mark_r() * 1.6, GOOD_RING)
	match heard:
		State.Heard.SLIP:
			_slip()
		State.Heard.ROUND:
			_round_done()
		State.Heard.SOLVED:
			_solved_now()

## The knocks of the round just knocked back (the state has moved on).
func _shown_round() -> Array[int]:
	var out: Array[int] = []
	var n: int = mini(int(State.START[_band]) + _st.history.size() - 1, _st.order.size())
	for i in n:
		out.append(_st.order[i])
	out.sort()
	return out

func _slip() -> void:
	_phase = Phase.PAUSE
	_slip_at = _t
	_missed.clear()
	for i in _st.knocks.size():
		if _st.grades[i] < 0:
			_missed.append(_st.knocks[i])
	_cue("slip")
	_say_now("BS_AGAIN")
	_toast.say(_why_line(), _t)
	_rate()
	_after(AFTER_SLIP, _knock_bar)

## Why the slip was a slip, and where the knock it was about sits.
func _why_line() -> String:
	var key: String = ["BS_WHY_EARLY", "BS_WHY_LATE", "BS_WHY_EXTRA", "BS_WHY_MISSED"][_st.why]
	return tr(key) % _where(_st.why_slot)

## A slot in words a player counts by: on a beat, half way between two, or
## just after or before one.
func _where(s: int) -> String:
	var per: int = _st.grid() / 4
	var b := s / per + 1
	match (s % per) * 4 / per:
		0:
			return tr("BS_AT_BEAT") % b
		2:
			return tr("BS_AT_AND") % [b, b + 1] if b < 4 else tr("BS_AT_AND_END") % b
		1:
			return tr("BS_AT_AFTER") % b
		_:
			return tr("BS_AT_BEFORE") % (b + 1) if b < 4 else tr("BS_AT_END")

## The stars by slips and bulbs read.
func _rate(shown := true) -> void:
	var n: int = _st.slips + hints_used
	_stars.rate(3 if n <= int(STARS_CUT[0]) else (2 if n <= int(STARS_CUT[1]) else 1), _t, shown)

func _round_done() -> void:
	_phase = Phase.PAUSE
	_round_at = _t
	_shown_knocks = _shown_round()
	_peek = false
	_toast.clear()
	# clean rounds in a row climb the flourish; three or more, or every
	# knock good, get their own word
	var run: int = _st.run
	var pitch := 1.0 + 0.05 * clampi(run - 1, 0, 4)
	_after(0.12, func() -> void:
		_cue("round", pitch)
		if not demo:
			fx.sparkle(_head_at() + Vector2(0, -_bird_r() * 0.8), Pal.SUN)
			if run >= 3 or _st.perfect:
				fx.sparkle(_head_at() + Vector2(-_bird_r(), -_bird_r() * 0.3), Pal.SUN)
				fx.sparkle(Vector2(_l("card_x") + _l("card_w") * 0.5, _l("card_y")), Pal.SUN))
	_after(AFTER_ROUND, _knock_bar)
	if run >= 3:
		_say = "BS_RUN"
		_say_at = _t
		_sub = ""
	elif _st.perfect:
		_say_now("BS_PERFECT")
	else:
		_say_now("BS_NICE")

func _solved_now() -> void:
	_phase = Phase.DONE
	_queue.clear()
	_won_at = _t
	_shown_knocks = _shown_round()
	_say = ""
	_sub = ""
	_peek = false
	_toast.clear()
	# the encore: the day's whole rhythm at twice the pace, the berries
	# hopping to each knock, then the flourish
	_encore_at = _t + ENCORE_LEAD
	_pecks.clear()
	var step: float = _st.slot_time() * 0.5
	for s in _shown_knocks:
		var at: float = _encore_at + s * step
		_pecks.append({"at": at, "slot": s, "feint": false, "new": false})
		_after(at - _t, func() -> void: _cue("peck", 1.04, 0.0, 0))
	var end: float = ENCORE_LEAD + _st.bar() * 0.5
	_after(end, func() -> void: _cue("solved"))
	if not demo:
		_after(end + 0.25, func() -> void:
			fx.confetti(_head_at() + Vector2(0, -_bird_r()), 26, size.x * 0.7)
			# three stars: the party's toots over the confetti
			_cue("party" if _stars.stars >= 3 else "confetti"))
	check_solved()

func is_solved() -> bool:
	return _st.solved()

## The bulb: the woodpecker knocks the round again.
func hint() -> bool:
	if hints_left() <= 0 or not (_phase == Phase.PLAY or _phase == Phase.LISTEN):
		return false
	hints_used += 1
	_peek = true
	_cue("hint")
	_rate()
	_knock_bar()
	return true

## The bin: the day from its first round.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_fresh()
	_rate(false)
	_cue("reset")
	_after(LEAD, _knock_bar)

func _say_now(key: String, sub := "") -> void:
	_say = key
	_sub = sub
	_say_at = _t

func _cue(name: String, pitch := 1.0, volume_db := 0.0, gap := Fx2D.CUE_GAP) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch, volume_db, gap)

## The tutorial's finger on the drum.
func demo_knock() -> void:
	_knock()

func phase() -> int:
	return _phase

func round_no() -> int:
	return _st.round_no()

func state():
	return _st

## When the player's bar's knock `i` is due on the board's clock: their
## first knock any time, the rest from it (the tutorial and the harness).
func knock_due(i: int) -> float:
	return _st.due(i) if _st.started() else _t

func clock() -> float:
	return _t

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	_t_us = Time.get_ticks_usec()
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
	if _phase == Phase.PLAY:
		# the player's beats from their first knock, lit on the card and
		# nodded by the woodpecker
		if _st.started():
			var k := int(floor((_t - _st.anchor) / _st.beat()))
			if k != _beat_k and k >= 0 and k < 4:
				_beat_k = k
				_beat_at = _t
		var miss: int = _st.missed(_t)
		if miss >= 0:
			_slip()
	queue_redraw()

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _pressing != -2:
				return
			_pressing = finger
			if on_drum(event.position):
				_knock()
		elif finger == _pressing:
			_pressing = -2

## A finger anywhere under the card is on the drum: one drum, the whole
## lawn its skin, so a thumb never misses it.
func on_drum(local: Vector2) -> bool:
	return not _L.is_empty() and local.y > float(_L.card_y) + float(_L.card_h) + 20.0 * _u()

## Where a finger knocking the drum goes, in this board's pixels.
func drum_to_local() -> Vector2:
	return _skin()

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

## What the host's rows cover, in this board's own pixels (laid full rect).
## On the win the board is not laid out again at once: it eases into the
## win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	var was := _won
	_won = won
	if won and not was and not _L.is_empty():
		_from = _L.duplicate()
		_lay_at = _t
	_relayout()

func set_shift(x: float, leaving := false) -> void:
	_shift = x
	position.x = x
	if _world != null:
		_world.position.x = -x
		_world.visible = not leaving

func skip_entrance() -> void:
	_enter_at = -10.0

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(float(_L.horizon), float(_L.foot))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 200.0 * u)
	var bird_r := minf(96.0 * u, span * 0.075)
	var card_w := w * 0.88
	var card_h := minf(290.0 * u, span * 0.21)
	var card_y := top + span * 0.38
	var drum_r := minf(180.0 * u, span * 0.13)
	var foot := bottom - maxf(30.0 * u, span * 0.06)
	return {
		"u": u, "top": top, "bottom": bottom,
		# the woodpecker on the trunk's right side, its head high in the span
		"bird_x": World.trunk_edge(w) if _world != null else w * 0.3,
		"bird_y": top + span * 0.29, "bird_r": bird_r,
		"say_x": w * 0.66, "say_y": top + span * 0.13,
		"card_x": (w - card_w) * 0.5, "card_y": card_y, "card_w": card_w, "card_h": card_h,
		"foot": foot, "drum_r": drum_r, "drum_x": w * 0.5,
		"count_y": card_y + card_h + 52.0 * u,
		"horizon": minf(foot - drum_r * 2.4, card_y + card_h + 120.0 * u),
	}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L[key])
	if _from.is_empty() or not _from.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _bird_r() -> float:
	return _l("bird_r")

func _bird_at() -> Vector2:
	return Vector2(_l("bird_x"), _l("bird_y"))

## The head's middle now: at rest, or on its way to the bark.
func _head_at() -> Vector2:
	var r := _bird_r()
	return _bird_at() + Bird.head_at(r) + Bird.strike(r) * _pose()

func _skin() -> Vector2:
	return Vector2(_l("drum_x"), _l("foot") + Parts.skin_y(0, _l("drum_r")))

## The card's two lanes: the woodpecker's on top, the player's under it.
func _lane(i: int) -> Rect2:
	var u := _u()
	var ch := _l("card_h")
	var x := _l("card_x") + 120.0 * u
	var w := _l("card_w") - 150.0 * u
	var h := ch * 0.33
	return Rect2(x, _l("card_y") + ch * 0.2 + i * (h + ch * 0.06), w, h)

## Slot `s` (a float: a knock lands between slots) across the lanes.
func _slot_x(s: float) -> float:
	var lane := _lane(0)
	var pad := 30.0 * _u()
	return lane.position.x + pad + s * (lane.size.x - 2.0 * pad) / float(_st.grid())

func _mark_r() -> float:
	var lane := _lane(0)
	var cell := (lane.size.x - 60.0 * _u()) / float(_st.grid())
	return minf(cell * 0.42, lane.size.y * 0.36)

# --- the peck ---

## How far the head is toward the bark: 1 at a strike, a feint less.
func _pose() -> float:
	var p := 0.0
	for k: Dictionary in _pecks:
		var reach := FEINT_REACH if k.feint else 1.0
		var d := float(k.at) - _t
		if d >= 0.0 and d < PECK_IN:
			p = maxf(p, reach * (1.0 - d / PECK_IN))
		var a := _t - float(k.at)
		if a >= 0.0 and a < PECK_OUT:
			p = maxf(p, reach * (1.0 - a / PECK_OUT))
	return p * (0.4 if Motion.reduce else 1.0)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.order.is_empty():
		return
	_draw_bird()
	_draw_chips()
	_draw_card()
	_draw_drum()
	_draw_say()

func _draw_bird() -> void:
	var r := _bird_r()
	var at := _bird_at()
	var e := _t - _enter_at - Motion.ENTER_DELAY
	if e < 0.0:
		return
	var lift := 0.0
	if e < Motion.DROP_TIME:
		lift -= Motion.drop_in_lift(maxf(e, 0.0), Motion.DROP * 2.0 * _u())
	if _phase == Phase.DONE:
		lift += Motion.hop_lift(fmod(_t - _won_at, 0.6), Motion.SOLVE_HOP * 1.4 * _u(), 0.5)
	var breath := 1.0 + 0.015 * sin(_t * TAU / 2.6) if not Motion.reduce else 1.0
	# the drumming spot it keeps coming back to
	var spot := at + Bird.head_at(r) + Bird.strike(r) + Bird.beak_tip(r)
	draw_set_transform(spot + Vector2(-4.0 * _u(), 0.0), 0.0, Vector2(0.7, 1.0))
	draw_circle(Vector2.ZERO, r * 0.1, HOLE)
	draw_set_transform(Vector2.ZERO)
	draw_mesh(Bird.body(r), null, Transform2D(0.0, Vector2(1.0, breath), 0.0, at + Vector2(0, lift)))
	var mood := Bird.Mood.REST
	var puzzled := _t - _slip_at < PUZZLED_TIME
	if _phase == Phase.DONE or _t - _round_at < AFTER_ROUND * 0.8 or _t - _glad_at < GLAD_TIME:
		mood = Bird.Mood.JOY
	elif puzzled:
		mood = Bird.Mood.PUZZLED
	elif fmod(_t, BLINK_EVERY) < BLINK_TIME:
		mood = Bird.Mood.BLINK
	var pose := _pose()
	var cock := 0.0
	if puzzled and not Motion.reduce:
		cock = 0.3 * sin(clampf((_t - _slip_at) / PUZZLED_TIME, 0.0, 1.0) * PI)
	# a nod on each beat of the player's bar: the beat they keep, seen
	if _phase == Phase.PLAY and _st.started() and _t - _beat_at < NOD_TIME and not Motion.reduce:
		cock += 0.16 * sin((_t - _beat_at) / NOD_TIME * PI)
	var head := at + Bird.head_at(r) * Vector2(1.0, breath) + Bird.strike(r) * pose + Vector2(0, lift)
	draw_mesh(Bird.head(r, mood), null, Transform2D(-0.1 * pose + cock, head))

## Chips off the bark at each strike, thrown out and falling.
func _draw_chips() -> void:
	if Motion.reduce:
		return
	var r := _bird_r()
	var u := _u()
	var spot := _bird_at() + Bird.head_at(r) + Bird.strike(r) + Bird.beak_tip(r)
	for k: Dictionary in _pecks:
		if k.feint:
			continue
		var a := _t - float(k.at)
		if a < 0.0 or a > CHIP_TIME:
			continue
		var fade := 1.0 - a / CHIP_TIME
		for i in CHIPS:
			var h1 := fposmod(sin(float(k.slot) * 12.9 + i * 78.2) * 43758.5, 1.0)
			var h2 := fposmod(sin(float(k.slot) * 39.3 + i * 11.7) * 24634.6, 1.0)
			var v := Vector2(160.0 + 300.0 * h1, -240.0 - 260.0 * h2) * u
			var p := spot + v * a + Vector2(0.0, 900.0 * u * a * a)
			var s := (7.0 + 4.0 * h1) * u
			var turn := a * (6.0 + i)
			var col := BARK if i % 2 == 0 else Color("d9b48a")
			if k.get("new", false) and i % 2 == 1:
				col = Pal.SUN
			draw_colored_polygon(PackedVector2Array([p + Vector2(-s, -s * 0.5).rotated(turn),
				p + Vector2(s * 1.1, -s * 0.2).rotated(turn), p + Vector2(-s * 0.2, s * 0.8).rotated(turn)]), Color(col, fade))

## The knock card: one cached mesh a layout (the paper, the lanes, the
## beats), the holes, rings and berries over it.
func _draw_card() -> void:
	var u := _u()
	var won := _phase == Phase.DONE or is_done()
	if _won:
		var seen := clampf(1.0 - (_t - _lay_at) / 0.4, 0.0, 1.0)
		if seen <= 0.0:
			return
	var key := "%d:%d:%d:%d" % [roundi(size.x), roundi(_l("card_y")), roundi(_l("card_h")), _st.grid()]
	if key != _card_key:
		_card_key = key
		_card = _build_card()
	draw_mesh(_card, null)
	var font: Font = CozyTheme.display(700)
	var fs := roundi(BEAT_SIZE * u)
	for k in 4:
		var x := _slot_x(k * _st.grid() / 4)
		var tw := font.get_string_size(str(k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lit := (_phase == Phase.LISTEN or _phase == Phase.PLAY) and _t - _beat_at < 0.2 and _beat_k == k
		draw_string(font, Vector2(x - tw * 0.5, _lane(0).position.y - 14.0 * u), str(k + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Parts.LANE_DEEP[0] if lit else Pal.TEXT_DIM)
	var r := _mark_r()
	var top := _lane(0).get_center().y
	var low := _lane(1).get_center().y
	# the woodpecker's holes
	var holes: Array[int] = []
	var vis := 0.0
	if won:
		holes = _shown_knocks if not _shown_knocks.is_empty() else _st.knocks
		vis = 1.0
	elif _phase == Phase.LISTEN:
		for k: Dictionary in _pecks:
			if not k.feint and _t >= float(k.at):
				holes.append(int(k.slot))
		vis = 1.0 if _show() > 0 or _peek else 0.0
	elif _phase == Phase.PLAY:
		holes = _st.knocks
		vis = 1.0 if _show() == 2 or _peek else (clampf(1.0 - (_t - _turn_at) / FADE, 0.0, 1.0) if _show() == 1 else 0.0)
	elif _phase == Phase.PAUSE and not _shown_knocks.is_empty():
		holes = _shown_knocks
		vis = 1.0
	if vis > 0.0:
		for s in holes:
			var since := _t - _peck_at(s)
			var k := Motion.pop_in_scale(since).x if since < Motion.POP_IN and _phase == Phase.LISTEN else 1.0
			var c := Vector2(_slot_x(s), top)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.86) * k)
			draw_circle(Vector2.ZERO, r, Color(BARK_DEEP, vis))
			draw_circle(Vector2(1.5, 2.5) * u, r * 0.66, Color(HOLE, vis))
			draw_set_transform(Vector2.ZERO)
			# the round's new knock glints
			if s == _new_slot and not won and since >= 0.0:
				var p := 0.5 if Motion.reduce else 0.5 + 0.5 * sin((_t - _peck_at(s)) * 6.0)
				draw_arc(c, (r + 7.0 * u) * k, 0.0, TAU, 32, Color(Pal.SUN, vis * (0.55 + 0.45 * p)), 5.0 * u, true)
	# after a slip: dashed rings where the knocks were
	if _phase == Phase.PAUSE and _shown_knocks.is_empty():
		for s in _missed:
			_dashed(Vector2(_slot_x(s), low), r, Color(Pal.BAD, 0.8), 4.0 * u)
	# the player's knocks
	for m: Dictionary in _marks:
		var s: float = clampf(float(m.slot), -0.45, _st.grid() - 0.55)
		var c := Vector2(_slot_x(s), low)
		var since := _t - float(m.at)
		var k := Motion.pop_in_scale(since).x if since < Motion.POP_IN else 1.0
		if won and not Motion.reduce:
			# hops to the encore's knock nearest it, or a wave on a reopened day
			var from := _won_at + _marks.find(m) * WAVE_STEP
			if _encore_at > -INF:
				from = _encore_at + roundf(float(m.slot)) * _st.slot_time() * 0.5
			c.y += Motion.hop_lift(maxf(0.0, _t - from), Motion.SOLVE_HOP * 1.4 * u, Motion.SOLVE_TIME)
		match int(m.grade):
			2:
				draw_mesh(Parts.berry(0, r * 0.8, Parts.Mood.WORRIED), null, Transform2D(0.0, Vector2.ONE * k, 0.0, c), Color(1, 1, 1, 0.55))
				draw_arc(c, r * 0.95 * k, 0.0, TAU, 32, Pal.BAD, 4.0 * u, true)
			_:
				draw_arc(c, (r + 6.0 * u) * k, 0.0, TAU, 32, GOOD_RING if int(m.grade) == 0 else OK_RING, 6.0 * u, true)
				draw_mesh(Parts.berry(0, r * 0.84, Parts.Mood.JOY if won else Parts.Mood.HAPPY), null, Transform2D(0.0, Vector2.ONE * k, 0.0, c))
	# the playhead: through the woodpecker's bar, and the player's once begun
	var ph := INF
	var lane := -1
	if _phase == Phase.LISTEN and _t >= _call_at:
		ph = (_t - _call_at) / _st.slot_time()
		lane = 0
	elif _phase == Phase.PLAY and _st.started():
		ph = _st.slot_at(_t)
		lane = 1
	if lane >= 0 and ph > -0.5 and ph < _st.grid() - 0.5:
		var rc := _lane(lane)
		var x := _slot_x(ph)
		draw_line(Vector2(x, rc.position.y + 8.0 * u), Vector2(x, rc.end.y - 8.0 * u), Color(Pal.TEXT, 0.5), 5.0 * u, true)

## How long the holes stay on the card; the tutorial's board always shows
## them, so its pages show what their words say.
func _show() -> int:
	return 2 if demo else _st.show()

func _peck_at(s: int) -> float:
	for k: Dictionary in _pecks:
		if int(k.slot) == s and not k.feint:
			return float(k.at)
	return -INF

func _dashed(c: Vector2, r: float, col: Color, w: float) -> void:
	var n := 12
	for i in n:
		var a := TAU * i / n
		draw_arc(c, r, a, a + TAU / n * 0.55, 6, col, w, true)

func _build_card() -> ArrayMesh:
	var u := _u()
	var b := Face.Builder.new()
	var at := Vector2(_l("card_x"), _l("card_y"))
	var sz := Vector2(_l("card_w"), _l("card_h"))
	b.polygon(Face.Builder.round_rect(at + Vector2(0, 8.0 * u), sz, 40.0 * u), Color(Pal.TEXT, 0.12))
	b.polygon(Face.Builder.round_rect(at, sz, 40.0 * u), CARD)
	# the tail toward the woodpecker
	var tip := Vector2(_l("bird_x") + 70.0 * u, at.y - 60.0 * u)
	b.polygon(PackedVector2Array([Vector2(tip.x - 20.0 * u, at.y + 4.0), tip, Vector2(tip.x + 60.0 * u, at.y + 4.0)]), CARD)
	# the woodpecker's lane in bark, its grain; the player's in paper
	var l0 := _lane(0)
	var l1 := _lane(1)
	b.polygon(Face.Builder.round_rect(l0.position, l0.size, 24.0 * u), BARK)
	for i in 3:
		var y := l0.position.y + l0.size.y * (0.28 + 0.22 * i)
		var pts := PackedVector2Array()
		for j in 25:
			var x := lerpf(l0.position.x + 20.0 * u, l0.end.x - 20.0 * u, j / 24.0)
			pts.append(Vector2(x, y + sin(x / (40.0 * u) + i) * 3.0 * u))
		b.stroke(pts, 3.0 * u, Color(BARK_DEEP, 0.35))
	b.polygon(Face.Builder.round_rect(l1.position, l1.size, 24.0 * u), LANE)
	# the beats between the lanes, the slots on the player's
	var g: int = _st.grid()
	var cell := (l0.size.x - 60.0 * u) / g
	for k in range(1, 4):
		var x := _slot_x(k * g / 4) - cell * 0.5
		b.stroke(PackedVector2Array([Vector2(x, l0.position.y + 8.0 * u), Vector2(x, l1.end.y - 8.0 * u)]), 3.0 * u, Color(Pal.TEXT_DIM, 0.35))
	for s in g:
		var big := s % (g / 4) == 0
		b.disc(Vector2(_slot_x(s), l1.get_center().y), (6.0 if big else 4.0) * u, Color(Pal.TEXT_DIM, 0.45 if big else 0.25))
	# the lanes' marks: the woodpecker's head, the drum
	var ic := Vector2(_l("card_x") + 62.0 * u, l0.get_center().y)
	b.append(Bird.head(18.0 * u / Bird.HEAD_R), Transform2D(0.0, ic + Vector2(14.0 * u, 0)))
	b.append(Parts.band_drum(0, 22.0 * u, Parts.Mood.HAPPY), Transform2D(0.0, Vector2(ic.x, l1.end.y - 8.0 * u)))
	return b.mesh()

func _draw_drum() -> void:
	var r := _l("drum_r")
	var u := _u()
	var seen := 1.0
	if _won:
		seen = clampf(1.0 - (_t - _lay_at) / 0.4, 0.0, 1.0)
		if seen <= 0.0:
			return
	var foot := Vector2(_l("drum_x"), _l("foot"))
	var e := _t - _enter_at - Motion.ENTER_DELAY
	var pop := 1.0 if e >= Motion.ENTER_POP else (Motion.wide_pop_scale(maxf(e, 0.0)) if e > 0.0 else 0.0)
	if pop <= 0.0:
		return
	var hit := _t - _drum_at
	var squash := Motion.bump_scale(hit, 0.12) if hit < Motion.BUMP_TIME else 1.0
	var skin := foot + Vector2(0.0, Parts.skin_y(0, r) * squash)
	# the beat on the skin while the woodpecker knocks; a knock's ring
	if _phase == Phase.LISTEN and _t - _beat_at < 0.25 and not Motion.reduce:
		var a := 1.0 - (_t - _beat_at) / 0.25
		draw_set_transform(skin, 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 40, Color(Parts.LANE_DEEP[0], 0.35 * a), 6.0 * u, true)
		draw_set_transform(Vector2.ZERO)
	if hit < 0.4:
		var a := 1.0 - hit / 0.4
		draw_set_transform(skin, 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, r * (1.25 + 0.25 * (1.0 - a)), Color(Parts.LANE_HI[0], 0.35 * a))
		draw_arc(Vector2.ZERO, r * (1.05 + 0.4 * (1.0 - a)), 0.0, TAU, 48, Color(Parts.CREAM, 0.9 * a), r * 0.08, true)
		draw_set_transform(Vector2.ZERO)
	# waiting on the player's first knock: a soft gold ring calls to it
	if _phase == Phase.PLAY and not _st.started():
		var p := 0.5 if Motion.reduce else 0.5 + 0.5 * sin((_t - _turn_at) * 5.0)
		draw_set_transform(skin, 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 48, Color(OK_RING, 0.4 + 0.4 * p), 8.0 * u, true)
		draw_set_transform(Vector2.ZERO)
	var mood := Parts.Mood.HAPPY
	if _phase == Phase.DONE or hit < 0.3:
		mood = Parts.Mood.JOY
	elif _t - _slip_at < PUZZLED_TIME:
		mood = Parts.Mood.WORRIED
	var shake := Motion.shiver_offset(_t - _slip_at, 6.0 * u) if _t - _slip_at < Motion.SHIVER_TIME * 2.0 else 0.0
	draw_mesh(Parts.band_drum(0, r, mood), null,
		Transform2D(0.0, Vector2(pop / squash, pop * squash), 0.0, foot + Vector2(shake, 0.0)), Color(1, 1, 1, seen))

## What the woodpecker is doing, beside it, and which round of how many
## under the card.
func _draw_say() -> void:
	if is_done() or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var x := _l("say_x")
	var y := _l("say_y")
	if _say != "":
		var text := tr(_say) % _st.run if _say == "BS_RUN" else tr(_say)
		var fs := roundi(SAY_SIZE * u)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var k := Motion.pop_in_scale(_t - _say_at, 0.25).x if _t - _say_at < 0.25 else 1.0
		draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * k)
		var base := Vector2(-tw * 0.5, 0.0)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * u), Color(Pal.SURFACE, 0.9))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
		draw_set_transform(Vector2.ZERO)
		if _sub != "" and not _st.started():
			var sub := tr(_sub)
			var ss := roundi(SUB_SIZE * u)
			var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
			var sp := Vector2(x - sw * 0.5, y + 44.0 * u)
			draw_string_outline(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, roundi(8 * u), Color(Pal.SURFACE, 0.85))
			draw_string(font, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Pal.TEXT_DIM)
	if demo:
		return
	var count := tr("BS_ROUND") % [_st.round_no(), _st.rounds()]
	var cs := roundi(COUNT_SIZE * u)
	var cw := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var cy := _l("count_y")
	# the round and the stars side by side under the card; a slip's why
	# lies over them while it shows
	var ss := 0.95 * u
	var sw := StarLine.width(ss)
	var gap := 24.0 * u
	var x0 := size.x * 0.5 - (cw + gap + sw) * 0.5
	var a := 1.0 - _toast.level(_t)
	if a > 0.0:
		draw_string_outline(font, Vector2(x0, cy), count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(8 * u), Color(Pal.SURFACE, 0.8 * a))
		draw_string(font, Vector2(x0, cy), count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Color(Pal.TEXT_DIM, a))
		_stars.draw(self, Vector2(x0 + cw + gap + StarLine.R * ss, cy - cs * 0.35), ss, _t, a)
	if _toast.showing(_t):
		var tw2 := _l("card_w")
		var fs2 := roundi(30 * u)
		var pad := Vector2(28.0, 18.0) * u
		var tall := _toast.tall(tw2, fs2, pad)
		_toast.draw(self, Vector2(size.x * 0.5, _l("card_y") + _l("card_h") + 18.0 * u + tall * 0.5), tw2, _t, fs2, pad)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(WIN_HOLD, ENCORE_LEAD + _st.bar() * 0.5 + 0.9)

func skill_quality() -> float:
	if _st.order.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🥁 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line := tr("BS_WIN_ALL") if _st.clean >= _st.rounds() else tr("BS_WIN_CLEAN") % [_st.clean, _st.rounds()]
	if _st.best_run >= 2 and _st.clean < _st.rounds():
		line += " " + tr("BS_WIN_RUN") % _st.best_run
	return {"faces": [], "subtitle": tr("BS_WIN") + " " + line}

func completion_record() -> Dictionary:
	return {"history": Array(_st.history)}

## A finished day reopens with the whole rhythm's holes on the card, the
## woodpecker content.
func restore_completed_board() -> void:
	_queue.clear()
	_st.finish(completed_record.get("history", []) as Array)
	_phase = Phase.DONE
	_won_at = _t
	_shown_knocks = _st.knocks.duplicate()
	_marks.clear()
	for s in _shown_knocks:
		_marks.append({"slot": float(s), "grade": 0, "at": -INF})
	_say = ""
	_rate(false)
	queue_redraw()
