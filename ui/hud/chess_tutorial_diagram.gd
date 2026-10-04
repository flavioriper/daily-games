extends Control

## One page of Chess's tutorial: a few pieces on the board itself. The page
## holds a `Quiet` -- versus/chess_board.gd with its sounds and knocks taken
## out -- laid at a cell of its own and looked at through a window four
## ranks deep (the player's end with the tray of what they took, or the far
## end with the computer's), over a hand-made position on the game's own
## rules (versus/chess_rules.gd). The lesson is played on a loop through the
## board's own input path (a press on a piece, a press on a square, or a
## press, a drag and the release), and the page does for the board what the
## screen does: makes the chosen move on the rules, hands the board its
## description, sets the check on a king left in one, ends the game on a
## mate or a stalemate, lifts the computer's piece a beat before it answers.
## So the marks, the hop, the knock into the tray, the "!" and its dashed
## line, the castled rook, the picker over the last row, the toppled king
## and the sleeping draw are the board's, not a drawing of them. `lesson`
## picks the page (set before it enters the tree):
##
## - MOVE: tap a piece, tap a dot; the computer answers; drag onto a ring.
## - LINES: the rook, the bishop and the queen, each picked up and moved.
## - STEPS: the knight over its pawns, the king, the pawn ahead and taking.
## - CHECK: a rook gives check, the king steps out, the other rook mates.
## - SPECIAL: castling, a pawn taken as it passes, a pawn made a queen.
## - DRAW: a queen leaves the king no move and no check: everyone sleeps.
## - BAR: a move and its answer taken back, the bulb's arrow, a new game.

const Rules = preload("res://versus/chess_rules.gd")
const Board = preload("res://versus/chess_board.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")

enum Lesson { MOVE, LINES, STEPS, CHECK, SPECIAL, DRAW, BAR }

## The board's cell on the page: the whole width of the board fits the slot,
## and four ranks, the frame and one tray its height above the caption.
const CELL := 78.0
const CAPTION_H := 46.0
const FINGER_R := 24.0
const FINGER_ALPHA := 0.16
## How long a drag takes from its piece to its square, how long the computer
## holds its piece up (the screen's PONDER), and a position's fade.
const DRAG := 0.6
const PONDER := 0.35
const FADE := 0.16
## The BAR page's own Undo, Reset and bulb, beside the caption.
const CHIPS := ["undo", "reset", "bulb"]
const CHIP := 44.0
const CHIP_GAP := 8.0
const CHIP_LEFT := 14.0

## The positions, rank 8 first, the player's cream pieces in capitals. Each
## has both kings (the rules look for them) and as much on the far side as on
## the near, so the tray's "+n" tag only shows once something is taken.
const P_MOVE := "1n2k3/8/8/3p4/8/8/4P3/4K1N1"
const P_ROOK := "r3k3/p7/8/8/8/8/2R2P2/6K1"
const P_BISHOP := "2b1k3/8/8/8/8/8/8/2B3K1"
const P_QUEEN := "3qk3/8/8/8/8/8/3Q4/6K1"
const P_KNIGHT := "1n2k3/pp6/8/8/8/8/1PP5/1N2K3"
const P_KING := "4k3/8/8/8/8/8/3K4/8"
const P_PAWN := "4k3/1p6/8/8/8/8/1P6/4K3"
const P_PAWN_TAKE := "4k3/8/8/8/3p4/4P3/8/4K3"
const P_CHECK := "8/4k3/1R6/R7/8/8/8/4K3"
const P_CHECKED := "8/R3k3/1R6/8/8/8/8/4K3"
const P_CASTLE := "r3k3/5ppp/8/8/8/8/5PPP/4K2R"
const P_PASSANT := "7k/3p4/8/4P3/8/8/8/4K3"
const P_PROMOTE := "8/1P6/8/7k/8/8/8/4K3"
const P_DRAW := "k7/8/4Q3/5K2/8/8/8/8"
const P_DRAWN := "k7/8/1Q6/5K2/8/8/8/8"

var lesson: int = Lesson.MOVE
## The set the screen's board wears, and the hints a game gives.
var skin: RefCounted
var hints := 3

var _window: Control
var _art: Quiet
var _over: Control
var _caption: Label
var _rules: RefCounted
var _history: Array = []
## Which end of the board the window is on: the far one, or the player's.
var _top := false
var _begun := false
var _running := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _chip_down := -1
var _badge := 0
var _chips_shown: ArrayMesh
var _finger_shown: ArrayMesh
var _fade: Tween
## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _clock: Timer

## The board, quiet: no sound set (its id names none), no cue and no knock.
class Quiet extends "res://versus/chess_board.gd":
	func puzzle_id() -> String:
		return "chess_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.buzzes = false

	func _cue(_name: String, _pitch := 1.0) -> void:
		pass

	## Every sleeper breathes out a z: the board gives them to two in five,
	## and a page's draw has two or three pieces in sight.
	func all_nap() -> void:
		for a in _actors:
			a.phase = fmod(a.phase, 0.4)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = lesson in [Lesson.CHECK, Lesson.DRAW]
	_badge = hints
	_window = Control.new()
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.clip_contents = true
	add_child(_window)
	_art = Quiet.new()
	if skin != null:
		_art.skin = skin
	_window.add_child(_art)
	_art.chosen.connect(_make)
	_art.settled.connect(_on_settled)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall.
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

## The window at the top of the page over the caption when it looks at the
## far end, under it when it looks at the player's; the board hung in it so
## that end's tray is just inside.
func _layout() -> void:
	if _art == null or size.x <= 0.0:
		return
	var win_h := maxf(0.0, size.y - CAPTION_H - 2.0)
	_window.position = Vector2(0.0, 0.0 if _top else size.y - win_h)
	_window.size = Vector2(size.x, win_h)
	# A pixel over, so the board's floor() lands on CELL.
	_art.size = Vector2(8.0 + 2.0 * Board.FRAME, 8.0 + 2.0 * (Board.FRAME + Board.TRAY + Board.TRAY_GAP)) * CELL + Vector2.ONE
	# The near tray's deep edge hangs a little under the board's own rect.
	_art.position = Vector2(floorf((size.x - _art.size.x) * 0.5), 0.0 if _top else win_h - _art.size.y - 6.0)
	_over.position = Vector2.ZERO
	_over.size = size
	var left := CHIP_LEFT + CHIPS.size() * (CHIP + CHIP_GAP) + 6.0 if lesson == Lesson.BAR else 20.0
	_caption.position = Vector2(left, size.y - CAPTION_H if _top else 0.0)
	_caption.size = Vector2(size.x - left - 20.0, CAPTION_H)
	if not _begun and is_inside_tree():
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
	Motion.stop(_fade)
	_window.modulate.a = 1.0
	if Motion.reduce:
		_still()
		_running = false
		return
	var first := true
	while gen == _gen:
		var ok := true
		match lesson:
			Lesson.MOVE:
				ok = await _show(P_MOVE, "TUT_CHESS_CAP_TAP", gen, first)
				if ok:
					ok = await _tap("g1", gen, 1.2)
				if ok:
					_say("TUT_CHESS_CAP_GO")
					ok = await _tap("f3", gen)
				if ok:
					ok = await _landed(gen, 0.5)
				if ok:
					_say("TUT_CHESS_CAP_BOT")
					ok = await _reply("d5", "d4", gen)
				if ok:
					_say("TUT_CHESS_CAP_DRAG")
					ok = await _drag("f3", "d4", gen)
				if ok:
					ok = await _landed(gen, 2.4)
			Lesson.LINES:
				for step: Array in [[P_ROOK, "TUT_CHESS_CAP_ROOK", "c2", "c4"], [P_BISHOP, "TUT_CHESS_CAP_BISHOP", "c1", "f4"],
						[P_QUEEN, "TUT_CHESS_CAP_QUEEN", "d2", "b4"]]:
					if ok:
						ok = await _walk(step, gen, first)
						first = false
			Lesson.STEPS:
				for step: Array in [[P_KNIGHT, "TUT_CHESS_CAP_KNIGHT", "b1", "c3"], [P_KING, "TUT_CHESS_CAP_KING", "d2", "e3"],
						[P_PAWN, "TUT_CHESS_CAP_PAWN", "b2", "b4"], [P_PAWN_TAKE, "TUT_CHESS_CAP_PAWN_TAKE", "e3", "d4"]]:
					if ok:
						ok = await _walk(step, gen, first)
						first = false
			Lesson.CHECK:
				ok = await _show(P_CHECK, "TUT_CHESS_CAP_ATTACK", gen, first)
				if ok:
					ok = await _tap("a5", gen, 0.7)
				if ok:
					ok = await _tap("a7", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					_lift()
					_say("TUT_CHESS_CAP_CHECK")
					ok = await _wait(1.7, gen)
				if ok:
					ok = await _reply("e7", "e8", gen)
				if ok:
					_say("TUT_CHESS_CAP_CHASE")
					ok = await _tap("b6", gen, 0.7)
				if ok:
					ok = await _tap("b8", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					_lift()
					_say("TUT_CHESS_CAP_MATE")
					_art.finish("won", _rules.kings[_rules.turn])
					ok = await _wait(4.2, gen)
			Lesson.SPECIAL:
				ok = await _show(P_CASTLE, "TUT_CHESS_CAP_CASTLE", gen, first, Rules.WHITE, Rules.WK, false)
				if ok:
					ok = await _tap("e1", gen, 1.2)
				if ok:
					ok = await _tap("g1", gen)
				if ok:
					ok = await _landed(gen, 1.6)
				if ok:
					ok = await _show(P_PASSANT, "TUT_CHESS_CAP_PASSANT_RUN", gen, false, Rules.BLACK, 0, true)
				if ok:
					ok = await _reply("d7", "d5", gen)
				if ok:
					_say("TUT_CHESS_CAP_PASSANT")
					ok = await _tap("e5", gen, 1.2)
				if ok:
					ok = await _tap("d6", gen)
				if ok:
					ok = await _landed(gen, 1.6)
				if ok:
					ok = await _show(P_PROMOTE, "TUT_CHESS_CAP_PROMOTE", gen, false, Rules.WHITE, 0, true)
				if ok:
					ok = await _tap("b7", gen, 0.6)
				if ok:
					ok = await _tap("b8", gen, 1.1)
				if ok:
					# the picker's first piece stands on the square itself
					ok = await _tap("b8", gen)
				if ok:
					ok = await _landed(gen, 2.2)
			Lesson.DRAW:
				ok = await _show(P_DRAW, "TUT_CHESS_CAP_STALE_A", gen, first)
				if ok:
					ok = await _tap("e6", gen, 0.8)
				if ok:
					ok = await _tap("b6", gen)
				if ok:
					ok = await _settle(gen)
				if ok:
					_lift()
					_say("TUT_CHESS_CAP_STALE_B")
					_art.finish("draw")
					_art.all_nap()
					ok = await _wait(4.6, gen)
			Lesson.BAR:
				_badge = hints
				ok = await _show(P_MOVE, "TUT_CHESS_CAP_PLAYED", gen, first)
				if ok:
					ok = await _tap("g1", gen, 0.5)
				if ok:
					ok = await _tap("f3", gen)
				if ok:
					ok = await _landed(gen, 0.3)
				if ok:
					ok = await _reply("d5", "d4", gen)
				if ok:
					_say("TUT_CHESS_CAP_UNDO")
					ok = await _press_chip(0, gen)
				# your move and the answer to it, as the screen takes them back
				for k in 2:
					if ok:
						var d: Dictionary = _history.pop_back()
						_rules.unmake()
						_art.rewind(d)
						ok = await _settle(gen)
				if ok:
					ok = await _wait(1.0, gen)
				if ok:
					_say("TUT_CHESS_CAP_HINT")
					ok = await _press_chip(2, gen)
				if ok:
					_badge = maxi(0, hints - 1)
					_art.set_hint(_find("g1", "f3"))
					ok = await _wait(2.2, gen)
				if ok:
					_say("TUT_CHESS_CAP_RESET")
					ok = await _press_chip(1, gen)
				if ok:
					_badge = hints
					_lay(P_MOVE, Rules.WHITE, 0, true)
					ok = await _settle(gen)
				if ok:
					ok = await _wait(1.6, gen)
		first = false
		if not ok:
			return

## One piece's turn on a page that walks through several: its position, its
## name and move in the caption, picked up so its moves show, and moved.
func _walk(step: Array, gen: int, first: bool) -> bool:
	if not await _show(step[0], step[1], gen, first):
		return false
	if not await _tap(step[2], gen, 1.3):
		return false
	if not await _tap(step[3], gen):
		return false
	return await _landed(gen, 1.3)

## Reduce-motion: the lesson's telling moment, standing still.
func _still() -> void:
	_lift()
	match lesson:
		Lesson.MOVE:
			_lay(P_MOVE)
			_art._select(_sq("g1"))
			_say("TUT_CHESS_CAP_TAP")
		Lesson.LINES:
			_lay(P_QUEEN)
			_art._select(_sq("d2"))
			_say("TUT_CHESS_CAP_QUEEN")
		Lesson.STEPS:
			_lay(P_KNIGHT)
			_art._select(_sq("b1"))
			_say("TUT_CHESS_CAP_KNIGHT")
		Lesson.CHECK:
			_lay(P_CHECKED, Rules.BLACK)
			_art.set_check(_rules.kings[Rules.BLACK])
			_say("TUT_CHESS_CAP_CHECK")
		Lesson.SPECIAL:
			_face(true)
			_lay(P_PROMOTE)
			_art._select(_sq("b7"))
			_art._choose(_sq("b8"))
			_say("TUT_CHESS_CAP_PROMOTE")
		Lesson.DRAW:
			_lay(P_DRAWN, Rules.BLACK)
			_art.finish("draw")
			_say("TUT_CHESS_CAP_STALE_B")
		Lesson.BAR:
			_lay(P_MOVE)
			_art.set_hint(_find("g1", "f3"))
			_badge = maxi(0, hints - 1)
			_say("TUT_CHESS_CAP_HINT")

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Waits for the board to say the move has landed.
func _settle(gen: int) -> bool:
	while _art.is_busy():
		if not await _wait(0.05, gen):
			return false
	return gen == _gen

## The move has landed, the finger is off, and `hold` seconds to look.
func _landed(gen: int, hold: float) -> bool:
	if not await _settle(gen):
		return false
	_lift()
	return await _wait(hold, gen)

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the position ---

func _sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

## A square's middle, page-local.
func _at(n: String) -> Vector2:
	return _window.position + _art.position + _art.px(_art.cell_of(_sq(n)))

func _find(a: String, b: String) -> int:
	for m in _rules.legal_moves():
		if Rules.mv_from(m) == _sq(a) and Rules.mv_to(m) == _sq(b):
			return m
	return -1

## Which end of the board the window looks at.
func _face(top: bool) -> void:
	if top != _top:
		_top = top
		_layout()

## The position `rows` on the rules and the board, the player in cream at
## the bottom; `enter` drops the pieces in as a new game does.
func _lay(rows: String, turn := Rules.WHITE, castling := 0, enter := false) -> void:
	var g: RefCounted = Rules.new(true)
	var map := {"p": Rules.PAWN, "n": Rules.KNIGHT, "b": Rules.BISHOP, "r": Rules.ROOK, "q": Rules.QUEEN, "k": Rules.KING}
	var ranks := rows.split("/")
	for i in 8:
		var f := 0
		for ch in ranks[i]:
			if ch.is_valid_int():
				f += int(ch)
			else:
				var t: int = map[ch.to_lower()]
				g.board[(7 - i) * 8 + f] = t if ch == ch.to_upper() else -t
				f += 1
	g.turn = turn
	g.castling = castling
	g.rehash()
	g.hashes = PackedInt64Array([g.hash])
	_rules = g
	_history.clear()
	_art.setup(g, Rules.WHITE, enter)
	_art.interactive = true

## A lesson's position and its caption: at once the first time, through a
## short fade after that (and to the board's other end when `top` says so).
func _show(rows: String, key: String, gen: int, first: bool, turn := Rules.WHITE, castling := 0, top := false) -> bool:
	_lift()
	if lesson != Lesson.SPECIAL:
		top = _top
	if not first:
		Motion.stop(_fade)
		_fade = create_tween()
		_fade.tween_property(_window, "modulate:a", 0.0, FADE)
		if not await _wait(FADE + 0.04, gen):
			return false
	_face(top)
	_lay(rows, turn, castling)
	_say(key)
	if not first:
		Motion.stop(_fade)
		_fade = create_tween()
		_fade.tween_property(_window, "modulate:a", 1.0, FADE)
	return await _wait(0.9 if first else 0.6, gen)

## What the screen does with a move the board chose (or the computer's):
## made on the rules, handed to the board to play.
func _make(m: int) -> void:
	if m < 0:
		return
	var d: Dictionary = _rules.describe(m)
	_rules.make(m)
	_history.append(d)
	_art.interactive = false
	_art.play(d)

## And once it has landed: a king left in check is marked, and trembles.
func _on_settled() -> void:
	if _rules == null:
		return
	if _rules.in_check():
		var king: int = _rules.kings[_rules.turn]
		_art.set_check(king)
		_art.tremble(king)
	else:
		_art.set_check(-1)
	_art.interactive = true

## The computer's answer: its piece held up a beat, then moved.
func _reply(a: String, b: String, gen: int) -> bool:
	if not await _settle(gen):
		return false
	_lift()
	if not await _wait(0.5, gen):
		return false
	_art.set_lifted(_sq(a))
	if not await _wait(PONDER, gen):
		return false
	_make(_find(a, b))
	if not await _settle(gen):
		return false
	return await _wait(0.6, gen)

# --- the finger, through the board's own input ---

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

## A tap on square `n`: a piece to pick it up, a mark to go there.
func _tap(n: String, gen: int, hold := 0.2) -> bool:
	var at := _at(n)
	_finger = at
	_down = false
	if not await _wait(0.4, gen):
		return false
	_button(true, at)
	if not await _wait(0.14, gen):
		return false
	_button(false, at)
	return await _wait(hold, gen)

## A drag from square `a` to `b`: a press, the way across, the release.
func _drag(a: String, b: String, gen: int) -> bool:
	var from := _at(a)
	var to := _at(b)
	_finger = from
	_down = false
	if not await _wait(0.4, gen):
		return false
	_button(true, from)
	if not await _wait(0.5, gen):
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
	return true

## The finger presses one of the page's own buttons.
func _press_chip(i: int, gen: int) -> bool:
	_finger = _chip_rect(i).get_center()
	_down = false
	if not await _wait(0.6, gen):
		return false
	_down = true
	_chip_down = i
	if not await _wait(0.2, gen):
		return false
	_chip_down = -1
	_lift()
	return true

func _button(pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at - _window.position - _art.position
	_finger = at
	_down = pressed
	_art._gui_input(ev)

func _motion(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = at - _window.position - _art.position
	_finger = at
	_down = true
	_art._gui_input(ev)

# --- drawing ---

func _chip_rect(i: int) -> Rect2:
	var y := (size.y - CAPTION_H if _top else 0.0) + (CAPTION_H - CHIP) * 0.5
	return Rect2(Vector2(CHIP_LEFT + i * (CHIP + CHIP_GAP), y), Vector2(CHIP, CHIP))

## The BAR page's Undo, Reset and bulb (the screen's are under the card),
## the bulb's count, and the finger.
func _draw_over() -> void:
	if lesson == Lesson.BAR:
		var b := Face.Builder.new()
		for i in CHIPS.size():
			var r := _chip_rect(i)
			var sink := 3.0 if i == _chip_down else 0.0
			b.fan(Face.Builder.round_rect(r.position + Vector2(0, 4.0), r.size, 12.0), Pal.LINE)
			b.fan(Face.Builder.round_rect(r.position + Vector2(0, sink), r.size, 12.0), Pal.SUN if i == _chip_down else Pal.SURFACE)
		var bulb := _chip_rect(2)
		var dot := Vector2(bulb.end.x - 3.0, bulb.position.y + 5.0)
		if _badge > 0:
			b.disc(dot, 11.0, Pal.ACCENT)
		_chips_shown = b.mesh()
		_over.draw_mesh(_chips_shown, null)
		for i in CHIPS.size():
			var r := _chip_rect(i)
			var sink := 3.0 if i == _chip_down else 0.0
			Icons.paint(_over, CHIPS[i], Rect2(r.position + Vector2(CHIP, CHIP) * 0.15 + Vector2(0, sink), Vector2(CHIP, CHIP) * 0.7), Pal.TEXT)
		if _badge > 0:
			var font: Font = CozyTheme.body(800)
			var word := str(_badge)
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_over.draw_string(font, dot + Vector2(-w * 0.5, 6.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	_finger_shown = null
	if _finger.x >= 0.0:
		var f := Face.Builder.new()
		var at := _finger + Vector2(10.0, 12.0)
		var fr := FINGER_R * (0.85 if _down else 1.0)
		f.disc(at, fr, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		f.stroke(Face.Builder.ring(at, fr, fr), 3.0, Color(Pal.TEXT, 0.45), true)
		_finger_shown = f.mesh()
		_over.draw_mesh(_finger_shown, null)
