extends Control

## One page of Pixel Garden's tutorial: a little tulip copied on a 6x6
## pegboard, played by the board itself. The page holds a `Board` --
## pixel_garden2d.gd with its sounds, tips, toasts, party and out-of-hearts
## card taken out, laid out side by side for a short page (the board on the
## left, the pattern card and the box on the right) -- and plays the lesson
## on a loop through the board's own input path (a press on a compartment, a
## press on a peg and its release, a press dragged along a row), over a
## caption that says what it means. So the tweezers glide, beads fly out of
## the box and seat, a colour runs out and shakes, a bead flies home, the
## iron crosses a plate and fuses it or frowns and sends a bead astray, a
## heart splits, the picture is held up big, exactly as on the board.
## `lesson` picks the page (set before it enters the tree):
##
## - SEAT: a colour picked, a peg tapped, a run dragged along a row.
## - KIT: a bead on the wrong peg, its colour running out, the bead lifted
##   back with its colour and the last one fitting.
## - PLATE: a plate filled right and ironed for good; another filled with a
##   bead astray, which hops home (a heart on Hard and Insane).
## - PEEK: the picture held to see it big.
## - WIND (Insane): the card's squares blown about and turned, a square's
##   clip matched to its plate's, and that plate copied with the clip on top.
## - CHECK (Easy and Medium): Check rings a bead out of place; it is lifted.
## - UNDO: a run taken back by Undo, then Reset sends every bead home.
## - HINT: the bulb puts a peg right, twice (bands with hints).
##
## The board checkup, 2026-10-03: Pixel Garden had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { SEAT, KIT, PLATE, PEEK, WIND, CHECK, UNDO, HINT }

const FINGER_R := 0.3
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How long a seat plays out before the next tap, and a run's step.
const WAIT := 0.8
const STEP := 0.14

## The picture: a tulip, pink with a rose heart on a green stem, five beads
## on each plate (plates are 3x3).
##
##      .  p  .  .  p  .
##      .  p  p  p  p  .
##      .  p  s  s  p  .
##      .  .  p  p  .  .
##      g  .  g  g  .  g
##      .  g  g  g  g  .
const PIC := {"id": "tutorial", "name": "PG_PIC_TULIP",
	"rows": [".p..p.", ".pppp.", ".pssp.", "..pp..", "g.gg.g", ".gggg."]}
## Windblown's card: square q shows plate PERM[q], turned TURN[q] quarter
## turns. The top left square shows the green plate on the bottom right
## (four dots), turned on its side.
const PERM := [3, 2, 1, 0]
const TURN := [1, 2, 3, 1]

var lesson: int = Lesson.SEAT
## The band the board behind the page is on.
var band := 0

var _art: Board
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips or toasts,
## no party, and a last heart lost never puts it to sleep -- the loop deals
## the board again. Laid out for a wide, short page.
class Board extends "res://puzzles/pixel_garden2d.gd":
	func puzzle_id() -> String:
		return "pixelgarden_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)

	func _tell(_key: String, _arg := "") -> void:
		pass

	func _tell_raw(_text: String) -> void:
		pass

	func _tell_hearts(_key: String, _astray: int) -> void:
		pass

	func _party(_span: float) -> void:
		pass

	func _lose_heart() -> void:
		super()
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## The board on the left as tall as the page; on the right the pattern
	## card at the top and the box, its name and bar at the bottom.
	func _layout() -> void:
		if _state.n == 0 or size.x <= 0.0 or size.y <= 0.0:
			return
		var top := 8.0
		var tall := size.y - 2.0 * top
		var gap := 24.0
		var right_w := 440.0
		_cell = minf((tall - 2.0 * RIM) / _span(), (size.x - right_w - gap - 24.0 - 2.0 * RIM) / _span())
		if _cell <= 0.0:
			return
		var side := _cell * _span() + 2.0 * RIM
		right_w = minf(right_w, size.x - side - gap - 16.0)
		var left := (size.x - side - gap - right_w) * 0.5
		_board = Rect2(left, top + (tall - side) * 0.5, side, side)
		_grid = _board.position + Vector2.ONE * (RIM + MARGIN * _cell)
		var rx := left + side + gap
		var th := minf(150.0, tall - HEAD - 6.0)
		_thumb = Rect2(rx, top, th, th)
		_head_top = top
		_right = Rect2(rx, size.y - top - HEAD, right_w, HEAD)
		_place_chips()
		_table = null
		_thumb_mesh = null
		_bands = []
		_love_mesh = null
		_drop_layout_meshes()
		_refresh()

	## Colour `nm`'s compartment.
	func colour(nm: String) -> int:
		return _state.names.find(nm)

	## The board as the page deals it on band `b`: the tulip with `p.beads`
	## ([row, column, colour name]) seated, the colour `p.brush` in hand,
	## every heart; popped in with the board's entrance when `enter`.
	func lay(p: Dictionary, b: int, enter: bool) -> void:
		_state.load_picture(PIC)
		_state.band = b
		if b == State.WINDBLOWN:
			_state.perm = PackedInt32Array(PERM)
			_state.turn = PackedInt32Array(TURN)
		for e: Array in p.get("beads", []):
			_state._seat(int(e[0]) * _state.n + int(e[1]), colour(String(e[2])))
		_gen += 1
		max_hearts = State.hearts_for(b)
		hearts = max_hearts
		out_of_hearts = false
		_heart_used = false
		_lost_ever = false
		_flawless = false
		_asleep = false
		_split_index = -1
		_back_index = -1
		modulate = Color.WHITE
		hints_used = 0
		hints_extra = 0
		checks = 0
		moves = 0
		_done = false
		_running = true
		_close_card()
		_reset_looks()
		# A page turned mid-press leaves the latch and a held card behind.
		_press_finger = -2
		_peek = false
		_peek_at = -100.0
		_solved_at = -1.0
		_won = false
		_toast = ""
		_toast_at = -100.0
		brush = colour(String(p.get("brush", "pink")))
		_tweez_from = brush
		var now := _now()
		_opened = now if enter else now - 10.0
		# The entrance draws on every frame of its pop: nothing else may move
		# before the lesson's first tap.
		_busy_for(Motion.ENTER_DELAY + Motion.ENTER_POP)
		_layout()

	## Control-local centre of the peg at (`r`, `c`).
	func peg(r: int, c: int) -> Vector2:
		return cell_to_local(r, c)

	## Control-local centre of colour `nm`'s compartment.
	func chip(nm: String) -> Vector2:
		return chip_to_local(colour(nm))

	## The pattern card's middle.
	func card() -> Vector2:
		return _thumb.get_center()

	## Where square `q`'s clip sits on the pattern card (the card's own
	## drawing, _build_thumb_pixels).
	func card_clip(q: int) -> Vector2:
		var n: int = _state.n
		var h: int = _state.half
		var inner := Rect2(Vector2.ZERO, _thumb.size).grow(-8.0)
		var s := (inner.size.x - 12.0) / (float(n) + THUMB_GAP_WIND)
		var at := inner.position + Vector2.ONE * 6.0
		var o := at + Vector2(float(q % 2) * (h + THUMB_GAP_WIND), float(q / 2) * (h + THUMB_GAP_WIND)) * s
		var pad := minf(0.15, THUMB_GAP_WIND * 0.4) * s
		var tile := Rect2(o - Vector2.ONE * pad, Vector2.ONE * (h * s + 2.0 * pad))
		var dir := Vector2.UP.rotated(_state.turn[q] * PI * 0.5)
		return _thumb.position + tile.get_center() + dir * (tile.size.x * 0.5 + s * 0.1)

	## Where plate `q`'s clip sits on the board.
	func plate_clip(q: int) -> Vector2:
		var pr := _plate_rect(q)
		return Vector2(pr.get_center().x, pr.position.y - MARGIN * _cell * 0.5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Board.new()
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
	Motion.stop(_loop)
	_loop = null

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
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

## The board each lesson starts from: [row, column, colour] seated.
func _position() -> Dictionary:
	match lesson:
		Lesson.KIT:
			return {"beads": [[1, 1, "pink"], [1, 2, "pink"], [1, 3, "pink"], [1, 4, "pink"], [0, 4, "pink"]],
				"brush": "pink"}
		Lesson.PLATE:
			# The top left plate one rose short of right; the top right one
			# a rose short of full, with a green bead where pink goes.
			return {"beads": [[0, 1, "pink"], [1, 1, "pink"], [1, 2, "pink"], [2, 1, "pink"],
				[0, 4, "pink"], [1, 3, "pink"], [1, 4, "pink"], [2, 4, "green"]], "brush": "pink"}
		Lesson.PEEK, Lesson.HINT:
			return {"beads": [[1, 1, "pink"], [1, 2, "pink"], [1, 3, "pink"], [1, 4, "pink"]]}
		Lesson.WIND:
			return {"beads": [[1, 1, "pink"], [1, 2, "pink"]], "brush": "green"}
		Lesson.CHECK:
			return {"beads": [[1, 1, "pink"], [1, 2, "pink"], [0, 2, "pink"], [5, 1, "green"], [5, 2, "green"]]}
	return {}

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
	_loop.tween_interval(1.6)
	var judged := band >= 3
	match lesson:
		Lesson.SEAT:
			_tap_at(func() -> Vector2: return _art.chip("pink"), "HTP_PG_PICK_CAP", "", 1.0)
			_tap(0, 1, "HTP_PG_TAP_CAP", "", 1.2)
			_run([[1, 1], [1, 2], [1, 3], [1, 4]], "HTP_PG_RUN_CAP", 1.4)
			_tap_at(func() -> Vector2: return _art.chip("green"), "HTP_PG_EACH_CAP", "", 0.8)
			_run([[5, 1], [5, 2], [5, 3], [5, 4]], "", 2.0)
		Lesson.KIT:
			_tap_at(func() -> Vector2: return _art.chip("rose"), "HTP_PG_PICK_CAP", "", 0.8)
			_tap(2, 1, "HTP_PG_WRONG_CAP", "", WAIT)
			_tap(2, 2, "", "", WAIT)
			_tap(2, 3, "", "HTP_PG_OUT_CAP", 1.8)
			_tap(2, 1, "HTP_PG_LIFT_CAP", "", 1.4)
			_tap(2, 3, "HTP_PG_FITS_CAP", "", 2.2)
		Lesson.PLATE:
			_tap_at(func() -> Vector2: return _art.chip("rose"), "HTP_PG_LAST_CAP", "", 0.8)
			_tap(2, 2, "", "HTP_PG_IRON_CAP", 3.0)
			_tap(2, 3, "HTP_PG_FULL_CAP", "", 1.4)
			_say_for("HTP_PG_ASTRAY_HEART_CAP" if judged else "HTP_PG_ASTRAY_CAP", 2.8)
		Lesson.PEEK:
			_hold_at(func() -> Vector2: return _art.card(), "HTP_PG_PEEK_CAP", 2.0, 1.6)
		Lesson.WIND:
			_point_for(func() -> Vector2: return _art.card_clip(0), "HTP_PG_BLOWN_CAP", 2.2)
			_point_for(func() -> Vector2: return _art.plate_clip(PERM[0]), "HTP_PG_CLIP_CAP", 2.2)
			_run([[5, 3], [5, 4]], "HTP_PG_TOP_CAP", 0.6)
			_run([[4, 3]], "", 0.6)
			_run([[4, 5]], "", 2.0)
		Lesson.CHECK:
			_loop.tween_callback(_say.bind("HTP_PG_CHECK_CAP"))
			_loop.tween_interval(0.5)
			_loop.tween_callback(func() -> void: _art.check())
			_loop.tween_interval(1.8)
			_tap(0, 2, "HTP_PG_CHECK_LIFT_CAP", "", 2.0)
		Lesson.UNDO:
			_run([[1, 1], [1, 2], [1, 3], [1, 4]], "HTP_PG_RUN_CAP", 1.0)
			_say_for("HTP_PG_UNDO_CAP", 0.6)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(1.4)
			_run([[1, 1], [1, 2], [1, 3], [1, 4]], "", 0.8)
			_run([[0, 1]], "", 1.0)
			_say_for("HTP_PG_RESET_CAP", 0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_say_for("HTP_PG_HINT_CAP", 0.4)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.6)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.2)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger rests on `at` for `hold`, the caption turned to `key`.
func _point_for(at: Callable, key: String, hold: float) -> void:
	if key != "":
		_loop.tween_callback(_say.bind(key))
	_loop.tween_callback(func() -> void: _point_at(at.call()))
	_loop.tween_interval(hold)
	_loop.tween_callback(_lift)

## The finger taps the peg at (`r`, `c`).
func _tap(r: int, c: int, before: String, after: String, wait := WAIT) -> void:
	_tap_at(func() -> Vector2: return _art.peg(r, c), before, after, wait)

## The finger taps `at`: the caption turns to `before` as it comes, and to
## `after` once it is up; then it plays out for `wait`.
func _tap_at(at: Callable, before: String, after: String, wait := WAIT) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(at.call()))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(at.call(), true))
	_loop.tween_interval(0.16)
	_loop.tween_callback(func() -> void: _button(at.call(), false))
	if after != "":
		_loop.tween_callback(_say.bind(after))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## The finger holds `at` for `hold`, then lets go and waits `wait`.
func _hold_at(at: Callable, key: String, hold: float, wait: float) -> void:
	if key != "":
		_loop.tween_callback(_say.bind(key))
	_loop.tween_callback(func() -> void: _point_at(at.call()))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(at.call(), true))
	_loop.tween_interval(hold)
	_loop.tween_callback(func() -> void: _button(at.call(), false))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## The finger presses the first peg of `pegs` ([row, column] each) and drags
## through the rest a peg a step, then lets go; then it plays out for `wait`.
func _run(pegs: Array, key: String, wait: float) -> void:
	if key != "":
		_loop.tween_callback(_say.bind(key))
	var first: Array = pegs[0]
	_loop.tween_callback(func() -> void: _point_at(_art.peg(first[0], first[1])))
	_loop.tween_interval(0.45)
	_loop.tween_callback(func() -> void: _button(_art.peg(first[0], first[1]), true))
	for i in range(1, pegs.size()):
		var p: Array = pegs[i]
		_loop.tween_interval(STEP)
		_loop.tween_callback(func() -> void: _motion(_art.peg(p[0], p[1])))
	var last: Array = pegs[pegs.size() - 1]
	_loop.tween_interval(STEP)
	_loop.tween_callback(func() -> void: _button(_art.peg(last[0], last[1]), false))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## Every lesson back to its question: the board as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the board in
## with its entrance.
func _reset(fresh := false) -> void:
	_art.lay(_position(), band, fresh)
	_lift()
	_say({Lesson.SEAT: "HTP_PG_PICK_CAP", Lesson.KIT: "HTP_PG_PICK_CAP", Lesson.PLATE: "HTP_PG_LAST_CAP",
		Lesson.PEEK: "HTP_PG_PEEK_CAP", Lesson.WIND: "HTP_PG_BLOWN_CAP", Lesson.CHECK: "HTP_PG_CHECK_CAP",
		Lesson.UNDO: "HTP_PG_RUN_CAP", Lesson.HINT: "HTP_PG_HINT_CAP"}[lesson])

## Reduce motion: the lesson's point, standing still.
func _still() -> void:
	match lesson:
		Lesson.SEAT:
			_tap_now(_art.peg(0, 1))
			_drag_now([[1, 1], [1, 2], [1, 3], [1, 4]])
			_say("HTP_PG_RUN_CAP")
		Lesson.KIT:
			_art._pick(_art.colour("rose"))
			_tap_now(_art.peg(2, 1))
			_tap_now(_art.peg(2, 2))
			_tap_now(_art.peg(2, 3))
			_say("HTP_PG_OUT_CAP")
		Lesson.PLATE:
			_art._pick(_art.colour("rose"))
			_tap_now(_art.peg(2, 2))
			_say("HTP_PG_IRON_CAP")
		Lesson.PEEK:
			_art._press(_art.card())
			_say("HTP_PG_PEEK_CAP")
		Lesson.WIND:
			_drag_now([[5, 3], [5, 4]])
			_say("HTP_PG_CLIP_CAP")
		Lesson.CHECK:
			_art.check()
			_say("HTP_PG_CHECK_CAP")
		Lesson.UNDO:
			_drag_now([[1, 1], [1, 2], [1, 3], [1, 4]])
			_say("HTP_PG_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_PG_HINT_CAP")
	_art._refresh()

func _tap_now(at: Vector2) -> void:
	_button(at, true)
	_button(at, false)
	_lift()

func _drag_now(pegs: Array) -> void:
	_button(_art.peg(pegs[0][0], pegs[0][1]), true)
	for i in range(1, pegs.size()):
		_motion(_art.peg(pegs[i][0], pegs[i][1]))
	_button(_art.peg(pegs[pegs.size() - 1][0], pegs[pegs.size() - 1][1]), false)
	_lift()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the finger, through the board's own input ---

func _point_at(at: Vector2) -> void:
	_finger = at
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(at: Vector2, pressed: bool) -> void:
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
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	var cell: float = _art._cell
	if _finger.x < 0.0 or cell <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := maxf(16.0, cell * FINGER_R) * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
