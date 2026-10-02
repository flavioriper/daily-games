extends Control

## One page of Sudoku's tutorial: the band's own grid (the mini's six by six
## on Easy and Medium, nine by nine on Hard and Insane) played by the board
## itself, with the game's own digit pad, scaled down, standing beside it.
## The page holds a `Sheet` -- sudoku2d.gd with its sounds, tip lines,
## streak, gags, solve and out-of-hearts card taken out -- dealt a fixed
## grid, and plays the lesson on a loop through the board's own input path
## (a tap on a cell, as a finger would) and the pad's own chips (the finger
## fires them), over a caption that says what it means. So a selected cell
## lifts with its row, column and box washed, a number drops in from the
## pad, a finished row lights gold, a clash turns rose, a wrong number on a
## judged band splits a heart and tumbles off, and a hill lights the four
## cells it counts exactly as on the board. `lesson` picks the page (set
## before it enters the tree):
##
## - PLACE: a row missing one number; its cell tapped, the number picked,
##   and the row lights up.
## - MISTAKE (Easy, Medium): a number already in the row turns both rose,
##   and the cross takes it out.
## - HEARTS (Hard, Insane): a wrong number costs a heart, tumbles off, and
##   is crossed out of the cell.
## - HILLS (Insane): a hill held lights the four cells beside it; its dots
##   count the smaller ones, and it turns gold when that comes true.
## - UNDO: Undo takes the last number back; Reset clears every one.
## - HINT: the bulb writes one number of the answer.
##
## The board checkup, 2026-10-02: Sudoku had only the shared one-page card.
## Gen holds one grid size at a time, so the page always plays the size the
## board behind it is on (it is asked for its pages, and Gen is its size).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/sudoku_gen.gd")
const State = preload("res://puzzles/sudoku_state.gd")
const DigitPad = preload("res://ui/flat/digit_pad.gd")

enum Lesson { PLACE, MISTAKE, HEARTS, HILLS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## Air round the grid's tray, and between the grid and the pad.
const EDGE := 18.0
const GAP := 28.0
## The answers, row by row. Six by six (regions two rows by three), and nine
## by nine.
const SOL_6 := "123456456123231564564231312645645312"
const SOL_9 := "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
## Which cells came with the puzzle: row 0 has all but TARGET, so the first
## lesson's question has one answer.
const GIVEN_6 := "xxxx.x" + ".x..x." + "x.x..x" + ".x.x.." + "x...x." + "..x..x"
const GIVEN_9 := "xxxxxx.xx" + "x..x.x..x" + ".xx..x.x." + "x...x...x" + ".x.x.x.x." \
	+ "x...x...x" + ".x..x.x.." + "x..x...x." + ".x.x.x..x"
## The cells the lessons use, as (row, col), per size.
const TARGET := {6: Vector2i(0, 4), 9: Vector2i(0, 6)}
## A slip: this cell's row holds `CLASH_WITH`'s number already.
const SLIP := {6: Vector2i(2, 1), 9: Vector2i(2, 0)}
const CLASH_WITH := {6: Vector2i(2, 0), 9: Vector2i(2, 1)}
const UNDO_AT := {6: Vector2i(1, 0), 9: Vector2i(1, 1)}
## Insane's hills (nine by nine only): the middle one is the lesson's, its
## four neighbours given; the other two keep it company.
const HILL := Vector2i(4, 4)
const HILLS_TOO := [Vector2i(6, 2), Vector2i(2, 7)]
## A hill is a small thing on a nine-by-nine this size: its page looks
## through a window the grid's size, magnified about the hill.
const HILL_ZOOM := 1.9

var lesson: int = Lesson.PLACE
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: Sheet
## The window the grid is seen through (the grid's own square, magnified on
## the hills' page).
var _clip: Control
var _pad: Control
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags, streak
## or solve, and a last heart lost never puts it to sleep -- the loop deals
## the grid again. Laid out by the page: the grid on the left, the hearts
## over the pad on the right.
class Sheet extends "res://puzzles/sudoku2d.gd":
	var left := 0.0
	var hearts_at := Vector2.ZERO

	func puzzle_id() -> String:
		return "sudoku_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right(_i: int, _d: int) -> void:
		pass

	func _wrong_digit(i: int, d: int) -> void:
		super(i, d)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _layout() -> void:
		if state == null:
			return
		_cell = (size.y - 2.0 * EDGE) / float(Gen.N)
		if _cell <= 0.0:
			return
		_grid = Vector2(left, EDGE)
		_hearts_y = hearts_at.y
		_love_mesh = null
		_seal_mesh = null
		_rm.reset()
		_redraw()
		for layer: Control in [_heart_layer, _life_layer, _combo_layer]:
			if layer != null:
				layer.queue_redraw()

	func _hearts_x() -> float:
		return hearts_at.x

	## The grid as the page deals it: `sol` and `given` (strings, row by
	## row), judged as `band` is with every heart of `h`, hills on `hills`
	## (cells), and popped in with the board's entrance when `enter`.
	func lay(b: int, h: int, sol: String, given: String, hill_cells: Array, enter: bool) -> void:
		_gen += 1
		var st := State.new()
		st.band = b
		st.sol = PackedByteArray()
		st.given = PackedByteArray()
		for i in Gen.CELLS:
			st.sol.append(int(sol[i]))
			st.given.append(int(sol[i]) if given[i] == "x" else 0)
		st.grid = st.given.duplicate()
		st.notes = PackedInt32Array()
		st.notes.resize(Gen.CELLS)
		st.history = []
		st.ruled = {}
		st.hints_left = 3
		st.hills = PackedInt32Array()
		if not hill_cells.is_empty():
			st.hills.resize(Gen.CELLS)
			st.hills.fill(-1)
			for cell: Vector2i in hill_cells:
				var i := cell.x * Gen.N + cell.y
				st.hills[i] = Gen.hill_count(st.sol, i)
		state = st
		max_hearts = h
		hints_used = 0
		_deal()
		_sel = -1
		_pencil = false
		_wrong = {}
		_flash = {}
		_bump = {}
		_drop = {}
		_shiver = {}
		_leaving = []
		_fx_due = []
		_won_at = -1.0e9
		_anim_until = 0.0
		_layout()
		if enter:
			_enter()
		else:
			_opened = _now() - 10.0
			_hills_at = _now() - 20.0
		_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_clip = Control.new()
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	add_child(_clip)
	_art = Sheet.new()
	_clip.add_child(_art)
	_pad = DigitPad.new()
	add_child(_pad)
	# The page's chips are the finger's: a real tap on them would write into
	# the lesson.
	for chip: Control in _pad._chips:
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.pick.connect(func(i: int) -> void: _art.pick(i))
	_art.moved.connect(_refresh_pad)
	_art.focus_changed.connect(_refresh_pad)
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

## The grid as tall as the page leaves over the caption, and the pad filling
## what is left beside it, the hearts' pill over it.
func _layout() -> void:
	if _art == null:
		return
	var h := maxf(0.0, size.y - CAPTION_H)
	var field := h - 2.0 * EDGE
	var pad_w := maxf(0.0, size.x - field - GAP - 2.0 * EDGE)
	var k := pad_w / DigitPad.MIN_WIDTH
	var pad_h := DigitPad.HEIGHT * k
	var x0 := (size.x - field - GAP - pad_w) * 0.5
	_art.size = Vector2(size.x, h)
	_art.left = x0
	var pad_at := Vector2(x0 + field + GAP, EDGE + (field - pad_h) * 0.5 + (32.0 if hearts > 0 else 0.0))
	_art.hearts_at = Vector2(pad_at.x + pad_w * 0.5, pad_at.y - 40.0)
	_art._layout()
	# The window: the grid with its tray and the air round it, the hearts'
	# strip over the pad left outside it but for its own lesson.
	_clip.position = Vector2(x0 - EDGE, 0.0) if lesson != Lesson.HEARTS else Vector2.ZERO
	_clip.size = Vector2(field + 2.0 * EDGE, h) if lesson != Lesson.HEARTS else Vector2(size.x, h)
	_frame_art()
	_pad.size = Vector2(DigitPad.MIN_WIDTH, DigitPad.HEIGHT)
	_pad.scale = Vector2(k, k)
	_pad.position = pad_at
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

## The grid under the window: as laid out, or magnified about the hill on
## the hills' page (once the grid is dealt and has a cell to measure).
func _frame_art() -> void:
	var zoom := HILL_ZOOM if lesson == Lesson.HILLS and Gen.N == 9 and _art._cell > 0.0 else 1.0
	_art.scale = Vector2(zoom, zoom)
	_art.position = -_clip.position
	if zoom != 1.0:
		_art.position = _clip.size * 0.5 - _art.cell_to_local(HILL.x, HILL.y) * zoom

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

func _refresh_pad() -> void:
	_pad.refresh(_art)

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
	var n := Gen.N
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.4)
	match lesson:
		Lesson.PLACE:
			_play_cell(_cell(TARGET[n]), "HTP_SD_PICK_CAP")
			_loop.tween_interval(1.4)
			_say_for("HTP_SD_MISSING_CAP", 1.4)
			_play_chip(_answer(TARGET[n]) - 1, "")
			_loop.tween_interval(0.4)
			_say_for("HTP_SD_DONE_CAP", 2.6)
		Lesson.MISTAKE:
			_play_cell(_cell(SLIP[n]), "")
			_play_chip(_answer(CLASH_WITH[n]) - 1, "")
			_loop.tween_interval(0.3)
			_say_for("HTP_SD_CLASH_CAP", 2.4)
			_play_chip(DigitPad.REMOVE, "HTP_SD_CROSS_CAP")
			_loop.tween_interval(1.0)
			_play_chip(_answer(SLIP[n]) - 1, "")
			_loop.tween_interval(1.8)
		Lesson.HEARTS:
			_play_cell(_cell(SLIP[n]), "")
			_play_chip(_answer(CLASH_WITH[n]) - 1, "")
			_loop.tween_interval(0.3)
			_say_for("HTP_SD_WRONG_CAP", 2.4)
			_say_for("HTP_SD_RULED_CAP", 2.6)
		Lesson.HILLS:
			_play_cell(_cell(HILL), "HTP_SD_HILL_CAP")
			_loop.tween_interval(1.8)
			_say_for(tr("HTP_SD_DOTS_CAP") % _art.state.hills[_cell(HILL)], 2.4)
			_play_chip(_answer(HILL) - 1, "")
			_loop.tween_interval(0.4)
			_say_for("HTP_SD_TRUE_CAP", 2.6)
		Lesson.UNDO:
			_play_cell(_cell(UNDO_AT[n]), "")
			_play_chip(_answer(UNDO_AT[n]) - 1, "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_SD_UNDO_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(1.6)
			_play_chip(_answer(UNDO_AT[n]) - 1, "")
			_play_cell(_cell(SLIP[n]), "")
			_play_chip(_answer(SLIP[n]) - 1, "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_SD_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.6)
	_loop.tween_callback(_reset)

## The caption turned to `key` (a key, or words already made) for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## A tap on cell `i`: the finger comes down there, the caption turns to
## `say` (when not ""), and lets go.
func _play_cell(i: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point_cell.bind(i))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_tap_cell.bind(i))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.3)

## The finger taps the pad's chip `k` (0..8 the digits, REMOVE the cross).
func _play_chip(k: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point_chip.bind(k))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void:
		_down = true
		(_pad._chips[k] as Button).pressed.emit())
	_loop.tween_interval(0.2)
	_loop.tween_callback(func() -> void: _down = false)
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## Every lesson back to its question: the grid as dealt with what the lesson
## starts from, every heart, nothing in flight. `fresh` is the first deal,
## which pops the grid in with the board's entrance.
func _reset(fresh := false) -> void:
	var n := Gen.N
	var sol: String = SOL_9 if n == 9 else SOL_6
	var given: String = GIVEN_9 if n == 9 else GIVEN_6
	var h := 0
	var hills: Array = []
	match lesson:
		Lesson.HEARTS:
			h = hearts
		Lesson.HILLS:
			hills = [HILL] + HILLS_TOO
	_art.lay(band, h, sol, given, hills, fresh)
	_frame_art()
	_refresh_pad()
	_lift()
	_say({Lesson.MISTAKE: "HTP_SD_RULE_CAP", Lesson.HEARTS: "HTP_SD_JUDGED_CAP",
		Lesson.HILLS: "HTP_SD_HILL_CAP", Lesson.UNDO: "HTP_SD_WRITE_CAP",
		Lesson.HINT: "HTP_SD_HINT_CAP"}.get(lesson, "HTP_SD_RULE_CAP"))

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var n := Gen.N
	match lesson:
		Lesson.PLACE:
			_art._sel = _cell(TARGET[n])
			_art.pick(_answer(TARGET[n]) - 1)
			_say("HTP_SD_DONE_CAP")
		Lesson.MISTAKE:
			_art._sel = _cell(SLIP[n])
			_art.pick(_answer(CLASH_WITH[n]) - 1)
			_say("HTP_SD_CLASH_CAP")
		Lesson.HEARTS:
			_art._sel = _cell(SLIP[n])
			_art.pick(_answer(CLASH_WITH[n]) - 1)
			_say("HTP_SD_RULED_CAP")
		Lesson.HILLS:
			_art._sel = _cell(HILL)
			_say(tr("HTP_SD_DOTS_CAP") % _art.state.hills[_cell(HILL)])
		Lesson.UNDO:
			_say("HTP_SD_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
	_refresh_pad()
	_art._redraw()

## `key` through tr: a key, or words already made (tr hands those back).
func _say(key: String) -> void:
	var line := tr(key)
	_caption.text = line % Gen.N if line.contains("%d") else line

func _cell(at: Vector2i) -> int:
	return at.x * Gen.N + at.y

## The answer's number at `at`.
func _answer(at: Vector2i) -> int:
	var sol: String = SOL_9 if Gen.N == 9 else SOL_6
	return int(sol[_cell(at)])

# --- the moves, through the board's and the pad's own input ---

func _point_cell(i: int) -> void:
	_finger = _clip.position + _art.position + _art.cell_to_local(Gen.row_of(i), Gen.col_of(i)) * _art.scale
	_down = false

func _tap_cell(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _art.cell_to_local(Gen.row_of(i), Gen.col_of(i))
	_down = true
	_art._gui_input(ev)

func _point_chip(k: int) -> void:
	var chip: Control = _pad._chips[k]
	_finger = get_global_transform().affine_inverse() * (chip.get_global_transform() * (chip.size * 0.5))
	_down = false

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
