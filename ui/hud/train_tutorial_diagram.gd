extends Control

## One page of Toy Cannons' tutorial (the board built as Toy Train: an
## engine here is a cannon, the siding its tray, the shed the toy box): a
## small rug played by the board itself.
## The page holds a `Small` -- train2d.gd with its sounds, buzzes, toast,
## pill, party and seal taken out -- laid with a hand-made rug, and plays
## the lesson on a loop through the board's own input path (a press on an
## engine and its release, as a finger would), over a caption that says what
## it means. `lesson` picks the page (set before it enters the tree):
##
## - SEND: the front engine tapped goes round and takes its colour; full, it
##   goes home.
## - LINE: an engine sees only the nearest block of a line, so the colour on
##   the outside goes first and the one behind it comes into sight.
## - SIDING: an engine sent too early comes round with room to spare and
##   waits in the siding, to be tapped again.
## - JAM (Insane): the same, under the warning that a full siding ends the
##   day.
## - HINT: the bulb sends an engine.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { SEND, LINE, SIDING, JAM, HINT }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0
const LEGEND := {"r": "red", "g": "green", "y": "yellow"}
## Seconds a stop on a lesson's rug (the board's own, as the captions were
## timed).
const LESSON_TICK := 0.085

## Red along the top and green under it: the red engine fills on its way
## back along the top, the green one takes the rest. [rows, engines as
## [letter, load, column], columns].
const PLAIN := [["rrrr", "gggg", "gggg"], [["r", 4, 0], ["g", 8, 1]], 2]
## One red block inside a ring of green: red sees nothing until green has
## gone round.
const RINGED := [["ggg", "grg", "ggg"], [["r", 1, 0], ["g", 8, 1]], 2]

var lesson: int = Lesson.SEND

var _art: Small
var _over: Control
var _caption: Label
var _chip: IconButton
var _chip_holder: Control
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none) and no buzz, no
## toast, no pill, no party and no seal.
class Small extends "res://puzzles/train2d.gd":
	func puzzle_id() -> String:
		return "train_tutorial"

	func _ready() -> void:
		super()
		# the page is short: small engines at rest and one row of the shed
		_rest_max = 46.0
		_rows = 1
		_pill = false
		_beside = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	## The lesson's own clock: the day's is a lap in two seconds of a
	## picture hundreds of blocks round, and a rug of twelve stops would be
	## gone round before its caption was read.
	func _begin() -> void:
		super()
		_clock = LESSON_TICK
		_hurry = false
		_tick_time = LESSON_TICK

	func _tell(_text: String) -> void:
		pass

	func _party(_lag: float) -> void:
		pass

	func _stamped() -> bool:
		return false

	## A timer of the page's own, which goes when the page does (the board's
	## hangs on the tree, and a page turned away is freed off it).
	func _after(delay: float, what: Callable) -> void:
		if delay <= 0.0:
			what.call()
			return
		var gen := _gen
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = delay
		timer.autostart = true
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			if gen == _gen and is_inside_tree():
				what.call())
		add_child(timer)

	## `rug` ([rows, engines, columns]) laid, popped in with the board's
	## entrance.
	func lay(rug: Array, band: int) -> void:
		_gen += 1
		state.band = band
		state.adopt_laid(rug[0], LEGEND, rug[1], int(rug[2]))
		_fresh()
		_begin()

	## The same rug from the top.
	func again() -> void:
		_gen += 1
		_fresh()
		_solved_at = -INF
		_win_pop_at = INF
		_won = false
		_restart()

	func _fresh() -> void:
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true

	## Stops whatever the board had waiting (the page is leaving the tree).
	func hush() -> void:
		_gen += 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Small.new()
	add_child(_art)
	if lesson == Lesson.HINT:
		_chip_holder = Control.new()
		_chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip_holder.scale = Vector2.ONE * CHIP_SCALE
		add_child(_chip_holder)
		_chip = IconButton.new("bulb")
		_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip.custom_minimum_size = Vector2.ONE * BULB_SIZE
		_chip_holder.add_child(_chip)
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

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null
	if is_instance_valid(_art):
		_art.hush()

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and _loop == null:
		call_deferred("_start")

func _layout() -> void:
	if _art == null:
		return
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, maxf(0.0, size.y - CAPTION_H))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 2.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 4.0)
	_place_chip()
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

## The bulb on the floor beside the shed, under the siding's far end.
func _place_chip() -> void:
	if _chip == null or _art._cell <= 0.0:
		return
	var shed: Rect2 = _art._shed_rect
	var siding: Rect2 = _art._siding_rect
	var room := siding.end.x - shed.end.x
	var want: Vector2 = _chip.get_combined_minimum_size()
	_chip.size = want
	var k := clampf(minf(room - 12.0, shed.size.y) / maxf(want.x, 1.0), 0.3, CHIP_SCALE)
	_chip_holder.scale = Vector2(k, k)
	_chip_holder.position = Vector2(shed.end.x + room * 0.5, shed.get_center().y) - want * k * 0.5

func _chip_mid() -> Vector2:
	return _chip_holder.position + _chip.size * _chip_holder.scale * 0.5

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

func _rug() -> Array:
	return PLAIN if lesson == Lesson.SEND or lesson == Lesson.HINT else RINGED

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough.
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
		Lesson.SEND:
			_tap(0, "HTP_TT_SEND_CAP", "HTP_TT_TAKE_CAP", 1.5)
			_loop.tween_callback(_say.bind("HTP_TT_GONE_CAP"))
			_loop.tween_interval(1.2)
			_tap(1, "", "HTP_TT_TAKE_CAP", 3.0)
		Lesson.LINE:
			_tap(1, "HTP_TT_NEAR_CAP", "", 2.2)
			_tap(0, "HTP_TT_OPEN_CAP", "", 2.6)
		Lesson.SIDING, Lesson.JAM:
			_tap(0, "HTP_TT_EARLY_CAP", "", 1.6)
			_loop.tween_callback(_say.bind("HTP_TT_WAIT_CAP"))
			_loop.tween_interval(1.6)
			_tap(1, "", "", 2.2)
			_tap(0, "HTP_TT_JAM_CAP" if lesson == Lesson.JAM else "HTP_TT_AGAIN_CAP", "", 2.6)
		Lesson.HINT:
			for k in 2:
				_press_chip()
				_loop.tween_interval(2.8)
	_loop.tween_callback(_reset)

## The finger taps engine `e` where it stands: the caption turns to `before`
## as it comes, and to `after` once the tap is made; then the rug plays for
## `wait`.
func _tap(e: int, before: String, after: String, wait: float) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_art.engine_screen(e)))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(e, true))
	_loop.tween_interval(0.18)
	_loop.tween_callback(func() -> void: _button(e, false))
	if after != "":
		_loop.tween_callback(_say.bind(after))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## The finger presses the page's bulb, which sends an engine.
func _press_chip() -> void:
	_loop.tween_callback(_say.bind("HTP_TT_BULB_CAP"))
	_loop.tween_callback(func() -> void: _point_at(_chip_mid()))
	_loop.tween_interval(0.55)
	_loop.tween_callback(func() -> void:
		_down = true
		_chip.squish())
	_loop.tween_interval(0.18)
	_loop.tween_callback(func() -> void:
		_art.hints_extra = 9
		_art.hint()
		_down = false)
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## A press or a release on engine `e`, through the board's own input.
func _button(e: int, down: bool) -> void:
	_down = down
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = _art.engine_screen(e)
	_art._gui_input(ev)

func _point_at(at: Vector2) -> void:
	_finger = at

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _say(key: String) -> void:
	_caption.text = tr(key)

## The rug from the top: laid the first time, played again after.
func _reset(first := false) -> void:
	_lift()
	var band := 3 if lesson == Lesson.JAM else 0
	if first or _art.state.w <= 0:
		_art.lay(_rug(), band)
	else:
		_art.again()
	_say(_opening())
	_place_chip()

func _opening() -> String:
	match lesson:
		Lesson.SEND: return "HTP_TT_SEND_CAP"
		Lesson.LINE: return "HTP_TT_NEAR_CAP"
		Lesson.SIDING: return "HTP_TT_EARLY_CAP"
		Lesson.JAM: return "HTP_TT_JAM_CAP"
	return "HTP_TT_BULB_CAP"

## Motion reduced: the rug as it lies, under the lesson's line.
func _still() -> void:
	_say(_opening())

func _draw_finger() -> void:
	if _finger.x < 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var r := FINGER_R * (0.8 if _down else 1.0)
	b.disc(Vector2.ZERO, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r, 0.0, TAU), 3.0, Color(Pal.TEXT, 0.35), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null, Transform2D(0.0, _finger))
