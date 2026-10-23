extends "res://core/puzzle_base.gd"

## Market Sums (spec docs/superpowers/specs/2026-10-22-market-design.md): a
## numbers board. Six crates stand on a garden market stall, a number on
## each, and the order board hung from the awning names a number. Tap a
## crate, a sign (+, take away, times, share) and another crate: the first
## crate slides into the second and they become one crate holding what they
## make. A crate holding the order fills it; on Insane (Every Crate) the
## order must be the one crate left. The rules are puzzles/market_state.gd's
## and the arithmetic, the solver and the day puzzles/market_gen.gd's.
##
## **The stall is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/market_world.gd) is the board's first child. From the top
## of the span down: the awning and the order board under it, two shelves
## of three crates, and the counter with the four sign tokens and the count
## line under them.
##
## A crate picked rides up a little over a sun halo; the sign picked turns
## sun. A combine is a crate sliding along an arc into the other, which
## pops with its new number; Undo is the same slide backwards, out of the
## crate it went into. A refused combine (two equal crates taken away, a
## share with a remainder, a number past the stall's 9999) shivers both
## crates and says why. The bulb makes one step of a shortest way on, from
## the stall as it stands, after walking back the steps that lost the way.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/market_tutorial_diagram.gd plays it with `demo_crate`/`demo_sign`.

const State = preload("res://puzzles/market_state.gd")
const Gen = preload("res://puzzles/market_gen.gd")
const World = preload("res://puzzles/market_world.gd")
const Art = preload("res://ui/faces/market_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

const Made = State.Made
const SLOTS := State.SLOTS

const HAPTICS := {
	"pick": Haptics.TICK,
	"drop": Haptics.TICK,
	"sign": Haptics.TICK,
	"make": Haptics.TAP,
	"refuse": Haptics.WARN,
	"undo": Haptics.TICK,
	"reset": Haptics.TAP,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The pieces at W: a crate's width, the order board, a sign token's radius.
const CRATE_W := 250.0
const CRATE_GAP := 50.0
const BOARD_W := 520.0
const BOARD_H := 210.0
const TOKEN_R := 72.0
const TOKEN_GAP := 56.0
## The rows' heights and gaps at W: the awning's depth, the shelf, the
## counter's front over the tokens, the count line.
const AWNING := 110.0
const SHELF := 26.0
const SHELF_GAP := 78.0
const COUNTER_FRONT := 54.0
## Under the signs: the step strip and the count under it. The strip
## spells the step being built, a slot each for the crate, the sign and the
## other crate ("5 + ?"), and the step just made in full ("5 + 6 = 11")
## until the next is begun; a refusal takes its place, rose. The user,
## 2026-10-23: "must be easy to understand as a new player".
const COUNT_H := 168.0
const COUNT_SIZE := 30
const SAY_SIZE := 30
const STRIP_H := 76.0
const STRIP_TOP := 22.0
const STRIP_PAD := 14.0
const STRIP_GAP := 10.0
const SLOT_W := 92.0
const STRIP_NUM := 44
const EQ_HOLD := 2.2
const COUNT_DROP := 46.0
## How high a picked crate rides, in its width.
const PICK_RISE := 0.08
## A crate sliding into another, and how high its arc rides, in crate
## widths.
const SLIDE_TIME := 0.26
const ARC := 0.45
## A refused combine's shiver, the toast's stay.
const REFUSE_TIME := 0.45
const SAY_TIME := 2.4
## The win: the crates' wave, how long the board's own win plays.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.07

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _t := 0.0
var _enter_at := 0.0
var _won_at := -INF
## The crate picked and the sign picked, -1 when none.
var _pick := -1
var _op := -1
## The number each place shows, which lags the state's through a slide.
var _shown_v: Array[int] = []
## The slide under way: {from, into, at, back (an Undo), value (the into
## crate's new number, or its old one on an Undo)}; {} when none.
var _slide := {}
## Per place: when its crate last popped, was refused, dropped in.
var _pop_at: Array[float] = []
var _refused_at: Array[float] = []
var _drop_at: Array[float] = []
## Per sign: when it was last pressed.
var _sign_at: Array[float] = []
var _say := ""
var _say_at := -INF
var _stuck_said := false
var _filled_at := -INF
## The step last made, [a, op, b, made, at]; [] when none to show.
var _eq: Array = []
## The strip's mesh, kept until the next replaces it (a mesh freed before
## the frame draws is drawn as nothing).
var _strip_shown: ArrayMesh
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
var _units := {}
var _units_w := -1.0
var _still: ArrayMesh
var _still_key := ""
var fx: Node

func puzzle_id() -> String: return "market"
func title() -> String: return "Market Sums"

func rules() -> String:
	var out := tr("MK_RULES")
	out += "\n\n" + tr("MK_RULES_SIGNS")
	if _st.every:
		out += "\n\n" + tr("MK_RULES_EVERY")
	out += "\n\n" + tr("MK_RULES_FEWEST")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/market_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.MAKE, "HTP_MK_MAKE", tr("HTP_MK_MAKE_BODY")],
		[Diagram.Lesson.SIGNS, "HTP_MK_SIGNS", tr("HTP_MK_SIGNS_BODY")],
		[Diagram.Lesson.ORDER, "HTP_MK_ORDER", tr("HTP_MK_ORDER_BODY" if not _st.every else "HTP_MK_EVERY_BODY")],
		[Diagram.Lesson.HINT, "HTP_MK_HINT", tr("HTP_MK_HINT_BODY")],
	]
	if _st.every:
		steps[2][1] = "HTP_MK_EVERY"
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Undo and the bulb; Insane keeps no Undo (its seal). No Check: the order
## board says when it is filled, and nothing on the stall is ever wrong.
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

## Every crate as dealt, nothing picked, nothing moving.
func _fresh() -> void:
	_shown_v.clear()
	_pop_at.clear()
	_refused_at.clear()
	_drop_at.clear()
	for i in SLOTS:
		_shown_v.append(_st.slots[i])
		_pop_at.append(-INF)
		_refused_at.append(-INF)
		_drop_at.append(-INF)
	_sign_at.clear()
	for o in 4:
		_sign_at.append(-INF)
	_pick = -1
	_op = -1
	_slide = {}
	_say = ""
	_stuck_said = false
	_filled_at = -INF
	_still_key = ""
	_relayout()

func day_dict() -> Dictionary:
	if _st.numbers.is_empty():
		return {}
	return {
		"source": "generator", "kind": "text",
		"payload": {"numbers": _st.numbers.duplicate(), "target": _st.target, "every": _st.every},
		"solution": {"steps": _st.answer.duplicate(true)},
		"metrics": {"par": _st.par, "target": _st.target},
	}

# --- the moves ---

## The player tapped the crate at place `s`.
func _tap_crate(s: int) -> void:
	if is_done() or _won:
		return
	_settle()
	if _st.slots[s] <= 0:
		return
	if _pick < 0:
		_pick = s
		_cue("pick", randf_range(0.96, 1.04))
		return
	if s == _pick:
		_pick = -1
		_cue("drop")
		return
	if _op < 0:
		_pick = s
		_cue("pick", randf_range(0.96, 1.04))
		return
	_make(_pick, s, _op, false)

## The player tapped sign `o`.
func _tap_sign(o: int) -> void:
	if is_done() or _won:
		return
	_sign_at[o] = _t
	if _op == o:
		_op = -1
		_cue("drop")
		return
	_op = o
	_cue("sign", randf_range(0.97, 1.03))

## Crate `from` into crate `into` under `op`, by the player or the bulb.
func _make(from: int, into: int, op: int, by_hint: bool) -> void:
	var old: int = _st.slots[into]
	var was: int = _st.slots[from]
	var heard: int = _st.make(from, into, op, by_hint)
	match heard:
		Made.SAME:
			return
		Made.ZERO, Made.UNEVEN, Made.BIG:
			_refused_at[from] = _t
			_refused_at[into] = _t
			_say_now({Made.ZERO: "MK_SAY_ZERO", Made.UNEVEN: "MK_SAY_UNEVEN", Made.BIG: "MK_SAY_BIG"}[heard])
			_cue("refuse")
			# the sign goes back; the crate in hand stays picked
			_op = -1
			return
	if not by_hint:
		moves += 1
		moved.emit()
	_say = ""
	var a := was
	var z := old
	if op == Gen.Op.SUB or op == Gen.Op.DIV:
		a = maxi(was, old)
		z = mini(was, old)
	_eq = [a, op, z, _st.slots[into], _t]
	_shown_v[into] = old
	_slide = {"from": from, "into": into, "at": _t, "back": false, "value": _st.slots[into]}
	_pick = -1
	_op = -1
	if heard == Made.SOLVED:
		_phase_solved()
	else:
		_pick = into

## The slide under way lands now: the crate it went into shows its number.
func _land() -> void:
	if _slide.is_empty():
		return
	var into := int(_slide.into)
	var from := int(_slide.from)
	if bool(_slide.back):
		_shown_v[from] = _st.slots[from]
		_pop_at[from] = _t
	else:
		_shown_v[into] = int(_slide.value)
		_pop_at[into] = _t
		_cue("make", randf_range(0.95, 1.05))
		if not demo and fx != null:
			fx.ring(_crate_pos(into), _l("cw") * 0.9, Pal.SUN)
	_shown_v[from] = _st.slots[from]
	_slide = {}
	if _st.solved():
		_filled_at = _t
		var at := _st.filled_at()
		if not demo and fx != null and at >= 0:
			fx.sparkle(_crate_pos(at), Pal.LEAF)
	elif not _stuck_said and not is_done() and _st.steps_left() < 0:
		# the way to the order was lost: say so once, until it is found again
		_stuck_said = true
		_say_now("MK_SAY_STUCK" if _band < 3 else "MK_SAY_STUCK_BIN")

## A slide still running is finished at once (a quick finger never waits).
func _settle() -> void:
	if not _slide.is_empty():
		_land()

func _phase_solved() -> void:
	check_solved()
	if not is_done():
		return
	var after := SLIDE_TIME if not Motion.reduce else 0.0
	_won_at = _t + after + 0.25
	_after_win(after)

func _after_win(after: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(after + 0.2, false).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_settle()
		_cue("solved")
		if not demo and fx != null:
			fx.confetti(Vector2(size.x * 0.5, _l("board_y")), 26, size.x * 0.7)
			# the order filled in the fewest steps there are: the party
			_cue("party" if _st.steps <= _st.par else "confetti"))

func is_solved() -> bool:
	return _st.solved()

func undo() -> bool:
	if not can_undo():
		return false
	_settle()
	var back: Array = _st.undo()
	if back.is_empty():
		return false
	var from := int(back[0])
	var into := int(back[1])
	# the crate comes back out of the one it went into
	_shown_v[into] = _st.slots[into]
	_shown_v[from] = 0
	_pop_at[into] = _t
	_slide = {"from": from, "into": into, "at": _t, "back": true, "value": _st.slots[into]}
	_pick = -1
	_op = -1
	_say = ""
	_eq = []
	_stuck_said = false
	_cue("undo")
	return true

## The bulb: the steps that lost the way walked back, then one step of a
## shortest way on, made as the player would make it.
func hint() -> bool:
	if hints_left() <= 0 or is_done():
		return false
	_settle()
	var step: Array = _st.hint_step()
	var walked := false
	while step.is_empty() and not _st.history.is_empty():
		_st.undo()
		walked = true
		step = _st.hint_step()
	if step.is_empty():
		return false
	hints_used += 1
	if walked:
		for i in SLOTS:
			_shown_v[i] = _st.slots[i]
			_drop_at[i] = _t if _st.slots[i] > 0 else -INF
	_stuck_said = false
	_cue("hint")
	_sign_at[int(step[2])] = _t
	if not demo and fx != null:
		for s in [int(step[0]), int(step[1])]:
			fx.ring(_crate_pos(s), _l("cw") * 1.1, Pal.SUN)
	_make(int(step[0]), int(step[1]), int(step[2]), true)
	return true

## The bin: every crate back as dealt.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_slide = {}
	_pick = -1
	_op = -1
	_say = ""
	_eq = []
	_stuck_said = false
	for i in SLOTS:
		_shown_v[i] = _st.slots[i]
		_drop_at[i] = _t + i * Motion.ENTER_STAGGER
	_cue("reset")

func _say_now(key: String) -> void:
	_say = key
	_say_at = _t

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger on the crate at place `s`, and on sign `o`.
func demo_crate(s: int) -> void:
	_tap_crate(s)

func demo_sign(o: int) -> void:
	_tap_sign(o)

func state():
	return _st

func picked() -> int:
	return _pick

func sign() -> int:
	return _op

func sliding() -> bool:
	return not _slide.is_empty()

## Where a finger tapping the crate at place `s` goes, in this board's
## pixels, and one tapping sign `o`.
func crate_to_local(s: int) -> Vector2:
	return _crate_pos(s)

func sign_to_local(o: int) -> Vector2:
	return _sign_pos(o)

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	if not _slide.is_empty() and (_t - float(_slide.at) >= SLIDE_TIME or Motion.reduce):
		_land()
	if _say != "" and _t - _say_at > SAY_TIME:
		_say = ""
	queue_redraw()

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
			var o := sign_at(event.position)
			if o >= 0:
				_tap_sign(o)
				return
			var s := crate_at(event.position)
			if s >= 0:
				_tap_crate(s)
		elif finger == _pressing:
			_pressing = -2

## The place a finger at `local` means: the nearest crate on the stall,
## within most of a crate's width of it.
func crate_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var best := -1
	var far := INF
	for s in SLOTS:
		if _st.slots[s] <= 0:
			continue
		var d := local.distance_to(_crate_pos(s))
		if d < far:
			far = d
			best = s
	return best if far < _l("cw") * 0.75 else -1

## The sign a finger at `local` means, within a token and a half of it.
func sign_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	for o in 4:
		if local.distance_to(_sign_pos(o)) < _l("tr") * 1.35:
			return o
	return -1

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
## On the win the board eases into the win's span.
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
		# on the win the awning stays where play left it, so it never climbs
		# behind the win's words; the shelves and the counter follow the crates
		var awn := float(_from.awn) if _won and not _from.is_empty() else float(_L.awn)
		_world.set_lines(awn, [float(_L.shelf0), float(_L.shelf1)], float(_L.counter))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var count_h := 0.0 if demo else COUNT_H
	var crate_h := CRATE_W * Art.H
	# on the win the signs and the count are put away: the order and the
	# crates fill the win's span
	var tokens_h := 0.0 if _won else COUNTER_FRONT + TOKEN_R * 2.0 + 24.0 + count_h
	var need := AWNING + 24.0 + BOARD_H + 40.0 + 2.0 * (crate_h + SHELF + SHELF_GAP) + tokens_h
	var k := minf(1.0, span / (need * u))
	var s := u * k
	var awn := top + AWNING * s
	var board_y := awn + (24.0 + BOARD_H * 0.5) * s
	var cw := CRATE_W * s
	var ch := cw * Art.H
	var row0 := board_y + (BOARD_H * 0.5 + 40.0) * s + ch * 0.5
	var shelf0 := row0 + ch * 0.5
	var row1 := shelf0 + (SHELF + SHELF_GAP) * s + ch * 0.5
	var shelf1 := row1 + ch * 0.5
	var counter := shelf1 + (SHELF + SHELF_GAP * 0.5) * s
	var tr_ := TOKEN_R * s
	var tokens_y := counter + COUNTER_FRONT * s + tr_
	# whatever the span leaves over goes under the count line
	return {
		"u": u, "s": s, "top": top, "bottom": bottom, "awn": awn,
		"board_y": board_y, "bw": BOARD_W * s, "bh": BOARD_H * s,
		"cw": cw, "gap": CRATE_GAP * s, "row0": row0, "row1": row1,
		"shelf0": shelf0, "shelf1": shelf1, "counter": counter,
		"tr": tr_, "tokens_y": tokens_y, "strip_y": tokens_y + tr_ + (STRIP_TOP + STRIP_H * 0.5) * s,
		"count_y": tokens_y + tr_ + (STRIP_TOP + STRIP_H + COUNT_DROP) * s,
	}

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

## The middle of the crate at place `s` as it stands on its shelf.
func _crate_pos(s: int) -> Vector2:
	var cw := _l("cw")
	var col := s % 3
	var x := size.x * 0.5 + (col - 1) * (cw + _l("gap"))
	return Vector2(x, _l("row0") if s < 3 else _l("row1"))

func _sign_pos(o: int) -> Vector2:
	var r := _l("tr")
	var step := r * 2.0 + TOKEN_GAP * float(_L.get("s", 1.0))
	return Vector2(size.x * 0.5 + (o - 1.5) * step, _l("tokens_y"))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.numbers.is_empty():
		return
	var cw := _l("cw")
	if absf(cw - _units_w) > 0.5:
		_units_w = cw
		_units = Art.units(cw)
	_draw_still()
	_draw_order()
	for s in SLOTS:
		_draw_crate(s)
	_draw_sliding()
	_draw_count()

## The order board and the sign tokens, one mesh while nothing changes.
func _draw_still() -> void:
	var lit: int = _op
	var pulse := []
	for o in 4:
		pulse.append(_t - _sign_at[o] < Motion.BUMP_TIME)
	var key := "%d:%d:%d:%d:%s:%s" % [roundi(size.x), roundi(_l("board_y")), roundi(_l("tokens_y") * 4.0), lit, str(pulse), _won]
	if key != _still_key or pulse.has(true):
		_still_key = key
		var b := Face.Builder.new()
		var s := float(_L.get("s", 1.0))
		Art.board(b, Vector2(size.x * 0.5, _l("board_y")), Vector2(_l("bw"), _l("bh")), _l("awn") - 10.0 * s, s)
		for o in 4:
			if _won:
				break
			var r := _l("tr")
			var e: float = _t - _sign_at[o]
			if e >= 0.0 and e < Motion.BUMP_TIME and not Motion.reduce:
				r *= Motion.bump_scale(e, 0.12)
			Art.token(b, _sign_pos(o), r, o, o == lit)
		_still = b.mesh()
	draw_mesh(_still, null)

## The order's number in chalk, "Order" over it, Insane's line under it,
## and a leaf tick once it is filled.
func _draw_order() -> void:
	var s := float(_L.get("s", 1.0))
	var at := Vector2(size.x * 0.5, _l("board_y"))
	var bh := _l("bh")
	var font: Font = CozyTheme.display(700)
	var big: Font = CozyTheme.display(800)
	var label := tr("MK_ORDER")
	var ls := roundi(30 * s)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
	draw_string(font, at + Vector2(-lw * 0.5, -bh * 0.22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(Art.CHALK_INK, 0.7))
	var n := str(_st.target)
	var ns := roundi(96 * s)
	var k := 1.0
	var fe := _t - _filled_at
	if fe >= 0.0 and fe < Motion.BUMP_TIME * 1.5 and not Motion.reduce:
		k = Motion.bump_scale(fe / 1.5, 0.18)
	var nw := big.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
	draw_set_transform(at + Vector2(0.0, bh * 0.2), 0.0, Vector2.ONE * k)
	draw_string(big, Vector2(-nw * 0.5, 0.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Art.CHALK_INK)
	draw_set_transform(Vector2.ZERO)
	if _st.every:
		var line := tr("MK_EVERY_NOTE")
		var es := roundi(24 * s)
		var ew := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
		draw_string(font, at + Vector2(-ew * 0.5, bh * 0.4), line, HORIZONTAL_ALIGNMENT_LEFT, -1, es, Color(Pal.SUN_RAY, 0.95))
	if _st.solved() and _filled_at > -INF:
		var tick := at + Vector2(_l("bw") * 0.36, -bh * 0.18)
		var pop := Motion.pop_in_scale(fe).x if fe < Motion.POP_IN and not Motion.reduce else 1.0
		var r := 26.0 * s * pop
		draw_circle(tick, r, Pal.LEAF)
		draw_polyline(PackedVector2Array([tick + Vector2(-r * 0.45, 0.0), tick + Vector2(-r * 0.1, r * 0.35), tick + Vector2(r * 0.45, -r * 0.35)]),
			Pal.SURFACE, 5.0 * s, true)

## Where the crate at place `s` is drawn now, and how big.
func _crate_xf(s: int) -> Transform2D:
	var at := _crate_pos(s)
	var cw := _l("cw")
	var u := _u()
	var k := 1.0
	var turn := 0.0
	if s == _pick:
		at.y -= cw * PICK_RISE
	var e := _t - _pop_at[s]
	if e >= 0.0 and e < Motion.BUMP_TIME and not Motion.reduce:
		k = Motion.bump_scale(e, 0.16)
	var r := _t - _refused_at[s]
	if r >= 0.0 and r < REFUSE_TIME and not Motion.reduce:
		at.x += sin(r * 46.0) * 8.0 * u * (1.0 - r / REFUSE_TIME)
	# the crates drop onto their shelves as the board comes in, place by place
	var d: float = _t - _enter_at - Motion.ENTER_DELAY - s * Motion.ENTER_STAGGER
	var dr := _t - _drop_at[s]
	if dr >= 0.0 and dr < d:
		d = dr
	if d >= 0.0 and d < Motion.DROP_TIME and not Motion.reduce:
		at.y -= Motion.drop_in_lift(d, Motion.DROP * 2.0 * u)
	if (_phase_won()) and not Motion.reduce:
		var wave := _t - _won_at - s * WAVE_STEP
		if wave >= 0.0:
			at.y -= Motion.hop_lift(fmod(wave, 1.3), Motion.SOLVE_HOP * 2.0 * u, Motion.SOLVE_TIME)
	return Transform2D(turn, Vector2.ONE * k, 0.0, at)

func _phase_won() -> bool:
	return is_done() and _won_at > -INF and _t >= _won_at

func _entered(s: int) -> bool:
	return _t - _enter_at - Motion.ENTER_DELAY - s * Motion.ENTER_STAGGER >= 0.0 or Motion.reduce

func _draw_crate(s: int) -> void:
	var v: int = _shown_v[s]
	if v <= 0 or not _entered(s):
		return
	# the crate on its way into another is drawn by the slide
	if not _slide.is_empty() and not bool(_slide.back) and int(_slide.from) == s:
		return
	if not _slide.is_empty() and bool(_slide.back) and int(_slide.from) == s:
		return
	var xf := _crate_xf(s)
	var rest := Transform2D(0.0, _crate_pos(s))
	draw_mesh(_units.shade, null, rest)
	if s == _pick and not is_done():
		draw_mesh(_units.halo, null, xf)
	var filled: bool = v == _st.target and _st.solved() and _slide.is_empty()
	draw_mesh(_units.filled if filled else _units.crate, null, xf)
	_numeral(v, xf)

func _numeral(v: int, xf: Transform2D) -> void:
	var cw := _l("cw")
	var font: Font = CozyTheme.display(800)
	var text := str(v)
	var fs := Art.numeral_size(text, cw)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var at := Art.label_centre(cw) + Vector2(-tw * 0.5, asc * 0.36)
	draw_set_transform_matrix(xf)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	draw_set_transform(Vector2.ZERO)

## The crate in the air: into the other along an arc, or out of it on an
## Undo.
func _draw_sliding() -> void:
	if _slide.is_empty():
		return
	var from := int(_slide.from)
	var into := int(_slide.into)
	var back := bool(_slide.back)
	var k := clampf((_t - float(_slide.at)) / SLIDE_TIME, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	if back:
		e = 1.0 - e
	var a := _crate_pos(from)
	var b := _crate_pos(into)
	var cw := _l("cw")
	var at := a.lerp(b, e) + Vector2(0.0, -sin(e * PI) * cw * ARC)
	var grow := 1.0 + sin(e * PI) * 0.08
	var shrink := lerpf(1.0, 0.7, e * e)
	var xf := Transform2D(0.0, Vector2.ONE * grow * shrink, 0.0, at)
	var v: int = _st.slots[from] if back else _shown_numeral_from()
	draw_mesh(_units.crate, null, xf, Color(1, 1, 1, 1.0 - e * e * 0.6))
	_numeral(v, xf)

## The number the crate on its way in carried: the stall before the move.
func _shown_numeral_from() -> int:
	if _st.history.is_empty():
		return 0
	var last: Array = _st.history[_st.history.size() - 1]
	return int((last[0] as Array)[int(_slide.from)])

## The step strip, or what was just refused in its place, and the steps
## taken against the fewest under it.
func _draw_count() -> void:
	if demo or _won:
		return
	var u := _u()
	var s := float(_L.get("s", u))
	var font: Font = CozyTheme.display(700)
	var mid := Vector2(size.x * 0.5, _l("strip_y"))
	var sh := STRIP_H * s
	if _say != "":
		var text := tr(_say)
		var fs := roundi(SAY_SIZE * u)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pk := Motion.pop_in_scale(_t - _say_at, 0.25).x if _t - _say_at < 0.25 and not Motion.reduce else 1.0
		var b := Face.Builder.new()
		_pill(b, Vector2(minf(tw + 2.0 * STRIP_PAD * 2.0 * s, size.x - 40.0 * u), sh), Pal.BAD_TILE)
		draw_set_transform(mid, 0.0, Vector2.ONE * pk)
		_strip_shown = b.mesh()
		draw_mesh(_strip_shown, null)
		draw_string(font, Vector2(-tw * 0.5, font.get_ascent(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
		draw_set_transform(Vector2.ZERO)
		return
	if is_done():
		return
	_draw_strip(mid, s)
	var n: int = _st.steps
	var text: String = (tr("MK_STEPS_ONE") if n == 1 else tr("MK_STEPS_N")) % n
	text += "  ·  " + tr("MK_FEWEST") % _st.par
	var cs := roundi(COUNT_SIZE * u)
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	draw_string(font, Vector2(size.x * 0.5 - cw * 0.5, _l("count_y")), text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs,
		Color(Pal.TEXT, 0.72))

## A paper pill `sz` about the origin, on a soft drop, with a hairline.
func _pill(b: Face.Builder, sz: Vector2, face: Color) -> void:
	var r := sz.y * 0.5
	b.fan(Face.Builder.round_rect(-sz * 0.5 + Vector2(0.0, sz.y * 0.07), sz, r), Color(Pal.TEXT, 0.14))
	b.fan(Face.Builder.round_rect(-sz * 0.5, sz, r), Color(Pal.LINE, 0.7))
	var e := 1.5 * _u()
	b.fan(Face.Builder.round_rect(-sz * 0.5 + Vector2.ONE * e, sz - Vector2.ONE * 2.0 * e, r - e), face)

## The strip: [crate][sign][crate] while a step is built, the step just made
## with its "= made" while nothing new is begun.
func _draw_strip(mid: Vector2, s: float) -> void:
	var big: Font = CozyTheme.display(800)
	var fs := roundi(STRIP_NUM * s)
	var sh := STRIP_H * s
	var slot_h := sh - 2.0 * STRIP_GAP * s
	# the parts: [kind, value] with kind "n" a number (0 = empty), "o" a
	# sign (-1 = empty), "=" the equals
	var parts: Array = []
	var made := not _eq.is_empty() and _op < 0 and _t - float(_eq[4]) < EQ_HOLD
	if made:
		parts = [["n", _eq[0]], ["o", _eq[1]], ["n", _eq[2]], ["=", 0], ["n", _eq[3]]]
	else:
		parts = [["n", _st.slots[_pick] if _pick >= 0 else 0], ["o", _op], ["n", 0]]
	var widths: Array = []
	var total := 0.0
	for p in parts:
		var w := slot_h
		if p[0] == "n":
			w = maxf(SLOT_W * s, big.get_string_size(str(p[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24.0 * s)
		elif p[0] == "=":
			w = slot_h * 0.6
		widths.append(w)
		total += w
	total += STRIP_GAP * s * (parts.size() - 1)
	var b := Face.Builder.new()
	var pill := Vector2(total + 2.0 * STRIP_PAD * s, sh)
	_pill(b, pill, Pal.SURFACE)
	var x := -total * 0.5
	var texts: Array = []
	for i in parts.size():
		var p: Array = parts[i]
		var w: float = widths[i]
		var c := Vector2(x + w * 0.5, 0.0)
		var empty: bool = (p[0] == "n" and int(p[1]) <= 0) or (p[0] == "o" and int(p[1]) < 0)
		if empty:
			b.fan(Face.Builder.round_rect(c - Vector2(w, slot_h) * 0.5, Vector2(w, slot_h), slot_h * 0.3),
				Color(Pal.LINE, 0.22))
		elif p[0] == "o":
			var lit: bool = not made
			b.disc(c, slot_h * 0.5, Pal.SUN if lit else Color(Pal.LINE, 0.3))
			Art.mark(b, c, slot_h * 0.24, int(p[1]), Pal.SURFACE if lit else Pal.TEXT)
		elif p[0] == "=":
			var t := slot_h * 0.07
			for dy in [-slot_h * 0.12, slot_h * 0.12]:
				b.fan(Face.Builder.round_rect(c + Vector2(-w * 0.32, dy - t * 0.5), Vector2(w * 0.64, t), t * 0.5), Pal.TEXT)
		else:
			var last: bool = made and i == parts.size() - 1
			if last:
				b.fan(Face.Builder.round_rect(c - Vector2(w, slot_h) * 0.5, Vector2(w, slot_h), slot_h * 0.3), Art.FILLED)
			texts.append([c, str(p[1])])
		x += w + STRIP_GAP * s
	draw_set_transform(mid)
	_strip_shown = b.mesh()
	draw_mesh(_strip_shown, null)
	for t in texts:
		var tw := big.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(big, (t[0] as Vector2) + Vector2(-tw * 0.5, big.get_ascent(fs) * 0.36), t[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	draw_set_transform(Vector2.ZERO)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.numbers.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🧺 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.steps <= _st.par:
		line = tr("MK_WIN_FEWEST")
	else:
		line = tr("MK_WIN_MORE") % _st.par
	var made: String = (tr("MK_WIN_ONE") if _st.steps == 1 else tr("MK_WIN_N")) % [_st.target, _st.steps]
	return {"faces": [], "subtitle": made + " " + line}

func completion_record() -> Dictionary:
	return {"slots": Array(_st.slots), "steps": _st.steps}

## A finished day reopens with the stall as it was left, the order filled.
func restore_completed_board() -> void:
	_st.finish(completed_record.get("slots", []) as Array, int(completed_record.get("steps", 0)))
	for i in SLOTS:
		_shown_v[i] = _st.slots[i]
		_pop_at[i] = -INF
	_slide = {}
	_pick = -1
	_op = -1
	_say = ""
	_filled_at = -10.0
	_won_at = -INF
	queue_redraw()
