extends Control

## One page of Button Box's tutorial: a small cloth played by the board
## itself. The page holds a `Small` -- buttons2d.gd with its sounds, buzzes,
## toast, party and seal taken out -- laid with a hand-made cloth, and plays
## the lesson on a loop through the board's own input path (a press on a
## button and its release, as a finger would), over a caption that says
## what it means. `lesson` picks the page (set before it enters the tree):
##
## - LIFT: a tap picks a whole run of one colour; a tap on the tin puts it
##   in.
## - SEW: the patches it left are bare, so the next run is picked and a
##   bare patch of its colour tapped: sewn. The tin's own go the same way.
## - TIN: a run longer than the tin has places.
## - HINT: the bulb makes a move.
## - ZOOM (Hard and Insane, whose pictures are big): two fingers apart
##   bring the picture close, one finger dragged looks around, and the
##   button shows it whole again. The page's fingers are real touches fed
##   to the board's own zoom.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { LIFT, SEW, TIN, HINT, ZOOM }

const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0
const LEGEND := {"r": "red", "g": "green", "y": "yellow"}

## Four moves do it: green into the tin, red home, yellow home, and the
## green out of the tin.
const PLAIN := [["rrgg", "rrgg", "yyyy"], ["ggyy", "ggyy", "rrrr"]]
## Five reds in a run and four places: one stays.
const LONG := [["yyygg", "rrrrr"], ["rrrrr", "yyygg"]]
## A picture with something in the middle to come close to; its buttons are
## its own rows, two rows down.
const FRAMED := [["yyggggyy", "ygrrrrgy", "ygryyrgy", "ygryyrgy", "ygrrrrgy", "yyggggyy"],
	["ygrrrrgy", "yyggggyy", "yyggggyy", "ygrrrrgy", "ygryyrgy", "ygryyrgy"]]
## How close the page's picture comes: at the button, and at the most.
const ZOOM_TO := Vector2(1.9, 2.3)

var lesson: int = Lesson.LIFT

var _art: Small
var _over: Control
var _caption: Label
var _chip: IconButton
var _chip_holder: Control
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
## The second finger of a pinch.
var _finger2 := Vector2(-1.0, -1.0)
var _down := false
## Where the finger went down, so it comes up on the same spot.
var _aim := Vector2.ZERO
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none) and no buzz, no
## toast, no party and no seal.
class Small extends "res://puzzles/buttons2d.gd":
	## The ZOOM page's cloth zooms, whatever its band; the page has a
	## button of its own.
	var zoom_lesson := false

	func puzzle_id() -> String:
		return "buttons_tutorial"

	func _zoom_limits() -> Vector2:
		return ZOOM_TO if zoom_lesson and _cell > 0.0 and not _won else Vector2.ONE

	func _zoom_button_wanted() -> bool:
		return false

	func _gesture_tick() -> void:
		pass

	func _ready() -> void:
		super()
		# the page is short: one row of four small places, the tin's own
		_tin_places = 4
		_tin_step_max = 58.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func _tell(_text: String, _near := -1) -> void:
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

	## `cloth` ([patches, buttons]) laid, popped in with the board's entrance.
	func lay(cloth: Array) -> void:
		_gen += 1
		state.band = 0
		state.tin_base = 4
		state.adopt_laid(cloth[0], cloth[1], LEGEND)
		_fresh()
		_begin()

	## The same cloth from the top, the buttons popping back on.
	func again() -> void:
		_gen += 1
		_fresh()
		_solved_at = -INF
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
	_art.zoom_lesson = lesson == Lesson.ZOOM
	add_child(_art)
	if lesson == Lesson.HINT or lesson == Lesson.ZOOM:
		_chip_holder = Control.new()
		_chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip_holder.scale = Vector2.ONE * CHIP_SCALE
		add_child(_chip_holder)
		_chip = IconButton.new("bulb" if lesson == Lesson.HINT else "plus")
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

## The bulb on the cloth right of the picture, level with its middle.
func _place_chip() -> void:
	if _chip == null or _art._cell <= 0.0:
		return
	var field: Rect2 = _art._field_px()
	var room := _art.size.x - field.end.x
	var want: Vector2 = _chip.get_combined_minimum_size()
	_chip.size = want
	var k := minf(CHIP_SCALE, (room - 28.0) / maxf(want.x, 1.0))
	_chip_holder.scale = Vector2(k, k)
	_chip_holder.position = Vector2(field.end.x + room * 0.5, field.get_center().y) - want * k * 0.5
	# the zoom button is at the foot of the picture's room on the left, as
	# it is on the board
	if lesson == Lesson.ZOOM:
		_chip_holder.position = Vector2(12.0, _art._view.end.y - 12.0 - want.y * k)

func _chip_mid() -> Vector2:
	return _chip_holder.position + _chip.size * _chip_holder.scale * 0.5

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()
	if lesson == Lesson.ZOOM and _chip != null:
		_chip.set_icon("minus" if _art.zoom.k > (1.0 + ZOOM_TO.x) * 0.5 else "plus")

func _cloth() -> Array:
	if lesson == Lesson.ZOOM:
		return FRAMED
	return LONG if lesson == Lesson.TIN else PLAIN

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
	_loop.tween_interval(2.0)
	match lesson:
		Lesson.LIFT:
			_tap(0, "HTP_BB_LIFT_CAP", "HTP_BB_HELD_CAP", 1.6)
			_tap(TIN, "", "HTP_BB_TIN_CAP", 3.0)
		Lesson.SEW:
			_tap(0, "", "", 0.3)
			_tap(TIN, "", "", 1.0)
			_tap(8, "HTP_BB_BARE_CAP", "", 0.9)
			_tap(0, "", "HTP_BB_SEWN_CAP", 2.2)
			_tap(2, "", "", 0.6)
			_tap(8, "", "", 1.4)
			_tap(TIN - 1, "HTP_BB_BACK_CAP", "", 0.9)
			_tap(2, "", "", 3.2)
		Lesson.TIN:
			_tap(0, "HTP_BB_LONG_CAP", "", 1.0)
			_tap(TIN, "", "HTP_BB_STAY_CAP", 3.4)
		Lesson.HINT:
			for k in 3:
				_press_chip()
				_loop.tween_interval(2.6)
		Lesson.ZOOM:
			_pinch()
			_loop.tween_interval(1.4)
			_pan()
			_loop.tween_interval(1.2)
			_loop.tween_callback(_say.bind("HTP_BB_ZOOM_BTN_CAP"))
			_press_chip()
			_loop.tween_interval(2.0)
	_loop.tween_callback(_reset)

## A square of the cloth, or the tin: TIN is its first free place and
## TIN - 1 - p its place p.
const TIN := -1

func _where(cell: int) -> Vector2:
	if cell >= 0:
		return _art.cell_centre(cell)
	if cell == TIN:
		return _art.tin_centre(mini(_art.state.in_tin(), _art._tin_places - 1))
	return _art.tin_centre(TIN - 1 - cell)

## The finger taps `cell`: the caption turns to `before` as it comes, and to
## `after` once the tap is made; then the cloth settles for `wait`.
func _tap(cell: int, before: String, after: String, wait: float) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_where(cell)))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(cell, true))
	_loop.tween_interval(0.18)
	_loop.tween_callback(func() -> void: _button(cell, false))
	if after != "":
		_loop.tween_callback(_say.bind(after))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## The finger presses the page's bulb, which makes a tap.
func _press_chip() -> void:
	_loop.tween_callback(func() -> void: _point_at(_chip_mid()))
	_loop.tween_interval(0.55)
	_loop.tween_callback(func() -> void:
		_down = true
		_chip.squish())
	_loop.tween_interval(0.18)
	_loop.tween_callback(func() -> void:
		if lesson == Lesson.ZOOM:
			_art.zoom_button()
			_art.zoom_button()
		else:
			_art.hint())
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Two fingers come down on the middle of the picture and go apart: the
## board's zoom has them as two touches, and brings the picture close.
func _pinch() -> void:
	_loop.tween_callback(_say.bind("HTP_BB_ZOOM_PINCH_CAP"))
	_loop.tween_callback(func() -> void: _two(0.0, false))
	_loop.tween_interval(0.5)
	_loop.tween_callback(func() -> void:
		_down = true
		_touch(0, _finger, true)
		_touch(1, _finger2, true))
	_loop.tween_method(func(u: float) -> void:
		_two(u, true)
		_drag(0, _finger)
		_drag(1, _finger2), 0.0, 1.0, 0.8)
	_loop.tween_interval(0.2)
	_loop.tween_callback(func() -> void:
		_touch(1, _finger2, false)
		_touch(0, _finger, false)
		_lift())

## Where a pinch's fingers are, `u` of the way apart.
func _two(u: float, down: bool) -> void:
	var mid: Vector2 = _art._view.get_center()
	var reach := Vector2(34.0, -14.0) * (1.0 + 2.4 * u)
	_finger = mid - reach
	_finger2 = mid + reach
	_down = down

## One finger dragged across the picture seen close: it pans.
func _pan() -> void:
	var from := func() -> Vector2: return _art._view.get_center() + Vector2(70.0, 30.0)
	_loop.tween_callback(_say.bind("HTP_BB_ZOOM_PAN_CAP"))
	_loop.tween_callback(func() -> void: _point_at(from.call()))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void:
		_down = true
		_touch(0, _finger, true))
	_loop.tween_method(func(u: float) -> void:
		_finger = from.call() + Vector2(-140.0, -60.0) * u
		_drag(0, _finger), 0.0, 1.0, 0.8)
	_loop.tween_interval(0.2)
	_loop.tween_callback(func() -> void:
		_touch(0, _finger, false)
		_lift())

func _touch(index: int, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = down
	ev.position = at
	_art._gui_input(ev)

func _drag(index: int, at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	_art._gui_input(ev)

## Every lesson back to its question. `fresh` is the first lay, which pops
## the cloth in with the board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(_cloth())
	else:
		_art.again()
	_lift()
	_place_chip()
	_say({Lesson.LIFT: "HTP_BB_LIFT_CAP", Lesson.SEW: "HTP_BB_BARE_CAP", Lesson.TIN: "HTP_BB_LONG_CAP",
		Lesson.HINT: "HTP_BB_BULB_CAP", Lesson.ZOOM: "HTP_BB_ZOOM_PINCH_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.LIFT:
			_art.tap(0)
			_art.tap_tin()
			_say("HTP_BB_TIN_CAP")
		Lesson.SEW:
			_art.tap(0)
			_art.tap_tin()
			_art.tap(8)
			_art.tap(0)
			_say("HTP_BB_SEWN_CAP")
		Lesson.TIN:
			_art.tap(0)
			_art.tap_tin()
			_say("HTP_BB_STAY_CAP")
		Lesson.HINT:
			_art.hint()
		Lesson.ZOOM:
			_art.zoom_button()
			_art.zoom_button()
			_say("HTP_BB_ZOOM_PINCH_CAP")

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the taps, through the board's own input ---

func _point_at(at: Vector2) -> void:
	_finger = at
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_finger2 = Vector2(-1.0, -1.0)
	_down = false

func _button(cell: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	if pressed:
		_aim = _where(cell)
	ev.position = _aim
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	var cell: float = _art._cell
	if _finger.x < 0.0 or cell <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	for finger: Vector2 in [_finger, _finger2]:
		if finger.x < 0.0:
			continue
		# a pinch's fingers are on the spot they touch; a tap's is a little
		# off its button, which it would hide
		var off := Vector2.ZERO if lesson == Lesson.ZOOM and _finger2.x >= 0.0 else Vector2(cell * 0.18, cell * 0.22)
		var at := _art.position + finger + off
		var r := (22.0 if lesson == Lesson.ZOOM else cell * FINGER_R) * (0.85 if _down else 1.0)
		b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
