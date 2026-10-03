extends Control

## One page of Word Trail's tutorial: a little field of 4 by 4 with three
## words hidden in it, played by the board itself. The page holds a `Trail`
## -- word_trail2d.gd with its sounds, tip lines, rewards, solve and out card
## taken out, laid out short (no scenery band, the slots just under the
## field) -- dealt the lesson's field, and plays the lesson on a loop through
## the board's own input path (a press, motions, a release in board
## coordinates, as a finger would), over a caption that says what it means.
## So a word locks with its own wave and drops its letters into its boxes, a
## wrong trail unwinds or blows a seed off the dandelion, and the lantern
## lights the dark exactly as on the board. `lesson` picks the page (set
## before it enters the tree):
##
## - TRACE: a finger drags the first word along its bends; it locks and its
##   letters drop into its boxes; the second word follows.
## - LENGTHS: the boxes are the only clue; a trail that is no word unwinds
##   (let go off the field where a band counts wishes); the long word fills
##   the last tiles.
## - UNDO: two words found; Undo lifts the last, Reset lifts them all.
## - HINT: the bulb lights where the shortest word starts, then its next.
## - WISHES: on a band that counts them, a wrong trail as long as a word
##   blows a seed off the dandelion, and the same trail again is free.
## - NIGHT: Night Walk: a finger held lights the lantern, the tiles fade
##   back as it moves on, and a found word lights its neighbours for good.
##
## The words are the player's language's (HTP_WT_WORDS: a four, a four and a
## five, in that order), so the field reads in it.
##
## The board checkup, 2026-10-02: Word Trail had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { TRACE, LENGTHS, UNDO, HINT, WISHES, NIGHT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a drag takes per tile it crosses.
const CELL_TIME := 0.2
## The field: three words' paths on a 4 by 4, every other cell a wall.
##
##     A A A #
##     B B A C
##     B B # C
##     # C C C
const PATHS := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
	[Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1)],
	[Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3)]]
## A trail four long that is none of the words.
const WRONG := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
## Where the lantern is walked in the dark: two walls and a tile between.
const WALK := [Vector2i(3, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 3)]

var lesson: int = Lesson.TRACE
## LENGTHS: whether this band counts wishes (a wrong trail is let go off the
## field there, the free way).
var wishes := false
## WISHES, LENGTHS and NIGHT: the seeds the band's dandelion holds.
var wish_count := 7

var _art: Trail
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The lesson's field, dealt in place of a day's.
class Field extends "res://puzzles/word_trail_state.gd":
	var spelt: Array = ["TREE", "LEAF", "BLOOM"]

	func build(_rng: RandomNumberGenerator, difficulty: int) -> void:
		band = clampi(difficulty, 0, BANDS.size() - 1)
		n = 4
		misses = 0
		wishes = int(WISHES[band])
		tried = {}
		shown = {}
		order = []
		given = {}
		words = []
		letters = {}
		for i in PATHS.size():
			var path: Array = PATHS[i]
			var word := String(spelt[i]).to_upper()
			words.append({"word": word, "path": path.duplicate(), "found": false})
			for k in path.size():
				letters[path[k]] = word.substr(k, 1)
		walls = []
		for y in n:
			for x in n:
				if not letters.has(Vector2i(x, y)):
					walls.append(Vector2i(x, y))

## The board, quiet and short: no sound set (its id names none), no tips,
## rewards, solve or out card, no scenery band; the field at the top of the
## page with the slots just under it, the dandelion beside the field and
## the lantern resting at its left.
class Trail extends "res://puzzles/word_trail2d.gd":
	## The field fills the page's height at its left, and the slots stand in
	## a column RIGHT_COL wide beside it, a word a line, over the dandelion
	## on a band that counts wishes.
	const TOP := 6.0
	const RIGHT_COL := 290.0
	const COL_GAP := 56.0

	func _init() -> void:
		_state = Field.new()

	func puzzle_id() -> String:
		return "wordtrail_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _cycle_tip() -> void:
		pass

	func _rewards(_i: int, _t: float) -> void:
		pass

	func _run_out(_t: float) -> void:
		pass

	func _build_band() -> ArrayMesh:
		return null

	func _cell_for(available: float) -> float:
		if _state.n <= 0:
			return 0.0
		var span := float(_state.n - 1) * GAP
		var across := (size.x - 2.0 * INSET - RIGHT_COL - COL_GAP - span) / float(_state.n)
		var down := (available - 2.0 * TOP - span) / float(_state.n)
		return maxf(0.0, minf(across, down))

	func _origin() -> Vector2:
		return Vector2((size.x - _field_size() - COL_GAP - RIGHT_COL) * 0.5, TOP)

	func _slots_top() -> float:
		return _origin().y

	func _slots_room() -> float:
		return _field_size() * (0.6 if _state.counts_wishes() else 1.0)

	func _slots_wide() -> float:
		return RIGHT_COL

	func _slots_left(_w: float) -> float:
		return _origin().x + _field_size() + COL_GAP

	func _band_top() -> float:
		return _origin().y + _slots_room()

	func _puff_foot() -> Vector2:
		return Vector2(_slots_left(0.0) + RIGHT_COL * 0.62, _origin().y + _field_size())

	func _puff_height(base: Vector2) -> float:
		return minf(PUFF_H, base.y - _band_top() - PUFF_R - 8.0)

	func _lamp_rest() -> Vector2:
		return Vector2(_slots_left(0.0) + 50.0, _origin().y + _field_size() - 60.0)

	## The field dealt for `band`, `pre` words already found and standing
	## still, popped in with the board's entrance when `enter`.
	func lay(band: int, spelt: Array, pre: Array, enter: bool, seeds := 0) -> void:
		(_state as Field).spelt = spelt
		var rng := RandomNumberGenerator.new()
		build(rng, band)
		if seeds > 0 and _state.counts_wishes():
			_state.wishes = seeds
		_tip_timer.stop()
		for i: int in pre:
			_state.words[i]["found"] = true
			_state.order.append(i)
		if not enter:
			_opened = _now() - 100.0
		_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Trail.new()
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
		Lesson.TRACE:
			_play_trail(PATHS[0], "HTP_WT_DRAG_CAP")
			_loop.tween_interval(0.3)
			_loop.tween_callback(_say.bind("HTP_WT_LOCK_CAP"))
			_loop.tween_interval(2.0)
			_play_trail(PATHS[1], "")
			_loop.tween_interval(0.3)
			_loop.tween_callback(_say.bind("HTP_WT_BOXES_CAP"))
			_loop.tween_interval(2.6)
		Lesson.LENGTHS:
			_loop.tween_callback(_say.bind("HTP_WT_LENGTHS_CAP"))
			_loop.tween_interval(2.0)
			_play_trail(WRONG, "", wishes)
			_loop.tween_interval(0.2)
			_loop.tween_callback(_say.bind("HTP_WT_OFF_CAP" if wishes else "HTP_WT_UNWIND_CAP"))
			_loop.tween_interval(2.2)
			_play_trail(PATHS[2], "")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_WT_EVERY_CAP"))
			_loop.tween_interval(2.6)
		Lesson.UNDO:
			_loop.tween_callback(_say.bind("HTP_WT_UNDO_CAP"))
			_loop.tween_interval(0.8)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(2.0)
			_loop.tween_callback(_say.bind("HTP_WT_RESET_CAP"))
			_loop.tween_interval(0.8)
			_loop.tween_callback(_art.reset_board)
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_WT_HINT_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.0)
			_loop.tween_callback(_say.bind("HTP_WT_HINT2_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.6)
			_play_trail(PATHS[0], "")
			_loop.tween_interval(2.2)
		Lesson.WISHES:
			_play_trail(WRONG, "HTP_WT_SEED_CAP")
			_loop.tween_interval(2.8)
			_play_trail(WRONG, "HTP_WT_AGAIN_CAP")
			_loop.tween_interval(2.4)
		Lesson.NIGHT:
			_loop.tween_callback(_say.bind("HTP_WT_LAMP_CAP"))
			_loop.tween_callback(_point.bind(WALK[0]))
			_loop.tween_interval(0.4)
			_loop.tween_callback(_button_at.bind(WALK[0], true))
			_loop.tween_method(_drag_along.bind(WALK, false), 0.0, 1.0, CELL_TIME * 2.0 * (WALK.size() - 1))
			_loop.tween_interval(0.3)
			_loop.tween_callback(_button_at.bind(WALK[-1], false))
			_loop.tween_callback(_lift)
			_loop.tween_callback(_say.bind("HTP_WT_FADE_CAP"))
			_loop.tween_interval(2.0)
			_play_trail(PATHS[0], "")
			_loop.tween_interval(0.4)
			_loop.tween_callback(_say.bind("HTP_WT_GLOW_CAP"))
			_loop.tween_interval(2.8)
	_loop.tween_callback(_reset)

## A trail along `cells`: the finger comes down on the first, the caption
## turns to `say` (when not ""), the finger is drawn through tile by tile and
## lets go -- off the field past the last tile when `off`.
func _play_trail(cells: Array, say: String, off := false) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(cells[0]))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button_at.bind(cells[0], true))
	_loop.tween_interval(0.15)
	_loop.tween_method(_drag_along.bind(cells, off), 0.0, 1.0, CELL_TIME * (cells.size() - 1 + (1 if off else 0)))
	_loop.tween_interval(0.2)
	if off:
		_loop.tween_callback(_button.bind(_off_point(cells), false))
	else:
		_loop.tween_callback(_button_at.bind(cells[-1], false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the field with what the lesson starts
## from, every wish, nothing in flight. `fresh` is the first deal, which
## pops the field in with the board's entrance.
func _reset(fresh := false) -> void:
	var band := 0
	var pre: Array = []
	match lesson:
		Lesson.LENGTHS:
			band = 2 if wishes else 0
		Lesson.UNDO:
			pre = [0, 1]
		Lesson.WISHES:
			band = 2
		Lesson.NIGHT:
			band = 3
	_art.lay(band, _spelt(), pre, fresh, wish_count)
	_lift()
	_say({Lesson.LENGTHS: "HTP_WT_LENGTHS_CAP", Lesson.UNDO: "HTP_WT_UNDO_CAP",
		Lesson.HINT: "HTP_WT_HINT_CAP", Lesson.WISHES: "HTP_WT_SEED_CAP",
		Lesson.NIGHT: "HTP_WT_LAMP_CAP"}.get(lesson, "HTP_WT_DRAG_CAP"))

## The three words in the player's language.
func _spelt() -> Array:
	var words := tr("HTP_WT_WORDS").split(",")
	if words.size() != PATHS.size():
		return ["TREE", "LEAF", "BLOOM"]
	for i in PATHS.size():
		if words[i].strip_edges().length() != (PATHS[i] as Array).size():
			return ["TREE", "LEAF", "BLOOM"]
	return Array(words).map(func(w: String) -> String: return w.strip_edges())

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art._state
	var find := func(i: int) -> void:
		st.words[i]["found"] = true
		st.order.append(i)
	match lesson:
		Lesson.TRACE:
			find.call(0)
			find.call(1)
			_say("HTP_WT_BOXES_CAP")
		Lesson.LENGTHS:
			find.call(2)
			_say("HTP_WT_EVERY_CAP")
		Lesson.UNDO:
			_art.undo()
			_say("HTP_WT_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
			_art.hint()
			_say("HTP_WT_HINT2_CAP")
		Lesson.WISHES:
			st.misses = 1
			_say("HTP_WT_SEED_CAP")
		Lesson.NIGHT:
			find.call(0)
			_say("HTP_WT_GLOW_CAP")
	_art._refresh()

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(cell: Vector2i) -> void:
	_finger = _art._centre(cell)
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button_at(cell: Vector2i, pressed: bool) -> void:
	_button(_art._centre(cell), pressed)

func _button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	_finger = at
	_down = pressed
	_art._gui_input(ev)

## Past the trail's last tile, off the field, the way the trail was going --
## over nothing it could take, so the trail is let go whole.
func _off_point(cells: Array) -> Vector2:
	var last: Vector2i = cells[-1]
	var dir: Vector2i = last - (cells[-2] as Vector2i)
	var cell := last
	while cell.x >= 0 and cell.y >= 0 and cell.x < 4 and cell.y < 4:
		cell += dir
	return _art._centre(cell) - Vector2(dir) * (_art._cell() * 0.2)

## The finger `u` of the way along `cells` (and on off the field when
## `off`), dragging.
func _drag_along(u: float, cells: Array, off: bool) -> void:
	var pts: Array[Vector2] = []
	for c: Vector2i in cells:
		pts.append(_art._centre(c))
	if off:
		pts.append(_off_point(cells))
	var span := float(pts.size() - 1)
	var at := pts[0]
	if span > 0.0:
		var k := clampf(u * span, 0.0, span)
		var i := mini(int(floor(k)), pts.size() - 2)
		at = pts[i].lerp(pts[i + 1], k - float(i))
	_finger = at
	_down = true
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0 or _art._cell() <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var cell: float = _art._cell()
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := cell * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
