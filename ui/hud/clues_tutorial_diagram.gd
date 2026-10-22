extends Control

## One page of Five Clues' tutorial, played by the board itself
## (puzzles/clues2d.gd built with `demo`: silent, deaf, laid in this rect,
## dealt the bank's first round of the lesson's tier) and a hand that types
## on it a letter at a time. `lesson` and `band` are set before it enters
## the tree:
##
## - GUESS: two cards turned with an empty Enter, then the idea typed: it is
##   chalked on the slate.
## - WRONG: a wrong idea typed: the next card turns; then the right one.
## - TURN: Enter on an empty line turns a card, no guess spent.
## - TRIES: Insane's three wrong lines and the round is lost.
## - HINT: the bulb shows the idea's first letter, then it is typed.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/clues2d.gd")
const State = preload("res://puzzles/clues_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { GUESS, WRONG, TURN, TRIES, HINT }

const FINGER_R := 26.0
const BULB := "#bulb"
const ENTER := "#enter"
const STEP_WAIT := 0.9
const LETTER_WAIT := 0.09
const REST := 2.0

var lesson: int = Lesson.GUESS
var band := 0
var _board: Control
var _over: Control
var _steps: Array = []
var _typing := ""
var _wait := 0.0
var _rest := -1.0
var _bulb_at := -INF
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	resized.connect(func() -> void: _over.size = size)
	add_child(_over)
	_deal()

func _band() -> int:
	return 3 if lesson == Lesson.TRIES else 0

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	var b := _band()
	var tiers := State.tiers()
	var t: int = State.TIER[b]
	if tiers.size() <= t or (tiers[t] as Array).is_empty():
		return
	_board = Board.new()
	_board.demo = true
	_board.demo_rounds = [tiers[t][0]]
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	if _over != null:
		move_child(_over, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026 + lesson
	_board.start(rng, b)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_typing = ""
	_bulb_at = -INF
	_steps = _script(_board.state())

## What the hand does, in order: a line to type and Enter, an empty Enter,
## or the bulb.
func _script(st) -> Array:
	var r: Dictionary = st.round_now()
	var right: String = State.norm(String(r.accept[0]))
	var wrong := "PEBBLE" if not State.accepts(r.accept, "pebble") else "CLOUD"
	match lesson:
		Lesson.WRONG:
			return [wrong, ENTER, right]
		Lesson.TURN:
			return [ENTER, ENTER, ENTER]
		Lesson.TRIES:
			return [wrong, "CLOUD" if wrong != "CLOUD" else "RIVER", "TEAPOT"]
		Lesson.HINT:
			return [BULB, right]
	return [ENTER, ENTER, right]

func _process(delta: float) -> void:
	if Motion.reduce or _board == null:
		return
	_t += delta
	_over.queue_redraw()
	if _rest >= 0.0:
		_rest -= delta
		if _rest < 0.0:
			_deal()
		return
	_wait += delta
	if _typing != "":
		if _wait >= LETTER_WAIT:
			_wait = 0.0
			_board.type_letter(_typing.substr(0, 1))
			_typing = _typing.substr(1)
			if _typing == "":
				_wait = -0.35
				_steps.push_front(ENTER)
		return
	if _wait < STEP_WAIT:
		return
	_wait = 0.0
	if _steps.is_empty() or _board.phase() != Board.Phase.PLAY:
		_rest = REST
		return
	var s: String = _steps.pop_front()
	if s == BULB:
		_bulb_at = _t
		_board.hints_extra += 1
		_board.hint()
	elif s == ENTER:
		_board.commit_row()
	else:
		_typing = s.to_upper()

func _draw_over() -> void:
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
