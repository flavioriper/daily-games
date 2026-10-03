extends Control

## One page of Quilt's tutorial: a little quilt of its own, four by three,
## played by the board itself. The page holds a `Patchwork` -- quilt2d.gd
## with its sounds, tip lines, coach, streak, gags, party and out-of-hearts
## card taken out -- dealt by hand, and plays the lesson on a loop through
## the board's own input path (a press on a patch, a drag, the release), over
## a caption that says what it means. So a patch grows as it lifts, its ghost
## shows where it will land, it glides down and sews its seams, a patch held
## over another wears the rose halo and flies home, and a wrong patch on a
## judged band snaps its stitch and flutters home exactly as on the board.
## `lesson` picks the page (set before it enters the tree):
##
## - FILL: two patches dragged from the rack onto the quilt, each sewing its
##   seams, and the last square covered lights the quilt.
## - FIT: a patch held over another is refused (rose halo) and goes home; it
##   goes on where it fits, as it is drawn -- patches never turn.
## - OFF (Easy, Medium): a sewn patch dragged off the quilt goes home.
## - HEARTS (Hard, Insane): a wrong patch snaps its stitch and costs a heart,
##   and the spot it tried is chalked.
## - SCRAPS (Insane): the basket holds a scrap the quilt does not need.
## - UNDO: Undo takes the last patch back (Easy, Medium); Reset sends every
##   patch home.
## - HINT: the bulb sews one patch of the answer.
##
## The board checkup, 2026-10-02: Quilt had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const State = preload("res://puzzles/quilt_state.gd")

enum Lesson { FILL, FIT, OFF, HEARTS, SCRAPS, UNDO, HINT }

## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 20.0
const FINGER_ALPHA := 0.16
const CAPTION_H := 92.0
## Air round the card on the page.
const EDGE := 10.0
## How long a drag takes from the rack to the quilt.
const DRAG_TIME := 0.7

## The quilt every lesson plays on, four by three, and its four patches:
##
##     A A B B
##     A C C B
##     D D C B
##
## as [shape, answer origin], plus Scrap Basket's scrap, a bar three tall
## that the quilt has no room for.
const COLS := 4
const ROWS := 3
const PA := 0
const PB := 1
const PC := 2
const PD := 3
const PS := 4
const SHAPES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)],
]
## Origins as cell indices (row * COLS + column); the scrap's is -1.
const ANSWER := [0, 2, 5, 8, -1]
## Where D is held over A (refused), and the right-shaped wrong spot D tries
## on a judged band.
const OVER_A := 0
const WRONG_D := 5

var lesson: int = Lesson.FILL
## The band the board behind the page is on, and its hearts.
var band := 0
var hearts := 0

var _art: Patchwork
var _over: Control
var _caption: Label
var _loop: Tween
var _begun := false
var _finger := Vector2(-1.0, -1.0)   # page-local; x < 0 is no finger
var _down := false
var _finger_shown: ArrayMesh
## Where the press of the drag in progress came down, in the card's space.
var _press_at := Vector2.ZERO

## The board, quiet: no sound set (its id names none), no tips, coach, gags,
## streak or party, and a last heart lost never puts it to sleep -- the loop
## deals the quilt again. Its card fills the page but for a thin edge.
class Patchwork extends "res://puzzles/quilt2d.gd":
	func puzzle_id() -> String:
		return "quilt_tutorial"

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx.buzzes = false  # (the page's finger is not the player's)
		_tip_timer.stop()

	func check_solved() -> void:
		pass

	func _say(_text: String, _mood: int) -> void:
		pass

	func _speak(_line: String, _mood: int) -> void:
		pass

	func _on_good_drop(_p: int) -> void:
		pass

	func _party() -> void:
		pass

	func _pick_coach() -> void:
		_coach_patch = -1
		_coach_origin = -1

	func _wrong_patch(p: int, origin: int, hand: Vector2) -> void:
		super(p, origin, hand)
		out_of_hearts = false
		_running = true

	func _run_out() -> void:
		pass

	func _content() -> Rect2:
		return Rect2(Vector2.ONE * EDGE, size - Vector2.ONE * (2.0 * EDGE))

	func _hearts_y() -> float:
		return EDGE + HEART_ROW * 0.5

	## Side by side on the page, which is wide and short where the board's
	## card is tall: the quilt on the left (with room on its right for the
	## label) and the rack on the right.
	func _field_box() -> Rect2:
		var box := _content()
		var row := _heart_row()
		return Rect2(box.position + Vector2(0.0, row),
			Vector2(box.size.x * FIELD_SIDE - TAG_SIZE.x - TAG_GAP, maxf(0.0, box.size.y - row)))

	func _rack_box() -> Rect2:
		var box := _content()
		var row := _heart_row()
		var x := box.position.x + box.size.x * FIELD_SIDE + MAT_PAD
		return Rect2(Vector2(x, box.position.y + row + MAT_PAD),
			Vector2(box.end.x - MAT_PAD - x, maxf(0.0, box.size.y - row - 2.0 * MAT_PAD)))

	## The quilt as the page deals it: the first `count` of SHAPES, the ones
	## in `sewn` already on, judged as `b` is with every heart of `h`, and
	## popped in with the board's entrance when `enter`.
	func lay(b: int, h: int, count: int, sewn: Array, enter: bool) -> void:
		_gen += 1
		var st := State.new()
		st.band = b
		st.cols = COLS
		st.rows = ROWS
		st.region = PackedByteArray()
		st.region.resize(COLS * ROWS)
		st.region.fill(1)
		st.quilt_cells = COLS * ROWS
		st.shapes = []
		st.answer = PackedInt32Array()
		for p in count:
			st.shapes.append(SHAPES[p].duplicate())
			st.answer.append(int(ANSWER[p]))
		st.ok = true
		st.at = PackedInt32Array()
		st.at.resize(count)
		st.at.fill(-1)
		for p: int in sewn:
			st.at[p] = int(ANSWER[p])
		st.locked = PackedByteArray()
		st.locked.resize(count)
		st.history = []
		st.ruled = {}
		st.recompute()
		st._assign_cloths()
		_state = st
		max_hearts = h
		hints_used = 0
		hints_extra = 0
		moves = 0
		_done = false
		_running = true
		_heart_used = false
		_lost_ever = false
		_stuck_ever = false
		_drag = {}
		_flying = {}
		_landed = {}
		_lifted = {}
		_glide = {}
		_refused = {}
		_pending = []
		_anim_until = 0.0
		_solved_at = -1.0
		_reset_rewards()
		_shape_cache()
		_deal()
		_layout()
		_enter()
		_pick_coach()
		_tip_timer.stop()
		if not enter:
			_opened = _now() - 10.0
			_anim_until = 0.0
		_refresh()

	## The last square covered: the solve's wave, without the party.
	func light() -> void:
		_on_solved()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_art = Patchwork.new()
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

## The card as tall as the page leaves over the caption, and as wide as the
## page (the quilt and the rack side by side), centred.
func _layout() -> void:
	if _art == null:
		return
	var h := maxf(0.0, size.y - CAPTION_H)
	var w := minf(size.x, h * CARD_RATIO)
	_art.position = Vector2((size.x - w) * 0.5, 0.0)
	_art.size = Vector2(w, h)
	_over.position = Vector2.ZERO
	_over.size = size
	_caption.position = Vector2(20.0, size.y - CAPTION_H + 4.0)
	_caption.size = Vector2(size.x - 40.0, CAPTION_H - 8.0)
	if not _begun and is_inside_tree() and size.x > 0.0:
		call_deferred("_start")

## Width over height of the page's card, at most.
const CARD_RATIO := 2.4
## The share of the card's width the quilt and its label take.
const FIELD_SIDE := 0.56

func _process(_delta: float) -> void:
	if _finger.x >= 0.0 or _finger_shown != null:
		_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	# Queued twice (by _ready and by the first layout): one loop is enough,
	# and a second would deal the quilt again without its entrance.
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
		Lesson.FILL:
			_play_on(PC, int(ANSWER[PC]), "HTP_QL_DRAG_CAP")
			_loop.tween_interval(1.0)
			_play_on(PD, int(ANSWER[PD]), "")
			_loop.tween_interval(0.3)
			_loop.tween_callback(func() -> void: _art.light())
			_say_for("HTP_QL_DONE_CAP", 3.0)
		Lesson.FIT:
			_play_hold(PD, OVER_A, "HTP_QL_OVER_CAP", 1.2)
			_loop.tween_interval(1.0)
			_play_on(PD, int(ANSWER[PD]), "HTP_QL_FITS_CAP")
			_loop.tween_interval(2.0)
		Lesson.OFF:
			_play_off(PC, "HTP_QL_OFF_CAP")
			_loop.tween_interval(1.4)
			_play_on(PC, int(ANSWER[PC]), "HTP_QL_BACK_CAP")
			_loop.tween_interval(1.6)
		Lesson.HEARTS:
			_play_on(PD, WRONG_D, "")
			_loop.tween_interval(0.2)
			_say_for("HTP_QL_SNIP_CAP", 1.9)
			_play_hold(PD, WRONG_D, "HTP_QL_CHALK_CAP", 1.4)
			_loop.tween_interval(1.4)
		Lesson.SCRAPS:
			_play_on(PC, int(ANSWER[PC]), "")
			_loop.tween_interval(0.6)
			_play_on(PD, int(ANSWER[PD]), "")
			_loop.tween_interval(0.3)
			_loop.tween_callback(func() -> void: _art.light())
			_say_for("HTP_QL_SCRAP_DONE_CAP", 3.0)
		Lesson.UNDO:
			_play_on(PC, int(ANSWER[PC]), "")
			_loop.tween_interval(0.8)
			if _judged():
				_play_on(PD, int(ANSWER[PD]), "")
			else:
				_loop.tween_callback(_say.bind("HTP_QL_UNDO_CAP"))
				_loop.tween_interval(0.6)
				_loop.tween_callback(func() -> void: _art.undo())
				_loop.tween_interval(1.4)
				_play_on(PC, int(ANSWER[PC]), "HTP_QL_AGAIN_CAP")
			_loop.tween_interval(0.8)
			_loop.tween_callback(_say.bind("HTP_QL_RESET_CAP"))
			_loop.tween_interval(0.6)
			_loop.tween_callback(func() -> void: _art.reset_board())
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(func() -> void: _art.hint())
			_loop.tween_interval(3.0)
	_loop.tween_callback(_reset)

func _judged() -> bool:
	return band >= 2

## The caption turned to `key` for `hold`.
func _say_for(key: String, hold: float) -> void:
	_loop.tween_callback(_say.bind(key))
	_loop.tween_interval(hold)

## Patch `p` dragged from where it is (its bay, or its place on the quilt)
## and let go over `origin`, the caption turning to `say` when not "".
func _play_on(p: int, origin: int, say: String) -> void:
	_play_hold(p, origin, say, 0.25)

## The same, held over `origin` for `hold` before the release: long enough
## for a halo or the chalk to be read.
func _play_hold(p: int, origin: int, say: String, hold: float) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(func() -> void: _finger = _art.position + _from(p); _down = false)
	_loop.tween_interval(0.35)
	_loop.tween_callback(func() -> void: _press(p))
	_loop.tween_interval(0.15)
	_loop.tween_method(func(u: float) -> void: _slide(p, _to(p, origin), u), 0.0, 1.0, DRAG_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(hold)
	_loop.tween_callback(func() -> void: _release(_to(p, origin)))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## Sewn patch `p` dragged down off the quilt into the rack and let go there.
func _play_off(p: int, say: String) -> void:
	if say != "":
		_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(func() -> void: _finger = _art.position + _from(p); _down = false)
	_loop.tween_interval(0.35)
	_loop.tween_callback(func() -> void: _press(p))
	_loop.tween_interval(0.15)
	var away := func() -> Vector2:
		var box: Rect2 = _art._rack_box()
		return Vector2(box.get_center().x, box.end.y - 4.0)
	_loop.tween_method(func(u: float) -> void: _slide(p, away.call(), u), 0.0, 1.0, DRAG_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.3)
	_loop.tween_callback(func() -> void: _release(away.call()))
	_loop.tween_interval(0.25)
	_loop.tween_callback(_lift)
	_loop.tween_interval(0.2)

## Every lesson back to its question: the quilt as dealt with what the
## lesson starts from, every heart, nothing in flight. `fresh` is the first
## deal, which pops the card in with the board's entrance.
func _reset(fresh := false) -> void:
	var h := hearts if lesson == Lesson.HEARTS else 0
	match lesson:
		Lesson.FILL, Lesson.FIT, Lesson.HEARTS, Lesson.UNDO:
			_art.lay(band, h, 4, [PA, PB], fresh)
		Lesson.OFF:
			_art.lay(band, h, 4, [PA, PB, PC], fresh)
		Lesson.SCRAPS:
			_art.lay(band, h, 5, [PA, PB], fresh)
		Lesson.HINT:
			_art.lay(band, h, 4, [PA, PB], fresh)
	_lift()
	_say({Lesson.FILL: "HTP_QL_FILL_CAP", Lesson.FIT: "HTP_QL_FIT_CAP",
		Lesson.OFF: "HTP_QL_TAKE_CAP", Lesson.HEARTS: "HTP_QL_JUDGED_CAP",
		Lesson.SCRAPS: "HTP_QL_SCRAP_CAP", Lesson.UNDO: "HTP_QL_LAY_CAP",
		Lesson.HINT: "HTP_QL_HINT_CAP"}[lesson])

## Reduce-motion: the lesson's point, standing still.
func _still() -> void:
	var st = _art._state
	match lesson:
		Lesson.FILL:
			st.place(PC, int(ANSWER[PC]))
			st.place(PD, int(ANSWER[PD]))
			_art._on_solved()
			_say("HTP_QL_DONE_CAP")
		Lesson.FIT:
			st.place(PD, int(ANSWER[PD]))
			_say("HTP_QL_FITS_CAP")
		Lesson.OFF:
			st.lift(PC)
			_say("HTP_QL_OFF_CAP")
		Lesson.HEARTS:
			st.rule(PD, WRONG_D)
			_art.hearts = maxi(0, hearts - 1)
			_say("HTP_QL_SNIP_CAP")
		Lesson.SCRAPS:
			st.place(PC, int(ANSWER[PC]))
			st.place(PD, int(ANSWER[PD]))
			_say("HTP_QL_SCRAP_DONE_CAP")
		Lesson.UNDO:
			_say("HTP_QL_RESET_CAP")
		Lesson.HINT:
			_art.hint()
	st.recompute()
	_art._refresh()
	_art._heart_layer.queue_redraw()

## `key` through tr.
func _say(key: String) -> void:
	_caption.text = tr(key)

# --- the moves, through the board's own input ---

## Where the finger takes hold of patch `p`: its first cell, in its bay or
## on the quilt.
func _from(p: int) -> Vector2:
	var st = _art._state
	var c: Vector2i = st.shapes[p][0]
	var origin := int(st.at[p])
	if origin >= 0:
		return _art._corner_of(origin) + (Vector2(c) + Vector2(0.5, 0.5)) * _art._cell()
	return _art._bay_home(p) + (Vector2(c) + Vector2(0.5, 0.5)) * _art._rack_cell()

## Where the finger lets go for patch `p` to be over `origin`: the board
## holds a patch HOLD_LIFT cells above the finger.
func _to(p: int, origin: int) -> Vector2:
	var c: Vector2i = _art._state.shapes[p][0]
	return _art._corner_of(origin) + (Vector2(c) + Vector2(0.5, 0.5 + _art.HOLD_LIFT)) * _art._cell()

func _press(p: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = _from(p)
	_down = true
	_press_at = ev.position
	_art._gui_input(ev)

func _slide(_p: int, to: Vector2, u: float) -> void:
	var at := _press_at.lerp(to, u)
	_finger = _art.position + at
	var ev := InputEventMouseMotion.new()
	ev.position = at
	_art._gui_input(ev)

func _release(at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = at
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
