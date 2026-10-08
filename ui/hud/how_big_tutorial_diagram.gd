extends Control

## One page of How Big?'s tutorial: a small day played by the board itself.
## The page holds a `Stage` -- how_big2d.gd with its sounds, buzzes, win and
## out-of-hearts card taken out -- dealt a hand-picked pair, and plays the
## lesson on a loop through the board's own input path (a touch pressed on
## the grip, dragged and let go, in board coordinates, as a finger would),
## over a caption that says what it means. So the white shape is rebuilt at
## every size the finger gives it, the truth grows out of the guess in the
## grade's colour, the card pops, the thing crosses over on the Ladder and a
## heart goes, exactly as on the board. `lesson` picks the page (set before
## it enters the tree):
##
## - SIZE: the finger pulls the white shape bigger, smaller, then about right.
## - LOCK: sized a little over, the page's Lock is pressed; the truth grows
##   out and the card says how far off.
## - GRADE: the same pair locked three times -- spot on, 30% over, 2.7
##   times too big -- for the three colours and their points.
## - TAPE (Easy): the answer's caption reading the size as the finger drags.
## - LADDER (Insane): a lock a quarter over, Next, and the thing crossing to
##   be the ruler at the size it was given.
## - HEARTS (Insane): a lock 2.5 times too big; a heart goes.
## - HINT: the bulb pressed on an answer too small; the grip turns leaf, the
##   toast says bigger, and the finger pulls it there.
##
## The board has fixed chrome (the pills' row, the grass with its captions,
## the result card) that a page a third of a phone tall cannot hold, so the
## Stage is laid out `BOARD_H` tall and drawn scaled down to the page; the
## finger and the chip are the page's own, at the page's scale.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { SIZE, LOCK, GRADE, TAPE, LADDER, HEARTS, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 24.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
## How tall the board believes it is, and the widest it is laid out.
const BOARD_H := 680.0
const BOARD_W := 1000.0
## The strip right of the board for the page's own Lock or bulb (the screen's
## are under the card), as the screen dresses them, in a holder that makes
## them small.
const CHIP_ROOM := 190.0
const CHIP_SCALE := 0.8
const LOCK_SIZE := Vector2(260.0, 130.0)
const BULB_SIZE := 110.0

## Each lesson's day: the band, the rounds as [ruler, answer] and the lot
## that frames them (how_big_state.gd's `frame`: a low lot leaves the most
## room over the truth, which GRADE's and HEARTS's misses need). Only the
## first round is ever locked, so no day here ends.
const DAYS := {
	Lesson.SIZE: {"band": 1, "lot": 0.5, "rounds": [["person", "horse"], ["dog", "sheep"], ["car", "bus"], ["cat", "dog"], ["door", "giraffe"]]},
	Lesson.LOCK: {"band": 1, "lot": 0.1, "rounds": [["cat", "dog"], ["person", "horse"], ["car", "bus"], ["dog", "sheep"], ["door", "giraffe"]]},
	Lesson.GRADE: {"band": 1, "lot": 0.0, "rounds": [["bicycle", "cow"], ["cat", "dog"], ["car", "bus"], ["dog", "sheep"], ["door", "giraffe"]]},
	Lesson.TAPE: {"band": 0, "lot": 0.5, "rounds": [["person", "elephant"], ["cat", "dog"], ["car", "bus"], ["dog", "sheep"], ["door", "giraffe"]]},
	Lesson.LADDER: {"band": 3, "lot": 0.1, "rounds": [["cat", "dog"], ["dog", "sheep"], ["sheep", "cow"], ["cow", "elephant"],
		["elephant", "orca"], ["orca", "trex"], ["trex", "whale"]]},
	Lesson.HEARTS: {"band": 3, "lot": 0.0, "rounds": [["football", "rabbit"], ["rabbit", "dog"], ["dog", "sheep"], ["sheep", "cow"],
		["cow", "elephant"], ["elephant", "orca"], ["orca", "whale"]]},
	Lesson.HINT: {"band": 1, "lot": 0.5, "rounds": [["dog", "horse"], ["cat", "dog"], ["car", "bus"], ["dog", "sheep"], ["door", "giraffe"]]},
}
## How far off the lessons' locks are, the guess over the truth.
const LOCK_OVER := 1.08
const FAIR_OVER := 1.3
## (The stage gives the answer 1.9 to 2.8 times its truth to grow into.)
const OFF_OVER := 2.7
const LADDER_OVER := 1.25
const HEART_OVER := 2.5

var lesson: int = Lesson.SIZE

var _art: Stage
var _over: Control
var _caption: Label
var _chip: IconButton
var _chip_holder: Control
var _loop: Tween
var _begun := false
var _k := 1.0
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _on_chip := false                # the finger is at the page's chip
var _down := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none) and no buzz, no win,
## no out-of-hearts card, and nothing counted.
class Stage extends "res://puzzles/how_big2d.gd":
	func puzzle_id() -> String:
		return "how_big_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _finish() -> void:
		pass

	func _on_solved() -> void:
		pass

	## A timer of the page's own, which goes when the page does (the board's
	## hangs on the tree, and a page turned away is freed off it).
	func _after(delay: float, what: Callable) -> void:
		var gen := _gen
		if delay <= 0.0:
			what.call()
			return
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = maxf(delay, 0.01)
		timer.autostart = true
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			if gen == _gen and is_inside_tree():
				what.call())
		add_child(timer)

	## Day `d` (one of DAYS) dealt, popped in with the board's entrance.
	func lay(d: Dictionary) -> void:
		_gen += 1
		_fresh()
		state.setup_fixed(int(d.band), d.rounds, float(d.lot))
		_begin()

	## The same day from its first round: the pair dropped in again, the card
	## standing as it was.
	func again() -> void:
		_gen += 1
		_fresh()
		state.restart()
		_deal()
		_result_mesh = null
		_layout()
		_round_at = _now()
		_busy_for(Motion.DROP_TIME + TGT_LAG + Motion.POP_IN)
		_hud_layer.queue_redraw()

	func _fresh() -> void:
		hints_used = 0
		hints_extra = 0
		moves = 0
		checks = 0
		_done = false
		_running = true

	## Stops whatever the board had waiting (the page is leaving the tree).
	func hush() -> void:
		_gen += 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Stage.new()
	add_child(_art)
	if lesson == Lesson.LOCK or lesson == Lesson.GRADE or lesson == Lesson.LADDER or lesson == Lesson.HEARTS:
		_chip = _make_chip(IconButton.new("check", "HB_LOCK", "SunButton"), LOCK_SIZE)
		CozyTheme.accent_button(_chip, _accent(), 40)
	elif lesson == Lesson.HINT:
		_chip = _make_chip(IconButton.new("bulb"), Vector2.ONE * BULB_SIZE)
		CozyTheme.lift_button(_chip, Pal.SURFACE, int(BULB_SIZE * 0.29))
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

## One of the screen's buttons, in a holder that makes it small (the
## button's own scale is its press).
func _make_chip(b: IconButton, at_size: Vector2) -> IconButton:
	_chip_holder = Control.new()
	_chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_holder.scale = Vector2.ONE * CHIP_SCALE
	add_child(_chip_holder)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = at_size
	_chip_holder.add_child(b)
	return b

## The colour Lock wears on the screen: the board's card's.
func _accent() -> Color:
	var puzzles: Array = load("res://ui/registry.gd").PUZZLES
	for i in puzzles.size():
		if String(puzzles[i].get("id", "")) == "how_big":
			return Pal.CAT[i % Pal.CAT.size()]
	return Pal.SUN

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null
	if is_instance_valid(_art):
		_art.hush()

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and _loop == null:
		call_deferred("_start")

## The board `BOARD_H` tall, scaled to what the page leaves over the caption,
## with the chip's strip (when there is one) to its right.
func _layout() -> void:
	if _art == null:
		return
	var room := Vector2(size.x - (CHIP_ROOM if _chip != null else 0.0), maxf(0.0, size.y - CAPTION_H))
	_k = maxf(0.05, room.y / BOARD_H)
	var wide := clampf(room.x / _k, 200.0, BOARD_W)
	var left := maxf(0.0, (room.x - wide * _k) * 0.5)
	_art.scale = Vector2(_k, _k)
	_art.position = Vector2(left, 0.0)
	_art.size = Vector2(wide, BOARD_H)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 2.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 4.0)
	if _chip != null:
		var want: Vector2 = _chip.get_combined_minimum_size()
		_chip.size = want
		var from := left + wide * _k
		var gap := size.x - from
		var k := minf(CHIP_SCALE, (gap - 24.0) / maxf(want.x, 1.0))
		_chip_holder.scale = Vector2(k, k)
		_chip_holder.position = Vector2(from + gap * 0.5, room.y * 0.5) - want * k * 0.5
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _chip_mid() -> Vector2:
	return _chip_holder.position + _chip.size * _chip_holder.scale * 0.5

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _on_chip or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the day again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.8)
	match lesson:
		Lesson.SIZE:
			_grab("HTP_HB_SIZE_CAP")
			_pull(1.75, 0.9, 0.35)
			_pull(0.55, 1.1, 0.35)
			_pull(1.0, 0.9, 0.3)
			_say_for("HTP_HB_SIZE_DONE_CAP", 0.5)
			_drop()
			_loop.tween_interval(2.6)
		Lesson.LOCK:
			_grab("")
			_pull(LOCK_OVER, 0.9, 0.3)
			_drop()
			_press_chip("HTP_HB_LOCK_PRESS_CAP", _lock)
			_say_for("HTP_HB_LOCK_CAP", 4.2)
		Lesson.GRADE:
			_graded(1.0, "HTP_HB_GRADE_SPOT_CAP")
			_loop.tween_callback(_again)
			_loop.tween_interval(1.0)
			_graded(FAIR_OVER, "HTP_HB_GRADE_FAIR_CAP")
			_loop.tween_callback(_again)
			_loop.tween_interval(1.0)
			_graded(OFF_OVER, "HTP_HB_GRADE_OFF_CAP")
			_loop.tween_interval(0.8)
		Lesson.TAPE:
			_grab("HTP_HB_TAPE_CAP")
			_pull(1.6, 1.3, 0.5)
			_pull(0.6, 1.5, 0.5)
			_pull(1.0, 1.2, 0.4)
			_drop()
			_loop.tween_interval(2.4)
		Lesson.LADDER:
			_grab("")
			_pull(LADDER_OVER, 0.8, 0.3)
			_drop()
			_press_chip("", _lock)
			_say_for("HTP_HB_LADDER_OVER_CAP", 2.2)
			_press_chip("", _lock)
			_say_for("HTP_HB_LADDER_CAP", 1.0)
			# The crossing over, the chip is Lock again as the screen's is.
			_loop.tween_callback(_dress_chip)
			_loop.tween_interval(3.4)
		Lesson.HEARTS:
			_grab("")
			_pull(HEART_OVER, 0.9, 0.3)
			_drop()
			_press_chip("", _lock)
			_say_for("HTP_HB_HEARTS_CAP", 4.2)
		Lesson.HINT:
			_press_chip("", _hint)
			_say_for("HTP_HB_HINT_CAP", 1.5)
			_grab("HTP_HB_HINT_DONE_CAP")
			_pull(1.0, 1.0, 0.4)
			_drop()
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger comes to the grip and presses it; the caption turns to `cap`.
func _grab(cap: String) -> void:
	_loop.tween_callback(func() -> void: _point_at(_art.grip_point()))
	_loop.tween_interval(0.5)
	if cap != "":
		_loop.tween_callback(_say.bind(cap))
	_loop.tween_callback(_touch.bind(true))
	_loop.tween_interval(0.25)

## The held finger drags the grip to where the answer reads `times` its true
## size, over `time`, and rests there for `rest`.
func _pull(times: float, time: float, rest: float) -> void:
	_loop.tween_callback(func() -> void:
		_from = _finger
		_to = _art.grip_for(_art.state.truth() * times))
	_loop.tween_method(_drag, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(rest)

## The finger lets go and leaves.
func _drop() -> void:
	_loop.tween_callback(_touch.bind(false))
	_loop.tween_interval(0.3)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## GRADE's one lock: sized to `times` the truth, locked, the card read.
func _graded(times: float, cap: String) -> void:
	_grab("")
	_pull(times, 0.6, 0.2)
	_drop()
	_press_chip("", _lock)
	_say_for(cap, 2.7)

## The finger presses the page's chip, which does `what`.
func _press_chip(before: String, what: Callable) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void:
		_on_chip = true
		_down = false)
	_loop.tween_interval(0.55)
	_loop.tween_callback(func() -> void:
		_down = true
		_chip.squish())
	_loop.tween_interval(0.18)
	_loop.tween_callback(what)
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## The page's Lock: the board's own check, which locks and then deals the
## next; the chip is dressed as the screen's button would be after it.
func _lock() -> void:
	_art.check()
	_dress_chip()

func _hint() -> void:
	_art.hint()

func _dress_chip() -> void:
	if _chip == null or lesson == Lesson.HINT:
		return
	_chip.set_icon(_art.check_icon())
	_chip.set_label(_art.check_label())

## GRADE: the same pair again, for the next lock.
func _again() -> void:
	_art.again()
	_dress_chip()
	_say("HTP_HB_GRADE_START_CAP")

## Every lesson back to its question. `fresh` is the first deal, which pops
## the card in with the board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(DAYS[lesson])
	else:
		_art.again()
	_lift()
	_dress_chip()
	_say({Lesson.SIZE: "HTP_HB_SIZE_START_CAP", Lesson.LOCK: "HTP_HB_LOCK_START_CAP",
		Lesson.GRADE: "HTP_HB_GRADE_START_CAP", Lesson.TAPE: "HTP_HB_TAPE_START_CAP",
		Lesson.LADDER: "HTP_HB_LADDER_START_CAP", Lesson.HEARTS: "HTP_HB_HEARTS_START_CAP",
		Lesson.HINT: "HTP_HB_HINT_START_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still. A lock waits out the
## beat the board holds a fresh round for.
func _still() -> void:
	var truth: float = _art.state.truth()
	match lesson:
		Lesson.SIZE:
			_art.size_to(truth)
			_say("HTP_HB_SIZE_DONE_CAP")
		Lesson.TAPE:
			_art.size_to(truth)
			_say("HTP_HB_TAPE_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_HB_HINT_CAP")
		_:
			var over: float = {Lesson.LOCK: LOCK_OVER, Lesson.GRADE: FAIR_OVER, Lesson.LADDER: LADDER_OVER,
				Lesson.HEARTS: HEART_OVER}[lesson]
			_art.size_to(truth * over)
			_loop = create_tween()
			_loop.tween_interval(0.4)
			_loop.tween_callback(_lock)
			if lesson == Lesson.LADDER:
				_loop.tween_interval(0.8)
				_loop.tween_callback(_lock)
				_loop.tween_interval(0.5)
				_loop.tween_callback(_dress_chip)
			_say({Lesson.LOCK: "HTP_HB_LOCK_CAP", Lesson.GRADE: "HTP_HB_GRADE_FAIR_CAP",
				Lesson.LADDER: "HTP_HB_LADDER_CAP", Lesson.HEARTS: "HTP_HB_HEARTS_CAP"}[lesson])

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the finger, through the board's own input ---

func _point_at(at: Vector2) -> void:
	_finger = at
	_on_chip = false
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_on_chip = false
	_down = false

## A touch pressed or let go where the finger is.
func _touch(pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = _finger
	_down = pressed
	_art._gui_input(ev)

## The held finger `u` of the way along its pull.
func _drag(u: float) -> void:
	var at := _from.lerp(_to, u)
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = at
	ev.relative = at - _finger
	_finger = at
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0 and not _on_chip:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _chip_mid() if _on_chip else _art.position + _finger * _k
	at += Vector2(FINGER_R * 0.4, FINGER_R * 0.5)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
