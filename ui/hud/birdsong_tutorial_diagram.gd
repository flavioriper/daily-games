extends Control

## One page of Birdsong's tutorial, played by the board itself
## (puzzles/birdsong2d.gd built with `demo`: silent, deaf, laid in this
## rect) and a finger that taps its drums. `lesson` and `band` are set
## before it enters the tree:
##
## - LISTEN: the bird sings the first round; nobody plays.
## - PLAY: the bird sings, the finger plays the round back, a berry a note,
##   and the round grows by one.
## - SLIP: the finger strikes the wrong drum; the bird is puzzled and sings
##   the round again, then it is played back right.
## - WHISPER: Insane's second round: only the new note is sung, and the
##   finger plays the whole tune.
## - HINT: the bulb over the board, and the bird sings again.
##
## A page plays until its point is made, waits a moment and starts over.
## Under reduce motion the board stands as it is dealt.

const Board = preload("res://puzzles/birdsong2d.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

enum Lesson { LISTEN, PLAY, SLIP, WHISPER, HINT }

const SEED := 20261022
const FINGER_R := 26.0
const FINGER_ALPHA := 0.22
## How long the finger waits before each tap, and the page's rest at the end.
const TAP_WAIT := 0.42
const REST := 1.6

var lesson: int = Lesson.LISTEN
var band := 0
var _board: Control
var _over: Control
var _wait := 0.0
var _rest := -1.0
var _slipped := false
var _hinted := false
var _finger := Vector2(-1, -1)
var _finger_at := -INF
var _t := 0.0
var _start_round := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	resized.connect(func() -> void: _over.size = size)
	_deal()
	add_child(_over)

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
	_slipped = false
	_hinted = false
	_rest = -1.0
	_wait = 0.0
	# Whisper's page opens on the second round: the first played already.
	if lesson == Lesson.WHISPER:
		var st = _board.state()
		st.round_len += 1
		st.history.append(0)
		st.clean += 1
	_start_round = _board.round_no()

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
	# the page's point made: rest, then start over
	if _board.round_no() > _start_round or _board.is_done() or lesson == Lesson.LISTEN and _board.phase() == Board.Phase.PLAY:
		_rest = REST
		return
	if lesson == Lesson.HINT and not _hinted and _board.phase() == Board.Phase.PLAY:
		_wait += delta
		if _wait > 0.8:
			_hinted = true
			_wait = 0.0
			_board.hints_extra += 1
			_board.hint()
		return
	if lesson == Lesson.LISTEN or _board.phase() != Board.Phase.PLAY:
		_wait = 0.0
		return
	_wait += delta
	if _wait < TAP_WAIT:
		return
	_wait = 0.0
	var want: int = st.tune[st.pos]
	var d := want
	if lesson == Lesson.SLIP and not _slipped and st.pos == st.round_len - 1:
		d = (want + 1) % st.drums()
		_slipped = true
	_finger = _board.drum_to_local(d)
	_finger_at = _t
	_board.demo_strike(d)

func _draw_over() -> void:
	var e := _t - _finger_at
	if e < 0.35:
		var a := FINGER_ALPHA * (1.0 - e / 0.35)
		_over.draw_circle(_finger + Vector2(0, 8.0), FINGER_R * (1.0 + e), Color(Pal.TEXT, a))
	if lesson == Lesson.HINT and _hinted and _rest < 0.0:
		var c := Vector2(size.x - 44.0, 40.0)
		_over.draw_circle(c, 26.0, Color(Pal.SUN, 0.9))
		_over.draw_arc(c, 32.0, 0.0, TAU, 32, Color(Pal.SUN, 0.5), 3.0, true)
