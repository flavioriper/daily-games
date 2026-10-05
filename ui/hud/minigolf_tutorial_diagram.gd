extends Control

## One page of Mini Golf's tutorial: a hand-made hole played by the board
## itself. The page holds a `Green` -- minigolf2d.gd with its sounds, tip
## lines, toasts, words, band, party and out-of-strokes card taken out and
## the hole grown to fill the page -- and plays the lesson on a loop through
## the board's own input path (a press on the ball, a drag back, a release),
## over a caption that says what it means. So the dots follow the finger,
## the ball banks off the kerb, drags in the sand, comes back out of the
## pond and waits for a gate exactly as on the board. The putts are found
## ahead (tests/_gf_tut_search.gd): the board's physics is pure data at a
## fixed step, so a putt plays the same every time. `lesson` picks the page
## (set before it enters the tree):
##
## - PUTT: drag back, let go: the ball rolls the other way and drops.
## - BANK: off the cut corner and round the bend.
## - CARD: two putts, and the card's pip takes the 2.
## - SAND (Medium up): the sand stops the ball short; a harder putt out.
## - WATER (Hard up): into the pond and back; round it and down the slope.
## - GATES (Insane): a gate shut for this putt; a tap, it swings, through.
## - HINT: the bulb's gold line, and the aim brought onto it.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { PUTT, BANK, CARD, SAND, WATER, GATES, HINT }

const FINGER_R := 26.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How long the finger takes to pull the putt back.
const SWING := 0.8

## The holes, lying along the page: a lane of row 2 (y 40 to 58), with a
## turn up into row 1 for the bank and the card.
const HOLES := {
	"putt": {"cells": [8, 9, 10], "cuts": [], "tee": [12.0, 49.0], "cup": [52.0, 49.0], "par": 1},
	"bank": {"cells": [8, 9, 10, 6], "cuts": [42], "tee": [12.0, 54.0], "cup": [53.0, 29.0], "par": 1},
	"card": {"cells": [8, 9, 10, 6], "cuts": [], "tee": [12.0, 49.0], "cup": [50.0, 29.0], "par": 2},
	"sand": {"cells": [8, 9, 10, 11], "cuts": [], "tee": [12.0, 49.0], "cup": [70.0, 49.0],
		"posts": [[30.0, 43.6, 2.4]], "sand": [[48.0, 50.0, 6.4, 5.4]], "par": 2},
	"water": {"cells": [8, 9, 10, 11], "cuts": [], "tee": [12.0, 46.0], "cup": [70.0, 49.0],
		"water": [[34.0, 45.0, 5.5, 4.6]], "slopes": [[10, 0]], "par": 2},
	"gates": {"cells": [8, 9, 10, 11], "cuts": [], "tee": [12.0, 49.0], "cup": [70.0, 49.0],
		"gates": [[41.0, 40.0, 41.0, 58.0, 0]], "par": 2},
}

## Each lesson's putts as [angle, power], found by tests/_gf_tut_search.gd.
const PUTT_SHOT := [0.0, 0.5]
const BANK_SHOT := [0.0, 0.83]
const CARD_SHOTS := [[0.0, 0.32], [-1.3177, 0.433]]
const SAND_SHOTS := [[0.0, 0.33], [0.1134, 0.517]]
const WATER_SHOTS := [[0.0, 0.3], [0.4712, 0.412]]
const GATE_SHOTS := [[0.0, 0.14], [-0.0524, 0.433]]

var lesson: int = Lesson.PUTT
## The band the board behind the page is on.
var band := 0

var _art: Green
var _over: Control
var _caption: Label
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, toasts or
## words, no band over the green (the card's lesson keeps the pips), no
## party or out-of-strokes card, and the hole as big as the page lets it be.
class Green extends "res://puzzles/minigolf2d.gd":
	## The card's lesson shows the pips.
	var show_card := false

	func puzzle_id() -> String:
		return "minigolf_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_key: String, _mood: int, _args: Array = []) -> void:
		pass

	func _sticker(_text: String, _col: Color, _big: bool) -> void:
		pass

	func _float_word(_key: String, _at: Vector2) -> void:
		pass

	func _party() -> void:
		pass

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _band() -> float:
		return 64.0 if show_card else 0.0

	func _hud_top() -> float:
		return -16.0

	func _line() -> String:
		return ""

	func _span() -> float:
		return 170.0

	## The hole fills the page: no cap on how big a small one may grow.
	func _s() -> float:
		var area := _area()
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return 0.0
		return minf(area.size.x / _box.size.x, area.size.y / _box.size.y)

	func _draw_hud(t: float, xf: Transform2D, tint: Color, shown: Array) -> void:
		if show_card:
			super(t, xf, tint, shown)

	## Hole `name` laid on band `b`, the ball on its tee, popped in with the
	## board's entrance when `enter`.
	func lay(name: String, b: int, enter: bool) -> void:
		_close_card()
		_drop_think()
		# never the band that counts strokes: the page has no pill
		_state.lay([HOLES[name]], mini(b, 2))
		_begin()
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		if not enter:
			_opened -= 10.0
			_hole_at -= 10.0

	## Whether a putt is still being played out (the cheer included).
	func playing() -> bool:
		if _phase == "sunk":
			return _now() - _sunk_at < 0.9
		return _phase != "aim"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Green.new()
	_art.show_card = lesson == Lesson.CARD
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
	_gen += 1
	_running = false

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and not _running:
		call_deferred("_start")

func _layout() -> void:
	if _art == null:
		return
	_art.position = Vector2.ZERO
	_art.size = Vector2(size.x, maxf(0.0, size.y - CAPTION_H))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the lessons ---

## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _clock: Timer
var _running := false

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	if _begun and _running:
		return
	_gen += 1
	var fresh := not _begun
	_begun = true
	_running = true
	_run(_gen, fresh)

## The lesson, over and over, while the page is up: a coroutine that waits
## on a timer of its own (freed with the page, so a turned page never
## resumes it) and stops as soon as `_gen` moves on.
func _run(gen: int, fresh: bool) -> void:
	if _clock == null:
		_clock = Timer.new()
		_clock.one_shot = true
		add_child(_clock)
	while gen == _gen:
		_reset(fresh)
		fresh = false
		if Motion.reduce:
			_still()
			_running = false
			return
		if not await _wait(1.4, gen):
			return
		var ok := true
		match lesson:
			Lesson.PUTT:
				ok = await _hand(PUTT_SHOT, "HTP_GF_PUTT_CAP", gen)
				_say("HTP_GF_DROP_CAP")
			Lesson.BANK:
				ok = await _hand(BANK_SHOT, "HTP_GF_BANK_CAP", gen)
			Lesson.CARD:
				ok = await _hand(CARD_SHOTS[0], "HTP_GF_CARD_CAP", gen)
				if ok:
					ok = await _wait(0.7, gen)
				if ok:
					ok = await _hand(CARD_SHOTS[1], "", gen)
					_say("HTP_GF_PIP_CAP")
			Lesson.SAND:
				ok = await _hand(SAND_SHOTS[0], "HTP_GF_SAND_CAP", gen)
				if ok:
					_say("HTP_GF_HARDER_CAP")
					ok = await _wait(0.9, gen)
				if ok:
					ok = await _hand(SAND_SHOTS[1], "", gen)
			Lesson.WATER:
				ok = await _hand(WATER_SHOTS[0], "HTP_GF_WATER_CAP", gen)
				if ok:
					_say("HTP_GF_BACK_CAP")
					ok = await _wait(1.2, gen)
				if ok:
					ok = await _hand(WATER_SHOTS[1], "HTP_GF_SLOPE_CAP", gen)
			Lesson.GATES:
				ok = await _hand(GATE_SHOTS[0], "HTP_GF_SHUT_CAP", gen)
				if ok:
					_say("HTP_GF_GATES_CAP")
					ok = await _wait(1.3, gen)
				if ok:
					ok = await _hand(GATE_SHOTS[1], "HTP_GF_OPEN_CAP", gen)
			Lesson.HINT:
				_say("HTP_GF_HINT_CAP")
				_art.hint()
				ok = await _wait(0.8, gen)
				while ok and not _art._think.is_empty():
					ok = await _wait(0.1, gen)
				if ok:
					ok = await _wait(1.2, gen)
				if ok and not _art._ghost.is_empty():
					_say("HTP_GF_GOLD_CAP")
					ok = await _hand([float(_art._ghost.a), float(_art._ghost.u)], "", gen)
		if not ok or not await _wait(2.2, gen):
			return

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Waits for the putt to be over: the ball at rest, down, or back from the
## pond.
func _settle(gen: int) -> bool:
	while _art.playing():
		if not await _wait(0.1, gen):
			return false
	return true

## The finger presses on the ball, pulls back the putt `shot` ([angle,
## power]; the caption turning to `press`), lets go, and the putt plays out.
func _hand(shot: Array, press: String, gen: int) -> bool:
	if press != "":
		_say(press)
	var a := float(shot[0])
	var u := float(shot[1])
	var from: Vector2 = _art.ball_at()
	var to: Vector2 = _art.pull_for(from, a, u)
	_finger = from
	_down = false
	if not await _wait(0.45, gen):
		return false
	_button(true, from)
	var steps := 16
	for k in steps:
		if not await _wait(SWING / float(steps), gen):
			return false
		var e := float(k + 1) / float(steps)
		_motion(from.lerp(to, e * e * (3.0 - 2.0 * e)))
	if not await _wait(0.45, gen):
		return false
	# the pull ends on a pixel; the putt was found at an exact angle and power
	_art._aiming = false
	_art._aim = a
	_art._power = u
	_art._putt()
	_lift()
	return await _settle(gen)

## Every lesson back to its question: the hole as laid, the ball on its tee.
## `fresh` is the first deal, popped in with the board's entrance.
func _reset(fresh := false) -> void:
	var name: String = {Lesson.PUTT: "putt", Lesson.BANK: "bank", Lesson.CARD: "card", Lesson.SAND: "sand",
		Lesson.WATER: "water", Lesson.GATES: "gates", Lesson.HINT: "bank"}[lesson]
	_art.lay(name, band, fresh)
	_lift()
	_say({Lesson.PUTT: "HTP_GF_PUTT_CAP", Lesson.BANK: "HTP_GF_BANK_CAP", Lesson.CARD: "HTP_GF_CARD_CAP",
		Lesson.SAND: "HTP_GF_SAND_CAP", Lesson.WATER: "HTP_GF_WATER_CAP", Lesson.GATES: "HTP_GF_SHUT_CAP",
		Lesson.HINT: "HTP_GF_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's question with its first putt's dots, standing
## still.
func _still() -> void:
	var shot: Array = {Lesson.PUTT: PUTT_SHOT, Lesson.BANK: BANK_SHOT, Lesson.CARD: CARD_SHOTS[0],
		Lesson.SAND: SAND_SHOTS[0], Lesson.WATER: WATER_SHOTS[1], Lesson.GATES: GATE_SHOTS[0],
		Lesson.HINT: BANK_SHOT}[lesson]
	_art._aiming = true
	_art._aim = float(shot[0])
	_art._power = float(shot[1])
	_art._live = null
	_art.queue_redraw()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the finger, through the board's own input ---

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	_finger = at
	_down = pressed
	_art._gui_input(ev)

func _motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_finger = at
	_down = true
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0 or _art._s() <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _art.position + _finger + Vector2(8.0, 10.0)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
