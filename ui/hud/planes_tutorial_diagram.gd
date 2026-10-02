extends Control

## One page of Paper Planes' tutorial: a little sky of its own, six by five,
## played by the board itself. The page holds a `TutorialSky` -- planes2d.gd with its
## sounds, tip lines, idle flutter, gags, streak, party and out-of-hearts card
## taken out -- dealt by hand, and plays the lesson on a loop through the
## board's own input path (a press on a plane, the release), over a caption
## that says what it means. So a plane sinks under the finger and flies off
## down its lane, a blocked one is refused (the lane flashes, the blocker
## shivers) or crashes and costs a heart, the clouds blow a cell downwind,
## and the sky's last plane brings the solve wave, exactly as on the board.
## `lesson` picks the page (set before it enters the tree):
##
## - LAUNCH: a plane whose lane is clear flies off when tapped.
## - ORDER: the plane in front goes first, and the one behind is free.
## - REFUSE (Easy, Medium): a blocked plane is refused, and nothing is lost.
## - HEARTS (Hard, Insane): a blocked plane bonks its nose, and a heart goes.
## - DONE: the last planes go and the sky is clear.
## - WIND (Insane): each launch blows the clouds a cell downwind; a cloud in
##   a lane blocks it until it has blown past.
## - UNDO: Undo calls the last plane back (not on Insane); Reset calls them
##   all back.
## - HINT: the bulb names a plane that can go.
##
## The board checkup, 2026-10-02: Paper Planes had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/planes_state.gd")

enum Lesson { LAUNCH, ORDER, REFUSE, HEARTS, DONE, WIND, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
const COLS := 6
const ROWS := 5

## The sky every lesson plays on, each plane tail to head:
##
##     row 0:  .  .  .  .  E  E>       E: free (off the right edge)
##     row 1:  .  G^ B  B  B> .        B: free; G free (up)
##     row 2:  C^ G  G  A^ .  .        A: up, blocked by B
##     row 3:  C  .  G  A  <D D        D: left, waits on A, G and C
##     row 4:  C  F  F> A  .  D        F: right, waits on A and D
const PLANES := [
	[Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)],                    # B
	[Vector2i(3, 4), Vector2i(3, 3), Vector2i(3, 2)],                    # A
	[Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2)],                    # C
	[Vector2i(5, 4), Vector2i(5, 3), Vector2i(4, 3)],                    # D
	[Vector2i(4, 0), Vector2i(5, 0)],                                    # E
	[Vector2i(1, 4), Vector2i(2, 4)],                                    # F
	[Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1)],    # G
]
const B := 0
const A := 1
const C := 2
const D := 3
const E := 4
const F := 5
const G := 6
## An order that clears the sky (front first).
const ORDER := [B, E, C, G, A, D, F]
## Windy Day's one cloud at count 0: in C's lane, blown east a cell a launch.
const CLOUD := Vector2i(0, 0)

var lesson: int = Lesson.LAUNCH
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: TutorialSky
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, idle
## flutter, gags, streak, party or out-of-hearts card, and a last heart lost
## never ends it -- the loop deals the sky again. A win is the solve wave
## alone, called by the page.
class TutorialSky extends "res://puzzles/planes2d.gd":
	func puzzle_id() -> String:
		return "planes_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		force_gag = Gag.NONE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _idle_tick(_t: float) -> void:
		pass

	func _on_launched(_i: int, _gag: int) -> void:
		pass

	func _party() -> void:
		pass

	func _check_stuck() -> void:
		pass

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _crash_tap(i: int, blocked: int, t: float) -> void:
		super(i, blocked, t)
		out_of_hearts = false
		_running = true

	## The sky as the page deals it: PLANES on `b`'s rules, judged when
	## `judged`, the cloud blowing east when `windy`, popped in with the
	## board's entrance when `enter`.
	func lay(b: int, judged: bool, windy: bool, enter: bool) -> void:
		_gen += 1
		_close_card()
		var st := State.new()
		st.rows = ROWS
		st.cols = COLS
		st.difficulty = b
		st.clear_occupancy()
		for p in PLANES:
			var cells: Array[Vector2i] = []
			for c in p:
				cells.append(c)
			st.add_plane(cells)
		for i in ORDER:
			st.order.append(i)
		st.judged = judged
		st.undo_allowed = b < 3
		if windy:
			st.wind = Vector2i(1, 0)
			st.clouds.append(CLOUD)
		_state = st
		max_hearts = State.hearts_for(b) if judged else 0
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_heart_used = false
		_lost_ever = false
		_undo_ever = false
		_flawless = false
		_hint_lit = -1
		_anim_until = 0.0
		_solved_at = -1.0
		_solve_from = Vector2i.ZERO
		_forget()
		_deal()
		_reset_rewards()
		_place_sprigs()
		_layout()
		if enter:
			_enter()
		else:
			_opened = _now() - 10.0
			_refresh_all()
		_tip_timer.stop()
		_idle_next = FAR

	## The planes in `which` gone already, as if flown long ago.
	func gone(which: Array) -> void:
		for i in which:
			_state.launch(i)
		_glide_from = float(_state.count())
		_glide_to = _glide_from
		_refresh_all()

	## The win as the board shows it, without the party: the solve wave.
	func win() -> void:
		_done = true
		_running = false
		_on_solved()

	## Where a finger taps plane `i`: the middle of its head cell.
	func head_at(i: int) -> Vector2:
		var cells: Array = _state.planes[i]["cells"]
		var c: Vector2i = cells[cells.size() - 1]
		return cell_to_local(c.y, c.x)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = TutorialSky.new()
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

## The sky as tall as the page leaves over the caption and the page's whole
## width: the board centres its own grid, and a judged band's hearts sit in
## their strip over it.
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
	# and a second would deal the sky again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
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
		Lesson.LAUNCH:
			_play_tap(C, "HTP_PP_TAP_CAP")
			_say_for("HTP_PP_GONE_CAP", 2.4)
		Lesson.ORDER:
			_play_tap(B, "HTP_PP_FRONT_CAP")
			_loop.tween_interval(1.0)
			_say_for("HTP_PP_FREE_CAP", 1.0)
			_play_tap(A, "")
			_loop.tween_interval(1.8)
		Lesson.REFUSE:
			_play_tap(A, "")
			_loop.tween_interval(0.1)
			_say_for("HTP_PP_WAIT_CAP", 2.0)
			_play_tap(B, "HTP_PP_FRONT_CAP")
			_loop.tween_interval(1.0)
			_play_tap(A, "")
			_loop.tween_interval(1.8)
		Lesson.HEARTS:
			_play_tap(A, "")
			_loop.tween_interval(0.2)
			_say_for("HTP_PP_BONK_CAP", 2.6)
		Lesson.DONE:
			_play_tap(D, "")
			_loop.tween_interval(0.6)
			_play_tap(F, "")
			_loop.tween_interval(0.9)
			_loop.tween_callback(func() -> void: _art.win())
			_say_for("HTP_PP_DONE_CAP", 3.0)
		Lesson.WIND:
			_loop.tween_interval(0.6)
			_play_tap(B, "HTP_PP_BLOW_CAP")
			_loop.tween_interval(1.4)
			_say_for("HTP_PP_PAST_CAP", 0.8)
			_play_tap(C, "")
			_loop.tween_interval(2.0)
		Lesson.UNDO:
			if band < 3:
				_play_tap(C, "HTP_PP_TAP_CAP")
				_loop.tween_interval(1.2)
				_loop.tween_callback(_say.bind("HTP_PP_UNDO_CAP"))
				_loop.tween_interval(0.5)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.8)
			_play_tap(B, "HTP_PP_TAP_CAP")
			_loop.tween_interval(0.5)
			_play_tap(E, "")
			_loop.tween_interval(1.4)
			_loop.tween_callback(_say.bind("HTP_PP_RESET_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(3.0)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## A tap on plane `i`: the finger comes down on its head (the caption turning
## to `say` when not ""), the plane sinks, and the finger lifts -- the launch.
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

## Every lesson back to its question: the sky as dealt (DONE's down to its
## last two planes), every heart, nothing in flight. `fresh` is the first
## deal, which pops the sky in with the board's entrance.
func _reset(fresh := false) -> void:
	var judged := band >= 2 and hearts > 0
	_art.lay(band, judged, lesson == Lesson.WIND, fresh)
	if lesson == Lesson.DONE:
		_art.gone([B, E, C, G, A])
	_lift()
	_say({Lesson.LAUNCH: "HTP_PP_CLEAR_CAP", Lesson.ORDER: "HTP_PP_BLOCKED_CAP",
		Lesson.REFUSE: "HTP_PP_BLOCKED_CAP", Lesson.HEARTS: "HTP_PP_BLOCKED_CAP",
		Lesson.DONE: "HTP_PP_LAST_CAP", Lesson.WIND: "HTP_PP_CLOUD_CAP",
		Lesson.UNDO: "HTP_PP_TAP_CAP", Lesson.HINT: "HTP_PP_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.LAUNCH:
			_art._tap(C)
			_say("HTP_PP_GONE_CAP")
		Lesson.ORDER:
			_art._tap(B)
			_say("HTP_PP_FREE_CAP")
		Lesson.REFUSE:
			_say("HTP_PP_WAIT_CAP")
		Lesson.HEARTS:
			_say("HTP_PP_BLOCKED_CAP")
		Lesson.DONE:
			_art._tap(D)
			_art._tap(F)
			_art.win()
			_say("HTP_PP_DONE_CAP")
		Lesson.WIND:
			_art._tap(B)
			_say("HTP_PP_PAST_CAP")
		Lesson.UNDO:
			_say("HTP_PP_UNDO_CAP" if band < 3 else "HTP_PP_RESET_CAP")
		Lesson.HINT:
			_art.hint()
	_art._refresh_all()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(i: int) -> void:
	_finger = _art.position + _art.head_at(i)
	_down = false

func _press(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _art.head_at(i)
	_down = true
	_art._gui_input(ev)

func _release(i: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = _art.head_at(i)
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
