extends Control

## One page of Nonogram's tutorial: a little house of 5 by 5 painted by the
## board itself. The page holds a `Floor` -- nonogram2d.gd with its sounds,
## tip lines, gags, streak, solve and out-of-hearts card taken out -- dealt
## the house, and plays the lesson on a loop through the board's own input
## path (a press, motions, a release in board coordinates, as a finger
## would), over a caption that says what it means. So a run is laid in a
## wave, a line's numbers go green or rose, an X is marked and a wrong tile
## turns out of its socket exactly as on the board. `lesson` picks the page
## (set before it enters the tree):
##
## - RUNS: a 5 fills its line; the numbers go green; a 3 is three in a row.
## - ORDER: a row of 1 3 painted whole turns rose; a tap rubs the extra tile
##   out and it reads right.
## - CROSS: the X chip marks the cells of a 1 that stay empty.
## - HINT: the bulb lays a tile and grouts it in; a press on it is refused.
## - HEARTS: on a judged band (`hearts`, the band's count), a stroke runs
##   into a tile the picture does not want: it costs a heart and turns into
##   an X; a line brought right fills its gaps with X's.
## - LEAVES: Leaf Fall: a row of 1 3 shown as 3 1 on leaves reads right in
##   either order.
##
## The board checkup, 2026-10-02: Nonogram had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/nonogram_state.gd")
const Gen = preload("res://puzzles/nonogram_gen.gd")

enum Lesson { RUNS, ORDER, CROSS, HINT, HEARTS, LEAVES }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a stroke takes per cell it crosses.
const CELL_TIME := 0.16
## The house: a roof of one, eaves of three, a wall of five, and a door in
## the second column of the two rows under it (so those rows read 1 3, an
## order Leaf Fall can tumble).
const HOUSE := [
	[0, 0, 1, 0, 0],
	[0, 1, 1, 1, 0],
	[1, 1, 1, 1, 1],
	[1, 0, 1, 1, 1],
	[1, 0, 1, 1, 1]]
## The wall and the chimney column, laid before a lesson that is not about
## them, so the floor reads as a picture under way.
const WALL := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4)]

var lesson: int = Lesson.RUNS
## HEARTS: how many hearts the band has (Hard 3, Insane 1).
var hearts := 3

var _art: Floor
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## streak or solve, and a last heart lost never puts it to sleep -- the loop
## deals the house again.
class Floor extends "res://puzzles/nonogram2d.gd":
	func puzzle_id() -> String:
		return "nonogram_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right_stroke(_cells: Array, _last: Vector2i, _land: float) -> void:
		pass

	func _wrong_tile(cell: Vector2i, land: float) -> void:
		super(cell, land)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	## The house, as the page deals it: `pre` laid, every heart of `h`, its
	## rows `tumble` on leaves, judged as `band` is, and the floor popped in
	## with the board's entrance when `enter`.
	func lay(band: int, h: int, tumble: Array, pre: Array, enter: bool) -> void:
		_gen += 1
		var st = state
		st.band = band
		st.w = HOUSE[0].size()
		st.h = HOUSE.size()
		st.bitmap = HOUSE.duplicate(true)
		st.row_clues = []
		st.col_clues = []
		for y in st.h:
			st.row_clues.append(Gen.clue_for(HOUSE[y]))
		for x in st.w:
			var line: Array = []
			for y in st.h:
				line.append(HOUSE[y][x])
			st.col_clues.append(Gen.clue_for(line))
		st.gw = 1
		st.gh = 1
		for clue in st.row_clues:
			st.gw = maxi(st.gw, (clue as Array).size())
		for clue in st.col_clues:
			st.gh = maxi(st.gh, (clue as Array).size())
		st.target = 0
		for row in HOUSE:
			for v in row:
				st.target += int(v)
		st.tumbled = []
		for i in st.w + st.h:
			st.tumbled.append(tumble.has(i))
		st.marks = {}
		st.locked = {}
		st.history = []
		for cell: Vector2i in pre:
			st.marks[cell] = State.FILL
		max_hearts = h
		hints_used = 0
		_deal()
		brush = State.FILL
		_arrive = {}
		_leaving = []
		_sunk = {}
		_hop = {}
		_nudge = {}
		_wrong = {}
		_shiver = {}
		_clue_bump = {}
		_clue_hop = {}
		_glint = {}
		_focus_cell = Vector2i(-1, -1)
		_clear_gesture()
		_solved_at = -INF
		_seed_verdicts()
		_layout()
		if enter:
			_enter()
		else:
			_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Floor.new()
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
		Lesson.RUNS:
			_play_stroke(Vector2i(0, 2), Vector2i(4, 2), "HTP_NG_FIVE_CAP")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_NG_GREEN_CAP"))
			_loop.tween_interval(1.4)
			_play_stroke(Vector2i(2, 0), Vector2i(2, 4), "")
			_loop.tween_interval(1.0)
			_play_stroke(Vector2i(1, 1), Vector2i(3, 1), "HTP_NG_THREE_CAP")
			_loop.tween_interval(2.4)
		Lesson.ORDER:
			_play_stroke(Vector2i(0, 3), Vector2i(4, 3), "HTP_NG_ORDER_CAP")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_NG_OVER_CAP"))
			_loop.tween_interval(1.8)
			_play_stroke(Vector2i(1, 3), Vector2i(1, 3), "HTP_NG_RUB_CAP")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_NG_GAP_CAP"))
			_loop.tween_interval(2.4)
		Lesson.CROSS:
			_loop.tween_callback(_say.bind("HTP_NG_ROOF_CAP"))
			_loop.tween_interval(1.2)
			_loop.tween_callback(_art.set_brush.bind(State.MARK))
			_play_stroke(Vector2i(0, 0), Vector2i(1, 0), "HTP_NG_X_CAP")
			_loop.tween_interval(0.4)
			_play_stroke(Vector2i(3, 0), Vector2i(4, 0), "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_NG_NOTE_CAP"))
			_loop.tween_interval(2.4)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_NG_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(1.8)
			_play_stroke(Vector2i(2, 0), Vector2i(2, 0), "HTP_NG_GROUT_CAP")
			_loop.tween_interval(2.4)
		Lesson.HEARTS:
			_play_stroke(Vector2i(0, 3), Vector2i(4, 3), "HTP_NG_JUDGED_CAP")
			_loop.tween_interval(0.3)
			_loop.tween_callback(_say.bind("HTP_NG_WRONG_CAP"))
			_loop.tween_interval(1.9)
			_play_stroke(Vector2i(1, 1), Vector2i(3, 1), "HTP_NG_AUTO_CAP")
			_loop.tween_interval(2.6)
		Lesson.LEAVES:
			_loop.tween_callback(_say.bind("HTP_NG_LEAF_CAP"))
			_loop.tween_interval(1.4)
			_play_stroke(Vector2i(3, 3), Vector2i(4, 3), "")
			_loop.tween_interval(0.4)
			_play_stroke(Vector2i(0, 3), Vector2i(0, 3), "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_NG_ANY_CAP"))
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

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

## Every lesson back to its question: the house with what the lesson starts
## from, every heart, nothing in flight. `fresh` is the first deal, which
## pops the floor in with the board's entrance.
func _reset(fresh := false) -> void:
	var pre: Array = []
	var band := 0
	var h := 0
	var tumble: Array = []
	match lesson:
		Lesson.ORDER:
			pre = WALL
		Lesson.CROSS:
			pre = WALL + [Vector2i(1, 1), Vector2i(3, 1)]
		Lesson.HINT:
			pre = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
		Lesson.HEARTS:
			pre = WALL
			band = 2
			h = hearts
		Lesson.LEAVES:
			pre = WALL
			tumble = [3, 4]
	_art.lay(band, h, tumble, pre, fresh)
	_lift()
	_say("HTP_NG_LEAF_CAP" if lesson == Lesson.LEAVES else "HTP_NG_START_CAP")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	var lay := func(cells: Array, to: int) -> void:
		for cell: Vector2i in cells:
			st.marks[cell] = to
	match lesson:
		Lesson.RUNS:
			lay.call([Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4), Vector2i(1, 1), Vector2i(3, 1)],
				State.FILL)
			_say("HTP_NG_GREEN_CAP")
		Lesson.ORDER, Lesson.LEAVES:
			lay.call([Vector2i(0, 3), Vector2i(3, 3), Vector2i(4, 3)], State.FILL)
			_say("HTP_NG_GAP_CAP" if lesson == Lesson.ORDER else "HTP_NG_ANY_CAP")
		Lesson.CROSS:
			lay.call([Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(4, 0)], State.MARK)
			_say("HTP_NG_X_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_NG_GROUT_CAP")
			return
		Lesson.HEARTS:
			# The still shows the finished line and its X's; the page's body
			# says what a wrong tile costs.
			lay.call([Vector2i(1, 1), Vector2i(3, 1)], State.FILL)
			lay.call([Vector2i(0, 1), Vector2i(4, 1)], State.MARK)
			_say("HTP_NG_AUTO_CAP")
	_art._seed_verdicts()
	_art._refresh()

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
