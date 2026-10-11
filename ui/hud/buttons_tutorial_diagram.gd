extends Control

## One page of Button Box's tutorial: a small cloth played by the board
## itself. The page holds a `Small` -- buttons2d.gd with its sounds, buzzes,
## toast, party and seal taken out -- laid with a hand-made cloth, and plays
## the lesson on a loop through the board's own input path (a press on a
## button and its release, as a finger would), over a caption that says
## what it means. `lesson` picks the page (set before it enters the tree):
##
## - LIFT: a tap lifts a whole run of one colour, into the tin.
## - SEW: the patches it left are bare, so the next run flies home and is
##   sewn, and the tin's own drop onto the patches that run left.
## - TIN: a run longer than the tin has places; a colour whole opens one.
## - HINT: the bulb makes a tap.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { LIFT, SEW, TIN, HINT }

const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0
const LEGEND := {"r": "red", "g": "green", "y": "yellow"}

## Three taps do it: green into the tin, red home, yellow home and the
## green out of the tin behind it.
const PLAIN := [["rrgg", "rrgg", "yyyy"], ["ggyy", "ggyy", "rrrr"]]
## Five reds in a run and four places: one stays. Yellow home makes yellow
## whole, and the tin gains its fifth place.
const LONG := [["yyygg", "rrrrr"], ["rrrrr", "yyygg"]]

var lesson: int = Lesson.LIFT

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
## toast, no party and no seal.
class Small extends "res://puzzles/buttons2d.gd":
	func puzzle_id() -> String:
		return "buttons_tutorial"

	func _ready() -> void:
		super()
		# the page is short: one row of six small places, which is all a
		# tin that starts at four and gains one or two ever opens here
		_tin_places = 6
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

func _chip_mid() -> Vector2:
	return _chip_holder.position + _chip.size * _chip_holder.scale * 0.5

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

func _cloth() -> Array:
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
			_tap(0, "HTP_BB_LIFT_CAP", "HTP_BB_TIN_CAP", 3.4)
		Lesson.SEW:
			_tap(0, "", "", 1.4)
			_tap(8, "HTP_BB_BARE_CAP", "HTP_BB_SEWN_CAP", 2.6)
			_tap(2, "", "HTP_BB_BACK_CAP", 3.6)
		Lesson.TIN:
			_tap(0, "HTP_BB_LONG_CAP", "HTP_BB_STAY_CAP", 2.8)
			_tap(5, "", "HTP_BB_OPEN_CAP", 3.2)
			_tap(8, "", "", 1.4)
			_tap(4, "", "", 2.8)
		Lesson.HINT:
			for k in 3:
				_press_chip()
				_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The finger taps `cell`: the caption turns to `before` as it comes, and to
## `after` once the tap is made; then the cloth settles for `wait`.
func _tap(cell: int, before: String, after: String, wait: float) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_art.cell_centre(cell)))
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
	_loop.tween_callback(func() -> void: _art.hint())
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

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
		Lesson.HINT: "HTP_BB_BULB_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.LIFT:
			_art.tap(0)
			_say("HTP_BB_TIN_CAP")
		Lesson.SEW:
			_art.tap(0)
			_art.tap(8)
			_say("HTP_BB_SEWN_CAP")
		Lesson.TIN:
			_art.tap(0)
			_say("HTP_BB_STAY_CAP")
		Lesson.HINT:
			_art.hint()

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the taps, through the board's own input ---

func _point_at(at: Vector2) -> void:
	_finger = at
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(cell: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.cell_centre(cell)
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
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := cell * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
