extends Control

## One page of Bridges' tutorial: a little sea of its own, five by five,
## played by the board itself. The page holds a `Sea` -- bridges2d.gd with
## its sounds, tip lines, streak, gags, party and out-of-hearts card taken
## out -- dealt by hand, and plays the lesson on a loop through the board's
## own input path (a press on an islet, a drag to the one it faces, the
## release; a tap on a bridge's water), over a caption that says what it
## means. So a plank rolls out and lands, a ring of slots fills, a met islet
## turns green and raises its pennant, a crossing drag is refused with the
## run in the way flashing, the network lights gold, and a wrong plank on a
## judged band cracks, sinks and leaves its buoy exactly as on the board.
## `lesson` picks the page (set before it enters the tree):
##
## - NUMBERS: two planks from one islet to the islet it faces, its ring
##   filling, and both islets met.
## - CROSS: a drag across a laid run is refused.
## - NETWORK: two groups, the loose one pulsing; the last plank joins them
##   and the network lights up.
## - OVER (Easy, Medium): a plank too many turns an islet rose, Check marks
##   the bridge, and taps on its water step it to two planks and then none.
## - HEARTS (Hard, Insane): a wrong plank sinks, costs a heart and leaves a
##   buoy.
## - LANTERNS (Insane): a lantern counts the islets joined to it, not planks.
## - UNDO: Undo lifts the last plank; Reset lifts them all.
## - HINT: the bulb lays one plank of the answer.
##
## The board checkup, 2026-10-02: Bridges had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/bridges_gen.gd")
const State = preload("res://puzzles/bridges_state.gd")

enum Lesson { NUMBERS, CROSS, NETWORK, OVER, HEARTS, LANTERNS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## Air round the pool on the page.
const EDGE := 10.0
## How long a drag takes from islet to islet.
const DRAG_TIME := 0.5
const N := 5

## The sea most lessons play on, as islet -> its number, and the answer as
## [a, b, planks]: a ring round the edge with a run down the middle, so the
## middle row's lane crosses it (the CROSS lesson's), and G-F the one plank
## that joins the two bottom-left islets to the rest (NETWORK's).
const A := Vector2i(0, 0)
const B := Vector2i(2, 0)
const C := Vector2i(4, 0)
const D := Vector2i(0, 2)
const E := Vector2i(4, 2)
const F := Vector2i(0, 4)
const G := Vector2i(2, 4)
const H := Vector2i(4, 4)
const SEA := {A: 2, B: 4, C: 2, D: 2, E: 3, F: 3, G: 3, H: 3}
const ANSWER := [[A, B, 2], [B, C, 1], [C, E, 1], [E, H, 2], [H, G, 1], [G, F, 1], [F, D, 2], [B, G, 1]]
## Lantern Night's: a lantern in the middle wanting two friends, one islet
## above it wanting two planks and one beside it wanting one.
const L := Vector2i(2, 2)
const X := Vector2i(2, 0)
const Y := Vector2i(4, 2)
const LANTERN_SEA := {L: 2, X: 2, Y: 1}
const LANTERN_ANSWER := [[L, X, 2], [L, Y, 1]]

var lesson: int = Lesson.NUMBERS
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: Sea
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags, streak,
## party or coach, and a last heart lost never puts it to sleep -- the loop
## deals the sea again. Its pool fills the page but for a thin edge.
class Sea extends "res://puzzles/bridges2d.gd":
	func puzzle_id() -> String:
		return "bridges_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _on_right(_key: String) -> void:
		pass

	func _gag(_cell: Vector2i) -> void:
		pass

	func _party(_after_wave: float) -> void:
		pass

	func _pick_coach() -> void:
		_coach_lane = ""

	func _wrong_plank(key: String, before: int, from: Vector2i) -> void:
		super(key, before, from)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	func _open_card() -> void:
		pass

	func _pool() -> Rect2:
		var row := _heart_row()
		return Rect2(EDGE, EDGE + row, maxf(0.0, size.x - 2.0 * EDGE),
			maxf(0.0, size.y - 2.0 * EDGE - row))

	func _hearts_y() -> float:
		return EDGE + HEART_ROW * 0.5

	## No ripple dashes: they are spaced in pixels for a pool a whole card
	## wide, and on the page's they bunch up in the middle.
	func _ripples(_b, _water: Rect2) -> void:
		pass

	## The sea as the page deals it: `need` (islet -> number), `answer` and
	## `laid` as [a, b, planks], `lights` the lanterns, judged as `b` is with
	## every heart of `h`, and popped in with the board's entrance when
	## `enter`.
	func lay(b: int, h: int, need: Dictionary, answer: Array, laid: Array, lights: Array,
			enter: bool) -> void:
		_gen += 1
		var st := State.new()
		st.band = b
		st.n = N
		st.islets = []
		for cell: Vector2i in need:
			st.islets.append(cell)
		st.need = need.duplicate()
		st.lanterns = {}
		for cell: Vector2i in lights:
			st.lanterns[cell] = true
		st.lanes = Gen.lanes_for(N, st.islets)
		st.crossing = Gen.crossings(st.lanes)
		for cell in st.islets:
			st._seat[cell] = true
		st.answer = {}
		for run: Array in answer:
			st.answer[Gen.lane_key(run[0], run[1])] = int(run[2])
		st.runs = {}
		for run: Array in laid:
			st.runs[Gen.lane_key(run[0], run[1])] = int(run[2])
		st.history = []
		st.ruled = {}
		state = st
		max_hearts = h
		hints_used = 0
		hints_extra = 0
		checks = 0
		moves = 0
		_done = false
		_running = true
		_begin()
		_tip_timer.stop()
		_groups = state.groups().size()
		if not enter:
			_opened = _now() - 10.0
			_anim_until = 0.0
			_next_lap = _now() + LAP_EVERY
		_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Sea.new()
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

## The sea as tall as the page leaves over the caption, as wide as it is
## tall (the lattice is square, and a wide pool only spends its slack on
## water), centred across the page.
func _layout() -> void:
	if _art == null:
		return
	var h := maxf(0.0, size.y - CAPTION_H)
	var w := minf(size.x, h + (HEART_ROW_FOR_PAGE if hearts > 0 else 0.0))
	_art.position = Vector2((size.x - w) * 0.5, 0.0)
	_art.size = Vector2(w, h)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

## A judged page's pool gives the hearts their strip over the water, so it
## is that much wider for the lattice to stay as large.
const HEART_ROW_FOR_PAGE := 64.0

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the sea again without its entrance.
	if _begun and _loop != null and _loop.is_valid():
		return
	Motion.stop(_loop)
	_reset(not _begun)
	_begun = true
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_interval(1.4)
	match lesson:
		Lesson.NUMBERS:
			_play_drag(A, B, "HTP_BR_DRAG_CAP")
			_loop.tween_interval(1.2)
			_play_drag(A, B, "HTP_BR_TWO_CAP")
			_loop.tween_interval(1.0)
			_say_for("HTP_BR_MET_CAP", 2.6)
		Lesson.CROSS:
			_play_drag(D, E, "")
			_loop.tween_interval(0.2)
			_say_for("HTP_BR_CROSS_CAP", 2.6)
		Lesson.NETWORK:
			_loop.tween_callback(_pulse_loose)
			_loop.tween_interval(1.6)
			_play_drag(G, F, "")
			_loop.tween_callback(func() -> void: _art._on_solved())
			_loop.tween_interval(0.6)
			_say_for("HTP_BR_ONE_CAP", 3.4)
		Lesson.OVER:
			_play_drag(D, E, "")
			_loop.tween_interval(0.4)
			_say_for("HTP_BR_OVER_CAP", 1.8)
			_loop.tween_callback(func() -> void: _art.check())
			_say_for("HTP_BR_CHECK_CAP", 2.2)
			_loop.tween_callback(_say.bind("HTP_BR_TAP_CAP"))
			_play_tap(D, E)
			_loop.tween_interval(0.9)
			_play_tap(D, E)
			_loop.tween_interval(1.8)
		Lesson.HEARTS:
			_play_drag(D, E, "")
			_loop.tween_interval(0.5)
			_say_for("HTP_BR_SINK_CAP", 1.8)
			_say_for("HTP_BR_BUOY_CAP", 2.6)
		Lesson.LANTERNS:
			_play_drag(L, X, "")
			_loop.tween_interval(0.8)
			_play_drag(L, X, "HTP_BR_LANTERN2_CAP")
			_loop.tween_interval(1.6)
			_play_drag(L, Y, "")
			_loop.tween_interval(0.6)
			_say_for("HTP_BR_LANTERN3_CAP", 2.6)
		Lesson.UNDO:
			_play_drag(A, B, "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_BR_UNDO_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.undo())
			_loop.tween_interval(1.4)
			_play_drag(A, B, "HTP_BR_LAY_CAP")
			_loop.tween_interval(0.5)
			_play_drag(G, H, "")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_BR_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.0)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(2.8)
	_loop.tween_callback(_reset)

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## A drag from islet `a` to islet `b`: the finger comes down on `a` (the
## caption turning to `say` when not ""), slides across the water to `b`
## through the board's own drag, and lets go there.
func _play_drag(a: Vector2i, b: Vector2i, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(a))
	_loop.tween_interval(0.35)
	_loop.tween_callback(_press.bind(a))
	_loop.tween_interval(0.15)
	_loop.tween_method(func(u: float) -> void: _slide(a, b, u), 0.0, 1.0, DRAG_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.1)
	_loop.tween_callback(_release.bind(b))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## A tap on the water of the lane from `a` to `b`, a cell along from `a`.
func _play_tap(a: Vector2i, b: Vector2i) -> void:
	var cell := a + Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	_loop.tween_callback(_point.bind(cell))
	_loop.tween_interval(0.35)
	_loop.tween_callback(_press.bind(cell))
	_loop.tween_interval(0.18)
	_loop.tween_callback(_release.bind(cell))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the sea as dealt with what the lesson
## starts from, every heart, nothing in flight. `fresh` is the first deal,
## which pops the sea in with the board's entrance.
func _reset(fresh := false) -> void:
	var h := hearts if lesson == Lesson.HEARTS else 0
	match lesson:
		Lesson.NUMBERS:
			_art.lay(band, h, SEA, ANSWER, [[B, C, 1], [B, G, 1]], [], fresh)
		Lesson.CROSS:
			_art.lay(band, h, SEA, ANSWER, [[B, G, 1], [B, C, 1]], [], fresh)
		Lesson.NETWORK:
			var laid := ANSWER.duplicate()
			laid.remove_at(5)   # G-F, the plank that joins them
			_art.lay(band, h, SEA, ANSWER, laid, [], fresh)
		Lesson.OVER, Lesson.HEARTS:
			_art.lay(band, h, SEA, ANSWER, [[F, D, 2]], [], fresh)
		Lesson.LANTERNS:
			_art.lay(band, h, LANTERN_SEA, LANTERN_ANSWER, [], [L], fresh)
		Lesson.UNDO, Lesson.HINT:
			_art.lay(band, h, SEA, ANSWER, [[B, C, 1], [B, G, 1]], [], fresh)
	_lift()
	_say({Lesson.NUMBERS: "HTP_BR_NUM_CAP", Lesson.CROSS: "HTP_BR_NOCROSS_CAP",
		Lesson.NETWORK: "HTP_BR_APART_CAP", Lesson.OVER: "HTP_BR_TOO_CAP",
		Lesson.HEARTS: "HTP_BR_JUDGED_CAP", Lesson.LANTERNS: "HTP_BR_LANTERN_CAP",
		Lesson.UNDO: "HTP_BR_LAY_CAP", Lesson.HINT: "HTP_BR_HINT_CAP"}[lesson])

## The loose group pulses, as the board pulses the groups a near-miss
## leaves apart.
func _pulse_loose() -> void:
	var t: float = _art._now()
	for cell: Vector2i in [D, F]:
		_art._pulse[cell] = t
	_art._busy_for(Bridges.SPLIT_PULSES * Bridges.SPLIT_BEAT + Motion.BUMP_TIME)
	_art._refresh()

const Bridges = preload("res://puzzles/bridges2d.gd")

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.NUMBERS:
			for k in 2:
				_art._move(_art.state.lane_at(A, B), A)
			_say("HTP_BR_MET_CAP")
		Lesson.CROSS:
			_say("HTP_BR_CROSS_CAP")
		Lesson.NETWORK:
			_art._move(_art.state.lane_at(G, F), G)
			_art._on_solved()
			_say("HTP_BR_ONE_CAP")
		Lesson.OVER:
			_art._move(_art.state.lane_at(D, E), D)
			_art.check()
			_say("HTP_BR_OVER_CAP")
		Lesson.HEARTS:
			_art._move(_art.state.lane_at(D, E), D)
			_say("HTP_BR_BUOY_CAP")
		Lesson.LANTERNS:
			for k in 2:
				_art._move(_art.state.lane_at(L, X), L)
			_say("HTP_BR_LANTERN2_CAP")
		Lesson.UNDO:
			_say("HTP_BR_UNDO_CAP")
		Lesson.HINT:
			_art.hint()
	_art._refresh()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _local(cell: Vector2i) -> Vector2:
	return _art.cell_to_local(cell.y, cell.x)

func _point(cell: Vector2i) -> void:
	_finger = _art.position + _local(cell)
	_down = false

func _press(cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _local(cell)
	_down = true
	_art._gui_input(ev)

func _slide(a: Vector2i, b: Vector2i, u: float) -> void:
	var at := _local(a).lerp(_local(b), u)
	_finger = _art.position + at
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

func _release(cell: Vector2i) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = _local(cell)
	_down = false
	_art._gui_input(ev)

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var at := _finger + Vector2(FINGER_R * 0.8, FINGER_R)
	var r := FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
