extends Control

## One page of Light Up's tutorial: a small court played by the board itself.
## The page holds a `Court` -- lightup2d.gd with its sounds, tip lines,
## gags, moths, streak, solve and out-of-hearts card taken out -- dealt the
## lesson's blocks, and plays the lesson on a loop through the board's own
## input path (a press, motions, a release in board coordinates, as a finger
## would), over a caption that says what it means. So a lantern lands and
## its light runs down the stones, two lanterns blush, a block turns green or
## rose and a chip is laid exactly as on the board. `lesson` picks the page
## (set before it enters the tree):
##
## - LIGHT: a lantern lights its row and column; a block stops it; three
##   lanterns light every stone.
## - SEE: a second lantern in the first one's row: both blush; it is taken
##   up and set down out of sight.
## - NUMBERS: a 2 with two lanterns beside it turns green, with three rose.
## - CHIPS: two sweeps chip the stones beside a 0.
## - HINT: the bulb sets a lantern down and pins it; a tap on it is refused.
## - HEARTS: a lantern that breaks no rule but is not the answer's gutters
##   out and costs a heart (`hearts` is the band's count); then the right ones.
## - CATS: a cat wants the light her tag says: one lantern on her and she
##   purrs, two and she is cross; light passes over her.
##
## The board checkup, 2026-10-01: Light Up had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/lightup_state.gd")
const Gen = preload("res://puzzles/lightup_gen.gd")

enum Lesson { LIGHT, SEE, NUMBERS, CHIPS, HINT, HEARTS, CATS }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a sweep takes from its first stone to its last.
const SWEEP_TIME := 0.8
const COLS := 4
const ROWS := 3

var lesson: int = Lesson.LIGHT
## HEARTS: how many hearts the band has (Hard 3, Insane 1).
var hearts := 3

var _art: Court
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
## The lanterns standing when the loop starts over.
var _pre: Array = []
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags, moths,
## streak or solve, and a last heart lost never puts it to sleep -- the loop
## deals the court again.
class Court extends "res://puzzles/lightup2d.gd":
	func puzzle_id() -> String:
		return "lightup_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _gag(_cell: Vector2i) -> void:
		pass

	func _want_flies(_fresh := Vector2i(-1, -1)) -> void:
		pass

	func _on_right_lamp(cell: Vector2i) -> void:
		if max_hearts > 0:
			_flare_lamp(cell)

	func _wrong_lamp(cell: Vector2i) -> void:
		super(cell)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	## A block hops where the caption names it.
	func _hop_block(cell: Vector2i) -> void:
		_block_hop[cell] = {"at": _now(), "height": CHEER_HOP * _cell, "time": Motion.HOP_TIME}
		_busy_for(Motion.HOP_TIME)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Court.new()
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

## The lesson's court: its blocks and cats, the answer and the lanterns it
## starts with.
func _setup() -> void:
	var W := Gen.WHITE
	var middle := Gen.WALL
	var solution: Array = [Vector2i(0, 0), Vector2i(2, 2), Vector2i(3, 1)]
	match lesson:
		Lesson.SEE:
			_pre = [Vector2i(0, 0)]
		Lesson.NUMBERS:
			middle = 2
			solution = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 2), Vector2i(3, 1)]
		Lesson.CHIPS:
			middle = 0
			solution = [Vector2i(0, 0), Vector2i(2, 2), Vector2i(3, 1)]
		Lesson.CATS:
			# Only the still reads it: the lantern whose light she wants.
			middle = Gen.CAT + 1
			solution = [Vector2i(1, 0)]
	var st = _art.state
	st.w = COLS
	st.h = ROWS
	st.band = 0
	st.grid = [[W, W, W, W], [W, middle, W, W], [W, W, W, W]]
	st.solution = solution
	st.cats = [Vector2i(1, 1)] if lesson == Lesson.CATS else []
	st.marks = {}
	st.locked = {}
	st.history = []
	st.recompute()
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
		# The court is dealt once and popped in with the board's entrance.
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
		Lesson.LIGHT:
			_play_tap(Vector2i(3, 1), "HTP_LU_ROW_CAP")
			_loop.tween_interval(1.4)
			_loop.tween_callback(_say.bind("HTP_LU_STOP_CAP"))
			_loop.tween_callback(_art._hop_block.bind(Vector2i(1, 1)))
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(0, 0), "HTP_LU_MORE_CAP")
			_loop.tween_interval(0.5)
			_play_tap(Vector2i(2, 2), "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_LU_ALL_CAP"))
			_loop.tween_interval(2.4)
		Lesson.SEE:
			_play_tap(Vector2i(2, 0), "HTP_LU_SEE_CAP")
			_loop.tween_interval(1.8)
			_play_tap(Vector2i(2, 0), "HTP_LU_TAKE_CAP")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(2, 2), "HTP_LU_APART_CAP")
			_loop.tween_interval(2.4)
		Lesson.NUMBERS:
			_loop.tween_callback(_art._hop_block.bind(Vector2i(1, 1)))
			_play_tap(Vector2i(1, 0), "HTP_LU_NUM_CAP")
			_loop.tween_interval(0.8)
			_play_tap(Vector2i(0, 1), "HTP_LU_MET_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(2, 1), "HTP_LU_OVER_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(2, 1), "")
			_loop.tween_interval(2.0)
		Lesson.CHIPS:
			_loop.tween_callback(_say.bind("HTP_LU_ZERO_CAP"))
			_loop.tween_callback(_art._hop_block.bind(Vector2i(1, 1)))
			_loop.tween_interval(1.4)
			_play_sweep(Vector2i(0, 1), Vector2i(2, 1), "HTP_LU_SWEEP_CAP")
			_loop.tween_interval(0.5)
			_play_sweep(Vector2i(1, 0), Vector2i(1, 2), "")
			_loop.tween_interval(1.0)
			_play_tap(Vector2i(0, 0), "HTP_LU_CHIPPED_CAP")
			_loop.tween_interval(2.4)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_LU_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(1.8)
			_play_tap(_hinted, "HTP_LU_PINNED_CAP")
			_loop.tween_interval(2.4)
		Lesson.HEARTS:
			_play_tap(Vector2i(1, 0), "HTP_LU_FAIR_CAP")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_LU_GUTTER_CAP"))
			_loop.tween_interval(1.8)
			_play_tap(Vector2i(0, 0), "HTP_LU_RIGHT_CAP")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(2, 2), "")
			_loop.tween_interval(0.6)
			_play_tap(Vector2i(3, 1), "")
			_loop.tween_interval(2.2)
		Lesson.CATS:
			_loop.tween_callback(_say.bind("HTP_LU_CAT_CAP"))
			_loop.tween_interval(1.2)
			_play_tap(Vector2i(1, 0), "HTP_LU_CAT_ONE_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(3, 1), "HTP_LU_CAT_TWO_CAP")
			_loop.tween_interval(1.6)
			_play_tap(Vector2i(3, 1), "")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_LU_CAT_OVER_CAP"))
			_loop.tween_interval(2.2)
	_loop.tween_callback(_reset)

## The hint's lantern: the first of the answer's, which is the one the bulb
## sets down on an empty court.
var _hinted: Vector2i:
	get:
		return _art.state.solution[0]

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
## across stone by stone, the release.
func _play_sweep(from: Vector2i, to: Vector2i, say: String) -> void:
	if say != "":
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

## Every lesson back to its question: the starting lanterns, every heart, no
## chip, nothing in flight, every stone at the light it stands in. `fresh` is
## the first deal, whose cats the board's entrance pops in.
func _reset(fresh := false) -> void:
	_art._stop_all()
	_art._deal()
	_art.hints_used = 0
	_art._beam_out = []
	_art._chip_in = {}
	_art._chip_out = []
	_art._blush = {}
	_art._sunk = {}
	_art._flare = {}
	_art._clear_gesture()
	var st = _art.state
	st.marks = {}
	st.locked = {}
	st.history = []
	for t: Vector2i in _pre:
		st.marks[t] = State.LAMP
		_art._lamp_node(t)
	st.recompute()
	for cell in _art._lamps:
		var lamp: Face = _art._lamps[cell]
		lamp.visible = st.mark_at(cell) == State.LAMP
		lamp.scale = Vector2.ONE
		lamp.rotation = 0.0
		lamp.position = Vector2.ZERO
		lamp.modulate.a = 1.0
		lamp.gutter = 0.0
		lamp.flare = 0.0
		lamp.pinned = false
	if not fresh:
		for cell in _art._cats:
			var cat: Face = _art._cats[cell]
			cat.scale = Vector2.ONE
			cat.position = Vector2.ZERO
			cat.rotation = 0.0
	_art._blocks_met = _art._met_blocks()
	_art._cat_was = {}
	for cell: Vector2i in st.cats:
		_art._cat_was[cell] = st.cat_state(cell)
	_art._refresh_faces(true)
	_art._settle()
	_art._redraw()
	_art._heart_layer.queue_redraw()
	_lift()
	_say("HTP_LU_START_CAP" if lesson != Lesson.CATS else "HTP_LU_CAT_CAP")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	match lesson:
		Lesson.HINT:
			_art.hint()
			_say("HTP_LU_PINNED_CAP")
			return
		Lesson.SEE:
			_say("HTP_LU_APART_CAP")
		Lesson.NUMBERS:
			_say("HTP_LU_MET_CAP")
		Lesson.CHIPS:
			for cell in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
				st.marks[cell] = State.CHIP
			_say("HTP_LU_SWEEP_CAP")
		Lesson.HEARTS:
			# The still shows the right lanterns with every heart; the page's
			# body says what a wrong one costs.
			_say("HTP_LU_RIGHT_CAP")
		Lesson.CATS:
			_say("HTP_LU_CAT_ONE_CAP")
		_:
			_say("HTP_LU_ALL_CAP")
	for t: Vector2i in st.solution:
		if st.mark_at(t) != State.LAMP:
			st.marks[t] = State.LAMP
		var lamp: Face = _art._lamp_node(t)
		lamp.visible = true
		lamp.scale = Vector2.ONE
	st.recompute()
	_art._refresh_faces(true)
	_art._settle()
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

## The finger `u` of the way from `a` to `b` (stones), dragging.
func _drag_to(u: float, a: Vector2i, b: Vector2i) -> void:
	var at: Vector2 = _art.cell_to_local(a.y, a.x).lerp(_art.cell_to_local(b.y, b.x), u)
	_finger = at
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
