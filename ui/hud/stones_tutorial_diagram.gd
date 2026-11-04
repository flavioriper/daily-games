extends Control

## One page of Stepping Stones' tutorial, played by the board itself
## (puzzles/stones2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a hand that types its stones letter by letter. `lesson` and `band`
## are set before it enters the tree. The crossing is a fixed one from the
## band's bank, never today's, so a page never gives the day's way away.
##
## - STEP: the first stone typed; it drops in under the near bank.
## - CROSS: every stone of a shortest way typed, and the crossing made.
## - GIVEN (Easy): a stone typed one letter from the mossy stone, which
##   steps into the way.
## - SLIP (Insane): the way typed up to and through a swap.
## - HINT: the bulb rings the letter to change, then lays the stone.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the crossing stands as it is dealt.

const Board = preload("res://puzzles/stones2d.gd")
const State = preload("res://puzzles/stones_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { STEP, CROSS, GIVEN, SLIP, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 11
const KEY_WAIT := 0.16
const STEP_WAIT := 0.7
const REST := 1.8

var lesson: int = Lesson.STEP
var band := 0
var _board: Control
var _over: Control
## What the hand does next: ["key", letter], ["enter"], ["bulb"], ["rest",
## seconds].
var _steps: Array = []
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
	add_child(_over)
	_deal()

## The crossing the pages show: a fixed entry of the band's bank, never
## today's; on the Slippery page, the first from there whose way swaps.
static func crossing(the_band: int, swap := false) -> Dictionary:
	var bank: String = State.BANKS[the_band]
	var pool := InsaneBank.boards(bank)
	if pool.is_empty():
		return State.SPARE_DAY
	var today := InsaneBank.pick(bank, 0)
	for step in pool.size():
		var at := (ENTRY + step) % pool.size()
		var day: Dictionary = pool[at]
		if day == today:
			continue
		if swap and _swap_at(day) < 0:
			continue
		return day
	return pool[ENTRY % pool.size()]

## The first stone of `day`'s route reached by a swap, or -1.
static func _swap_at(day: Dictionary) -> int:
	var prev := String(day.get("from", ""))
	var route: Array = day.get("route", [])
	for i in route.size():
		if State.is_swap(prev, String(route[i])):
			return i
		prev = String(route[i])
	return -1

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	var b := band
	if lesson == Lesson.GIVEN:
		b = 0
	elif lesson == Lesson.SLIP:
		b = 3
	_board.demo_day = crossing(b, lesson == Lesson.SLIP)
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
	_steps = _script(_board.demo_day)

func _typing(word: String) -> Array:
	var out := []
	for c in word.to_upper():
		out.append(["key", c])
	out.append(["rest", STEP_WAIT])
	return out

func _script(day: Dictionary) -> Array:
	var out := []
	var route: Array = day.get("route", [])
	match lesson:
		Lesson.STEP:
			if not route.is_empty():
				out.append_array(_typing(String(route[0])))
			out.append(["rest", 1.0])
		Lesson.CROSS:
			for w in route:
				out.append_array(_typing(String(w)))
			out.append(["rest", 1.6])
		Lesson.GIVEN:
			if not route.is_empty():
				out.append_array(_typing(String(route[0])))
			out.append(["rest", 1.4])
		Lesson.SLIP:
			var upto := _swap_at(day)
			for i in maxi(0, upto) + 1:
				if i < route.size():
					out.append_array(_typing(String(route[i])))
			out.append(["rest", 1.4])
		_:
			out.append(["bulb"])
			out.append(["rest", 1.6])
			out.append(["bulb"])
			out.append(["rest", 1.6])
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
	if _wait < KEY_WAIT:
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	match String(next[0]):
		"key":
			_board.type_letter(String(next[1]))
		"rest":
			_wait = -float(next[1])
		_:
			_bulb_at = _t
			_board.demo_hint()

func _draw_over() -> void:
	if lesson == Lesson.HINT and _t - _bulb_at < 1.5 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
