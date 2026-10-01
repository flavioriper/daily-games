extends Control

## One page of Shikaku's tutorial: a small field drawn with the board's own
## meshes -- its ground, tilled beds, pinned lines, fence and dashed wash --
## and real MarkerFace signs, with one lesson played on a loop over a caption
## that says what it means. The moves are real: a board script that never
## enters the tree (`_art`) keeps a State of the lesson's field, judges every
## drag with State.commit and lends its own mesh code, so a sign beams,
## strains or puzzles exactly as it would on the board. `lesson` picks the
## page (set before it enters the tree):
##
## - DRAG: corner to corner round a sign, the count climbing; the bed lands.
## - ONE: a bed round two signs blushes; a tap clears it; one sign each.
## - SHAPES: a square sign refuses a wide plot and takes a square one; a
##   sign with no number takes any size of its shape.
## - HINT: the bulb drops a bed in and pins it; a drag on it is refused.
## - HEARTS: a bed that fits its sign but is not the answer wilts and costs
##   a heart (`hearts` is the band's count), then the right one.
## - CROW: a scarecrow's number counts the beds sharing a fence with its own.
##
## The board checkup, 2026-10-01: Shikaku had only the shared one-page card.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Board = preload("res://puzzles/shikaku2d.gd")
const Gen = preload("res://puzzles/shikaku_gen.gd")

enum Lesson { DRAG, ONE, SHAPES, HINT, HEARTS, CROW }

const CELL_MAX := 120.0
## The finger: a soft disc and a ring, pressed smaller while it is down.
const FINGER_R := 0.2
const FINGER_ALPHA := 0.16
## How long a drag takes from its first cell to its last, a beat after the
## press.
const DRAG_TIME := 0.9
const HEART_TOP := 56.0
## CROW: how much a neighbour swells as it is counted.
const COUNT_BUMP := 0.05

var lesson: int = Lesson.DRAG
## HEARTS: how many hearts the band has (Hard 3, Insane 1).
var hearts := 3

var _art: Board
var _cols := 4
var _rows := 3
## The beds standing when the loop starts over.
var _pre: Array[Rect2i] = []
var _signs: Array = []          # [i] -> MarkerFace
var _field: Control
var _over: Control
var _caption: Label
var _loop: Tween
var _cell := 0.0
var _origin := Vector2.ZERO
var _ground: ArrayMesh
## Rect -> {"at", "drop"}: a bed arriving. Rect -> msec: a bed wilting.
var _bed_in: Dictionary = {}
var _wilt: Dictionary = {}
## Beds on their way out: [{"rect", "mesh", "at"}].
var _gone: Array = []
## Rect -> msec: a bed blushing at a refused drag.
var _flash: Dictionary = {}
## The drag: its first cell, the rectangle, when it popped in and when its
## count last changed.
var _from := Vector2i(-1, -1)
var _pend := Rect2i()
var _pend_at := -1.0e9
var _count_at := -1.0e9
var _finger := Vector2(-1.0, -1.0)   # in cells; x < 0 is no finger
var _down := false
var _full := 3.0                      # hearts still whole, as drawn
var _split_at := -1.0e9
## Kept until the next draw replaces them: a canvas command holds a mesh by
## RID.
var _field_shown: Array = []
var _over_shown: ArrayMesh
var _disc: ArrayMesh
var _disc_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_art = Board.new()
	_setup()
	_field = Control.new()
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)
	for i in _art.state.clues.size():
		var clue: Dictionary = _art.state.clues[i]
		var sign := MarkerFace.new()
		var crow := Gen.crow_of(clue)
		sign.crow = crow >= 0
		sign.number = crow if crow >= 0 else int(clue.area)
		sign.shape = int(clue.get("shape", 0))
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sign)
		_signs.append(sign)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
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
	if _cell > 0.0 and _loop == null:
		call_deferred("_start")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_art):
		_art.free()

## The lesson's field: its signs, its answer and the beds it starts with.
func _setup() -> void:
	var clues: Array = []
	var solution: Array[Rect2i] = []
	const ANY := Gen.Shape.ANY
	match lesson:
		Lesson.SHAPES:
			clues = [
				{"pos": Vector2i(0, 0), "area": 0, "shape": Gen.Shape.SQUARE},
				{"pos": Vector2i(2, 0), "area": 2, "shape": ANY},
				{"pos": Vector2i(3, 1), "area": 3, "shape": Gen.Shape.TALL},
				{"pos": Vector2i(1, 2), "area": 0, "shape": Gen.Shape.WIDE}]
			solution = [Rect2i(0, 0, 2, 2), Rect2i(2, 0, 1, 2), Rect2i(3, 0, 1, 3), Rect2i(0, 2, 3, 1)]
			_pre = [Rect2i(2, 0, 1, 2), Rect2i(3, 0, 1, 3)]
		Lesson.HEARTS:
			clues = [
				{"pos": Vector2i(0, 1), "area": 3, "shape": ANY},
				{"pos": Vector2i(2, 0), "area": 3, "shape": ANY},
				{"pos": Vector2i(3, 2), "area": 6, "shape": ANY}]
			solution = [Rect2i(0, 0, 1, 3), Rect2i(1, 0, 3, 1), Rect2i(1, 1, 3, 2)]
			_pre = [Rect2i(1, 0, 3, 1)]
		Lesson.CROW:
			clues = [
				{"pos": Vector2i(0, 0), "area": 0, "shape": ANY, "crow": 3},
				{"pos": Vector2i(3, 0), "area": 2, "shape": ANY},
				{"pos": Vector2i(2, 2), "area": 4, "shape": ANY},
				{"pos": Vector2i(1, 2), "area": 2, "shape": ANY}]
			solution = [Rect2i(0, 0, 2, 2), Rect2i(2, 0, 2, 1), Rect2i(2, 1, 2, 2), Rect2i(0, 2, 2, 1)]
			_pre = [Rect2i(2, 0, 2, 1), Rect2i(2, 1, 2, 2), Rect2i(0, 2, 2, 1)]
		_:
			clues = [
				{"pos": Vector2i(1, 0), "area": 4, "shape": ANY},
				{"pos": Vector2i(2, 0), "area": 2, "shape": ANY},
				{"pos": Vector2i(3, 2), "area": 4, "shape": ANY},
				{"pos": Vector2i(0, 2), "area": 2, "shape": ANY}]
			solution = [Rect2i(0, 0, 2, 2), Rect2i(2, 0, 2, 1), Rect2i(2, 1, 2, 2), Rect2i(0, 2, 2, 1)]
			match lesson:
				Lesson.DRAG:
					_pre = [Rect2i(2, 0, 2, 1), Rect2i(0, 2, 2, 1)]
				Lesson.ONE:
					_pre = [Rect2i(2, 1, 2, 2), Rect2i(0, 2, 2, 1)]
				Lesson.HINT:
					_pre = [Rect2i(0, 2, 2, 1)]
	var st = _art.state
	st.w = _cols
	st.h = _rows
	st.clues = clues
	st.solution = solution

func _layout() -> void:
	if _signs.is_empty():
		return
	var top := HEART_TOP if lesson == Lesson.HEARTS else 0.0
	var room := Vector2(size.x - 120.0, size.y - 104.0 - top)
	_cell = floorf(minf(CELL_MAX, minf(room.x / _cols, room.y / _rows)))
	if _cell <= 0.0:
		return
	_origin = Vector2((size.x - _cell * _cols) * 0.5, top + (room.y - _cell * _rows) * 0.5 + 4.0)
	_art._cell = _cell
	_art._origin = _origin
	_art._bed_cache = {}
	_art._seed_cache = {}
	_art._fence_still_key = -1
	_art._fence_dirty = true
	_ground = _art._build_ground()
	var seat := _cell * Board.MARKER
	for i in _signs.size():
		var sign: MarkerFace = _signs[i]
		sign.size = Vector2(seat, seat)
		sign.pivot_offset = sign.size * 0.5
		sign.position = _art._marker_centre(_art.state.clues[i].pos) - sign.size * 0.5
	for c: Control in [_field, _over]:
		c.position = Vector2.ZERO
		c.size = size
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)

func _process(_delta: float) -> void:
	if _cell <= 0.0:
		return
	_field.queue_redraw()
	_over.queue_redraw()

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or _cell <= 0.0:
		return
	Motion.stop(_loop)
	_reset()
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	_loop.tween_callback(_reset)
	_loop.tween_interval(0.8)
	match lesson:
		Lesson.DRAG:
			_play_drag(Vector2i(0, 0), Vector2i(1, 1), 0, 1)
			_loop.tween_interval(1.4)
			_play_drag(Vector2i(2, 1), Vector2i(3, 2), 1, 2)
			_loop.tween_interval(2.2)
		Lesson.ONE:
			_play_drag(Vector2i(0, 0), Vector2i(2, 0), 0)
			_loop.tween_interval(1.5)
			_play_tap(Vector2i(1, 0), 1)
			_loop.tween_interval(0.9)
			_play_drag(Vector2i(0, 0), Vector2i(1, 1), 1, 2)
			_loop.tween_interval(2.2)
		Lesson.SHAPES:
			_play_drag(Vector2i(0, 0), Vector2i(1, 0), 0, -1, false)
			_loop.tween_interval(0.7)
			_loop.tween_method(_drag_to.bind(Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)), 0.0, 1.0, DRAG_TIME * 0.5)
			_loop.tween_callback(_say.bind(1))
			_loop.tween_interval(0.6)
			_loop.tween_callback(_release)
			_loop.tween_interval(1.2)
			_play_drag(Vector2i(0, 2), Vector2i(2, 2), 2)
			_loop.tween_interval(2.2)
		Lesson.HINT:
			_loop.tween_callback(_hint)
			_loop.tween_interval(1.8)
			_play_drag(Vector2i(1, 1), Vector2i(1, 0), 0)
			_loop.tween_interval(2.0)
		Lesson.HEARTS:
			_play_drag(Vector2i(0, 1), Vector2i(2, 1), 0)
			_loop.tween_interval(0.5)
			_loop.tween_callback(_wilt_wrong)
			_loop.tween_interval(1.4)
			_loop.tween_callback(_take_back)
			_loop.tween_interval(0.8)
			_play_drag(Vector2i(0, 0), Vector2i(0, 2), 1, 2)
			_loop.tween_interval(2.2)
		Lesson.CROW:
			_play_drag(Vector2i(0, 0), Vector2i(1, 1), 0)
			_loop.tween_interval(0.6)
			for k in 3:
				_loop.tween_callback(_count_neighbour.bind(k))
				_loop.tween_interval(0.6)
			_loop.tween_callback(_say.bind(2))
			_loop.tween_interval(2.2)

## A press on `from`, a drag to `to` and the release, the caption turning to
## `say` as the finger goes down and to `after` (when not -1) as it lets go.
func _play_drag(from: Vector2i, to: Vector2i, say: int, after := -1, release := true) -> void:
	_loop.tween_callback(_say.bind(say))
	_loop.tween_callback(_press.bind(from))
	_loop.tween_interval(0.35)
	_loop.tween_method(_drag_to.bind(from, from, to), 0.0, 1.0, DRAG_TIME)
	if release:
		_loop.tween_interval(0.4)
		_loop.tween_callback(_release)
		if after >= 0:
			_loop.tween_callback(_say.bind(after))

func _play_tap(cell: Vector2i, say: int) -> void:
	_loop.tween_callback(_say.bind(say))
	_loop.tween_interval(0.5)
	_loop.tween_callback(_press.bind(cell))
	_loop.tween_interval(0.3)
	_loop.tween_callback(_release)

## Every lesson back to its question: the starting beds, the fence round
## them, the hearts whole, no drag.
func _reset() -> void:
	var st = _art.state
	var rects: Array[Rect2i] = []
	var locked: Array[bool] = []
	for r in _pre:
		rects.append(r)
		locked.append(false)
	st.rects = rects
	st.locked = locked
	st.history.clear()
	st.reown()
	_bed_in = {}
	_wilt = {}
	_gone = []
	_flash = {}
	_from = Vector2i(-1, -1)
	_pend = Rect2i()
	_finger = Vector2(-1.0, -1.0)
	_down = false
	_full = hearts
	_split_at = -1.0e9
	_art._edges = {}
	_art._fence_sync(Vector2.ZERO, 0.0, true)
	_art._fence_still_key = -1
	_art._fence_dirty = true
	for sign: MarkerFace in _signs:
		sign.scale = Vector2.ONE
	_layout()
	_refresh_signs()
	_say(0)

## Reduce-motion: the lesson's answer, standing still.
func _still() -> void:
	var st = _art.state
	match lesson:
		Lesson.ONE, Lesson.DRAG, Lesson.SHAPES, Lesson.CROW:
			for rect: Rect2i in st.solution:
				if not st.rects.has(rect):
					st.commit(rect)
			_say(2)
		Lesson.HINT:
			st.apply_hint()
			_say(0)
		Lesson.HEARTS:
			# The still shows the right bed with every heart; the page's body
			# says what a wrong one costs.
			st.commit(Rect2i(0, 0, 1, 3))
			_say(2)
	st.reown()
	_art._fence_sync(Vector2.ZERO, 0.0, true)
	_refresh_signs()

func _say(step: int) -> void:
	_caption.text = _caption_for(step)

func _caption_for(step: int) -> String:
	var keys: Array
	match lesson:
		Lesson.DRAG:
			keys = ["HTP_SK_DRAG_CAP", "HTP_SK_FIT_CAP", "HTP_SK_DONE_CAP"]
		Lesson.ONE:
			keys = ["HTP_SK_TWO_CAP", "HTP_SK_CLEAR_CAP", "HTP_SK_EACH_CAP"]
		Lesson.SHAPES:
			keys = ["HTP_SK_SQUARE_CAP", "HTP_SK_SQUARED_CAP", "HTP_SK_ANY_CAP"]
		Lesson.HINT:
			keys = ["HTP_SK_HINT_CAP", "HTP_SK_PINNED_CAP"]
		Lesson.HEARTS:
			keys = ["HTP_SK_FITS_CAP", "HTP_SK_WILT_CAP", "HTP_SK_RIGHT_CAP"]
		Lesson.CROW:
			keys = ["HTP_SK_CROW_CAP", "HTP_SK_COUNT_CAP", "HTP_SK_CROWED_CAP"]
	return tr(keys[clampi(step, 0, keys.size() - 1)])

# --- the moves ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _press(cell: Vector2i) -> void:
	var st = _art.state
	_finger = Vector2(cell) + Vector2(0.5, 0.5)
	_down = true
	var who: int = st.owner_at(cell.y, cell.x)
	if who >= 0 and st.locked[who]:
		# A pinned bed refuses before the drag starts, as on the board.
		_refuse(who)
		_from = Vector2i(-1, -1)
		return
	_from = cell
	# A drag from inside a bed redraws it, so that bed does not turn the wash
	# rose (the board's _drag_own).
	_art._drag_own = who
	_pend = Rect2i(cell, Vector2i.ONE)
	_pend_at = _now()
	_count_at = -1.0e9

## The finger `u` of the way from `a` to `b` (cells), the rectangle from the
## press to the cell under it.
func _drag_to(u: float, from: Vector2i, a: Vector2i, b: Vector2i) -> void:
	var at := Vector2(a).lerp(Vector2(b), u)
	_finger = at + Vector2(0.5, 0.5)
	if _from.x < 0:
		return
	var cell := Vector2i(roundi(at.x), roundi(at.y))
	var lo := Vector2i(mini(from.x, cell.x), mini(from.y, cell.y))
	var hi := Vector2i(maxi(from.x, cell.x), maxi(from.y, cell.y))
	var pend := Rect2i(lo, hi - lo + Vector2i.ONE)
	if pend.get_area() != _pend.get_area():
		_count_at = _now()
	_pend = pend

func _release() -> void:
	_down = false
	var from := _from
	_from = Vector2i(-1, -1)
	if from.x < 0:
		_pend = Rect2i()
		return
	var st = _art.state
	var pend := _pend
	_pend = Rect2i()
	var own: int = st.owner_at(from.y, from.x)
	_art._drag_own = -1
	var before: Array = []
	for i in st.rects.size():
		before.append([st.rects[i], _art._bed_variant(st.rects[i], st.locked[i], st.plot_blushes(i))])
	var out: Dictionary = st.commit(pend, own)
	match String(out.get("kind", "none")):
		"plot":
			_leave_missing(before)
			_bed_in[out.rect] = {"at": _now(), "drop": false}
			_art._fence_sync(Vector2(from) + Vector2(0.5, 0.5))
		"clear":
			_leave_missing(before)
			_art._fence_sync(Vector2(out.rect.position) + Vector2(out.rect.size) * 0.5)
		"locked":
			_refuse(st.owner_at(from.y, from.x))
		"taken":
			_refuse(int(out.plot))
	_refresh_signs()

## The beds in `before` the state no longer has shrink away.
func _leave_missing(before: Array) -> void:
	for was in before:
		if not _art.state.rects.has(was[0]):
			_gone.append({"rect": was[0], "mesh": was[1], "at": _now()})

## A refused drag on bed `who`: it blushes and its sign shivers.
func _refuse(who: int) -> void:
	if who < 0:
		return
	_flash[_art.state.rects[who]] = _now()
	var i: int = _art.state.clue_index_in(who)
	if i >= 0:
		Motion.shiver(_signs[i], _cell * Board.MARKER * Board.SHIVER)
	_say(1)

## HINT: the bulb draws the answer's first missing bed and pins it, dropping
## it in from above.
func _hint() -> void:
	var rect: Rect2i = _art.state.apply_hint()
	if rect.size == Vector2i.ZERO:
		return
	_bed_in[rect] = {"at": _now(), "drop": true}
	_art._fence_sync(Vector2(rect.position) + Vector2(rect.size) * 0.5, Motion.DROP_TIME * 0.6)
	_refresh_signs()
	var i: int = _art.state.clue_index_in(_art.state.rects.find(rect))
	if i >= 0:
		Motion.bump(_signs[i])

## HEARTS: the bed just drawn fits its sign but is not the answer: it wilts,
## its sign worries, and a heart breaks.
func _wilt_wrong() -> void:
	var st = _art.state
	if st.rects.is_empty():
		return
	var rect: Rect2i = st.rects[st.rects.size() - 1]
	_wilt[rect] = _now()
	_full = maxf(0.0, _full - 1.0)
	_split_at = _now()
	var i: int = st.clue_index_in(st.rects.size() - 1)
	if i >= 0:
		_signs[i].expression = Face.Expr.WORRIED
	_say(1)

## ...and it is taken back, as though never drawn.
func _take_back() -> void:
	var st = _art.state
	var before: Array = []
	for r: Rect2i in st.rects:
		before.append([r, _art._bed_variant(r, false, false)])
	st.undo()
	_leave_missing(before)
	for g in _gone:
		if _wilt.has(g.rect):
			g["tint"] = Board.WILT_TINT
	_wilt = {}
	_art._fence_sync(Vector2(0.5, 1.5))
	_refresh_signs()

## CROW: the `k`th bed round the scarecrow's bumps as it is counted.
func _count_neighbour(k: int) -> void:
	var order := [Rect2i(2, 0, 2, 1), Rect2i(2, 1, 2, 2), Rect2i(0, 2, 2, 1)]
	var rect: Rect2i = order[k]
	_bed_in[rect] = {"at": _now(), "drop": false, "bump": true}
	var i: int = _art.state.clue_index_in(_art.state.rects.find(rect))
	if i >= 0:
		Motion.bump(_signs[i])
	_caption.text = tr("HTP_SK_COUNT_CAP") % (k + 1)

## Every sign takes the face its state asks for, as on the board -- where,
## with hearts, a sign whose bed fits but is not the answer worries at once.
func _refresh_signs() -> void:
	var st = _art.state
	for i in _signs.size():
		var expr: int = _art._expression(i)
		if lesson == Lesson.HEARTS:
			var who: int = st.owner_at(st.clues[i].pos.y, st.clues[i].pos.x)
			if who >= 0 and not st.is_answer(st.rects[who]):
				expr = Face.Expr.WORRIED
		if _signs[i].expression != expr:
			_signs[i].expression = expr

# --- drawing ---

func _draw_field() -> void:
	if _cell <= 0.0 or _ground == null:
		return
	var now := _now()
	var shown: Array = [_ground]
	_field.draw_mesh(_ground, null, Transform2D(0.0, _art._field_px().get_center()))
	var still: Array = []
	for g in _gone:
		var k := Motion.pop_out_scale(now - float(g.at))
		if k <= 0.0:
			continue
		still.append(g)
		shown.append(g.mesh)
		_field.draw_mesh(g.mesh, null, Transform2D(0.0, Vector2(k, k), 0.0,
			_art._rect_px(g.rect).get_center()), g.get("tint", Color.WHITE))
	_gone = still
	var st = _art.state
	for i in st.rects.size():
		var rect: Rect2i = st.rects[i]
		var px: Rect2 = _art._rect_px(rect)
		var xf := Transform2D(0.0, px.get_center())
		var tint := Color.WHITE
		var arrival: Dictionary = _bed_in.get(rect, {})
		if not arrival.is_empty():
			var e: float = now - float(arrival.at)
			if arrival.get("bump", false):
				var k := Motion.bump_scale(e, COUNT_BUMP)
				xf = xf.scaled_local(Vector2(k, k))
			elif arrival.drop:
				tint.a = Motion.appear_level(e)
				xf.origin.y -= Motion.drop_in_lift(e)
			else:
				var k := Motion.wide_pop_scale(e, Motion.POP_IN)
				xf = xf.scaled_local(Vector2(k, k))
		if _wilt.has(rect):
			var level := clampf((now - float(_wilt[rect])) / Board.WILT_TIME, 0.0, 1.0)
			tint *= Color.WHITE.lerp(Board.WILT_TINT, level)
			var sag := Board.WILT_SAG * level
			xf = xf * Transform2D(0.0, Vector2(1.0 + sag * 0.3, 1.0 - sag), 0.0,
				Vector2(0.0, px.size.y * sag * 0.5))
		var bed: ArrayMesh = _art._bed_variant(rect, st.locked[i], st.plot_blushes(i))
		shown.append(bed)
		_field.draw_mesh(bed, null, xf, tint)
		if _flash.has(rect):
			var level := Motion.flash_level(now - float(_flash[rect]))
			if level > 0.0:
				var blush: ArrayMesh = _art._bed_variant(rect, st.locked[i], true)
				shown.append(blush)
				_field.draw_mesh(blush, null, xf, Color(1.0, 1.0, 1.0, level))
	if _art._fence_dirty or now < _art._fence_until:
		_art._fence_dirty = false
		_art._build_fence(now)
	for f: ArrayMesh in [_art._fence_still, _art._fence]:
		if f != null:
			shown.append(f)
			_field.draw_mesh(f, null, Transform2D(0.0, _origin))
	if _pend.has_area():
		var px: Rect2 = _art._rect_px(_pend)
		var colour: Color = _art._pending_colour(_pend)
		var at := -px.size * 0.5
		var b := Face.Builder.new()
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * Board.BED_INSET,
			px.size - Vector2.ONE * 2.0 * Board.BED_INSET, Board.BED_RADIUS), Color(colour, Board.PEND_ALPHA))
		var crawl := 0.0 if Motion.reduce else now * Board.ANTS * _cell
		_art._dash_path(b, Face.Builder.round_rect(at + Vector2.ONE * 3.0,
			px.size - Vector2.ONE * 6.0, Board.BED_RADIUS), true,
			maxf(Board.PEND_MIN, _cell * Board.PEND_WIDTH), colour, _cell * Board.PEND_DASH,
			_cell * Board.PEND_GAP, crawl)
		var wash := b.mesh()
		shown.append(wash)
		var k := Motion.wide_pop_scale(now - _pend_at, Motion.POP_IN)
		_field.draw_mesh(wash, null, Transform2D(0.0, Vector2(k, k), 0.0, px.get_center()))
	_field_shown = shown

## Over the signs: the drag's count disc, the finger and, on HEARTS, the
## hearts.
func _draw_over() -> void:
	if _cell <= 0.0:
		return
	var now := _now()
	var b := Face.Builder.new()
	if lesson == Lesson.HEARTS:
		_draw_hearts(b, now)
	if _finger.x >= 0.0:
		var at := _origin + _finger * _cell + Vector2(_cell * 0.18, _cell * 0.22)
		var r := _cell * FINGER_R * (0.85 if _down else 1.0)
		b.disc(at, r, Color(Pal.TEXT, FINGER_ALPHA * (1.6 if _down else 1.0)))
		b.stroke(Face.Builder.ring(at, r, r), 3.0, Color(Pal.TEXT, 0.45), true)
	if not b.verts.is_empty():
		_over_shown = b.mesh()
		_over.draw_mesh(_over_shown, null)
	if _pend.has_area():
		_draw_disc(now)

## The count disc over the drag, popping in and bumping at each recount: the
## board's own (shikaku2d.gd's Overlay).
func _draw_disc(now: float) -> void:
	var px: Rect2 = _art._rect_px(_pend)
	var colour: Color = _art._pending_colour(_pend)
	var r := minf(_cell * Board.DISC_SHARE, Board.DISC_MAX)
	var key := "%.1f_%s" % [r, colour.to_html(false)]
	if key != _disc_key:
		_disc_key = key
		var b := Face.Builder.new()
		b.disc(Vector2.ZERO, r, Pal.SURFACE)
		b.stroke(Face.Builder.ring(Vector2.ZERO, r, r), Board.DISC_RIM, colour, true)
		_disc = b.mesh()
	var grown: Vector2 = Motion.pop_in_scale(now - _pend_at) * Motion.bump_scale(now - _count_at)
	if grown.x <= 0.0:
		return
	_over.draw_set_transform(px.get_center(), 0.0, grown)
	_over.draw_mesh(_disc, null)
	var font: Font = CozyTheme.display(700)
	var text := str(_pend.get_area())
	var fs := int(roundf(r * Board.DISC_TEXT))
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	_over.draw_string(font, Vector2(-wide * 0.5, font.get_ascent(fs) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, colour)
	_over.draw_set_transform_matrix(Transform2D.IDENTITY)

## The board's heart pill over the field: whole hearts, then the one that
## broke falling apart in two.
func _draw_hearts(b, now: float) -> void:
	var r := Board.HEART_R
	var step := 2.0 * r + Board.HEART_GAP
	var y := HEART_TOP * 0.5
	var x0 := size.x * 0.5 - step * (hearts - 1) * 0.5
	var pill := Vector2(step * (hearts - 1) + 2.0 * r, 2.0 * r) + 2.0 * Board.HEART_PILL_PAD
	var corner := Vector2(size.x * 0.5, y) - pill * 0.5
	var rim := Vector2.ONE * Board.HEART_PILL_RIM
	b.polygon(Face.Builder.round_rect(corner - rim, pill + 2.0 * rim, pill.y * 0.5 + Board.HEART_PILL_RIM), Pal.LINE)
	b.polygon(Face.Builder.round_rect(corner, pill, pill.y * 0.5), Pal.SURFACE)
	for i in hearts:
		var at := Vector2(x0 + step * i, y)
		if i < int(_full):
			b.polygon(Board._heart(at, r, -1), Pal.FLOWER)
			b.polygon(Board._heart(at, r, 1), Pal.FLOWER_DEEP)
			Board._heart_face(b, at, r)
			continue
		b.polygon(Board._heart(at, r, 0), Color(Pal.FLOWER, 0.22))
		var u := (now - _split_at) / Board.SPLIT_TIME
		if i == int(_full) and u < 1.0 and not Motion.reduce:
			var fade := 1.0 - u * u
			for side in [-1, 1]:
				var turn: float = side * Board.SPLIT_TURN * u
				var shift := Vector2(side * Board.SPLIT_SPREAD * u, Board.SPLIT_FALL * u * u)
				var pts := Board._heart(Vector2.ZERO, r, side)
				for k in pts.size():
					pts[k] = at + shift + pts[k].rotated(turn)
				b.polygon(pts, Color(Pal.FLOWER if side < 0 else Pal.FLOWER_DEEP, fade))
