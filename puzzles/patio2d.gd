extends "res://core/puzzle_base.gd"

## Domino Patio (spec docs/superpowers/specs/2026-10-22-domino-patio-design.md):
## a patio of squares parted into flower beds, each with a rule on its tag
## (a sum, under or over a number, all the same, all different), and a rack
## of the house's dominoes under it. Lay every tile on two squares side by
## side so the patio is covered and every bed keeps its rule. The rules are
## puzzles/patio_state.gd's; the day is puzzles/patio_gen.gd's.
##
## **The terrace is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/patio_world.gd) is the board's first child. From the top
## of the span down: the patio, then the rack, a wooden tray with a bay for
## every tile, in one coordinate space so a tile is dragged from one to the
## other (Quilt's rack, for the same reason).
##
## A tile is drawn where the rules put it: each frame asks the state where
## each tile lies and which way it is turned, and a tile whose place changed
## glides there from wherever it was shown, and one turned spins a quarter
## (`Motion.turn_angle`). So a drop, an Undo, the bulb and the bin all
## animate the same way and none of them knows how. The tiles are the
## house's (ui/faces/domino_tile.gd), one cached mesh a tile a turn.
##
## A press on a tile and a move past `TAP_PX` lifts it: it rides over the
## finger at the patio's size, a ghost shows the two squares it would take
## (the nearest that fit), and it is laid there on release. Let go anywhere
## else over the patio it is refused and goes back; let go off the patio it
## goes to its bay. A tap turns it a quarter: on the rack freely, on the
## patio about its first square and then about its second, the first way
## that fits.
##
## A bed's tag says its rule and, from the rule alone, how it stands: a leaf
## tick when the bed is full and keeps it, a rose ring when what lies in it
## already breaks it (shown on every band: it is the rule's own word, never
## the answer's). The beds' colours are their names (Pal.REGION by index),
## so no state is ever a shade of a bed (CLAUDE.md).

const State = preload("res://puzzles/patio_state.gd")
const World = preload("res://puzzles/patio_world.gd")
const Tile = preload("res://ui/faces/domino_tile.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

const Rule = State.Rule
const DIRS := State.DIRS

const HAPTICS := {
	"pick": Haptics.TICK,
	"set": Haptics.TAP,
	"turn": Haptics.TICK,
	"lift": Haptics.TICK,
	"back": Haptics.TICK,
	"refuse": Haptics.WARN,
	"bed": Haptics.GOOD,
	"broken": Haptics.WARN,
	"hint": Haptics.GOOD,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The rows' margin, the patio's largest square, and the gap between the
## patio and the rack, at W.
const SIDE := 40.0
const CELL_MAX := 150.0
const GAP := 56.0
## A tile on the rack against one on the patio, and a bay's room round a
## tile, in the rack's half-tiles.
const RACK_K := 0.6
const BAY := 2.3
## A press that moves farther than this is a drag, at W.
const TAP_PX := 14.0
## A held tile rides this far over the finger, in squares.
const HOLD_LIFT := 0.55
## How far from the finger a drop still finds two squares that fit, in
## squares.
const REACH := 0.75
## A tile gliding to a new place, and a refused one's shiver and halo.
const MOVE_TIME := 0.26
const REFUSE_TIME := 0.5
## A bed's tag, as a share of a square, and its tick's and ring's moments.
const TAG := 0.36
const TAG_FONT := 0.34
const KEPT_TIME := 0.45
## The win: the patio's wave, the board's own win.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.06
const SAY_SIZE := 34
## The beds' colours by index: Queens' pastels without the tan and silver,
## which read as bare stone.
const BED_COLOURS := [1, 2, 3, 4, 6, 7, 8, 9, 11, 10]
const STONE := Color("efe4cf")
const STONE_EDGE := Color("d9c7a6")
const GROUT := Color("c9b48f")
const TRAY := Color("c49a6c")
const TRAY_DEEP := Color("9c7450")
const TRAY_LIT := Color("d8b48a")
const BAY_INK := Color("7d5a3c")
const LEAF := Color("6f9e4c")

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
## Each tile as shown: where its glide began, how big it was, when, the
## place it glides to ([at, dir]), the turn it shows and when that turn
## began, how many quarters, and when it was last refused, laid or bumped.
var _from: Array[Vector2] = []
var _from_k: Array[float] = []
var _move_at: Array[float] = []
var _key: Array[Vector2i] = []
var _shown_dir: Array[int] = []
var _turn_at: Array[float] = []
var _turn_q: Array[int] = []
var _refused_at: Array[float] = []
var _land_at: Array[float] = []
## Where each tile was shown last frame, and how big: a glide starts there.
var _last_pos: Array[Vector2] = []
var _last_k: Array[float] = []
## Each bed as it last stood, and when it was last kept or broken.
var _bed_was: Array[int] = []
var _kept_at: Array[float] = []
var _broke_at: Array[float] = []
var _bed_colour: Array[Color] = []
## The finger: {t, finger, press, point, grab, moved}; {} when none.
var _press := {}
## The ghost under a held tile: [anchor, dir] or (-1, 0).
var _ghost := Vector2i(-1, 0)
var _say := ""
var _say_at := -INF
var _refusals := 0
## The layout.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _lfrom := {}
var _lay_at := -INF
var _world: Control
var _meshes := {}
var _patio_mesh: ArrayMesh
var _patio_key := ""
var _rack_mesh: ArrayMesh
var _rack_key := ""
var fx: Node

func puzzle_id() -> String: return "patio"
func title() -> String: return "Domino Patio"

func rules() -> String:
	var out := tr("DP_RULES")
	out += "\n\n" + tr("DP_RULES_TAGS")
	if _band >= 1:
		out += "\n\n" + tr("DP_RULES_BOUNDS")
	if _band >= 2:
		out += "\n\n" + tr("DP_RULES_APART")
	if _st.spare():
		out += "\n\n" + tr("DP_RULES_SPARE")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/patio_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LAY, "HTP_DP_LAY", tr("HTP_DP_LAY_BODY")],
		[Diagram.Lesson.TURN, "HTP_DP_TURN", tr("HTP_DP_TURN_BODY")],
		[Diagram.Lesson.BEDS, "HTP_DP_BEDS", tr("HTP_DP_BEDS_BODY")],
	]
	if _band >= 1:
		steps.append([Diagram.Lesson.BOUNDS, "HTP_DP_BOUNDS", tr("HTP_DP_BOUNDS_BODY" if _band < 2 else "HTP_DP_BOUNDS_APART_BODY")])
	if _st.spare():
		steps.append([Diagram.Lesson.SPARE, "HTP_DP_SPARE", tr("HTP_DP_SPARE_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_DP_HINT", tr("HTP_DP_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and the bulb; Insane keeps no Undo (its seal). No Check: the beds'
## tags are the check, on every band.
func capabilities() -> Array[String]:
	if _band >= 3:
		return ["hint"]
	return ["undo", "hint"]

func can_undo() -> bool:
	return _band < 3 and not _st.history.is_empty() and not is_done()

func hints_left() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_fresh()
	_enter_at = _t
	_cue("enter")

## Every tile in its bay, every bed open, nothing moving.
func _fresh() -> void:
	var n: int = _st.tiles.size()
	_from.clear()
	_from_k.clear()
	_move_at.clear()
	_key.clear()
	_shown_dir.clear()
	_turn_at.clear()
	_turn_q.clear()
	_refused_at.clear()
	_land_at.clear()
	_last_pos.clear()
	_last_k.clear()
	for t in n:
		_from.append(Vector2.ZERO)
		_from_k.append(0.0)
		_move_at.append(-INF)
		_key.append(Vector2i(_st.at[t], _st.dir[t]))
		_shown_dir.append(_st.dir[t])
		_turn_at.append(-INF)
		_turn_q.append(0)
		_refused_at.append(-INF)
		_land_at.append(-INF)
		_last_pos.append(Vector2.ZERO)
		_last_k.append(0.0)
	_bed_was.clear()
	_kept_at.clear()
	_broke_at.clear()
	for b in _st.beds.size():
		_bed_was.append(State.Bed.OPEN)
		_kept_at.append(-INF)
		_broke_at.append(-INF)
	_colour_beds()
	_meshes.clear()
	_press = {}
	_ghost = Vector2i(-1, 0)
	_say = ""
	_patio_key = ""
	_rack_key = ""
	_relayout()

## Each bed a colour by index, never its neighbour's; a bed with no rule is
## bare stone.
func _colour_beds() -> void:
	_bed_colour.clear()
	var used: Array[int] = []
	for b in _st.beds.size():
		used.append(-1)
	for b in _st.beds.size():
		if int(_st.beds[b].rule) == Rule.NONE:
			_bed_colour.append(STONE)
			continue
		var near := {}
		for c: int in _st.beds[b].cells:
			for d: Vector2i in DIRS:
				var o: Vector2i = _st.cell(c) + d
				if _st.on_patio(o):
					var ob: int = _st.bed_of[_st.idx(o)]
					if ob != b and used[ob] >= 0:
						near[used[ob]] = true
		var k: int = b % BED_COLOURS.size()
		for step in BED_COLOURS.size():
			var kk: int = (b + step) % BED_COLOURS.size()
			if not near.has(kk):
				k = kk
				break
		used[b] = k
		_bed_colour.append(Pal.REGION[int(BED_COLOURS[k])])

func day_dict() -> Dictionary:
	if _st.tiles.is_empty():
		return {}
	var beds: Array = []
	for info: Dictionary in _st.beds:
		beds.append({"cells": Array(info.cells), "rule": State.tag(info) if int(info.rule) != Rule.NONE else ""})
	var tiles: Array = []
	for v: Vector2i in _st.tiles:
		tiles.append([v.x, v.y])
	var sol: Array = []
	for a: Vector2i in _st.answer:
		sol.append([a.x, a.y])
	return {
		"source": "generator", "kind": "text",
		"payload": {"cols": _st.cols, "rows": _st.rows, "beds": beds, "tiles": tiles},
		"solution": {"answer": sol},
		"metrics": {"tiles": _st.laid_count(), "beds": _st.beds.size(), "spare": _st.tiles.size() - _st.laid_count(),
			"unique": _st.unique},
	}

# --- moves ---

func _changed(sound: String) -> void:
	moves += 1
	moved.emit()
	# a tile laid is a pop varied a little each time (the house sound)
	_cue(sound, randf_range(0.94, 1.06) if sound == "set" else 1.0)
	_judge_beds()
	check_solved()
	if is_done():
		_solved_now()

## Each bed that came to be kept or broken by the move just made says so.
func _judge_beds() -> void:
	var kept := 0
	for b in _st.beds.size():
		var now: int = _st.bed(b)
		if now != _bed_was[b]:
			if now == State.Bed.KEPT and int(_st.beds[b].rule) != Rule.NONE:
				_kept_at[b] = _t
				kept += 1
				if not demo:
					fx.sparkle(_tag_at(b), Pal.GOOD)
			elif now == State.Bed.BROKEN:
				_broke_at[b] = _t
				_cue("broken")
			_bed_was[b] = now
	if kept > 0:
		_cue("bed", 1.0 + 0.06 * mini(kept - 1, 4))
	if _st.covered() and not _st.solved():
		_say_now("DP_ALMOST")
	elif _say == "DP_ALMOST":
		_say = ""

func _solved_now() -> void:
	_won_at = _t
	_say = ""
	_press = {}
	_ghost = Vector2i(-1, 0)
	_cue("solved")
	if not demo:
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			fx.confetti(_patio_centre() - Vector2(0, _l("cell") * _st.rows * 0.4), 26, size.x * 0.7)
			# not one bulb and not one tile refused: the party's toots
			_cue("party" if hints_used == 0 and _refusals == 0 else "confetti"))

func is_solved() -> bool:
	return _st.solved()

func undo() -> bool:
	if not can_undo() or not _st.undo():
		return false
	_press = {}
	_ghost = Vector2i(-1, 0)
	_cue("undo")
	_judge_beds()
	return true

## The bulb: one tile of the answer laid where it goes; what lay there goes
## back to the rack.
func hint() -> bool:
	if hints_left() <= 0 or is_done():
		return false
	var m: Dictionary = _st.hint_move()
	if m.is_empty():
		return false
	hints_used += 1
	_st.remember()
	for o: int in m.off:
		_st.lift(o)
	_st.place(int(m.tile), int(m.at), int(m.dir))
	_land_at[int(m.tile)] = _t + MOVE_TIME
	_press = {}
	_ghost = Vector2i(-1, 0)
	if not demo:
		fx.ring(_target(int(m.tile)), _l("cell") * 1.3, Pal.SUN)
	_cue("hint")
	_judge_beds()
	check_solved()
	if is_done():
		_solved_now()
	return true

## The bin: every tile back to its bay.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_press = {}
	_ghost = Vector2i(-1, 0)
	_say = ""
	_cue("reset")
	_judge_beds()

func _say_now(key: String) -> void:
	if _say != key:
		_say_at = _t
	_say = key

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

# --- the tutorial's hand ---

## Lays tile `t` where the answer has it, as a finger would.
func demo_lay(t: int) -> void:
	var want: Vector2i = _st.answer[t]
	if want.x < 0:
		return
	_st.place(t, want.x, want.y)
	_land_at[t] = _t + MOVE_TIME
	_judge_beds()
	check_solved()

func demo_turn(t: int) -> void:
	_tap(t)

func state():
	return _st

## Where a finger holding tile `t` presses, in this board's pixels.
func tile_to_local(t: int) -> Vector2:
	return _shown_pos(t)

## Where tile `t`'s answer puts its middle, in this board's pixels.
func answer_to_local(t: int) -> Vector2:
	var want: Vector2i = _st.answer[t]
	if want.x < 0:
		return _bay(t)
	return _patio_pos(want.x, want.y)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	for t in _st.tiles.size():
		var key := Vector2i(_st.at[t], _st.dir[t])
		if key != _key[t]:
			# the place changed: glide there from wherever it is shown
			if (key.x != _key[t].x or _held() != t) and _move_at[t] != _t:
				_from[t] = _last_pos[t]
				_from_k[t] = _last_k[t]
				_move_at[t] = _t
			_key[t] = key
		if _st.dir[t] != _shown_dir[t]:
			var q := posmod(_st.dir[t] - _shown_dir[t], 4)
			_turn_q[t] = -1 if q == 3 else q
			_turn_at[t] = _t
			_shown_dir[t] = _st.dir[t]
		_last_pos[t] = _shown_pos(t)
		_last_k[t] = _shown_k(t)
	queue_redraw()

# --- the fingers ---

func _held() -> int:
	if _press.is_empty() or not bool(_press.moved):
		return -1
	return int(_press.t)

func _gui_input(event: InputEvent) -> void:
	if demo or is_done() or _won:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	var finger: int = event.index if (event is InputEventScreenTouch or event is InputEventScreenDrag) else -1
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()
		if event.pressed:
			if not _press.is_empty():
				return
			var t := tile_at(event.position)
			if t < 0:
				return
			_press = {"t": t, "finger": finger, "press": event.position, "point": event.position,
				"grab": _shown_pos(t) - event.position, "moved": false}
		elif not _press.is_empty() and finger == int(_press.finger):
			_press.point = event.position
			_release()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _press.is_empty() \
			and finger == int(_press.finger):
		accept_event()
		_press.point = event.position
		if not bool(_press.moved) and (event.position as Vector2).distance_to(_press.press) > TAP_PX * _u():
			_press.moved = true
			var t := int(_press.t)
			# it grows to the patio's size about the finger, and rides over it
			_from[t] = _shown_pos(t)
			_from_k[t] = _shown_k(t)
			_move_at[t] = _t
			_cue("pick")
		if bool(_press.moved):
			_ghost = _drop_at(int(_press.t), _held_centre())

## The tile under a finger at `local`: one on the patio by its squares, one
## on the rack by its bay; -1 for none.
func tile_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var c := _square_at(local)
	if _st.on_patio(c) and _st.cover[_st.idx(c)] >= 0:
		return _st.cover[_st.idx(c)]
	var half := _l("rack") * BAY * 0.5
	var best := -1
	var far := INF
	for t in _st.tiles.size():
		if _st.at[t] >= 0:
			continue
		var d := local - _bay(t)
		if absf(d.x) <= half and absf(d.y) <= half and d.length() < far:
			far = d.length()
			best = t
	return best

func _release() -> void:
	var t := int(_press.t)
	var moved := bool(_press.moved)
	var point: Vector2 = _press.point
	_press = {}
	if not moved:
		_tap(t)
		return
	var drop := _drop_at(t, point + (_held_centre_offset()))
	_ghost = Vector2i(-1, 0)
	_from[t] = point + _held_centre_offset()
	_from_k[t] = _l("cell")
	_move_at[t] = _t
	if drop.x >= 0:
		if drop.x == _st.at[t] and drop.y == _st.dir[t]:
			_cue("set", 0.94)
			return
		_st.remember()
		_st.place(t, drop.x, drop.y)
		_land_at[t] = _t + MOVE_TIME * 0.6
		_changed("set")
		return
	if _over_patio(point):
		_refuse(t)
		return
	if _st.at[t] >= 0:
		_st.remember()
		_st.lift(t)
		_changed("lift")
		return
	_cue("back")

## A tap: a quarter turn clockwise. On the rack it is free; on the patio it
## turns about its first square, then about its second, the first way that
## fits, or is refused.
func _tap(t: int) -> void:
	if _st.at[t] < 0:
		_st.dir[t] = (_st.dir[t] + 1) % 4
		_cue("turn")
		return
	var a: int = _st.at[t]
	var d: int = _st.dir[t]
	var b: int = _st.other(a, d)
	for k in range(1, 4):
		var nd := (d + k) % 4
		if _st.fits(t, a, nd):
			_st.remember()
			_st.place(t, a, nd)
			_changed("turn")
			return
	for k in range(1, 4):
		# about the second square: the first number goes round it
		var nd := (d + 2 + k) % 4
		var na := _st.other(b, nd)
		if na >= 0 and _st.fits(t, na, (nd + 2) % 4):
			_st.remember()
			_st.place(t, na, (nd + 2) % 4)
			_changed("turn")
			return
	_refuse(t)

func _refuse(t: int) -> void:
	_refused_at[t] = _t
	_refusals += 1
	_cue("refuse")

## The two squares a held tile with its middle at `centre` would take: the
## nearest pair that fits within REACH, as (anchor, dir); (-1, 0) for none.
func _drop_at(t: int, centre: Vector2) -> Vector2i:
	var d: int = _st.dir[t]
	var cell := _l("cell")
	var first := centre - Vector2(DIRS[d]) * cell * 0.5
	var o := _origin()
	var raw := (first - o) / cell - Vector2(0.5, 0.5)
	var best := Vector2i(-1, 0)
	var far := REACH
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(roundi(raw.x) + dx, roundi(raw.y) + dy)
			if not _st.on_patio(c):
				continue
			var dist := (Vector2(c) - raw).length()
			if dist < far and _st.fits(t, _st.idx(c), d):
				far = dist
				best = Vector2i(_st.idx(c), d)
	return best

func _held_centre_offset() -> Vector2:
	return Vector2(0.0, -HOLD_LIFT * _l("cell"))

func _held_centre() -> Vector2:
	return (_press.point as Vector2) + _held_centre_offset()

func _over_patio(local: Vector2) -> bool:
	var o := _origin()
	var cell := _l("cell")
	return Rect2(o - Vector2.ONE * cell * 0.3, Vector2(_st.cols, _st.rows) * cell + Vector2.ONE * cell * 0.6).has_point(local)

func _square_at(local: Vector2) -> Vector2i:
	var q := (local - _origin()) / _l("cell")
	return Vector2i(floori(q.x), floori(q.y))

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	var was := _won
	_won = won
	if won and not was and not _L.is_empty():
		_lfrom = _L.duplicate()
		_lay_at = _t
	_relayout()

func set_shift(x: float, leaving := false) -> void:
	_shift = x
	position.x = x
	if _world != null:
		_world.position.x = -x
		_world.visible = not leaving

func skip_entrance() -> void:
	_enter_at = -10.0

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _st.tiles.is_empty():
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(float(_L.wall), float(_L.foot))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 200.0 * u)
	var cols: int = _st.cols
	var rows: int = _st.rows
	var n: int = _st.tiles.size()
	var room := w - 2.0 * SIDE * u
	var pad := 24.0 * u
	if _won:
		# the patio alone, in the middle of the win's span
		var cell_w := minf(room / cols, CELL_MAX * 1.1 * u)
		var cell := minf(cell_w, span * 0.8 / rows)
		var oy := top + (span - rows * cell) * 0.5
		return {"u": u, "cell": cell, "ox": (w - cols * cell) * 0.5, "oy": oy, "rack": cell * RACK_K,
			"rack_y": oy + rows * cell + GAP * u, "per_row": 5, "seen": 0.0, "wall": float(_L.get("wall", oy - 60.0 * u)),
			"foot": float(_L.get("foot", bottom))}
	var cell := minf(room / cols, CELL_MAX * u)
	var per_row := 5
	var rack_rows := 1
	while cell > 30.0 * u:
		var rc := cell * RACK_K
		per_row = maxi(1, floori(room / (rc * BAY)))
		rack_rows = ceili(float(n) / per_row)
		var need := pad + rows * cell + GAP * u + rack_rows * rc * BAY + pad
		if need <= span:
			break
		cell -= 2.0 * u
	var rc2 := cell * RACK_K
	var oy2 := top + pad
	var rack_y := oy2 + rows * cell + GAP * u
	return {"u": u, "cell": cell, "ox": (w - cols * cell) * 0.5, "oy": oy2, "rack": rc2,
		"rack_y": rack_y, "per_row": per_row, "rack_rows": rack_rows, "seen": 1.0,
		"wall": oy2 - 30.0 * u, "foot": rack_y + rack_rows * rc2 * BAY}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L.get(key, 0.0))
	if _lfrom.is_empty() or not _lfrom.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_lfrom[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _origin() -> Vector2:
	return Vector2(_l("ox"), _l("oy"))

func _patio_centre() -> Vector2:
	return _origin() + Vector2(_st.cols, _st.rows) * _l("cell") * 0.5

## The middle of a tile laid at `a` turned `d`.
func _patio_pos(a: int, d: int) -> Vector2:
	var cell := _l("cell")
	return _origin() + (Vector2(_st.cell(a)) + Vector2(0.5, 0.5)) * cell + Vector2(DIRS[d]) * cell * 0.5

## Tile `t`'s bay on the rack, its middle.
func _bay(t: int) -> Vector2:
	var per := int(_L.get("per_row", 5))
	var n: int = _st.tiles.size()
	var row := t / per
	var in_row := mini(per, n - row * per)
	var step := _l("rack") * BAY
	var x := size.x * 0.5 + (t % per - (in_row - 1) * 0.5) * step
	return Vector2(x, _l("rack_y") + (row + 0.5) * step)

## Where tile `t` belongs now, and how big a half of it is there.
func _target(t: int) -> Vector2:
	if _st.at[t] >= 0:
		return _patio_pos(_st.at[t], _st.dir[t])
	return _bay(t)

func _target_k(t: int) -> float:
	return _l("cell") if _st.at[t] >= 0 else _l("rack")

func _shown_pos(t: int) -> Vector2:
	if _held() == t:
		var to := _held_centre()
		var e := (_t - _move_at[t]) / Motion.LIFT_TIME
		return _from[t].lerp(to, Motion.back_out(clampf(e, 0.0, 1.0))) if e < 1.0 else to
	var e := (_t - _move_at[t]) / MOVE_TIME
	if e >= 1.0 or Motion.reduce:
		return _target(t)
	return _from[t].lerp(_target(t), Motion.back_out(clampf(e, 0.0, 1.0)))

func _shown_k(t: int) -> float:
	if _held() == t:
		var e := (_t - _move_at[t]) / Motion.LIFT_TIME
		var k := _l("cell") * Motion.LIFT_SCALE
		return lerpf(_from_k[t], k, clampf(e, 0.0, 1.0))
	var e := (_t - _move_at[t]) / MOVE_TIME
	if e >= 1.0 or Motion.reduce:
		return _target_k(t)
	return lerpf(_from_k[t], _target_k(t), clampf(e, 0.0, 1.0))

## A bed's tag: over the top left corner of its first square.
func _tag_at(b: int) -> Vector2:
	var first: int = (_st.beds[b].cells as Array).min()
	var cell := _l("cell")
	return _origin() + Vector2(_st.cell(first)) * cell + Vector2.ONE * cell * 0.2

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.tiles.is_empty():
		return
	var e := _t - _enter_at - Motion.ENTER_DELAY
	if e < 0.0:
		return
	var pop := Motion.wide_pop_scale(e) if e < Motion.ENTER_POP else 1.0
	_draw_patio(pop)
	_draw_rack()
	_draw_ghost()
	var held := _held()
	for t in _st.tiles.size():
		if t != held:
			_draw_tile(t, e)
	_draw_tags(e)
	if held >= 0:
		_draw_tile(held, e)
	_draw_say()

## The patio: a raised bed of stone squares, each bed's own colour, a line
## round every bed. One cached mesh a layout.
func _draw_patio(pop: float) -> void:
	var cell := _l("cell")
	var o := _origin()
	var key := "%d:%d:%d" % [roundi(cell * 10.0), roundi(o.x), roundi(o.y)]
	if key != _patio_key:
		_patio_key = key
		_patio_mesh = _build_patio(cell, o)
	var mid := _patio_centre()
	draw_mesh(_patio_mesh, null, Transform2D(0.0, Vector2.ONE * pop, 0.0, mid - mid * pop))

func _build_patio(cell: float, o: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var u := _u()
	var r := cell * 0.12
	# the bed's raised edge and its shadow on the terrace
	for i in _st.bed_of.size():
		if _st.bed_of[i] < 0:
			continue
		var at := o + Vector2(_st.cell(i)) * cell
		b.fan(Face.Builder.round_rect(at + Vector2(-cell * 0.08, cell * 0.02), Vector2.ONE * cell * 1.16, r * 1.4), Color(Pal.TEXT, 0.12))
	for i in _st.bed_of.size():
		if _st.bed_of[i] < 0:
			continue
		var at := o + Vector2(_st.cell(i)) * cell
		b.fan(Face.Builder.round_rect(at - Vector2.ONE * cell * 0.06, Vector2.ONE * cell * 1.12, r * 1.4), GROUT)
	for i in _st.bed_of.size():
		var bed: int = _st.bed_of[i]
		if bed < 0:
			continue
		var at := o + Vector2(_st.cell(i)) * cell
		var col: Color = _bed_colour[bed]
		var inset := cell * 0.05
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * inset + Vector2(0, cell * 0.03), Vector2.ONE * (cell - 2.0 * inset), r), col.darkened(0.12))
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * inset, Vector2.ONE * (cell - 2.0 * inset), r), col)
		b.fan(Face.Builder.round_rect(at + Vector2.ONE * inset * 2.2, Vector2(cell - 4.4 * inset, cell * 0.22), r * 0.6), Color(1, 1, 1, 0.16))
	# a bed's line: along each side of its squares that meets another bed,
	# carried over the grout between two squares of the same bed
	for i in _st.bed_of.size():
		var bed: int = _st.bed_of[i]
		if bed < 0 or int(_st.beds[bed].rule) == Rule.NONE:
			continue
		var col: Color = _bed_colour[bed].darkened(0.38)
		var c: Vector2i = _st.cell(i)
		var at := o + Vector2(c) * cell
		var k := cell * 0.09
		var w := 3.5 * u
		if _border(c, Vector2i(0, -1)):
			b.stroke(PackedVector2Array([at + Vector2(k, k), at + Vector2(cell - k, k)]), w, col)
		if _border(c, Vector2i(1, 0)):
			b.stroke(PackedVector2Array([at + Vector2(cell - k, k), at + Vector2(cell - k, cell - k)]), w, col)
		if _border(c, Vector2i(0, 1)):
			b.stroke(PackedVector2Array([at + Vector2(k, cell - k), at + Vector2(cell - k, cell - k)]), w, col)
		if _border(c, Vector2i(-1, 0)):
			b.stroke(PackedVector2Array([at + Vector2(k, k), at + Vector2(k, cell - k)]), w, col)
		if not _border(c, Vector2i(1, 0)):
			var n := c + Vector2i(1, 0)
			for side: Array in [[Vector2i(0, -1), k], [Vector2i(0, 1), cell - k]]:
				if _border(c, side[0]) and _border(n, side[0]):
					b.stroke(PackedVector2Array([at + Vector2(cell - k, side[1]), at + Vector2(cell + k, side[1])]), w, col)
		if not _border(c, Vector2i(0, 1)):
			var n := c + Vector2i(0, 1)
			for side: Array in [[Vector2i(-1, 0), k], [Vector2i(1, 0), cell - k]]:
				if _border(c, side[0]) and _border(n, side[0]):
					b.stroke(PackedVector2Array([at + Vector2(side[1], cell - k), at + Vector2(side[1], cell + k)]), w, col)
	return b.mesh()

## Whether square `c`'s side toward `d` ends its bed.
func _border(c: Vector2i, d: Vector2i) -> bool:
	var n := c + d
	return not (_st.on_patio(n) and _st.bed_of[_st.idx(n)] == _st.bed_of[_st.idx(c)])

## The rack: a wooden tray across the terrace, a bay a tile, the empty ones
## drawn so the rack never reads as nothing. Fades on the win.
func _draw_rack() -> void:
	var seen := _l("seen")
	if seen <= 0.01:
		return
	var rc := _l("rack")
	var key := "%d:%d:%d" % [roundi(rc * 10.0), roundi(_l("rack_y")), _st.tiles.size()]
	if key != _rack_key:
		_rack_key = key
		var b := Face.Builder.new()
		var u := _u()
		var step := rc * BAY
		var per := int(_L.get("per_row", 5))
		var rows := ceili(float(_st.tiles.size()) / per)
		var wide := minf(per, _st.tiles.size()) * step + 30.0 * u
		var at := Vector2(size.x * 0.5 - wide * 0.5, _l("rack_y") - 15.0 * u)
		var sz := Vector2(wide, rows * step + 30.0 * u)
		Scenery.soft_disc(b, at + Vector2(sz.x * 0.5, sz.y + 6.0 * u), sz.x * 0.55, 22.0 * u, Color(Pal.TEXT, 0.18))
		b.fan(Face.Builder.round_rect(at + Vector2(0, 8.0 * u), sz, 26.0 * u), TRAY_DEEP)
		b.fan(Face.Builder.round_rect(at, sz, 26.0 * u), TRAY)
		b.fan(Face.Builder.round_rect(at + Vector2(10.0, 10.0) * u, sz - Vector2(20.0, 20.0) * u, 18.0 * u), TRAY_LIT)
		for t in _st.tiles.size():
			var c := _bay(t)
			b.stroke(Face.Builder.round_rect(c - Vector2(rc * 1.05, rc * 0.55), Vector2(rc * 2.1, rc * 1.1), rc * 0.2),
				2.0 * u, Color(BAY_INK, 0.35), true)
		_rack_mesh = b.mesh()
	draw_mesh(_rack_mesh, null, Transform2D.IDENTITY, Color(1, 1, 1, seen))

## The two squares a held tile would take: a soft leaf outline.
func _draw_ghost() -> void:
	var held := _held()
	if held < 0 or _ghost.x < 0:
		return
	var cell := _l("cell")
	var a := _ghost.x
	var b: int = _st.other(a, _ghost.y)
	var o := _origin()
	var p0 := o + Vector2(_st.cell(a)) * cell
	var p1 := o + Vector2(_st.cell(b)) * cell
	var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) + Vector2.ONE * cell * 0.06
	var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2.ONE * cell * 0.94
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	draw_rect(Rect2(lo, hi - lo), Color(Pal.SURFACE, 0.35 + 0.15 * pulse))
	draw_polyline(Face.Builder.round_rect(lo, hi - lo, cell * 0.14), Color(LEAF, 0.85), 4.0 * _u(), true)

func _mesh(t: int, d: int) -> ArrayMesh:
	var key := t * 4 + d
	if not _meshes.has(key):
		var v: Vector2i = _st.tiles[t]
		var b := Face.Builder.new()
		var first := v.x if d < 2 else v.y
		var second := v.y if d < 2 else v.x
		Tile.face(b, first, second, d % 2 == 1, v.x == v.y)
		_meshes[key] = b.mesh()
	return _meshes[key]

func _draw_tile(t: int, e: float) -> void:
	var pos := _shown_pos(t)
	var k := _shown_k(t) / Tile.H
	var on_rack: bool = _st.at[t] < 0 and _held() != t
	var seen := 1.0
	if on_rack:
		seen = _l("seen")
		if seen <= 0.01:
			return
		# the rack's tiles pop in after the patio
		var pe := e - 0.2 - t * Motion.ENTER_STAGGER * 2.0
		if pe < 0.0:
			return
		if pe < Motion.POP_IN:
			k *= Motion.pop_in_scale(pe).x
	var angle := 0.0
	var turn := _t - _turn_at[t]
	if turn < Motion.TURN_TIME and not Motion.reduce:
		angle = Motion.turn_angle(turn, _turn_q[t]) - _turn_q[t] * PI * 0.5
	var land := _t - _land_at[t]
	var sx := 1.0
	var sy := 1.0
	if land >= 0.0 and land < Motion.BUMP_TIME:
		var bump := Motion.bump_scale(land, 0.1)
		sx = bump
		sy = 1.0 / bump
	var shake := 0.0
	var refused := _t - _refused_at[t]
	if refused < REFUSE_TIME:
		shake = Motion.shiver_offset(refused, 6.0 * _u(), REFUSE_TIME * 0.6)
	var lift := 0.0
	if is_done() and _won_at > -INF and _st.at[t] >= 0:
		var c: Vector2i = _st.cell(_st.at[t])
		var wave := _t - _won_at - (c.x + c.y) * WAVE_STEP
		if wave > 0.0:
			lift = Motion.hop_lift(wave, Motion.SOLVE_HOP * 2.0 * _u(), Motion.SOLVE_TIME)
	var at := pos + Vector2(shake, lift)
	if refused < REFUSE_TIME:
		# a rose halo round the refused tile's own shape, never its paint
		var a := 1.0 - refused / REFUSE_TIME
		var half := Vector2(Tile.H, Tile.H * 0.5) * k if _st.dir[t] % 2 == 0 else Vector2(Tile.H * 0.5, Tile.H) * k
		draw_polyline(Face.Builder.round_rect(at - half * 1.08, half * 2.16, Tile.H * 0.2 * k), Color(Pal.BAD, 0.85 * a), 6.0 * _u(), true)
	draw_mesh(_mesh(t, _shown_dir[t]), null, Transform2D(angle, Vector2(k * sx, k * sy), 0.0, at), Color(1, 1, 1, seen))

## Each bed's tag on its first square's corner: its rule, a leaf tick when
## kept, a rose ring when broken.
func _draw_tags(e: float) -> void:
	var cell := _l("cell")
	var font: Font = CozyTheme.display(700)
	var u := _u()
	for b in _st.beds.size():
		var info: Dictionary = _st.beds[b]
		if int(info.rule) == Rule.NONE:
			continue
		var te: float = e - 0.1 - b * Motion.ENTER_STAGGER * 2.0
		if te < 0.0:
			continue
		var c := _tag_at(b)
		var r := cell * TAG * 0.5
		var drop := -Motion.drop_in_lift(te, Motion.DROP * u) if te < Motion.DROP_TIME else 0.0
		var state: int = _bed_was[b]
		var kept := _t - _kept_at[b]
		var broke := _t - _broke_at[b]
		var s := 1.0
		if kept < Motion.BUMP_TIME:
			s = Motion.bump_scale(kept, 0.3)
		var shake := Motion.shiver_offset(broke, 5.0 * u, Motion.SHIVER_TIME * 2.0) if broke < Motion.SHIVER_TIME * 2.0 else 0.0
		var at := c + Vector2(shake, drop)
		var deep: Color = _bed_colour[b].darkened(0.38)
		var text := State.tag(info)
		var fs := roundi(cell * TAG_FONT)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if int(info.rule) != Rule.SAME and int(info.rule) != Rule.APART else 0.0
		var half := Vector2(maxf(r, tw * 0.5 + r * 0.45), r) * s
		if state == State.Bed.BROKEN:
			draw_polyline(Face.Builder.round_rect(at - half - Vector2.ONE * 5.0 * u, half * 2.0 + Vector2.ONE * 10.0 * u, half.y + 5.0 * u),
				Color(Pal.BAD, 0.9), 4.0 * u, true)
		draw_colored_polygon(Face.Builder.round_rect(at - half + Vector2(0, 3.0 * u), half * 2.0, half.y), Color(deep, 0.6))
		draw_colored_polygon(Face.Builder.round_rect(at - half, half * 2.0, half.y), Pal.SURFACE)
		draw_polyline(Face.Builder.round_rect(at - half, half * 2.0, half.y), deep, 2.5 * u, true)
		match int(info.rule):
			Rule.SAME, Rule.APART:
				var bw := r * 0.62 * s
				var th := maxf(2.0, r * 0.16)
				draw_line(at + Vector2(-bw, -r * 0.2 * s), at + Vector2(bw, -r * 0.2 * s), Pal.TEXT, th, true)
				draw_line(at + Vector2(-bw, r * 0.2 * s), at + Vector2(bw, r * 0.2 * s), Pal.TEXT, th, true)
				if int(info.rule) == Rule.APART:
					draw_line(at + Vector2(r * 0.3, -r * 0.62) * s, at + Vector2(-r * 0.3, r * 0.62) * s, Pal.TEXT, th, true)
			_:
				var asc := font.get_ascent(fs) - font.get_descent(fs)
				draw_set_transform(at, 0.0, Vector2.ONE * s)
				draw_string(font, Vector2(-tw * 0.5, asc * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
				draw_set_transform(Vector2.ZERO)
		if state == State.Bed.KEPT:
			var tick := at + Vector2(half.x * 0.85, -half.y * 0.75)
			var tk := r * 0.42 * (Motion.pop_in_scale(kept).x if kept < Motion.POP_IN else 1.0)
			draw_circle(tick, tk, Pal.GOOD)
			draw_polyline(PackedVector2Array([tick + Vector2(-tk * 0.45, 0.0), tick + Vector2(-tk * 0.1, tk * 0.35),
				tick + Vector2(tk * 0.5, -tk * 0.35)]), Pal.SURFACE, maxf(2.0, tk * 0.28), true)

## A word over the rack when the patio is covered but a bed is unhappy.
func _draw_say() -> void:
	if _say == "" or is_done() or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var text := tr(_say)
	var fs := roundi(SAY_SIZE * u)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var k := Motion.pop_in_scale(_t - _say_at, 0.25).x if _t - _say_at < 0.25 else 1.0
	var y := _l("rack_y") - GAP * u * 0.3
	draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * k)
	draw_string_outline(font, Vector2(-tw * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * u), Color(Pal.SURFACE, 0.9))
	draw_string(font, Vector2(-tw * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	draw_set_transform(Vector2.ZERO)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func share_glyphs() -> String:
	return "🌼 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("DP_WIN")}

func completion_record() -> Dictionary:
	return {"at": Array(_st.at), "dir": Array(_st.dir)}

## A finished day reopens with its tiles where they were laid.
func restore_completed_board() -> void:
	var rec := completed_record
	if not _st.finish_from(rec.get("at", []) as Array, rec.get("dir", []) as Array):
		_st.finish()
	for t in _st.tiles.size():
		_key[t] = Vector2i(_st.at[t], _st.dir[t])
		_shown_dir[t] = _st.dir[t]
		_move_at[t] = -INF
	for b in _st.beds.size():
		_bed_was[b] = _st.bed(b)
	_won_at = -INF
	queue_redraw()
