extends Control

## One page of Trestle's tutorial: a small gap bridged by the board itself.
## The page holds a `Gap` -- trestle2d.gd with its sounds, toasts, stickers,
## win and out-of-hearts card taken out, its view drawn in onto the rows the
## lesson needs and (on most pages) its strip of chips left off -- dealt a
## hand-made level three steps wide, and plays the lesson on a loop through
## the board's own input path (a press on a pin, a drag to a dot, the
## release; a tap on a chip or a member), with a Go button of its own at
## the foot for the finger to press, over a caption that says what it means.
## So the road is laid plank by plank, the test runs on the real physics, a
## road alone snaps and is marked, wood triangles carry the cart over tinted
## by their load, a price floats off a member and comes back, rope hangs the
## road from the posts, a failed test splits a heart and the tea spills
## where the deck dips, exactly as on the board. The bridges were tried in
## the sim ahead (it is pure data at a fixed step, so a design gives the
## same crossing every time): at this cart the road alone snaps, two struts
## hold it at 0.73 of the limit, two ropes from the posts at 0.80, and on a
## Tea Party the two struts spill at the third plank where the two more
## diagonals carry the tea over at 0.77 of the rim. `lesson` picks the page
## (set before it enters the tree):
##
## - BUILD: drag from a pin to lay the road, press Go: a road alone gives way.
## - TRUSS: brace it with wood: every member shows its load, the cart is over.
## - BUDGET: pick a material, a member costs, tap it to take it down.
## - ROPE (bands with rope): hang the road from the posts.
## - HEARTS (Hard and Insane): a test that fails costs a heart.
## - TEA (Insane): the deck dips and the tea spills; stiffened, not a drop.
## - BAR: Undo takes back the last member, Reset clears the bridge.
## - HINT (bands with hints): the bulb lays a member of a bridge that works.
##
## The board checkup, 2026-10-03: Trestle had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Sim = preload("res://puzzles/trestle_sim.gd")

enum Lesson { BUILD, TRUSS, BUDGET, ROPE, HEARTS, TEA, BAR, HINT }

const CAPTION_H := 92.0
const FINGER_R := 26.0
const FINGER_ALPHA := 0.16
## How long a drag takes from its pin to its dot.
const DRAG := 0.55
## The page's own Go: where it sits at the art's foot, and its size.
const GO_SIZE := Vector2(168.0, 68.0)
const GO_PAD := 14.0
const GO_COL := Color("e26a55")
const GO_DEEP := Color("a84534")

## The gaps: three steps wide, a pin under each bank's road end (and a post
## on each bank for the rope's page). Every one carries the bridge a hint
## lays: the road and the two struts.
const ROAD := [[0, 0, 1, 0, 0], [1, 0, 2, 0, 0], [2, 0, 3, 0, 0]]
const STRUTS := [[0, -1, 1, 0, 1], [3, -1, 2, 0, 1]]
const ROPES := [[-1, 1, 1, 0, 2], [4, 1, 2, 0, 2]]
const BRACES := [[0, -1, 2, 0, 1], [3, -1, 1, 0, 1]]
const PINS := [[0, 0], [3, 0], [0, -1], [3, -1]]
const POSTS := [[0, 0], [3, 0], [0, -1], [3, -1], [-1, 1], [4, 1]]

var lesson: int = Lesson.BUILD
## The band the board behind the page is on, and the materials it offers.
var band := 0
var mats: Array = [Sim.ROAD, Sim.WOOD]

var _art: Gap
var _over: Control
var _caption: Label
var _begun := false
var _running := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _go_down := false
var _over_shown: ArrayMesh
## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _clock: Timer

## The board, quiet: no sound set (its id names none) and no rolling
## wheels, no toasts or stickers, no win and no out-of-hearts card, the view
## drawn in onto the bridge, and the strip only on the page that needs it.
class Gap extends "res://puzzles/trestle2d.gd":
	var strip := false
	var rows := Vector2(1.9, -2.4)

	func puzzle_id() -> String:
		return "trestle_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_roll.stream = null
		fx.buzzes = false

	func _view() -> Vector2:
		return rows

	func _strip_shown() -> bool:
		return strip

	## The hearts hang at the right, clear of the cart waiting on the near bank.
	func _sign_left() -> float:
		return size.x - PAD - 6.0 - (HEART_STEP * max_hearts + 22.0)

	func check_solved() -> void:
		pass

	func _tell(_key: String, _args: Array = []) -> void:
		pass

	func _sticker(_text: String, _where: Vector2, _fs: int, _life: float, _rainbow := true, _col := Color.WHITE, _rays := false, _id := "", _rise := 0.0, _keep := false) -> void:
		pass

	func _warm_words() -> void:
		pass

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## The gap with `anchors`, `budget` to spend, the day's proof `proof`
	## (what a hint lays), on band `b`: its riders, its cups on a Tea Party,
	## and its hearts when `with_hearts`. `built` is laid at once.
	func lay(anchors: Array, proof: Array, budget: int, b: int, offers: Array, tea: bool, with_hearts: bool, built: Array) -> void:
		var cost := 0
		for r in proof:
			cost += Sim.member_cost(Vector2i(r[0], r[1]), Vector2i(r[2], r[3]), r[4])
		_deal({"anchors": anchors, "band": b, "budget": budget, "cart": 1.6, "dy": 0, "mats": offers,
			"proof_cost": cost, "w": 3, "proof": proof, "tea": tea}, b)
		if not with_hearts:
			max_hearts = 0
			hearts = 0
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		for r in built:
			state.add(Vector2i(r[0], r[1]), Vector2i(r[2], r[3]), r[4])
		state._undo = []
		_sel = NONE
		_frame = null
		_bar_shown = clampf(float(state.cost()) / maxf(1.0, float(state.budget)), 0.0, 1.2)
		_money_shown = float(state.cost())

	## The cart is over, in the river, or its tea is on the deck.
	func test_over() -> bool:
		return _run_over or _fail_at >= 0.0

	## Back at the drawing board after a test that failed.
	func building() -> bool:
		return not _testing

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Gap.new()
	_art.strip = lesson == Lesson.BUDGET
	if _art.strip:
		_art.rows = Vector2(1.5, -1.7)
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 6
	_over.draw.connect(_draw_over)
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
	_over.queue_redraw()

# --- the lessons ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	if _begun and _running:
		return
	_gen += 1
	_begun = true
	_running = true
	_run(_gen)

## The lesson, over and over, while the page is up: a coroutine that waits
## on a timer of its own (freed with the page, so a turned page never
## resumes it) and stops as soon as `_gen` moves on.
func _run(gen: int) -> void:
	if _clock == null:
		_clock = Timer.new()
		_clock.one_shot = true
		add_child(_clock)
	while gen == _gen:
		_reset()
		if Motion.reduce:
			_still()
			_running = false
			return
		if not await _wait(1.3, gen):
			return
		var ok := true
		match lesson:
			Lesson.BUILD:
				ok = await _lay_all(ROAD, gen)
				if ok:
					ok = await _go("HTP_TR_GO_CAP", gen)
				if ok:
					_say("HTP_TR_ALONE_CAP")
					ok = await _back(gen)
				if ok:
					_say("HTP_TR_MARK_CAP")
			Lesson.TRUSS:
				ok = await _lay_all(STRUTS, gen)
				if ok:
					ok = await _go("HTP_TR_LOAD_CAP", gen)
				if ok:
					_say("HTP_TR_HOLD_CAP")
			Lesson.BUDGET:
				ok = await _tap(_art.chip_to_local(Sim.WOOD), gen)
				if ok:
					_say("HTP_TR_COST_CAP")
					ok = await _lay_all(STRUTS, gen)
				if ok:
					ok = await _wait(0.9, gen)
				if ok:
					_say("HTP_TR_TAKE_CAP")
					ok = await _tap(_mid(STRUTS[1]), gen)
				if ok:
					ok = await _wait(0.9, gen)
				if ok:
					ok = await _tap(_mid(STRUTS[0]), gen)
			Lesson.ROPE:
				ok = await _lay_all(ROPES, gen)
				if ok:
					ok = await _go("HTP_TR_GO_CAP", gen)
				if ok:
					_say("HTP_TR_HANG_CAP")
			Lesson.HEARTS:
				ok = await _wait(0.8, gen)
				if ok:
					ok = await _go("HTP_TR_PROMISE_CAP", gen)
				if ok:
					_say("HTP_TR_HEART_CAP")
					ok = await _back(gen)
			Lesson.TEA:
				ok = await _wait(0.8, gen)
				if ok:
					ok = await _go("HTP_TR_GO_CAP", gen)
				if ok:
					_say("HTP_TR_SPILL_CAP")
					ok = await _back(gen)
				if ok:
					ok = await _wait(1.2, gen)
				if ok:
					_say("HTP_TR_STIFF_CAP")
					ok = await _lay_all(BRACES, gen)
				if ok:
					ok = await _go("HTP_TR_GO_CAP", gen)
				if ok:
					_say("HTP_TR_DRY_CAP")
			Lesson.BAR:
				ok = await _lay_all([ROAD[0], ROAD[1], STRUTS[0]], gen)
				if ok:
					ok = await _wait(0.5, gen)
				if ok:
					_say("HTP_TR_UNDO_CAP")
					_art.undo()
					ok = await _wait(1.5, gen)
				if ok:
					_say("HTP_TR_RESET_CAP")
					_art.reset_board()
			Lesson.HINT:
				_art.hint()
				ok = await _wait(1.3, gen)
				if ok:
					_say("HTP_TR_HINT_MORE_CAP")
					_art.hint()
		if not ok or not await _wait(2.6, gen):
			return

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Every lesson back to its question: the gap dealt again with what the
## lesson starts from already built, the material it lays in hand.
func _reset() -> void:
	_lift()
	var hearts := lesson == Lesson.HEARTS or lesson == Lesson.TEA
	match lesson:
		Lesson.BUILD:
			_art.lay(PINS, ROAD + STRUTS, 2400, band, mats, false, false, [])
			_say("HTP_TR_DRAG_CAP")
		Lesson.TRUSS:
			_art.lay(PINS, ROAD + STRUTS, 2400, band, mats, false, false, ROAD)
			_art._mat = Sim.WOOD
			_say("HTP_TR_BRACE_CAP")
		Lesson.BUDGET:
			_art.lay(PINS, ROAD + STRUTS, 1500, band, mats, false, false, ROAD)
			_say("HTP_TR_PICK_CAP")
		Lesson.ROPE:
			_art.lay(POSTS, ROAD + ROPES, 2400, band, mats, false, false, ROAD)
			_art._mat = Sim.ROPE
			_say("HTP_TR_ROPE_CAP")
		Lesson.HEARTS:
			_art.lay(PINS, ROAD + STRUTS, 2400, band, mats, false, hearts, ROAD)
			_say("HTP_TR_PROMISE_CAP")
		Lesson.TEA:
			_art.lay(PINS, ROAD + STRUTS + BRACES, 2400, band, mats, true, hearts, ROAD + STRUTS)
			_art._mat = Sim.WOOD
			_say("HTP_TR_TEA_CAP")
		Lesson.BAR:
			_art.lay(PINS, ROAD + STRUTS, 2400, band, mats, false, false, [])
			_say("HTP_TR_DRAG_CAP")
		Lesson.HINT:
			_art.lay(PINS, ROAD + STRUTS, 2400, band, mats, false, false, [])
			_say("HTP_TR_HINT_CAP")

## Reduce-motion: the lesson's bridge, standing still.
func _still() -> void:
	var built: Array = {Lesson.BUILD: ROAD, Lesson.TRUSS: STRUTS, Lesson.BUDGET: STRUTS, Lesson.ROPE: ROPES,
		Lesson.HEARTS: [], Lesson.TEA: BRACES, Lesson.BAR: ROAD, Lesson.HINT: []}[lesson]
	for r in built:
		_art.state.add(Vector2i(r[0], r[1]), Vector2i(r[2], r[3]), r[4])
	if lesson == Lesson.HINT:
		_art.hint()
	_art._sel = Gap.NONE
	_art._frame = null

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

## The finger lays every member of `rows`, one drag each.
func _lay_all(rows: Array, gen: int) -> bool:
	for r in rows:
		_art._mat = int(r[4])
		if not await _drag(Vector2i(r[0], r[1]), Vector2i(r[2], r[3]), gen):
			return false
		if not await _wait(0.3, gen):
			return false
	_lift()
	return true

## A drag from grid point `a` to `b`: a press, the way across, the release.
func _drag(a: Vector2i, b: Vector2i, gen: int) -> bool:
	var from: Vector2 = _art.point_to_local(a)
	var to: Vector2 = _art.point_to_local(b)
	_finger = from
	_down = false
	if not await _wait(0.3, gen):
		return false
	_button(true, from)
	var steps := 10
	for k in steps:
		if not await _wait(DRAG / float(steps), gen):
			return false
		var u := float(k + 1) / float(steps)
		_motion(from.lerp(to, u * u * (3.0 - 2.0 * u)))
	if not await _wait(0.12, gen):
		return false
	_button(false, to)
	return true

## A tap at `at` (board-local): a chip, or a member's middle.
func _tap(at: Vector2, gen: int) -> bool:
	_finger = at
	_down = false
	if not await _wait(0.45, gen):
		return false
	_button(true, at)
	if not await _wait(0.16, gen):
		return false
	_button(false, at)
	if not await _wait(0.3, gen):
		return false
	_lift()
	return true

## The finger presses the page's Go (the caption turning to `key`) and the
## test plays until the cart is over, in the river or its tea is spilled.
func _go(key: String, gen: int) -> bool:
	_finger = _go_rect().get_center()
	_down = false
	if not await _wait(0.5, gen):
		return false
	_down = true
	_go_down = true
	_say(key)
	_art.check()
	if not await _wait(0.2, gen):
		return false
	_go_down = false
	_lift()
	while not _art.test_over():
		if not await _wait(0.1, gen):
			return false
	return await _wait(0.5, gen)

## Waits for the board to come back to building after a failed test.
func _back(gen: int) -> bool:
	while not _art.building():
		if not await _wait(0.1, gen):
			return false
	return await _wait(1.6, gen)

## A member's middle, board-local.
func _mid(r: Array) -> Vector2:
	return (_art.point_to_local(Vector2i(r[0], r[1])) + _art.point_to_local(Vector2i(r[2], r[3]))) * 0.5

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

## Whether this page's lesson presses Go.
func _has_go() -> bool:
	return lesson in [Lesson.BUILD, Lesson.TRUSS, Lesson.ROPE, Lesson.HEARTS, Lesson.TEA]

func _go_rect() -> Rect2:
	return Rect2(_art.position + _art.size - GO_SIZE - Vector2(GO_PAD, GO_PAD), GO_SIZE)

## The page's Go (the board's is the host's, under the card) and the finger.
func _draw_over() -> void:
	var b := Face.Builder.new()
	var go := _has_go()
	var r := _go_rect()
	var sink := 3.0 if _go_down else 0.0
	if go:
		# asleep while the cart is on its way, as the real one is
		var live: bool = _art.building()
		var face := GO_COL if live else GO_COL.lerp(Pal.SURFACE_HI, 0.55)
		b.fan(Face.Builder.round_rect(r.position + Vector2(0, 6), r.size, 22.0), GO_DEEP if live else GO_DEEP.lerp(Pal.SURFACE_HI, 0.55))
		b.fan(Face.Builder.round_rect(r.position + Vector2(0, sink), r.size, 22.0), face)
		var c := r.position + Vector2(44.0, r.size.y * 0.5 + sink)
		b.polygon(PackedVector2Array([c + Vector2(-9.0, -13.0), c + Vector2(13.0, 0.0), c + Vector2(-9.0, 13.0)]), Color.WHITE)
	if _finger.x >= 0.0:
		var at := _art.position + _finger + Vector2(12.0, 14.0)
		var fr := FINGER_R * (0.85 if _down else 1.0)
		b.disc(at, fr, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		b.stroke(Face.Builder.ring(at, fr, fr), 3.0, Color(Pal.TEXT, 0.45), true)
	_over_shown = b.mesh() if not b.verts.is_empty() else null
	if _over_shown != null:
		_over.draw_mesh(_over_shown, null)
	if go:
		var font: Font = CozyTheme.body(800)
		var word := tr("TR_GO")
		var fs := 34
		_over.draw_string(font, Vector2(r.position.x + 70.0, r.get_center().y + sink + font.get_ascent(fs) * 0.36), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
