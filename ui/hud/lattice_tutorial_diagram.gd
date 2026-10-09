extends Control

## One page of Lattice's tutorial: a small lattice played by the board
## itself. The page holds a `Small` -- lattice2d.gd with its sounds, buzzes,
## tip lines, toast, party and seal taken out -- dealt a hand-made 5 by 5,
## and plays the lesson on a loop through the board's own input path (a press
## on a tile and its release, in board coordinates, as a finger would), over
## a caption that says what it means. So a tile lifts under the finger, two
## cross in their arc, the ones that land at home turn green, a whole line
## hops and a settled knot turns leaf, exactly as on the board. `lesson`
## picks the page (set before it enters the tree):
##
## - SWAP: two tiles tapped and both home; then a swap that sends one home
##   and leaves the other plain, and the swap that mends it.
## - LINES: a row with three tiles home that still lacks a 2 and a 4, and
##   the two plain tiles traded into it.
## - KNOT: a knot pointing at a green 2 and a plain tile, reading 6; the 4
##   swapped in beside it and the knot turning leaf.
## - HINT: the bulb makes a swap of the answer, twice.
## - COUNT: Insane's count of swaps going down.
##
## Every lattice below is the one answer
##
##      1  2  3  4  5
##      2  .  4  .  1
##      3  4  5  1  2
##      4  .  1  .  3
##      5  1  2  3  4
##
## with a few tiles traded, written as a line of the bank
## (puzzles/lattice_gen.gd's `unpack`): cells are counted in reading order
## with the holes left out.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/lattice_gen.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { SWAP, LINES, KNOT, HINT, COUNT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
## How long two tiles take to cross and turn, before the next tap.
const TAP_WAIT := 0.7
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0

## SWAP (and HINT, COUNT): 2 and 4 traded on the top row (cells 1 and 3),
## and 5, 2, 4 round a ring on the bottom row (cells 16, 18, 20).
const SWAP_DEAL := "123452413451241351234|143252413451241321435|0LU,3DR|3"
## LINES: 4 and 2 traded on the middle row (cells 9 and 12); 5 and 2 on the
## bottom row so the day is not done.
const LINES_DEAL := "123452413451241351234|123452413251441321534||2"
## KNOT: the knot in the first gap points up at the 2 and right at cell 6,
## whose 4 has traded with the 1 of cell 14.
const KNOT_DEAL := "123452413451241351234|123452113451244321534|0UR|2"

var lesson: int = Lesson.SWAP

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

## The board, quiet: no sound set (its id names none) and no buzz, no tip
## lines or toast, no party and no seal. It is laid out for the page: the
## pill over the lattice as on the screen, the lattice to the card's foot.
class Small extends "res://puzzles/lattice2d.gd":
	## The card left under the lattice and between it and the pill.
	const EDGE := 10.0

	func puzzle_id() -> String:
		return "lattice_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_text: String, _mood: int, _near := -1) -> void:
		pass

	func _party(_lag: float) -> void:
		pass

	func _stamped() -> bool:
		return false

	func _cycle_tip() -> void:
		pass

	## The page is short: the lattice takes all of it under the pill.
	func _cell_for(available: float) -> float:
		if state.n <= 0:
			return 0.0
		return minf((size.x - 2.0 * PAD) / state.n, (available - HUD_ROW - 2.0 * EDGE) / state.n)

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

	## `line` dealt on `band`, popped in with the board's entrance.
	func lay(line: String, band: int) -> void:
		_gen += 1
		state.band = band
		state.adopt(Gen.unpack(line))
		_fresh()
		_begin()
		_tip_timer.stop()

	## The same deal from the top, the tiles popping back in.
	func again() -> void:
		_gen += 1
		_fresh()
		_solved_at = -1.0
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
	clip_contents = false
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

## The lattice as tall as the page leaves over the caption and the page's
## whole width: the board centres its own lattice.
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

## The bulb on the card right of the lattice, level with its middle.
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

func _deal() -> String:
	match lesson:
		Lesson.LINES:
			return LINES_DEAL
		Lesson.KNOT:
			return KNOT_DEAL
	return SWAP_DEAL

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the lattice again without its entrance.
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
		Lesson.SWAP:
			_tap(1, "HTP_LA_PICK_CAP", "", 0.5)
			_tap(3, "HTP_LA_SWAP_CAP", "HTP_LA_BOTH_CAP", 2.2)
			_tap(16, "", "", 0.3)
			_tap(20, "", "HTP_LA_HOME_CAP", 2.0)
			_say_for("HTP_LA_MISS_CAP", 2.0)
			_tap(18, "", "", 0.3)
			_tap(20, "", "", 3.2)
		Lesson.LINES:
			_say_for("HTP_LA_ROW_CAP", 2.2)
			_tap(9, "", "", 0.3)
			_tap(12, "", "HTP_LA_ROW_DONE_CAP", 3.4)
		Lesson.KNOT:
			_say_for("HTP_LA_KNOT_CAP", 2.2)
			_say_for("HTP_LA_KNOT_SUB_CAP", 2.2)
			_tap(14, "", "", 0.3)
			_tap(6, "", "HTP_LA_KNOT_DONE_CAP", 3.4)
		Lesson.HINT:
			_press_chip()
			_loop.tween_interval(2.6)
			_press_chip()
			_loop.tween_interval(2.6)
		Lesson.COUNT:
			_tap(1, "", "", 0.3)
			_tap(3, "", "", 1.6)
			_tap(16, "", "", 0.3)
			_tap(20, "", "", 2.6)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger taps `cell`: the caption turns to `before` as it comes, and to
## `after` once the tap is made; then the lattice settles for `wait`.
func _tap(cell: int, before: String, after: String, wait := TAP_WAIT) -> void:
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

## The finger presses the page's bulb, which makes a swap.
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

## Every lesson back to its question: the lattice as it was dealt, nothing in
## the air. `fresh` is the first deal, which pops the lattice in with the
## board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(_deal(), 3 if lesson == Lesson.COUNT else 0)
	else:
		_art.again()
	_lift()
	_place_chip()
	_say({Lesson.SWAP: "HTP_LA_PICK_CAP", Lesson.LINES: "HTP_LA_ROW_CAP", Lesson.KNOT: "HTP_LA_KNOT_CAP",
		Lesson.HINT: "HTP_LA_BULB_CAP", Lesson.COUNT: "HTP_LA_LEFT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.SWAP:
			for cell: int in [1, 3, 16, 20]:
				_art.tap(cell)
			_say("HTP_LA_HOME_CAP")
		Lesson.LINES:
			_art.tap(9)
			_art.tap(12)
			_say("HTP_LA_ROW_DONE_CAP")
		Lesson.KNOT:
			_art.tap(14)
			_art.tap(6)
			_say("HTP_LA_KNOT_DONE_CAP")
		Lesson.HINT:
			_art.hint()
		Lesson.COUNT:
			_art.tap(1)
			_art.tap(3)

## `key` through tr.
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
