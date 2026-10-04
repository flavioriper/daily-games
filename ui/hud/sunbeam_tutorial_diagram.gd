extends Control

## One page of Sunbeam's tutorial: a small greenhouse floor played by the
## board itself. The page holds a `Floor` -- sunbeam2d.gd with its sounds,
## tip lines, streak, gags, party and out-of-hearts card taken out -- dealt a
## hand-made floor, and plays the lesson on a loop through the board's own
## input path (a press on a piece, motions along its rail, a release, in
## board coordinates, as a finger would), over a caption that says what it
## means. So the light bends live under the finger, a drop rings as it is
## lit, the bud grows and blooms, a snail worries under a held piece's light
## and wakes when it is let go there, a shy drop blushes and dries, a heart
## splits and the piece slides back, exactly as on the board. `lesson` picks
## the page (set before it enters the tree):
##
## - DRAG: a mirror slid into the light turns it into the bud.
## - GOAL (Easy to Hard): the light in the bud with a drop still dry; swung
##   over the drop, then into the bud.
## - CUP: a copper cup slid into the light sends it back one lane over.
## - SNAILS (Hard): a held piece's light on a snail is a peek; let go there,
##   it wakes, a heart, the piece slides back; let go where the light misses.
## - SHY (Insane): let go with the light on a drop and it dries, a heart;
##   the rest set in the shade first, then every drop lit at once.
## - UNDO: Undo takes a slide back; Reset puts every piece back (Reset alone
##   on Insane, which has no Undo).
## - HINT: the bulb slides the next piece home and pins it.
##
## The board checkup, 2026-10-02: Sunbeam had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { DRAG, GOAL, CUP, SNAILS, SHY, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long the finger takes to slide a piece one peg.
const PEG_TIME := 0.42
const CAPTION_H := 92.0

## The floors, in Gen's dictionary (sunbeam_gen.gd). Cells count along the
## rows: on a floor five wide, (x, y) is y * 5 + x.
##
## DRAG, five by four: the sun at the top left shining right, a mirror ("\")
## on a rail down column 3 starting out of the light, the bud under it.
##
##      S  .  .  m  .
##      .  p  .  |  .
##      .  .  .  |  .
##      .  .  .  B  .
const DRAG_FLOOR := {"cols": 5, "rows": 4, "lamp": 0, "dir": 0, "bud": 18,
	"pieces": [{"kind": "m", "t": "\\", "rail": [3, 8, 13], "home": 0}],
	"drops": [], "pots": [6], "start": [2]}
## GOAL (and SNAILS, SHY, UNDO, HINT), five by four: mirror A ("\") on a rail
## along the top row, starting at its far end, so the light runs down column
## 3 into the bud with the drop in column 1 dry; mirror B ("\") on a rail
## along the bottom row, starting at its left end. The answer: A to the
## near end (down column 1, over the drop), B under it (into the bud).
##
##      S  a  a  A  .
##      .  .  z  .  .        z: SNAILS' snail
##      .  d  .  .  .
##      B  b  .  B  .
const GOAL_FLOOR := {"cols": 5, "rows": 4, "lamp": 0, "dir": 0, "bud": 18,
	"pieces": [{"kind": "m", "t": "\\", "rail": [1, 2, 3], "home": 0},
		{"kind": "m", "t": "\\", "rail": [15, 16], "home": 1}],
	"drops": [11], "pots": [9], "start": [2, 0]}
const SNAIL := 7
## SHY's two drops, both down column 1.
const SHY_DROPS := [6, 11]
## CUP, five by three: a cup (mouth left, its second cell under it) on a
## rail down column 3, starting under the light; slid up into it, the light
## comes back along the middle row over the drop into the bud.
##
##      S  .  .  u  .
##      B  .  d  u  .
##      .  p  .  u  .
const CUP_FLOOR := {"cols": 5, "rows": 3, "lamp": 0, "dir": 0, "bud": 5,
	"pieces": [{"kind": "u", "f": 2, "s": 1, "rail": [3, 8], "home": 0}],
	"drops": [7], "pots": [11], "start": [1]}

var lesson: int = Lesson.DRAG
## The band the board behind the page is on.
var band := 0

var _art: Floor
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, streak,
## gags, party or out-of-hearts card, and a last heart lost never puts it to
## sleep -- the loop deals the floor again. A win is the wave and the bloom
## alone, called by the page.
class Floor extends "res://puzzles/sunbeam2d.gd":
	func puzzle_id() -> String:
		return "sunbeam_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_drops(_cells: Array) -> void:
		pass

	func _party() -> void:
		pass

	func _misstep(p: int, before: PackedInt32Array, kind: String, t: float) -> void:
		super(p, before, kind, t)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Just the frame's width of glass round the floor: the page is short.
	func _inset() -> float:
		return FRAME + 12.0

	## The floor leaves room beside it for the hearts' pill.
	func _cell() -> float:
		var c := super()
		if max_hearts <= 0 or _in_ref or _state.cols <= 0:
			return c
		var pill := (2.0 * HEART_R + HEART_GAP) * (max_hearts - 1) + 2.0 * HEART_R + 2.0 * HEART_PILL_PAD.x
		return minf(c, maxf(0.0, (size.x - 2.0 * (pill + FRAME + 22.0)) / _state.cols))

	## The hearts hang beside the floor, so it takes the page's height.
	func _heart_row() -> float:
		return 0.0

	func _hearts_at(pill: Vector2, _y: float) -> Vector2:
		var o := _origin()
		return Vector2(maxf(pill.x * 0.5 + 6.0, o.x - FRAME - 16.0 - pill.x * 0.5), _mid().y)

	## The floor `g` (Gen's dictionary) as the page deals it on band `b`:
	## every piece at its start, every heart, and popped in with the board's
	## entrance (the light running out of the sun) when `enter`.
	func lay(g: Dictionary, b: int, enter: bool) -> void:
		_gen += 1
		_state.g = g
		_state.difficulty = b
		_state.setup()
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
		_make_snails()
		_opened = _now() if enter else _now() - 10.0
		_beam_at = _opened + (0.0 if Motion.reduce or not enter else BEAM_DELAY)
		_layout()
		_tip_timer.stop()
		_heart_layer.queue_redraw()
		_life_layer.queue_redraw()

	## The win as the board shows it, without the party: the gold wave down
	## the light and the bloom.
	func win() -> void:
		_done = true
		_on_solved()

	## Control-local point over piece `p` standing at float peg `s`.
	func piece_at(p: int, s: float) -> Vector2:
		return _pt(_piece_mid(p, s))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Floor.new()
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

## The floor as tall as the page leaves over the caption and the page's
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

## The lesson's floor: a fresh copy, as the board's state keeps it.
func _floor() -> Dictionary:
	var src: Dictionary = {Lesson.DRAG: DRAG_FLOOR, Lesson.CUP: CUP_FLOOR}.get(lesson, GOAL_FLOOR)
	var pieces: Array = []
	for pc: Dictionary in src.pieces:
		var row := pc.duplicate()
		row["rail"] = PackedInt32Array(pc.rail)
		row["sol"] = int(pc.rail[pc.home])
		pieces.append(row)
	var g := {"cols": src.cols, "rows": src.rows, "lamp": src.lamp, "dir": src.dir, "bud": src.bud,
		"pieces": pieces, "drops": PackedInt32Array(src.drops), "pots": PackedInt32Array(src.pots),
		"start": PackedInt32Array(src.start), "snails": PackedInt32Array(), "shy": false,
		"unique": true, "attempts": 0}
	if lesson == Lesson.SNAILS:
		g["snails"] = PackedInt32Array([SNAIL])
	elif lesson == Lesson.SHY:
		g["shy"] = true
		g["drops"] = PackedInt32Array(SHY_DROPS)
	return g

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the floor again without its entrance.
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
		Lesson.DRAG:
			_slide(0, 2, 0, "HTP_SB_PRESS_CAP", {2: "HTP_SB_TURN_CAP"})
			_say_for("HTP_SB_BUD_CAP", 0.5)
			_win()
			_say_for("HTP_SB_DONE_CAP", 3.2)
		Lesson.GOAL:
			_say_for("HTP_SB_DRY_CAP", 1.2)
			_slide(0, 2, 0, "HTP_SB_DROP_CAP")
			_loop.tween_interval(0.6)
			_slide(1, 0, 1, "HTP_SB_HOME_CAP")
			_win()
			_say_for("HTP_SB_DONE_CAP", 3.2)
		Lesson.CUP:
			_slide(0, 1, 0, "HTP_SB_CUP_CAP")
			_say_for("HTP_SB_BACK_CAP", 0.5)
			_win()
			_say_for("HTP_SB_DONE_CAP", 3.2)
		Lesson.SNAILS:
			_slide(0, 2, 1, "HTP_SB_PEEK_CAP", {}, 1.4)
			_say_for("HTP_SB_WAKE_CAP", 2.2)
			_slide(0, 2, 0, "HTP_SB_MISS_CAP", {}, 0.5)
			_loop.tween_interval(0.5)
			_slide(1, 0, 1, "HTP_SB_HOME_CAP")
			_win()
			_say_for("HTP_SB_DONE_CAP", 3.0)
		Lesson.SHY:
			_slide(0, 2, 0, "HTP_SB_SHY_CAP", {}, 0.9)
			_say_for("HTP_SB_DRIED_BACK_CAP", 2.2)
			_slide(1, 0, 1, "HTP_SB_FIRST_CAP")
			_loop.tween_interval(0.6)
			_slide(0, 2, 0, "HTP_SB_ONCE_CAP")
			_win()
			_say_for("HTP_SB_DONE_CAP", 3.2)
		Lesson.UNDO:
			_slide(0, 2, 0, "HTP_SB_DROP_CAP")
			_loop.tween_interval(0.6)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_SB_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_slide(1, 0, 1, "")
				_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind("HTP_SB_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_SB_HINT_CAP"))
			_loop.tween_interval(0.4)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.8)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(0.6)
			_win()
			_loop.tween_interval(3.0)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The win, once the last piece has landed.
func _win() -> void:
	_loop.tween_callback(func() -> void: _art.win())

## The finger takes piece `p` on peg `from` and slides it along its rail to
## peg `to`, the caption turning to `press` on the press and to `at[k]` as
## it sets off toward the k-th peg on its way; it holds `hold` before
## letting go.
func _slide(p: int, from: int, to: int, press: String, at := {}, hold := 0.25) -> void:
	if press != "":
		_loop.tween_callback(_say.bind(press))
	_loop.tween_callback(_point.bind(p, float(from)))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(p, float(from), true))
	_loop.tween_interval(0.25)
	var step := 1 if to > from else -1
	var k := 0
	var q := from
	while q != to:
		if at.has(k + 1):
			_loop.tween_callback(_say.bind(at[k + 1]))
		_loop.tween_method(_drag_to.bind(p, float(q), float(q + step)), 0.0, 1.0, PEG_TIME)
		q += step
		k += 1
	_loop.tween_interval(hold)
	_loop.tween_callback(_button.bind(p, float(to), false))
	_loop.tween_interval(0.3)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the floor as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the floor in
## with the board's entrance.
func _reset(fresh := false) -> void:
	_art.lay(_floor(), band, fresh)
	_lift()
	_say({Lesson.DRAG: "HTP_SB_PRESS_CAP", Lesson.GOAL: "HTP_SB_DRY_CAP",
		Lesson.CUP: "HTP_SB_CUP_CAP", Lesson.SNAILS: "HTP_SB_PEEK_CAP",
		Lesson.SHY: "HTP_SB_SHY_CAP", Lesson.UNDO: "HTP_SB_DROP_CAP",
		Lesson.HINT: "HTP_SB_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.SNAILS:
			_slide_now(0, 2, 0)
			_say("HTP_SB_MISS_CAP")
		Lesson.SHY:
			_slide_now(1, 0, 1)
			_say("HTP_SB_FIRST_CAP")
		Lesson.UNDO:
			_slide_now(0, 2, 0)
			_say("HTP_SB_UNDO_CAP" if band < 3 else "HTP_SB_RESET_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_SB_HINT_CAP")
		Lesson.DRAG:
			_slide_now(0, 2, 0)
			_art.win()
			_say("HTP_SB_DONE_CAP")
		Lesson.CUP:
			_slide_now(0, 1, 0)
			_art.win()
			_say("HTP_SB_BACK_CAP")
		_:
			_slide_now(0, 2, 0)
			_slide_now(1, 0, 1)
			_art.win()
			_say("HTP_SB_DONE_CAP")
	_art._refresh()

## Piece `p` slid from peg `from` to `to` at once, through the board's own
## input.
func _slide_now(p: int, from: int, to: int) -> void:
	_button(p, float(from), true)
	_drag_to(1.0, p, float(from), float(to))
	_button(p, float(to), false)
	_lift()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(p: int, s: float) -> void:
	_finger = _art.piece_at(p, s)
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(p: int, s: float, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.piece_at(p, s)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

## The finger `u` of the way from piece `p` at peg `a` to peg `b`, dragging.
func _drag_to(u: float, p: int, a: float, b: float) -> void:
	var at := _art.piece_at(p, lerpf(a, b, u))
	_finger = at
	_down = true
	var ev := InputEventMouseMotion.new()
	ev.position = at
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
