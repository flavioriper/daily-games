extends Control

## One page of Queens' tutorial: a little court of 5 by 5 seated by the board
## itself. The page holds a `Court` -- queens2d.gd with its sounds, tip lines,
## streak, gags, solve and out-of-hearts card taken out -- dealt a court of
## five patches, and plays the lesson on a loop through the board's own input
## path (a press, motions, a release in board coordinates, as a finger
## would), over a caption that says what it means. So a queen's wave crosses
## her row, column and colour, a seat she sees is refused, a wrong queen
## buzzes off with a heart and the mist keeps a patch open exactly as on the
## board. `lesson` picks the page (set before it enters the tree):
##
## - SEAT: a tap lays a cross, a second tap seats a queen; her wave crosses
##   her row, her column and her colour; a second queen goes where nothing
##   sees.
## - TOUCH: with a queen seated, a tap on the seat at her corner is refused
##   (it shivers and she wobbles); the next queen goes where she cannot see.
## - CROSS: a drag lays the player's own crosses; a drag from a cross picks
##   them up again.
## - HINT: the bulb seats a queen and pins her; a tap on her is refused.
## - HEARTS: on a judged band (`hearts`, the band's count), a queen seated
##   where the answer has none costs a heart, buzzes off, and leaves a rose
##   cross for good.
## - MIST: Morning Mist: a misty patch takes two queens; the first leaves it
##   open and lights one of its two crowns, the second crosses the rest.
##
## The board checkup, 2026-10-02: Queens had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/queens_state.gd")

enum Lesson { SEAT, TOUCH, CROSS, HINT, HEARTS, MIST }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a stroke takes per cell it crosses.
const CELL_TIME := 0.16
## The court: five patches, [row][column] -> patch, and the answer's column
## in every row. No two of the answer's queens touch.
const COURT := [
	[0, 0, 1, 1, 1],
	[0, 0, 1, 1, 1],
	[2, 0, 3, 1, 1],
	[2, 2, 3, 3, 4],
	[2, 2, 3, 4, 4]]
const ANSWER := [1, 3, 0, 2, 4]
## The misty court: the last two patches run together into one that takes
## two queens.
const MISTY := [
	[0, 0, 1, 1, 1],
	[0, 0, 1, 1, 1],
	[2, 0, 3, 1, 1],
	[2, 2, 3, 3, 3],
	[2, 2, 3, 3, 3]]
## The first queen, seated before a lesson that is not about her.
const FIRST := Vector2i(1, 0)

var lesson: int = Lesson.SEAT
## HEARTS and MIST: how many hearts the band has (Hard 3, Insane 1).
var hearts := 3

var _art: Court
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## streak or solve, and a last heart lost never puts it to sleep -- the loop
## deals the court again.
class Court extends "res://puzzles/queens2d.gd":
	func puzzle_id() -> String:
		return "queens_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right_seat(_cell: Vector2i, _land: float) -> void:
		pass

	func _wrong_seat(cell: Vector2i, land_at: float) -> void:
		super(cell, land_at)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	## The court as the page deals it: misty when `mist`, `pre` seated,
	## every heart of `h`, judged as `band` is, and the court popped in with
	## the board's entrance when `enter`.
	func lay(band: int, h: int, mist: bool, pre: Array, enter: bool) -> void:
		_stop_all()
		var st = state
		st.band = band
		st.n = COURT.size()
		st.region = (MISTY if mist else COURT).duplicate(true)
		st.solution = PackedInt32Array(ANSWER)
		st.ok = true
		st.quota = PackedInt32Array([1, 1, 1, 2] if mist else [1, 1, 1, 1, 1])
		st.mist = [3] if mist else []
		st.queens = {}
		st.crosses = {}
		st.locked = {}
		st.shown = {}
		st.history = []
		for cell: Vector2i in pre:
			st.queens[cell] = true
		st.recompute()
		max_hearts = h
		hints_used = 0
		hints_extra = 0
		_deal()
		_pick_blooms()
		_mist_in_at = -INF
		_mist_out_at = INF
		_cross_in = {}
		_cross_out = []
		_wash = {}
		_glint = {}
		_blush = {}
		_shiver = {}
		_sunk = {}
		_clear_gesture()
		_solved_at = -INF
		_laid_n = -1
		_build_pieces()
		_layout()
		for cell: Vector2i in pre:
			var bee := _bee_node(cell)
			bee.visible = true
			bee.scale = Vector2.ONE
			bee.modulate.a = 1.0
		_update_blooms()
		_refresh_faces()
		if enter:
			_enter()
		elif mist:
			_mist_in_at = _now() - MIST_IN
		_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Court.new()
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 4
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

func _layout() -> void:
	if _art == null:
		return
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, maxf(0.0, size.y - 96.0))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.4)
	match lesson:
		Lesson.SEAT:
			_play_tap(FIRST, "HTP_QN_ONCE_CAP")
			_loop.tween_interval(0.9)
			_play_tap(FIRST, "HTP_QN_TWICE_CAP")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_QN_SEES_CAP"))
			_loop.tween_interval(2.2)
			_play_tap(Vector2i(3, 1), "")
			_loop.tween_interval(0.3)
			_play_tap(Vector2i(3, 1), "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_QN_EACH_CAP"))
			_loop.tween_interval(2.6)
		Lesson.TOUCH:
			_loop.tween_callback(_say.bind("HTP_QN_CORNER_CAP"))
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(2, 1), "")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_QN_REFUSED_CAP"))
			_loop.tween_interval(1.8)
			_play_tap(Vector2i(3, 1), "HTP_QN_FREE_CAP")
			_loop.tween_interval(0.3)
			_play_tap(Vector2i(3, 1), "")
			_loop.tween_interval(2.6)
		Lesson.CROSS:
			_play_stroke(Vector2i(2, 2), Vector2i(4, 2), "HTP_QN_DRAG_CAP")
			_loop.tween_interval(1.2)
			_play_stroke(Vector2i(2, 2), Vector2i(4, 2), "HTP_QN_PICK_CAP")
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_QN_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(2.0)
			_play_tap(FIRST, "HTP_QN_PINNED_CAP")
			_loop.tween_interval(2.4)
		Lesson.HEARTS:
			_play_tap(Vector2i(0, 0), "HTP_QN_JUDGED_CAP")
			_loop.tween_interval(0.3)
			_play_tap(Vector2i(0, 0), "")
			_loop.tween_interval(0.5)
			_loop.tween_callback(_say.bind("HTP_QN_WRONG_CAP"))
			_loop.tween_interval(2.8)
			_loop.tween_callback(_say.bind("HTP_QN_SHOWN_CAP"))
			_loop.tween_interval(2.2)
		Lesson.MIST:
			_play_tap(Vector2i(2, 3), "HTP_QN_MIST_CAP")
			_loop.tween_interval(0.3)
			_play_tap(Vector2i(2, 3), "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_QN_HALF_CAP"))
			_loop.tween_interval(2.0)
			_play_tap(Vector2i(4, 4), "")
			_loop.tween_interval(0.3)
			_play_tap(Vector2i(4, 4), "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_QN_FULL_CAP"))
			_loop.tween_interval(2.6)
	_loop.tween_callback(_reset)

## A tap on `cell`: the finger comes down, the caption turns to `say` (when
## not ""), and lets go.
func _play_tap(cell: Vector2i, say: String) -> void:
	_play_stroke(cell, cell, say)

## A stroke from `from` to `to` along a line (one cell is a tap): the finger
## comes down, the caption turns to `say` (when not ""), the finger is drawn
## across cell by cell, and lets go.
func _play_stroke(from: Vector2i, to: Vector2i, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(from))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(from, true))
	_loop.tween_interval(0.2)
	var cells := maxi(absi(to.x - from.x), absi(to.y - from.y))
	if cells > 0:
		_loop.tween_method(_drag_to.bind(from, to), 0.0, 1.0, CELL_TIME * cells)
		_loop.tween_interval(0.15)
	_loop.tween_callback(_button.bind(to, false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the court with what the lesson starts
## from, every heart, nothing in flight. `fresh` is the first deal, which
## pops the court in with the board's entrance.
func _reset(fresh := false) -> void:
	var pre: Array = []
	var band := 0
	var h := 0
	var mist := false
	match lesson:
		Lesson.TOUCH, Lesson.CROSS:
			pre = [FIRST]
		Lesson.HEARTS:
			band = 2
			h = hearts
		Lesson.MIST:
			pre = [FIRST, Vector2i(3, 1), Vector2i(0, 2)]
			band = 3
			h = hearts
			mist = true
	_art.lay(band, h, mist, pre, fresh)
	_lift()
	_say("HTP_QN_MIST_CAP" if lesson == Lesson.MIST else "HTP_QN_START_CAP")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	var seat := func(cells: Array) -> void:
		for cell: Vector2i in cells:
			st.queens[cell] = true
			var bee: Control = _art._bee_node(cell)
			bee.visible = true
			bee.scale = Vector2.ONE
	match lesson:
		Lesson.SEAT, Lesson.TOUCH:
			seat.call([FIRST, Vector2i(3, 1)])
			_say("HTP_QN_EACH_CAP" if lesson == Lesson.SEAT else "HTP_QN_FREE_CAP")
		Lesson.CROSS:
			for x in range(2, 5):
				st.crosses[Vector2i(x, 2)] = true
			_say("HTP_QN_DRAG_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_QN_PINNED_CAP")
			return
		Lesson.HEARTS:
			st.shown[Vector2i(0, 0)] = true
			st.crosses[Vector2i(0, 0)] = true
			_say("HTP_QN_SHOWN_CAP")
		Lesson.MIST:
			seat.call([Vector2i(2, 3), Vector2i(4, 4)])
			_say("HTP_QN_FULL_CAP")
	st.recompute()
	_art._update_blooms()
	_art._refresh_faces()
	_art._redraw()

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(cell: Vector2i) -> void:
	_finger = _art.cell_to_local(cell.y, cell.x)
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(cell: Vector2i, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.cell_to_local(cell.y, cell.x)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

## The finger `u` of the way from cell `a` to cell `b`, dragging.
func _drag_to(u: float, a: Vector2i, b: Vector2i) -> void:
	var at: Vector2 = _art.cell_to_local(a.y, a.x).lerp(_art.cell_to_local(b.y, b.x), u)
	_finger = at
	_down = true
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0 or _art._cell <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var cell: float = _art._cell
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := cell * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
