extends Control

## One page of Padlock's tutorial, played by the board itself
## (puzzles/padlock2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that turns its dials. `lesson` and `band` are set before it
## enters the tree. The lock is a fixed one from the band's bank, never
## today's, so a page never gives the day's words away.
##
## - TURN: the finger turns the dials one by one until the window spells a
##   word; its letters light.
## - LIGHT: two more words dialled; the finger points at a letter still
##   dark.
## - RUSTY (Insane): the rusty dial turned down, past its last letter and
##   round to its first.
## - HINT: the bulb rings a word's letters, then turns the dials to it.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the lock stands as it is dealt.

const Board = preload("res://puzzles/padlock2d.gd")
const State = preload("res://puzzles/padlock_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { TURN, LIGHT, RUSTY, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 7
const FINGER_R := 24.0
const FINGER_ALPHA := 0.24
const STEP_WAIT := 0.6
const REST := 1.8

var lesson: int = Lesson.TURN
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["turn", dial, letter], ["point", dial,
## letter], ["bulb"], ["rest", seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _finger := Vector2(-1, -1)
var _finger_at := -INF
var _point := Vector2i(-1, -1)
var _bulb_at := -INF
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	_deal()

## The lock the pages show: a fixed entry of the band's bank, never today's.
static func lock(the_band: int) -> Dictionary:
	var bank: String = State.BANKS[the_band]
	var pool := InsaneBank.boards(bank)
	if pool.is_empty():
		return State.SPARE_DAY
	var today := InsaneBank.pick(bank, 0)
	var at := ENTRY % pool.size()
	if pool[at] == today:
		at = (at + 1) % pool.size()
	return pool[at]

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	var b := 3 if lesson == Lesson.RUSTY else band
	_board.demo_day = lock(b)
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	if _over != null:
		move_child(_over, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261104 + lesson
	_board.start(rng, b)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_point = Vector2i(-1, -1)
	_bulb_at = -INF
	_steps = _script(_board.state())

## The finger's turns that dial `w`: one per dial that is not there yet.
static func _turns(st, w: String) -> Array:
	var out := []
	for k in st.length():
		var i: int = st.dials[k].find(w[k])
		if i != st.pos[k]:
			out.append(["turn", k, i])
	return out

func _script(st) -> Array:
	var out := []
	match lesson:
		Lesson.TURN:
			var w: String = st.hint_word()
			out.append_array(_turns(st, w))
			out.append(["rest", 1.2])
		Lesson.LIGHT:
			# two words in a row, then a dark letter pointed at
			var sim = State.new()
			sim.band = st.band
			sim.load_day(_board.demo_day)
			for n in 2:
				var w: String = sim.hint_word()
				if w == "":
					break
				out.append_array(_turns(sim, w))
				sim.dial_to(w)
				sim.read()
				out.append(["rest", 0.6])
			for k in sim.length():
				for i in sim.dials[k].length():
					if not sim.is_lit(k, i) and out[-1][0] != "point":
						out.append(["point", k, i])
			out.append(["rest", 1.2])
		Lesson.RUSTY:
			var k: int = st.rusty
			var n: int = st.dials[k].length()
			for i in range(st.pos[k] + 1, n):
				out.append(["turn", k, i])
			out.append(["round", k])
			out.append(["rest", 1.4])
		_:
			out.append(["bulb"])
			out.append(["rest", 1.4])
			out.append(["bulb"])
			out.append(["rest", 1.4])
	return out

func _process(delta: float) -> void:
	if Motion.reduce:
		return
	_t += delta
	_over.queue_redraw()
	if _rest >= 0.0:
		_rest -= delta
		if _rest < 0.0:
			_deal()
		return
	if _steps.is_empty():
		if not _board.busy():
			_rest = REST
		return
	_wait += delta
	if _wait < STEP_WAIT:
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	match String(next[0]):
		"turn":
			_point = Vector2i(-1, -1)
			_finger = _board.cell_to_local(int(next[1]), int(next[2]))
			_finger_at = _t
			_board.demo_turn(int(next[1]), int(next[2]))
		"round":
			var k := int(next[1])
			_finger = _board.cell_to_local(k, _board.state().pos[k])
			_finger_at = _t
			_board.state().turn(k, 0)
			_board.demo_turn(k, 0)
		"point":
			_point = Vector2i(int(next[1]), int(next[2]))
			_finger = _board.cell_to_local(_point.x, _point.y)
			_finger_at = _t
		"rest":
			_wait = -float(next[1])
		_:
			_point = Vector2i(-1, -1)
			_bulb_at = _t
			_board.demo_hint()

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.45:
		var a := FINGER_ALPHA * (1.0 - e / 0.45)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e * 0.6), Color(Pal.TEXT, a))
	if _point.x >= 0:
		var c: Vector2 = _board.cell_to_local(_point.x, _point.y)
		var pulse := 0.6 + 0.4 * sin(_t * 6.0)
		var r := float((_board.get("_L") as Dictionary).get("cell", 80.0)) * 0.6
		_over.draw_arc(c, r, 0.0, TAU, 40, Color(Pal.SUN, pulse), 5.0, true)
	if lesson == Lesson.HINT and _t - _bulb_at < 1.5 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
