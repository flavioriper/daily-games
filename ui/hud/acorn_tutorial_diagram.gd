extends Control

## One page of Golden Acorn's tutorial: a question asked by the board itself.
## The page holds a `Stage` -- acorn2d.gd with its sounds, buzzes, win and
## out-of-hearts card taken out -- dealt a hand-picked question, and plays the
## lesson on a loop through the board's own input path (a touch pressed and
## let go on a plate, in board coordinates, as a finger would), over a
## caption that says what it means. `lesson` picks the page (set before it
## enters the tree):
##
## - PICK: the finger taps one answer, then another; the light moves.
## - LOCK: the right answer picked, the page's Lock pressed; the held
##   breath, then the plate turns leaf green.
## - WHY: a wrong answer locked; it turns berry, the right one green, and
##   the line under the question says why. Then Next.
## - CLIMB (Insane): a wrong lock, and a heart goes.
## - HINT: the bulb pressed; two wrong answers fade, and the finger picks
##   from what is left.
##
## The board has fixed chrome (the pills' row, the paper, four plates) that a
## page a third of a phone tall cannot hold, so the Stage is laid out
## `BOARD_H` tall and drawn scaled down to the page; the finger and the chip
## are the page's own, at the page's scale.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { PICK, LOCK, WHY, CLIMB, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 24.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
## How tall the board believes it is, and the widest it is laid out.
const BOARD_H := 760.0
const BOARD_W := 760.0
## The strip right of the board for the page's own Lock or bulb (the screen's
## are under the card), as the screen dresses them, in a holder that makes
## them small.
const CHIP_ROOM := 190.0
const CHIP_SCALE := 0.8
const LOCK_SIZE := Vector2(260.0, 130.0)
const BULB_SIZE := 110.0

## The questions the pages ask, in the contract's shape
## (tools/acorn/CONTRACT.md). Every page puts the right answer at C.
const ASKED := [
	{"id": "t001", "cat": "science",
		"en": {"q": "Which planet is known as the Red Planet?", "right": "Mars", "wrong": ["Venus", "Jupiter", "Saturn"],
			"why": "Rust in its soil gives Mars its red colour."},
		"pt": {"q": "Qual planeta é conhecido como o Planeta Vermelho?", "right": "Marte", "wrong": ["Vênus", "Júpiter", "Saturno"],
			"why": "A ferrugem do solo dá a Marte a cor vermelha."},
		"es": {"q": "¿Qué planeta se conoce como el Planeta Rojo?", "right": "Marte", "wrong": ["Venus", "Júpiter", "Saturno"],
			"why": "El óxido de su suelo le da a Marte su color rojo."}},
	{"id": "t002", "cat": "nature",
		"en": {"q": "How many legs does a spider have?", "right": "Eight", "wrong": ["Six", "Ten", "Four"],
			"why": "Eight legs is what sets spiders apart from insects, which have six."},
		"pt": {"q": "Quantas pernas tem uma aranha?", "right": "Oito", "wrong": ["Seis", "Dez", "Quatro"],
			"why": "Oito pernas diferenciam as aranhas dos insetos, que têm seis."},
		"es": {"q": "¿Cuántas patas tiene una araña?", "right": "Ocho", "wrong": ["Seis", "Diez", "Cuatro"],
			"why": "Ocho patas distinguen a las arañas de los insectos, que tienen seis."}},
]
const RIGHT_AT := 2
## Each lesson's band (the Climb's has hearts; Easy's has the bulb).
const BANDS := {Lesson.PICK: 1, Lesson.LOCK: 1, Lesson.WHY: 1, Lesson.CLIMB: 3, Lesson.HINT: 0}

var lesson: int = Lesson.PICK

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
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none) and no buzz, no win,
## no out-of-hearts card, and nothing counted.
class Stage extends "res://puzzles/acorn2d.gd":
	func puzzle_id() -> String:
		return "acorn_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func _run_out() -> void:
		pass

	func _open_card() -> void:
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

	## `list` dealt on `band`, popped in with the board's entrance.
	func lay(band: int, list: Array, right_at: int) -> void:
		_gen += 1
		_fresh()
		state.setup_fixed(band, list, right_at)
		_begin()

	## The same questions from the first: the plates popped in again, the
	## card standing as it was.
	func again() -> void:
		_gen += 1
		_fresh()
		state.restart()
		_clear()
		_phase = Phase.PLAY
		_layout()
		_round_at = _now()
		_busy_for(Motion.POP_IN + 4.0 * PLATE_STAGGER + 0.1)
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
	if lesson == Lesson.LOCK or lesson == Lesson.WHY or lesson == Lesson.CLIMB:
		_chip = _make_chip(IconButton.new("check", "AC_LOCK", "SunButton"), LOCK_SIZE)
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
		if String(puzzles[i].get("id", "")) == "acorn":
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
	# and a second would deal the question again without its entrance.
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
		Lesson.PICK:
			_tap(1, "HTP_AC_PICK_CAP")
			_loop.tween_interval(1.2)
			_tap(RIGHT_AT, "HTP_AC_PICK_DONE_CAP")
			_loop.tween_interval(2.6)
		Lesson.LOCK:
			_tap(RIGHT_AT, "")
			_press_chip("HTP_AC_LOCK_PRESS_CAP", _lock)
			_say_for("HTP_AC_LOCK_CAP", 4.0)
		Lesson.WHY:
			_tap(0, "")
			_press_chip("", _lock)
			_say_for("HTP_AC_WHY_CAP", 3.4)
			_press_chip("HTP_AC_WHY_NEXT_CAP", _lock)
			_loop.tween_callback(_dress_chip)
			_loop.tween_interval(2.4)
		Lesson.CLIMB:
			_tap(3, "")
			_press_chip("", _lock)
			_say_for("HTP_AC_CLIMB_CAP", 4.2)
		Lesson.HINT:
			_press_chip("", _hint)
			_say_for("HTP_AC_HINT_CAP", 1.8)
			_tap(RIGHT_AT, "HTP_AC_HINT_DONE_CAP")
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger comes to plate `place`, presses it and lets go; the caption
## turns to `cap`.
func _tap(place: int, cap: String) -> void:
	_loop.tween_callback(func() -> void: _point_at(_art.plate_point(place)))
	_loop.tween_interval(0.5)
	if cap != "":
		_loop.tween_callback(_say.bind(cap))
	_loop.tween_callback(_touch.bind(true))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_touch.bind(false))
	_loop.tween_interval(0.3)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

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

## Every lesson back to its question. `fresh` is the first deal, which pops
## the card in with the board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(BANDS[lesson], ASKED, RIGHT_AT)
	else:
		_art.again()
	_lift()
	_dress_chip()
	_say({Lesson.PICK: "HTP_AC_PICK_START_CAP", Lesson.LOCK: "HTP_AC_LOCK_START_CAP",
		Lesson.WHY: "HTP_AC_WHY_START_CAP", Lesson.CLIMB: "HTP_AC_CLIMB_START_CAP",
		Lesson.HINT: "HTP_AC_HINT_START_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.PICK:
			_art.pick_answer(RIGHT_AT)
			_say("HTP_AC_PICK_DONE_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_AC_HINT_CAP")
		_:
			_art.pick_answer({Lesson.LOCK: RIGHT_AT, Lesson.WHY: 0, Lesson.CLIMB: 3}[lesson])
			_lock()
			_say({Lesson.LOCK: "HTP_AC_LOCK_CAP", Lesson.WHY: "HTP_AC_WHY_CAP", Lesson.CLIMB: "HTP_AC_CLIMB_CAP"}[lesson])

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
