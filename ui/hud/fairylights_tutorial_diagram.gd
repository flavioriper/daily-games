extends Control

## One page of Fairy Lights' tutorial: a little garden of its own, four by
## four, played by the board itself. The page holds a `Garden` --
## fairy_lights2d.gd with its sounds, tip lines, streak, gags, party and
## out-of-hearts card taken out -- dealt by hand, and plays the lesson on a
## loop through the board's own input path (a press on a piece, the release),
## over a caption that says what it means. So a piece sinks under the finger
## and turns a quarter, the light washes out from the post along the joined
## wire, a lantern wakes, the win's chase runs gold, a right piece blows a
## fuse and takes its clip, and a tag ticks gold exactly as on the board.
## `lesson` picks the page (set before it enters the tree):
##
## - TURN: a piece tapped twice turns until it meets the lit wire, and the
##   light runs on to the lantern at its end.
## - DONE: the last loose end turned home: every lantern lit, the chase.
## - HEARTS (Hard, Insane): a tap on a piece that is already right blows a
##   fuse, costs a heart and clips the piece.
## - TAGS (Insane): a tagged lantern joined at its tag's count ticks gold.
## - UNDO: Undo turns the last piece back; Reset turns them all back.
## - HINT: the bulb turns one piece to its answer and pins it.
##
## The board checkup, 2026-10-02: Fairy Lights had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const State = preload("res://puzzles/fairy_lights_state.gd")

enum Lesson { TURN, DONE, HEARTS, TAGS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
const N := 4

## The garden every lesson plays on, its answer cell by cell (N 1, E 2, S 4,
## W 8): the post at row 1, column 1 as a cross, and a tree out of it to
## seven lanterns -- the four corners, the top row's and the middle rows'
## right ends, and the left end of the third row.
##
##     L  ┌  ─  L
##     └  P  ┬  L
##     L  ┘  ├  L
##     L  ─  ┴  L
const POST := 5
const SOL := [4, 6, 10, 8,
	3, 15, 14, 8,
	2, 9, 7, 8,
	2, 10, 11, 8]
## The pieces the lessons turn: the elbow under the top row's straight (two
## quarters off), the straight along the bottom row (one off), and a piece
## that starts right (the elbow at the left of row 1, HEARTS' fuse).
const ELBOW := 1
const STRAIGHT := 13
const RIGHT_PIECE := 4
## Wish Tags' tags: the bottom-left lantern sits five steps along the wire
## from the post, the top-right one three.
const TAGS := {12: 5, 3: 3}

var lesson: int = Lesson.TURN
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: Garden
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags, streak,
## party or out-of-hearts card, and a last heart lost never puts it to sleep
## -- the loop deals the garden again. A win is the chase alone, called by
## the page.
class Garden extends "res://puzzles/fairy_lights2d.gd":
	func puzzle_id() -> String:
		return "fairylights_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_turned(i: int, _before: PackedInt32Array) -> void:
		_join_sparks(i)

	func _on_lantern_woke(_i: int, _by_turn: bool) -> void:
		pass

	func _party() -> void:
		pass

	func _fuse(i: int) -> void:
		super(i)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Only the frame round the grid: the page is short.
	func _inset() -> float:
		return FRAME + 2.0

	## The hearts hang beside the garden, so the page's height is all grid.
	func _heart_row() -> float:
		return 0.0

	func _hearts_at() -> Vector2:
		var wide := (2.0 * HEART_R + HEART_GAP) * float(maxi(0, max_hearts - 1)) \
			+ 2.0 * HEART_R + 2.0 * HEART_PILL_PAD.x
		return Vector2(_grid.x - FRAME - 16.0 - wide * 0.5,
			_grid.y + HEART_R + HEART_PILL_PAD.y)

	## The garden as the page deals it: `deal` on the lesson's answer,
	## `tags` on its lanterns, judged on `band` when `judged`, washed in from
	## the post and, when `enter`, popped in with the board's entrance.
	func lay(b: int, deal: Array, tags: Dictionary, judged: bool, enter: bool) -> void:
		_gen += 1
		var st := State.new()
		st.band = b
		st.n = N
		st.post = POST
		st.sol = PackedInt32Array(SOL)
		st.deal = PackedInt32Array(deal)
		st.grid = st.deal.duplicate()
		st.tags = tags.duplicate()
		st.proved = true
		st.judged = judged
		st.pinned = PackedByteArray()
		st.pinned.resize(N * N)
		st.pinned.fill(0)
		st.clipped = PackedByteArray()
		st.clipped.resize(N * N)
		st.clipped.fill(0)
		st.history = PackedInt32Array()
		state = st
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_dealt()
		if enter:
			_enter()
		else:
			# The light still washes out from the post, so every loop opens
			# by showing where it comes from.
			var t := _now()
			_opened = t - 10.0
			var dark := PackedInt32Array()
			dark.resize(N * N)
			dark.fill(-1)
			_settle(dark, t)
			_dress(t)
			_refresh()
		_tip_timer.stop()

	## The win as the board shows it, without the party: the chase.
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
## whole width: the board centres its own square grid, and a judged band's
## hearts hang in the air to its left.
func _layout() -> void:
	if _art == null:
		return
	var h := maxf(0.0, size.y - CAPTION_H)
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, h)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

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
		Lesson.TURN:
			_play_tap(ELBOW, "HTP_FL_TAP_CAP")
			_loop.tween_interval(1.0)
			_play_tap(ELBOW, "")
			_loop.tween_interval(0.6)
			_say_for("HTP_FL_GOLD_CAP", 2.8)
		Lesson.DONE:
			_play_tap(STRAIGHT, "")
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_FL_DONE_CAP", 3.6)
		Lesson.HEARTS:
			_play_tap(RIGHT_PIECE, "")
			_loop.tween_interval(0.3)
			_say_for("HTP_FL_FUSE_CAP", 1.6)
			_say_for("HTP_FL_CLIP_CAP", 2.6)
		Lesson.TAGS:
			_play_tap(STRAIGHT, "")
			_loop.tween_interval(0.8)
			_say_for("HTP_FL_TICK_CAP", 3.0)
		Lesson.UNDO:
			_play_tap(ELBOW, "HTP_FL_TAP_CAP")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_FL_UNDO_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(1.4)
			_play_tap(ELBOW, "HTP_FL_TAP_CAP")
			_loop.tween_interval(0.5)
			_play_tap(ELBOW, "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_FL_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(3.0)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## A tap on cell `i`: the finger comes down on it (the caption turning to
## `say` when not ""), the piece sinks, and the finger lifts -- the turn.
func _play_tap(i: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(i))
	_loop.tween_interval(0.35)
	_loop.tween_callback(_press.bind(i))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_release.bind(i))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## The deal a lesson starts from: the answer with ELBOW two quarters back
## (its arm points away from the top row) and STRAIGHT one (so the bottom
## row's left half is dark); DONE and TAGS leave only STRAIGHT to turn.
func _deal_for() -> Array:
	var deal := SOL.duplicate()
	deal[STRAIGHT] = Gen.ccw(SOL[STRAIGHT])
	if lesson != Lesson.DONE and lesson != Lesson.TAGS:
		deal[ELBOW] = Gen.ccw(Gen.ccw(SOL[ELBOW]))
	return deal

## Every lesson back to its question: the garden as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the garden in
## with the board's entrance.
func _reset(fresh := false) -> void:
	var judged := band >= 2 and hearts > 0
	var tags: Dictionary = TAGS if lesson == Lesson.TAGS else {}
	_art.lay(band, _deal_for(), tags, judged, fresh)
	_lift()
	_say({Lesson.TURN: "HTP_FL_WRONG_CAP", Lesson.DONE: "HTP_FL_LOOSE_CAP",
		Lesson.HEARTS: "HTP_FL_RIGHT_CAP", Lesson.TAGS: "HTP_FL_TAG_CAP",
		Lesson.UNDO: "HTP_FL_TAP_CAP", Lesson.HINT: "HTP_FL_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.TURN:
			_art._turn(ELBOW)
			_art._turn(ELBOW)
			_say("HTP_FL_GOLD_CAP")
		Lesson.DONE:
			_art._turn(STRAIGHT)
			_art.win()
			_say("HTP_FL_DONE_CAP")
		Lesson.HEARTS:
			_art._turn(RIGHT_PIECE)
			_say("HTP_FL_CLIP_CAP")
		Lesson.TAGS:
			_art._turn(STRAIGHT)
			_say("HTP_FL_TICK_CAP")
		Lesson.UNDO:
			_say("HTP_FL_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
	_art._refresh()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(i: int) -> void:
	_finger = _art.position + _art.cell_centre(i)
	_down = false

func _press(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _art.cell_centre(i)
	_down = true
	_art._gui_input(ev)

func _release(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = _art.cell_centre(i)
	_down = false
	_art._gui_input(ev)

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
