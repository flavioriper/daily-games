extends Control

## One page of Picket Sums' tutorial: the band's own size of grid (the six
## by six on Easy and Medium, the nine on Hard and Insane), fenced into
## plots and played by the board itself, with the game's own digit pad,
## scaled down, beside it. Sudoku's page (ui/hud/sudoku_tutorial_diagram.gd)
## with plots: the page holds a `Sheet` -- picket2d.gd with its sounds, tip
## lines and solve taken out -- dealt a fixed grid, and plays the lesson on a
## loop through the board's own input path and the pad's own chips, over a
## caption. `lesson` picks the page (set before it enters the tree):
##
## - PLOT: a plot with one number missing; its tag less what it holds is the
##   number, and the plot lights up when it comes right.
## - LINES: a row missing one number, Sudoku's own rule.
## - LOST (Insane): a plot whose tag is lost: its numbers only never repeat.
## - UNDO: Undo takes the last number back; Reset clears every one.
## - HINT: the bulb writes one number of the answer.
##
## Gen holds one grid size at a time, so the page plays the size the board
## behind it is on. The six's plots are drawn by hand; the nine's are fenced
## once from a fixed seed (PG.fence).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/sudoku_gen.gd")
const PG = preload("res://puzzles/picket_gen.gd")
const State = preload("res://puzzles/picket_state.gd")
const DigitPad = preload("res://ui/flat/digit_pad.gd")

enum Lesson { PLOT, LINES, LOST, UNDO, HINT }

const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
const EDGE := 18.0
const GAP := 28.0
## Sudoku's lesson answers, row by row.
const SOL_6 := "123456456123231564564231312645645312"
const SOL_9 := "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
## Which cells came with the puzzle (Sudoku's page's).
const GIVEN_6 := "xxxx.x" + ".x..x." + "x.x..x" + ".x.x.." + "x...x." + "..x..x"
const GIVEN_9 := "xxxxxx.xx" + "x..x.x..x" + ".xx..x.x." + "x...x...x" + ".x.x.x.x." \
	+ "x...x...x" + ".x..x.x.." + "x..x...x." + ".x.x.x..x"
## The six's plots, a letter a plot (the roadmap page's mock).
const PLOTS_6 := "aabbcc" + "deebfc" + "dgghfi" + "jjghki" + "lmmnki" + "lopnqq"
## The nine's fencing seed.
const FENCE_SEED := 20261022
## The row the LINES lesson finishes, as (row, col) per size.
const TARGET := {6: Vector2i(0, 4), 9: Vector2i(0, 6)}
const UNDO_AT := {6: Vector2i(1, 0), 9: Vector2i(1, 1)}
const SLIP := {6: Vector2i(2, 1), 9: Vector2i(2, 0)}

var lesson: int = Lesson.PLOT
var band := 0

var _art: Sheet
var _clip: Control
var _pad: Control
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)
var _down := false
var _finger_shown: ArrayMesh
## The page's plots: each cell's plot, and the lesson's plot and cell.
var _cage_of := PackedInt32Array()
var _plot := -1
var _target := -1

## The board, quiet: no sound set (its id names none), no tips or solve.
class Sheet extends "res://puzzles/picket2d.gd":
	var left := 0.0

	func puzzle_id() -> String:
		return "picket_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right(_i: int, _d: int) -> void:
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
		_love_mesh = null
		_seal_mesh = null
		_fence_key = ""
		_rm.reset()
		_redraw()

	## The grid as the page deals it: `sol` and `given` (strings, row by
	## row), fenced as `cage_of` says with `lost` plots' tags gone, and
	## popped in with the board's entrance when `enter`.
	func lay(b: int, sol: String, given: String, cage_of: PackedInt32Array, lost: Array, enter: bool) -> void:
		_gen += 1
		var st := PicketState.new()
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
		st.cage_of = cage_of
		st.plots = PG.plots_of(cage_of)
		st.sums = PackedInt32Array()
		for p in st.plots.size():
			var s := 0
			for i in st.plots[p]:
				s += st.sol[i]
			st.sums.append(-1 if lost.has(p) else s)
		state = st
		max_hearts = 0
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
		_stand = state.standings()
		_tag_hop = {}
		_tag_shake = {}
		_layout()
		if enter:
			_enter()
		else:
			_opened = _now() - 10.0
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
	var pad_at := Vector2(x0 + field + GAP, EDGE + (field - pad_h) * 0.5)
	_art._layout()
	# The window: the grid with its tray and the air round it.
	_clip.position = Vector2(x0 - EDGE, 0.0)
	_clip.size = Vector2(field + 2.0 * EDGE, h)
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

## The grid under the window, as laid out.
func _frame_art() -> void:
	_art.scale = Vector2.ONE
	_art.position = -_clip.position

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
		Lesson.PLOT:
			_play_cell(_target, "HTP_PK_TAG_CAP")
			_loop.tween_interval(1.2)
			_say_for(_take_line(), 1.8)
			_play_chip(_answer_of(_target) - 1, "")
			_loop.tween_interval(0.4)
			_say_for("HTP_PK_DONE_CAP", 2.6)
		Lesson.LINES:
			_play_cell(_target, "HTP_SD_PICK_CAP")
			_loop.tween_interval(1.4)
			_say_for("HTP_SD_MISSING_CAP", 1.4)
			_play_chip(_answer_of(_target) - 1, "")
			_loop.tween_interval(0.4)
			_say_for("HTP_SD_DONE_CAP", 2.6)
		Lesson.LOST:
			_play_cell(_target, "HTP_PK_LOST_CAP")
			_loop.tween_interval(1.4)
			_say_for("HTP_PK_ONCE_CAP", 1.6)
			_play_chip(_answer_of(_target) - 1, "")
			_loop.tween_interval(2.2)
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
## starts from, nothing in flight. `fresh` is the first deal, which pops the
## grid in with the board's entrance.
func _reset(fresh := false) -> void:
	var n := Gen.N
	var sol: String = SOL_9 if n == 9 else SOL_6
	var given := (GIVEN_9 if n == 9 else GIVEN_6).to_ascii_buffer()
	_fences()
	var lost: Array = []
	match lesson:
		Lesson.PLOT, Lesson.LOST:
			_plot = _pick_plot(3 if lesson == Lesson.LOST else 2)
			var cells: PackedInt32Array = PG.plots_of(_cage_of)[_plot]
			_target = cells[cells.size() - 1]
			for i in cells:
				given[i] = "x".unicode_at(0)
			given[_target] = ".".unicode_at(0)
			if lesson == Lesson.LOST:
				lost = [_plot]
		Lesson.LINES:
			_target = _cell(TARGET[n])
	_art.lay(band, sol, given.get_string_from_ascii(), _cage_of, lost, fresh)
	_frame_art()
	_refresh_pad()
	_lift()
	_say({Lesson.PLOT: "HTP_PK_RULE_CAP", Lesson.LINES: "HTP_SD_RULE_CAP",
		Lesson.LOST: "HTP_PK_LOST_CAP", Lesson.UNDO: "HTP_SD_WRITE_CAP",
		Lesson.HINT: "HTP_SD_HINT_CAP"}.get(lesson, "HTP_PK_RULE_CAP"))

## The page's plots, for the size Gen is on.
func _fences() -> void:
	if _cage_of.size() == Gen.CELLS:
		return
	if Gen.N == 6:
		_cage_of = PackedInt32Array()
		var ids := {}
		for ch in PLOTS_6:
			if not ids.has(ch):
				ids[ch] = ids.size()
			_cage_of.append(ids[ch])
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = FENCE_SEED
	var sol := PackedByteArray()
	for ch in SOL_9:
		sol.append(int(ch))
	_cage_of = PG.fence(rng, sol, [2, 2, 3])

## The first plot of `want` cells clear of the top row (where LINES works),
## else the first of two or more.
func _pick_plot(want: int) -> int:
	var plots := PG.plots_of(_cage_of)
	for p in plots.size():
		if plots[p].size() == want and Gen.row_of(plots[p][0]) > 0:
			return p
	for p in plots.size():
		if plots[p].size() >= 2:
			return p
	return 0

## "7 − 4 = 3": the tag, what the plot holds, and what is left.
func _take_line() -> String:
	var cells: PackedInt32Array = PG.plots_of(_cage_of)[_plot]
	var tag := 0
	var have := 0
	for i in cells:
		tag += _answer_of(i)
		if i != _target:
			have += _answer_of(i)
	return tr("HTP_PK_TAKE_CAP") % [tag, have, tag - have]

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var n := Gen.N
	match lesson:
		Lesson.PLOT, Lesson.LINES, Lesson.LOST:
			_art._sel = _target
			_art.pick(_answer_of(_target) - 1)
			_say({Lesson.PLOT: "HTP_PK_DONE_CAP", Lesson.LINES: "HTP_SD_DONE_CAP"}.get(lesson, "HTP_PK_ONCE_CAP"))
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
	return _answer_of(_cell(at))

func _answer_of(i: int) -> int:
	var sol: String = SOL_9 if Gen.N == 9 else SOL_6
	return int(sol[i])

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
