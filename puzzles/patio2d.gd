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
const StarLine = preload("res://ui/flat/star_line.gd")
const Toast = preload("res://ui/flat/toast_card.gd")
const Rewards = preload("res://arcade/rewards.gd")

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
## Made fun (2026-10-29): the stars by slips (beds broken, bulbs read: none
## 3, up to two 2, more 1), their row over the patio, a run's climb in
## pitch, the toast's letters and padding, the running sum's chip under a
## tag, and the bed lines laid over the tiles.
const STARS_CUT := [0, 2]
const STAR_ROW := 64.0
const RUN_STEP := 0.05
const TOAST_SIZE := 30
const TOAST_PAD := Vector2(26.0, 16.0)
const SUM_FONT := 0.24
const LINES_OVER := 0.95

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
## Made fun: the stars, the toast, the big words, the bulb's standing
## reading (State.read_hint, {} for none), the slips, the run of tiles
## that kept a bed and the best, what the ghost's drop would do (-1 break,
## 1 keep, 0 neither), the bed a toast is about (-1 none) and the meshes of
## the rims and of the bed lines over the tiles.
var _stars := StarLine.new()
var _toast := Toast.new()
var _rw: Rewards
var _reading := {}
var _slips := 0
var _run := 0
var _best_run := 0
var _ghost_says := 0
var _told_bed := -1
var _rim_mesh: ArrayMesh
var _rim_key := ""
var _lines_mesh: ArrayMesh
var _lines_key := ""

func puzzle_id() -> String: return "patio"
func title() -> String: return "Domino Patio"

func rules() -> String:
	var out := tr("DP_RULES")
	out += "\n\n" + tr("DP_RULES_TAGS")
	out += "\n\n" + tr("DP_RULES_HELP")
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	if not demo:
		fx = Fx2D.new()
		fx.name = "Fx"
		fx.haptics = HAPTICS
		add_child(fx)
		_rw = Rewards.new()
		_rw.name = "Rewards"
		_rw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rw.z_index = 4
		add_child(_rw)
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
	_lines_key = ""
	_rim_key = ""
	_reading = {}
	_toast.clear()
	_told_bed = -1
	_slips = 0
	_run = 0
	_best_run = 0
	_stars.clear(3)
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
	if not _reading.is_empty():
		# a move by hand puts a standing reading out (laid as read, it was free)
		_reading = {}
		_toast.clear()
	moved.emit()
	# a tile laid is a pop varied a little each time (the house sound)
	_cue(sound, randf_range(0.94, 1.06) if sound == "set" else 1.0)
	_judge_beds(sound == "set")
	check_solved()
	if is_done():
		_solved_now()

## Each bed that came to be kept or broken by the move just made says so.
## Made fun: a bed newly broken is a slip (a star may fall) and its toast
## says why; a tile laid that keeps a bed and breaks none carries the run
## on, and the run and the beds kept climb in pitch; one that breaks a bed
## ends it. `laid`: the move was a tile set down.
func _judge_beds(laid := false) -> void:
	var kept := 0
	var broke := -1
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
				broke = b
				_cue("broken")
			_bed_was[b] = now
	if broke >= 0:
		_run = 0
		if laid and not demo:
			_slips += 1
			_rate(true)
			_tell_bed(broke)
	elif laid and kept > 0:
		_run += 1
		_best_run = maxi(_best_run, _run)
	if kept > 0:
		_cue("bed", 1.0 + 0.06 * mini(kept - 1, 4) + RUN_STEP * mini(maxi(_run - 1, 0), 5))
		if broke < 0 and not demo:
			_cheer(kept)
	if _told_bed >= 0 and _st.bed(_told_bed) != State.Bed.BROKEN:
		# the bed the toast was about is mended: the toast goes with it
		_told_bed = -1
		_toast.clear()
	if _st.covered() and not _st.solved() and broke < 0 and _told_bed < 0:
		_say_now("DP_ALMOST")
	elif not _st.covered() and _say == "DP_ALMOST":
		_say = ""

## The stars the day's slips leave; `heard`: a lost one falls.
func _rate(heard: bool) -> void:
	var w := _slips
	_stars.rate(3 if w <= int(STARS_CUT[0]) else (2 if w <= int(STARS_CUT[1]) else 1), _t, heard)

## A tile that keeps two beds at once, or a run of three tiles each keeping
## one: a big word over the patio and a spray of stars.
func _cheer(kept: int) -> void:
	if _rw == null or is_done():
		return
	var text := ""
	if kept >= 2:
		text = tr("DP_W_TWO") if kept == 2 else tr("DP_W_MANY") % kept
	elif _run >= 3:
		text = tr("DP_W_RUN") % _run
	if text == "":
		return
	var at := _rw.at(self, _patio_centre() - Vector2(0.0, _l("cell") * _st.rows * 0.5 + 10.0 * _u()))
	var big := mini(maxi(_run, kept) - 2, 3)
	_rw.sticker(text, at, roundi((70.0 + 6.0 * big) * _u()), 1.3, true, Color.WHITE, kept >= 2 or _run >= 4, "run", 20.0)
	_rw.spray(at, Pal.SUN, 8 + 3 * big, 600.0, "star", 1.0)

## A bed just broken says why, on the toast, its squares rimmed rose.
func _tell_bed(b: int) -> void:
	var line := _bed_line(b)
	if line == "":
		return
	_told_bed = b
	_say = ""
	_toast.say(line, _t)

## The sentence for bed `b`'s break (State.bed_why).
func _bed_line(b: int) -> String:
	var why: Dictionary = _st.bed_why(b)
	if why.is_empty():
		return ""
	match String(why.why):
		"over": return tr("DP_BAD_OVER") % [int(why.a), int(why.b)]
		"short": return tr("DP_BAD_SHORT") % [int(why.a), int(why.b)]
		"less": return tr("DP_BAD_LESS") % [int(why.a), int(why.b)]
		"more": return tr("DP_BAD_MORE") % [int(why.a), int(why.b)]
		"same": return tr("DP_BAD_SAME") % [int(why.a), int(why.b)]
		"apart": return tr("DP_BAD_APART") % int(why.a)
	return ""

func _solved_now() -> void:
	_won_at = _t
	_say = ""
	_press = {}
	_ghost = Vector2i(-1, 0)
	_reading = {}
	_told_bed = -1
	_toast.clear()
	_cue("solved")
	if not demo:
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			fx.confetti(_patio_centre() - Vector2(0, _l("cell") * _st.rows * 0.4), 26, size.x * 0.7)
			# three stars kept: the party's toots
			_cue("party" if _stars.stars >= 3 else "confetti"))

func is_solved() -> bool:
	return _st.solved()

func undo() -> bool:
	if not can_undo() or not _st.undo():
		return false
	_press = {}
	_ghost = Vector2i(-1, 0)
	_reading = {}
	_cue("undo")
	_judge_beds()
	return true

## Made fun: the bulb teaches, in two presses. The first reads the patio
## (State.read_hint: a bed broken, a square only one tile can cover, a tile
## with only one place, else the tile with the fewest), rims the tile and
## the squares it goes to in sun and says why, for one hint. A second press
## while the reading stands, or the tile laid there by hand, lays it, free.
func hint() -> bool:
	if is_done():
		return false
	if not _reading.is_empty():
		return _lay_hint()
	if _hints_held() <= 0:
		return false
	var m: Dictionary = _st.read_hint()
	if m.is_empty():
		return false
	hints_used += 1
	_reading = m
	_told_bed = -1
	_say = ""
	if not demo:
		_slips += 1
		_rate(true)
		_toast.say(_read_line(m), _t, true)
		fx.ring(_answer_mid(m), _l("cell") * 1.3, Pal.SUN)
	_cue("hint")
	moved.emit()
	return true

## The bulb's second press: the tile it read, laid where it goes; what lay
## there goes back to the rack.
func _lay_hint() -> bool:
	var m := _reading
	_reading = {}
	_toast.clear()
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
	moved.emit()
	return true

func hints_left() -> int:
	return _hints_held() + (0 if _reading.is_empty() else 1)

func _hints_held() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

## The middle of the two squares a reading lays its tile on.
func _answer_mid(m: Dictionary) -> Vector2:
	return _patio_pos(int(m.at), int(m.dir))

## The sentence for a reading (State.read_hint).
func _read_line(m: Dictionary) -> String:
	var v: Vector2i = _st.tiles[int(m.tile)]
	var name := "%d|%d" % [v.x, v.y]
	var line := ""
	match String(m.get("kind", "")):
		"broken":
			line = _bed_line(int(m.bed)) + " " + tr("DP_READ_BROKEN") % name
		"square":
			line = tr("DP_READ_SQUARE") % name
		"tile":
			line = tr("DP_READ_TILE") % name
		_:
			var n := int(m.get("places", 0))
			line = tr("DP_READ_FEWEST") % [name, n] if n >= 2 else tr("DP_READ_HERE") % name
	return line + " " + tr("DP_READ_AGAIN")

## The bin: every tile back to its bay.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_press = {}
	_ghost = Vector2i(-1, 0)
	_say = ""
	_reading = {}
	_told_bed = -1
	_toast.clear()
	_run = 0
	_cue("reset")
	_judge_beds()

## A short word on the toast (the patio covered with a bed unhappy).
func _say_now(key: String) -> void:
	if _say != key:
		_say_at = _t
		if not demo:
			_toast.say(tr(key), _t)
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
	if _rw != null:
		_rw.step(delta)
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
			var g := _drop_at(int(_press.t), _held_centre())
			if g != _ghost:
				_ghost = g
				_ghost_says = _st.try_drop(int(_press.t), g.x, g.y) if g.x >= 0 else 0

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
		var need := pad + STAR_ROW * u + rows * cell + GAP * u + rack_rows * rc * BAY + pad
		if need <= span:
			break
		cell -= 2.0 * u
	var rc2 := cell * RACK_K
	var oy2 := top + pad + STAR_ROW * u
	var rack_y := oy2 + rows * cell + GAP * u
	return {"u": u, "cell": cell, "ox": (w - cols * cell) * 0.5, "oy": oy2, "rack": rc2,
		"rack_y": rack_y, "per_row": per_row, "rack_rows": rack_rows, "seen": 1.0,
		"wall": oy2 - 30.0 * u - STAR_ROW * u, "foot": rack_y + rack_rows * rc2 * BAY, "bottom": bottom}

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
	_draw_lines(pop)
	_draw_rims()
	_draw_tags(e)
	if held >= 0:
		_draw_tile(held, e)
	_draw_stars(e)
	_draw_toast()

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
	_bed_lines(b, cell, o, -1, Color())
	return b.mesh()

## A bed's line: along each side of its squares that meets another bed,
## carried over the grout between two squares of the same bed. `only` >= 0
## draws that bed's alone in `colour`, thicker (a rim).
func _bed_lines(b: Face.Builder, cell: float, o: Vector2, only: int, colour: Color, thick := 3.5) -> void:
	var u := _u()
	for i in _st.bed_of.size():
		var bed: int = _st.bed_of[i]
		if bed < 0 or int(_st.beds[bed].rule) == Rule.NONE and only < 0:
			continue
		if only >= 0 and bed != only:
			continue
		var col: Color = _bed_colour[bed].darkened(0.38) if only < 0 else colour
		var c: Vector2i = _st.cell(i)
		var at := o + Vector2(c) * cell
		var k := cell * 0.09
		var w := (thick if only < 0 else 6.0) * u
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
	# made fun: the drop's outcome before it is made -- rose when it would
	# break a bed, sun when it would fill one to its rule
	var ink := LEAF
	var fill := Pal.SURFACE
	if _ghost_says < 0:
		ink = Pal.BAD
		fill = Color(Pal.BAD).lerp(Pal.SURFACE, 0.6)
	elif _ghost_says > 0:
		ink = Pal.SUN
	draw_rect(Rect2(lo, hi - lo), Color(fill, 0.35 + 0.15 * pulse))
	draw_polyline(Face.Builder.round_rect(lo, hi - lo, cell * 0.14), Color(ink, 0.9), (4.0 if _ghost_says == 0 else 6.0) * _u(), true)

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
		if state == State.Bed.OPEN and int(info.rule) in [Rule.SUM, Rule.LESS, Rule.MORE] and (info.cells as Array).size() >= 2:
			# made fun: what the bed holds so far, a small chip under its tag
			var got := _st.so_far(b)
			if got.y > 0:
				var sfs := roundi(cell * SUM_FONT)
				var st := str(got.x)
				var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
				var ch := Vector2(maxf(sw * 0.5 + sfs * 0.35, sfs * 0.6), sfs * 0.58)
				var cc := at + Vector2(0.0, half.y + ch.y + 2.0 * u)
				draw_colored_polygon(Face.Builder.round_rect(cc - ch, ch * 2.0, ch.y), Color(deep, 0.92))
				var sasc := font.get_ascent(sfs) - font.get_descent(sfs)
				draw_string(font, cc + Vector2(-sw * 0.5, sasc * 0.5), st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Pal.SURFACE)
		if state == State.Bed.KEPT:
			var tick := at + Vector2(half.x * 0.85, -half.y * 0.75)
			var tk := r * 0.42 * (Motion.pop_in_scale(kept).x if kept < Motion.POP_IN else 1.0)
			draw_circle(tick, tk, Pal.GOOD)
			draw_polyline(PackedVector2Array([tick + Vector2(-tk * 0.45, 0.0), tick + Vector2(-tk * 0.1, tk * 0.35),
				tick + Vector2(tk * 0.5, -tk * 0.35)]), Pal.SURFACE, maxf(2.0, tk * 0.28), true)

## Made fun: the bed lines again over the laid tiles, faint, so a tile's
## two halves still read as in their beds. One cached mesh a layout.
func _draw_lines(pop: float) -> void:
	var cell := _l("cell")
	var o := _origin()
	var key := "%d:%d:%d" % [roundi(cell * 10.0), roundi(o.x), roundi(o.y)]
	if key != _lines_key:
		_lines_key = key
		var b := Face.Builder.new()
		_bed_lines(b, cell, o, -1, Color(), 5.0)
		_lines_mesh = b.mesh()
	var mid := _patio_centre()
	draw_mesh(_lines_mesh, null, Transform2D(0.0, Vector2.ONE * pop, 0.0, mid - mid * pop), Color(1, 1, 1, LINES_OVER))

## Made fun: the rims. The bulb's reading in sun: the two squares its tile
## goes to (and, read off a lone square, that square thicker); a bed the
## toast says is broken in rose round its squares. One mesh made when what
## it rims changes.
func _draw_rims() -> void:
	if demo and _reading.is_empty():
		return
	var on_bed := _told_bed >= 0 and _toast.showing(_t)
	if _reading.is_empty() and not on_bed:
		return
	var cell := _l("cell")
	var o := _origin()
	var key := "%s:%d:%d:%d:%d" % [str(_reading), _told_bed if on_bed else -1, roundi(cell * 10.0), roundi(o.x), roundi(o.y)]
	if key != _rim_key:
		_rim_key = key
		var b := Face.Builder.new()
		var u := _u()
		if on_bed:
			_bed_lines(b, cell, o, _told_bed, Pal.BAD)
		if not _reading.is_empty():
			var m := _reading
			if String(m.kind) == "broken":
				_bed_lines(b, cell, o, int(m.bed), Pal.BAD)
			var p0 := o + Vector2(_st.cell(int(m.at))) * cell
			var p1 := o + Vector2(_st.cell(_st.other(int(m.at), int(m.dir)))) * cell
			var lo := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) + Vector2.ONE * cell * 0.03
			var hi := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2.ONE * cell * 0.97
			b.stroke(Face.Builder.round_rect(lo, hi - lo, cell * 0.16), 6.0 * u, Pal.SUN, true)
			if String(m.kind) == "square":
				var sq := o + Vector2(_st.cell(int(m.square))) * cell
				b.stroke(Face.Builder.round_rect(sq + Vector2.ONE * cell * 0.1, Vector2.ONE * cell * 0.8, cell * 0.14), 9.0 * u, Pal.SUN, true)
			# the tile it lays, where it lies now
			var t := int(m.tile)
			var c := _target(t)
			var k := _target_k(t) / Tile.H
			var half := Vector2(Tile.H, Tile.H * 0.5) * k if _st.dir[t] % 2 == 0 else Vector2(Tile.H * 0.5, Tile.H) * k
			b.stroke(Face.Builder.round_rect(c - half * 1.12, half * 2.24, Tile.H * 0.22 * k), 5.0 * u, Pal.SUN, true)
		_rim_mesh = b.mesh()
	var pulse := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(_t * 5.0)
	draw_mesh(_rim_mesh, null, Transform2D.IDENTITY, Color(1, 1, 1, pulse))

## Made fun: the three stars, in their row over the patio.
func _draw_stars(e: float) -> void:
	if demo or _won or is_done():
		return
	var u := _u()
	var ss := u * 1.1
	var sw := StarLine.width(ss)
	var alpha := clampf((e - 0.1) / 0.3, 0.0, 1.0)
	_stars.draw(self, Vector2(size.x * 0.5 - sw * 0.5 + StarLine.R * ss, _l("oy") - STAR_ROW * u * 0.55), ss, _t, alpha)

## Made fun: the toast, in the open terrace under the rack, or over the
## rack's top when there is no room under it.
func _draw_toast() -> void:
	if demo or is_done() or _won or not _toast.showing(_t):
		return
	var u := _u()
	var width := minf(size.x - 2.0 * SIDE * u, 900.0 * u)
	var fs := roundi(TOAST_SIZE * u)
	var pad := TOAST_PAD * u
	var tall := _toast.tall(width, fs, pad)
	var y := _l("foot") + 24.0 * u
	if y + tall > float(_L.get("bottom", size.y)) - 8.0 * u:
		y = _l("rack_y") - GAP * u * 0.5
	_toast.draw(self, Vector2(size.x * 0.5, y + tall * 0.5), width, _t, fs, pad)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func share_glyphs() -> String:
	return "🌼 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	if _best_run >= 2:
		return {"faces": [], "subtitle": tr("DP_WIN_RUN") % _best_run}
	return {"faces": [], "subtitle": tr("DP_WIN")}

func completion_record() -> Dictionary:
	return {"at": Array(_st.at), "dir": Array(_st.dir), "slips": _slips, "run": _best_run}

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
	_slips = int(rec.get("slips", 0))
	_best_run = int(rec.get("run", 0))
	_rate(false)
	_won_at = -INF
	queue_redraw()
