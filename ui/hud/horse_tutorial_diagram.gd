extends Control

## One page of Horse Pen's tutorial: a small meadow played by the board
## itself. The page holds a `Meadow` -- horse2d.gd with its sounds, buzzes,
## tip lines, toast and party taken out -- dealt a hand-made 5x5 field, and
## plays the lesson on a loop through the board's own input path (a press on
## a cell and its release, in board coordinates, as a finger would), over a
## caption that says what it means. So a bale drops with its squash and lifts
## out, the wheat sinks where the horse is cut off, the pills recount, the
## horse shakes its head at a Submit that is not one yet and kicks up its
## heels at one that is, exactly as on the board. `lesson` picks the page
## (set before it enters the tree):
##
## - PEN: a bale dropped and lifted again; then the four that cut the wheat
##   off from every edge, and the pen is closed.
## - LEAN: a stream and two boulders already fence most of the field; four
##   bales in the gaps pen all nine cells inside.
## - TARGET: a closed pen of one under a target of three, and Submit shakes
##   the horse's head; the bales moved out for a pen of four, and Submit ends
##   the day.
## - APPLES: a pen that leaves the apple out, then one bale moved to take it
##   in.
## - BEES: the golden apple and the hive both penned, then the bale moved to
##   shut the bees out.
## - TUNNEL: a pen with one mouth in it is still open, the wheat running out
##   of the other; a bale by that one closes it.
## - HINT: the bulb drops a bale in older straw; a tap on it is refused; the
##   bulb again.
##
## Every meadow's `best` and `sol` are what `Gen.search(rng, m, budget, 200,
## 20000)` found on it (four seeds), and every beat below was walked with
## `Gen.reach` before it was written down.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/horse_gen.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { PEN, LEAN, TARGET, APPLES, BEES, TUNNEL, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 80.0
## How long a bale takes to land and the wheat to follow, before the next tap.
const TAP_WAIT := 0.55
## The page's own Submit and bulb (the screen's are under the card), right of
## the field: as the screen dresses them, in a holder that makes them small.
const CHIP_SCALE := 0.8
const SUBMIT_SIZE := Vector2(260.0, 130.0)
const BULB_SIZE := 110.0

## The meadows, 5x5 (a cell is y * 5 + x). W water, S a boulder, H the
## horse, a an apple, g the golden apple, b a hive, 1 a tunnel's mouth.
##
## PEN: the boulders are two sides already; four bales (11, 16, 22, 23) are
## the other two, and the pen is the four cells between.
##
##      .  .  .  .  .
##      .  .  S  S  .
##      .  .  H  .  S
##      .  .  .  .  S
##      .  .  .  .  .
const PEN_MEADOW := {"w": 5, "h": 5, "horse": 12, "stones": [7, 8, 14, 19],
	"budget": 4, "best": 4, "sol": [11, 16, 22, 23]}
const PEN_STRAY := 6
## LEAN (and HINT): the stream fences the top and the left, a boulder a
## corner each; four bales in the gaps (14, 19, 22, 23) pen all nine cells.
##
##      W  W  W  W  .
##      W  .  .  .  S
##      W  .  H  .  .
##      W  .  .  .  .
##      .  S  .  .  .
const LEAN_MEADOW := {"w": 5, "h": 5, "horse": 12, "water": [0, 1, 2, 3, 5, 10, 15],
	"stones": [9, 21], "budget": 4, "best": 9, "sol": [14, 19, 22, 23]}
## TARGET: the best pen is four (14, 22, 23), so the target is three. Bales
## on 13 and 17 box the horse into a pen of one; lifted, and the three laid
## further out, four.
##
##      .  .  .  .  .
##      .  W  W  W  .
##      .  W  H  .  .
##      .  W  .  .  S
##      .  .  .  .  .
const TARGET_MEADOW := {"w": 5, "h": 5, "horse": 12, "water": [6, 7, 8, 11, 16],
	"stones": [19], "budget": 3, "best": 4, "sol": [14, 22, 23]}
const TARGET_SMALL := [13, 17]
## APPLES: a bale on 17 (with 23) closes a pen of six and leaves the apple
## out; on 22 instead, eight cells and the apple's three: eleven.
##
##      .  W  W  W  W
##      S  .  .  .  W
##      .  S  H  .  W
##      S  a  .  .  W
##      .  S  .  .  .
const APPLES_MEADOW := {"w": 5, "h": 5, "horse": 12, "water": [1, 2, 3, 4, 9, 14, 19],
	"stones": [5, 11, 15, 21], "apples": [16], "budget": 3, "best": 11, "sol": [22, 23]}
## BEES: a bale on 22 pens eight cells, the golden apple and the hive:
## 8 + 10 - 5 = 13. On 17 instead, six cells and the golden apple: 16.
##
##      W  W  W  W  .
##      W  g  .  .  S
##      W  .  H  S  .
##      W  .  .  b  W
##      .  S  .  W  W
const BEES_MEADOW := {"w": 5, "h": 5, "horse": 12, "water": [0, 1, 2, 3, 5, 10, 15, 19, 23, 24],
	"stones": [9, 13, 21], "gold": [6], "bees": [18], "budget": 2, "best": 16, "sol": [17]}
## TUNNEL: a bale on 18 fences the horse's four cells, but the mouth on 8
## comes out on 16 and the field is open from there; a bale on 21 closes it,
## and the pen is five.
##
##      .  W  W  W  W
##      .  S  .  1  W
##      .  S  H  .  W
##      S  1  S  .  .
##      .  .  .  .  .
const TUNNEL_MEADOW := {"w": 5, "h": 5, "horse": 12, "water": [1, 2, 3, 4, 9, 14],
	"stones": [6, 11, 15, 17], "tunnels": [[8, 16]], "budget": 2, "best": 5, "sol": [18, 21]}

var lesson: int = Lesson.PEN

var _art: Meadow
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
## lines or toast, no party, and nothing counted. It is laid out for the
## page: the pills over the field as on the screen, the field to the card's
## foot.
class Meadow extends "res://puzzles/horse2d.gd":
	## The grass left under the field and between it and the pills.
	const EDGE := 10.0
	## How long after a fresh deal a bale already standing drops in.
	const PRE_LAG := 0.25

	func puzzle_id() -> String:
		return "horse_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_text: String, _mood: int, _near := -1) -> void:
		pass

	func _party() -> void:
		pass

	func _cycle_tip() -> void:
		pass

	func _speak() -> void:
		pass

	## The page is short: the field takes all of it under the pills.
	func _cell_for(available: float) -> float:
		if state.w <= 0:
			return 0.0
		return minf((size.x - 2.0 * PAD) / state.w, (available - HUD_ROW - 2.0 * EDGE) / state.h)

	## A timer of the page's own, which goes when the page does (the board's
	## hangs on the tree, and a page turned away is freed off it).
	func _after(delay: float, what: Callable) -> void:
		var gen := _gen
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = maxf(delay, 0.01)
		timer.autostart = true
		timer.timeout.connect(func() -> void:
			timer.queue_free()
			if gen == _gen and is_inside_tree():
				what.call())
		add_child(timer)

	## Meadow `d` dealt with the bales `pre` standing, popped in with the
	## board's entrance.
	func lay(d: Dictionary, pre: Array) -> void:
		_gen += 1
		state.band = 0
		state.adopt(Gen.unpack(d))
		_fresh()
		_begin()
		_tip_timer.stop()
		var land := _opened
		if not Motion.reduce:
			land += Motion.ENTER_DELAY + HORSE_LAG + HORSE_LAND + PRE_LAG
		for cell: int in pre:
			state.tap(cell)
			_bale_in[cell] = land
		state.history = []
		if not pre.is_empty():
			_busy_for(land - _now() + BALE_TIME)
			_after_change(land, true)
		_redraw()

	## The same meadow from the top: every bale off in the board's own wave,
	## the wheat back out to the edges, `pre` standing.
	func again(pre: Array) -> void:
		_gen += 1
		_fresh()
		_solved_at = -1.0
		_stamp_at = INF
		var stood: Array = state.laid.duplicate()
		var old: Dictionary = state.pinned.duplicate()
		_deal()
		var now := _now()
		_clear_field(now)
		for cell: int in pre:
			state.tap(cell)
			if stood.has(cell) and not old.has(cell):
				# It never left.
				_bale_out = _bale_out.filter(func(out: Dictionary) -> bool: return int(out.cell) != cell)
			else:
				_bale_in[cell] = now + PRE_LAG
		state.history = []
		_after_change(now + PRE_LAG, true)
		_redraw()

	func _fresh() -> void:
		hints_used = 0
		hints_extra = 0
		moves = 0
		checks = 0
		_done = false
		_running = true

	## A bale on `cell` (or off it) at once, with nothing in flight: the
	## still page's.
	func put(cell: int) -> void:
		state.tap(cell)
		state.history = []
		_after_change(_now(), true)
		_redraw()

	## Stops whatever the board had waiting (the page is leaving the tree).
	func hush() -> void:
		_gen += 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Meadow.new()
	add_child(_art)
	if lesson == Lesson.TARGET:
		_chip = _make_chip(IconButton.new("check", "HP_SUBMIT", "SunButton"), SUBMIT_SIZE)
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

## The colour Submit wears on the screen: the board's card's.
func _accent() -> Color:
	var puzzles: Array = load("res://ui/registry.gd").PUZZLES
	for i in puzzles.size():
		if String(puzzles[i].get("id", "")) == "horse":
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

## The meadow as tall as the page leaves over the caption and the page's
## whole width: the board centres its own field.
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

## The chip in the grass right of the field, level with its middle.
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

func _meadow() -> Dictionary:
	match lesson:
		Lesson.PEN:
			return PEN_MEADOW
		Lesson.TARGET:
			return TARGET_MEADOW
		Lesson.APPLES:
			return APPLES_MEADOW
		Lesson.BEES:
			return BEES_MEADOW
		Lesson.TUNNEL:
			return TUNNEL_MEADOW
	return LEAN_MEADOW

## The bales standing when the lesson starts.
func _pre() -> Array:
	match lesson:
		Lesson.TARGET:
			return TARGET_SMALL
		Lesson.APPLES:
			return [23]
	return []

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the meadow again without its entrance.
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
		Lesson.PEN:
			_tap(PEN_STRAY, "HTP_HP_DROP_CAP", "", 1.2)
			_tap(PEN_STRAY, "HTP_HP_LIFT_CAP", "", 1.0)
			_tap(11, "HTP_HP_GAPS_CAP", "")
			_tap(16, "", "")
			_tap(22, "", "")
			_tap(23, "", "HTP_HP_CLOSED_CAP", 3.4)
		Lesson.LEAN:
			_tap(14, "HTP_HP_LEAN_GAPS_CAP", "")
			_tap(19, "", "")
			_tap(22, "", "")
			_tap(23, "", "HTP_HP_LEAN_DONE_CAP", 3.4)
		Lesson.TARGET:
			_press_chip("HTP_HP_SUBMIT_CAP", _submit)
			_say_for("HTP_HP_NOTYET_CAP", 2.0)
			_tap(13, "HTP_HP_BIGGER_CAP", "", 0.3)
			_tap(17, "", "", 0.3)
			_tap(14, "", "")
			_tap(22, "", "")
			_tap(23, "", "HTP_HP_WORTH_CAP", 1.6)
			_press_chip("", _submit)
			_say_for("HTP_HP_DAY_CAP", 3.6)
		Lesson.APPLES:
			_tap(17, "", "HTP_HP_APPLE_OUT_CAP", 2.2)
			_tap(17, "HTP_HP_APPLE_MOVE_CAP", "", 0.4)
			_tap(22, "", "HTP_HP_APPLE_IN_CAP", 3.4)
		Lesson.BEES:
			_tap(22, "", "HTP_HP_BEES_IN_CAP", 2.6)
			_tap(22, "HTP_HP_BEES_MOVE_CAP", "", 0.4)
			_tap(17, "", "HTP_HP_BEES_OUT_CAP", 3.4)
		Lesson.TUNNEL:
			_tap(18, "", "HTP_HP_TUNNEL_OUT_CAP", 2.8)
			_tap(21, "HTP_HP_TUNNEL_BOTH_CAP", "HTP_HP_TUNNEL_DONE_CAP", 3.4)
		Lesson.HINT:
			_press_chip("", _hint)
			_say_for("HTP_HP_PINNED_CAP", 1.8)
			_loop.tween_callback(_say.bind("HTP_HP_STAYS_CAP"))
			_tap_pinned()
			_loop.tween_interval(1.6)
			_press_chip("HTP_HP_HINT_CAP", _hint)
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger taps `cell`: the caption turns to `before` as it comes, and to
## `after` once the bale is down (or up); then the field settles for `wait`.
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

## HINT: the finger tries the bale the bulb dropped.
func _tap_pinned() -> void:
	_loop.tween_callback(func() -> void: _point_at(_art.cell_centre(_pinned())))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(_pinned(), true))
	_loop.tween_interval(0.18)
	_loop.tween_callback(func() -> void: _button(_pinned(), false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## The finger presses the page's chip, which does `what`.
func _press_chip(before: String, what: Callable) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_chip_mid()))
	_loop.tween_interval(0.55)
	_loop.tween_callback(func() -> void:
		_down = true
		_chip.squish())
	_loop.tween_interval(0.18)
	_loop.tween_callback(what)
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

func _submit() -> void:
	_art.check()

func _hint() -> void:
	_art.hint()

## The first bale the bulb pinned, or the horse's cell before there is one.
func _pinned() -> int:
	var st = _art.state
	for cell: int in st.laid:
		if st.pinned.has(cell):
			return cell
	return int(st.horse)

## Every lesson back to its question: the meadow bare but for the bales it
## starts with, nothing in flight. `fresh` is the first deal, which pops the
## meadow in with the board's entrance.
func _reset(fresh := false) -> void:
	if fresh:
		_art.lay(_meadow(), _pre())
	else:
		_art.again(_pre())
	_lift()
	_place_chip()
	_say({Lesson.PEN: "HTP_HP_START_CAP", Lesson.LEAN: "HTP_HP_LEAN_START_CAP",
		Lesson.TARGET: "HTP_HP_SMALL_CAP", Lesson.APPLES: "HTP_HP_APPLE_START_CAP",
		Lesson.BEES: "HTP_HP_BEES_START_CAP", Lesson.TUNNEL: "HTP_HP_TUNNEL_START_CAP",
		Lesson.HINT: "HTP_HP_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.PEN:
			for cell: int in PEN_MEADOW.sol:
				_art.put(cell)
			_say("HTP_HP_CLOSED_CAP")
		Lesson.LEAN:
			for cell: int in LEAN_MEADOW.sol:
				_art.put(cell)
			_say("HTP_HP_LEAN_DONE_CAP")
		Lesson.TARGET:
			for cell: int in [13, 17, 14, 22, 23]:
				_art.put(cell)
			_art.check()
			_say("HTP_HP_DAY_CAP")
		Lesson.APPLES:
			_art.put(22)
			_say("HTP_HP_APPLE_IN_CAP")
		Lesson.BEES:
			_art.put(17)
			_say("HTP_HP_BEES_OUT_CAP")
		Lesson.TUNNEL:
			_art.put(18)
			_art.put(21)
			_say("HTP_HP_TUNNEL_DONE_CAP")
		Lesson.HINT:
			_hint()
			_say("HTP_HP_PINNED_CAP")

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
