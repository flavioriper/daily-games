extends Control

## One page of Marigold's tutorial: a few rows of the garden played by the
## board itself. The page holds a `Garden` -- marigold2d.gd with its sounds,
## tip lines, toasts, stickers, band, party and out-of-hearts card taken out
## and its view zoomed onto the rows the lesson needs -- laid with a
## hand-made garden, and plays the lesson on a loop through the board's own
## input path (a press by the sun, a drag that turns the aim, a release),
## over a caption that says what it means. So the guide follows the finger,
## the seed bounces, every bud it touches blooms and is picked, a clover
## splits the seed, the pot sends it back, the last marigold brings the full
## bloom, a lonely sweetheart folds back, exactly as on the board. The shots
## are found ahead (tests/_mg_tut_search.gd scanned each garden's fan for a
## wide run of angles giving the shot): the board's physics is pure data at
## a fixed step, so an angle plays the same shot every time. `lesson` picks
## the page (set before it enters the tree):
##
## - AIM: drag from the sun to aim, let go: the seed blooms what it touches.
## - GOAL: the last marigold: a near miss, then the full bloom.
## - CLOVER: a clover splits the seed in two; the violet moves after a shot.
## - POT: a seed that lands in the sliding pot comes back.
## - OUT: out of seeds, the garden grows back (a heart on Hard and Insane).
## - SWEET (Insane): a marigold alone folds back; a pair blooms together.
## - UNDO: Undo takes the shot back (a heart on Hard and Insane), Reset grows
##   the garden back.
## - HINT: the bulb finds a line and shows it the whole way.
##
## The board checkup, 2026-10-02: Marigold had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/marigold_state.gd")

enum Lesson { AIM, GOAL, CLOVER, POT, OUT, SWEET, UNDO, HINT }

const FINGER_R := 3.2
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## How far down its aim from the sun the finger presses and lets go, in
## field units.
const REACH := 16.0
## How long the finger takes to swing the aim to the shot.
const SWING := 0.9

## The gardens: staggered rows (the board's own field, Gen's "staggered
## rows" figure) across the top of the field under the sun, or across the
## foot over the pot; buds named by [row, column] are made marigolds,
## clovers or a pair of sweethearts. The view is the band of field units the
## page shows.
const TOP_ROWS := [22.0, 30.0, 38.0, 46.0, 54.0]
const FOOT_ROWS := [92.0, 100.0, 108.0, 116.0, 124.0]
const GARDENS := {
	"aim": {"rows": TOP_ROWS, "orange": [[1, 2], [2, 6], [3, 4], [0, 8]]},
	"goal": {"rows": TOP_ROWS, "orange": [[2, 4]]},
	"clover": {"rows": TOP_ROWS, "orange": [[3, 1], [3, 7]], "green": [[0, 4]]},
	"sweet": {"rows": TOP_ROWS, "pairs": [[[1, 2], [2, 5]]], "orange": []},
	"pot": {"rows": FOOT_ROWS, "orange": [[0, 1]]},
}

var lesson: int = Lesson.AIM
## The band the board behind the page is on.
var band := 0

var _art: Garden
var _over: Control
var _caption: Label
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, toasts or
## stickers, no band over the field, no party or out-of-hearts card, and the
## view zoomed onto the lesson's rows.
class Garden extends "res://puzzles/marigold2d.gd":
	## The field units the page shows.
	var view := Rect2(0.0, 0.0, State.W, 60.0)

	## Lays garden `name` into state `s` on band `b`: its buds, kinds and pairs,
	## the band's pot and seeds, the violet where the board's dice put it.
	static func lay_state(s, name: String, b: int) -> void:
		var g: Dictionary = GARDENS[name]
		var rows: Array = g.rows
		s.band = b
		s.pos = PackedVector2Array()
		s.kind0 = PackedInt32Array()
		s.pair = PackedInt32Array()
		var at := {}
		for r in rows.size():
			var odd := r % 2 == 1
			var c := 0
			var x := 14.5 if odd else 10.0
			while x <= 91.0:
				at[Vector2i(r, c)] = s.pos.size()
				s.pos.append(Vector2(x, float(rows[r])))
				s.kind0.append(State.BLUE)
				s.pair.append(-1)
				x += 9.0
				c += 1
		for rc: Array in g.get("orange", []):
			s.kind0[at[Vector2i(rc[0], rc[1])]] = State.ORANGE
		for rc: Array in g.get("green", []):
			s.kind0[at[Vector2i(rc[0], rc[1])]] = State.GREEN
		s.sweethearts = g.has("pairs")
		for pr: Array in g.get("pairs", []):
			var i: int = at[Vector2i(pr[0][0], pr[0][1])]
			var j: int = at[Vector2i(pr[1][0], pr[1][1])]
			s.kind0[i] = State.ORANGE
			s.kind0[j] = State.ORANGE
			s.pair[i] = j
			s.pair[j] = i
		# one pot for every band, so the pot lesson's shot lands in it
		s.pot_w = POT_W
		s._purple_seed = 3
		s.tries = 1
		s.proof = []
		s._grid()
		s._begin()

	func puzzle_id() -> String:
		return "marigold_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _voice(_cue_name: String, _loop: bool) -> AudioStreamPlayer:
		var p := AudioStreamPlayer.new()
		add_child(p)
		return p

	func _s() -> float:
		if size.x <= 0.0 or view.size.y <= 0.0:
			return 0.0
		return minf(size.x / view.size.x, size.y / view.size.y)

	func _origin() -> Vector2:
		return size * 0.5 - (view.position + view.size * 0.5) * _s()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _tell(_key: String, _mood: int, _args: Array = []) -> void:
		pass

	func _sticker(_text: String, _at: Vector2, _px: int, _life: float, _rainbow := true, _col := Color.WHITE, _rays := false, _id := "") -> void:
		pass

	func _draw_hud(_t: float, _xf: Transform2D, _tint: Color, _shown: Array) -> void:
		pass

	## The bloom counter would sit on the top row in this view.
	func _draw_count(_t: float, _xf: Transform2D, _seen: float) -> void:
		pass

	func _party() -> void:
		pass

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	## Let go anywhere to shoot: the page has no band to put the aim down on.
	func _release(_local: Vector2) -> void:
		if not _aiming:
			return
		_aiming = false
		_shoot()

	## Garden `name` laid on band `b`, every heart back, popped in with the
	## board's entrance when `enter`; `seeds` overrides the band's handful.
	func lay(name: String, b: int, enter: bool, seeds := -1) -> void:
		_close_card()
		lay_state(_state, name, b)
		if seeds >= 0:
			_state.seeds = seeds
		view = Rect2(0.0, 76.0, State.W, 64.0) if name == "pot" else Rect2(0.0, 0.0, State.W, 62.0)
		max_hearts = State.hearts_for(b)
		hearts = max_hearts
		out_of_hearts = false
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_lost_ever = false
		_won = false
		_split_index = -1
		_back_index = -1
		_streak = 0
		_reset_party()
		modulate = Color.WHITE
		_looks = null
		_opened = _now() if enter else _now() - 10.0
		_fresh(_opened if enter else _opened - 10.0)
		_log = ""
		_layout()

	## Control-local point `reach` field units down the aim `a` from the sun.
	func aim_point(a: float, reach: float) -> Vector2:
		return _pt(State.SUN_C + State.aim_dir(a) * reach)

	## Whether a shot is still being played or picked.
	func playing() -> bool:
		return _phase != "aim"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Garden.new()
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

## Each lesson's shots, found by tests/_mg_tut_search.gd: the middle of a
## wide run of angles that all give the same shot.
## The garden is chaotic -- no run of angles giving one shot is wider
## than a few thousandths of a radian -- so a lesson plays its exact angle,
## with the pot put at POT_X as the seed leaves (a seed off its rim can fly
## back up into the buds). Checked on every band (one pot width for all).
##
## AIM (and UNDO's first): fifteen blooms, two of them marigolds.
const AIM_SHOT := 1.72
## GOAL: one bluebell, then the last marigold and the full bloom.
const GOAL_MISS := 1.424
const GOAL_HIT := 0.762
## CLOVER: the clover first, the seed split, the violet among the blooms.
const CLOVER_SHOT := 1.882
## POT: two bluebells on the way down and into the pot (anywhere from 58
## to 71 along the foot catches it).
const POT_SHOT := 0.795
const POT_CATCH := 65.0
const POT_X := 50.0
const POT_W := 15.0
## OUT: the last seed blooms one bluebell.
const OUT_SHOT := 1.424
## SWEET: one sweetheart alone (it folds back), then both and the full bloom.
const SWEET_ONE := 0.762
const SWEET_BOTH := 1.441
## UNDO's second shot, from the garden as Undo left it.
const UNDO_AGAIN := 0.762

## Bumped to stop the lesson's loop (a page turned away, a new start).
var _gen := 0
var _clock: Timer

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

var _running := false

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
		if not await _wait(1.6, gen):
			return
		var ok := true
		match lesson:
			Lesson.AIM:
				ok = await _shot(AIM_SHOT, "HTP_MG_AIM_CAP", "HTP_MG_BLOOM_CAP", gen)
				_say("HTP_MG_PICK_CAP")
			Lesson.GOAL:
				ok = await _shot(GOAL_MISS, "HTP_MG_GOAL_CAP", "", gen)
				if ok:
					_say("HTP_MG_CLOSE_CAP")
					ok = await _wait(1.0, gen)
				if ok:
					ok = await _shot(GOAL_HIT, "", "HTP_MG_FULL_CAP", gen)
			Lesson.CLOVER:
				ok = await _shot(CLOVER_SHOT, "HTP_MG_CLOVER_CAP", "", gen)
				_say("HTP_MG_VIOLET_CAP")
			Lesson.POT:
				ok = await _shot(POT_SHOT, "HTP_MG_POT_CAP", "", gen, POT_CATCH)
				_say("HTP_MG_BACK_CAP")
			Lesson.OUT:
				ok = await _shot(OUT_SHOT, "HTP_MG_LAST_CAP", "", gen)
				if ok:
					_say("HTP_MG_OUT_HEART_CAP" if band >= 2 else "HTP_MG_OUT_CAP")
					ok = await _settle(gen)
				if ok:
					_say("HTP_MG_REGROW_CAP")
			Lesson.SWEET:
				ok = await _shot(SWEET_ONE, "HTP_MG_SWEET_CAP", "", gen)
				if ok:
					_say("HTP_MG_FOLD_CAP")
					ok = await _wait(1.4, gen)
				if ok:
					ok = await _shot(SWEET_BOTH, "HTP_MG_PAIR_CAP", "", gen)
					_say("HTP_MG_STAY_CAP")
			Lesson.UNDO:
				ok = await _shot(AIM_SHOT, "HTP_MG_AIM_CAP", "", gen)
				if ok:
					_say("HTP_MG_UNDO_HEART_CAP" if band >= 2 else "HTP_MG_UNDO_CAP")
					ok = await _wait(0.9, gen)
				if ok:
					_art.undo()
					ok = await _wait(1.6, gen)
				if ok:
					ok = await _shot(UNDO_AGAIN, "", "", gen)
				if ok:
					_say("HTP_MG_RESET_HEART_CAP" if band >= 2 else "HTP_MG_RESET_CAP")
					ok = await _wait(0.9, gen)
				if ok:
					_art.reset_board()
			Lesson.HINT:
				_say("HTP_MG_HINT_CAP")
				_art.hint()
				ok = await _wait(1.2, gen)
				while ok and not _art._think.is_empty():
					ok = await _wait(0.1, gen)
				if ok:
					_say("HTP_MG_LINE_CAP")
					ok = await _wait(1.6, gen)
				if ok:
					ok = await _shot(_art._aim, "", "", gen)
		if not ok or not await _wait(2.4, gen):
			return

## Waits `seconds`; false when the lesson has been stopped meanwhile.
func _wait(seconds: float, gen: int) -> bool:
	_clock.start(seconds)
	await _clock.timeout
	return gen == _gen and is_inside_tree()

## Waits for the shot to be over: the blooms picked, the garden back for the
## next aim (or grown back, or in its full bloom).
func _settle(gen: int) -> bool:
	while _art.playing() and _art._phase not in ["won", "asleep"]:
		if not await _wait(0.1, gen):
			return false
	return true

## The finger presses by the sun, swings the aim to `a` (the caption turning
## to `press`), lets go (the caption turning to `shot`) and the shot plays
## out. The sliding pot is put at `pot_x` as the seed leaves.
func _shot(a: float, press: String, shot: String, gen: int, pot_x := POT_X) -> bool:
	if press != "":
		_say(press)
	if not Rect2(Vector2.ZERO, _art.size).has_point(_art.aim_point(a, REACH)):
		# the sun is off the page (the pot's rows): the seed just falls in
		if not await _wait(0.8, gen):
			return false
		_art._aim = a
		_art._state.pot_x = pot_x
		_art._state.pot_dir = 1.0
		if shot != "":
			_say(shot)
		_art._shoot()
		return await _settle(gen)
	var from: float = _art._aim
	_finger = _art.aim_point(from, REACH)
	_down = false
	if not await _wait(0.45, gen):
		return false
	_button(true, _art.aim_point(from, REACH))
	var steps := 18
	for k in steps:
		if not await _wait(SWING / float(steps), gen):
			return false
		var u := float(k + 1) / float(steps)
		_motion(_art.aim_point(lerp_angle(from, a, u * u * (3.0 - 2.0 * u)), REACH))
	if not await _wait(0.35, gen):
		return false
	# the swing turns the aim to a pixel; the shot was found at an exact angle
	_art._aim = a
	_art._guide = null
	_art._state.pot_x = pot_x
	_art._state.pot_dir = 1.0
	if shot != "":
		_say(shot)
	_button(false, _art.aim_point(a, REACH))
	_lift()
	return await _settle(gen)

## Every lesson back to its question: the garden as laid, every heart,
## nothing in flight. `fresh` is the first deal, popped in with the board's
## entrance.
func _reset(fresh := false) -> void:
	var name := "aim"
	var seeds := -1
	match lesson:
		Lesson.GOAL:
			name = "goal"
		Lesson.CLOVER:
			name = "clover"
		Lesson.POT:
			name = "pot"
		Lesson.SWEET:
			name = "sweet"
		Lesson.OUT:
			seeds = 1
	_art.lay(name, band, fresh, seeds)
	_lift()
	_say({Lesson.AIM: "HTP_MG_AIM_CAP", Lesson.GOAL: "HTP_MG_GOAL_CAP", Lesson.CLOVER: "HTP_MG_CLOVER_CAP",
		Lesson.POT: "HTP_MG_POT_CAP", Lesson.OUT: "HTP_MG_LAST_CAP", Lesson.SWEET: "HTP_MG_SWEET_CAP",
		Lesson.UNDO: "HTP_MG_AIM_CAP", Lesson.HINT: "HTP_MG_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's question with its shot's guide, standing still.
func _still() -> void:
	var a: float = {Lesson.AIM: AIM_SHOT, Lesson.GOAL: GOAL_HIT, Lesson.CLOVER: CLOVER_SHOT, Lesson.POT: POT_SHOT,
		Lesson.OUT: OUT_SHOT, Lesson.SWEET: SWEET_BOTH, Lesson.UNDO: AIM_SHOT, Lesson.HINT: AIM_SHOT}[lesson]
	_art._aim = a
	_art._aim_shown = a
	_art._guide = null
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
	var s: float = _art._s()
	if _finger.x < 0.0 or s <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _art.position + _finger + Vector2(s * 0.6, s * 0.7)
	var r := s * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
