extends Control

## One page of Domino Patio's tutorial, played by the board itself
## (puzzles/patio2d.gd built with `demo`: silent, deaf, laid in this rect)
## and a finger that carries its tiles. `lesson` and `band` are set before
## it enters the tree:
##
## - LAY: the finger carries each tile from the rack to its two squares.
## - TURN: the finger taps a tile on the rack round, then lays it.
## - BEDS: the tiles go down one after another and each bed's tag ticks as
##   it fills and keeps its rule.
## - BOUNDS: a day with under, over (and on Hard, all different) tags, laid.
## - SPARE: Insane's day laid; one tile is left on the rack.
## - HINT: the bulb over the board, and one tile goes down where it belongs.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/patio2d.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { LAY, TURN, BEDS, BOUNDS, SPARE, HINT }

const SEED := 20261022
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before each tile, how long it carries one, and
## the page's rest at the end.
const WAIT := 0.5
const CARRY := 0.45
const REST := 1.8

var lesson: int = Lesson.LAY
var band := 0
var _board: Control
var _over: Control
var _wait := 0.0
var _rest := -1.0
var _next := 0
var _turns := 0
var _hinted := false
var _finger_from := Vector2(-1, -1)
var _finger_to := Vector2(-1, -1)
var _finger_at := -INF
var _tap_at := -INF
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
	# the rules lessons show their own band's tags; the first three keep
	# to the smallest patio, whatever the band
	var b := band if lesson == Lesson.BOUNDS or lesson == Lesson.SPARE or lesson == Lesson.HINT else 0
	if lesson == Lesson.BOUNDS:
		b = clampi(band, 1, 2)
	_board.start(rng, b)
	_board.skip_entrance()
	_rest = -1.0
	_wait = 0.0
	_next = 0
	_turns = 0
	_hinted = false

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
	if _board.is_done() or _next >= st.tiles.size():
		_rest = REST
		return
	_wait += delta
	if _wait < WAIT:
		return
	if lesson == Lesson.HINT:
		if _hinted:
			if _wait > WAIT + 1.4:
				_rest = REST
			return
		_hinted = true
		_board.hints_extra += 1
		_board.hint()
		return
	# the next tile the answer lays (a spare stays on the rack)
	while _next < st.tiles.size() and st.answer[_next].x < 0:
		_next += 1
	if _next >= st.tiles.size():
		return
	if lesson == Lesson.TURN and _next == 0 and _turns < 3:
		_wait = WAIT * 0.4
		_turns += 1
		_finger_from = _board.tile_to_local(0)
		_finger_to = _finger_from
		_finger_at = _t
		_tap_at = _t
		_board.demo_turn(0)
		return
	_wait = 0.0
	_finger_from = _board.tile_to_local(_next)
	_finger_to = _board.answer_to_local(_next)
	_finger_at = _t
	_board.demo_lay(_next)
	_next += 1

func _draw_over() -> void:
	var e := (_t - _finger_at) / CARRY
	if e < 1.4:
		var at := _finger_from.lerp(_finger_to, Motion.back_out(clampf(e, 0.0, 1.0)))
		var a := FINGER_ALPHA * clampf(1.4 - e, 0.0, 1.0)
		var tap := _t - _tap_at
		var r := FINGER_R * (1.0 + (0.3 * (1.0 - tap / 0.25) if tap < 0.25 else 0.0))
		_over.draw_circle(at + Vector2(0, 8.0), r, Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _hinted and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
