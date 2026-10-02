extends Control

## One page of Caterpillar's tutorial: a small garden walked by the board
## itself. The page holds a `Garden` -- caterpillar2d.gd with its sounds, tip
## lines, streak, gags, party and out-of-hearts card taken out -- dealt a
## hand-made garden of four by three squares, and plays the lesson on a loop
## through the board's own input path (a press, motions, a release in board
## coordinates, as a finger would), over a caption that says what it means.
## So a leaf is chewed and gulped, a badge shakes at a step out of turn, a
## fence flashes, the body runs back over a cut, a stranded square blushes
## while a heart splits, and the solve hops and turns into a butterfly,
## exactly as on the board. `lesson` picks the page (set before it enters the
## tree); on Insane every garden is a Peckish one (an unmarked middle leaf, a
## tummy of five):
##
## - WALK: leaf 1 pressed and the whole garden walked in one drag.
## - ORDER (Easy to Hard): the last leaf refused while squares are empty, and
##   leaf 3 refused while leaf 2 is due; leaf 2, and on.
## - FENCE (Medium on): a step through a fence refused; round it.
## - BACK: a wrong turn, dragged back over the body, and the other way.
## - HEARTS (Hard, Insane): a step that strands a square (Hard) or leaves the
##   one walk (Insane) costs a heart and the caterpillar scoots back.
## - PECKISH (Insane): bare squares empty the tummy, an empty tummy refuses a
##   bare square, a leaf fills it again, and the walk ends on the star.
## - UNDO: Undo takes a stroke back; Reset empties the garden (Reset alone on
##   Insane, which has no Undo).
## - HINT: the bulb crawls on to the next leaf.
##
## The board checkup, 2026-10-02: Caterpillar had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/caterpillar_gen.gd")

enum Lesson { WALK, ORDER, FENCE, BACK, HEARTS, PECKISH, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long the finger takes across one square.
const STEP_TIME := 0.26
const CAPTION_H := 92.0

## The garden, four by three:
##
##      0  1  2  3
##      4  5  6  7
##      8  9 10 11
##
## walked as a snake along the rows: the answer.
const COLS := 4
const ROWS := 3
const SNAKE := [0, 1, 2, 3, 7, 6, 5, 4, 8, 9, 10, 11]
## The leaves on Easy to Hard (leaf 1, 2, ... by cell), the ORDER page's four
## (so the head meets leaf 3 and the last leaf early), and Peckish's: leaf 1,
## one unmarked leaf five bare squares on, and the star four after it, for
## Peckish's tummy of five.
const LEAVES := [0, 6, 11]
const ORDER_LEAVES := [0, 5, 10, 11]
const PECK_LEAVES := [0, 5, 11]
const HUNGER := 5
## The FENCE page's two fences, under squares 1 and 2.
const FENCES := [[1, 5], [2, 6]]

var lesson: int = Lesson.WALK
## The band the board behind the page is on.
var band := 0

var _art: Garden
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, streak,
## gags, party or out-of-hearts card, and a last heart lost never puts it to
## sleep -- the loop deals the garden again. A win is the hop and the
## butterfly alone, called by the page.
class Garden extends "res://puzzles/caterpillar2d.gd":
	func puzzle_id() -> String:
		return "caterpillar_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_leaf(_c: int) -> void:
		pass

	func _party() -> void:
		pass

	func _misstep(c: int, kind: String, t: float) -> void:
		super(c, kind, t)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Just the frame's width of lawn round the bed: the page is short.
	func _inset() -> float:
		return GROUND_PAD + FRAME + 6.0

	## The garden `g` (Gen's dictionary) as the page deals it on band `b`:
	## nothing walked, every heart, and popped in with the board's entrance
	## when `enter`.
	func lay(g: Dictionary, b: int, enter: bool) -> void:
		_gen += 1
		_state.setup(g)
		_state.difficulty = b
		max_hearts = State.hearts_for(b)
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_heart_used = false
		_lost_ever = false
		_undo_ever = false
		_flawless = false
		_deal()
		_reset_rewards()
		_ref_cell = 0.0
		_layout()
		_tip_timer.stop()
		_opened = _now() if enter else _now() - 10.0
		if enter:
			_decor_for(_entrance())
		_heart_layer.queue_redraw()
		_life_layer.queue_redraw()

	## The win as the board shows it, without the party: the hop down the
	## body and the butterfly.
	func win() -> void:
		_on_solved()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Garden.new()
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

## The garden as tall as the page leaves over the caption and the page's
## whole width: the board centres its own bed.
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

func _peckish() -> bool:
	return band >= 3

## The lesson's garden, as Gen deals one.
func _garden() -> Dictionary:
	# ORDER's leaves meet the head early; HEARTS' leave square 6 bare, so
	# the stranding step is not onto a leaf.
	var leaves: Array = PECK_LEAVES if _peckish() else \
		(ORDER_LEAVES if lesson in [Lesson.ORDER, Lesson.HEARTS] else LEAVES)
	var hedges: Array = []
	if lesson == Lesson.FENCE:
		for f: Array in FENCES:
			hedges.append(Gen.edge_key(f[0], f[1]))
	return {"cols": COLS, "rows": ROWS, "path": PackedInt32Array(SNAKE),
		"leaves": PackedInt32Array(leaves), "hedges": hedges,
		# Insane's hearts page is priced off the one walk, as Peckish is.
		"unique": _peckish() and lesson == Lesson.HEARTS,
		"hunger": HUNGER if _peckish() else 0}

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the garden again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.6)
	match lesson:
		Lesson.WALK:
			_play_walk(SNAKE, "HTP_CP_START_CAP", "HTP_CP_STAR_CAP" if _peckish() else "HTP_CP_DRAG_CAP")
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_CP_DONE_CAP", 3.4)
		Lesson.ORDER:
			_play_walk([0, 1, 2, 3, 7, 11, 7, 6, 10, 6, 5, 4, 8, 9, 10, 11], "HTP_CP_START_CAP", "",
				{5: "HTP_CP_LAST_CAP", 8: "HTP_CP_ORDER_CAP", 10: "HTP_CP_ON_CAP"}, {5: 1.1, 8: 1.1})
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_CP_DONE_CAP", 3.2)
		Lesson.FENCE:
			_play_walk([0, 1, 5, 1, 2, 3, 7, 6, 5, 4], "HTP_CP_START_CAP", "",
				{2: "HTP_CP_FENCE_CAP", 4: "HTP_CP_ROUND_CAP"}, {2: 1.2})
			_loop.tween_interval(2.0)
		Lesson.BACK:
			_play_walk([0, 4, 8, 4, 0, 1, 2, 3], "HTP_CP_WRONG_CAP", "",
				{3: "HTP_CP_BACK_CAP", 5: "HTP_CP_RIGHT_CAP"}, {2: 0.7})
			_loop.tween_interval(2.0)
		Lesson.HEARTS:
			if _peckish():
				_play_walk([0, 1, 5], "HTP_CP_DOOM_CAP", "")
				_loop.tween_callback(_say.bind("HTP_CP_HEART_CAP"))
				_loop.tween_interval(1.8)
				_play_walk([1, 2, 3, 7], "HTP_CP_RIGHT_CAP", "")
			else:
				_play_walk([0, 1, 2, 6], "HTP_CP_STRAND_CAP", "")
				_loop.tween_callback(_say.bind("HTP_CP_HEART_CAP"))
				_loop.tween_interval(1.8)
				_play_walk([2, 3, 7, 6], "HTP_CP_RIGHT_CAP", "")
			_loop.tween_interval(2.0)
		Lesson.PECKISH:
			_play_walk([0, 1, 2, 3, 7, 6, 10, 6, 5, 4, 8, 9, 10, 11], "HTP_CP_TUMMY_CAP", "",
				{6: "HTP_CP_HUNGRY_CAP", 8: "HTP_CP_REFILL_CAP", 13: "HTP_CP_STAR_CAP"}, {6: 1.3, 8: 0.8})
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_CP_DONE_CAP", 3.2)
		Lesson.UNDO:
			_play_walk([0, 1, 2], "HTP_CP_START_CAP", "")
			_loop.tween_interval(0.4)
			_play_walk([2, 3, 7, 6], "", "")
			_loop.tween_interval(0.8)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_CP_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.6)
			_loop.tween_callback(_say.bind("HTP_CP_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_CP_HINT_CAP"))
			_loop.tween_interval(0.4)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.8)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.6)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger presses square `walk[0]` and drags through the rest of `walk`
## without lifting, the caption turning to `press` on the press, `drag` once
## it moves and `at[k]` as it sets off toward walk[k]; `wait[k]` holds the
## finger that long once it has reached walk[k] (a refusal playing out).
func _play_walk(walk: Array, press: String, drag: String, at := {}, wait := {}) -> void:
	if press != "":
		_loop.tween_callback(_say.bind(press))
	_loop.tween_callback(_point.bind(int(walk[0])))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(int(walk[0]), true))
	_loop.tween_interval(0.3)
	if drag != "":
		_loop.tween_callback(_say.bind(drag))
	for k in range(1, walk.size()):
		if at.has(k):
			_loop.tween_callback(_say.bind(at[k]))
		_loop.tween_method(_drag_to.bind(int(walk[k - 1]), int(walk[k])), 0.0, 1.0, STEP_TIME)
		_loop.tween_interval(float(wait.get(k, 0.06)))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_button.bind(int(walk[-1]), false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the garden as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the garden in
## with the board's entrance.
func _reset(fresh := false) -> void:
	_art.lay(_garden(), band, fresh)
	_lift()
	_say({Lesson.WALK: "HTP_CP_START_CAP", Lesson.ORDER: "HTP_CP_START_CAP",
		Lesson.FENCE: "HTP_CP_START_CAP", Lesson.BACK: "HTP_CP_WRONG_CAP",
		Lesson.HEARTS: "HTP_CP_DOOM_CAP" if _peckish() else "HTP_CP_STRAND_CAP",
		Lesson.PECKISH: "HTP_CP_TUMMY_CAP", Lesson.UNDO: "HTP_CP_START_CAP",
		Lesson.HINT: "HTP_CP_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.FENCE:
			_walk_now([0, 1, 2, 3, 7, 6, 5, 4])
			_say("HTP_CP_ROUND_CAP")
		Lesson.BACK:
			_walk_now([0, 1, 2, 3])
			_say("HTP_CP_RIGHT_CAP")
		Lesson.HEARTS:
			_walk_now([0, 1, 2, 3, 7])
			_say("HTP_CP_RIGHT_CAP")
		Lesson.UNDO:
			_walk_now([0, 1, 2])
			_say("HTP_CP_UNDO_CAP" if band < 3 else "HTP_CP_RESET_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_CP_HINT_CAP")
		_:
			_walk_now(SNAKE)
			_art.win()
			_say("HTP_CP_DONE_CAP")
	_art._refresh()

## The garden walked along `walk` at once, through the board's own input.
func _walk_now(walk: Array) -> void:
	_button(int(walk[0]), true)
	for k in range(1, walk.size()):
		_drag_to(1.0, int(walk[k - 1]), int(walk[k]))
	_button(int(walk[-1]), false)
	_lift()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _at(c: int) -> Vector2:
	return _art.cell_to_local(c / COLS, c % COLS)

func _point(c: int) -> void:
	_finger = _at(c)
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(c: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _at(c)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

## The finger `u` of the way from square `a` to square `b`, dragging. (A
## board that has let the finger go -- a step that cost a heart -- takes no
## motion, as it would take none from a player.)
func _drag_to(u: float, a: int, b: int) -> void:
	var at := _at(a).lerp(_at(b), u)
	_finger = at
	_down = true
	var ev := InputEventMouseMotion.new()
	ev.position = at
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
