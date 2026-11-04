extends Control

## One page of Biscuit Tin's tutorial, played by the board itself
## (puzzles/biscuit2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that taps its pieces. `lesson` and `band` are set before it
## enters the tree. The tin is a fixed one from the band's bank, never
## today's, so a page never gives the day's words away.
##
## - WORD: the finger lays two pieces that spell a short word; it is found.
## - BISCUIT: the finger lays a biscuit's four pieces; it knits whole and
##   flies to the lid.
## - CRUMBS (Insane): the four crumbs are pointed at, one by one.
## - HINT: the bulb rings a biscuit's first piece, then lays it whole.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the tin stands as it is dealt.

const Board = preload("res://puzzles/biscuit2d.gd")
const State = preload("res://puzzles/biscuit_state.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { WORD, BISCUIT, CRUMBS, HINT }

## The bank entry the pages show (today's is skipped for the next).
const ENTRY := 5
const FINGER_R := 24.0
const FINGER_ALPHA := 0.24
const STEP_WAIT := 0.55
const REST := 1.8

var lesson: int = Lesson.WORD
var band := 0
var _board: Control
var _over: Control
## What the finger does next: ["tap", piece], ["point", piece], ["bulb"],
## ["rest", seconds].
var _steps: Array = []
var _wait := 0.0
var _rest := -1.0
var _finger := Vector2(-1, -1)
var _finger_at := -INF
var _point := -1
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

## The tin the pages show: a fixed entry of the band's bank, never today's,
## and one whose pieces make a short word for the first page (the next
## entry that does, should it not).
static func tin(the_band: int) -> Dictionary:
	var bank: String = State.BANKS[the_band]
	var pool := InsaneBank.boards(bank)
	if pool.is_empty():
		return State.SPARE_DAY
	var today := InsaneBank.pick(bank, 0)
	for step in mini(pool.size(), 40):
		var at := (ENTRY + step) % pool.size()
		if pool[at] == today:
			continue
		var st = State.new()
		st.load_day(pool[at])
		if not short_word(st).is_empty():
			return pool[at]
	return pool[ENTRY % pool.size()]

func _deal() -> void:
	if _board != null:
		_board.queue_free()
	_board = Board.new()
	_board.demo = true
	var b := 3 if lesson == Lesson.CRUMBS else band
	_board.demo_day = tin(b)
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
	_point = -1
	_bulb_at = -INF
	_steps = _script(_board.state())

## Two pieces that spell a word the tin takes and no biscuit: the shortest
## lesson there is. Three pieces when no two will do.
static func short_word(st) -> Array:
	for n in [2, 3]:
		for a in st.pieces.size():
			for b in st.pieces.size():
				if b == a:
					continue
				var w: String = st.pieces[a] + st.pieces[b]
				if n == 2:
					if st.knows(w) and st.biscuit_of(w) < 0:
						return [a, b]
					continue
				for c in st.pieces.size():
					if c == a or c == b:
						continue
					var w3: String = w + st.pieces[c]
					if st.knows(w3) and st.biscuit_of(w3) < 0:
						return [a, b, c]
	return []

func _script(st) -> Array:
	var out := []
	match lesson:
		Lesson.WORD:
			for i in short_word(st):
				out.append(["tap", i])
			out.append(["rest", 1.6])
		Lesson.BISCUIT:
			for i in st.biscuits[0]:
				out.append(["tap", int(i)])
			out.append(["rest", 1.8])
		Lesson.CRUMBS:
			for i in st.crumbs:
				out.append(["point", i])
				out.append(["rest", 0.5])
			out.append(["rest", 1.0])
		_:
			out.append(["bulb"])
			out.append(["rest", 1.4])
			out.append(["bulb"])
			out.append(["rest", 1.8])
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
	if _wait < STEP_WAIT:
		return
	_wait = 0.0
	var next: Array = _steps.pop_front()
	match String(next[0]):
		"tap":
			_point = -1
			_finger = _board.piece_to_local(int(next[1]))
			_finger_at = _t
			_board.demo_tap(int(next[1]))
		"point":
			_point = int(next[1])
			_finger = _board.piece_to_local(_point)
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
		var c: Vector2 = _board.piece_to_local(_point)
		var pulse := 0.6 + 0.4 * sin(_t * 6.0)
		var r := float((_board.get("_L") as Dictionary).get("cell_h", 80.0)) * 0.62
		_over.draw_arc(c, r, 0.0, TAU, 40, Color(Pal.SUN, pulse), 5.0, true)
	if lesson == Lesson.HINT and _t - _bulb_at < 1.5 and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
