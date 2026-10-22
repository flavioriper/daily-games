extends Control

## One page of Market Sums' tutorial, played by the board itself
## (puzzles/market2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that taps its crates and signs. `lesson` and `band` are set
## before it enters the tree:
##
## - MAKE: the answer's first step, crate, sign, crate.
## - SIGNS: a share with a remainder refused (the crates shake), then a
##   take-away made.
## - ORDER: the whole answer played, the order filled (on Insane every
##   crate goes into it).
## - HINT: the bulb makes a step.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/market2d.gd")
const Gen = preload("res://puzzles/market_gen.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { MAKE, SIGNS, ORDER, HINT }

const SEED := 20261022
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.5
const REST := 1.8

var lesson: int = Lesson.MAKE
var band := 0
var _board: Control
var _over: Control
## What the finger does next: [kind, value...]: ["step", a, b, op] (three
## taps found on the stall as it is then), ["crate", s], ["sign", o],
## ["bulb"].
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
	resized.connect(func() -> void: _over.size = size)
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

func _script(st) -> Array:
	var out := []
	match lesson:
		Lesson.MAKE:
			out.append(["step"] + (st.answer[0] as Array).slice(0, 3))
		Lesson.SIGNS:
			var pair := _uneven(st)
			if not pair.is_empty():
				out.append(["crate", pair[0]])
				out.append(["sign", Gen.Op.DIV])
				out.append(["crate", pair[1]])
			# a take-away of the stall's largest and smallest
			out.append(["crate", 5])
			out.append(["sign", Gen.Op.SUB])
			out.append(["crate", 0])
		Lesson.ORDER:
			for s: Array in st.answer:
				out.append(["step"] + s.slice(0, 3))
		_:
			out.append(["bulb"])
	return out

## Two places whose share leaves a remainder, or [].
func _uneven(st) -> Array:
	for i in range(5, -1, -1):
		for j in 6:
			if i != j and st.slots[i] > 0 and st.slots[j] > 0 and st.would(i, j, Gen.Op.DIV) == Gen.UNEVEN:
				return [i, j]
	return []

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
		if not _board.sliding():
			_rest = REST
		return
	if _board.sliding():
		_wait = 0.0
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	var st = _board.state()
	match String(next[0]):
		"step":
			var from: int = st.slots.find(int(next[1]))
			var into := -1
			for i in 6:
				if i != from and st.slots[i] == int(next[2]):
					into = i
					break
			_steps.push_front(["crate", into])
			_steps.push_front(["sign", int(next[3])])
			_steps.push_front(["crate", from])
			_wait = TAP_WAIT
		"crate":
			# the crate a step made is in hand already
			if _board.picked() == int(next[1]):
				_wait = TAP_WAIT
				return
			_finger = _board.crate_to_local(int(next[1]))
			_finger_at = _t
			_board.demo_crate(int(next[1]))
		"sign":
			_finger = _board.sign_to_local(int(next[1]))
			_finger_at = _t
			_board.demo_sign(int(next[1]))
		_:
			_bulb_at = _t
			_board.hints_extra += 1
			_board.hint()
			_wait = -0.6

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
