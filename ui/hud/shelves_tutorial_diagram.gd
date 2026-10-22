extends Control

## One page of Four Shelves' tutorial, played by the board itself
## (puzzles/shelves2d.gd built with `demo`: silent, deaf, laid in this rect,
## dealt the bank's first puzzle of the lesson's band) and a finger that
## taps its jars and keys. `lesson` and `band` are set before it enters the
## tree:
##
## - PICK: four jars of one shelf picked and shelved: the shelf goes up.
## - CLOSE: three of one shelf and one of another: a heart goes, the line
##   says three belong together; then the right four.
## - CROWDED: Insane's five shelves; one goes up.
## - HINT: the bulb picks a word, the finger the rest of its shelf.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/shelves2d.gd")
const State = preload("res://puzzles/shelves_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { PICK, CLOSE, CROWDED, HINT }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## A step: a word to tap, or one of these.
const BULB := "#bulb"
const SHELVE := "#shelve"
const TAP_WAIT := 0.42
const REST := 1.8

var lesson: int = Lesson.PICK
var band := 0
var _board: Control
var _over: Control
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _bulb_at := -INF
var _finger := Vector2(-1, -1)
var _finger_at := -INF
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

func _band() -> int:
	return 3 if lesson == Lesson.CROWDED else 0

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	var tiers := State.tiers()
	var b := _band()
	if tiers.size() <= b or (tiers[b] as Array).is_empty():
		return
	_board = Board.new()
	_board.demo = true
	_board.demo_puzzle = tiers[b][0]
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	if _over != null:
		move_child(_over, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025 + lesson
	_board.start(rng, b)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_steps = _script(_board.state())

func _script(st) -> Array:
	var g0: Array = st.groups[0].words
	var g1: Array = st.groups[1].words
	match lesson:
		Lesson.CLOSE:
			return [g1[0], g1[1], g1[2], g0[0], SHELVE, g0[0], g1[3], SHELVE]
		Lesson.HINT:
			return [BULB, g0[1], g0[2], g0[3], SHELVE]
	return [g0[0], g0[1], g0[2], g0[3], SHELVE]

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
	if _steps.is_empty():
		if not _board.busy():
			_rest = REST
		return
	if _board.busy():
		_wait = 0.0
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var s: String = _steps.pop_front()
	if s == BULB:
		_bulb_at = _t
		_board.hints_extra += 1
		_board.hint()
		_wait = -0.5
		return
	if s == SHELVE:
		_finger = _board.key_to_local(Board.Key.ENTER)
		_finger_at = _t
		_board.demo_key(Board.Key.ENTER)
		_wait = -0.9
		return
	_finger = _board.word_to_local(s)
	_finger_at = _t
	_board.demo_tap_word(s)

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
