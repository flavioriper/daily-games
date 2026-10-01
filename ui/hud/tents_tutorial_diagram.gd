extends Control

## One page of Tents' tutorial: a small meadow played by the board itself.
## The page holds a `Meadow` -- tents2d.gd with its sounds, tip lines, gags,
## butterflies, solve and out-of-hearts card taken out -- dealt the lesson's
## trees and counts, and plays the lesson on a loop through the board's own
## input path (a press, motions, a release in board coordinates, as a finger
## would), over a caption that says what it means. So a tent pitches,
## strains, wilts and is struck, a tree beams, a chip turns green and a
## cairn is stacked exactly as on the board. `lesson` picks the page (set
## before it enters the tree):
##
## - PITCH: a tent on a tree's corner strains (a corner is not beside); a tap
##   takes it down; beside its tree, the tree beams.
## - TOUCH: two tents touching at a corner both strain; one moves away.
## - LINES: a line holding its number turns its chip green; a sweep lays
##   cairns over the rest of it, and over a line whose number is 0.
## - HINT: the bulb pitches a tent and pegs it down; a tap on it is refused.
## - HEARTS: a tent that breaks no rule but is not the answer wilts and costs
##   a heart (`hearts` is the band's count); then the right ones.
## - OAK: an old oak wants two tents, which can't sit on neighbouring sides;
##   a "?" keeps its line's count to itself.
##
## The board checkup, 2026-10-01: Tents had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/tents_state.gd")

enum Lesson { PITCH, TOUCH, LINES, HINT, HEARTS, OAK }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a sweep takes from its first square to its last.
const SWEEP_TIME := 0.9
const COLS := 4
const ROWS := 3

var lesson: int = Lesson.PITCH
## HEARTS: how many hearts the band has (Hard 3, Insane 1).
var hearts := 3

var _art: Meadow
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
## The tents standing when the loop starts over.
var _pre: Array = []
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## butterflies or solve, and a last heart lost never puts it to sleep -- the
## loop deals the meadow again.
class Meadow extends "res://puzzles/tents2d.gd":
	func puzzle_id() -> String:
		return "tents_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _gag(_cell: Vector2i) -> void:
		pass

	func _want_flies() -> void:
		pass

	func _wrong_tent(cell: Vector2i) -> void:
		super(cell)
		out_of_hearts = false

	func _run_out() -> void:
		pass

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Meadow.new()
	add_child(_art)
	_setup()
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 3
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

## The lesson's meadow: its trees, the answer and the tents it starts with.
func _setup() -> void:
	var trees: Array = []
	var oaks: Array = []
	var solution: Array = []
	var hidden: Array = []   # [row, col]: -1 keeps that count, a "?"
	match lesson:
		Lesson.PITCH, Lesson.HINT:
			trees = [Vector2i(1, 1), Vector2i(3, 2)]
			solution = [Vector2i(1, 0), Vector2i(3, 1)]
			_pre = [Vector2i(3, 1)] if lesson == Lesson.PITCH else []
		Lesson.TOUCH:
			trees = [Vector2i(0, 0), Vector2i(2, 2)]
			solution = [Vector2i(1, 0), Vector2i(3, 2)]
			_pre = [Vector2i(1, 0)]
		Lesson.LINES:
			trees = [Vector2i(2, 1), Vector2i(0, 2)]
			solution = [Vector2i(2, 0), Vector2i(1, 2)]
			_pre = [Vector2i(1, 2)]
		Lesson.HEARTS:
			# Two layouts with the same counts: the one off the answer breaks
			# no rule the board can see.
			trees = [Vector2i(1, 0), Vector2i(1, 1)]
			solution = [Vector2i(0, 0), Vector2i(2, 1)]
		Lesson.OAK:
			trees = [Vector2i(1, 1)]
			oaks = [Vector2i(1, 1)]
			solution = [Vector2i(0, 1), Vector2i(2, 1)]
			hidden = [1, 2]
	var st = _art.state
	st.w = COLS
	st.h = ROWS
	st.band = 0
	st.tree_list = trees
	st.trees = {}
	for t in trees:
		st.trees[t] = true
	st.oaks = {}
	for o in oaks:
		st.oaks[o] = true
	st.solution = solution
	st.row_counts = []
	st.col_counts = []
	for r in ROWS:
		st.row_counts.append(-1 if hidden.size() == 2 and hidden[0] == r else
			solution.filter(func(t: Vector2i) -> bool: return t.y == r).size())
	for c in COLS:
		st.col_counts.append(-1 if hidden.size() == 2 and hidden[1] == c else
			solution.filter(func(t: Vector2i) -> bool: return t.x == c).size())
	st.marks = {}
	st.locked = {}
	st.history = []
	_art.max_hearts = hearts if lesson == Lesson.HEARTS else 0

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
	if not _begun:
		# The meadow is dealt once and popped in with the board's entrance.
		_begun = true
		_art._build_pieces()
		_art._layout()
		_reset(true)
		_art._enter()
	else:
		_reset()
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.2)
	match lesson:
		Lesson.PITCH:
			_play_tap(Vector2i(0, 0), "HTP_TN_CORNER_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(0, 0), "HTP_TN_DOWN_CAP")
			_loop.tween_interval(1.0)
			_play_tap(Vector2i(1, 0), "HTP_TN_BESIDE_CAP")
			_loop.tween_interval(2.4)
		Lesson.TOUCH:
			_play_tap(Vector2i(2, 1), "HTP_TN_TOUCH_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(2, 1), "HTP_TN_MOVE_CAP")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(3, 2), "HTP_TN_APART_CAP")
			_loop.tween_interval(2.4)
		Lesson.LINES:
			_play_tap(Vector2i(2, 0), "HTP_TN_FULL_CAP")
			_loop.tween_interval(1.4)
			_play_sweep(Vector2i(0, 0), Vector2i(3, 0), "HTP_TN_SWEEP_CAP")
			_loop.tween_interval(1.4)
			_play_sweep(Vector2i(0, 1), Vector2i(3, 1), "HTP_TN_ZERO_CAP")
			_loop.tween_interval(2.4)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_TN_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(1, 0), "HTP_TN_PEGGED_CAP")
			_loop.tween_interval(2.2)
		Lesson.HEARTS:
			_play_tap(Vector2i(0, 1), "HTP_TN_FAIR_CAP")
			_loop.tween_interval(0.3)
			_loop.tween_callback(_say.bind("HTP_TN_WILT_CAP"))
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(0, 0), "HTP_TN_RIGHT_CAP")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(2, 1), "")
			_loop.tween_interval(2.4)
		Lesson.OAK:
			_play_tap(Vector2i(0, 1), "HTP_TN_OAK_CAP")
			_loop.tween_interval(1.2)
			_play_tap(Vector2i(1, 0), "HTP_TN_OAK_TOUCH_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(1, 0), "")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(2, 1), "HTP_TN_OAK_DONE_CAP")
			_loop.tween_interval(1.6)
			_loop.tween_callback(_bump_hidden)
			_loop.tween_callback(_say.bind("HTP_TN_HIDDEN_CAP"))
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## A tap on `cell`: the finger comes down, the caption turns to `say` (when
## not ""), and the finger lets go.
func _play_tap(cell: Vector2i, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(cell))
	_loop.tween_interval(0.45)
	_loop.tween_callback(_button.bind(cell, true))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_button.bind(cell, false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## A sweep from `from` to `to` along a line: the press, the finger drawn
## across square by square, the release.
func _play_sweep(from: Vector2i, to: Vector2i, say: String) -> void:
	_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(from))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(from, true))
	_loop.tween_interval(0.2)
	_loop.tween_method(_drag_to.bind(from, to), 0.0, 1.0, SWEEP_TIME)
	_loop.tween_interval(0.2)
	_loop.tween_callback(_button.bind(to, false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the starting tents, every heart, no
## cairn, nothing in flight. `fresh` is the first deal, whose trees and chips
## the board's entrance pops in.
func _reset(fresh := false) -> void:
	_art._stop_all()
	_art._deal()
	_art.hints_used = 0
	var st = _art.state
	st.marks = {}
	st.locked = {}
	st.history = []
	for t: Vector2i in _pre:
		st.marks[t] = State.TENT
		_art._tent_node(t)
	for cell in _art._tents:
		var tent: Face = _art._tents[cell]
		tent.visible = st.mark_at(cell) == State.TENT
		tent.scale = Vector2.ONE
		tent.rotation = 0.0
		tent.position = Vector2.ZERO
		tent.modulate.a = 1.0
	for cell in _art._trees:
		var tree: Face = _art._trees[cell]
		tree.position = Vector2.ZERO
		tree.rotation = 0.0
		if not fresh:
			tree.scale = Vector2.ONE
	if not fresh:
		for chip: Control in _art._chips_row + _art._chips_col:
			chip.scale = Vector2.ONE
	_art._refresh_faces()
	_art._redraw()
	_art._heart_layer.queue_redraw()
	_lift()
	_say("HTP_TN_START_CAP" if lesson != Lesson.HINT else "HTP_TN_HINT_CAP")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	match lesson:
		Lesson.HINT:
			_art.hint()
			_say("HTP_TN_PEGGED_CAP")
		Lesson.OAK:
			_say("HTP_TN_OAK_DONE_CAP")
		Lesson.TOUCH:
			_say("HTP_TN_APART_CAP")
		Lesson.HEARTS:
			# The still shows the right tents with every heart; the page's
			# body says what a wrong one costs.
			_say("HTP_TN_RIGHT_CAP")
		Lesson.LINES:
			for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0),
					Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 1)]:
				st.marks[cell] = State.GRASS
			_say("HTP_TN_ZERO_CAP")
		_:
			_say("HTP_TN_BESIDE_CAP")
	for t: Vector2i in st.solution:
		if st.mark_at(t) != State.TENT:
			st.marks[t] = State.TENT
		var tent: Face = _art._tent_node(t)
		tent.visible = true
		tent.scale = Vector2.ONE
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

## The finger `u` of the way from `a` to `b` (squares), dragging.
func _drag_to(u: float, a: Vector2i, b: Vector2i) -> void:
	var at: Vector2 = _art.cell_to_local(a.y, a.x).lerp(_art.cell_to_local(b.y, b.x), u)
	_finger = at
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

## OAK: the chips that keep their counts bump as the caption names them.
func _bump_hidden() -> void:
	var st = _art.state
	for r in st.h:
		if int(st.row_counts[r]) < 0:
			_art._bump(_art._chips_row[r])
	for c in st.w:
		if int(st.col_counts[c]) < 0:
			_art._bump(_art._chips_col[c])

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
