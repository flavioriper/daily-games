extends Control

## One page of Who Ate the Pie?'s tutorial, played by the board itself
## (puzzles/pie2d.gd built with `demo`: silent, deaf, laid in this rect) and
## a finger that picks bakers and presses the verdict buttons. `lesson` and
## `band` are set before it enters the tree:
##
## - MARK: a baker the clues prove is picked and marked; the card turns.
## - CLUES: the opening baker is picked (the bakers their clue speaks of
##   ring), then a proven baker is marked and speaks.
## - PROOF: a baker nothing proves yet is marked: the card shivers and the
##   bubble says why; then a proven one is marked.
## - DISH: proven bakers are marked until one who ate is caught, and a
##   slice of the pie turns to crumbs.
## - HINT: the bulb lights the clues that prove a baker, then marks them.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/pie2d.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { MARK, CLUES, PROOF, DISH, HINT }
## What the finger does next: pick a proven baker, mark them right, pick
## the opening baker, pick a baker nothing proves, mark them "didn't",
## press the bulb, pick-and-mark until one who ate is caught.
enum Step { PICK_PROVEN, MARK_RIGHT, PICK_START, PICK_OPEN, MARK_NOT, BULB, CATCH }

const SEED := 20261024
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.75
const REST := 1.8

var lesson: int = Lesson.MARK
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
var _caught := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	add_child(_over)
	_deal()

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
	# the tutorial's table is always Easy's: nine bakers read at a glance
	_board.start(rng, 0)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_caught = 0
	match lesson:
		Lesson.MARK:
			_steps = [Step.PICK_PROVEN, Step.MARK_RIGHT, Step.PICK_PROVEN, Step.MARK_RIGHT]
		Lesson.CLUES:
			_steps = [Step.PICK_START, Step.PICK_PROVEN, Step.MARK_RIGHT]
		Lesson.PROOF:
			_steps = [Step.PICK_OPEN, Step.MARK_NOT, Step.PICK_PROVEN, Step.MARK_RIGHT]
		Lesson.DISH:
			_steps = [Step.CATCH]
		_:
			_steps = [Step.BULB, Step.BULB]

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
	if _steps.is_empty() or _board.phase() != Board.Phase.PLAY:
		if _rest < 0.0:
			_rest = REST + 0.8
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var st = _board.state()
	var step: int = _steps[0]
	match step:
		Step.PICK_PROVEN:
			_steps.pop_front()
			_pick(st.hint_baker(-1))
		Step.MARK_RIGHT:
			_steps.pop_front()
			_mark(st.did_eat(_board.picked()))
		Step.PICK_START:
			_steps.pop_front()
			_pick(st.start)
		Step.PICK_OPEN:
			_steps.pop_front()
			for i in st.count():
				if not st.is_marked(i) and not st.proven(i):
					_pick(i)
					break
		Step.MARK_NOT:
			_steps.pop_front()
			_mark(false)
		Step.BULB:
			_steps.pop_front()
			_bulb_at = _t
			# the lit clues are read a while before the second press
			_wait = -1.6
			_board.hints_extra += 1
			_board.hint()
		Step.CATCH:
			# pick a proven eater when there is one, else any proven baker
			if _board.picked() >= 0 and not st.is_marked(_board.picked()) and st.proven(_board.picked()):
				var eat: bool = st.did_eat(_board.picked())
				_mark(eat)
				if eat:
					_steps.pop_front()
				return
			var pick: int = st.hint_baker(-1)
			for i in st.count():
				if st.proven(i) and st.did_eat(i):
					pick = i
					break
			_pick(pick)

func _pick(i: int) -> void:
	if i < 0:
		return
	_finger = _board.card_to_local(i)
	_finger_at = _t
	_board.demo_select(i)

func _mark(eat: bool) -> void:
	_finger = _board.button_to_local(eat)
	_finger_at = _t
	_board.demo_mark(eat)

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
