extends Control

## One page of Pearl Dive's tutorial: a prompt asked by the board itself. The
## page holds a `Stage` -- pearl2d.gd with its sounds, buzzes, win and
## out-of-air card taken out -- dealt one hand-picked prompt, and plays the
## lesson on a loop through the board's own way in: the letters the
## keyboard's keys would send, one after another, and its Enter. The screen's
## keyboard is under the card and not on the page, so the line types itself;
## the one thing a finger presses here is the page's own bulb. `lesson`
## picks the page (set before it enters the tree):
##
## - TYPE: the commonest answer typed and sent; the bell goes down a metre.
## - RARE: a rare answer, and then the Pearl; the bell goes far down.
## - MISS: something the list does not hold, which costs the clock; then
##   one it does.
## - BREATH (Insane): one tank for the dive; an answer gives air back.
## - HINT: the bulb pressed; the Pearl's first letter and its length.
##
## The board has fixed chrome (the pills' row, the paper, the water) that a
## page a third of a phone tall cannot hold, so the Stage is laid out
## `BOARD_H` tall and drawn scaled down to the page.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const State = preload("res://puzzles/pearl_state.gd")

enum Lesson { TYPE, RARE, MISS, BREATH, HINT }

const FINGER_R := 24.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
## How tall the board believes it is, and the widest it is laid out.
const BOARD_H := 700.0
const BOARD_W := 760.0
## The strip right of the board for the page's own bulb.
const CHIP_ROOM := 150.0
const CHIP_SCALE := 0.8
const BULB_SIZE := 110.0
## A letter a beat, as a thumb types.
const KEY_BEAT := 0.13

## The prompt every page asks, in the contract's shape
## (tools/pearl/CONTRACT.md).
const ASKED := [
	{"id": "t001", "level": 0,
		"en": {"ask": "A fruit"}, "pt": {"ask": "Uma fruta"}, "es": {"ask": "Una fruta"},
		"answers": [
			{"t": 0, "en": ["Apple"], "pt": ["Maçã"], "es": ["Manzana"]},
			{"t": 0, "en": ["Banana"], "pt": ["Banana"], "es": ["Plátano", "Banana"]},
			{"t": 0, "en": ["Orange"], "pt": ["Laranja"], "es": ["Naranja"]},
			{"t": 1, "en": ["Mango"], "pt": ["Manga"], "es": ["Mango"]},
			{"t": 1, "en": ["Pear"], "pt": ["Pera"], "es": ["Pera"]},
			{"t": 1, "en": ["Grape"], "pt": ["Uva"], "es": ["Uva"]},
			{"t": 1, "en": ["Pineapple"], "pt": ["Abacaxi"], "es": ["Piña", "Ananá"]},
			{"t": 1, "en": ["Strawberry"], "pt": ["Morango"], "es": ["Fresa", "Frutilla"]},
			{"t": 2, "en": ["Fig"], "pt": ["Figo"], "es": ["Higo"]},
			{"t": 2, "en": ["Guava"], "pt": ["Goiaba"], "es": ["Guayaba"]},
			{"t": 2, "en": ["Papaya"], "pt": ["Mamão"], "es": ["Papaya"]},
			{"t": 2, "en": ["Quince"], "pt": ["Marmelo"], "es": ["Membrillo"]},
			{"t": 3, "en": ["Persimmon"], "pt": ["Caqui"], "es": ["Caqui"]},
			{"t": 3, "en": ["Lychee"], "pt": ["Lichia"], "es": ["Lichi"]},
			{"t": 3, "en": ["Starfruit"], "pt": ["Carambola"], "es": ["Carambola"]},
			{"t": 4, "en": ["Jackfruit"], "pt": ["Jaca"], "es": ["Yaca"]},
		]},
]
## The answers the pages type, as indices into the prompt's list.
const COMMON := 0
const KNOWN := 3
const RARE := 11
const PEARL := 15
## What the MISS page types first: a thing the list does not hold.
const WRONG := {"en": "carrot", "pt": "cenoura", "es": "zanahoria"}
## Each lesson's band (One Breath's has the tank; Easy's has the bulb).
const BANDS := {Lesson.TYPE: 1, Lesson.RARE: 1, Lesson.MISS: 1, Lesson.BREATH: 3, Lesson.HINT: 0}

var lesson: int = Lesson.TYPE

var _art: Stage
var _over: Control
var _caption: Label
var _chip: IconButton
var _chip_holder: Control
var _loop: Tween
var _begun := false
var _k := 1.0
var _on_chip := false
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none) and no buzz, no win,
## no out-of-air card, and nothing counted.
class Stage extends "res://puzzles/pearl2d.gd":
	func puzzle_id() -> String:
		return "pearl_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's typing is not the player's)
		_enter_line = false

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

	## `list` dealt on `band`, popped in with the board's entrance, and the
	## dive begun: the page has no Enter to press.
	func lay(band: int, list: Array) -> void:
		_gen += 1
		_fresh()
		state.setup_fixed(band, list)
		_begin()
		start_dive()

	## The same prompt again, nothing answered, the clock full.
	func again() -> void:
		_gen += 1
		_fresh()
		state.restart()
		_clear()
		_phase = Phase.PLAY
		_layout()
		_round_at = _now()
		_whole = int(ceil(state.time_left))
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

## The board `BOARD_H` tall, scaled to what the page leaves over the caption,
## with the bulb's strip (when there is one) to its right.
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
	if _on_chip or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

## Answer `a` of the page's prompt as the keys would type it in the screen's
## language.
static func _letters(a: int) -> String:
	return State.norm(str((ASKED[0].answers[a][State.lang()] as Array)[0]))

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the prompt again without its entrance.
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
		Lesson.TYPE:
			_type(_letters(COMMON), "HTP_PD_TYPE_CAP")
			_send("HTP_PD_TYPE_DONE_CAP", 3.4)
		Lesson.RARE:
			_type(_letters(RARE), "")
			_send("HTP_PD_RARE_CAP", 3.2)
			_loop.tween_callback(_reset)
			_loop.tween_interval(1.0)
			_type(_letters(PEARL), "")
			_send("HTP_PD_RARE_PEARL_CAP", 3.6)
		Lesson.MISS:
			_type(str(WRONG[State.lang()]), "")
			_send("HTP_PD_MISS_CAP", 2.4)
			_type(_letters(KNOWN), "HTP_PD_MISS_DONE_CAP")
			_send("", 3.0)
		Lesson.BREATH:
			_loop.tween_interval(1.6)
			_type(_letters(RARE), "")
			_send("HTP_PD_BREATH_CAP", 3.6)
		Lesson.HINT:
			_press_chip(_hint)
			_say_for("HTP_PD_HINT_CAP", 4.0)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## `letters` typed on the line a key at a time; the caption turns to `cap`.
func _type(letters: String, cap: String) -> void:
	if cap != "":
		_loop.tween_callback(_say.bind(cap))
	for i in letters.length():
		_loop.tween_callback(_art.type_letter.bind(letters[i]))
		_loop.tween_interval(KEY_BEAT)
	_loop.tween_interval(0.5)

## Enter, and then the caption turned to `cap` for `hold`.
func _send(cap: String, hold: float) -> void:
	_loop.tween_callback(_art.commit_row)
	_loop.tween_interval(0.3)
	if cap != "":
		_loop.tween_callback(_say.bind(cap))
	_loop.tween_interval(hold)

## The finger presses the page's bulb, which does `what`.
func _press_chip(what: Callable) -> void:
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

func _hint() -> void:
	_art.hint()

## Every lesson back to its prompt. `fresh` is the first deal, which pops the
## card in with the board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(BANDS[lesson], ASKED)
	else:
		_art.again()
	_lift()
	_say({Lesson.TYPE: "HTP_PD_TYPE_START_CAP", Lesson.RARE: "HTP_PD_RARE_START_CAP",
		Lesson.MISS: "HTP_PD_MISS_START_CAP", Lesson.BREATH: "HTP_PD_BREATH_START_CAP",
		Lesson.HINT: "HTP_PD_HINT_START_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.HINT:
			_art.hint()
			_say("HTP_PD_HINT_CAP")
		_:
			var a: int = {Lesson.TYPE: COMMON, Lesson.RARE: PEARL, Lesson.MISS: KNOWN, Lesson.BREATH: RARE}[lesson]
			for ch in _letters(a):
				_art.type_letter(ch)
			_art.commit_row()
			_say({Lesson.TYPE: "HTP_PD_TYPE_DONE_CAP", Lesson.RARE: "HTP_PD_RARE_PEARL_CAP",
				Lesson.MISS: "HTP_PD_MISS_DONE_CAP", Lesson.BREATH: "HTP_PD_BREATH_CAP"}[lesson])

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

func _lift() -> void:
	_on_chip = false
	_down = false

# --- drawing ---

func _draw_finger() -> void:
	if not _on_chip:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _chip_mid() + Vector2(FINGER_R * 0.4, FINGER_R * 0.5)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
