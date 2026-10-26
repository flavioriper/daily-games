extends "res://core/puzzle_base.gd"

## Who Ate the Pie? (spec docs/superpowers/specs/2026-10-22-pie-design.md): a
## logic board. Bakers stand in a grid on the bake-sale table at the
## village fête, and some of them ate the pie. Tap a baker and say whether
## they ate it; a baker marked says one true thing about the others, on
## their card and in the bubble under the table. A mark stands only when
## the clues showing prove it: one they do not prove yet is turned away for
## free, one they prove wrong is a slip. Every baker marked is the solve.
## The rules are puzzles/pie_state.gd's, the clues and the solver
## puzzles/pie_gen.gd's.
##
## **The table is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/pie_world.gd) is the board's first child. The cards, the
## pie, the badges, the bubble and the buttons are ui/faces/pie_art.gd's;
## the bakers are the house's own faces, one node per baker and look, never
## in the tree, drawn by this board from their `layers_now()`.
##
## A mark flips the card over to its paper (leaf for "didn't", berry for
## "ate pie"), its badge pops and the baker hops; the bakers the new clue
## speaks of are ringed a moment, and one caught owns up in the bubble with
## crumbs on their chin. An open baker picked rings every clue that speaks
## of them, and the bubble counts those clues; a marked baker picked again
## dims their clue, the player's note that it is spent. A refusal shivers
## the card and says why in the bubble. The bulb's first press rings the
## clues that prove somebody (the fewest that do) and leaves the who to the
## player; a second press while they stand marks that baker. No Undo
## (a mark is proven, so there is nothing to take back) and no bin (a day
## started over is a day already reasoned through).
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/pie_tutorial_diagram.gd plays it with `demo_select` and
## `demo_mark`.

const State = preload("res://puzzles/pie_state.gd")
const Gen = preload("res://puzzles/pie_gen.gd")
const World = preload("res://puzzles/pie_world.gd")
const Art = preload("res://ui/faces/pie_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Phase { PLAY, DONE }

const HAPTICS := {
	"pick": Haptics.TICK,
	"clear": Haptics.TAP,
	"caught": Haptics.GOOD,
	"refuse": Haptics.WARN,
	"slip": Haptics.WARN,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## A card turning over to its verdict, and the badge after it.
const FLIP_TIME := 0.32
## How long the bakers a new clue speaks of stay ringed.
const SPOKE_TIME := 1.4
## How long a refusal's words stay in the bubble, and a caught baker's.
const SAY_TIME := 2.2
const QUIP_TIME := 2.6
## The caught bakers' lines, PI_QUIP_0.. (one a baker by their place).
const QUIPS := 8
## A pressed button's look.
const PRESS_TIME := 0.14
## The win: how long the board's own win plays, and the bakers' wave.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.05
## The columns' letters.
const LETTERS := "ABCDEFGH"

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _phase := Phase.PLAY
## The board's own clock: it stands while a sheet lies over the board.
var _t := 0.0
## [time, Callable] run when the clock reaches them, in order.
var _queue: Array = []
## Per baker: when their card turned over, last shivered, last hopped; when
## the bakers their clue speaks of were last ringed.
var _flip_at: Array[float] = []
var _shake_at: Array[float] = []
var _hop_at: Array[float] = []
var _spoke_at := -INF
var _spoke := 0
## The picked baker (-1 none) and since when.
var _sel := -1
var _sel_at := -INF
## A refusal's words and when they were said.
var _say := ""
var _say_at := -INF
## The marked bakers whose clues speak of the picked open baker.
var _leads := 0
## The bulb's first press: the clues it rings, the baker they prove and
## since when (-1 when no nudge stands).
var _nudge := 0
var _nudge_baker := -1
var _nudge_at := -INF
## The clues the player dimmed as spent, a bit a baker.
var _dim := 0
## A caught baker's line and when they said it.
var _quip := ""
var _quip_at := -INF
## The verdict button last pressed (0 didn't, 1 ate) and when.
var _press := -1
var _press_at := -INF
var _slip_at := -INF
var _found_at := -INF
## The clue sentences, a baker each, written once a deal.
var _text: Array[String] = []
## The bakers' faces, "kind:expression" -> Control (never in the tree).
var _faces := {}
var _won_at := -INF
var _enter_at := 0.0
var _pressing := -2
## The layout: where the rows let the board be, and what it sets there.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
## The board's sounds and sparks; none on the tutorial's silent board.
var fx: Node

func puzzle_id() -> String: return "pie"
func title() -> String: return "Who Ate the Pie?"

func rules() -> String:
	var out := tr("PI_RULES") % _st.count()
	out += "\n\n" + tr("PI_RULES_PROOF")
	out += "\n\n" + tr("PI_RULES_EMPTY" if _st.empty_dish() else "PI_RULES_DISH")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/pie_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.MARK, "HTP_PI_MARK", tr("HTP_PI_MARK_BODY")],
		[Diagram.Lesson.CLUES, "HTP_PI_CLUES", tr("HTP_PI_CLUES_BODY")],
		[Diagram.Lesson.PROOF, "HTP_PI_PROOF", tr("HTP_PI_PROOF_BODY")],
		[Diagram.Lesson.DISH, "HTP_PI_DISH", tr("HTP_PI_DISH_BODY")],
		[Diagram.Lesson.HINT, "HTP_PI_HINT", tr("HTP_PI_HINT_BODY")],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a proven mark has nothing to take back, and nothing on the
## table is ever wrong for a Check to find.
func capabilities() -> Array[String]:
	return ["hint"]

## No bin: a day started over is a day already reasoned through.
func can_reset() -> bool:
	return false

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

func _exit_tree() -> void:
	for f: Control in _faces.values():
		if is_instance_valid(f):
			f.free()
	_faces.clear()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_fresh()
	_enter_at = _t
	_cue("enter")

## Every card as dealt, nobody picked.
func _fresh() -> void:
	var n: int = _st.count()
	_flip_at.clear()
	_shake_at.clear()
	_hop_at.clear()
	for i in n:
		_flip_at.append(-10.0 if _st.is_marked(i) else -INF)
		_shake_at.append(-INF)
		_hop_at.append(-INF)
	_text.clear()
	for i in n:
		_text.append(clue_text(i))
	_sel = _st.start
	_sel_at = -INF
	_say = ""
	_leads = 0
	_nudge = 0
	_nudge_baker = -1
	_dim = 0
	_quip = ""
	_queue.clear()
	_phase = Phase.PLAY
	_relayout()

func day_dict() -> Dictionary:
	if _st.names.is_empty():
		return {}
	return {
		"source": "generator", "kind": "text",
		"payload": {"cols": _st.cols, "rows": _st.rows, "names": _st.names, "clues": _st.clues,
			"start": _st.start, "dish": _st.dish},
		"solution": {"ate": _st.ate},
		"metrics": {"bakers": _st.count(), "eaters": _st.eaters()},
	}

# --- the clues in words ---

## Baker `i`'s clue as a sentence in the player's language.
func clue_text(i: int) -> String:
	var c: Dictionary = _st.clues[i]
	if c.is_empty():
		return ""
	var n := int(c.get("n", 0))
	var a := int(c.get("a", 0))
	match int(c.k):
		Gen.Kind.NB:
			if a == i:
				return _counted("PI_NB_ME", n, [])
			return _counted("PI_NB", n, [_st.names[a]])
		Gen.Kind.ROW:
			return _counted("PI_ROW", n, [a + 1])
		Gen.Kind.COL:
			return _counted("PI_COL", n, [LETTERS[a]])
		Gen.Kind.DIR:
			var d: String = ["PI_ABOVE", "PI_BELOW", "PI_LEFT", "PI_RIGHT"][int(c.d)]
			var where: String = tr(d + "_ME") if a == i else tr(d) % _st.names[a]
			return _counted("PI_DIR", n, [where])
		Gen.Kind.EDGE:
			return _counted("PI_EDGE", n, [])
		Gen.Kind.CORNER:
			return _counted("PI_CORNER", n, [])
		Gen.Kind.PAIR:
			var key: String = ["PI_PAIR_0", "PI_PAIR_ONE", "PI_PAIR_TWO"][clampi(n, 0, 2)]
			return tr(key) % [_st.names[a], _st.names[int(c.b)]]
		Gen.Kind.ONE:
			return tr("PI_ONE_ATE" if n == 1 else "PI_ONE_NOT") % _st.names[a]
		Gen.Kind.MORE_ROW:
			return tr("PI_MORE_ROW") % [a + 1, int(c.b) + 1]
		Gen.Kind.MORE_COL:
			return tr("PI_MORE_COL") % [LETTERS[a], LETTERS[int(c.b)]]
		Gen.Kind.ODD_ROW:
			return tr("PI_ODD_ROW" if n == 1 else "PI_EVEN_ROW") % (a + 1)
		_:
			return tr("PI_ODD_COL" if n == 1 else "PI_EVEN_COL") % LETTERS[a]

## A count sentence: `stem`_0 says nobody, _ONE one, _N takes the count
## before `args`.
func _counted(stem: String, n: int, args: Array) -> String:
	if n == 0:
		return tr(stem + "_0") % args if not args.is_empty() else tr(stem + "_0")
	if n == 1:
		return tr(stem + "_ONE") % args if not args.is_empty() else tr(stem + "_ONE")
	return tr(stem + "_N") % ([n] + args)

# --- marking ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

## The player tapped baker `i`'s card.
func _select(i: int) -> void:
	if is_done() or _phase == Phase.DONE or i < 0:
		return
	if i == _sel:
		_hop_at[i] = _t
		if _st.is_marked(i):
			# a second tap on a marked baker: their clue spent, or back
			_dim ^= 1 << i
			_cue("pick", 0.85 if _dim & (1 << i) else 1.1)
		else:
			_cue("pick", 0.9)
		return
	_sel = i
	_sel_at = _t
	_say = ""
	_quip = ""
	_cue("pick", randf_range(0.96, 1.04))
	if _st.is_marked(i):
		_leads = 0
		_ring_spoken(i)
	else:
		# only the clues about them, not the last clue's fading rings
		_spoke = 0
		_leads = _st.leads(i)

## The player said the picked baker ate (`eat`) or didn't.
func _verdict(eat: bool, by_hint := false) -> void:
	if is_done() or _phase == Phase.DONE or _sel < 0 or _st.is_marked(_sel):
		return
	var i := _sel
	_press = 1 if eat else 0
	_press_at = _t
	# a baker the bulb's rings prove counts as the bulb's
	var nudged := i == _nudge_baker
	var heard: int = _st.mark(i, eat, by_hint or nudged)
	match heard:
		State.Marked.IGNORED:
			return
		State.Marked.UNPROVEN:
			_shake_at[i] = _t
			_say = "PI_SAY_UNPROVEN"
			_say_at = _t
			_cue("refuse")
			return
		State.Marked.WRONG:
			_shake_at[i] = _t
			_say = "PI_SAY_WRONG"
			_say_at = _t
			_slip_at = _t
			_cue("slip")
			return
	_say = ""
	_leads = 0
	if nudged:
		_nudge = 0
		_nudge_baker = -1
	if not by_hint:
		moves += 1
		moved.emit()
	if eat:
		_quip = "PI_QUIP_%d" % (i % QUIPS)
		_quip_at = _t + FLIP_TIME
	_flip_at[i] = _t
	_hop_at[i] = _t + FLIP_TIME * 0.5
	if eat:
		_found_at = _t + FLIP_TIME * 0.5
	var turn := FLIP_TIME * 0.5 if not Motion.reduce else 0.0
	_after(turn, func() -> void:
		_cue("caught" if eat else "clear", randf_range(0.96, 1.04))
		if not demo:
			fx.ring(_card_centre(i), _l("cw") * 0.55, Pal.BERRY if eat else Pal.LEAF)
			if eat:
				fx.puff(_header_pie(), Art.CRUMB, 5))
	_after(FLIP_TIME, func() -> void: _ring_spoken(i))
	if heard == State.Marked.SOLVED:
		_solved_now()

## Ring the bakers baker `i`'s clue speaks of, a moment.
func _ring_spoken(i: int) -> void:
	_spoke = _st.about(i)
	_spoke_at = _t

func _solved_now() -> void:
	_phase = Phase.DONE
	_sel = -1
	_won_at = _t + FLIP_TIME + 0.2
	_after(FLIP_TIME + 0.15, func() -> void: _cue("solved"))
	if not demo:
		_after(FLIP_TIME + 0.5, func() -> void:
			fx.confetti(Vector2(size.x * 0.5, _l("oy")), 26, size.x * 0.7)
			# not one slip all day: the party's toots
			_cue("party" if _st.slips == 0 else "confetti"))
	check_solved()

func is_solved() -> bool:
	return _st.solved()

## The bulb. The first press rings the fewest clues that prove somebody
## (the picked baker when they are proven) and leaves the who to the
## player; a press while those rings stand marks the baker they prove. A
## bulb a press. When the dish alone proves the baker there is nothing to
## light and the first press marks them.
func hint() -> bool:
	if hints_left() <= 0 or _phase == Phase.DONE or is_done():
		return false
	var lit := {}
	if _nudge_baker < 0 or _st.is_marked(_nudge_baker):
		lit = _st.nudge(_sel)
		if lit.is_empty():
			return false
		if int(lit.clues) == 0:
			# the dish alone proves them (every eater found, or every other
			# baker cleared): no card to light, so the press marks them
			_nudge_baker = int(lit.baker)
			lit = {}
	if lit.is_empty():
		var i := _nudge_baker
		hints_used += 1
		_cue("hint")
		_sel = i
		_sel_at = _t
		if not demo:
			fx.sparkle(_card_centre(i), Pal.SUN)
		_verdict(_st.did_eat(i), true)
		return true
	hints_used += 1
	_cue("hint")
	_nudge = int(lit.clues)
	_nudge_baker = int(lit.baker)
	_nudge_at = _t
	_sel = -1
	_leads = 0
	_say = ""
	if not demo:
		for j in _st.count():
			if _nudge & (1 << j):
				fx.sparkle(_card_centre(j), Pal.SUN)
	return true

## The bulb's rings standing, as {"clues", "baker"} (the tutorial's and the
## harness's view).
func nudge() -> Dictionary:
	return {"clues": _nudge, "baker": _nudge_baker}

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger on baker `i`, and on a verdict button.
func demo_select(i: int) -> void:
	_select(i)

func demo_mark(eat: bool) -> void:
	_verdict(eat)

func phase() -> int:
	return _phase

func state():
	return _st

func picked() -> int:
	return _sel

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
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
			_tap(event.position)
		elif finger == _pressing:
			_pressing = -2

func _tap(local: Vector2) -> void:
	var btn := button_at(local)
	if btn >= 0:
		_verdict(btn == 1)
		return
	var i := card_at(local)
	if i >= 0:
		_select(i)

## The verdict button under `local`: 0 didn't, 1 ate, -1 none (or none
## showing).
func button_at(local: Vector2) -> int:
	if not _asking():
		return -1
	for eat in 2:
		var r := _button_rect(eat == 1).grow(10.0 * _u())
		if r.has_point(local):
			return eat
	return -1

## The card under `local`, or the nearest within a little of one.
func card_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var best := -1
	var far := INF
	for i in _st.count():
		var r := _card_rect(i)
		var d := 0.0 if r.has_point(local) else local.distance_to(r.get_center()) - minf(r.size.x, r.size.y) * 0.5
		if d < far:
			far = d
			best = i
	return best if far < _l("gap") * 1.5 else -1

## Where a finger tapping baker `i`'s card goes, in this board's pixels.
func card_to_local(i: int) -> Vector2:
	return _card_centre(i)

func button_to_local(eat: bool) -> Vector2:
	return _button_rect(eat).get_center()

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
## On the win the board is not laid out again at once: it eases into the
## win's span.
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
	if size.x <= 0.0 or size.y <= 0.0 or _st.names.is_empty():
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		if not _won or _from.is_empty():
			_world.set_lines(float(_L.edge), float(_L.foot))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var cols: int = _st.cols
	var rows: int = _st.rows
	var won := _won
	var head := 104.0 * u
	var letters := 32.0 * u
	var bubble := 0.0 if won else 252.0 * u
	var gutter := 32.0 * u
	var gap := 10.0 * u
	var margin := 18.0 * u
	var cw := (w - margin * 2.0 - gutter - gap * (cols - 1)) / cols
	cw = minf(cw, 330.0 * u)
	var room := span - head - letters - bubble - margin * 1.5
	var ch := minf((room - gap * (rows - 1)) / rows, cw * 1.05)
	ch = maxf(ch, 90.0 * u)
	var grid_w := cols * cw + (cols - 1) * gap
	var grid_h := rows * ch + (rows - 1) * gap
	var used := head + letters + grid_h + bubble + margin * 0.5
	var y0 := top + maxf(0.0, (span - used) * 0.5)
	var ox := w * 0.5 - grid_w * 0.5 + gutter * 0.5
	var oy := y0 + head + letters
	var L := {
		"u": u, "top": top, "bottom": bottom, "cw": cw, "ch": ch, "gap": gap, "ox": ox, "oy": oy,
		"head_y": y0 + head * 0.5, "letters_y": oy - letters * 0.3,
		"bubble_y": oy + grid_h + 24.0 * u, "bubble_h": bubble - 24.0 * u,
		"edge": oy - letters - 20.0 * u,
		"foot": oy + grid_h + (bubble if not won else 0.0) + 16.0 * u,
	}
	_fit_text(L)
	return L

## The clue size on the cards: the largest that fits every clue of the day
## in its card, and the name size beside the face.
func _fit_text(L: Dictionary) -> void:
	var u: float = L.u
	var cw: float = L.cw
	var ch: float = L.ch
	var pad := minf(cw, ch) * 0.075
	# a marked card: a small face and the name on a row at the top, the
	# clue under them over the card's whole width
	var mini := minf(ch * 0.27, cw * 0.2)
	var room := ch - pad * 2.0 - mini * 1.08
	var width := cw - pad * 2.0
	var font: Font = CozyTheme.body(600)
	var fs := roundi(32.0 * u)
	var low := roundi(16.0 * u)
	while fs > low:
		var fits := true
		for s: String in _text:
			if font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y > room:
				fits = false
				break
		if fits:
			break
		fs -= 1
	L["clue_fs"] = fs
	L["name_fs"] = roundi(minf(34.0 * u, mini * 0.72))
	L["big_fs"] = roundi(minf(38.0 * u, ch * 0.17))
	L["pad"] = pad
	L["mini"] = mini
	L["seat"] = minf(ch * 0.52, cw * 0.46)

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L[key])
	if _from.is_empty() or not _from.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _card_rect(i: int) -> Rect2:
	var cols: int = _st.cols
	var x := _l("ox") + (i % cols) * (_l("cw") + _l("gap"))
	var y := _l("oy") + (i / cols) * (_l("ch") + _l("gap"))
	return Rect2(x, y, _l("cw"), _l("ch"))

func _card_centre(i: int) -> Vector2:
	return _card_rect(i).get_center()

func _header_pie() -> Vector2:
	return Vector2(size.x * 0.5 - 90.0 * _u(), _l("head_y"))

func _bubble_rect() -> Rect2:
	var m := 26.0 * _u()
	return Rect2(m, _l("bubble_y"), size.x - m * 2.0, _l("bubble_h"))

## Whether the bubble asks for a verdict (a baker picked and not marked).
func _asking() -> bool:
	return _sel >= 0 and not _st.is_marked(_sel) and _phase == Phase.PLAY and not _won

func _button_rect(eat: bool) -> Rect2:
	var b := _bubble_rect()
	var u := _u()
	var bw := minf(b.size.x * 0.42, 380.0 * u)
	var bh := 84.0 * u
	var gap := 30.0 * u
	var x := b.get_center().x + (gap * 0.5 if eat else -gap * 0.5 - bw)
	return Rect2(x, b.position.y + b.size.y - bh - 22.0 * u, bw, bh)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.names.is_empty():
		return
	_draw_letters()
	for i in _st.count():
		_draw_card(i)
	_draw_head()
	_draw_bubble()

## The columns' letters over the grid and the rows' numbers at its left.
func _draw_letters() -> void:
	if _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var fs := roundi(26.0 * u)
	var ink := Color(Pal.TEXT_DIM, 0.9)
	for c in _st.cols:
		var r := _card_rect(c)
		var s := LETTERS[c]
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(r.get_center().x - sw * 0.5, _l("letters_y")), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	for row in _st.rows:
		var r := _card_rect(row * _st.cols)
		var s := str(row + 1)
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(r.position.x - 22.0 * u - sw * 0.5, r.get_center().y + fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

func _face(kind: int, expr: int) -> Control:
	var key := "%d:%d" % [kind, expr]
	if not _faces.has(key):
		var f: Control = Art.baker(kind)
		f.expression = expr
		_faces[key] = f
	return _faces[key]

func _draw_card(i: int) -> void:
	var u := _u()
	var r := _card_rect(i)
	var won := _phase == Phase.DONE or is_done()
	# the cards drop onto the cloth as the board comes in, place by place
	var e: float = _t - _enter_at - Motion.ENTER_DELAY - i * Motion.ENTER_STAGGER
	if e < 0.0:
		return
	var a := 1.0
	var off := Vector2.ZERO
	if e < Motion.DROP_TIME and not Motion.reduce:
		off.y = -Motion.drop_in_lift(e, Motion.DROP * 2.0 * u)
		a = Motion.appear_level(e)
	var sh := _t - _shake_at[i]
	if sh >= 0.0 and sh < Motion.SHIVER_TIME * 2.0 and not Motion.reduce:
		off.x += Motion.shiver_offset(sh, 6.0 * u, Motion.SHIVER_TIME * 2.0)
	var hop := _t - _hop_at[i]
	if hop >= 0.0 and hop < Motion.HOP_TIME and not Motion.reduce:
		off.y += Motion.hop_lift(hop, Motion.SOLVE_HOP * 1.2 * u, Motion.HOP_TIME)
	if won and _won_at > -INF and not Motion.reduce:
		var wave: float = _t - _won_at - i * WAVE_STEP
		if wave >= 0.0 and wave < Motion.SOLVE_TIME:
			off.y += Motion.hop_lift(wave, Motion.SOLVE_HOP * 2.0 * u, Motion.SOLVE_TIME)
	# the turn over: the card narrows to an edge, its paper changes, it opens
	var marked: bool = _st.is_marked(i)
	var flip := _t - _flip_at[i]
	var sx := 1.0
	var shown := marked
	if marked and flip >= 0.0 and flip < FLIP_TIME and not Motion.reduce:
		var k := flip / FLIP_TIME
		sx = absf(cos(k * PI))
		shown = k >= 0.5
	elif marked and flip < 0.0:
		shown = false
	var paper := Art.Paper.OPEN
	if shown:
		paper = Art.Paper.ATE if _st.did_eat(i) else Art.Paper.CLEAR
	var mid := r.get_center() + off
	var base := Transform2D(0.0, Vector2(sx, 1.0), 0.0, mid) * Transform2D(0.0, -r.size * 0.5)
	var tint := Color(1, 1, 1, a)
	if i == _sel and not won:
		var k := Motion.pop_in_scale(_t - _sel_at).x if _t - _sel_at < Motion.POP_IN else 1.0
		draw_mesh(Art.halo(r.size, Pal.SUN, 7.0 * u), null,
			Transform2D(0.0, Vector2(sx * k, k), 0.0, mid) * Transform2D(0.0, -r.size * 0.5), tint)
	draw_mesh(Art.card(r.size, paper), null, base, tint)
	if _spoke & (1 << i) and _t - _spoke_at < SPOKE_TIME and i != _sel and not won:
		var fade := 1.0 - clampf((_t - _spoke_at - SPOKE_TIME * 0.6) / (SPOKE_TIME * 0.4), 0.0, 1.0)
		draw_mesh(Art.halo(r.size, Pal.ACCENT, 4.0 * u), null, base, Color(1, 1, 1, a * fade))
	if _leads & (1 << i) and not won:
		# a clue that speaks of the picked open baker, for as long as they are picked
		var k := clampf((_t - _sel_at) / Motion.POP_IN, 0.0, 1.0)
		draw_mesh(Art.halo(r.size, Pal.ACCENT, 4.0 * u), null, base, Color(1, 1, 1, a * k))
	if _nudge & (1 << i) and not won:
		# the bulb's clues breathe until the baker they prove is marked
		var glow := 0.75 + 0.25 * sin((_t - _nudge_at) * 4.0) if not Motion.reduce else 1.0
		draw_mesh(Art.halo(r.size, Pal.SUN, 6.0 * u), null, base, Color(1, 1, 1, a * glow))
	if _dim & (1 << i) and shown and not won:
		tint.a *= 0.4
	if sx < 0.15:
		return
	var pad := _l("pad")
	var expr := Face.Expr.HAPPY
	if shown:
		expr = Face.Expr.WORRIED if _st.did_eat(i) else (Face.Expr.JOY if won or flip < 1.2 else Face.Expr.HAPPY)
	elif won:
		expr = Face.Expr.JOY
	var f := _face(int(_st.faces[i]), expr)
	var font: Font = CozyTheme.display(700)
	var name: String = _st.names[i]
	if not shown:
		# an open card: the baker large in the middle, their name under them
		var seat := _l("seat")
		var fc := Vector2(r.size.x * 0.5, pad + seat * 0.62)
		_draw_baker(f, seat, base, fc, tint)
		var bfs := int(_L.big_fs)
		draw_set_transform_matrix(base)
		draw_string(font, Vector2(0.0, r.size.y - pad - bfs * 0.15), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, bfs, Color(Pal.TEXT, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var mini := _l("mini")
	var fc := Vector2(pad + mini * 0.5, pad + mini * 0.6)
	_draw_baker(f, mini, base, fc, tint)
	if _st.did_eat(i):
		draw_mesh(Art.crumbs(mini), null, base * Transform2D(0.0, fc + Vector2(0.0, mini * 0.3)), tint)
	var nfs := int(_L.name_fs)
	var body: Font = CozyTheme.body(600)
	var cfs := int(_L.clue_fs)
	draw_set_transform_matrix(base)
	draw_string(font, Vector2(pad + mini * 1.15, fc.y + nfs * 0.36), name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0 - mini * 2.0, nfs, Color(Pal.TEXT, tint.a))
	draw_multiline_string(body, Vector2(pad, pad + mini * 1.08 + cfs * 0.92), _text[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, cfs, -1, Color(Pal.TEXT, tint.a))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if shown:
		var br := minf(r.size.x, r.size.y) * 0.11
		var bk := _t - _flip_at[i] - FLIP_TIME * 0.5
		var bs := Motion.pop_in_scale(bk).x if bk < Motion.POP_IN and not Motion.reduce else 1.0
		var badge: ArrayMesh = Art.slice(br) if _st.did_eat(i) else Art.tick(br)
		draw_mesh(badge, null, base * Transform2D(0.0, Vector2.ONE * bs, 0.0, Vector2(r.size.x - br * 0.9, br * 0.9)), tint)

## A baker's face in a `seat` square centred on `fc` (card space), their
## hat on top.
func _draw_baker(f: Control, seat: float, base: Transform2D, fc: Vector2, tint: Color) -> void:
	f.size = Vector2.ONE * seat
	var fxf := base * Transform2D(0.0, fc - f.size * 0.5)
	for layer: Array in f.layers_now():
		draw_mesh(layer[0], null, fxf * (layer[1] as Transform2D), tint)
	draw_mesh(Art.hat(seat * 0.46), null, base * Transform2D(0.0, fc + Vector2(0.0, -seat * 0.38)), tint)

## The pie in its dish and how many who ate are found; the slips under it.
func _draw_head() -> void:
	var u := _u()
	var at := _header_pie()
	var bump := 1.0
	var fe := _t - _found_at
	if fe >= 0.0 and fe < Motion.BUMP_TIME and not Motion.reduce:
		bump = Motion.bump_scale(fe, 0.12)
	var slices: int = -1 if _st.empty_dish() else _st.eaters()
	draw_mesh(Art.pie(58.0 * u, slices, _st.found()), null, Transform2D(0.0, Vector2.ONE * bump, 0.0, at))
	var font: Font = CozyTheme.display(700)
	var fs := roundi(44.0 * u)
	var text: String = tr("PI_FOUND_Q") % _st.found() if _st.empty_dish() else tr("PI_FOUND") % [_st.found(), _st.eaters()]
	var x := at.x + 80.0 * u
	var y := at.y + fs * 0.1
	if _st.slips > 0 and not _won:
		y -= fs * 0.3
	draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(8 * u), Color(Pal.SURFACE, 0.85))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
	if _st.slips > 0 and not _won:
		var s: String = (tr("PI_SLIPS_ONE") if _st.slips == 1 else tr("PI_SLIPS_N")) % _st.slips
		var sfs := roundi(28.0 * u)
		var sy := y + sfs * 1.3
		var se := _t - _slip_at
		var sxo := Motion.shiver_offset(se, 5.0 * u, Motion.SHIVER_TIME * 2.0) if se >= 0.0 and se < Motion.SHIVER_TIME * 2.0 and not Motion.reduce else 0.0
		draw_string_outline(font, Vector2(x + sxo, sy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, roundi(6 * u), Color(Pal.SURFACE, 0.85))
		draw_string(font, Vector2(x + sxo, sy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Pal.BERRY_DEEP)

## The bubble: the picked baker's question and the two buttons, or their
## clue in large; a refusal's words while they last.
func _draw_bubble() -> void:
	if _won or _phase == Phase.DONE or is_done() or _l("bubble_h") <= 0.0:
		return
	var u := _u()
	var b := _bubble_rect()
	var tail := -1.0
	if _sel >= 0:
		tail = _card_centre(_sel).x - b.position.x
	draw_mesh(Art.bubble(b.size, tail), null, Transform2D(0.0, b.position))
	var font: Font = CozyTheme.display(700)
	var body: Font = CozyTheme.body(600)
	var pad := 30.0 * u
	var width := b.size.x - pad * 2.0
	var saying := _say != "" and _t - _say_at < SAY_TIME
	if _sel < 0:
		if _nudge_baker >= 0:
			_centred(font, tr("PI_NUDGE"), b, roundi(34.0 * u), Pal.TEXT)
		else:
			_centred(body, tr("PI_PICK"), b, roundi(32.0 * u), Pal.TEXT_DIM)
		return
	var name: String = _st.names[_sel]
	if _asking():
		var line: String = tr(_say) if saying else tr("PI_ASK") % name
		var ink: Color = Pal.BERRY_DEEP if saying and _say == "PI_SAY_WRONG" else (Pal.TEXT_DIM if saying else Pal.TEXT)
		var fs := roundi(36.0 * u)
		var top := b.position.y + pad * 0.5 + fs
		draw_string(font, Vector2(b.position.x + pad, top), line, HORIZONTAL_ALIGNMENT_CENTER, width, fs, ink)
		# how many of the clues showing speak of them: the ringed cards
		var n := Gen.popcount(_leads)
		var lead: String
		if n == 0:
			lead = tr("PI_LEADS_0") % name
		elif n == 1:
			lead = tr("PI_LEADS_ONE") % name
		else:
			lead = tr("PI_LEADS_N") % [n, name]
		var lfs0 := roundi(26.0 * u)
		draw_string(body, Vector2(b.position.x + pad, top + lfs0 * 1.35), lead, HORIZONTAL_ALIGNMENT_CENTER, width, lfs0, Pal.ACCENT_DEEP if n > 0 else Pal.TEXT_DIM)
		for eat in [false, true]:
			var br := _button_rect(eat)
			var down := _press == int(eat) and _t - _press_at < PRESS_TIME
			var sh := _t - _shake_at[_sel]
			var xo := 0.0
			if saying and sh >= 0.0 and sh < Motion.SHIVER_TIME * 2.0 and not Motion.reduce:
				xo = Motion.shiver_offset(sh, 4.0 * u, Motion.SHIVER_TIME * 2.0)
			draw_mesh(Art.button(br.size, eat, down), null, Transform2D(0.0, br.position + Vector2(xo, 0.0)))
			var label: String = tr("PI_ATE" if eat else "PI_NOT")
			var lfs := roundi(34.0 * u)
			var lift := 0.0 if down else br.size.y * 0.08
			var tx := br.position.x + br.size.y + xo
			var ty := br.position.y + br.size.y * 0.58 + br.size.y * 0.08 - lift + lfs * 0.3
			draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_CENTER, br.size.x - br.size.y * 1.2, lfs, Pal.SURFACE)
		return
	# a marked baker: their clue, large
	var text: String = _text[_sel]
	var fs := roundi(36.0 * u)
	var low := roundi(24.0 * u)
	var room := b.size.y - pad * 2.0
	var full := name + ": " + text
	if _quip != "" and _t - _quip_at < QUIP_TIME and _t >= _quip_at:
		full = tr(_quip) + "\n" + full
	while fs > low and body.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, width, fs).y > room:
		fs -= 1
	var hgt := body.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_CENTER, width, fs).y
	var y := b.position.y + (b.size.y - hgt) * 0.5 + fs * 0.95
	draw_multiline_string(body, Vector2(b.position.x + pad, y), full, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, Pal.TEXT)

func _centred(font: Font, text: String, b: Rect2, fs: int, ink: Color) -> void:
	draw_string(font, Vector2(b.position.x, b.get_center().y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, b.size.x, fs, ink)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.names.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🥧 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.slips == 0:
		line = tr("PI_WIN_CLEAN")
	else:
		line = (tr("PI_WIN_SLIPS_ONE") if _st.slips == 1 else tr("PI_WIN_SLIPS_N")) % _st.slips
	return {"faces": [], "subtitle": tr("PI_WIN") % _st.eaters() + " " + line}

func completion_record() -> Dictionary:
	return {"history": Array(_st.history)}

## A finished day reopens with every card turned over.
func restore_completed_board() -> void:
	_queue.clear()
	_st.finish(completed_record.get("history", []) as Array)
	for i in _st.count():
		_flip_at[i] = -10.0
	_sel = -1
	_phase = Phase.DONE
	_won_at = _t
	queue_redraw()
