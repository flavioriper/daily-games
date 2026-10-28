extends "res://core/puzzle_base.gd"

## Hosepipes (spec docs/superpowers/specs/2026-10-22-hoses-design.md): a
## raised garden bed of soil squares. Each colour has a garden tap and a
## flower on the bed; drag a hose from either end to the other. Hoses never
## share a square, and the bed is done when every flower is reached and
## every square is watered. On Insane (Seedlings) some flowers are bare
## seeds, and any seed hose may water one. The rules are
## puzzles/hoses_state.gd's, the deal and its proof puzzles/hoses_gen.gd's.
##
## **The garden is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/hoses_world.gd) is the board's first child. The bed sits
## in the span and the count line under it.
##
## A drag is walked a square at a time toward the finger (a flick never
## skips a square); a finger slid back along its own hose cuts it back to
## there. Crossing another hose cuts it, with a puff; backing off again
## grows it back, because the other hoses are always the stroke's start cut
## at the live hose. A flower opens as its hose reaches it and water runs
## down the hose once. The bulb lays one hose of the answer, drawn out from
## its tap.
##
## **Made fun** (2026-10-28, docs/agents/boards/hoses.md): water runs only
## through a joined hose, darkening the soil square by square and sprouting a
## tuft on each (a daisy on each at the win); joins climb in pitch; the hose
## in hand's other end pulses; three live stars ride the count line, by
## strokes (a hose drawn in two goes on running is one); the bulb teaches in
## two presses (puzzles/hoses_reader.gd says why); a bed all joined but dry
## rings its dry squares.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/hoses_tutorial_diagram.gd plays it with `demo_press`, `demo_move`
## and `demo_release`.

const State = preload("res://puzzles/hoses_state.gd")
const Gen = preload("res://puzzles/hoses_gen.gd")
const World = preload("res://puzzles/hoses_world.gd")
const Art = preload("res://ui/faces/hoses_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Reader = preload("res://puzzles/hoses_reader.gd")
const StarLine = preload("res://ui/flat/star_line.gd")

const Step = State.Step

const HAPTICS := {
	"pick": Haptics.TICK,
	"grow": Haptics.TICK,
	"back": Haptics.TICK,
	"cut": Haptics.TAP,
	"join": Haptics.GOOD,
	"refuse": Haptics.WARN,
	"hush": Haptics.TICK,
	"dry": Haptics.WARN,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The bed: the largest square, the side margins, the frame's width in
## squares, the count line under it.
const CELL_MAX := 176.0
const SIDE := 54.0
const FRAME := 0.26
const COUNT_H := 150.0
const COUNT_SIZE := 34
const SAY_SIZE := 32
## A flower opening, the water's run down a joined hose, the bulb's hose
## drawn out, a refused end's shiver, the toast's stay.
const BLOOM_TIME := 0.42
const RUSH_TIME := 0.7
const LAY_TIME := 0.5
const REFUSE_TIME := 0.4
const SAY_TIME := 2.6
## The stars under the count line: their scale and drop below it.
const STAR_SCALE := 1.25
const STAR_DROP := 58.0
## A sprout's growing, the partner end's pulse, each join's step up.
const GROW_TIME := 0.32
const PULSE_TIME := 1.1
const JOIN_STEP := 0.05
## The win: the flowers' wave, how long the board's own win plays.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.07

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
## Per hose: whether it was joined when last seen, and when that changed.
var _joined_was: Array[bool] = []
var _bloom_at: Array[float] = []
## Per hose: when water last ran down it.
var _rush_at: Array[float] = []
## The bulb's hose being drawn out: {hose, at}; {} when none.
var _lay := {}
## A refused square's shiver.
var _refused_cell := -1
var _refused_at := -INF
## The square under the finger the last refusal was for (one tongue a square).
var _refused_for := -1
## When the hose in hand last grew, for its head's bump.
var _head_at := -INF
var _say := ""
var _say_at := -INF
var _pressing := -2
## The layout.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
var _soil: ArrayMesh
var _soil_key := ""
var _hoses: ArrayMesh
var _hoses_key := ""
var _ends: ArrayMesh
var _ends_key := ""
## The head's halo, kept while the square size stands.
var _halo: ArrayMesh
var _halo_cell := 0.0
var fx: Node
var _stars := StarLine.new()
## The bulb's reading while it stands: {hose, cell, rule, ways}; {} when none.
var _reading := {}
var _reading_mesh: ArrayMesh
var _reading_key := ""
## The dry squares rung while every hose is joined.
var _dry_mesh: ArrayMesh
var _dry_key := ""
## Square -> when water reached it (its sprout grows from then).
var _wet_at := {}

func puzzle_id() -> String: return "hoses"
func title() -> String: return "Hosepipes"

func rules() -> String:
	var out := tr("HS_RULES")
	if not _st.seeds.is_empty():
		out += "\n\n" + tr("HS_RULES_SEEDS")
	out += "\n\n" + tr("HS_RULES_CUT")
	out += "\n\n" + tr("HS_RULES_STARS")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/hoses_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.JOIN, "HTP_HS_JOIN", tr("HTP_HS_JOIN_BODY")],
		[Diagram.Lesson.WATER, "HTP_HS_WATER", tr("HTP_HS_WATER_BODY")],
		[Diagram.Lesson.CUT, "HTP_HS_CUT", tr("HTP_HS_CUT_BODY")],
	]
	if not _st.seeds.is_empty():
		steps.append([Diagram.Lesson.SEEDS, "HTP_HS_SEEDS", tr("HTP_HS_SEEDS_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_HS_HINT", tr("HTP_HS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and the bulb; Insane keeps no Undo (its seal). No Check: a flower
## opens when its hose reaches it and the count line says what is dry.
func capabilities() -> Array[String]:
	if _band >= 3:
		return ["hint"]
	return ["undo", "hint"]

func can_undo() -> bool:
	return _band < 3 and not _st.history.is_empty() and not is_done() and _st.live < 0

func hints_left() -> int:
	return hints_held() + (0 if _reading.is_empty() else 1)

func hints_held() -> int:
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
	_st.deal(rng, _band, bank_step)
	_fresh()
	_enter_at = _t
	_cue("enter")

## The tutorial's own bed: `day` (a fixed one, never today's) at `band`.
func demo_day(day: Dictionary, band: int) -> void:
	_band = clampi(band, 0, 3)
	_st.band = _band
	_st.load_day(day)
	_fresh()

## Every hose taken up, nothing in hand, nothing moving.
func _fresh() -> void:
	_joined_was.clear()
	_bloom_at.clear()
	_rush_at.clear()
	for c in _st.count():
		_joined_was.append(false)
		_bloom_at.append(-INF)
		_rush_at.append(-INF)
	_lay = {}
	_say = ""
	_reading = {}
	_wet_at = {}
	_stars.clear()
	_refused_cell = -1
	_refused_for = -1
	_soil_key = ""
	_hoses_key = ""
	_ends_key = ""
	_relayout()

func day_dict() -> Dictionary:
	if _st.ends.is_empty():
		return {}
	var banked: bool = _band >= 2 and InsaneBank.size("hoses" if _band == 3 else "hoses_hard") > 0
	return {
		"source": "bank" if banked else "generator", "kind": "grid",
		"payload": {"n": _st.n, "ends": _st.ends.duplicate(true), "seeds": _st.seeds.duplicate()},
		"solution": {"paths": _st.answer.duplicate(true)},
		"metrics": {"hoses": _st.count(), "seeds": _st.seeds.size()},
	}

# --- the moves ---

## A finger down at `local`.
func _press(local: Vector2) -> void:
	if is_done() or _won:
		return
	_finish_lay()
	var cell := cell_at(local)
	if cell < 0:
		return
	_refused_for = -1
	var c: int = _st.begin(cell)
	if c < 0:
		# bare soil or a seed: heard, and nothing happens
		_cue("hush", randf_range(0.95, 1.05))
		return
	_head_at = _t
	_cue("pick", randf_range(0.96, 1.04))
	_say = ""

## The finger at `local` while a hose is in hand: walked a square at a time.
func _drag(local: Vector2) -> void:
	if _st.live < 0 or is_done():
		return
	var target := cell_at(local, true)
	if target < 0:
		return
	var c: int = _st.live
	if (_st.hoses[c] as Array).has(target):
		if _st.back_to(target):
			_head_at = _t
			_cue("back", randf_range(0.95, 1.02))
		return
	for guard in _st.n * 2:
		var head: int = _st.head()
		if head == target:
			return
		var n: int = _st.n
		var hx := head % n
		var hy := head / n
		var dx := target % n - hx
		var dy := target / n - hy
		var tries := []
		if absi(dx) >= absi(dy):
			tries.append(head + signi(dx))
			if dy != 0:
				tries.append(head + signi(dy) * n)
		else:
			tries.append(head + signi(dy) * n)
			if dx != 0:
				tries.append(head + signi(dx))
		var heard: int = Step.NONE
		for next: int in tries:
			heard = _st.step(next)
			if heard != Step.NONE and heard != Step.REFUSE:
				break
			if heard == Step.REFUSE:
				_refuse(next, target)
		if heard == Step.NONE or heard == Step.REFUSE:
			return
		_heard(heard, c)

func _heard(heard: int, c: int) -> void:
	_head_at = _t
	var length := (_st.hoses[c] as Array).size()
	match heard:
		Step.GROW:
			_cue("grow", minf(0.9 + length * 0.025, 1.35))
		Step.BACK:
			_cue("back", randf_range(0.95, 1.02))
		Step.CUT:
			_cue("cut", randf_range(0.96, 1.04))
			if not demo and fx != null:
				for cut: Array in _st.cut_hoses():
					fx.puff(_cell_pos(int(cut[1])), Art.colour(int(cut[0])), 5)
		Step.JOIN:
			# each hose joined a step higher than the last
			_cue("join", minf(0.94 + JOIN_STEP * _st.joined_count(), 1.34))

func _refuse(cell: int, target: int) -> void:
	if _refused_for == target:
		return
	_refused_for = target
	_refused_cell = cell
	_refused_at = _t
	_cue("refuse")

## The finger lifted: the stroke is one move if it changed the bed.
func _release() -> void:
	if _st.live < 0:
		return
	if _st.end_stroke():
		moves += 1
		_reading = {}
		_rate(true)
		moved.emit()
	_after_change()

func _after_change() -> void:
	if _st.solved():
		_phase_solved()
	elif _st.all_joined_dry():
		_say_now("HS_SAY_DRY|HS_SAY_DRY_HOW")
		_cue("dry")

func _phase_solved() -> void:
	check_solved()
	if not is_done():
		return
	_won_at = _t + 0.35
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(0.3, false).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_cue("solved")
		if not demo and fx != null:
			fx.confetti(Vector2(size.x * 0.5, _l("oy") + _l("cell") * _st.n * 0.4), 26, size.x * 0.7)
			# every hose drawn in one go, and no bulb: the party
			_cue("party" if _perfect() else "confetti"))

func _perfect() -> bool:
	return _st.strokes <= _st.count() and hints_used == 0

func is_solved() -> bool:
	return _st.solved()

func undo() -> bool:
	if not can_undo():
		return false
	_finish_lay()
	if not _st.undo():
		return false
	_say = ""
	_reading = {}
	_cue("undo")
	return true

## The bulb: the first hose not as the answer has it, laid as the answer
## has it and drawn out from its tap; what was in its way is cut.
##
## Made fun (2026-10-28): the bulb teaches, in two presses. The first reads
## the bed the way a player can (puzzles/hoses_reader.gd, on from the links
## the player has right): it rims the square that decides a hose and the
## squares it must link to, and says why, for one hint. The player may draw
## it themselves; a second press while the reading stands lays that hose,
## free. Where no square decides anything yet, it rims the pair's two ends.
func hint() -> bool:
	if is_done():
		return false
	if _st.live >= 0:
		_release()
	_finish_lay()
	if not _reading.is_empty():
		var lay := int(_reading.hose)
		_reading = {}
		_say = ""
		return _lay_hose(lay)
	if hints_held() <= 0:
		return false
	var r := _read()
	if r.is_empty():
		return false
	hints_used += 1
	_reading = r
	_say_now(_why(r))
	_cue("hint")
	_rate(true)
	if not demo and fx != null:
		var at: int = int(r.cell) if int(r.cell) >= 0 else int((_st.ends[int(r.hose)] as Array)[0])
		fx.ring(_cell_pos(at), _l("cell") * 0.8, Pal.SUN)
	return true

## What the bulb reads now: {hose, cell, rule, ways}, cell -1 and ways the
## hose's ends when no square decides one. {} when every hose is right.
func _read() -> Dictionary:
	var day := {"n": _st.n, "ends": _st.ends, "seeds": _st.seeds}
	var r = Reader.new(day)
	for l: Array in _st.right_links():
		r.link(int(l[0]), int(l[1]))
	var got: Dictionary = r.next()
	if not got.is_empty():
		var c: int = _st.answer_hose(int(got.cell), int(got.ways[0]))
		if c >= 0:
			return {"hose": c, "cell": int(got.cell), "rule": int(got.rule), "ways": got.ways}
	var c := _st.hint_hose()
	if c < 0:
		return {}
	var a: Array = _st.answer[c]
	return {"hose": c, "cell": -1, "rule": Reader.Rule.NONE, "ways": [int(a[0]), int(a[a.size() - 1])]}

## The reading's toast: why, then what a second press does.
func _why(r: Dictionary) -> String:
	var line := "HS_WHY_PAIR"
	match int(r.rule):
		Reader.Rule.END:
			var cell := int(r.cell)
			line = "HS_WHY_SEED" if _st.is_seed(cell) else ("HS_WHY_TAP" if _st.is_tap(cell) else "HS_WHY_FLOWER")
		Reader.Rule.CORNER:
			line = "HS_WHY_CORNER"
		Reader.Rule.LAST:
			line = "HS_WHY_LAST"
	return line + "|HS_WHY_AGAIN"

## Hose `c` laid as the answer has it, drawn out from its tap.
func _lay_hose(c: int) -> bool:
	if c < 0 or c >= _st.count():
		return false
	_st.lay_answer(c)
	_lay = {"hose": c, "at": _t}
	_say = ""
	_cue("hint")
	_rate(true)
	if not demo and fx != null:
		fx.ring(_cell_pos(int((_st.ends[c] as Array)[0])), _l("cell") * 0.8, Pal.SUN)
	if Motion.reduce:
		_finish_lay()
	return true

## The bulb's hose drawn out at once (a finger never waits for it).
func _finish_lay() -> void:
	if _lay.is_empty():
		return
	_lay = {}
	_after_change()

## The bin: every hose taken up.
func reset_board() -> void:
	if is_done():
		return
	_lay = {}
	_st.restart()
	moves = 0
	_say = ""
	_reading = {}
	_enter_at = _t - Motion.ENTER_DELAY
	_cue("reset")

func _say_now(key: String) -> void:
	_say = key
	_say_at = _t

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger: down on square `cell`, moved onto `cell`, lifted.
func demo_press(cell: int) -> void:
	_press(_cell_pos(cell))

func demo_move(cell: int) -> void:
	_drag(_cell_pos(cell))

func demo_release() -> void:
	_release()

func state():
	return _st

func laying() -> bool:
	return not _lay.is_empty()

## Where a finger on square `cell` goes, in this board's pixels.
func cell_to_local(cell: int) -> Vector2:
	return _cell_pos(cell)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	_watch_joins()
	if not _lay.is_empty() and _t - float(_lay.at) >= LAY_TIME:
		_finish_lay()
	if _say != "" and _t - _say_at > SAY_TIME and not (_say.begins_with("HS_WHY") and not _reading.is_empty()):
		_say = ""
	queue_redraw()

## A flower opens (or closes) as its hose joins (or is cut), and water runs
## down a hose that has just joined.
func _watch_joins() -> void:
	for c in _st.count():
		var j: bool = _st.joined(c)
		if j == _joined_was[c]:
			continue
		_joined_was[c] = j
		_bloom_at[c] = _t
		if j:
			_rush_at[c] = _t
			if not demo and fx != null:
				var h: Array = _st.hoses[c]
				var at := _cell_pos(int(h[h.size() - 1]))
				fx.ring(at, _l("cell") * (0.6 + 0.08 * _st.joined_count()), Art.colour(c))
				fx.sparkle(at, Pal.SUN)

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _pressing != -2:
				return
			_pressing = finger
			_press(event.position)
		elif finger == _pressing:
			_pressing = -2
			_release()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		var finger: int = event.index if event is InputEventScreenDrag else -1
		if finger != _pressing:
			return
		accept_event()
		_drag(event.position)

## The square a finger at `local` means: the one under it, or -1 off the
## bed; `clamp` holds a finger off the bed to its nearest square.
func cell_at(local: Vector2, clamp := false) -> int:
	if _L.is_empty():
		return -1
	var cs := _l("cell")
	var p := (local - Vector2(_l("ox"), _l("oy"))) / cs
	var n: int = _st.n
	if not clamp and (p.x < -0.15 or p.y < -0.15 or p.x > n + 0.15 or p.y > n + 0.15):
		return -1
	var x := clampi(int(floorf(p.x)), 0, n - 1)
	var y := clampi(int(floorf(p.y)), 0, n - 1)
	return y * n + x

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

## What the host's rows cover, in this board's own pixels (laid full rect).
## On the win the bed eases into the win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	var was := _won
	_won = won
	if won and not was and not _L.is_empty():
		_from = _L.duplicate()
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
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		# on the win the garden stays where play left it; only the bed moves
		var L: Dictionary = _from if _won and not _from.is_empty() else _L
		var cs := float(L.cell)
		var fw := cs * FRAME
		var bed := Rect2(float(L.ox) - fw, float(L.oy) - fw, cs * _st.n + fw * 2.0, cs * _st.n + fw * 2.0)
		_world.set_bed(bed, float(L.oy) - fw - 70.0 * float(L.u))
	_soil_key = ""
	_hoses_key = ""
	_ends_key = ""
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var n: int = maxi(_st.n, 1)
	var count_h := 0.0 if demo or _won else COUNT_H * u
	var span := maxf(bottom - top - count_h, 200.0 * u)
	var room_w := w - SIDE * 2.0 * u
	var cell := minf(minf(room_w / (n + FRAME * 2.0), (span - 24.0 * u) / (n + FRAME * 2.0)), CELL_MAX * u)
	var side := cell * n
	var ox := (w - side) * 0.5
	var oy := top + (span - side) * 0.5
	return {"u": u, "cell": cell, "ox": ox, "oy": oy, "count_y": oy + side + cell * FRAME + 64.0 * u}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L.get(key, 0.0))
	if _from.is_empty() or not _from.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _u() -> float:
	return float(_L.get("u", 1.0))

## The middle of square `cell`.
func _cell_pos(cell: int) -> Vector2:
	var cs := _l("cell")
	var n: int = _st.n
	return Vector2(_l("ox") + (cell % n + 0.5) * cs, _l("oy") + (cell / n + 0.5) * cs)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.ends.is_empty():
		return
	var easing := not _from.is_empty() and _t - _lay_at < 0.5
	_draw_soil(easing)
	_draw_dry()
	_draw_hoses(easing)
	_draw_rush()
	_draw_ends(easing)
	_draw_reading()
	_draw_partner()
	_draw_head()
	_draw_count()

## The squares water stands in: those of a joined hose, reached square by
## square from its tap while the water runs down it.
func _wet() -> Dictionary:
	var wet := {}
	for c in _st.count():
		if not _st.joined(c):
			continue
		var h: Array = _st.hoses[c]
		var reach := h.size()
		var e: float = _t - _rush_at[c]
		if e >= 0.0 and e < RUSH_TIME and not Motion.reduce:
			reach = ceili(e / RUSH_TIME * h.size())
		var from_tap: bool = int(h[0]) == int((_st.ends[c] as Array)[0])
		for i in reach:
			wet[int(h[i if from_tap else h.size() - 1 - i])] = true
	return wet

## Squares under joined hoses, for the count line.
func _watered() -> int:
	var k := 0
	for c in _st.count():
		if _st.joined(c):
			k += (_st.hoses[c] as Array).size()
	return k

## The frame and the soil squares, dry or wet, a tuft on each wet one (a
## daisy in it on the win); one mesh while nothing is watered, dried or
## growing.
func _draw_soil(easing: bool) -> void:
	var wet := _wet()
	for v in wet:
		if not _wet_at.has(v):
			_wet_at[v] = _t
	for v in _wet_at.keys():
		if not wet.has(v):
			_wet_at.erase(v)
	var growing := false
	if not Motion.reduce:
		for v in _wet_at:
			if _t - float(_wet_at[v]) < GROW_TIME:
				growing = true
				break
	var blooming := _phase_won() and _t - _won_at < WIN_HOLD + 0.6 and not Motion.reduce
	var key := "%s:%d:%d:%d:%s" % [str(wet.keys()), roundi(_l("cell") * 8.0), roundi(_l("ox")), roundi(_l("oy")), is_done()]
	if key != _soil_key or easing or growing or blooming or _soil == null:
		_soil_key = key
		var b := Face.Builder.new()
		var cs := _l("cell")
		var n: int = _st.n
		Art.frame(b, Rect2(_l("ox"), _l("oy"), cs * n, cs * n), cs * FRAME)
		for i in n * n:
			Art.soil(b, _cell_pos(i), cs, wet.has(i), i)
		for i in n * n:
			if not wet.has(i) or _st.end_of(i) >= 0 or _st.is_seed(i):
				continue
			var grow := 1.0
			var bloom := 0.0
			if not Motion.reduce:
				grow = Motion.back_out(clampf((_t - float(_wet_at.get(i, -INF))) / GROW_TIME, 0.0, 1.0))
			if is_done():
				# a reopened day (_won_at -INF) stands in bloom
				bloom = 1.0 if Motion.reduce else Motion.back_out(clampf((_t - _won_at - (i % n + i / n) * WAVE_STEP * 0.6) / 0.35, 0.0, 1.0))
			Art.sprout(b, _cell_pos(i), cs, i, grow, bloom)
		_soil = b.mesh()
	draw_mesh(_soil, null)

## Every hose joined and squares still dry: each dry square rimmed in sun.
func _draw_dry() -> void:
	if _st.live >= 0 or not _st.all_joined_dry() or is_done():
		return
	var dry := []
	for i in _st.squares():
		if _st.owner(i) < 0 and _st.end_of(i) < 0:
			dry.append(i)
	var key := "%s:%d:%d:%d" % [str(dry), roundi(_l("cell") * 8.0), roundi(_l("ox")), roundi(_l("oy"))]
	if key != _dry_key or _dry_mesh == null:
		_dry_key = key
		var b := Face.Builder.new()
		for i in dry:
			Art.rim(b, _cell_pos(int(i)), _l("cell"), Pal.SUN)
		_dry_mesh = b.mesh() if not b.verts.is_empty() else null
	if _dry_mesh != null:
		draw_mesh(_dry_mesh, null)

## The bulb's reading: the square it reads rimmed and washed in sun, the
## squares it links to rimmed softly (a pair's two ends when none decides).
func _draw_reading() -> void:
	if _reading.is_empty():
		return
	var key := "%s:%d:%d:%d" % [str(_reading), roundi(_l("cell") * 8.0), roundi(_l("ox")), roundi(_l("oy"))]
	if key != _reading_key or _reading_mesh == null:
		_reading_key = key
		var b := Face.Builder.new()
		var cs := _l("cell")
		if int(_reading.cell) >= 0:
			Art.rim(b, _cell_pos(int(_reading.cell)), cs, Pal.SUN)
		for v in _reading.ways:
			Art.rim(b, _cell_pos(int(v)), cs, Pal.SUN, int(_reading.cell) >= 0)
		_reading_mesh = b.mesh()
	# a slow breath so it reads as asked, not as a mark of the bed
	var a := 1.0 if Motion.reduce else 0.75 + 0.25 * sin(_t * 4.0)
	draw_mesh(_reading_mesh, null, Transform2D(), Color(1, 1, 1, a))

## The hose in hand's other end pulses (on Seedlings, every bare seed), so
## the eye finds where it is going.
func _draw_partner() -> void:
	var c: int = _st.live
	if c < 0 or _st.joined(c) or _halo == null:
		return
	var h: Array = _st.hoses[c]
	var e: Array = _st.ends[c]
	var goals := []
	if _st.seeded(c):
		for sc in _st.seeds:
			if _st.seed_owner(int(sc)) < 0:
				goals.append(int(sc))
	else:
		goals.append(int(e[1]) if int(h[0]) == int(e[0]) else int(e[0]))
	var k := fmod(_t, PULSE_TIME) / PULSE_TIME
	var sc := 1.0 if Motion.reduce else 0.9 + 0.35 * k
	var a := 0.8 if Motion.reduce else 0.9 * (1.0 - k)
	for g in goals:
		draw_mesh(_halo, null, Transform2D(0.0, Vector2.ONE * sc, 0.0, _cell_pos(int(g))), Color(1, 1, 1, a))

## The hoses, one mesh rebuilt only when one changed.
func _draw_hoses(easing: bool) -> void:
	var shown := -1
	if not _lay.is_empty():
		shown = ceili(clampf((_t - float(_lay.at)) / LAY_TIME, 0.0, 1.0) * (_st.hoses[int(_lay.hose)] as Array).size())
	var key := "%s:%d:%d:%d:%d" % [str(_st.hoses), shown, roundi(_l("cell") * 8.0), roundi(_l("ox")), roundi(_l("oy"))]
	if key != _hoses_key or easing:
		_hoses_key = key
		var b := Face.Builder.new()
		var cs := _l("cell")
		for c in _st.count():
			var h: Array = _st.hoses[c]
			var upto := h.size()
			if not _lay.is_empty() and c == int(_lay.hose):
				upto = mini(upto, maxi(shown, 1))
			if upto < 2:
				continue
			var pts := []
			for i in upto:
				pts.append(_cell_pos(int(h[i])))
			Art.hose(b, pts, cs, Art.colour(c))
		_hoses = b.mesh() if not b.verts.is_empty() else null
	if _hoses != null:
		draw_mesh(_hoses, null)

## Water running down a hose just joined: three cream drops from its first
## square to its last.
func _draw_rush() -> void:
	if Motion.reduce:
		return
	var cs := _l("cell")
	for c in _st.count():
		var e: float = _t - _rush_at[c]
		if e < 0.0 or e > RUSH_TIME or not _st.joined(c):
			continue
		var h: Array = _st.hoses[c]
		# water runs from the tap, whichever end the hose was drawn from
		var from_tap: bool = int(h[0]) == int((_st.ends[c] as Array)[0])
		for k in 3:
			var f := clampf(e / RUSH_TIME * 1.3 - k * 0.12, 0.0, 1.0)
			if f <= 0.0 or f >= 1.0:
				continue
			var along := f * (h.size() - 1)
			var i := int(floorf(along))
			var j := mini(i + 1, h.size() - 1)
			var a := _cell_pos(int(h[i if from_tap else h.size() - 1 - i]))
			var b := _cell_pos(int(h[j if from_tap else h.size() - 1 - j]))
			var p := a.lerp(b, along - i)
			draw_circle(p, cs * (0.07 - k * 0.012), Color(Art.CREAM, 0.95 - k * 0.2))

## How open the flower of hose `c` is now, 0 to 1.
func _open(c: int) -> float:
	var j: bool = _st.joined(c)
	var e: float = _t - _bloom_at[c]
	if Motion.reduce or e >= BLOOM_TIME:
		return 1.0 if j else 0.0
	var k := clampf(e / BLOOM_TIME, 0.0, 1.0)
	return Motion.back_out(k) if j else 1.0 - k

## Taps, flowers and seeds, one mesh rebuilt while one moves.
func _draw_ends(easing: bool) -> void:
	var moving := easing
	var opens := []
	for c in _st.count():
		var o := _open(c)
		opens.append(snappedf(o, 0.01))
		if o > 0.0 and o < 1.0:
			moving = true
	var entering := _t - _enter_at < Motion.ENTER_DELAY + _st.count() * 2 * Motion.ENTER_STAGGER + Motion.POP_IN + 0.05 and not Motion.reduce
	# the wave hops once over the win's hold and then the flowers stand
	var waving := _phase_won() and _t - _won_at < WIN_HOLD + 1.3 and not Motion.reduce
	var shiver := _t - _refused_at < REFUSE_TIME and not Motion.reduce
	var key := "%s:%s:%d:%d:%d" % [str(opens), str(_seed_owners()), roundi(_l("cell") * 8.0), roundi(_l("ox")), roundi(_l("oy"))]
	if key != _ends_key or moving or entering or waving or shiver:
		_ends_key = key
		var b := Face.Builder.new()
		var cs := _l("cell")
		var u := _u()
		var k := 0
		for c in _st.count():
			var e: Array = _st.ends[c]
			var col := Art.colour(c)
			for side in 2:
				var cell := int(e[side])
				if cell < 0:
					continue
				var xf := _end_xf(cell, k, side == 1, u)
				k += 1
				if xf == Transform2D():
					continue
				var sub := Face.Builder.new()
				if side == 0:
					Art.tap(sub, Vector2.ZERO, cs, col, c)
				else:
					Art.flower(sub, Vector2.ZERO, cs, col, _open(c), c)
				_put(b, sub, xf)
		for sc in _st.seeds:
			var cell := int(sc)
			var xf := _end_xf(cell, k, true, u)
			k += 1
			if xf == Transform2D():
				continue
			var sub := Face.Builder.new()
			var by: int = _st.seed_owner(cell)
			if by >= 0:
				Art.flower(sub, Vector2.ZERO, cs, Art.colour(by), _open(by), by)
			else:
				Art.seed_mound(sub, Vector2.ZERO, cs)
			_put(b, sub, xf)
		_ends = b.mesh() if not b.verts.is_empty() else null
	if _ends != null:
		draw_mesh(_ends, null)

## The shapes of `sub` laid into `b` under `xf`, with no mesh made between.
func _put(b: Face.Builder, sub: Face.Builder, xf: Transform2D) -> void:
	var base := b.verts.size()
	b.verts.append_array(xf * sub.verts)
	b.cols.append_array(sub.cols)
	var ix := sub.idx.duplicate()
	for i in ix.size():
		ix[i] += base
	b.idx.append_array(ix)

## Where an end on `cell` is drawn: popped in as the board enters (the
## `k`th), shivered when refused, hopping in a wave on the win (flowers).
## Transform2D() while it has not come in yet.
func _end_xf(cell: int, k: int, flower: bool, u: float) -> Transform2D:
	var at := _cell_pos(cell)
	var scale := 1.0
	if not Motion.reduce:
		var e := _t - _enter_at - Motion.ENTER_DELAY - k * Motion.ENTER_STAGGER
		if e < 0.0:
			return Transform2D()
		if e < Motion.POP_IN:
			scale = Motion.pop_in_scale(e).x
		var r := _t - _refused_at
		if cell == _refused_cell and r >= 0.0 and r < REFUSE_TIME:
			at.x += sin(r * 46.0) * 7.0 * u * (1.0 - r / REFUSE_TIME)
		if flower and _phase_won() and _t - _won_at < WIN_HOLD + 1.3:
			var n: int = _st.n
			var wave := _t - _won_at - (cell % n) * WAVE_STEP
			if wave >= 0.0:
				at.y -= Motion.hop_lift(fmod(wave, 1.3), Motion.SOLVE_HOP * 2.0 * u, Motion.SOLVE_TIME)
	return Transform2D(0.0, Vector2.ONE * scale, 0.0, at)

func _seed_owners() -> Array:
	var out := []
	for sc in _st.seeds:
		out.append(_st.seed_owner(int(sc)))
	return out

func _phase_won() -> bool:
	return is_done() and _won_at > -INF and _t >= _won_at

## The cream halo at the head of the hose in hand, bumping as it grows.
func _draw_head() -> void:
	var head: int = _st.head()
	if head < 0:
		return
	var at := _cell_pos(head)
	var k := 1.0
	var e := _t - _head_at
	if e >= 0.0 and e < Motion.BUMP_TIME and not Motion.reduce:
		k = Motion.bump_scale(e, 0.14)
	var cs := _l("cell")
	if _halo == null or absf(cs - _halo_cell) > 0.5:
		var b := Face.Builder.new()
		Art.halo(b, Vector2.ZERO, cs)
		_halo = b.mesh()
		_halo_cell = cs
	draw_mesh(_halo, null, Transform2D(0.0, Vector2.ONE * k, 0.0, at))

## The hoses joined and the share watered, or what was just said.
func _draw_count() -> void:
	if demo or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var y := _l("count_y")
	var text: String
	var fs: int
	if _say != "":
		var parts := PackedStringArray()
		for k in _say.split("|"):
			parts.append(tr(k))
		text = "\n".join(parts)
		fs = roundi(SAY_SIZE * u)
	elif is_done():
		return
	else:
		var j: int = _st.joined_count()
		text = tr("HS_JOINED") % [j, _st.count()]
		text += "  ·  " + tr("HS_WATERED") % roundi(100.0 * _watered() / float(_st.squares()))
		fs = roundi(COUNT_SIZE * u)
	var pk := 1.0
	if _say != "" and _t - _say_at < 0.25 and not Motion.reduce:
		pk = Motion.pop_in_scale(_t - _say_at, 0.25).x
	draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * pk)
	var lines := text.split("\n")
	for i in lines.size():
		var tw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(-tw * 0.5, i * fs * 1.25)
		draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * u), Color(Pal.SURFACE, 0.92))
		draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	draw_set_transform(Vector2.ZERO)
	# the stars under the count; a toast of two lines has them
	if lines.size() < 2:
		var sw := StarLine.width(STAR_SCALE * u)
		_stars.draw(self, Vector2(size.x * 0.5 - sw * 0.5 + StarLine.R * STAR_SCALE * u, y + STAR_DROP * u), STAR_SCALE * u, _t)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func share_glyphs() -> String:
	return "🌷 " + "🟩".repeat(_st.count()) + ("" if hints_used == 0 else " " + "💡".repeat(hints_used))

func flat_win() -> Dictionary:
	var made: String = (tr("HS_WIN_ONE") if _st.strokes == 1 else tr("HS_WIN_N")) % [_st.count(), _st.strokes]
	var line: String = tr("HS_WIN_PERFECT") if _st.strokes <= _st.count() else ""
	return {"faces": [], "subtitle": (made + " " + line).strip_edges()}

## Three stars while the strokes are at most one past the hoses (a hose a
## stroke, and one slip), two up to four past, one beyond; a hose the bulb
## laid counts as a stroke, its reading as nothing, so drawing the read hose
## yourself costs what letting the bulb lay it does. Read off strokes only,
## never the answer, so a star never falls to say a hose is wrong. Reset
## keeps the day's strokes.
func _rate(heard: bool) -> void:
	var extra: int = _st.strokes + _st.hinted - _st.count()
	_stars.rate(3 if extra <= 1 else (2 if extra <= 4 else 1), _t, heard and not is_done())

func completion_record() -> Dictionary:
	return {"hoses": _st.hoses.duplicate(true), "strokes": _st.strokes}

## A finished day reopens with the hoses as they were left, every flower open.
func restore_completed_board() -> void:
	_st.finish(completed_record.get("hoses", []) as Array)
	_st.strokes = int(completed_record.get("strokes", 0))
	for c in _st.count():
		_joined_was[c] = _st.joined(c)
		_bloom_at[c] = -INF
		_rush_at[c] = -INF
	_lay = {}
	_say = ""
	_reading = {}
	for i in _st.squares():
		_wet_at[i] = -INF
	_rate(false)
	_won_at = -INF
	queue_redraw()
