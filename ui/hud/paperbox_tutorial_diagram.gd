extends Control

## One page of Paper Box's tutorial, played by the board itself
## (puzzles/paperbox2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that picks its boxes. `lesson` and `band` are set before it
## enters the tree:
##
## - FOLD: the right box picked; the net folds into it and goes to the shelf.
## - OPPOSITE: a box showing two sides that never meet is struck, then the
##   right one picked (an Easy deal, whose wrong boxes are all that kind).
## - CORNER: a box whose corner turns the wrong way round is struck, then
##   the right one (a Hard deal).
## - STAMPS: Insane's stamps; a box with a stamp turned is struck.
## - HINT: the bulb strikes a wrong box, then the right one is picked.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/paperbox2d.gd")
const State = preload("res://puzzles/paperbox_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { FOLD, OPPOSITE, CORNER, STAMPS, HINT }

const SEED := 20261024
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## The bulb, among the steps.
const BULB := -1
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.8
const REST := 1.6

var lesson: int = Lesson.FOLD
var band := 0
var _board: Control
var _over: Control
var _steps: Array[int] = []
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
	resized.connect(func() -> void: _over.size = size)
	add_child(_over)
	_deal()

## The band each lesson's deal is from: its wrong boxes are the lesson's kind.
func _band() -> int:
	match lesson:
		Lesson.OPPOSITE:
			return 0
		Lesson.CORNER:
			return 2
		Lesson.STAMPS:
			return 3
		Lesson.FOLD:
			return mini(band, 1)
	return band

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_board)
	if _over != null:
		move_child(_over, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + lesson
	_board.start(rng, _band())
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_steps = _script(_board.state())

## The boxes the finger picks, in order, for this page.
func _script(st) -> Array[int]:
	var r: Dictionary = st.now()
	var answer := int(r.answer)
	var want := -1
	match lesson:
		Lesson.OPPOSITE:
			want = State.Kind.OPPOSITE
		Lesson.CORNER:
			want = State.Kind.FLIPPED
		Lesson.STAMPS:
			want = State.Kind.TURNED
	match lesson:
		Lesson.FOLD:
			return [answer]
		Lesson.HINT:
			return [BULB, answer]
	var wrong := (r.kinds as Array).find(want)
	if wrong < 0:
		wrong = 0 if answer != 0 else 1
	return [wrong, answer]

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
	if _board.phase() != Board.Phase.PLAY:
		_wait = 0.0
		return
	if _steps.is_empty():
		# the point made once the box is on the shelf
		_rest = REST
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var o: int = _steps.pop_front()
	if o == BULB:
		_bulb_at = _t
		_board.hints_extra += 1
		_board.hint()
		_wait = -0.3
		return
	_finger = _board.option_to_local(o)
	_finger_at = _t
	_board.demo_tap(o)
	# a struck box is left to show itself before the next pick
	if _board.phase() == Board.Phase.PLAY:
		_wait = -0.7

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
