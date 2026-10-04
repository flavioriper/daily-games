extends Control

## One page of Hedgehogs' tutorial: a small autumn lawn played by the board
## itself. The page holds a `Board` -- hedgehogs2d.gd with its sounds, tip
## lines, toasts, streak, gags, breeze, party and out-of-hearts card taken
## out -- dealt one hand-made 5x4 lawn, and plays the lesson on a loop through
## the board's own input path (a press on a pile and its release, a press
## held for the flag, in board coordinates, as a finger would), over a
## caption that says what it means. So the rake is pulled across, the leaves
## blow off, numbers pop in, a flag drops and presses its pile down, a woken
## hedgehog curls up on a rose patch, a heart splits, the moon's bell rings
## and two piles snuffle alike, exactly as on the board. `lesson` picks the
## page (set before it enters the tree):
##
## - RAKE: a pile raked shows its number; a blank one blows its neighbours
##   clear.
## - FLAG: a 1 that touches one pile, and the pile held for a flag; a 2 that
##   touches two.
## - CHORD: a number whose hedgehogs are flagged, tapped, rakes the rest
##   round it -- twice.
## - WOKE: a guess between two piles wakes a hedgehog (a heart on Hard and
##   Insane).
## - WALK (Insane): three rakes light the moon's dots, the bell rings, and a
##   hedgehog walks; the two piles rustle alike and wear paw prints.
## - UNDO: a rake taken back by Undo, then Reset to the opening (Reset alone
##   on Insane, which has no Undo).
## - HINT: the bulb flags and pins a sleeper, then rakes a pile.
##
## The board checkup, 2026-10-02: Hedgehogs had only the shared one-page
## card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

enum Lesson { RAKE, FLAG, CHORD, WOKE, WALK, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How long a rake takes to play out, before the next tap.
const RAKE_WAIT := 1.2
## A press held this long plants a flag (the board's LONG_PRESS is 0.4).
const HOLD := 0.6

## The lawn, 5x4 (a pile is y * 5 + x), checked against the real rules
## (hedgehogs_state.gd): hedgehogs under 11, 12 and 19, the opening raked
## from 9. Its walk seed makes the third rake of WALK's line (10, 15, 16,
## with 11 and 12 flagged) send the hedgehog under 19 to 18 -- a step the
## board itself takes, one no raked number tells the way of.
##
##      .  .  .  .  .
##      1  2  2  1  .
##      #  H  H  2  1
##      #  #  #  #  H
const HOGS := [11, 12, 19]
const START := 9
const WALK_SEED := 2310537765
## FLAG: the 1 on 8 touches only 12; the 2 on 7 touches 11 and 12.
const ONE := 8
const TWO := 7
## CHORD: the 2 on 6 sees both flags and rakes 10; the 1 on 10 then rakes
## 15 and 16.
const CHORD_LINE := [6, 10]
## WOKE: the 1 on 14 has two piles beside it, 18 and 19; a guess at 19.
const GUESS_AT := 14
const GUESS := 19
## WALK: three rakes, then 17 after the walk.
const WALK_LINE := [10, 15, 16]
const AFTER_WALK := 17

var lesson: int = Lesson.RAKE
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
## no streak, gags, breeze or party, and a last heart lost never puts it to
## sleep -- the loop deals the lawn again.
class Board extends "res://puzzles/hedgehogs2d.gd":
	const Gen = preload("res://puzzles/hedgehogs_gen.gd")

	func puzzle_id() -> String:
		return "hedgehogs_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_key: String, _mood: int, _arg := "") -> void:
		pass

	func _on_safe_rake(_c: int, _lands: float) -> void:
		pass

	func _party(_lead: float) -> void:
		pass

	func _breeze(t: float) -> void:
		_next_breeze = t + 1000.0

	func _lose_heart(at: float) -> void:
		super(at)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Just a little lawn round the bed: the page is short.
	func _pad() -> float:
		return FRAME + 8.0

	## No row for the hearts over the tally: they hang beside the bed.
	func _top_h() -> float:
		return TALLY

	func _hearts_at(pill: Vector2) -> Vector2:
		var field := Vector2(_state.cols(), _state.rows()) * _cell
		return Vector2(maxf(pill.x * 0.5 + 6.0, _grid.x - FRAME - 24.0 - pill.x * 0.5), _grid.y + field.y * 0.5)

	## The lawn as the page deals it on band `b`: the opening raked, or
	## nothing when `p.bare`; `p.open` raked and `p.flags` flagged on top;
	## every heart; popped in with the board's entrance when `enter`.
	func lay(p: Dictionary, b: int, enter: bool) -> void:
		var g: Dictionary = Gen.blank(5, 4, HOGS.size())
		for h: int in HOGS:
			g.hog[h] = 1
		Gen.count(g)
		g.start = START
		_state.g = g
		_state.difficulty = b
		_state.dealt_hog = g.hog.duplicate()
		_state.walk_seed = WALK_SEED
		for a: PackedByteArray in [_state.open, _state.flag, _state.woke, _state.pin, _state.wrong]:
			a.resize(g.n)
			a.fill(0)
		_state.woken = 0
		_state.restart()
		if p.get("bare", false):
			_state.open.fill(0)
		for c: int in p.get("open", []):
			_state.open[c] = 1
		for c: int in p.get("flags", []):
			_state.flag[c] = 1
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_dealt()
		# No opening gust: the lawn is dealt as it stands.
		var now := _now()
		_blow_at.fill(-100.0)
		_until.fill(-100.0)
		_moving = {}
		_busy_until = now
		_anim_until = now
		_next_breeze = now + 1000.0
		_opened = now if enter else now - 10.0
		if enter and not Motion.reduce:
			_busy_until = _opened + Motion.ENTER_DELAY + Motion.ENTER_POP
		_tip_timer.stop()
		_refresh()
		_heart_layer.queue_redraw()
		_life_layer.queue_redraw()

	## Control-local centre of pile `c`.
	func square(c: int) -> Vector2:
		return _centre(c)

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

## The board as tall as the page leaves over the caption and the page's
## whole width: the board centres its own bed.
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

## The lawn each lesson starts from.
func _position() -> Dictionary:
	match lesson:
		Lesson.RAKE:
			return {"bare": true}
		Lesson.CHORD, Lesson.WALK:
			return {"flags": [11, 12]}
	return {}

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the lawn again without its entrance.
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
	# No band has hearts since 2026-10-04, so no page shows one splitting.
	var judged: bool = _art.State.hearts_for(band) > 0
	match lesson:
		Lesson.RAKE:
			_tap(13, "HTP_HH_TAP_CAP", "HTP_HH_COUNT_CAP", 2.2)
			_tap(0, "HTP_HH_BLANK_TAP_CAP", "HTP_HH_BLANK_CAP", 3.0)
		Lesson.FLAG:
			_point(ONE, "HTP_HH_ONE_CAP", 1.6)
			_hold(12, "HTP_HH_HOLD_CAP", 1.6)
			_point(TWO, "HTP_HH_TWO_CAP", 1.6)
			_hold(11, "", 1.4)
			_say_for("HTP_HH_SAFE_CAP", 2.4)
		Lesson.CHORD:
			_point(CHORD_LINE[0], "HTP_HH_FLAGGED_CAP", 1.4)
			_tap(CHORD_LINE[0], "", "HTP_HH_CHORD_CAP", 1.6)
			_tap(CHORD_LINE[1], "HTP_HH_AGAIN_CAP", "", 2.6)
		Lesson.WOKE:
			_point(GUESS_AT, "HTP_HH_GUESS_CAP", 1.8)
			_tap(GUESS, "", "HTP_HH_WOKE_HEART_CAP" if judged else "HTP_HH_WOKE_CAP", 2.8)
			_say_for("HTP_HH_ON_CAP", 1.8)
		Lesson.WALK:
			_tap(WALK_LINE[0], "HTP_HH_DOTS_CAP", "", RAKE_WAIT)
			_tap(WALK_LINE[1], "", "", RAKE_WAIT)
			_tap(WALK_LINE[2], "", "HTP_HH_BELL_CAP", 0.8)
			_say_for("HTP_HH_PAWS_CAP", 2.6)
			_tap(AFTER_WALK, "HTP_HH_STILL_CAP", "", 2.4)
		Lesson.UNDO:
			_tap(10, "HTP_HH_RAKE_CAP", "", RAKE_WAIT)
			if band < 3:
				_loop.tween_callback(_say.bind("HTP_HH_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_tap(10, "", "", RAKE_WAIT)
			_tap(15, "", "", RAKE_WAIT)
			_loop.tween_callback(_say.bind("HTP_HH_NIGHT_CAP" if band >= 3 else "HTP_HH_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_HH_HINT_CAP"))
			_loop.tween_interval(0.4)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(1.8)
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## The finger rests on pile `c` (a number being read) for `hold`, the
## caption turned to `key`.
func _point(c: int, key: String, hold: float) -> void:
	if key != "":
		_loop.tween_callback(_say.bind(key))
	_loop.tween_callback(func() -> void: _point_at(_art.square(c)))
	_loop.tween_interval(hold)
	_loop.tween_callback(_lift)

## The finger taps pile `c`: the caption turns to `before` as it comes, and
## to `after` once the rake is off; then it plays out for `wait`.
func _tap(c: int, before: String, after: String, wait := RAKE_WAIT) -> void:
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

## The finger holds pile `c` until the flag goes in, the caption turned to
## `key` as it comes; then it plays out for `wait`.
func _hold(c: int, key: String, wait: float) -> void:
	if key != "":
		_loop.tween_callback(_say.bind(key))
	_loop.tween_callback(func() -> void: _point_at(_art.square(c)))
	_loop.tween_interval(0.5)
	_loop.tween_callback(_button.bind(c, true))
	_loop.tween_interval(HOLD)
	_loop.tween_callback(_button.bind(c, false))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)
	_loop.tween_interval(wait)

## Every lesson back to its question: the lawn as dealt, every heart,
## nothing in flight. `fresh` is the first deal, which pops the lawn in with
## its entrance.
func _reset(fresh := false) -> void:
	_art.lay(_position(), band, fresh)
	_lift()
	_say({Lesson.RAKE: "HTP_HH_TAP_CAP", Lesson.FLAG: "HTP_HH_ONE_CAP",
		Lesson.CHORD: "HTP_HH_FLAGGED_CAP", Lesson.WOKE: "HTP_HH_GUESS_CAP",
		Lesson.WALK: "HTP_HH_DOTS_CAP", Lesson.UNDO: "HTP_HH_RAKE_CAP",
		Lesson.HINT: "HTP_HH_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's point, standing still.
func _still() -> void:
	match lesson:
		Lesson.RAKE:
			_tap_now(13)
			_tap_now(0)
			_say("HTP_HH_BLANK_CAP")
		Lesson.FLAG:
			_art._act(12, _art.State.FLAG)
			_art._act(11, _art.State.FLAG)
			_say("HTP_HH_SAFE_CAP")
		Lesson.CHORD:
			_tap_now(CHORD_LINE[0])
			_say("HTP_HH_CHORD_CAP")
		Lesson.WOKE:
			_tap_now(GUESS)
			_say("HTP_HH_WOKE_HEART_CAP" if _art.State.hearts_for(band) > 0 else "HTP_HH_WOKE_CAP")
		Lesson.WALK:
			for c: int in WALK_LINE:
				_tap_now(c)
			_say("HTP_HH_PAWS_CAP")
		Lesson.UNDO:
			_tap_now(10)
			_say("HTP_HH_RESET_CAP" if band < 3 else "HTP_HH_NIGHT_CAP")
		Lesson.HINT:
			_art.hint()
			_say("HTP_HH_HINT_CAP")
	_art._refresh()

## Pile `c` tapped at once, through the board's own input.
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
