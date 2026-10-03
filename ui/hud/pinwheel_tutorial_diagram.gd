extends Control

## One page of Pinwheel's tutorial: a little frame of its own, four by
## three, played by the board itself. The page holds a `Frame` --
## pinwheel2d.gd with its sounds, tip lines, streak, gags, party and
## out-of-hearts card taken out -- dealt by hand, and plays the lesson on a
## loop through the board's own input path (a press on a pinwheel, the
## release), over a caption that says what it means. So a wheel sinks under
## the finger, the piece lifts and swings a quarter round its pin, the dark
## hatched squares lift off as it lands, the frame's solve wave runs, a piece
## already home snags and takes its gold button, and a ribbon tugs the
## pieces tied below exactly as on the board. `lesson` picks the page (set
## before it enters the tree):
##
## - TURN: the L turned twice round its pin, from lying across two pieces
##   to home, the dark squares and the bare ones going with it.
## - DONE: the last piece turned home (over the quarter that would leave the
##   frame, which is skipped): every square covered once, the solve wave.
## - HEARTS (Hard, Insane): a tap on a piece that is already home snags,
##   costs a heart and sews a gold button on it.
## - RIBBONS (Insane): one tap on the top pinwheel turns the two tied below,
##   the crossed blue ribbon's the other way, and the frame is done.
## - UNDO: Undo turns the last piece back; Reset turns them all back (Reset
##   alone on Insane, which has no Undo).
## - HINT: the bulb turns the piece furthest from home all the way home.
##
## The board checkup, 2026-10-02: Pinwheel had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/pinwheel_gen.gd")
const State = preload("res://puzzles/pinwheel_state.gd")

enum Lesson { TURN, DONE, HEARTS, RIBBONS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How far right the frame sits on a band with hearts, so their pill hangs
## in the air to its left.
const HEART_SHIFT := 56.0

## The frame every lesson plays on, as it is answered: an L, a T, a domino
## and a bar, each pinned through the capital.
##
##     a  b  b  b
##     a  A  B  C
##     d  d  D  c
const COLS := 4
const ROWS := 3
const L_PIECE := 0
const T_PIECE := 1
const DOMINO := 2
const BAR := 3
const CELLS := [
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1)],
	[Vector2i(3, 1), Vector2i(3, 2)],
	[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
]
const PINS := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2)]
const CLOTHS := [0, 3, 5, 1]
## Ribbons' frame: the L's pinwheel pulls the bar the same way (pink) and
## the domino the other way (crossed, blue).
const RIBBONS := [{"from": L_PIECE, "to": BAR, "sign": 1},
	{"from": L_PIECE, "to": DOMINO, "sign": -1}]

var lesson: int = Lesson.TURN
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: Frame
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## streak, party or out-of-hearts card, and a snag never puts it to sleep --
## the loop deals the frame again. A win is the solve wave alone, called by
## the page.
class Frame extends "res://puzzles/pinwheel2d.gd":
	func puzzle_id() -> String:
		return "pinwheel_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_turned(_p: int, _before: int, _after: int, _lands: float) -> void:
		pass

	func _party() -> void:
		pass

	func _snag(p: int, t: float) -> void:
		super(p, t)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## The hearts hang beside the frame, so the page's height is all frame.
	func _heart_row() -> float:
		return 0.0

	func _origin() -> Vector2:
		var o := super()
		if _in_ref or max_hearts <= 0:
			return o
		return o + Vector2(HEART_SHIFT, 0.0)

	func _hearts_at() -> Vector2:
		var left := _origin().x - FRAME_PAD - FRAME_RIM
		return Vector2(left * 0.5, _grid_centre().y)

	## The frame as the page deals it: every piece on `start` (orientation
	## indices, 0 home), the ribbons when `tied`, band `b`'s judge, hearts and
	## hints, and, when `enter`, popped in with the board's entrance.
	func lay(b: int, start: Array, tied: bool, enter: bool) -> void:
		_gen += 1
		var shapes: Array = []
		var pins := PackedInt32Array()
		for p in CELLS.size():
			var pin: Vector2i = PINS[p]
			shapes.append(Gen.orientations(CELLS[p], pin, COLS, ROWS))
			pins.append(pin.y * COLS + pin.x)
		var answer := PackedInt32Array()
		answer.resize(CELLS.size())
		_state.take({"cols": COLS, "rows": ROWS, "pins": pins, "shapes": shapes,
			"answer": answer, "start": PackedInt32Array(start),
			"cloth": PackedInt32Array(CLOTHS), "unique": true,
			"ribbons": RIBBONS if tied else []}, b)
		hints_used = 0
		moves = 0
		_done = false
		_running = true
		_dealt()
		_tip_timer.stop()
		if not enter:
			# Already in: no pop, and the dark squares already arrived.
			var t := _now()
			_opened = t - 10.0
			for p in _turned_at.size():
				_turned_at[p] = t - 10.0
			_heart_layer.queue_redraw()
			_refresh()

	## The win as the board shows it, without the party: the solve wave.
	func win() -> void:
		_on_solved()

	## Where pinwheel `p` sits, in the frame's own pixels.
	func pin_at(p: int) -> Vector2:
		return _pin_point(p)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Frame.new()
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 6
	_over.draw.connect(_draw_finger)
	add_child(_over)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall and
	# its centred text sinks under the buttons.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start")

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and _loop == null:
		call_deferred("_start")

## The frame as tall as the page leaves over the caption and the page's
## whole width: the board centres its own frame, and a judged band's hearts
## hang in the air to its left.
func _layout() -> void:
	if _art == null:
		return
	var h := maxf(0.0, size.y - CAPTION_H)
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, h)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the frame again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.8)
	match lesson:
		Lesson.TURN:
			_play_tap(L_PIECE, "HTP_PW_TAP_CAP")
			_loop.tween_interval(0.2)
			_say_for("HTP_PW_PIN_CAP", 1.4)
			_play_tap(L_PIECE, "")
			_loop.tween_interval(0.6)
			_say_for("HTP_PW_FIT_CAP", 2.6)
		Lesson.DONE:
			_play_tap(DOMINO, "")
			_loop.tween_interval(0.1)
			_say_for("HTP_PW_SKIP_CAP", 1.4)
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_PW_DONE_CAP", 3.4)
		Lesson.HEARTS:
			_play_tap(T_PIECE, "")
			_loop.tween_interval(0.1)
			_say_for("HTP_PW_SNAG_CAP", 1.8)
			_say_for("HTP_PW_BUTTON_CAP", 2.6)
		Lesson.RIBBONS:
			_play_tap(L_PIECE, "HTP_PW_TUG_CAP")
			_loop.tween_interval(0.3)
			_say_for("HTP_PW_CROSS_CAP", 2.0)
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_PW_DONE_CAP", 3.0)
		Lesson.UNDO:
			_play_tap(L_PIECE, "HTP_PW_TAP_CAP")
			_loop.tween_interval(0.8)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_PW_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_play_tap(L_PIECE, "HTP_PW_TAP_CAP")
				_loop.tween_interval(0.6)
			_play_tap(L_PIECE, "")
			_loop.tween_interval(0.9)
			_loop.tween_callback(_say.bind("HTP_PW_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(3.2)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## A tap on piece `p`'s pinwheel: the finger comes down on it (the caption
## turning to `say` when not ""), the wheel sinks, and the finger lifts --
## the turn.
func _play_tap(p: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(p))
	_loop.tween_interval(0.35)
	_loop.tween_callback(_press.bind(p))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_release.bind(p))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Where a lesson's frame starts (orientation indices, 0 home): the L two
## quarters round (lying across the T and the bar, two squares bare), the
## domino two (its square doubled on the T's end, its own bare) for DONE and
## the bulb, the bar one for HEARTS (so the frame is not already done when
## the home T is tapped), and Ribbons' three pieces each one tug from home.
func _start_for() -> Array:
	match lesson:
		Lesson.DONE:
			return [0, 0, 2, 0]
		Lesson.HEARTS:
			return [0, 0, 0, 1]
		Lesson.RIBBONS:
			return [3, 0, 1, 1]
		Lesson.HINT:
			return [2, 0, 2, 0]
	return [2, 0, 0, 0]

## Every lesson back to its question: the frame as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the frame in with
## the board's entrance.
func _reset(fresh := false) -> void:
	_art.lay(band, _start_for(), lesson == Lesson.RIBBONS, fresh)
	_lift()
	_say({Lesson.TURN: "HTP_PW_DARK_CAP", Lesson.DONE: "HTP_PW_LAST_CAP",
		Lesson.HEARTS: "HTP_PW_HOME_CAP", Lesson.RIBBONS: "HTP_PW_TIED_CAP",
		Lesson.UNDO: "HTP_PW_TAP_CAP", Lesson.HINT: "HTP_PW_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.TURN:
			_art._tap(PINS[L_PIECE])
			_art._tap(PINS[L_PIECE])
			_say("HTP_PW_FIT_CAP")
		Lesson.DONE:
			_art._tap(PINS[DOMINO])
			_art.win()
			_say("HTP_PW_DONE_CAP")
		Lesson.HEARTS:
			_art._tap(PINS[T_PIECE])
			_say("HTP_PW_BUTTON_CAP")
		Lesson.RIBBONS:
			_art._tap(PINS[L_PIECE])
			_art.win()
			_say("HTP_PW_CROSS_CAP")
		Lesson.UNDO:
			_say("HTP_PW_UNDO_CAP" if band < 3 else "HTP_PW_RESET_CAP")
		Lesson.HINT:
			_art.hint()
	_art._refresh()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(p: int) -> void:
	_finger = _art.position + _art.pin_at(p)
	_down = false

func _press(p: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _art.pin_at(p)
	_down = true
	_art._gui_input(ev)

func _release(p: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = _art.pin_at(p)
	_down = false
	_art._gui_input(ev)

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _finger + Vector2(FINGER_R * 0.8, FINGER_R)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
