extends Control

## One page of Checkers' tutorial: a few rows of the board itself, played by
## a drawn finger. The page holds a `Lawn` -- versus/checkers_board.gd with
## its sounds and knocks taken out -- laid at a cell that reads on the card
## and looked at through a window five rows tall (the home rows, the home
## rows with the planter the taken pieces land in, or the far rows), the cut
## edge faded into the card. A hand-made position is set on the real rules
## (versus/checkers_rules.gd) and the lesson is played on a loop through the
## board's own input path (a press and release on a piece, on a landing; a
## drag), the computer's answers scripted and played as the screen plays
## them. So the dots and routes, the gold ring on a piece that must take,
## the shiver of a piece that may not move, the jumps, the crown falling,
## the king's glide, the winners' hop and the hint's arrow are the board's.
## `lesson` picks the page (set before it enters the tree):
##
## - MOVE: tap a man, tap where it lands; the computer answers; or drag.
## - JUMP: a man jumps one forward and one backward in a single move.
## - MUST: two pieces shiver and stay; only the move that takes most plays.
## - KING: a man is crowned on the far row, and the king takes from afar.
## - END: the last piece taken, then a last piece boxed in: both win.
## - BAR: the bulb's arrow, Undo taking back the move and its answer, Reset.
##
## The top bar's three buttons on the BAR page are the bar's own
## (ui/hud/icon_button.gd), small, beside the board for the finger to press.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Rules = preload("res://versus/checkers_rules.gd")
const CheckersSkin = preload("res://versus/checkers_skin.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

enum Lesson { MOVE, JUMP, MUST, KING, END, BAR }
## What the window looks at: the hand's rows down to the frame, the same
## with the planter under it, or the far rows from the frame down.
enum View { HOME, TRAY, FAR }

const CAPTION_H := 68.0
## A square on the page (112 on the screen): five rows and a cut edge fit.
const CELL := 68.0
## How deep the cut edge fades into the card.
const FADE := 26.0
const FINGER_R := 26.0
const FINGER_ALPHA := 0.16
const DRAG := 0.6
## How long the computer holds its piece up, as on the screen.
const PONDER := 0.35
## The bar's buttons beside the board: their size on the bar, and here.
const BUTTON := 110.0
const BUTTON_SCALE := 0.74
const BUTTON_GAP := 20.0

## The positions: "sq:piece" items, M/K the hand's, m/k the computer's.
const MOVE_POS := "b2:M f2:M c3:M e3:M g3:M b6:m d6:m f6:m"
const JUMP_POS := "b2:M h2:M g1:M c3:m e3:m"
const MUST_POS := "a3:M b2:M d2:M g1:M c3:m e3:m"
const KING_POS := "c7:M g5:m h8:m"
const KING_STILL := "d8:K g5:m g7:m"
const LAST_POS := "b2:M e1:M g1:M c3:m"
const BLOCK_POS := "a1:M c1:M e1:M a3:m"
const BLOCK_STILL := "b2:M c1:M e1:M a3:m"
const BAR_POS := "c1:M b2:M f2:M c3:M e3:M b6:m d6:m f6:m"

var lesson: int = Lesson.MOVE
## The piece set the screen's board wears.
var skin_id := "garden"
## Hints a game, for the bulb's badge.
var hints := 3

var _frame: Control
var _art: Lawn
var _rules: RefCounted
var _played: Array = []
var _over: Control
var _caption: Label
var _buttons := {}
var _begun := false
var _running := false
## Where the finger is going and where it is drawn, in this control's
## pixels; x < 0 is no finger.
var _finger := Vector2(-1.0, -1.0)
var _finger_at := Vector2(-1.0, -1.0)
var _down := false
var _fade_mesh: ArrayMesh
var _fade_key := Vector2.ZERO
var _finger_meshes: Array = []
## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _clock: Timer

## The board, quiet: no sound (its cues go nowhere), no knock, no touch but
## the page's own.
class Lawn extends "res://versus/checkers_board.gd":
	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false

	func _cue(_name: String, _pitch := 1.0) -> void:
		pass

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.clip_contents = true
	add_child(_frame)
	_art = Lawn.new()
	_art.skin = CheckersSkin.named(skin_id)
	_art.chosen.connect(_make)
	_frame.add_child(_art)
	if lesson == Lesson.BAR:
		for icon: String in ["undo", "reset", "bulb"]:
			_buttons[icon] = _bar_button(icon)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall and
	# its centred text sinks under the buttons.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 6
	_over.draw.connect(_draw_over)
	add_child(_over)
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start")

## One of the top bar's buttons, dressed as the bar dresses it, in a holder
## that makes it small (the button's own scale is its press).
func _bar_button(icon: String) -> Button:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.scale = Vector2.ONE * BUTTON_SCALE
	add_child(holder)
	var b := IconButton.new(icon)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size = Vector2.ONE * BUTTON
	CozyTheme.lift_button(b, Pal.SURFACE, int(BUTTON * 0.29))
	holder.add_child(b)
	return b

func _exit_tree() -> void:
	_gen += 1
	_running = false

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _begun and not _running:
		call_deferred("_start")

func _view() -> int:
	match lesson:
		Lesson.MOVE, Lesson.BAR:
			return View.HOME
		Lesson.KING:
			return View.FAR
	return View.TRAY

## The board at CELL, hung behind the window so the lesson's rows show; on
## the bar's page it stands to the left and the buttons take the room.
func _layout() -> void:
	if _art == null or size.x <= 0.0:
		return
	var room := Vector2(size.x, maxf(0.0, size.y - CAPTION_H))
	_frame.position = Vector2.ZERO
	_frame.size = room
	var across := 8.0 + 2.0 * Lawn.FRAME
	var board := Vector2(across, across + 2.0 * (Lawn.TRAY + Lawn.TRAY_GAP)) * CELL + Vector2.ONE * 0.5
	_art.size = board
	var x := floorf((room.x - board.x) * 0.5)
	if lesson == Lesson.BAR:
		var side := BUTTON * BUTTON_SCALE
		x = floorf((room.x - board.x - side - 34.0) * 0.5)
		var bx := x + board.x + 34.0
		var tall := side * 3.0 + BUTTON_GAP * 2.0
		var by := floorf((room.y - tall) * 0.5)
		var i := 0
		for icon: String in ["undo", "reset", "bulb"]:
			(_buttons[icon].get_parent() as Control).position = Vector2(bx, by + i * (side + BUTTON_GAP))
			i += 1
	var top := 0.0
	match _view():
		View.HOME:
			top = _art.frame_rect().end.y - room.y
		View.TRAY:
			top = _art.used_rect.end.y - room.y
		View.FAR:
			top = _art.frame_rect().position.y
	_art.position = Vector2(x, -floorf(top))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	_over.queue_redraw()
	if not _begun and is_inside_tree():
		call_deferred("_start")

func _process(delta: float) -> void:
	if _finger.x < 0.0:
		if _finger_at.x >= 0.0:
			_finger_at = _finger
			_over.queue_redraw()
		return
	# The finger glides to where it is wanted; it appears there.
	var at := _finger
	if _finger_at.x >= 0.0 and not Motion.reduce:
		at = _finger_at.lerp(_finger, 1.0 - exp(-delta * 16.0))
	_finger_at = at
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
		if not await _wait(1.2, gen):
			return
		var ok := true
		match lesson:
			Lesson.MOVE:
				ok = await _tap("e3", gen)
				if ok:
					ok = await _wait(0.9, gen)
				if ok:
					ok = await _tap("f4", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					_say("TUT_CHECKERS_MOVE_CAP_REPLY")
					ok = await _reply("d6", "c5", gen)
				if ok:
					_say("TUT_CHECKERS_MOVE_CAP_DRAG")
					ok = await _drag("g3", "h4", gen)
				if ok:
					ok = await _settle(gen)
			Lesson.JUMP:
				_say("TUT_CHECKERS_JUMP_CAP_ROUTE")
				ok = await _tap("b2", gen)
				if ok:
					ok = await _wait(1.3, gen)
				if ok:
					ok = await _tap("f2", gen)
				if ok:
					_say("TUT_CHECKERS_JUMP_CAP_DONE")
					ok = await _settle(gen)
			Lesson.MUST:
				ok = await _tap("a3", gen)
				if ok:
					_say("TUT_CHECKERS_MUST_CAP_NO")
					ok = await _wait(1.5, gen)
				if ok:
					ok = await _tap("d2", gen)
				if ok:
					_say("TUT_CHECKERS_MUST_CAP_ONE")
					ok = await _wait(1.5, gen)
				if ok:
					ok = await _tap("b2", gen)
				if ok:
					_say("TUT_CHECKERS_MUST_CAP_MOST")
					ok = await _wait(1.1, gen)
				if ok:
					ok = await _tap("f2", gen)
				if ok:
					ok = await _settle(gen)
			Lesson.KING:
				ok = await _tap("c7", gen)
				if ok:
					ok = await _wait(0.7, gen)
				if ok:
					ok = await _tap("d8", gen)
				if ok:
					_say("TUT_CHECKERS_KING_CAP_CROWN")
					ok = await _settle(gen)
				if ok:
					ok = await _reply("h8", "g7", gen)
				if ok:
					_say("TUT_CHECKERS_KING_CAP_FLY")
					ok = await _tap("d8", gen)
				if ok:
					ok = await _wait(1.2, gen)
				if ok:
					ok = await _tap("h4", gen)
				if ok:
					ok = await _settle(gen)
			Lesson.END:
				ok = await _tap("b2", gen)
				if ok:
					ok = await _wait(0.7, gen)
				if ok:
					ok = await _tap("d4", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					ok = await _won("TUT_CHECKERS_END_CAP_WON", gen)
				if ok:
					_lay(BLOCK_POS)
					_say("TUT_CHECKERS_END_CAP_BLOCK")
					ok = await _wait(1.0, gen)
				if ok:
					ok = await _tap("a1", gen)
				if ok:
					ok = await _wait(0.7, gen)
				if ok:
					ok = await _tap("b2", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					ok = await _won("TUT_CHECKERS_END_CAP_STUCK", gen)
			Lesson.BAR:
				ok = await _press("bulb", gen)
				if ok:
					_art.set_hint(_find("c3", "d4"))
					_buttons.bulb.badge = hints - 1
					ok = await _wait(1.6, gen)
				if ok:
					ok = await _tap("c3", gen)
				if ok:
					ok = await _wait(0.5, gen)
				if ok:
					ok = await _tap("d4", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					ok = await _reply("b6", "a5", gen)
				if ok:
					_buttons.undo.set_enabled(true)
					_say("TUT_CHECKERS_BAR_CAP_UNDO")
					ok = await _press("undo", gen)
				# Undo, as the screen's: the answer walks back, then the move.
				for k in 2:
					if ok:
						_art.interactive = false
						_art.set_must(PackedInt32Array())
						_rules.unmake()
						_art.rewind(_played.pop_back())
						ok = await _settle(gen)
				if ok:
					_buttons.undo.set_enabled(false)
					ok = await _wait(1.0, gen)
				if ok:
					_say("TUT_CHECKERS_BAR_CAP_RESET")
					ok = await _press("reset", gen)
				if ok:
					_lay(BAR_POS, true)
					_buttons.bulb.badge = hints
					ok = await _settle(gen)
		_lift()
		if not ok or not await _wait(2.4, gen):
			return

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Waits for the board's scene to finish (its `settled`), then hands the
## turn on as the screen does: the hand's pieces that must take are ringed.
func _settle(gen: int) -> bool:
	if not await _wait(0.1, gen):
		return false
	while _art.is_busy():
		if not await _wait(0.05, gen):
			return false
	_turn()
	return await _wait(0.4, gen)

## Every lesson back to its question.
func _reset() -> void:
	_lift()
	match lesson:
		Lesson.MOVE:
			_lay(MOVE_POS)
			_say("TUT_CHECKERS_MOVE_CAP_TAP")
		Lesson.JUMP:
			_lay(JUMP_POS)
			_say("TUT_CHECKERS_JUMP_CAP_RING")
		Lesson.MUST:
			_lay(MUST_POS)
			_say("TUT_CHECKERS_MUST_CAP_RING")
		Lesson.KING:
			_lay(KING_POS)
			_say("TUT_CHECKERS_KING_CAP_ROW")
		Lesson.END:
			_lay(LAST_POS)
			_say("TUT_CHECKERS_END_CAP_LAST")
		Lesson.BAR:
			_lay(BAR_POS)
			_buttons.undo.set_enabled(false)
			_buttons.bulb.badge = hints
			_say("TUT_CHECKERS_BAR_CAP_HINT")

## Reduce-motion: the lesson's telling moment, standing still.
func _still() -> void:
	match lesson:
		Lesson.MOVE:
			_art._select(_sq("e3"))
		Lesson.JUMP:
			_art._select(_sq("b2"))
			_say("TUT_CHECKERS_JUMP_CAP_ROUTE")
		Lesson.MUST:
			_say("TUT_CHECKERS_MUST_CAP_MOST")
			_art._select(_sq("b2"))
		Lesson.KING:
			_lay(KING_STILL)
			_art._select(_sq("d8"))
			_say("TUT_CHECKERS_KING_CAP_FLY")
		Lesson.END:
			_lay(BLOCK_STILL, false, Rules.DARK)
			_art.interactive = false
			_art.finish("won")
			_say("TUT_CHECKERS_END_CAP_STUCK")
		Lesson.BAR:
			_art.set_hint(_find("c3", "d4"))
			_buttons.bulb.badge = hints - 1

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

static func _sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

## The legal move from `a` that ends on `b`.
func _find(a: String, b: String) -> PackedInt32Array:
	for m: PackedInt32Array in _rules.legal_moves():
		if m[0] == _sq(a) and Rules.mv_to(m) == _sq(b):
			return m
	return PackedInt32Array()

## A position set on fresh rules and the board laid from it; `enter` deals
## the pieces in, as a new game does.
func _lay(spec: String, enter := false, turn := Rules.LIGHT) -> void:
	var g: RefCounted = Rules.new(Rules.Variant.BRAZILIAN, true)
	for item in spec.split(" ", false):
		var ch := item[3]
		var v := Rules.MAN if ch.to_lower() == "m" else Rules.KING
		g.board[_sq(item.substr(0, 2))] = v if ch == ch.to_upper() else -v
	g.turn = turn
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	_rules = g
	_played.clear()
	_art.setup(g, Rules.LIGHT, enter)
	if not enter:
		_turn()

## The hand's turn, as the screen begins it: the board takes touch, and the
## pieces that can take wear their ring.
func _turn() -> void:
	var mine: bool = _rules.turn == Rules.LIGHT and _rules.status() == Rules.PLAYING
	_art.interactive = mine
	var must := PackedInt32Array()
	if mine:
		for m: PackedInt32Array in _rules.legal_moves():
			if Rules.mv_ncaps(m) > 0 and not must.has(m[0]):
				must.append(m[0])
	_art.set_must(must)

## A move made on the rules and played on the board, the screen's way: the
## board's `chosen` comes here, and so do the computer's answers.
func _make(m: PackedInt32Array) -> void:
	if m.is_empty():
		return
	var d: Dictionary = _rules.describe(m)
	_rules.make(m)
	_played.append(d)
	_art.interactive = false
	_art.set_must(PackedInt32Array())
	_art.play(d)

## The computer's answer: it holds its piece up a beat, then moves.
func _reply(a: String, b: String, gen: int) -> bool:
	var m := _find(a, b)
	_art.set_lifted(_sq(a))
	if not await _wait(PONDER + 0.25, gen):
		return false
	_make(m)
	return await _settle(gen)

## The game is over and the hand has won: the board's own ending.
func _won(key: String, gen: int) -> bool:
	_say(key)
	_art.interactive = false
	_art.finish("won")
	return await _wait(3.0, gen)

# --- the finger, through the board's own input ---

## A square's middle, in the board's pixels.
func _at(n: String) -> Vector2:
	return _art.px(_art.cell_of(_sq(n)))

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

## The finger goes to `at` (the board's pixels) and rests there a moment.
func _reach(at: Vector2, gen: int) -> bool:
	_finger = _frame.position + _art.position + at
	_down = false
	return await _wait(0.45, gen)

## A tap on a square: a piece to pick it up, a landing to go there.
func _tap(n: String, gen: int) -> bool:
	var at := _at(n)
	if not await _reach(at, gen):
		return false
	_button(true, at)
	if not await _wait(0.14, gen):
		return false
	_button(false, at)
	return await _wait(0.25, gen)

## A drag from a piece to a landing: a press, the way across, the release.
func _drag(a: String, b: String, gen: int) -> bool:
	var from := _at(a)
	var to := _at(b)
	if not await _reach(from, gen):
		return false
	_button(true, from)
	if not await _wait(0.25, gen):
		return false
	var steps := 12
	for k in steps:
		if not await _wait(DRAG / float(steps), gen):
			return false
		var u := float(k + 1) / float(steps)
		_motion(from.lerp(to, u * u * (3.0 - 2.0 * u)))
	if not await _wait(0.15, gen):
		return false
	_button(false, to)
	_lift()
	return true

## The finger presses one of the bar's buttons beside the board.
func _press(icon: String, gen: int) -> bool:
	var b: Button = _buttons[icon]
	var holder: Control = b.get_parent()
	_finger = holder.position + Vector2.ONE * BUTTON * BUTTON_SCALE * 0.5
	_down = false
	if not await _wait(0.6, gen):
		return false
	_down = true
	b.squish()
	if not await _wait(0.25, gen):
		return false
	_down = false
	return await _wait(0.2, gen)

func _button(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	_finger = _frame.position + _art.position + at
	_down = pressed
	_art._gui_input(ev)

func _motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = at
	_finger = _frame.position + _art.position + at
	_finger_at = _finger
	_down = true
	_art._gui_input(ev)

# --- drawing ---

## The cut edge of the board fading into the card (made once a layout), and
## the finger (made once, moved by transform).
func _draw_over() -> void:
	var room := _frame.size
	if room.x <= 0.0 or room.y <= 0.0:
		return
	if _fade_mesh == null or _fade_key != room:
		_fade_key = room
		var b := Face.Builder.new()
		var x0 := _art.position.x
		var x1 := x0 + _art.size.x
		var far := _view() == View.FAR
		var edge := room.y if far else 0.0
		var inner := room.y - FADE if far else FADE
		var solid := Color(Pal.PAPER, 1.0)
		var clear := Color(Pal.PAPER, 0.0)
		var a := b.vertex(Vector2(x0, edge), solid)
		var c := b.vertex(Vector2(x1, edge), solid)
		var e := b.vertex(Vector2(x1, inner), clear)
		var f := b.vertex(Vector2(x0, inner), clear)
		b.tri(a, c, e)
		b.tri(a, e, f)
		_fade_mesh = b.mesh()
	_over.draw_mesh(_fade_mesh, null)
	if _finger_at.x < 0.0:
		return
	if _finger_meshes.is_empty():
		for down in 2:
			var b := Face.Builder.new()
			var r := FINGER_R * (0.85 if down == 1 else 1.0)
			b.disc(Vector2.ZERO, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if down == 1 else 1.0)))
			b.stroke(Face.Builder.ring(Vector2.ZERO, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
			_finger_meshes.append(b.mesh())
	_over.draw_mesh(_finger_meshes[1 if _down else 0], null,
		Transform2D(0.0, _finger_at + Vector2(12.0, 14.0)))
