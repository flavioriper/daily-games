extends "res://core/puzzle_base.gd"

## Teacups (spec docs/superpowers/specs/2026-10-22-teacups-design.md): a
## memory board. Cups stand upside down on their saucers across a garden tea
## table, a little friend hidden under each and every friend under two cups.
## Tap a cup to lift it, then another: the same friend under both is a pair
## found, and the two cups fly off leaving the friends on their saucers; two
## different friends are shown a moment and covered again. Every pair found
## is the solve. The rules are puzzles/teacups_state.gd's.
##
## **The table is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/teacups_world.gd) is the board's first child. The cups and
## saucers are ui/faces/teacup.gd's; the friends are the house's own faces,
## one node per friend and look, never in the tree, drawn by this board
## from their `layers_now()`.
##
## A lift rides up and tips the cup off its friend; a cup put back drops and
## lands with a bump. A miss holds both friends worried a moment, then
## covers them -- a tap on another cup covers them at once and lifts it. On
## Insane (Waltz) every second miss sets two hidden cups wiggling, then
## swapping places in plain sight. The bulb peeks: the partner of the cup in
## hand, or a pair still hidden when none is. No Undo (a cup seen cannot be
## unseen) and no bin (a day started over would be a day remembered).
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/teacups_tutorial_diagram.gd plays it with `demo_tap`.

const State = preload("res://puzzles/teacups_state.gd")
const World = preload("res://puzzles/teacups_world.gd")
const Cup = preload("res://ui/faces/teacup.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Phase { PLAY, HOLD, BUSY, DONE }

const HAPTICS := {
	"lift": Haptics.TAP,
	"down": Haptics.TICK,
	"pair": Haptics.GOOD,
	"miss": Haptics.WARN,
	"hush": Haptics.TICK,
	"waltz": Haptics.TICK,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## A cup going up, coming down, and how long a miss is shown.
const LIFT_TIME := 0.2
const DROP_TIME := 0.16
const MISS_HOLD := 0.9
## How high a lifted cup rides and how far it tips, in its mouth's half width
## and radians.
const RISE := 1.25
const TIP := 0.34
const SLIDE := 0.32
## A found pair's cups flying off.
const GONE_TIME := 0.35
const GONE_RISE := 2.2
## The bulb's peek.
const PEEK_TIME := 1.0
## Insane: the wiggle before a waltz and the waltz itself.
const WIGGLE := 0.4
const WALTZ_TIME := 0.75
## A friend's hop and how long a worried look lasts.
const HOP_TIME := 0.35
const WORRY_TIME := 0.9
## The win: the friends' wave, how long the board's own win plays.
const WIN_HOLD := 1.4
const WAVE_STEP := 0.05
## The count line under the table, at W.
const COUNT_SIZE := 30

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _phase := Phase.PLAY
## The board's own clock: it stands while a sheet lies over the board.
var _t := 0.0
## [time, Callable] run when the clock reaches them, in order.
var _queue: Array = []
## Per cup id: whether it is up, since when; when it flew off (found); when
## it was last wiggled or shaken; when its friend last hopped or worried;
## where it waltzed from and when; its peek's token.
var _up: Array[bool] = []
var _up_at: Array[float] = []
var _gone_at: Array[float] = []
var _wiggle_at: Array[float] = []
var _shake_at: Array[float] = []
var _hop_at: Array[float] = []
var _worry_until: Array[float] = []
var _waltz_from: Array[int] = []
var _waltz_at: Array[float] = []
var _waltz_dir: Array[float] = []
var _peek_tok: Array[int] = []
## The two cups a miss holds up.
var _held: Array[int] = []
## The friends' nodes, "kind:expression" -> Control (never in the tree).
var _friends := {}
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
var _table: ArrayMesh
var _table_key := ""
## The board's sounds and sparks; none on the tutorial's silent board.
var fx: Node

func puzzle_id() -> String: return "teacups"
func title() -> String: return "Teacups"

func rules() -> String:
	var out := tr("TC_RULES") % [_st.cups(), _st.pairs()]
	out += "\n\n" + tr("TC_RULES_LAPSE")
	if _st.waltzes():
		out += "\n\n" + tr("TC_RULES_WALTZ")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/teacups_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LIFT, "HTP_TC_LIFT", tr("HTP_TC_LIFT_BODY")],
		[Diagram.Lesson.PAIR, "HTP_TC_PAIR", tr("HTP_TC_PAIR_BODY")],
		[Diagram.Lesson.REMEMBER, "HTP_TC_REMEMBER", tr("HTP_TC_REMEMBER_BODY")],
	]
	if _st.waltzes():
		steps.append([Diagram.Lesson.WALTZ, "HTP_TC_WALTZ", tr("HTP_TC_WALTZ_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_TC_HINT", tr("HTP_TC_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a cup seen cannot be unseen, and nothing on the table is
## ever wrong for a Check to find.
func capabilities() -> Array[String]:
	return ["hint"]

## No bin: the same table started over would be a table remembered.
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
	for f: Control in _friends.values():
		if is_instance_valid(f):
			f.free()
	_friends.clear()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_fresh()
	_enter_at = _t
	_cue("enter")

## Every cup down and still.
func _fresh() -> void:
	var n: int = _st.cups()
	_up.clear()
	_up_at.clear()
	_gone_at.clear()
	_wiggle_at.clear()
	_shake_at.clear()
	_hop_at.clear()
	_worry_until.clear()
	_waltz_from.clear()
	_waltz_at.clear()
	_waltz_dir.clear()
	_peek_tok.clear()
	for c in n:
		_up.append(false)
		_up_at.append(-INF)
		_gone_at.append(-INF)
		_wiggle_at.append(-INF)
		_shake_at.append(-INF)
		_hop_at.append(-INF)
		_worry_until.append(0.0)
		_waltz_from.append(-1)
		_waltz_at.append(-INF)
		_waltz_dir.append(1.0)
		_peek_tok.append(0)
	_held.clear()
	_queue.clear()
	_phase = Phase.PLAY
	_relayout()

func day_dict() -> Dictionary:
	if _st.kind.is_empty():
		return {}
	return {
		"source": "generator", "kind": "text",
		"payload": {"cols": _st.cols(), "rows": _st.rows(), "waltz": _st.waltzes()},
		"solution": {"kind": Array(_st.kind), "slot": Array(_st.slot)},
		"metrics": {"pairs": _st.pairs(), "cups": _st.cups()},
	}

# --- the cups ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _raise(c: int) -> void:
	if _up[c]:
		return
	_up[c] = true
	_up_at[c] = _t
	_peek_tok[c] += 1

func _lower(c: int) -> void:
	if not _up[c] or _st.found[c]:
		return
	_up[c] = false
	_up_at[c] = _t
	_peek_tok[c] += 1
	var land := DROP_TIME if not Motion.reduce else 0.0
	_after(land, func() -> void: _cue("down", randf_range(0.95, 1.05)))

## The player tapped the cup at place `s`.
func _tap(s: int) -> void:
	if is_done() or _won or _phase == Phase.DONE:
		return
	if _phase == Phase.BUSY:
		_cue("hush")
		return
	if _phase == Phase.HOLD:
		_end_hold()
		if _phase != Phase.PLAY:
			_cue("hush")
			return
	var c: int = _st.cup_at(s)
	if c < 0:
		return
	if _st.found[c]:
		# a friend already found says hello
		_hop_at[c] = _t
		_cue("hush")
		return
	if c == _st.first:
		_wiggle_at[c] = _t
		_cue("hush")
		return
	var a: int = _st.first
	var heard: int = _st.lift(s)
	if heard == State.Lifted.IGNORED:
		return
	moves += 1
	moved.emit()
	_raise(c)
	_cue("lift", randf_range(0.96, 1.04))
	match heard:
		State.Lifted.MISS:
			_held = [a, c]
			_phase = Phase.HOLD
			_after(0.22, func() -> void:
				_cue("miss")
				for k in [a, c]:
					_worry_until[k] = _t + WORRY_TIME)
			_after(MISS_HOLD, _miss_over)
		State.Lifted.PAIR:
			_found(a, c)
		State.Lifted.SOLVED:
			_found(a, c)
			_solved_now()

## Two cups of one friend: they fly off, the friends hop on their saucers.
func _found(a: int, c: int) -> void:
	var at := _t + LIFT_TIME * 0.8
	for k in [a, c]:
		_gone_at[k] = at
		_hop_at[k] = at
	_after(LIFT_TIME * 0.8, func() -> void:
		_cue("pair")
		if not demo:
			for k in [a, c]:
				fx.sparkle(_friend_at(k), Pal.SUN))

func _miss_over() -> void:
	if _phase == Phase.HOLD:
		_end_hold()

## The cups a miss held up go down; on Insane a waltz may follow.
func _end_hold() -> void:
	for c in _held:
		_lower(c)
		_worry_until[c] = 0.0
	_held.clear()
	_phase = Phase.PLAY
	if _st.waltz_due():
		_phase = Phase.BUSY
		_after(DROP_TIME + 0.1, _waltz)

## Insane: two hidden cups wiggle, then trade places along two arcs.
func _waltz() -> void:
	var from := {}
	for c in _st.hidden():
		from[c] = _st.slot[c]
	var pair: Array[int] = _st.waltz()
	for i in pair.size():
		var c: int = pair[i]
		_waltz_from[c] = int(from[c])
		_wiggle_at[c] = _t
		_waltz_at[c] = _t + WIGGLE
		_waltz_dir[c] = 1.0 if i == 0 else -1.0
	_after(WIGGLE, func() -> void: _cue("waltz"))
	_after(WIGGLE + WALTZ_TIME, func() -> void:
		_cue("down")
		if _phase == Phase.BUSY:
			_phase = Phase.PLAY)

func _solved_now() -> void:
	_phase = Phase.DONE
	_queue.clear()
	_won_at = _t + 0.3
	_after(0.25, func() -> void: _cue("solved"))
	if not demo:
		_after(0.6, func() -> void:
			fx.confetti(Vector2(size.x * 0.5, _l("oy")), 26, size.x * 0.7)
			# not one partner forgotten all day: the party's toots
			_cue("party" if _st.lapses == 0 else "confetti"))
	check_solved()

func is_solved() -> bool:
	return _st.solved()

## The bulb: the partner of the cup in hand peeks out, or with no cup in
## hand a pair still hidden does.
func hint() -> bool:
	if hints_left() <= 0 or _phase == Phase.DONE or _phase == Phase.BUSY or is_done():
		return false
	hints_used += 1
	_cue("hint")
	if _phase == Phase.HOLD:
		_end_hold()
	if _phase == Phase.BUSY:
		_after(WIGGLE + WALTZ_TIME + DROP_TIME + 0.15, _peek)
	else:
		_peek()
	return true

func _peek() -> void:
	for c in _st.peek():
		_raise(c)
		_hop_at[c] = _t + LIFT_TIME
		var tok: int = _peek_tok[c]
		_after(PEEK_TIME, func() -> void:
			if _peek_tok[c] == tok and c != _st.first and not _held.has(c):
				_lower(c))

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger on the cup at place `s`.
func demo_tap(s: int) -> void:
	_tap(s)

func phase() -> int:
	return _phase

func state():
	return _st

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
			var s := slot_at(event.position)
			if s >= 0:
				_tap(s)
		elif finger == _pressing:
			_pressing = -2

## The place a finger at `local` means: the nearest cup, if the finger is
## within a cell of it (the nearest action, never a miss for a thumb a
## little off).
func slot_at(local: Vector2) -> int:
	if _L.is_empty():
		return -1
	var best := -1
	var far := INF
	for s in _st.cups():
		var d := local.distance_to(_slot_pos(s) + Vector2(0.0, -_l("r") * 0.5))
		if d < far:
			far = d
			best = s
	return best if far < _l("cw") * 0.8 else -1

## Where a finger lifting the cup at place `s` goes, in this board's pixels.
func slot_to_local(s: int) -> Vector2:
	return _slot_pos(s) + Vector2(0.0, -_l("r") * 0.5)

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
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		# the table stays where play left it on the win, so the hedge never
		# climbs behind the win's words
		if not _won or _from.is_empty():
			_world.set_lines(float(_L.edge), float(_L.foot))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 200.0 * u)
	var cols: int = maxi(1, _st.cols())
	var rows: int = maxi(1, _st.rows())
	var count_h := 0.0 if demo else 70.0 * u
	# a cell: the row pitch is 0.8 of it, a lifted top cup needs 0.75 over
	# the first row's mouths and a saucer 0.3 under the last's
	var cw := minf(w * 0.92 / cols, (span - count_h) / ((rows - 1) * 0.8 + 1.1))
	cw = minf(cw, 320.0 * u)
	var ph := cw * 0.8
	var grid_h := (rows - 1) * ph + cw * 1.05
	var oy := top + (span - count_h - grid_h) * 0.5 + cw * 0.75
	var ox := w * 0.5 - cols * cw * 0.5
	var foot := oy + (rows - 1) * ph + cw * 0.3
	return {
		"u": u, "top": top, "bottom": bottom,
		"cw": cw, "ph": ph, "r": cw * 0.3, "ox": ox, "oy": oy,
		"foot": foot, "count_y": foot + 50.0 * u,
		# the cloth's far edge sits a little over the first row's cups
		"edge": maxf(top + 10.0 * u, oy - cw * 0.62),
	}

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

## The middle of the mouth of the saucer at place `s`.
func _slot_pos(s: int) -> Vector2:
	var cols: int = _st.cols()
	return Vector2(_l("ox") + (s % cols + 0.5) * _l("cw"), _l("oy") + (s / cols) * _l("ph"))

## Where cup `c` stands now: its place, or along its waltz.
func _cup_pos(c: int) -> Vector2:
	var to := _slot_pos(_st.slot[c])
	var e := _t - _waltz_at[c]
	if _waltz_from[c] < 0 or e >= WALTZ_TIME or Motion.reduce:
		return to
	var from := _slot_pos(_waltz_from[c])
	if e < 0.0:
		return from
	var k := clampf(e / WALTZ_TIME, 0.0, 1.0)
	var s := k * k * (3.0 - 2.0 * k)
	var side := (to - from).orthogonal().normalized() * _l("cw") * 0.42 * _waltz_dir[c]
	return from.lerp(to, s) + side * sin(k * PI)

## How far cup `c` is lifted, 0 down to 1 up.
func _lift(c: int) -> float:
	if Motion.reduce:
		return 1.0 if _up[c] else 0.0
	var e := _t - _up_at[c]
	if _up[c]:
		return Motion.back_out(clampf(e / LIFT_TIME, 0.0, 1.0))
	if _up_at[c] == -INF:
		return 0.0
	var k := clampf(e / DROP_TIME, 0.0, 1.0)
	return 1.0 - k * k

func _friend_at(c: int) -> Vector2:
	return _slot_pos(_st.slot[c]) + Vector2(0.0, -_l("r") * 0.42)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.kind.is_empty():
		return
	_draw_table()
	var order: Array[int] = []
	for c in _st.cups():
		order.append(c)
	# far rows first, so a nearer cup stands in front
	order.sort_custom(func(a: int, b: int) -> bool: return _cup_pos(a).y < _cup_pos(b).y)
	for c in order:
		_draw_friend(c)
		_draw_cup(c)
	_draw_count()

## The saucers, one cached mesh a layout.
func _draw_table() -> void:
	var r := _l("r")
	var key := "%d:%d:%d:%d" % [roundi(size.x), roundi(_l("ox")), roundi(_l("oy")), roundi(r * 4.0)]
	if key != _table_key:
		_table_key = key
		var b := Face.Builder.new()
		for s in _st.cups():
			Cup.saucer(b, _slot_pos(s), r)
		_table = b.mesh()
	draw_mesh(_table, null)

func _friend(kind: int, expr: int) -> Control:
	var key := "%d:%d" % [kind, expr]
	if not _friends.has(key):
		var f: Control = Cup.friend(kind)
		f.expression = expr
		_friends[key] = f
	return _friends[key]

func _draw_friend(c: int) -> void:
	var lift := _lift(c)
	# -INF until the pair is found: a friend is never drawn under a cup that
	# stands on it, or its edge would show under the rim
	var gone := _t - _gone_at[c] if _gone_at[c] > -INF else -1.0
	var won := _phase == Phase.DONE or is_done()
	if lift <= 0.02 and gone < 0.0 and not won:
		return
	var r := _l("r")
	var seat := r * 1.55
	var k := 1.0 if gone >= 0.0 or won else clampf(lift * 1.4, 0.0, 1.0)
	var at := _friend_at(c)
	var u := _u()
	var hop := _t - _hop_at[c]
	if hop >= 0.0 and hop < HOP_TIME:
		at.y += Motion.hop_lift(hop, Motion.SOLVE_HOP * 1.6 * u, HOP_TIME)
	if won and _won_at > -INF:
		var wave: float = _t - _won_at - _st.slot[c] * WAVE_STEP
		if wave >= 0.0:
			at.y += Motion.hop_lift(fmod(wave, 1.2), Motion.SOLVE_HOP * 2.0 * u, Motion.SOLVE_TIME) if not Motion.reduce else 0.0
	if _st.found[c] and gone >= 0.0:
		var ring_k := Motion.pop_in_scale(gone).x if gone < Motion.POP_IN else 1.0
		draw_mesh(Cup.found_ring(r), null, Transform2D(0.0, Vector2.ONE * ring_k, 0.0, _slot_pos(_st.slot[c])))
	var expr := Face.Expr.HAPPY
	if _st.found[c] or won:
		expr = Face.Expr.JOY
	elif _t < _worry_until[c]:
		expr = Face.Expr.WORRIED
	var f := _friend(_st.kind[c], expr)
	f.size = Vector2.ONE * seat
	var base := Transform2D(0.0, Vector2.ONE * k, 0.0, at) * Transform2D(0.0, -f.size * 0.5)
	for layer: Array in f.layers_now():
		draw_mesh(layer[0], null, base * (layer[1] as Transform2D))

func _draw_cup(c: int) -> void:
	var r := _l("r")
	var u := _u()
	var gone := _t - _gone_at[c]
	var a := 1.0
	var at := _cup_pos(c)
	var lift := _lift(c)
	var rise := lift * RISE * r
	var tip := lift * TIP
	var slide := lift * SLIDE * r
	if _gone_at[c] > -INF and gone >= 0.0:
		if gone >= GONE_TIME or Motion.reduce:
			return
		var k := gone / GONE_TIME
		rise += k * k * GONE_RISE * r
		a = 1.0 - k
	# the cups drop onto the table as the board comes in, place by place
	var e: float = _t - _enter_at - Motion.ENTER_DELAY - _st.slot[c] * Motion.ENTER_STAGGER
	if e < 0.0:
		return
	var drop := 0.0
	if e < Motion.DROP_TIME:
		drop = -Motion.drop_in_lift(e, Motion.DROP * 2.0 * u)
		a *= Motion.appear_level(e)
	var squash := 1.0
	if not _up[c] and _up_at[c] > -INF:
		var land := _t - _up_at[c] - DROP_TIME
		if land >= 0.0 and land < Motion.BUMP_TIME:
			squash = Motion.bump_scale(land, 0.08)
	var turn := 0.0
	var wig := _t - _wiggle_at[c]
	if wig >= 0.0 and wig < WIGGLE:
		turn += Motion.wobble_angle(wig, 0.14, WIGGLE)
	var shadow_k := clampf(1.0 - lift * 0.5, 0.3, 1.0)
	draw_mesh(Cup.shadow(r), null, Transform2D(0.0, Vector2(shadow_k, shadow_k), 0.0, at), Color(1, 1, 1, a * shadow_k))
	var xf := Transform2D(tip + turn, Vector2(1.0 / squash, squash), 0.0, at + Vector2(slide, -rise + drop))
	draw_mesh(Cup.cup(r), null, xf, Color(1, 1, 1, a))

## How many pairs are found of how many, and the lifts so far.
func _draw_count() -> void:
	if demo or is_done() or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var lifts: String = (tr("TC_LIFTS_ONE") if _st.lifts == 1 else tr("TC_LIFTS_N")) % _st.lifts
	var text: String = tr("TC_PAIRS") % [_st.pairs_found, _st.pairs()] + "  ·  " + lifts
	var cs := roundi(COUNT_SIZE * u)
	var cw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var at := Vector2(size.x * 0.5 - cw * 0.5, _l("count_y"))
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(8 * u), Color(Pal.SURFACE, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT_DIM)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.kind.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "☕ " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.lapses == 0:
		line = tr("TC_WIN_SHARP")
	else:
		line = (tr("TC_WIN_LAPSES_ONE") if _st.lapses == 1 else tr("TC_WIN_LAPSES_N")) % _st.lapses
	return {"faces": [], "subtitle": tr("TC_WIN") % _st.lifts + " " + line}

func completion_record() -> Dictionary:
	return {"history": Array(_st.history), "lifts": _st.lifts}

## A finished day reopens with every friend on its saucer, the cups gone.
func restore_completed_board() -> void:
	_queue.clear()
	_st.finish(completed_record.get("history", []) as Array, int(completed_record.get("lifts", 0)))
	for c in _st.cups():
		_gone_at[c] = -10.0
		_up[c] = true
		_up_at[c] = -10.0
	_phase = Phase.DONE
	_won_at = _t
	queue_redraw()
