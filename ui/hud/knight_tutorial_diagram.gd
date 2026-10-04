extends Control

## One page of Knight's tutorial: a small garden-table board played by the
## board itself. The page holds a `Board` -- knight2d.gd with its sounds,
## tip lines, toasts, streak, gags, party and out-of-hearts card taken out --
## dealt a hand-made 5x5 position, and plays the lesson on a loop through the
## board's own input path (a press on a square and its release, in board
## coordinates, as a finger would), over a caption that says what it means.
## So the knight crouches and hops, the rose knights answer, a catch knocks
## your knight dizzy and slides it back, a taken knight tumbles away, a
## bramble springs up behind you and a fenced-in knight nods off, a heart
## splits, and the king topples and his crown lands on your knight's head,
## exactly as on the board. `lesson` picks the page (set before it enters the
## tree):
##
## - HOP: a dot tapped and the knight hops in an L; the next hop takes the
##   king.
## - ANSWER: a dot in rose corners is a catch (a heart on Hard and Insane)
##   and slides back; a hop with no corners, the rose knight answers, then
##   the king.
## - TAKE: a rose knight in a green ring taken, then the king.
## - BRAMBLES (Insane): a bramble grows on the square you leave, and a rose
##   knight left nowhere to hop naps.
## - STUCK: a hop into the corner leaves no way to the king: Start over comes
##   up and is tapped (Easy to Hard); on Insane it is boxed in, a heart, and
##   the brambles wither back. Then the way that works.
## - UNDO: a hop, Undo takes it back; Reset puts every piece back (Reset alone
##   on Insane, which has no Undo).
## - HINT: the bulb hops for you, twice, onto the king.
##
## The board checkup, 2026-10-02: Knight had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { HOP, ANSWER, TAKE, BRAMBLES, STUCK, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How long a hop takes to play out with its answer, before the next tap.
const HOP_WAIT := 1.3

## The positions, 5x5 (a square is y * 5 + x), each checked against the
## real rules (knight_gen.gd's `step`):
##
## HOP: you in the top left, the king two hops away (11, then 2); no guard.
##
##      Y  .  K  .  .
##      .  .  .  .  .
##      .  1  .  .  .
const HOP_POS := {"you": 0, "king": 2, "foes": []}
## ANSWER (and UNDO, HINT): one rose knight at (1, 3). Hopping to 7 lands in
## its reach and is caught; hopping to 11 is safe, it answers to 7, and the
## king is a hop from 11.
##
##      Y  .  K  .  .
##      .  .  x  .  .        x: in its reach
##      .  1  .  .  .
##      .  R  .  .  .
const ANSWER_POS := {"you": 0, "king": 2, "foes": [16]}
const CAUGHT := 7
## TAKE: a rose knight on 7, a hop from you and a hop from the king.
const TAKE_POS := {"you": 0, "king": 4, "foes": [7]}
## BRAMBLES: two rose knights at the foot; your first hop (to 7) leaves the
## one in the corner nowhere to go but its king's square and its friend's,
## so it naps; then 14 and the king on 17.
const NAP_POS := {"you": 0, "king": 17, "foes": [22, 24]}
const NAP_LINE := [7, 14, 17]
## STUCK: the corner (0) is a dead end -- the rose knight answers to 18 and
## reaches both squares out of it; 4 and then the king on 13 is the way.
const STUCK_POS := {"you": 7, "king": 13, "foes": [21]}
const DEAD_END := 0
const STUCK_LINE := [4, 13]

var lesson: int = Lesson.HOP
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
## no streak, gags, party or out-of-hearts card, and a last heart lost never
## puts it to sleep -- the loop deals the position again.
class Board extends "res://puzzles/knight2d.gd":
	## The Start over button and the hearts stand in a column right of the
	## board, which moves left to make room (STUCK on Easy to Hard).
	var side := false

	func puzzle_id() -> String:
		return "knight_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_key: String, _mood: int) -> void:
		pass

	func _on_safe_hop(_to: int, _land: float, _gag: int) -> void:
		pass

	func _party() -> void:
		pass

	func _lose_heart(at: float) -> void:
		super(at)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Just the frame's width of table round the board: the page is short.
	func _inset() -> float:
		return FRAME + 12.0

	## The board leaves room beside it for the hearts' pill, or for the
	## side column.
	func _cell() -> float:
		var c := super()
		if _state.w <= 0:
			return c
		var room := 0.0
		if side:
			room = _column_w() + 24.0
		elif max_hearts > 0:
			room = 2.0 * (_pill_w() + 22.0)
		if room <= 0.0:
			return c
		return minf(c, maxf(0.0, (size.x - room - 2.0 * (FRAME + 12.0)) / _state.w))

	func _heart_row() -> float:
		return 0.0

	func _origin() -> Vector2:
		var o := super()
		if side:
			o.x = FRAME + 24.0
		return o

	func _pill_w() -> float:
		return (2.0 * HEART_R + HEART_GAP) * (max_hearts - 1) + 2.0 * HEART_R + 2.0 * HEART_PILL_PAD.x

	func _column_w() -> float:
		return maxf(_pill_w() if max_hearts > 0 else 0.0, _stuck_btn.get_combined_minimum_size().x)

	## The side column's centre: right of the board's frame.
	func _column_x() -> float:
		var right := _origin().x + _grid_size().x + FRAME
		return (right + size.x) * 0.5

	func _mid_y() -> float:
		return _origin().y + _grid_size().y * 0.5

	## Beside the board: left of it, or atop the side column.
	func _hearts_at(pill: Vector2, _y: float) -> Vector2:
		if side:
			return Vector2(_column_x(), _mid_y() - STUCK_H * 0.5 - 14.0 - pill.y * 0.5)
		var o := _origin()
		return Vector2(maxf(pill.x * 0.5 + 6.0, o.x - FRAME - 16.0 - pill.x * 0.5), _mid_y())

	func _stuck_width() -> float:
		return _stuck_btn.get_combined_minimum_size().x

	func _stuck_spot(w: float) -> Vector2:
		var y := _mid_y() - STUCK_H * 0.5
		if max_hearts > 0:
			y += HEART_R + 14.0
		return Vector2(_column_x() - w * 0.5, y)

	## Position `p` (you, king, foes) as the page deals it on band `b`:
	## brambles on Insane, every heart, and popped in with the board's
	## entrance when `enter`.
	func lay(p: Dictionary, b: int, enter: bool) -> void:
		_gen += 1
		_close_card()
		var foes := PackedInt32Array(p.foes)
		_state.g = {"w": 5, "king": int(p.king), "you": int(p.you), "foes": foes, "brambles": b >= 3}
		_state.difficulty = b
		_state.w = 5
		_state.king = int(p.king)
		_state.reset_board()
		max_hearts = State.hearts_for(b)
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_heart_used = false
		_lost_ever = false
		_undo_ever = false
		_flawless = false
		_deal()
		_reset_rewards()
		_opened = _now() if enter else _now() - 10.0
		if enter and not Motion.reduce:
			_busy_until = _opened + Motion.ENTER_DELAY + 0.2 \
				+ Motion.stagger(_state.foes.size() + 1, 0.07) + Motion.POP_IN
			_busy_for(_busy_until - _now() + MARK_FADE)
		_layout()
		_tip_timer.stop()
		_heart_layer.queue_redraw()
		_life_layer.queue_redraw()

	## Control-local centre of square `c`.
	func square(c: int) -> Vector2:
		return _centre(c)

	## Control-local centre of the Start over button.
	func stuck_mid() -> Vector2:
		return _stuck_btn.position + _stuck_btn.size * 0.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Board.new()
	_art.side = lesson == Lesson.STUCK and band < 3
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

## The board as tall as the page leaves over the caption and the page's
## whole width: the board centres its own frame.
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

func _position() -> Dictionary:
	match lesson:
		Lesson.HOP:
			return HOP_POS
		Lesson.TAKE:
			return TAKE_POS
		Lesson.BRAMBLES:
			return NAP_POS
		Lesson.STUCK:
			return STUCK_POS
	return ANSWER_POS

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the board again without its entrance.
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
		Lesson.HOP:
			_tap(11, "HTP_KN_TAP_CAP", "HTP_KN_L_CAP")
			_tap(2, "HTP_KN_KING_CAP", "")
			_say_for("HTP_KN_DONE_CAP", 3.4)
		Lesson.ANSWER:
			_say_for("HTP_KN_CORNERS_CAP", 1.4)
			_tap(CAUGHT, "", "HTP_KN_CAUGHT_HEART_CAP" if judged else "HTP_KN_CAUGHT_CAP", 1.9)
			_tap(11, "HTP_KN_SAFE_CAP", "HTP_KN_REPLY_CAP", 1.6)
			_tap(2, "HTP_KN_KING_CAP", "")
			_say_for("HTP_KN_DONE_CAP", 3.2)
		Lesson.TAKE:
			_say_for("HTP_KN_RING_CAP", 1.4)
			_tap(7, "", "HTP_KN_TAKEN_CAP", 1.6)
			_tap(4, "HTP_KN_KING_CAP", "")
			_say_for("HTP_KN_DONE_CAP", 3.2)
		Lesson.BRAMBLES:
			_tap(NAP_LINE[0], "HTP_KN_THORN_CAP", "HTP_KN_NAP_CAP", 2.4)
			_tap(NAP_LINE[1], "HTP_KN_NAPPER_CAP", "", 1.6)
			_tap(NAP_LINE[2], "HTP_KN_KING_CAP", "")
			_say_for("HTP_KN_DONE_CAP", 3.2)
		Lesson.STUCK:
			if band >= 3:
				_tap(DEAD_END, "HTP_KN_CORNER_CAP", "HTP_KN_BOXED_CAP", 2.8)
			else:
				_tap(DEAD_END, "HTP_KN_CORNER_CAP", "HTP_KN_LOST_CAP", 1.8)
				_loop.tween_callback(_say.bind("HTP_KN_OVER_CAP"))
				_loop.tween_callback(func() -> void: _point_at(_art.stuck_mid()))
				_loop.tween_interval(0.5)
				_loop.tween_callback(func() -> void: _down = true)
				_loop.tween_interval(0.15)
				_loop.tween_callback(func() -> void: _art._on_start_over())
				_loop.tween_callback(_lift)
				_loop.tween_interval(1.0)
			_tap(STUCK_LINE[0], "HTP_KN_OTHER_CAP", "", 1.5)
			_tap(STUCK_LINE[1], "HTP_KN_KING_CAP", "")
			_say_for("HTP_KN_DONE_CAP", 3.2)
		Lesson.UNDO:
			_tap(11, "HTP_KN_HOP_CAP", "", 1.5)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_KN_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_tap(11, "", "", 1.5)
			_loop.tween_callback(_say.bind("HTP_KN_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_KN_HINT_CAP"))
			_loop.tween_interval(0.4)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.6)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(0.8)
			_say_for("HTP_KN_DONE_CAP", 3.0)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger taps square `c`: the caption turns to `before` as it comes,
## and to `after` once the hop is off; then the hop plays out for `wait`.
func _tap(c: int, before: String, after: String, wait := HOP_WAIT) -> void:
	if before != "":
		_loop.tween_callback(_say.bind(before))
	_loop.tween_callback(func() -> void: _point_at(_art.square(c)))
	_loop.tween_interval(0.5)
	_loop.tween_callback(_button.bind(c, true))
	_loop.tween_interval(0.18)
	_loop.tween_callback(_button.bind(c, false))
	if after != "":
		_loop.tween_callback(_say.bind(after))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## Every lesson back to its question: the position as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the board in with
## its entrance.
func _reset(fresh := false) -> void:
	_art.lay(_position(), band, fresh)
	_lift()
	_say({Lesson.HOP: "HTP_KN_TAP_CAP", Lesson.ANSWER: "HTP_KN_CORNERS_CAP",
		Lesson.TAKE: "HTP_KN_RING_CAP", Lesson.BRAMBLES: "HTP_KN_THORN_CAP",
		Lesson.STUCK: "HTP_KN_CORNER_CAP", Lesson.UNDO: "HTP_KN_HOP_CAP",
		Lesson.HINT: "HTP_KN_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's point, standing still.
func _still() -> void:
	match lesson:
		Lesson.HOP:
			_tap_now(11)
			_say("HTP_KN_L_CAP")
		Lesson.ANSWER:
			_tap_now(11)
			_say("HTP_KN_REPLY_CAP")
		Lesson.TAKE:
			_tap_now(7)
			_say("HTP_KN_TAKEN_CAP")
		Lesson.BRAMBLES:
			_tap_now(NAP_LINE[0])
			_say("HTP_KN_NAP_CAP")
		Lesson.STUCK:
			if band >= 3:
				_say("HTP_KN_CORNER_CAP")
			else:
				_tap_now(DEAD_END)
				_say("HTP_KN_LOST_CAP")
		Lesson.UNDO:
			_tap_now(11)
			_say("HTP_KN_UNDO_CAP" if band < 3 else "HTP_KN_RESET_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_KN_HINT_CAP")
	_art._refresh()

## Square `c` tapped at once, through the board's own input.
func _tap_now(c: int) -> void:
	_button(c, true)
	_button(c, false)
	_lift()

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

func _button(c: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.square(c)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	var cell: float = _art._cell()
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
