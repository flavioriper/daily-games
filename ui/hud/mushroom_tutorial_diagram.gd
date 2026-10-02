extends Control

## One page of Mushroom Patch's tutorial: a little patch of 5 by 5 planted by
## the board itself. The page holds a `Patch` -- mushroom2d.gd with its
## sounds, tip lines, streak, gags, solve and out-of-hearts card taken out --
## dealt a fixed patch of five mushrooms, and plays the lesson on a loop
## through the board's own input path (a press, motions, a release in board
## coordinates, as a finger would), over a caption that says what it means.
## Beside the patch stands a little tray of the two chips, the armed one
## rimmed in gold as on the board, and the finger taps it to switch. So a
## number lights what it counts, washes green when its count holds, a stroke
## lays pebbles, a wrong mushroom wilts with a heart and a fairy ring counts
## two steps out exactly as on the board. `lesson` picks the page (set before
## it enters the tree):
##
## - COUNT: a number held lights the cells it counts; the one still covered
##   is planted, and the number turns green.
## - PEBBLE: a number with its mushroom has the rest of its cells empty: the
##   pebble chip, a stroke lays pebbles, a stroke from a pebble rubs them out.
## - RINGS: Fairy Rings (Insane): a number in a ring held lights the ring two
##   steps out, and nothing touching it.
## - HEARTS: on a judged band (`hearts`, the band's count), a mushroom where
##   none grows costs a heart, wilts and leaves a pebble for good.
## - UNDO: Undo takes back a whole stroke; Reset clears the patch.
## - HINT: the bulb plants a mushroom and pins it; a tap on her is refused.
##
## The board checkup, 2026-10-02: Mushroom Patch had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Mosaic = preload("res://ui/faces/mosaic_tile.gd")
const State = preload("res://puzzles/mushroom_state.gd")

enum Lesson { COUNT, PEBBLE, RINGS, HEARTS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a stroke takes per cell it crosses.
const CELL_TIME := 0.18
## The patch: five mushrooms, and the cells turned over to show their
## numbers (counted from the mushrooms as the page deals it). The 1 at the
## top touches one covered cell, (2, 0); the 1 under it has her and so
## leaves (1, 2) to (3, 2) empty.
const SIDE := 5
const MUSHROOMS := [Vector2i(2, 0), Vector2i(4, 1), Vector2i(0, 3), Vector2i(3, 4), Vector2i(4, 4)]
const GIVEN := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(1, 3), Vector2i(4, 3)]
## Fairy Rings turns the middle over too, in a ring: it counts the patch's
## rim, two steps out.
const RING := Vector2i(2, 2)
const TOP_ONE := Vector2i(1, 0)
const FIRST := Vector2i(2, 0)
const SIDE_ONE := Vector2i(2, 1)
const ROW_FROM := Vector2i(1, 2)
const ROW_TO := Vector2i(3, 2)
const WRONG := Vector2i(3, 1)
## The chip tray: each chip a cell and a bit across, a gap between them.
const CHIP := 1.15
const CHIP_GAP := 0.3
const CHIP_RIM := 4.0
const CHIP_SHIFT := 0.9

var lesson: int = Lesson.COUNT
## HEARTS: how many hearts the band has (Hard 3, Insane 2).
var hearts := 3

var _art: Patch
var _over: Control
var _caption: Label
var _chip_face: MushroomFace
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## streak or solve, and a last heart lost never puts it to sleep -- the loop
## deals the patch again.
class Patch extends "res://puzzles/mushroom2d.gd":
	func puzzle_id() -> String:
		return "mushroom_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right_plant(_cell: Vector2i, _land: float) -> void:
		pass

	func _wrong_plant(cell: Vector2i, land: float) -> void:
		super(cell, land)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	## No card round it and no tally strip over it, so the little patch can
	## be as big as the page lets it.
	func _pad() -> float:
		return 4.0

	func _tally_h() -> float:
		return 0.0

	func _draw_tally(_now: float) -> void:
		pass

	func _tally_pill(_b: Face.Builder, _now: float) -> void:
		pass

	func _layout_tally() -> void:
		if _tally_face != null:
			_tally_face.visible = false

	## The patch as the page deals it: judged as `band` is with every heart
	## of `h`, the middle a fairy ring when `ring`, `found` planted, and the
	## patch popped in with the board's entrance when `enter`.
	func lay(band: int, h: int, ring: bool, found: Array, enter: bool) -> void:
		_stop_all()
		var st = state
		st.band = band
		st.n = SIDE
		st.k = MUSHROOMS.size()
		st.mushrooms = {}
		for cell: Vector2i in MUSHROOMS:
			st.mushrooms[cell] = true
		st.rings = {}
		st.given = {}
		for cell: Vector2i in GIVEN:
			st.given[cell] = 0
		if ring:
			st.given[RING] = 0
			st.rings[RING] = true
		for cell in st.given:
			st.given[cell] = st.count(cell)
		st.marks = {}
		st.pinned = {}
		st.shown = {}
		st.history = []
		for cell: Vector2i in found:
			st.marks[cell] = State.FOUND
		max_hearts = h
		hints_used = 0
		hints_extra = 0
		_deal()
		_frm.reset()
		_grm.reset()
		_ref = 0.0
		brush = State.FOUND
		_pebble_in = {}
		_pebble_out = []
		_wash = {}
		_bump = {}
		_blush = {}
		_shiver = {}
		_wobble = {}
		_sunk = {}
		_sod = {}
		_glint = {}
		_clear_gesture()
		_solved_at = -1.0
		_build_pieces()
		_layout()
		for cell: Vector2i in found:
			var face := _cap_node(cell)
			face.visible = true
			face.scale = Vector2.ONE
			face.modulate.a = 1.0
		_refresh_faces()
		if enter:
			_enter()
		else:
			_rings_at = _now() - 20.0
		_sway_timer.start()
		_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Patch.new()
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 4
	_over.draw.connect(_draw_over)
	add_child(_over)
	_chip_face = MushroomFace.new()
	_chip_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_face.z_index = 5
	add_child(_chip_face)
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

## The patch is shifted left of the middle to make room for the chip tray
## on its right, on the pages that switch chips.
func _layout() -> void:
	if _art == null:
		return
	var shift := 0.0
	if _tray_shown() and _art._cell > 0.0:
		shift = -_art._cell * CHIP_SHIFT
	_art.position = Vector2(shift, 0.0)
	_art.size = Vector2(size.x, maxf(0.0, size.y - 96.0))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	_layout_chips()
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	_layout()
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.4)
	match lesson:
		Lesson.COUNT:
			_play_hold(TOP_ONE, "HTP_MP_COUNTS_CAP")
			_loop.tween_callback(_say.bind("HTP_MP_ONLY_CAP"))
			_loop.tween_interval(1.6)
			_play_tap(FIRST, "")
			_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_MP_GREEN_CAP"))
			_loop.tween_interval(2.6)
		Lesson.PEBBLE:
			_play_hold(SIDE_ONE, "HTP_MP_HAS_CAP")
			_play_chip(State.CLEAR, "HTP_MP_EMPTY_CAP")
			_play_stroke(ROW_FROM, ROW_TO, "")
			_loop.tween_interval(1.6)
			_play_stroke(ROW_FROM, ROW_TO, "HTP_MP_RUB_CAP")
			_loop.tween_interval(1.4)
			_play_chip(State.FOUND, "")
			_loop.tween_interval(0.8)
		Lesson.RINGS:
			_play_hold(RING, "HTP_MP_RING_CAP", 2.6)
			_loop.tween_callback(_say.bind("HTP_MP_RING_NOT_CAP"))
			_loop.tween_interval(1.0)
			_play_hold(Vector2i(1, 1), "", 1.6)
			_loop.tween_interval(1.0)
		Lesson.HEARTS:
			_loop.tween_callback(_say.bind("HTP_MP_JUDGED_CAP"))
			_loop.tween_interval(0.6)
			_play_tap(WRONG, "")
			_loop.tween_interval(0.5)
			_loop.tween_callback(_say.bind("HTP_MP_WRONG_CAP"))
			_loop.tween_interval(2.4)
			_loop.tween_callback(_say.bind("HTP_MP_SHOWN_CAP"))
			_loop.tween_interval(2.4)
		Lesson.UNDO:
			_play_chip(State.CLEAR, "")
			_play_stroke(ROW_FROM, ROW_TO, "")
			_loop.tween_interval(1.0)
			_loop.tween_callback(_say.bind("HTP_MP_UNDO_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(1.8)
			_play_chip(State.FOUND, "")
			_play_tap(FIRST, "")
			_loop.tween_interval(1.0)
			_loop.tween_callback(_say.bind("HTP_MP_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(_art.reset_board)
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_MP_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.0)
			_play_tap(FIRST, "HTP_MP_PINNED_CAP")
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## A tap on `cell`: the finger comes down, the caption turns to `say` (when
## not ""), and lets go.
func _play_tap(cell: Vector2i, say: String) -> void:
	_play_stroke(cell, cell, say)

## A finger held on `cell` for `hold` seconds, the caption turned to `say`
## (when not ""): a number held lights what it counts.
func _play_hold(cell: Vector2i, say: String, hold := 2.2) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(cell))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(cell, true))
	_loop.tween_interval(hold)
	_loop.tween_callback(_button.bind(cell, false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.3)

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

## The finger taps the tray's chip `kind` and arms it.
func _play_chip(kind: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(func() -> void:
		_finger = _chip_at(kind) - _art.position
		_down = false)
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void:
		_down = true
		_art.set_brush(kind))
	_loop.tween_interval(0.2)
	_loop.tween_callback(func() -> void: _down = false)
	_loop.tween_interval(0.3)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## Every lesson back to its question: the patch with what the lesson starts
## from, every heart, the mushroom chip armed, nothing in flight. `fresh` is
## the first deal, which pops the patch in with the board's entrance.
func _reset(fresh := false) -> void:
	var found: Array = []
	var band := 0
	var h := 0
	var ring := false
	match lesson:
		Lesson.PEBBLE:
			found = [FIRST]
		Lesson.RINGS:
			band = 3
			ring = true
		Lesson.HEARTS:
			band = 2
			h = hearts
		Lesson.UNDO:
			found = [Vector2i(4, 4)]
	_art.lay(band, h, ring, found, fresh)
	_lift()
	_say({Lesson.PEBBLE: "HTP_MP_HAS_CAP", Lesson.RINGS: "HTP_MP_RING_CAP",
		Lesson.HEARTS: "HTP_MP_JUDGED_CAP", Lesson.UNDO: "HTP_MP_STROKE_CAP",
		Lesson.HINT: "HTP_MP_HINT_CAP"}.get(lesson, "HTP_MP_COUNTS_CAP"))

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	var plant := func(cells: Array) -> void:
		for cell: Vector2i in cells:
			st.marks[cell] = State.FOUND
			var face: Control = _art._cap_node(cell)
			face.visible = true
			face.scale = Vector2.ONE
	match lesson:
		Lesson.COUNT:
			plant.call([FIRST])
			_say("HTP_MP_GREEN_CAP")
		Lesson.PEBBLE:
			for x in range(ROW_FROM.x, ROW_TO.x + 1):
				st.marks[Vector2i(x, ROW_FROM.y)] = State.CLEAR
			_art.set_brush(State.CLEAR)
			_say("HTP_MP_EMPTY_CAP")
		Lesson.RINGS:
			_art._reach = {"cell": RING, "down": -INF, "up": INF}
			_say("HTP_MP_RING_CAP")
		Lesson.HEARTS:
			st.reveal(WRONG)
			_art.hearts = maxi(0, hearts - 1)
			_art._heart_layer.queue_redraw()
			_say("HTP_MP_SHOWN_CAP")
		Lesson.UNDO:
			_say("HTP_MP_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_MP_PINNED_CAP")
			return
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

# --- the chip tray ---

## Whether this page shows the tray: the pages whose finger switches chips.
func _tray_shown() -> bool:
	return lesson == Lesson.PEBBLE or lesson == Lesson.UNDO

## The centre of chip `kind` in this page's space: the mushroom over the
## pebble, right of the patch.
func _chip_at(kind: int) -> Vector2:
	var cell: float = _art._cell
	var field: float = cell * SIDE
	var x: float = _art.position.x + _art._grid.x + field + cell * (CHIP_SHIFT + CHIP * 0.5)
	var y: float = _art._grid.y + field * 0.5
	var step := cell * (CHIP + CHIP_GAP) * 0.5
	return Vector2(x, y - step if kind == State.FOUND else y + step)

func _layout_chips() -> void:
	_chip_face.visible = _tray_shown() and _art._cell > 0.0
	if not _chip_face.visible:
		return
	var px := _art._cell * CHIP * 0.8
	_chip_face.size = Vector2.ONE * px
	_chip_face.position = _chip_at(State.FOUND) - _chip_face.size * 0.5

# --- drawing ---

## The chip tray and the finger, over the patch.
func _draw_over() -> void:
	var cell: float = _art._cell
	if cell <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	if _tray_shown():
		for kind in [State.FOUND, State.CLEAR]:
			var armed: bool = _art.brush == kind
			var at := _chip_at(kind)
			var side := cell * CHIP
			var corner := at - Vector2.ONE * (side * 0.5)
			if armed:
				b.fan(Face.Builder.round_rect(corner - Vector2.ONE * CHIP_RIM, Vector2.ONE * (side + CHIP_RIM * 2.0),
					side * 0.24 + CHIP_RIM), Pal.SUN)
			b.fan(Face.Builder.round_rect(corner, Vector2.ONE * side, side * 0.24),
				Pal.SURFACE if armed else Pal.SURFACE_HI)
			if kind == State.CLEAR:
				Mosaic.pebble(b, at, cell * 0.9, Vector2.ONE, 1.0)
	if _finger.x >= 0.0:
		var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
		var r := cell * FINGER_R * (0.85 if _down else 1.0)
		b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	if b.verts.is_empty():
		_finger_shown = null
		return
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
