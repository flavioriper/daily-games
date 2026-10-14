extends Control

## One page of Yarn Hoop's tutorial: a small hoop played by the board itself.
## The page holds a `Small` -- hoop2d.gd with its sounds, buzzes, toast,
## pill, party and seal taken out -- laid with a hand-cut picture of three
## triangles and a square, and plays the lesson on a loop through the
## board's own hand (`press`, `drag`, `release`, as a finger would), over a
## caption that says what it means. `lesson` picks the page (set before it
## enters the tree):
##
## - THREAD: a drag from pin to pin lays a side; a drag between two pins
##   that share no side is refused.
## - FILL: every side of a triangle threaded, and it knits in.
## - COMBO: one long drag closes the three triangles in a row.
## - BLIND (Insane): the same triangle, with no corner dots to read.
## - HINT: the bulb lays a thread.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { THREAD, FILL, COMBO, BLIND, HINT }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0
## Seconds the finger takes from one pin to the next.
const LEG := 0.4

## The picture, in its own squares: three triangles along the top, 0-1-3,
## 1-4-3 and 1-2-4, and a square under the middle one, 3-4-6-5.
const PINS := [Vector2(0, 0), Vector2(2, 0), Vector2(4, 0), Vector2(1, 2), Vector2(3, 2), Vector2(1, 4), Vector2(3, 4)]
const PANELS := [[0, 1, 3], [1, 4, 3], [1, 2, 4], [3, 4, 6, 5]]
const COLOURS := ["yellow", "orange", "red", "teal"]

var lesson: int = Lesson.THREAD

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
class Small extends "res://puzzles/hoop2d.gd":
	func puzzle_id() -> String:
		return "hoop_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func _tell(_text: String) -> void:
		pass

	func _party(_lag: float) -> void:
		pass

	func _stamped() -> bool:
		return false

	## No pill on the page: only the combo's bubble.
	func _draw_hud() -> void:
		if _k > 0.0:
			_draw_combo(_now())

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

	## The hand-cut picture laid on `band`, popped in with the board's
	## entrance.
	func lay(band: int) -> void:
		_gen += 1
		_fresh()
		state.band = band
		state.adopt_laid(PINS, PANELS, COLOURS)
		_begin()

	## The same picture from the top.
	func again() -> void:
		_gen += 1
		_fresh()
		state.reset()
		_begin()

	func _fresh() -> void:
		hints_used = 0
		hints_extra = 9
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
	_art.size = size
	# the board keeps a row for its pill at the top: the page has none
	_art.set_clear(-_art.HUD_ROW + 6.0, CAPTION_H)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 2.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 4.0)
	_place_chip()
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

## The bulb at the page's lower right, over the table beside the hoop.
func _place_chip() -> void:
	if _chip == null:
		return
	var want: Vector2 = _chip.get_combined_minimum_size()
	_chip.size = want
	var k := CHIP_SCALE * 0.8
	_chip_holder.scale = Vector2(k, k)
	_chip_holder.position = Vector2(size.x - want.x * k - 14.0, size.y - CAPTION_H - want.y * k - 6.0)

func _chip_mid() -> Vector2:
	return _chip_holder.position + _chip.size * _chip_holder.scale * 0.5

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

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
	_loop.tween_interval(1.4)
	match lesson:
		Lesson.THREAD:
			_stroke([0, 1], "HTP_YH_DRAG_CAP", 1.0)
			_stroke([3, 2], "HTP_YH_NO_CAP", 1.8)
		Lesson.FILL, Lesson.BLIND:
			var cap := "HTP_YH_BLIND_CAP" if lesson == Lesson.BLIND else "HTP_YH_DRAG_CAP"
			_stroke([0, 1, 3, 0], cap, 0.2)
			_loop.tween_callback(_say.bind("HTP_YH_BLIND_CAP" if lesson == Lesson.BLIND else "HTP_YH_FILL_CAP"))
			_loop.tween_interval(2.0)
		Lesson.COMBO:
			_stroke([3, 0, 1, 3, 4, 1, 2, 4], "HTP_YH_COMBO_CAP", 2.6)
		Lesson.HINT:
			for k in 3:
				_press_chip()
				_loop.tween_interval(1.3)
	_loop.tween_callback(_reset)

## The finger presses pin `path[0]`, drags through the rest in order and
## lets go; the caption turns to `say` as it comes, then the hoop plays for
## `wait`.
func _stroke(path: Array, say: String, wait: float) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(func() -> void: _finger = _art.pin_screen(int(path[0])))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void:
		_down = true
		_art.press(_art.pin_screen(int(path[0]))))
	_loop.tween_interval(0.15)
	for m in range(1, path.size()):
		var a := int(path[m - 1])
		var b := int(path[m])
		_loop.tween_method(func(t: float) -> void:
			var at: Vector2 = _art.pin_screen(a).lerp(_art.pin_screen(b), t)
			_finger = at
			_art.drag(at), 0.0, 1.0, LEG).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.15)
	_loop.tween_callback(func() -> void:
		_art.release(_finger)
		_down = false)
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## The finger presses the page's bulb, which lays a thread.
func _press_chip() -> void:
	_loop.tween_callback(_say.bind("HTP_YH_BULB_CAP"))
	_loop.tween_callback(func() -> void: _finger = _chip_mid())
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

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _say(key: String) -> void:
	_caption.text = tr(key)

## The hoop from the top: laid the first time, played again after.
func _reset(first := false) -> void:
	_lift()
	var band := 3 if lesson == Lesson.BLIND else 0
	if first or _art.state.pins.is_empty():
		_art.lay(band)
	else:
		_art.again()
	_say(_opening())
	_place_chip()

func _opening() -> String:
	match lesson:
		Lesson.THREAD, Lesson.FILL: return "HTP_YH_DRAG_CAP"
		Lesson.COMBO: return "HTP_YH_COMBO_CAP"
		Lesson.BLIND: return "HTP_YH_BLIND_CAP"
	return "HTP_YH_BULB_CAP"

## Motion reduced: the hoop as it lies, under the lesson's line.
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
