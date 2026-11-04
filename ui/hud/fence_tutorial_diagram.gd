extends Control

## One page of Garden Fence's tutorial, played by the board itself
## (puzzles/fence2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a fingertip that taps its posts. `lesson` and `band` are set before
## it enters the tree. The fence is a fixed one from the band's bank, never
## today's, so a page never gives the day's words away.
##
## - STRING: the first word of a fewest way strung post by post and tied
##   with a tap on its last post.
## - CHAIN: the first word tied already; the finger tries a post from the
##   side it is on (it shivers), then strings the next word from the post
##   the first ended on.
## - BLOOM: the whole way strung, every post in bloom.
## - GATE (Insane): the whole way, ending on the gate.
## - HINT: the bulb rings the next word's posts, then strings and ties it.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the fence stands as it is dealt.

const Board = preload("res://puzzles/fence2d.gd")
const State = preload("res://puzzles/fence_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { STRING, CHAIN, BLOOM, GATE, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 9
const TAP_WAIT := 0.36
const WORD_WAIT := 0.8
const REST := 1.8
const TAP_TIME := 0.3

var lesson: int = Lesson.STRING
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["tap", post], ["tie"], ["bulb"], ["rest",
## seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _bulb_at := -INF
var _tap_at := -INF
var _tap_post := -1
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

## The fence the pages show: a fixed entry of the band's bank, never
## today's.
static func fence(the_band: int) -> Dictionary:
	var bank: String = State.BANKS[the_band]
	var pool := InsaneBank.boards(bank)
	if pool.is_empty():
		return State.SPARE_DAY
	var today := InsaneBank.pick(bank, 0)
	for step in pool.size():
		var day: Dictionary = pool[(ENTRY + step) % pool.size()]
		if day != today:
			return day
	return pool[ENTRY % pool.size()]

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	var b := 3 if lesson == Lesson.GATE else band
	_board.demo_day = fence(b)
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
	_bulb_at = -INF
	_tap_at = -INF
	var route: Array = _board.demo_day.get("route", [])
	if lesson == Lesson.CHAIN and not route.is_empty():
		var st = _board.state()
		st.string_word(String(route[0]))
		_board.demo_tie()
	_steps = _script(route)

func _word(w: String, joint: bool) -> Array:
	var out := []
	var st = _board.state()
	for k in w.length():
		if k == 0 and joint:
			continue
		out.append(["tap", st.post_of(w[k])])
	# the last post tapped again ties it
	out.append(["tap", st.post_of(w[w.length() - 1])])
	out.append(["rest", WORD_WAIT])
	return out

func _script(route: Array) -> Array:
	var out := []
	var st = _board.state()
	match lesson:
		Lesson.STRING:
			if not route.is_empty():
				out.append_array(_word(String(route[0]), false))
			out.append(["rest", 1.0])
		Lesson.CHAIN:
			if route.size() >= 2:
				var j: int = st.post_of(String(route[0]).right(1))
				# a post from the joint's own side: refused
				var same := -1
				for p in st.posts.size():
					if p != j and st.side_of(p) == st.side_of(j):
						same = p
						break
				if same >= 0:
					out.append(["tap", same])
					out.append(["rest", 0.6])
				out.append_array(_word(String(route[1]), true))
			out.append(["rest", 1.2])
		Lesson.BLOOM, Lesson.GATE:
			for k in route.size():
				out.append_array(_word(String(route[k]), k > 0))
			out.append(["rest", 1.6])
		_:
			out.append(["bulb"])
			out.append(["rest", 1.6])
			out.append(["bulb"])
			out.append(["rest", 2.4])
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
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	match String(next[0]):
		"tap":
			_tap_post = int(next[1])
			_tap_at = _t
			_board.demo_tap(_tap_post)
		"rest":
			_wait = -float(next[1])
		_:
			_bulb_at = _t
			_board.demo_hint()

func _draw_over() -> void:
	if _rest >= 0.0:
		return
	if _t - _tap_at < TAP_TIME and _tap_post >= 0:
		var e := (_t - _tap_at) / TAP_TIME
		var c: Vector2 = _board.post_to_local(_tap_post) + Vector2(18.0, 22.0)
		_over.draw_circle(c, 20.0 - 4.0 * e, Color(1, 1, 1, 0.75 * (1.0 - e * 0.5)))
		_over.draw_arc(c, 26.0 + 10.0 * e, 0.0, TAU, 32, Color(1, 1, 1, 0.6 * (1.0 - e)), 3.0, true)
	if lesson == Lesson.HINT and _t - _bulb_at < 1.5:
		var c2 := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c2, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c2, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
