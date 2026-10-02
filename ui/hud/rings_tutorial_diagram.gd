extends Control

## One page of Rings' tutorial: a row of three pegs of its own, played by the
## board itself. The page holds a `Yard` -- rings2d.gd with its sounds, tip
## lines, streak, gags, party and out-of-hearts card taken out, its pegs in
## one row -- dealt by hand, and plays the lesson on a loop through the
## board's own input path (a press on a peg, the release), over a caption
## that says what it means. So a ring slides up its post and turns in the
## hand, a drop on another colour is refused with a shiver, a drop flies and
## threads down its post, a full peg glints and wears its daisy, a dead end
## wobbles and hops home for a heart, and a two-tone ring somersaults as it
## lifts, exactly as on the board. `lesson` picks the page (set before it
## enters the tree):
##
## - LIFT: a ring lifted, refused on another colour, set down on an empty peg.
## - SORT: a ring onto its own colour fills a peg, which locks; the last ring
##   home and the solve wave.
## - HEARTS (Hard, Insane): the only empty peg spent on the wrong ring is a
##   dead end -- it wobbles, a heart splits, it hops back -- and the ring
##   that belongs there goes instead.
## - TUMBLE (Insane): a two-tone ring turns over as it lifts and lands as the
##   colour it shows, locking the peg.
## - UNDO: Undo takes a drop back; Reset puts every ring back (Reset alone on
##   Insane, which has no Undo).
## - HINT: the bulb plays a move.
##
## The board checkup, 2026-10-02: Rings had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { LIFT, SORT, HEARTS, TUMBLE, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0

## The lessons' pegs, bottom ring first, two colours (0 the berry heart, 1
## the sun sprout). A Tumble ring is `top | (under + 1) << 3`: 9 shows the
## sun over a berry band, 16 the berry over a sun band.
const LIFT_PEGS := [[1, 1, 1, 0], [0, 0, 0, 1], []]
const SORT_PEGS := [[1, 1, 1, 0], [0, 0, 0], [1]]
## Searched for (every three-peg deal of two colours): the empty peg spent on
## the middle peg's sun leaves no way to sort them; the left peg's berry
## there is the way on.
const DOOM_PEGS := [[1, 1, 0, 0], [0, 1, 0, 1], []]
const TUMBLE_PEGS := [[0, 0, 0], [1, 1, 9], [1, 16]]

var lesson: int = Lesson.LIFT
## The band the board behind the page is on.
var band := 0

var _art: Yard
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, streak, gags,
## party or out-of-hearts card, and a dead end never puts it to sleep -- the
## loop deals the pegs again. One row of pegs. A win is the solve wave alone,
## called by the page.
class Yard extends "res://puzzles/rings2d.gd":
	func puzzle_id() -> String:
		return "rings_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_dropped(_i: int, _onto: bool) -> void:
		pass

	func _party(_wave: float) -> void:
		pass

	func _doom(to: int) -> void:
		super(to)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _row_counts() -> Array:
		return [_state.pegs.size(), 0]

	## One row: the held ring's headroom, the pegs and their plank.
	func _min_h() -> float:
		return HEAD + STATION_H + SHELF_H + 24.0

	## The pegs as the page deals them (`pegs`, `count` colours) on band `b`,
	## and, when `enter`, popped in with the board's entrance.
	func lay(b: int, pegs: Array, count: int, enter: bool) -> void:
		_gen += 1
		_state.take(pegs, b, count)
		hints_used = 0
		moves = 0
		_done = false
		_running = true
		_dealt()
		_tip_timer.stop()
		if not enter:
			_opened = _now() - 10.0
			_heart_layer.queue_redraw()
			_refresh()

	## The win as the board shows it, without the party: the solve wave.
	func win() -> void:
		_on_solved()

	## Where a finger taps peg `i`, in the board's own pixels: up its column,
	## over the rings.
	func peg_point(i: int) -> Vector2:
		var st := _station(i)
		return Vector2(float(st["cx"]), float(st["ground"]) - 120.0) * _s

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Yard.new()
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

## The pegs as tall as the page leaves over the caption and the page's whole
## width: the board centres its own row.
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
	# and a second would deal the pegs again without their entrance.
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
		Lesson.LIFT:
			_play_tap(1, "HTP_RG_TAP_CAP")
			_loop.tween_interval(0.9)
			_play_tap(0, "HTP_RG_COLOUR_CAP")
			_loop.tween_interval(1.2)
			_play_tap(2, "HTP_RG_EMPTY_CAP")
			_loop.tween_interval(2.4)
		Lesson.SORT:
			_play_tap(0, "")
			_loop.tween_interval(0.5)
			_play_tap(1, "HTP_RG_OWN_CAP")
			_loop.tween_interval(2.0)
			_play_tap(2, "")
			_loop.tween_interval(0.5)
			_play_tap(0, "")
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_RG_DONE_CAP", 3.0)
		Lesson.HEARTS:
			_play_tap(1, "")
			_loop.tween_interval(0.5)
			_play_tap(2, "")
			_loop.tween_interval(0.35)
			_say_for("HTP_RG_DOOM_CAP", 2.2)
			_play_tap(0, "HTP_RG_BETTER_CAP")
			_loop.tween_interval(0.5)
			_play_tap(2, "")
			_loop.tween_interval(2.2)
		Lesson.TUMBLE:
			_play_tap(1, "HTP_RG_TURN_CAP")
			_loop.tween_interval(1.4)
			_play_tap(0, "HTP_RG_LANDS_CAP")
			_loop.tween_interval(2.0)
			_play_tap(2, "HTP_RG_TURN_CAP")
			_loop.tween_interval(1.0)
			_play_tap(1, "")
			_loop.tween_interval(2.0)
		Lesson.UNDO:
			_play_tap(1, "HTP_RG_TAP_CAP")
			_loop.tween_interval(0.4)
			_play_tap(2, "")
			_loop.tween_interval(0.9)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_RG_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_play_tap(0, "HTP_RG_TAP_CAP")
				_loop.tween_interval(0.4)
				_play_tap(2, "")
				_loop.tween_interval(0.9)
			_loop.tween_callback(_say.bind("HTP_RG_RESET_CAP"))
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

## A tap on peg `i`: the finger comes down on it (the caption turning to
## `say` when not ""), the peg dips, and the finger lifts -- the lift or the
## drop.
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

## Every lesson back to its question: the pegs as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the pegs in with
## the board's entrance.
func _reset(fresh := false) -> void:
	var pegs: Array = {Lesson.SORT: SORT_PEGS, Lesson.HEARTS: DOOM_PEGS,
		Lesson.TUMBLE: TUMBLE_PEGS}.get(lesson, LIFT_PEGS)
	_art.lay(band, pegs, 2, fresh)
	_lift()
	_say({Lesson.LIFT: "HTP_RG_START_CAP", Lesson.SORT: "HTP_RG_SORT_CAP",
		Lesson.HEARTS: "HTP_RG_EMPTY_LEFT_CAP", Lesson.TUMBLE: "HTP_RG_TWO_CAP",
		Lesson.UNDO: "HTP_RG_START_CAP", Lesson.HINT: "HTP_RG_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.LIFT:
			_art._tap(1)
			_art._tap(2)
			_say("HTP_RG_EMPTY_CAP")
		Lesson.SORT:
			for i in [0, 1, 2, 0]:
				_art._tap(i)
			_art.win()
			_say("HTP_RG_DONE_CAP")
		Lesson.HEARTS:
			_art._tap(0)
			_art._tap(2)
			_say("HTP_RG_BETTER_CAP")
		Lesson.TUMBLE:
			_art._tap(1)
			_art._tap(0)
			_say("HTP_RG_LANDS_CAP")
		Lesson.UNDO:
			_say("HTP_RG_UNDO_CAP" if band < 3 else "HTP_RG_RESET_CAP")
		Lesson.HINT:
			_art.hint()
	_art._refresh()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(i: int) -> void:
	_finger = _art.position + _art.peg_point(i)
	_down = false

func _press(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _art.peg_point(i)
	_down = true
	_art._gui_input(ev)

func _release(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = _art.peg_point(i)
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
