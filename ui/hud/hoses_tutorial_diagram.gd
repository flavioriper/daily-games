extends Control

## One page of Hosepipes' tutorial, played by the board itself
## (puzzles/hoses2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that drags its hoses. `lesson` and `band` are set before it
## enters the tree:
##
## - JOIN: one hose drawn from its tap to its flower, which opens.
## - WATER: every hose drawn, every square watered.
## - CUT: a hose drawn, another dragged across it (it is cut) and back off
##   it (it grows back), then laid its own way.
## - SEEDS: on an Insane bed, a seed hose drawn to a seed, which blooms.
## - HINT: the bulb lays a hose.
##
## Easy beds but SEEDS (a fixed Insane bed from the bank, never today's). A page plays until its
## point is made, waits a moment and starts over. Under reduce motion the
## bed stands as it is dealt.

const Board = preload("res://puzzles/hoses2d.gd")
const Gen = preload("res://puzzles/hoses_gen.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { JOIN, WATER, CUT, SEEDS, HINT }

const SEED := 20261022
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before it presses, a square's step, and the
## page's rest at the end.
const PRESS_WAIT := 0.5
const STEP_WAIT := 0.12
const REST := 1.8

var lesson: int = Lesson.JOIN
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["press", cell], ["move", cell], ["release"],
## ["bulb"], ["wait", seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _bulb_at := -INF
var _finger := Vector2(-1, -1)
var _down := false
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
	_board.start(rng, 0)
	if lesson == Lesson.SEEDS:
		# a fixed bed from the Insane bank, never today's (that would spoil it)
		var pool := InsaneBank.boards("hoses")
		var day: Dictionary = Gen.from_bank(pool[SEED % pool.size()]) if not pool.is_empty() else {}
		if day.is_empty():
			day = Gen.deal(rng, 3)
		_board.demo_day(day, 3)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_bulb_at = -INF
	_down = false
	_steps = _script(_board.state())

## A hose drawn along `path`: pressed on its first square, moved through
## the rest, lifted.
func _draw_path(out: Array, path: Array) -> void:
	out.append(["press", int(path[0])])
	for i in range(1, path.size()):
		out.append(["move", int(path[i])])
	out.append(["release"])

func _script(st) -> Array:
	var out := []
	var order := range(st.count())
	# the shortest hoses first: the point is made sooner
	order.sort_custom(func(a, b): return (st.answer[a] as Array).size() < (st.answer[b] as Array).size())
	match lesson:
		Lesson.JOIN:
			_draw_path(out, st.answer[order[0]])
		Lesson.WATER:
			for c in order:
				_draw_path(out, st.answer[c])
		Lesson.CUT:
			var a: int = order[order.size() - 1]
			var path_a: Array = st.answer[a]
			_draw_path(out, path_a)
			# another tap with a straight run of bare soil into the first hose
			var run := run_into(st, a)
			if not run.is_empty():
				var b: int = st.end_of(int(run[0]))
				out.append(["press", int(run[0])])
				for i in range(1, run.size()):
					out.append(["move", int(run[i])])
				out.append(["wait", 0.6])
				for i in range(run.size() - 2, -1, -1):
					out.append(["move", int(run[i])])
				out.append(["release"])
				out.append(["wait", 0.3])
				_draw_path(out, st.answer[b])
		Lesson.SEEDS:
			for c in order:
				if st.seeded(c):
					_draw_path(out, st.answer[c])
					break
		_:
			out.append(["bulb"])
	return out

## From another hose's tap, a straight run over bare soil ending on a
## middle square of hose `a`'s answer: [tap, ..., that square], or [].
static func run_into(st, a: int) -> Array:
	var path: Array = st.answer[a]
	var inside := {}
	for i in range(1, path.size() - 1):
		inside[int(path[i])] = true
	var n: int = st.n
	for c in st.count():
		if c == a:
			continue
		var tap := int((st.ends[c] as Array)[0])
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var run := [tap]
			var x := tap % n
			var y := tap / n
			while true:
				x += d.x
				y += d.y
				if x < 0 or y < 0 or x >= n or y >= n:
					break
				var v := y * n + x
				if inside.has(v):
					run.append(v)
					return run
				if st.end_of(v) >= 0 or st.is_seed(v) or path.has(v):
					break
				run.append(v)
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
		if not _board.laying():
			_rest = REST
		return
	_wait += delta
	var next: Array = _steps[0]
	var kind := String(next[0])
	var need := PRESS_WAIT if kind == "press" or kind == "bulb" else STEP_WAIT
	if kind == "wait":
		need = float(next[1])
	if _wait < need:
		return
	_wait = 0.0
	_steps.pop_front()
	match kind:
		"press":
			_finger = _board.cell_to_local(int(next[1]))
			_down = true
			_board.demo_press(int(next[1]))
		"move":
			_finger = _board.cell_to_local(int(next[1]))
			_board.demo_move(int(next[1]))
		"release":
			_down = false
			_board.demo_release()
		"bulb":
			_bulb_at = _t
			_board.hints_extra += 1
			_board.hint()
			_wait = -0.6

func _draw_over() -> void:
	if _down:
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R, Color(Pal.TEXT, FINGER_ALPHA))
	if lesson == Lesson.HINT and _t - _bulb_at < 2.0 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
