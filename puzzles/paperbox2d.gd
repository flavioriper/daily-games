extends "res://core/puzzle_base.gd"

## Paper Box (spec docs/superpowers/specs/2026-10-22-paperbox-design.md): a
## space board. A flat paper net of six coloured squares lies on a cutting
## mat on a craft table, and three or four paper boxes stand on the table
## under it; one of them is the box the net folds into. Tap it. A wrong box
## is struck off with a pencil cross and counted; the right one sets the net
## folding up into its box in front of the player, the box turning to show
## the very corner that was picked, then flying up to the shelf on the wall.
## Five boxes on the shelf is the day. The rules are
## puzzles/paperbox_state.gd's, the fold puzzles/paperbox_fold.gd's.
##
## **The table is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/paperbox_world.gd) is the board's first child. The papers,
## boxes, stamps and the pencil's hatch are ui/faces/paperbox_art.gd's.
##
## No Undo (a pick is a pick) and no bin (a day started over would be a day
## already seen). The bulb strikes one wrong box off.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/paperbox_tutorial_diagram.gd plays it with `demo_tap`.

const State = preload("res://puzzles/paperbox_state.gd")
const Fold = preload("res://puzzles/paperbox_fold.gd")
const World = preload("res://puzzles/paperbox_world.gd")
const Art = preload("res://ui/faces/paperbox_art.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Phase { PLAY, FOLD, DONE }

const HAPTICS := {
	"pick": Haptics.TAP,
	"wrong": Haptics.WARN,
	"fold": Haptics.TICK,
	"made": Haptics.GOOD,
	"shelf": Haptics.TICK,
	"hush": Haptics.TICK,
	"hint": Haptics.GOOD,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## The right pick's play, in seconds: the box held, the net tilting toward
## the eye, each hinge folding (one after another), the box turning to the
## picked corner, shown, then flown to the shelf.
const HOLD := 0.3
const LIFT := 0.38
const HINGE_STEP := 0.15
const HINGE_TIME := 0.34
const TURN := 0.5
const SHOW := 0.4
const FLY := 0.42
## A new net sliding onto the mat, and the boxes dropping in after it.
const SLIDE_TIME := 0.42
const BOX_STAGGER := 0.08
## A struck box's dimming.
const STRUCK_ALPHA := 0.42
## The win: the board's own play before the host's win.
const WIN_HOLD := 1.2
## The words, at W.
const COUNT_SIZE := 30
const ASK_SIZE := 30

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _phase := Phase.PLAY
## The board's own clock: it stands while a sheet lies over the board.
var _t := 0.0
## [time, Callable] run when the clock reaches them, in order.
var _queue: Array = []
## When this round's net came to the mat; when its box was picked right.
var _round_at := 0.0
var _pick_at := -INF
var _picked := -1
## Per option: when it was struck (by a wrong pick or the bulb), and
## whether the bulb did it.
var _struck_at: Array[float] = []
var _hinted: Array[bool] = []
var _won_at := -INF
var _pressing := -2
## The layout: where the rows let the board be, and what it sets there.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _world: Control
## Meshes kept until the next replaces them: the net at rest, the shelf,
## the fold's frame, and the boxes by key.
var _net_mesh: ArrayMesh
var _net_key := ""
var _shelf_mesh: ArrayMesh
var _shelf_key := ""
var _fold_mesh: ArrayMesh
var _boxes := {}
var _used := {}
## The board's sounds and sparks; none on the tutorial's silent board.
var fx: Node

func puzzle_id() -> String: return "paperbox"
func title() -> String: return "Paper Box"

func rules() -> String:
	var out := tr("PB_RULES") % [State.ROUNDS, int(State.CHOICES[_band])]
	out += "\n\n" + tr("PB_RULES_TIP")
	if _st.stamped():
		out += "\n\n" + tr("PB_RULES_STAMPED")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/paperbox_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.FOLD, "HTP_PB_FOLD", tr("HTP_PB_FOLD_BODY")],
		[Diagram.Lesson.OPPOSITE, "HTP_PB_OPPOSITE", tr("HTP_PB_OPPOSITE_BODY")],
		[Diagram.Lesson.CORNER, "HTP_PB_CORNER", tr("HTP_PB_CORNER_BODY")],
	]
	if _st.stamped():
		steps.append([Diagram.Lesson.STAMPS, "HTP_PB_STAMPS", tr("HTP_PB_STAMPS_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_PB_HINT", tr("HTP_PB_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a pick cannot be taken back, and the board says itself
## whether a pick was right.
func capabilities() -> Array[String]:
	return ["hint"]

## No bin: the same day started over would be a day already seen.
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

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_queue.clear()
	_phase = Phase.PLAY
	_fresh_round()
	_cue("enter")

func _fresh_round() -> void:
	_round_at = _t
	_pick_at = -INF
	_picked = -1
	_struck_at.clear()
	_hinted.clear()
	for o in _st.struck.size():
		_struck_at.append(-INF)
		_hinted.append(false)
	_net_key = ""
	_relayout()

func day_dict() -> Dictionary:
	if _st.rounds.is_empty():
		return {}
	var rounds := []
	for r: Dictionary in _st.rounds:
		var net := []
		for p: Vector2i in r.net:
			net.append([p.x, p.y])
		rounds.append({"net": net, "colours": Array(r.colours), "ways": Array(r.ways), "answer": r.answer, "kinds": Array(r.kinds)})
	return {
		"source": "generator", "kind": "text",
		"payload": {"rounds": rounds, "stamped": _st.stamped()},
		"solution": {"answers": rounds.map(func(r: Dictionary) -> int: return int(r.answer))},
		"metrics": {"rounds": State.ROUNDS, "choices": int(State.CHOICES[_band])},
	}

# --- picks ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

## The player tapped box `o`.
func _tap(o: int) -> void:
	if is_done() or _won or _phase == Phase.DONE:
		return
	if _phase == Phase.FOLD:
		_cue("hush")
		return
	if o < 0 or o >= _st.struck.size():
		return
	if _st.struck[o]:
		# a struck box only shakes its head again
		_struck_at[o] = _t
		_hinted[o] = false
		_cue("hush")
		return
	var heard: int = _st.pick(o)
	if heard == State.Picked.IGNORED:
		return
	moves += 1
	moved.emit()
	if heard == State.Picked.WRONG:
		_struck_at[o] = _t
		_cue("wrong")
		return
	_picked = o
	_pick_at = _t
	_phase = Phase.FOLD
	_cue("pick")
	if not demo:
		fx.ring(_opt_pos(o), _l("bs") * 1.3, Pal.GOOD)
	if Motion.reduce:
		_after(Motion.REDUCED_TIME, _land)
		return
	var hinges: int = Fold.NETS[0].size() - 1
	for i in hinges:
		_after(HOLD + LIFT + i * HINGE_STEP, func() -> void: _cue("fold", 1.0 + i * 0.06))
	_after(_turn_end(), func() -> void:
		_cue("made")
		if not demo:
			fx.sparkle(_mat_centre(), Pal.SUN))
	_after(_fly_end(), _land)

func _fold_end() -> float:
	return HOLD + LIFT + (Fold.NETS[0].size() - 2) * HINGE_STEP + HINGE_TIME

func _turn_end() -> float:
	return _fold_end() + TURN

func _fly_end() -> float:
	return _turn_end() + SHOW + FLY

## The picked box lands on the shelf; the next net comes, or the day is done.
func _land() -> void:
	var slot: int = _st.current
	_st.advance()
	_cue("shelf", 1.0 + slot * 0.05)
	if not demo:
		fx.ring(_shelf_pos(slot), _l("ss") * 1.4, Pal.SUN)
	_shelf_key = ""
	if _st.solved():
		_solved_now()
		return
	_phase = Phase.PLAY
	_fresh_round()
	_cue("enter")

func _solved_now() -> void:
	_phase = Phase.DONE
	_queue.clear()
	_won_at = _t + 0.2
	_after(0.2, func() -> void: _cue("solved"))
	if not demo:
		_after(0.5, func() -> void:
			fx.confetti(Vector2(size.x * 0.5, _l("shelf") - _l("ss")), 26, size.x * 0.7)
			# five boxes, not one wrong pick: the party's toots
			_cue("party" if _st.wrongs == 0 else "confetti"))
	_relayout()
	check_solved()

func is_solved() -> bool:
	return _st.solved()

## The bulb: one wrong box still standing is struck off.
func hint() -> bool:
	if hints_left() <= 0 or _phase != Phase.PLAY or is_done():
		return false
	var o: int = _st.strike()
	if o < 0:
		return false
	hints_used += 1
	_struck_at[o] = _t
	_hinted[o] = true
	_cue("hint")
	if not demo:
		fx.ring(_opt_pos(o), _l("bs") * 1.3, Pal.SUN)
	return true

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger on box `o`.
func demo_tap(o: int) -> void:
	_tap(o)

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
			var o := option_at(event.position)
			if o >= 0:
				_tap(o)
			elif not _won and not is_done():
				_cue("hush")
		elif finger == _pressing:
			_pressing = -2

## The box a finger at `local` means: the nearest, if the finger is within
## its slot (the nearest action, never a miss for a thumb a little off), and
## never a finger on the mat over them.
func option_at(local: Vector2) -> int:
	if _L.is_empty() or _won or is_done():
		return -1
	if local.y < _l("opt_y") - _l("bs") * 1.15:
		return -1
	var best := -1
	var far := INF
	for o in _st.struck.size():
		var d := local.distance_to(_opt_pos(o))
		if d < far:
			far = d
			best = o
	return best if far < minf(_l("slot") * 0.6, _l("bs") * 1.25) else -1

## Where a finger picking box `o` goes, in this board's pixels.
func option_to_local(o: int) -> Vector2:
	return _opt_pos(o)

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
func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	_won = won
	_relayout()

func set_shift(x: float, leaving := false) -> void:
	_shift = x
	position.x = x
	if _world != null:
		_world.position.x = -x
		_world.visible = not leaving

func skip_entrance() -> void:
	_round_at = -10.0

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	_shelf_key = ""
	_net_key = ""
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		var ended := _won or is_done() or _phase == Phase.DONE
		_world.set_lines(float(_L.shelf), Rect2() if ended else _L.mat as Rect2, float(_L.edge), float(_L.count_y))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 300.0 * u)
	var n: int = maxi(3, _st.struck.size())
	var ended := _won or is_done() or _phase == Phase.DONE
	if ended:
		# the win: the shelf of five, big, in the middle of the span
		var ss := minf(w * 0.86 / State.ROUNDS / 1.9, span * 0.22)
		var shelf := top + span * 0.5 + ss
		return {"u": u, "top": top, "bottom": bottom, "ss": ss, "shelf": shelf,
			"edge": shelf + 60.0 * u, "slot": 0.0, "bs": ss, "mat": Rect2(), "opt_y": 0.0,
			"cell": ss, "count_y": 0.0}
	var count_h := 0.0 if demo else 64.0 * u
	# the shelf: five small boxes standing on it
	var ss := minf(46.0 * u, span * 0.04)
	var shelf := top + ss * 2.0 + 18.0 * u
	var edge := shelf + 52.0 * u
	# the boxes to pick from, across the foot
	var slot := w * 0.92 / n
	var bs := minf(slot * 0.8 / (2.0 * Fold.C30), minf(118.0 * u, span * 0.1))
	var opt_y := bottom - count_h - 30.0 * u - bs * 1.3
	# the mat between them, the net laid in it
	var mat_top := edge + 30.0 * u
	var mat_bot := opt_y - bs * 1.0 - 34.0 * u
	var mat := Rect2(w * 0.06, mat_top, w * 0.88, maxf(mat_bot - mat_top, 120.0 * u))
	var ext := Fold.extent(_st.now().net) if not _st.rounds.is_empty() else Vector2i(4, 3)
	var ask := 0.0 if demo else ASK_SIZE * 2.0 * u
	var cell := minf((mat.size.x - 90.0 * u) / ext.x, (mat.size.y - 70.0 * u - ask) / ext.y)
	cell = clampf(cell, 20.0 * u, 168.0 * u)
	return {
		"u": u, "top": top, "bottom": bottom, "ss": ss, "shelf": shelf, "edge": edge,
		"slot": slot, "bs": bs, "opt_y": opt_y, "mat": mat, "cell": cell,
		"net_c": Vector2(mat.get_center().x, mat.position.y + ask + (mat.size.y - ask) * 0.5),
		"ask_y": mat.position.y + 26.0 * u + ASK_SIZE * u,
		"count_y": bottom - 34.0 * u,
	}

func _l(key: String) -> float:
	return float(_L.get(key, 0.0))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _mat_centre() -> Vector2:
	return _L.get("net_c", Vector2.ZERO)

## The middle of box `o` at rest.
func _opt_pos(o: int) -> Vector2:
	var n: int = maxi(1, _st.struck.size())
	return Vector2(size.x * 0.5 + (o - (n - 1) * 0.5) * _l("slot"), _l("opt_y"))

## The middle of the shelf's box `k`.
func _shelf_pos(k: int) -> Vector2:
	var ss := _l("ss")
	var gap := minf(size.x * 0.84 / State.ROUNDS, ss * 3.4)
	return Vector2(size.x * 0.5 + (k - (State.ROUNDS - 1) * 0.5) * gap, _l("shelf") - ss)

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.rounds.is_empty():
		return
	_used.clear()
	_draw_shelf()
	if not (_won or is_done() or _phase == Phase.DONE):
		_draw_ask()
		var e := _t - _pick_at
		if _phase == Phase.FOLD and not Motion.reduce and e >= HOLD:
			_draw_fold(e)
		else:
			_draw_net()
		for o in _st.struck.size():
			_draw_option(o)
		_draw_count()
	# the boxes this frame did not draw are let go; those it drew are kept
	# until a later frame no longer does
	for k in _boxes.keys():
		if not _used.has(k):
			_boxes.erase(k)

## The shelf's spots and the boxes already folded today; on the win they
## hop in a wave.
func _draw_shelf() -> void:
	var ss := _l("ss")
	var done: int = mini(_st.current, State.ROUNDS)
	var key := "%d:%d:%d:%d" % [done, roundi(ss * 10.0), roundi(_l("shelf")), roundi(size.x)]
	var ended := _phase == Phase.DONE or is_done()
	if key != _shelf_key:
		_shelf_key = key
		var b := Face.Builder.new()
		for k in State.ROUNDS:
			if k >= done or ended:
				if k >= done:
					Art.spot(b, _shelf_pos(k), ss)
				continue
			Art.box(b, _shelf_pos(k), ss, _answer(k), maxf(1.2, ss * 0.035))
		_shelf_mesh = b.mesh() if not b.verts.is_empty() else null
	if _shelf_mesh != null:
		draw_mesh(_shelf_mesh, null)
	if ended:
		# each box its own mesh, so the wave can hop them
		for k in done:
			var at := _shelf_pos(k)
			var wave := _t - _won_at - k * Motion.WAVE_STEP * 2.0
			if wave >= 0.0 and not Motion.reduce:
				at.y += Motion.hop_lift(fmod(wave, 1.4), Motion.SOLVE_HOP * 2.0 * _u(), Motion.SOLVE_TIME)
			draw_mesh(_box_mesh("shelf:%d" % k, _answer(k), ss, false), null, Transform2D(0.0, at))

func _answer(k: int) -> Array:
	var r: Dictionary = _st.rounds[k]
	return r.options[int(r.answer)]

func _draw_ask() -> void:
	if demo:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var text := tr("PB_ASK")
	var fs := roundi(ASK_SIZE * u)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(size.x * 0.5 - tw * 0.5, _l("ask_y"))
	var a := 1.0
	if _phase == Phase.FOLD:
		a = clampf(1.0 - (_t - _pick_at) / 0.3, 0.0, 1.0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(World.MAT_LINE.lerp(Color.WHITE, 0.6), a))

## The net at rest on the mat, sliding in when its round begins.
func _draw_net() -> void:
	var r: Dictionary = _st.now()
	var cell := _l("cell")
	var key := "%d:%d" % [_st.current, roundi(cell * 10.0)]
	if key != _net_key:
		_net_key = key
		var ext := Fold.extent(r.net)
		var half := Vector2(ext) * 0.5
		var proj := func(p: Vector3) -> Vector2: return (Vector2(p.x, p.y) - half) * cell
		var b := Face.Builder.new()
		# the net's shadow on the mat, a little down and right
		for p: Vector2i in r.net:
			var c := (Vector2(p) + Vector2(0.5, 0.5) - half) * cell + Vector2(5.0, 7.0) * _u()
			b.fan(Face.Builder.round_rect(c - Vector2.ONE * cell * 0.5, Vector2.ONE * cell, cell * 0.06), Color(0.15, 0.25, 0.18, 0.18))
		Art.sheet(b, Fold.frames(r.net, r.root, 0.0), r.colours, r.ways, proj, Vector3(0, 0, 1), _edge_w(cell))
		_net_mesh = b.mesh()
	var at := _mat_centre()
	var a := 1.0
	var k := clampf((_t - _round_at) / SLIDE_TIME, 0.0, 1.0)
	if k < 1.0 and not Motion.reduce:
		at.x += (1.0 - Motion.back_out(k)) * size.x * 0.7
		a = clampf(k * 3.0, 0.0, 1.0)
	draw_mesh(_net_mesh, null, Transform2D(0.0, at), Color(1, 1, 1, a))

func _edge_w(px: float) -> float:
	return maxf(1.2, px * 0.028)

## The right pick's play from `e` seconds after the pick: the net tilts
## toward the eye and folds, hinge by hinge, into its box, which turns to
## the corner that was picked and then flies to the shelf.
func _draw_fold(e: float) -> void:
	var r: Dictionary = _st.now()
	var cell := _l("cell")
	var turn: Basis = Fold.turns()[int(r.turn)]
	if e >= _turn_end() + SHOW:
		# flying: the box itself, from the mat to its shelf spot
		var k := clampf((e - _turn_end() - SHOW) / FLY, 0.0, 1.0)
		var s := k * k * (3.0 - 2.0 * k)
		var to := _shelf_pos(_st.current)
		var at := _mat_centre().lerp(to, s) + Vector2(0.0, -sin(s * PI) * 120.0 * _u())
		var shrink := lerpf(1.0, _l("ss") / cell, s)
		draw_mesh(_box_mesh("fly:%d" % _st.current, _answer(_st.current), cell, false), null, Transform2D(0.0, Vector2.ONE * shrink, 0.0, at))
		return
	var lift := clampf((e - HOLD) / LIFT, 0.0, 1.0)
	var tilt := lift * lift * (3.0 - 2.0 * lift)
	var t := tree_order(r)
	var angles := []
	angles.resize(r.net.size())
	var shut := true
	for i in r.net.size():
		angles[i] = 0.0
	for j in range(1, t.size()):
		var i: int = t[j]
		var k := clampf((e - HOLD - LIFT - (j - 1) * HINGE_STEP) / HINGE_TIME, 0.0, 1.0)
		angles[i] = Motion.back_out(k) * PI * 0.5 if k < 1.0 else PI * 0.5
		if k < 1.0:
			shut = false
	var spin := clampf((e - _fold_end()) / TURN, 0.0, 1.0)
	spin = spin * spin * (3.0 - 2.0 * spin)
	var q := Quaternion().slerp(Quaternion(turn), spin)
	var ext := Fold.extent(r.net)
	var flat_c := Vector3(ext.x * 0.5, ext.y * 0.5, 0.0)
	var anchor := flat_c.lerp(Fold.box_centre(r.net, r.root), tilt)
	var place := Transform3D(Basis(q), Vector3.ZERO) * Transform3D(Basis(), -anchor)
	var frames := []
	for f: Transform3D in Fold.frames(r.net, r.root, angles):
		frames.append(place * f)
	var origin := _mat_centre()
	var proj := func(p: Vector3) -> Vector2:
		return origin + Vector2(p.x, p.y).lerp(Fold.project(p), tilt) * cell
	var eye := Vector3(0, 0, 1).lerp(Vector3(1, 1, 1).normalized(), tilt).normalized()
	var b := Face.Builder.new()
	Art.shadow(b, origin + Vector2(0.0, cell * 0.1 * tilt), cell * lerpf(1.4, 0.9, tilt))
	var colours: Array = r.colours
	var ways: Array = r.ways
	if shut and spin > 0.0:
		# a shut box: its inside never shows, so only the faces toward the eye
		var keep := []
		var keep_c := []
		var keep_w := []
		for i in frames.size():
			if ((frames[i] as Transform3D).basis * Vector3(0, 0, 1)).dot(eye) > 0.0:
				keep.append(frames[i])
				keep_c.append(colours[i])
				keep_w.append(ways[i])
		frames = keep
		colours = keep_c
		ways = keep_w
	Art.sheet(b, frames, colours, ways, proj, eye, _edge_w(cell))
	_fold_mesh = b.mesh()
	draw_mesh(_fold_mesh, null)

## The net's squares in the order they fold (the root first).
func tree_order(r: Dictionary) -> Array[int]:
	return Fold.tree(r.net, r.root).order

## A box to pick from: dropping in with its round, hopping when picked
## right, shaking and struck when wrong.
func _draw_option(o: int) -> void:
	var bs := _l("bs")
	var u := _u()
	var at := _opt_pos(o)
	var a := 1.0
	var e := _t - _round_at - Motion.ENTER_DELAY - SLIDE_TIME * 0.5 - o * BOX_STAGGER
	if e < 0.0 and not Motion.reduce:
		return
	if e < Motion.DROP_TIME and not Motion.reduce:
		at.y -= Motion.drop_in_lift(e, Motion.DROP * 2.0 * u)
		a = Motion.appear_level(e)
	var struck: bool = _st.struck[o]
	var se := _t - _struck_at[o]
	if struck and se >= 0.0 and se < Motion.SHIVER_TIME * 1.6 and not Motion.reduce and not _hinted[o]:
		at.x += Motion.shiver_offset(se, Motion.SHIVER_PX * 3.0 * u, Motion.SHIVER_TIME * 1.6)
	if o == _picked:
		var pe := _t - _pick_at
		if pe >= 0.0 and pe < Motion.HOP_TIME * 1.4 and not Motion.reduce:
			at.y += Motion.hop_lift(pe, Motion.SOLVE_HOP * 1.6 * u, Motion.HOP_TIME * 1.4)
		# the picked box stays until its net is folded, then gives way
		var gone := clampf((pe - _fold_end()) / 0.3, 0.0, 1.0)
		a *= 1.0 - gone
		draw_mesh(_ring_mesh(bs), null, Transform2D(0.0, _opt_pos(o)), Color(1, 1, 1, a))
	elif _phase == Phase.FOLD:
		a = clampf(1.0 - (_t - _pick_at) / 0.3, 0.0, 1.0)
	if a <= 0.0:
		return
	var face_a := a * (STRUCK_ALPHA if struck else 1.0)
	draw_mesh(_shadow_mesh(bs), null, Transform2D(0.0, at), Color(1, 1, 1, face_a))
	draw_mesh(_box_mesh("opt:%d:%d" % [_st.current, o], _st.options()[o], bs, false), null, Transform2D(0.0, at), Color(1, 1, 1, face_a))
	if struck:
		var k := clampf(se / Motion.POP_IN, 0.0, 1.0) if not Motion.reduce else 1.0
		draw_mesh(_box_mesh("struck", [], bs, true), null, Transform2D(0.0, Vector2.ONE * lerpf(1.3, 1.0, k), 0.0, at), Color(1, 1, 1, a * k))

## A box drawn about its middle, cached by key and size; `cross` the pencil
## hatch and cross instead.
func _box_mesh(key: String, pic: Array, s: float, cross: bool) -> ArrayMesh:
	var k := "%s:%d" % [key, roundi(s * 10.0)]
	_used[k] = true
	if not _boxes.has(k):
		var b := Face.Builder.new()
		if cross:
			Art.struck(b, Vector2.ZERO, s)
		else:
			Art.box(b, Vector2.ZERO, s, pic, _edge_w(s))
		_boxes[k] = b.mesh()
	return _boxes[k]

func _shadow_mesh(s: float) -> ArrayMesh:
	var k := "shadow:%d" % roundi(s * 10.0)
	_used[k] = true
	if not _boxes.has(k):
		var b := Face.Builder.new()
		Art.shadow(b, Vector2.ZERO, s)
		_boxes[k] = b.mesh()
	return _boxes[k]

func _ring_mesh(s: float) -> ArrayMesh:
	var k := "ring:%d" % roundi(s * 10.0)
	_used[k] = true
	if not _boxes.has(k):
		var b := Face.Builder.new()
		b.stroke(Face.Builder.ring(Vector2(0.0, s * 0.05), s * 1.25, s * 1.25), maxf(3.0, s * 0.07), Pal.GOOD, true)
		_boxes[k] = b.mesh()
	return _boxes[k]

## Which box of five, and the wrong picks so far.
func _draw_count() -> void:
	if demo or is_done() or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var text: String = tr("PB_ROUND") % [mini(_st.current + 1, State.ROUNDS), State.ROUNDS]
	if _st.wrongs > 0:
		text += "  ·  " + (tr("PB_WRONG_ONE") if _st.wrongs == 1 else tr("PB_WRONG_N")) % _st.wrongs
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
	if _st.rounds.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "📦 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line: String
	if _st.wrongs == 0:
		line = tr("PB_WIN_CLEAN")
	else:
		line = (tr("PB_WIN_WRONG_ONE") if _st.wrongs == 1 else tr("PB_WIN_WRONG_N")) % _st.wrongs
	return {"faces": [], "subtitle": tr("PB_WIN") + " " + line}

func completion_record() -> Dictionary:
	return {"wrongs": Array(_st.wrong_in)}

## A finished day reopens with the five boxes on the shelf.
func restore_completed_board() -> void:
	_queue.clear()
	_st.finish(completed_record.get("wrongs", []) as Array)
	_phase = Phase.DONE
	_won_at = _t
	_relayout()
	queue_redraw()
