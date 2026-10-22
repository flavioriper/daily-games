extends Control

## One page of Teacups' tutorial, played by the board itself
## (puzzles/teacups2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that lifts its cups. `lesson` and `band` are set before it
## enters the tree:
##
## - LIFT: two cups lifted, two different friends, both covered again.
## - PAIR: a cup and its partner lifted: the cups fly off.
## - REMEMBER: a miss shows a friend; the next cup lifted is its partner,
##   and the finger goes back to where the friend was seen.
## - WALTZ: Insane's two misses, and two hidden cups trade places.
## - HINT: a cup lifted, the bulb, its partner peeks out and is lifted.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/teacups2d.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { LIFT, PAIR, REMEMBER, WALTZ, HINT }

const SEED := 20261023
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## The bulb, among the steps.
const BULB := -1
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.55
const REST := 1.8

var lesson: int = Lesson.LIFT
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
	_board.start(rng, band)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_steps = _script(_board.state())

## The places the finger taps, in order, for this page.
func _script(st) -> Array[int]:
	var a := 0
	var pa: int = st.partner(a)
	# a cup that is neither the first nor its partner
	var b := 1 if pa != 1 else 2
	var pb: int = st.partner(b)
	match lesson:
		Lesson.LIFT:
			return [st.slot[a], st.slot[b]]
		Lesson.PAIR:
			return [st.slot[a], st.slot[pa]]
		Lesson.REMEMBER:
			# b is seen on the miss; its partner, lifted next, sends the
			# finger back to it
			return [st.slot[a], st.slot[b], st.slot[pb], st.slot[b]]
		Lesson.WALTZ:
			var c := b + 1
			while c == pa or c == pb or st.partner(c) == a or st.partner(c) == b:
				c += 1
			var pc: int = st.partner(c)
			var d := 0
			while d == a or d == pa or d == c or d == pc or st.kind[d] == st.kind[b]:
				d += 1
			return [st.slot[a], st.slot[b], st.slot[c], st.slot[d]]
		_:
			return [st.slot[a], BULB, st.slot[pa]]

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
	var st = _board.state()
	if _steps.is_empty():
		# the page's point made once the board is still again
		if _board.phase() == Board.Phase.PLAY and _settled(st):
			_rest = REST
		return
	if _board.phase() != Board.Phase.PLAY and _board.phase() != Board.Phase.HOLD:
		_wait = 0.0
		return
	# a miss is left to show itself before the next tap
	if _board.phase() == Board.Phase.HOLD:
		_wait = 0.0
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var s: int = _steps.pop_front()
	if s == BULB:
		_bulb_at = _t
		_board.hints_extra += 1
		_board.hint()
		_wait = -0.6
		return
	# the next place's cup, wherever a waltz has moved it
	_finger = _board.slot_to_local(s)
	_finger_at = _t
	_board.demo_tap(s)

## Nothing up but found cups and a cup in hand.
func _settled(st) -> bool:
	for c in st.cups():
		if _board._up[c] and not st.found[c] and c != st.first:
			return false
	return _board._queue.is_empty()

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
