extends Control

## One page of Super Slider's tutorial: a small tray played by the board
## itself. The page holds a `Board` -- slider2d.gd with its sounds, tip
## lines, toasts, streak, gags, party and out-of-hearts card taken out --
## dealt a hand-made tray, and plays the lesson on a loop through the
## board's own input path (a press on a block, a motion a cell at a time
## along the way it slides, the release, in board coordinates, as a finger
## would), over a caption that says what it means. So a held block lifts and
## glides, the red block watches it and sweats, a heart splits and the block
## slides back, the red block shakes its head, and the gate's doors swing
## open and the red block walks out, exactly as on the board. `lesson` picks
## the page (set before it enters the tree):
##
## - SLIDE: two squares slid aside, one cell each, then the red block down
##   into the gate and out.
## - CORNER: a square taken down and round a corner in one drag -- the count
##   says one move --, the other the same, then the red block out.
## - HEARTS (Hard): a bar held over the gate's way and the red block
##   sweats; let go, a heart and it slides back; then the way out.
## - HOMESICK (Insane): the red block dragged up shakes its head; brought
##   down a cell too soon it can never get home: a heart, and it slides back.
##   Then a move that makes room.
## - UNDO: a slide, Undo takes it back, Reset puts every block back (Reset
##   alone on Insane, which has no Undo).
## - HINT: the bulb slides the next block of the shortest way, three times,
##   and the red block walks out.
##
## The board checkup, 2026-10-02: Super Slider had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/slider_gen.gd")

enum Lesson { SLIDE, CORNER, HEARTS, HOMESICK, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.22
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How long the finger takes over each cell of a drag, and how long a slide
## plays out after its release.
const CELL_TIME := 0.16
const SETTLE := 0.7
## The win plays out (the mat, the doors, the walk out) before the loop
## starts again.
const WIN_WAIT := 2.6

## The trays, twenty cell codes in reading order (puzzles/slider_gen.gd),
## each checked against the solver (two-way and Homesick):
##
## SLIDE (and HEARTS, UNDO): the red block at the top, two squares under it,
## room either side of them. Shortest 3: each square aside, the red down.
## Hard's setback is the bottom-left bar slid under the gate (3 -> 4). Every
## tray is crowded on purpose: an open tray's graph is huge (the first try,
## with eight empty cells, was 288k positions and 6 s to solve; these are
## 20-46k, under a second, and solved once a session -- `Board._solved`).
##
##      V R R V
##      V R R V
##      . S S .
##      V . . V
##      V . . V
const SLIDE_TRAY := "26723773011020023003"
const SLIDE_PAR := 3
const SLIDE_LINE := [[9, 8], [10, 11], [1, 5, 9, 13]]
const SETBACK := [12, 13]
## CORNER (and HINT): bars down both sides, so each square has to go down
## and round a corner to get out of the red block's way. Shortest 3.
##
##      V R R V
##      V R R V
##      V S S V
##      V . . V
##      . . . .
const CORNER_TRAY := "26723773211230030000"
const CORNER_PAR := 3
const CORNER_LINE := [[9, 13, 17, 16], [10, 14, 18, 19], [1, 5, 9, 13]]
## HOMESICK: a crowded tray ten moves from home (the shallowest dead end in
## the Insane bank's graphs: none comes nearer). The red block on the left,
## two cells free under it: a cell down and it can never get home.
##
##      V V V S
##      V V V S
##      R R V S
##      R R V S
##      . . S S
const HOME_TRAY := "22213331672177310011"
const HOME_PAR := 10
const HOME_RED := 8
const HOME_DOWN := [8, 12]

var lesson: int = Lesson.SLIDE
## The band the board behind the page is on.
var band := 0

var _art: Board
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips or toasts,
## no streak, gags, party or out-of-hearts card, and a last heart lost never
## puts it to sleep -- the loop deals the tray again. The count line stands
## left of the tray and the hearts right of it: the page is wide and short.
class Board extends "res://puzzles/slider2d.gd":
	const SIDE_FONT := 26
	## Each tray's solve, kept for the session: a page loops, and turning
	## back to it deals the same tray again.
	static var _solved := {}

	func puzzle_id() -> String:
		return "slider_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_key: String, _mood: int) -> void:
		pass

	func _on_nearer(_p: int, _land: float, _left: int) -> void:
		pass

	func _party() -> void:
		pass

	func _lose_heart(at: float) -> void:
		super(at)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _inset() -> float:
		return 10.0

	func _top_band() -> float:
		return 0.0

	func _count_font() -> int:
		return SIDE_FONT

	## Left of the tray's frame, halfway down it.
	func _count_spot(w: float, font: Font) -> Vector2:
		var left := _origin().x - Block.FRAME * _cell()
		var mid := _origin().y + _grid_size().y * 0.5
		return Vector2(maxf(4.0, (left - w) * 0.5), mid + font.get_ascent(SIDE_FONT) * 0.5)

	## Right of the tray's frame, halfway down it.
	func _hearts_mid(_pill: Vector2) -> Vector2:
		var right := _origin().x + _grid_size().x + Block.FRAME * _cell()
		return Vector2((right + size.x) * 0.5, _origin().y + _grid_size().y * 0.5)

	## Tray `code` as the page deals it on band `b`: Homesick on Insane,
	## every heart, `par` the day's shortest for the count line, and popped
	## in with the board's entrance when `enter`.
	func lay(code: String, par: int, b: int, enter: bool) -> void:
		_close_card()
		var k := Gen.decode(code)
		_state.difficulty = b
		_state.homesick = b >= 3
		_state.start_key = k
		_state.key = k
		_state.par = par
		_state.band = b
		_state.blocks = Gen.blocks(k)
		_state.start_blocks = _state.blocks.duplicate(true)
		_state.history.clear()
		var key := "%s|%d" % [code, int(_state.homesick)]
		var box: Dictionary = _solved.get(key, {})
		if not box.get("r", {}).is_empty() and not box.get("stop", false):
			_state.abandon()
			_state._box = box
		else:
			_state.solve_async()
			_solved[key] = _state._box
		max_hearts = State.hearts_for(b)
		hints_used = 0
		# the bulb page plays the whole way, whatever the band allows
		hints_extra = 3
		moves = 0
		_done = false
		_running = true
		_heart_used = false
		_lost_ever = false
		_undo_ever = false
		_flawless = false
		_deal()
		_reset_rewards()
		_opened = _now() if enter else _now() - 10.0
		_blink_at = _opened + 2.0
		_layout()
		_tip_timer.stop()
		_heart_layer.queue_redraw()
		_life_layer.queue_redraw()

	## Control-local centre of the cell a block anchored at `c` is held by.
	func cell_mid(c: int) -> Vector2:
		return _pt(Vector2(c % Gen.COLS, c / Gen.COLS) + Vector2(0.5, 0.5))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Board.new()
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

## The board as tall as the page leaves over the caption and the page's
## whole width: the board centres its own tray.
func _layout() -> void:
	if _art == null:
		return
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, maxf(0.0, size.y - CAPTION_H))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

func _tray() -> Array:
	match lesson:
		Lesson.CORNER, Lesson.HINT:
			return [CORNER_TRAY, CORNER_PAR]
		Lesson.HOMESICK:
			return [HOME_TRAY, HOME_PAR]
	return [SLIDE_TRAY, SLIDE_PAR]

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the tray again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	_run()

## The lesson's loop, once the tray's solver is done: every move is judged
## by its distances (a phone may take a few seconds over the first solve).
func _run() -> void:
	if not is_inside_tree() or (_loop != null and _loop.is_valid()):
		return
	if not _art._state.solver_ready():
		get_tree().create_timer(0.1).timeout.connect(_run)
		return
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.6)
	match lesson:
		Lesson.SLIDE:
			_drag(SLIDE_LINE[0], "HTP_SL_DRAG_CAP", "")
			_drag(SLIDE_LINE[1], "HTP_SL_ASIDE_CAP", "")
			_drag(SLIDE_LINE[2], "HTP_SL_DOWN_CAP", "")
			_say_for("HTP_SL_OUT_CAP", WIN_WAIT)
		Lesson.CORNER:
			_drag(CORNER_LINE[0], "HTP_SL_ROUND_CAP", "HTP_SL_ONE_CAP", 1.4)
			_drag(CORNER_LINE[1], "", "")
			_drag(CORNER_LINE[2], "HTP_SL_DOWN_CAP", "")
			_say_for("HTP_SL_OUT_CAP", WIN_WAIT)
		Lesson.HEARTS:
			_drag(SETBACK, "HTP_SL_SWEAT_CAP", "HTP_SL_HEART_CAP", 2.2, 0.9)
			_drag(SLIDE_LINE[0], "HTP_SL_CALM_CAP", "")
			_drag(SLIDE_LINE[1], "", "")
			_drag(SLIDE_LINE[2], "HTP_SL_DOWN_CAP", "")
			_say_for("HTP_SL_OUT_CAP", WIN_WAIT)
		Lesson.HOMESICK:
			_drag([HOME_RED, HOME_RED - Gen.COLS], "HTP_SL_UP_CAP", "HTP_SL_NEVER_CAP", 1.4, 0.5)
			_drag(HOME_DOWN, "HTP_SL_SOON_CAP", "HTP_SL_STUCK_CAP", 2.6)
			_loop.tween_callback(_say.bind("HTP_SL_ROOM_CAP"))
			_loop.tween_callback(_drag_hint)
			_loop.tween_interval(_hint_time())
			_loop.tween_interval(1.2)
		Lesson.UNDO:
			_drag(SLIDE_LINE[0], "HTP_SL_SLIDE_CAP", "", SETTLE + 0.4)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_SL_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.2)
				_drag(SLIDE_LINE[0], "", "", SETTLE)
			_drag(SLIDE_LINE[1], "", "", SETTLE + 0.3)
			_loop.tween_callback(_say.bind("HTP_SL_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_SL_HINT_CAP"))
			for k in 3:
				_loop.tween_interval(0.4)
				_loop.tween_callback(func() -> void: _art.hint())
				_loop.tween_interval(1.1)
			_say_for("HTP_SL_OUT_CAP", WIN_WAIT)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger drags the block anchored at `path[0]` through `path`'s
## anchors, a cell at a time: the caption turns to `before` as it comes and
## to `after` once it lets go; it holds `hold` before letting go, and the
## slide plays out for `wait`.
func _drag(path: Array, before: String, after: String, wait := SETTLE, hold := 0.12) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_art.cell_mid(path[0])))
	_loop.tween_interval(0.45)
	_loop.tween_callback(_press.bind(path[0], true))
	_loop.tween_interval(0.15)
	for k in range(1, path.size()):
		_loop.tween_method(_glide.bind(int(path[k - 1]), int(path[k])), 0.0, 1.0, CELL_TIME)
	_loop.tween_interval(hold)
	_loop.tween_callback(_press.bind(path[path.size() - 1], false))
	if after != "":
		_loop.tween_callback(_say.bind(after))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## Homesick's last beat: the next move of the way home (the solver's, read
## when it plays), dragged by the finger.
func _drag_hint() -> void:
	var m: Dictionary = _art._state.hint_move()
	if m.is_empty():
		return
	var t := create_tween()
	var path: PackedInt32Array = m.path
	t.tween_callback(func() -> void: _point_at(_art.cell_mid(path[0])))
	t.tween_interval(0.45)
	t.tween_callback(_press.bind(path[0], true))
	t.tween_interval(0.15)
	for k in range(1, path.size()):
		t.tween_method(_glide.bind(path[k - 1], path[k]), 0.0, 1.0, CELL_TIME)
	t.tween_interval(0.12)
	t.tween_callback(_press.bind(path[path.size() - 1], false))
	t.tween_interval(0.2)
	t.tween_callback(_lift)

## How long `_drag_hint` takes, for the loop to wait it out.
func _hint_time() -> float:
	return 0.45 + 0.15 + CELL_TIME * 4.0 + 0.12 + 0.2 + SETTLE

## Every lesson back to its question: the tray as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which drops the blocks in
## with the board's entrance.
func _reset(fresh := false) -> void:
	var tray := _tray()
	_art.lay(tray[0], tray[1], band, fresh)
	_lift()
	_say({Lesson.SLIDE: "HTP_SL_DRAG_CAP", Lesson.CORNER: "HTP_SL_ROUND_CAP",
		Lesson.HEARTS: "HTP_SL_SWEAT_CAP", Lesson.HOMESICK: "HTP_SL_UP_CAP",
		Lesson.UNDO: "HTP_SL_SLIDE_CAP", Lesson.HINT: "HTP_SL_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's point, standing still.
func _still() -> void:
	match lesson:
		Lesson.SLIDE:
			_drag_now(SLIDE_LINE[0])
			_say("HTP_SL_DRAG_CAP")
		Lesson.CORNER:
			_drag_now(CORNER_LINE[0])
			_say("HTP_SL_ONE_CAP")
		Lesson.HEARTS:
			_say("HTP_SL_SWEAT_CAP")
		Lesson.HOMESICK:
			_say("HTP_SL_SOON_CAP")
		Lesson.UNDO:
			_drag_now(SLIDE_LINE[0])
			_say("HTP_SL_UNDO_CAP" if band < 3 else "HTP_SL_RESET_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_SL_HINT_CAP")
	_art._refresh()

## A drag through `path` at once, through the board's own input.
func _drag_now(path: Array) -> void:
	_press(path[0], true)
	for k in range(1, path.size()):
		_glide(1.0, int(path[k - 1]), int(path[k]))
	_press(path[path.size() - 1], false)
	_lift()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the drags, through the board's own input ---

func _point_at(at: Vector2) -> void:
	_finger = at
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _press(c: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.cell_mid(c)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

## The finger `u` of the way from anchor `a`'s cell to `z`'s, held down.
func _glide(u: float, a: int, z: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _art.cell_mid(a).lerp(_art.cell_mid(z), u)
	_finger = ev.position
	_down = true
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	var cell: float = _art._cell()
	if _finger.x < 0.0 or cell <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := cell * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
