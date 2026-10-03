extends Control

## One page of One Line's tutorial: a small figure walked by the board itself.
## The page holds a `Walk` -- oneline2d.gd with its sounds, tip lines, gags,
## ladybugs, streak, solve and out-of-hearts card taken out -- dealt a little
## house of eight lines on six posts, and plays the lesson on a loop through
## the board's own input path (a press, motions, a release in board
## coordinates, as a finger would), over a caption that says what it means.
## So the snail stands on her post, a plank is laid behind her, a post
## shivers and a stranded line greys exactly as on the board. `lesson` picks
## the page (set before it enters the tree):
##
## - TRACE: a green post pressed and the whole figure walked in one drag.
## - START: a teal post refuses the stroke; a green one takes it.
## - ONCE: a drag back over a plank is refused; a stone line is taken.
## - STRAND: a step leaves a triangle behind. Without hearts it greys and
##   Undo takes the step back; with hearts (`hearts`, the band's count) it
##   costs one and the plank comes back up. Then the other way round.
## - HINT: the bulb shows where to begin, then walks a safe step.
## - SUN: Sunny Spells: a sunny line, a second refused, a dewy one between.
##
## The board checkup, 2026-10-02: One Line had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Gen = preload("res://puzzles/oneline_gen.gd")

enum Lesson { TRACE, START, ONCE, STRAND, HINT, SUN }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long the finger takes along one line.
const LINE_TIME := 0.42
## The house: posts 0 1 2 over 3 4 5, eight lines, posts 0 and 1 odd (green).
## Walked in this order from post 0 it is one stroke; its lines alternate
## sunny and dewy along it, so the same walk keeps Sunny Spells' rule.
const COLS := 3
const ROWS := 2
const WALK := [0, 3, 4, 0, 1, 2, 5, 4, 1]
## STRAND: round the outside first, which leaves the triangle 0-3-4 behind
## when the snail steps from 4 up to 1; then the right way from 4.
const ASTRAY := [0, 1, 2, 5, 4]
const HOME := [4, 0, 3, 4, 1]

var lesson: int = Lesson.TRACE
## STRAND: how many hearts the band has (Hard 3, Insane 1; 0 on Easy and
## Medium, where a stranded line greys instead).
var hearts := 0

var _art: Walk
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # board-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh

## The board, quiet: no sound set (its id names none), no tips, gags,
## ladybugs, streak or solve, and a last heart lost never puts it to sleep --
## the loop deals the figure again.
class Walk extends "res://puzzles/oneline2d.gd":
	func puzzle_id() -> String:
		return "oneline_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _gag(_e: int, _n: int) -> void:
		pass

	func _want_bug() -> void:
		pass

	func _on_right_step(_e: int, _n: int, _judged: bool) -> void:
		pass

	func _wrong_step(e: int, n: int) -> void:
		super(e, n)
		out_of_hearts = false

	func _run_out() -> void:
		pass

	## The house, as the page deals it: nothing walked, every heart, and the
	## figure popped in with the board's entrance when `enter`.
	func lay(sunny: Array, h: int, enter: bool) -> void:
		_stop_all()
		var edges: Array = []
		for k in WALK.size() - 1:
			edges.append(Vector2i(mini(WALK[k], WALK[k + 1]), maxi(WALK[k], WALK[k + 1])))
		var nodes: Array = [0, 1, 2, 3, 4, 5]
		state.band = 0
		state.cols = COLS
		state.rows = ROWS
		state.load_figure(edges, nodes, Gen.odd_nodes(edges, nodes), sunny)
		state.reset()
		max_hearts = h
		hints_used = 0
		_deal()
		_stroke = {}
		_post_press = {}
		_post_hop = {}
		_cap_bump = {}
		_post_shiver = {}
		_post_blush = {}
		_wrong = {}
		_bright = {}
		_warm = {}
		_gone = []
		_walker_out = -100.0
		_joy = false
		_drawing = false
		_pressed_post = -1
		_solved_at = -1.0
		_done = false
		_running = true
		_layout()
		if enter:
			_enter()
		else:
			_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Walk.new()
	add_child(_art)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.z_index = 3
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
	_art.size = Vector2(size.x, maxf(0.0, size.y - 96.0))
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

## The house's lines sunny on the SUN page, each other one along the walk.
func _sunny() -> Array:
	if lesson != Lesson.SUN:
		return []
	var out: Array = []
	for k in WALK.size() - 1:
		out.append(k % 2 == 0)
	return out

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
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
		Lesson.TRACE:
			_play_walk(WALK, "HTP_OL_PRESS_CAP", "HTP_OL_DRAG_CAP")
			_loop.tween_callback(_say.bind("HTP_OL_DONE_CAP"))
			_loop.tween_callback(_cheer)
			_loop.tween_interval(2.6)
		Lesson.START:
			_play_tap(4, "HTP_OL_TEAL_CAP")
			_loop.tween_interval(1.4)
			_play_tap(2, "")
			_loop.tween_interval(1.2)
			_play_tap(0, "HTP_OL_GREEN_CAP")
			_loop.tween_interval(2.4)
		Lesson.ONCE:
			_play_walk([0, 3, 4, 3], "HTP_OL_PRESS_CAP", "", {3: "HTP_OL_BACK_CAP"})
			_loop.tween_interval(1.6)
			_play_walk([4, 0, 1], "HTP_OL_ON_CAP", "")
			_loop.tween_interval(2.2)
		Lesson.STRAND:
			_play_walk(ASTRAY + [1], "HTP_OL_START_CAP", "", {5: "HTP_OL_CORNER_CAP"})
			_loop.tween_interval(0.5)
			if hearts > 0:
				_loop.tween_callback(_say.bind("HTP_OL_HEART_CAP"))
				_loop.tween_interval(2.4)
			else:
				_loop.tween_callback(_say.bind("HTP_OL_LOST_CAP"))
				_loop.tween_interval(1.8)
				_loop.tween_callback(_art.undo)
				_loop.tween_interval(1.0)
			_play_walk(HOME, "HTP_OL_OTHER_CAP", "")
			_loop.tween_callback(_say.bind("HTP_OL_DONE_CAP"))
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_say.bind("HTP_OL_HINT_CAP"))
			_loop.tween_interval(0.4)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(1.8)
			_loop.tween_callback(_say.bind("HTP_OL_HINT_STEP_CAP"))
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(1.4)
			_loop.tween_callback(_art.hint)
			_loop.tween_interval(2.2)
		Lesson.SUN:
			_play_walk([0, 4, 5], "HTP_OL_SUN_CAP", "", {2: "HTP_OL_DRY_CAP"})
			_loop.tween_interval(1.4)
			_play_walk([4, 3], "HTP_OL_DEW_CAP", "")
			_loop.tween_interval(2.4)
	_loop.tween_callback(_reset)

## The finger presses post `walk[0]` and drags along the rest of `walk`
## without lifting, the caption turning to `press` on the press, `drag` once
## it moves and `at[k]` as it sets off toward walk[k].
func _play_walk(walk: Array, press: String, drag: String, at := {}) -> void:
	if press != "":
		_loop.tween_callback(_say.bind(press))
	_loop.tween_callback(_point.bind(int(walk[0])))
	_loop.tween_interval(0.4)
	_loop.tween_callback(_button.bind(int(walk[0]), true))
	_loop.tween_interval(0.35)
	if drag != "":
		_loop.tween_callback(_say.bind(drag))
	for k in range(1, walk.size()):
		if at.has(k):
			_loop.tween_callback(_say.bind(at[k]))
		_loop.tween_method(_drag_to.bind(int(walk[k - 1]), int(walk[k])), 0.0, 1.0, LINE_TIME)
		_loop.tween_interval(0.12)
	_loop.tween_interval(0.2)
	_loop.tween_callback(_button.bind(int(walk[-1]), false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## A tap on post `n`: the finger comes down, the caption turns to `say` (when
## not ""), and the finger lets go.
func _play_tap(n: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_point.bind(n))
	_loop.tween_interval(0.45)
	_loop.tween_callback(_button.bind(n, true))
	_loop.tween_interval(0.2)
	_loop.tween_callback(_button.bind(n, false))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)

## Every lesson back to its question: the house unwalked, every heart,
## nothing in flight. `fresh` is the first deal, which pops the figure in
## with the board's entrance.
func _reset(fresh := false) -> void:
	_art.lay(_sunny(), hearts if lesson == Lesson.STRAND else 0, fresh)
	_lift()
	_say("HTP_OL_SUN_CAP" if lesson == Lesson.SUN else "HTP_OL_START_CAP")

## The whole figure walked: the snail grins.
func _cheer() -> void:
	_art._joy = true
	_art._refresh()

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	match lesson:
		Lesson.START:
			_art._take(0)
			_say("HTP_OL_GREEN_CAP")
		Lesson.HINT:
			_art.hint()
			_art.hint()
			_say("HTP_OL_HINT_STEP_CAP")
		Lesson.SUN:
			for n in [0, 3, 4]:
				_art._take(n)
			_say("HTP_OL_DEW_CAP")
		Lesson.STRAND:
			# The still shows the figure walked the right way round; the
			# page's body says what a stranding step does.
			for n in ASTRAY + HOME.slice(1):
				_art._take(n)
			_say("HTP_OL_OTHER_CAP")
		_:
			for n in WALK:
				_art._take(n)
			_art._joy = true
			_say("HTP_OL_DONE_CAP")
	_art._drawing = false
	_art._release_post()
	_art._refresh()

func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

func _point(n: int) -> void:
	_finger = _art.node_to_local(n)
	_down = false

func _lift() -> void:
	_finger = Vector2(-1.0, -1.0)
	_down = false

func _button(n: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _art.node_to_local(n)
	_finger = ev.position
	_down = pressed
	_art._gui_input(ev)

## The finger `u` of the way from post `a` to post `b`, dragging. (A board
## that has let the finger go -- a stranding step on a band with hearts --
## takes no motion, as it would take none from a player.)
func _drag_to(u: float, a: int, b: int) -> void:
	var at: Vector2 = _art.node_to_local(a).lerp(_art.node_to_local(b), u)
	_finger = at
	_down = true
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

# --- drawing ---

func _draw_finger() -> void:
	if _finger.x < 0.0 or _art._step <= 0.0:
		_finger_shown = null
		return
	var b := Face.Builder.new()
	var cell: float = _art._step * 0.6
	var at := _art.position + _finger + Vector2(cell * 0.18, cell * 0.22)
	var r := cell * FINGER_R * (0.85 if _down else 1.0)
	b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
	b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	_finger_shown = b.mesh()
	_over.draw_mesh(_finger_shown, null)
