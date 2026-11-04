extends Control

## One page of Cross Stitch's tutorial, played by the board itself
## (puzzles/crossstitch2d.gd built with `demo`: silent, deaf, laid in this
## rect) and a finger that drags its patches. `lesson` and `band` are set
## before it enters the tree. The sampler is a fixed one from the band's
## bank, never today's, so a page never gives the day's words away.
##
## - SWAP: a letter dragged onto another; both land in their places.
## - THREAD: the finger points at a stitched patch, one on the right thread
##   and a stray, then swaps the amber one home.
## - LOOSE (Insane): the same sampler with no amber, a swap made.
## - WORD: the last swaps of a sampler, words sewn round in gold.
## - HINT: the bulb rings two letters, then swaps them.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/crossstitch2d.gd")
const State = preload("res://puzzles/crossstitch_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { SWAP, THREAD, LOOSE, WORD, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 7
const FINGER_R := 26.0
const FINGER_ALPHA := 0.24
## The finger's glide while dragging, its wait between steps, the rest.
const GLIDE := 0.5
const STEP_WAIT := 0.55
const REST := 1.8
## WORD: how many swaps are left for the finger to make.
const LAST := 3

var lesson: int = Lesson.SWAP
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["drag", a, b], ["point", i], ["bulb"],
## ["rest", seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _glide := {}
var _bulb_at := -INF
var _finger := Vector2(-1, -1)
var _finger_at := -INF
var _point := -1
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

## The sampler the pages show: a fixed entry of the band's bank, never today's.
static func sampler(the_band: int) -> Dictionary:
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
	var b := band
	if lesson == Lesson.LOOSE:
		b = 3
	elif lesson == Lesson.THREAD and band == 3:
		b = 2
	_board.demo_day = sampler(b)
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
	_glide = {}
	_point = -1
	_bulb_at = -INF
	_steps = _script(_board.state())

func _script(st) -> Array:
	var out := []
	match lesson:
		Lesson.SWAP:
			var h: Vector2i = st.hint_swap()
			out.append(["drag", h.x, h.y])
			out.append(["rest", 1.0])
		Lesson.THREAD, Lesson.LOOSE:
			for m in ([State.Mark.STITCHED, State.Mark.NEAR, State.Mark.STRAY] if lesson == Lesson.THREAD else [State.Mark.STITCHED, State.Mark.STRAY]):
				var i: int = st.marks.find(m)
				if i >= 0:
					out.append(["point", i])
					out.append(["rest", 0.5])
			var h: Vector2i = st.hint_swap()
			out.append(["drag", h.x, h.y])
			out.append(["rest", 1.0])
		Lesson.WORD:
			# the sampler stitched quietly but for its last few swaps
			while st.to_go > LAST:
				var h: Vector2i = st.hint_swap()
				st.swap(h.x, h.y, true)
			_board._fresh()
			for k in LAST:
				out.append(["next"])
			out.append(["rest", 1.6])
		_:
			out.append(["bulb"])
			out.append(["rest", 1.3])
			out.append(["bulb"])
			out.append(["rest", 1.2])
	return out

func _process(delta: float) -> void:
	if Motion.reduce:
		return
	_t += delta
	_over.queue_redraw()
	if not _glide.is_empty():
		var e := (_t - float(_glide.at)) / GLIDE
		var k := clampf(e, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_finger = _board.tile_to_local(int(_glide.a)).lerp(_board.tile_to_local(int(_glide.b)), k)
		_finger_at = _t
		_board.demo_drag(int(_glide.a), _finger)
		if e >= 1.0:
			_board.demo_swap(int(_glide.a), int(_glide.b))
			_glide = {}
		return
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
		"drag":
			_point = -1
			_glide = {"a": int(next[1]), "b": int(next[2]), "at": _t + 0.15}
			_finger = _board.tile_to_local(int(next[1]))
			_finger_at = _t
		"next":
			var h: Vector2i = _board.state().hint_swap()
			if h.x >= 0:
				_glide = {"a": h.x, "b": h.y, "at": _t + 0.15}
				_finger = _board.tile_to_local(h.x)
				_finger_at = _t
		"point":
			_point = int(next[1])
			_finger = _board.tile_to_local(_point)
			_finger_at = _t
		"rest":
			_wait = -float(next[1])
		_:
			_point = -1
			_bulb_at = _t
			_board.demo_hint()

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.45:
		var a := FINGER_ALPHA * (1.0 - e / 0.45)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e * 0.6), Color(Pal.TEXT, a))
	if _point >= 0:
		var c: Vector2 = _board.tile_to_local(_point)
		var pulse := 0.6 + 0.4 * sin(_t * 6.0)
		var r := float((_board.get("_L") as Dictionary).get("tile", 100.0)) * 0.62
		_over.draw_arc(c, r, 0.0, TAU, 40, Color(Pal.SUN, pulse), 5.0, true)
	if lesson == Lesson.HINT and _t - _bulb_at < 1.5 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
