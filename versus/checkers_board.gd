extends Control

## The checkerboard, seen from straight above: the squares in a wooden
## frame, a tray above and one below for the pieces each side has taken, and
## the pieces lying on the lawn squares. It draws, it takes the player's
## touch, and it plays every move as a little scene -- but how a piece looks
## and how it moves is the skin's (versus/checkers_skin.gd), so none of that
## is written here. What is written here is everything round the pieces:
## where every piece is looking (at whatever just moved, at the piece you
## picked up, at your finger), the marks, the ripples and stars, the combo
## count on a chain of captures, the trays, the petals.
##
## The truth is the rules object (versus/checkers_rules.gd); the board
## mirrors it with one actor a piece, so a piece keeps its identity (its
## breathing, its glances, its blinks) as it moves. The screen makes a move
## on the rules and hands the board its description (play()); the board
## says `settled` when the scene has finished.
##
## Input: tap a piece of yours to pick it up (where it can go appears; a
## capture shows its whole route and what it takes), then tap where it
## lands; or drag it there. When two routes share a first landing the
## route is chosen a landing at a time.
##
## Draw calls: the board is one mesh, the marks one, the two live layers
## one each, and every piece a shadow, a base and a top (cached meshes,
## moved by transform, never rebuilt to move).

signal chosen(move: PackedInt32Array)
signal settled
## A tap the rules turned down: "must" (a capture is on elsewhere, and
## capturing is compulsory) or "stuck" (the piece has no move).
signal refused(reason: String)

const Rules = preload("res://versus/checkers_rules.gd")
const CheckersSkin = preload("res://versus/checkers_skin.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")

## In cells: the tray strip above and below (at least TRAY, growing to
## TRAY_MAX into a tall phone's spare height), the air between it and the
## frame, the wooden frame, and a taken piece's spacing and size at the
## smallest tray.
const TRAY := 0.66
const TRAY_MAX := 1.0
const TRAY_GAP := 0.12
const FRAME := 0.3
const TRAY_STEP := 0.62
const TRAY_SCALE := 0.62
const DRAG_START := 14.0
## How much a piece grows and rises up the screen a cell of lift.
const LIFT_GROW := 0.22
const LIFT_RISE := 0.28

## The live layers' timings, seconds.
const MARK_STEP := 0.035
const MARK_POP := 0.22
const RIPPLE_TIME := 0.42
const IMPACT_TIME := 0.32
const COMBO_TIME := 0.9
const Z_PERIOD := 3.4
const PETALS := 26
const PETAL_FALL := 2.6

const LIGHT := Color("f1e1c1")
const DARK := Color("a4c088")
const DARK_DEEP := Color("8fab74")
const FRAME_COL := Color("74492c")
const FRAME_DEEP := Color("4f311d")
const FRAME_LIP := Color("a97a4f")
const TROUGH := Color("8a5d3a")
const TROUGH_DEEP := Color("5e3d24")
const MARK_LAST := Color(1.0, 0.82, 0.36, 0.42)
const MARK_PICK := Color(1.0, 0.78, 0.3, 0.6)
const MARK_DOT := Color(0.23, 0.19, 0.16, 0.22)
const HINT := Color("f5a623")
const SOIL := Color("6f4c33")
const SOIL_DEEP := Color("553823")
const MOSS := Color("9cb97c")
const MOSS_DEEP := Color("7f9f62")
const BRASS := Color("d9a441")
const BRASS_DEEP := Color("a8772a")

## A leg of a move: a quiet step, a jump over what it takes, the zip back
## to its square when a capture was dropped somewhere else, a walk back
## under undo.
enum { LEG_STEP, LEG_JUMP, LEG_RETURN, LEG_BACK }

var rules: RefCounted
var skin: RefCounted = CheckersSkin.named("garden")
## The colour the player moves (Rules.LIGHT or DARK); their pieces are
## always the cream ones and always at the bottom.
var player := Rules.LIGHT
var interactive := false
var still := false

var cell := 100.0
var tray_h := TRAY
var tray_scale := TRAY_SCALE
## The top-left corner of the squares, in pixels.
var origin := Vector2.ZERO
## The whole board, trays included, in this control's pixels.
var used_rect := Rect2()

class Actor:
	var type := 0
	var side := 0
	var sq := -1
	var at := Vector2.ZERO
	var rest_scale := 1.0
	var phase := 0.0
	var blink_at := 0.0
	var kind := ""
	var t0 := 0.0
	var dur := 0.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var dir := Vector2.ZERO
	var move_type := 0
	## A move's legs: [from, to, start, seconds, LEG_*], start from t0.
	var legs: Array = []
	var fidget := 0
	var face := -1
	var face_until := 0.0
	## Where it glances when nothing is going on, until when.
	var glance := Vector2i.ZERO
	var glance_until := 0.0
	## Turned over for good (lost the game).
	var face_down := false
	## When a crown began to fall on it (the board's clock), -1 if none.
	var crown_at := -1.0
	## Taken by the move in play but not hit yet: it watches it come.
	var doomed := false

var _actors: Array = []
var _at_sq := {}
var _trays: Array = [[], []]
var _now := 0.0
var _events: Array = []
var _busy := false
var _fidget_at := 3.0
var _rng := RandomNumberGenerator.new()
var _fx: Node2D

var _selected := -1
var _sel_moves: Array = []
var _prefix := PackedInt32Array()
var _targets := {}
var _last := PackedInt32Array()
var _hint := PackedInt32Array()
var _must := PackedInt32Array()
var _lifted := -1
var _mood := ""

var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
var _drag_cell := Vector2.ZERO
var _hover := -1

var _board_mesh: ArrayMesh
var _marks_mesh: ArrayMesh
var _marks_prev: ArrayMesh
var _marks_dirty := true
var _shadow_mesh: ArrayMesh
var _meshes := {}
var _font: Font

var _under_mesh: ArrayMesh
var _over_mesh: ArrayMesh
var _live_prev: Array = []
var _select_at := 0.0
var _gone: Dictionary = {}
var _gone_from := -1
var _gone_at := -10.0
var _hint_at := 0.0
var _must_at := 0.0
var _ripples: Array = []
var _impacts: Array = []
## [pixel, count, when] for a chain's "x2", "x3".
var _combos: Array = []
var _thinking := false
var _think_at := 0.0
var _think_off := -10.0
var _petals: Array = []
var _petal_at := 0.0
## Where the piece everyone is watching is this frame, in cells.
var _focus := Vector2.INF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_font = get_theme_default_font()
	resized.connect(_layout)
	if not still:
		_fx = Fx2D.new()
		add_child(_fx)

# --- setting up ---

## A fresh set from the rules' position. `enter` deals the pieces in, and
## the board says `settled` once they are down.
func setup(the_rules: RefCounted, as_colour: int, enter := true) -> void:
	rules = the_rules
	player = as_colour
	_actors.clear()
	_at_sq.clear()
	_trays = [[], []]
	_events.clear()
	_selected = -1
	_sel_moves = []
	_prefix = PackedInt32Array()
	_targets = {}
	_last = PackedInt32Array()
	_hint = PackedInt32Array()
	_must = PackedInt32Array()
	_lifted = -1
	_mood = ""
	_gone = {}
	_ripples.clear()
	_impacts.clear()
	_combos.clear()
	_petals.clear()
	_thinking = false
	for sq in 64:
		var p: int = rules.board[sq]
		if p == 0:
			continue
		var a := Actor.new()
		a.type = absi(p)
		a.side = 0 if Rules.side_of(p) == player else 1
		a.sq = sq
		a.at = cell_of(sq)
		a.phase = _rng.randf()
		a.blink_at = _rng.randf_range(1.0, 6.0)
		a.glance_until = _rng.randf_range(0.5, 4.0)
		_actors.append(a)
		_at_sq[sq] = a
	_marks_dirty = true
	if enter and not still and not Motion.reduce:
		_busy = true
		for a: Actor in _actors:
			# dealt from the far side forward, a ripple across each row
			var row := a.at.y if a.side == 1 else 7.0 - a.at.y
			var delay := (row * 0.1 if a.side == 1 else 0.4 + row * 0.1) + a.at.x * 0.03
			_start(a, "enter", skin.enter_time(), a.at, a.at, delay)
		_after(0.1, func() -> void: _cue("enter"))
	queue_redraw()

## The computer is thinking: its pieces look round the board.
func set_thinking(on: bool) -> void:
	if on and not _thinking:
		_think_at = _now
	elif not on and _thinking:
		_think_off = _now
	_thinking = on

func set_hint(move: PackedInt32Array) -> void:
	_hint = move
	_hint_at = _now
	_marks_dirty = true
	if not move.is_empty() and _fx != null:
		var at := px(cell_of(move[0]))
		_fx.ring(at, cell * 0.5, HINT)
		_fx.sparkle(at, HINT)

## The pieces of yours that can capture, when capturing is compulsory:
## they wear a pulsing ring until you move.
func set_must(squares: PackedInt32Array) -> void:
	if squares != _must:
		_must_at = _now
	_must = squares

func set_lifted(sq: int) -> void:
	_lifted = sq

func deselect() -> void:
	if _selected >= 0 and not _targets.is_empty():
		# the marks pop back out rather than vanish
		_gone = _targets
		_gone_from = _selected
		_gone_at = _now
	_selected = -1
	_sel_moves = []
	_prefix = PackedInt32Array()
	_targets = {}
	_dragging = false
	_pressing = false
	_hover = -1
	_marks_dirty = true

func is_busy() -> bool:
	return _busy

# --- geometry ---

func cell_of(sq: int) -> Vector2:
	var f := sq & 7
	var r := sq >> 3
	return Vector2(f, 7 - r) if player == Rules.LIGHT else Vector2(7 - f, r)

func sq_of(c: Vector2i) -> int:
	if c.x < 0 or c.x > 7 or c.y < 0 or c.y > 7:
		return -1
	return (7 - c.y) * 8 + c.x if player == Rules.LIGHT else c.y * 8 + (7 - c.x)

## A square's centre, in pixels, for a display cell (fractional allowed).
func px(c: Vector2) -> Vector2:
	return origin + (c + Vector2(0.5, 0.5)) * cell

func cell_at(p: Vector2) -> Vector2:
	return (p - origin) / cell - Vector2(0.5, 0.5)

func sq_at(p: Vector2) -> int:
	var c := (p - origin) / cell
	return sq_of(Vector2i(floori(c.x), floori(c.y)))

## Where a taken piece lies in its tray: tray 0 below the board (what the
## player took), 1 above (what the computer took).
func tray_cell(tray: int, slot: int) -> Vector2:
	var at := Vector2(origin.x + (0.42 + slot * TRAY_STEP) * cell, _tray_mid(tray))
	return cell_at(at)

func _tray_mid(tray: int) -> float:
	if tray == 0:
		return origin.y + (8.0 + FRAME + TRAY_GAP + tray_h * 0.5) * cell
	return origin.y - (FRAME + TRAY_GAP + tray_h * 0.5) * cell

func frame_rect() -> Rect2:
	return Rect2(origin - Vector2.ONE * FRAME * cell, Vector2.ONE * (8.0 + 2.0 * FRAME) * cell)

func _layout() -> void:
	var across := 8.0 + 2.0 * FRAME
	var c := floorf(minf(size.x / across, size.y / (across + 2.0 * (TRAY + TRAY_GAP))))
	if c <= 0.0:
		return
	if c != cell:
		_meshes.clear()
	cell = c
	tray_h = clampf((size.y / cell - across) * 0.5 - TRAY_GAP, TRAY, TRAY_MAX)
	var k := (tray_h - TRAY) / (TRAY_MAX - TRAY)
	tray_scale = lerpf(TRAY_SCALE, 0.75, k)
	var down := across + 2.0 * (tray_h + TRAY_GAP)
	var used := Vector2(across, down) * cell
	var corner := ((size - used) * 0.5).floor()
	used_rect = Rect2(corner, used)
	origin = corner + Vector2(FRAME, FRAME + TRAY_GAP + tray_h) * cell
	for a: Actor in _actors:
		if a.sq >= 0:
			a.at = cell_of(a.sq)
	for t in 2:
		for i in _trays[t].size():
			_trays[t][i].at = tray_cell(t, i)
			_trays[t][i].rest_scale = tray_scale
	_board_mesh = null
	_shadow_mesh = null
	_marks_dirty = true
	queue_redraw()

# --- the clock ---

func _process(delta: float) -> void:
	if still:
		return
	_now += minf(delta, 0.05)
	while not _events.is_empty() and _events[0][0] <= _now:
		var e: Array = _events.pop_front()
		(e[1] as Callable).call()
	for a: Actor in _actors:
		if a.kind != "" and _now >= a.t0 + a.dur:
			_finish(a)
	_fidget()
	if _busy and _events.is_empty():
		var moving := false
		for a: Actor in _actors:
			if a.kind in ["move", "knock", "crown", "enter", "back"]:
				moving = true
				break
		if not moving:
			_busy = false
			settled.emit()
	queue_redraw()

func _after(seconds: float, fn: Callable) -> void:
	_events.append([_now + seconds, fn])
	_events.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])

func _start(a: Actor, kind: String, dur: float, from: Vector2, to: Vector2, delay := 0.0) -> void:
	a.kind = kind
	a.t0 = _now + delay
	a.dur = maxf(dur, 0.01)
	a.from = from
	a.to = to

func _finish(a: Actor) -> void:
	var kind := a.kind
	a.kind = ""
	match kind:
		"move", "knock", "back":
			a.at = a.to
		"yield":
			a.face_down = true
		"crown":
			a.crown_at = -1.0
	if kind == "knock":
		a.face = CheckersSkin.F_SLEEP
		a.face_until = INF

func _cue(name: String, pitch := 1.0) -> void:
	if _fx != null:
		_fx.cue(name, pitch)

func _puff(c: Vector2, colour := Color("e9dcc3"), n := 5) -> void:
	if _fx != null:
		_fx.puff(px(c) + Vector2(0.0, cell * 0.2), colour, n)

# --- playing a move ---

## Plays a move the rules have just made: `d` is rules.describe() taken
## before it. The board says `settled` when everything has landed.
func play(d: Dictionary) -> void:
	var a: Actor = _at_sq.get(int(d.from))
	if a == null:
		return
	_busy = true
	var reduce := Motion.reduce
	var capture: bool = not (d.caps as Array).is_empty()
	var dragged := _dragging
	var drag_at := _drag_cell
	deselect()
	_lifted = -1
	_hint = PackedInt32Array()
	_must = PackedInt32Array()
	var type := absi(int(d.piece))
	var path: Array = d.path
	var points: Array = [cell_of(int(d.from))]
	for sq: int in path:
		points.append(cell_of(sq))
	var legs: Array = []
	var t := 0.0
	var dropped_quiet := dragged and not capture
	if dragged and capture:
		# dropped at the end of a capture: back to its square, then the jumps
		legs.append([drag_at, points[0], 0.0, 0.18, LEG_RETURN])
		t = 0.18
	for i in path.size():
		var f: Vector2 = drag_at if dropped_quiet else points[i]
		var to: Vector2 = points[i + 1]
		var dur: float
		if reduce:
			dur = 0.2
		elif dropped_quiet:
			dur = 0.2
		elif capture:
			dur = skin.jump_time(type, f, to, i)
		else:
			dur = skin.step_time(type, f, to)
		legs.append([f, to, t, dur, LEG_JUMP if capture else LEG_STEP])
		t += dur
	_at_sq.erase(int(d.from))
	a.sq = int(d.to)
	a.move_type = type
	a.legs = legs
	a.kind = ""
	_start(a, "move", t, legs[0][0], points[points.size() - 1])
	_at_sq[a.sq] = a
	# each leg: take off, and land
	var first := 1 if dragged and capture else 0
	for i in range(first, legs.size()):
		var leg: Array = legs[i]
		var n := i - first
		var pitch := 1.0 + 0.09 * n
		if not reduce and not dropped_quiet:
			_after(float(leg[2]), func() -> void: _cue(skin.takeoff_cue(type, capture), pitch))
		_after(float(leg[2]) + float(leg[3]), func() -> void:
			_cue(skin.land_cue(type, capture), pitch * _rng.randf_range(0.96, 1.04))
			if skin.lands_with_dust(type, capture) and not reduce:
				_puff(leg[1])
			elif not reduce:
				_puff(leg[1], Color("efe4cc"), 3)
			_ripple(leg[1], 1.0 if capture else 0.7))
	# what it takes, each at the moment the piece is over it
	var caps: Array = d.caps
	for i in caps.size():
		var victim: Actor = _at_sq.get(int(caps[i]))
		if victim == null:
			continue
		_at_sq.erase(int(caps[i]))
		var leg: Array = legs[i + first]
		var lf: Vector2 = leg[0]
		var lt: Vector2 = leg[1]
		var frac := lf.distance_to(victim.at) / maxf(lf.distance_to(lt), 0.01)
		var contact: float = float(leg[2]) + float(leg[3]) * (1.0 if reduce else skin.jump_contact(frac))
		_knock(victim, lt - lf, contact, i)
	if bool(d.crown):
		var ct: float = skin.crown_time()
		_after(t, func() -> void:
			# the move may not have been wound up yet this frame
			a.at = a.to
			_start(a, "crown", 0.2 if reduce else ct, a.to, a.to)
			a.crown_at = _now
			a.face = CheckersSkin.F_JOY
			a.face_until = _now + ct + 0.6
			_cue("lift", 1.4))
		_after(t + (0.1 if reduce else ct * skin.crown_land()), func() -> void:
			a.type = Rules.KING
			_cue("crown")
			if _fx != null:
				_fx.sparkle(px(a.to), Pal.SUN)
				_fx.ring(px(a.to), cell * 0.55, Pal.SUN))
	_last = PackedInt32Array([int(d.from)])
	for sq: int in path:
		_last.append(sq)
	_marks_dirty = true

## Knocks `victim` off the board into its tray, `contact` seconds from now,
## pushed the way it was jumped; `n` is its place in a chain.
func _knock(victim: Actor, dir: Vector2, contact: float, n: int) -> void:
	var tray := 0 if victim.side == 1 else 1
	var slot: int = _trays[tray].size()
	_trays[tray].append(victim)
	victim.sq = -1
	var target := tray_cell(tray, slot)
	victim.doomed = true
	victim.face = CheckersSkin.F_WORRY
	victim.face_until = INF
	_after(contact, func() -> void:
		victim.doomed = false
		_start(victim, "knock", 0.25 if Motion.reduce else skin.knock_time(), victim.at, target)
		victim.dir = dir
		victim.rest_scale = tray_scale
		victim.face = CheckersSkin.F_DIZZY
		victim.face_until = INF
		_cue("capture", 1.0 + 0.1 * n)
		if _fx != null:
			var hit := px(victim.at)
			_fx.ring(hit, cell * 0.35, Color(Pal.PAPER, 0.9), 0.35)
			_fx.puff(hit, Pal.SUN_RAY, 6)
		if not Motion.reduce:
			_impacts.append([px(victim.at), _now])
			if n >= 1:
				_combos.append([px(victim.at) - Vector2(0.0, cell * 0.7), n + 1, _now]))

## Takes a move back (undo): the piece walks home along its route, what it
## took comes back out of the tray, and a crowned man is a man again.
func rewind(d: Dictionary) -> void:
	var a: Actor = _at_sq.get(int(d.to))
	if a == null:
		return
	_busy = true
	var reduce := Motion.reduce
	_at_sq.erase(int(d.to))
	if bool(d.crown):
		a.type = Rules.MAN
	var route: Array = [cell_of(int(d.from))]
	for sq: int in d.path:
		route.append(cell_of(sq))
	route.reverse()
	var legs: Array = []
	var t := 0.0
	for i in route.size() - 1:
		var dur := 0.2 if reduce else 0.3
		legs.append([route[i], route[i + 1], t, dur, LEG_BACK])
		t += dur
	a.sq = int(d.from)
	a.legs = legs
	_start(a, "move", t, route[0], route[route.size() - 1])
	_at_sq[a.sq] = a
	var caps: Array = d.caps
	for i in range(caps.size() - 1, -1, -1):
		var tray := 0 if Rules.side_of(int(d.capvals[i])) != player else 1
		var victim: Actor = _trays[tray].pop_back() if not _trays[tray].is_empty() else null
		if victim == null:
			continue
		victim.sq = int(caps[i])
		victim.rest_scale = 1.0
		victim.face = CheckersSkin.F_JOY
		victim.face_until = _now + 1.2
		_start(victim, "back", 0.25 if reduce else 0.45, victim.at, cell_of(victim.sq), 0.0 if reduce else 0.08 * (caps.size() - 1 - i))
		_at_sq[victim.sq] = victim
	_cue("slide")
	_last = PackedInt32Array()
	deselect()

## The end of the game: the winners hop in a wave out from the last move and
## the losers turn face down one by one; a draw puts everyone to sleep.
func finish(outcome: String) -> void:
	_mood = outcome
	deselect()
	_lifted = -1
	_must = PackedInt32Array()
	if Motion.reduce or outcome == "draw":
		return
	if outcome == "won":
		_petal_at = _now
		var prng := RandomNumberGenerator.new()
		prng.seed = 4711
		for i in PETALS:
			_petals.append([prng.randf_range(-0.3, 8.3), 0.6 + prng.randf_range(0.0, 1.6),
				prng.randf_range(4.5, 8.4), prng.randf() * TAU, prng.randf_range(0.8, 1.2), i % 3])
	var winners := 0 if outcome == "won" else 1
	var centre := cell_of(_last[_last.size() - 1]) if not _last.is_empty() else Vector2(3.5, 3.5)
	var losers: Array = []
	for a: Actor in _actors:
		if a.sq < 0:
			continue
		if a.side == winners:
			var delay := 0.4 + a.at.distance_to(centre) * 0.07
			for k in 2:
				_after(delay + k * 0.7, func() -> void:
					if a.kind == "":
						_start(a, "cheer", skin.cheer_time(), a.at, a.at))
		else:
			losers.append(a)
	losers.sort_custom(func(x: Actor, y: Actor) -> bool: return x.at.x + x.at.y * 0.5 < y.at.x + y.at.y * 0.5)
	for i in losers.size():
		var a: Actor = losers[i]
		_after(0.5 + i * 0.16, func() -> void:
			if a.kind == "" and not a.face_down:
				_start(a, "yield", skin.yield_time(), a.at, a.at)
				_cue("flip", 0.9 + 0.05 * i))

## Now and then one resting piece does its own little thing, while the
## game waits on someone.
func _fidget() -> void:
	var gap: Vector2 = skin.fidget_gap()
	if gap == Vector2.ZERO or _now < _fidget_at or Motion.reduce:
		return
	_fidget_at = _now + _rng.randf_range(gap.x, gap.y)
	if _busy or _mood != "" or _dragging:
		return
	var idle: Array = []
	for a: Actor in _actors:
		if a.sq >= 0 and a.kind == "" and a.sq != _selected and a.sq != _lifted and not _must.has(a.sq):
			idle.append(a)
	if idle.is_empty():
		return
	var a: Actor = idle[_rng.randi() % idle.size()]
	a.fidget = _rng.randi() % int(skin.fidget_kinds())
	_start(a, "fidget", skin.fidget_time(a.type, a.fidget), a.at, a.at)

func _shiver(a: Actor) -> void:
	_start(a, "shiver", skin.shiver_time(), a.at, a.at)
	a.face = CheckersSkin.F_WORRY
	a.face_until = _now + 0.6

## The pieces that must capture lean toward what they would take.
func nudge_must() -> void:
	if Motion.reduce:
		return
	var moves: Array = rules.legal_moves()
	var done := {}
	for m: PackedInt32Array in moves:
		if Rules.mv_ncaps(m) == 0 or done.has(m[0]):
			continue
		done[m[0]] = true
		var a: Actor = _at_sq.get(m[0])
		if a == null or a.kind != "":
			continue
		a.dir = cell_of(m[2]) - a.at
		_start(a, "nudge", skin.nudge_time(), a.at, a.at, 0.1)
		a.face = CheckersSkin.F_BRAVE
		a.face_until = _now + 0.8

# --- touch ---

func _gui_input(event: InputEvent) -> void:
	if still or not interactive or _busy:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	if press:
		_on_press(at)
	elif release:
		_on_release(at)
	else:
		_on_drag(at)

func _on_press(p: Vector2) -> void:
	var sq := sq_at(p)
	if _selected >= 0 and _targets.has(sq):
		_choose(sq)
		return
	var a: Actor = _at_sq.get(sq)
	if a != null and a.side == 0:
		if sq == _selected:
			if _prefix.is_empty():
				_pressing = true
				_press_at = p
			return
		_select(sq)
		if _selected >= 0:
			_pressing = true
			_press_at = p
		return
	if _selected >= 0:
		_cue("lift", 0.8)
	deselect()

func _on_drag(p: Vector2) -> void:
	if not _pressing or _selected < 0:
		return
	if not _dragging and p.distance_to(_press_at) > DRAG_START:
		_dragging = true
	if _dragging:
		_drag_cell = cell_at(p - Vector2(0.0, cell * 0.25))
		var over := sq_at(p)
		var h := over if _targets.has(over) else -1
		if h != _hover:
			_hover = h
			_marks_dirty = true

func _on_release(p: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if not _dragging:
		return
	var over := sq_at(p)
	if _targets.has(over):
		_choose(over)
		if _dragging:
			# the route goes on: the piece settles back while it is chosen
			_drop_back()
		return
	_drop_back()

## Dropped nowhere it can go: back to its square.
func _drop_back() -> void:
	var a: Actor = _at_sq.get(_selected)
	_dragging = false
	_hover = -1
	if a != null:
		a.legs = [[_drag_cell, a.at, 0.0, 0.22, LEG_RETURN]]
		_start(a, "move", 0.22, _drag_cell, a.at)
	_marks_dirty = true

func _select(sq: int) -> void:
	var moves: Array = rules.moves_from(sq)
	var a: Actor = _at_sq[sq]
	if moves.is_empty():
		deselect()
		_shiver(a)
		_cue("refused")
		if rules.must_capture():
			nudge_must()
			refused.emit("must")
		else:
			refused.emit("stuck")
		return
	if a.kind == "fidget" or a.kind == "nudge":
		a.kind = ""
	_selected = sq
	_select_at = _now
	_sel_moves = moves
	_prefix = PackedInt32Array()
	_gone = {}
	_retarget()
	_cue("lift")

## Where the picked piece can land next, given the landings chosen so far.
func _retarget() -> void:
	_targets = {}
	for m: PackedInt32Array in _routes():
		var path := Rules.mv_path(m)
		_targets[path[_prefix.size()]] = true
		_targets[Rules.mv_to(m)] = true
	_marks_dirty = true

## The picked piece's moves that follow the landings chosen so far.
func _routes() -> Array:
	var out: Array = []
	for m: PackedInt32Array in _sel_moves:
		var path := Rules.mv_path(m)
		if path.size() <= _prefix.size():
			continue
		var ok := true
		for i in _prefix.size():
			if path[i] != _prefix[i]:
				ok = false
				break
		if ok:
			out.append(m)
	return out

func _choose(to: int) -> void:
	var routes := _routes()
	var next: Array = routes.filter(func(m: PackedInt32Array) -> bool: return Rules.mv_path(m)[_prefix.size()] == to)
	var ending: Array = routes.filter(func(m: PackedInt32Array) -> bool: return Rules.mv_to(m) == to)
	if ending.size() == 1:
		chosen.emit(ending[0])
		return
	if next.size() == 1:
		chosen.emit(next[0])
		return
	if not next.is_empty():
		# routes part after this landing: choose the rest a landing at a time
		_prefix.append(to)
		_retarget()
		_cue("lift", 1.1 + 0.08 * _prefix.size())
		return
	if not ending.is_empty():
		chosen.emit(ending[0])

# --- drawing ---

func _draw() -> void:
	if _board_mesh == null:
		_board_mesh = _build_board()
	draw_mesh(_board_mesh, null)
	_draw_coords()
	if _marks_dirty:
		_marks_prev = _marks_mesh
		_marks_mesh = _build_marks()
		_marks_dirty = false
	if _marks_mesh != null:
		draw_mesh(_marks_mesh, null)
	# Everything lying on the board, in the order it lies: far to near, and
	# whatever is in the air over the rest.
	var poses: Array = []
	_focus = Vector2.INF
	for a: Actor in _actors:
		var pose: RefCounted = _pose_of(a)
		var key: float = pose.at.y + (20.0 if pose.lift > 0.15 or a.kind == "knock" or (a.sq == _selected and _dragging) else 0.0)
		poses.append([key, a, pose])
		if a.kind == "move" and _now >= a.t0:
			_focus = pose.at
	poses.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	_live_prev = [_under_mesh, _over_mesh]
	_under_mesh = null if still else _build_under()
	_over_mesh = null if still else _build_over(poses)
	if _under_mesh != null:
		draw_mesh(_under_mesh, null)
	if _shadow_mesh == null:
		var sb := Face.Builder.new()
		var ss: Vector2 = skin.shadow_size()
		Scenery.soft_disc(sb, Vector2(cell * 0.06, cell * 0.1), cell * ss.x * 1.08, cell * ss.y * 1.08, Color(Pal.TEXT, 0.18))
		Scenery.soft_disc(sb, Vector2(cell * 0.02, cell * 0.07), cell * ss.x * 0.92, cell * ss.y * 0.9, Color(Pal.TEXT, 0.26))
		_shadow_mesh = sb.mesh()
	for e: Array in poses:
		var pose = e[2]
		var up := clampf(pose.lift, 0.0, 3.0)
		var k: float = pose.scale * (1.0 - up * 0.18)
		draw_mesh(_shadow_mesh, null, Transform2D(0.0, Vector2(k, k) * pose.squash, 0.0, px(pose.at) + Vector2(up * 0.2, up * 0.12) * cell),
			Color(1, 1, 1, pose.alpha * (1.0 - up * 0.25)))
	for e: Array in poses:
		var a: Actor = e[1]
		var pose = e[2]
		var up := clampf(pose.lift, 0.0, 3.0)
		var fl := cos(pose.flip)
		var under := fl < 0.0
		var sc: Vector2 = pose.squash * pose.scale * (1.0 + LIFT_GROW * up) * Vector2(1.0, maxf(absf(fl), 0.06))
		var at := px(pose.at) - Vector2(0.0, up * cell * LIFT_RISE)
		var tint := Color(1, 1, 1, pose.alpha)
		draw_mesh(_base_mesh(a.type, a.side), null, Transform2D(0.0, sc, 0.0, at), tint)
		var top := _under(a.type, a.side) if under else _mesh(a.type, a.side, _face_of(a), _gaze_of(a, pose))
		draw_mesh(top, null, Transform2D(pose.spin, sc, 0.0, at), tint)
		if a.kind == "crown" and a.crown_at >= 0.0:
			_draw_falling_crown(a, pose, at, sc)
	if _over_mesh != null:
		draw_mesh(_over_mesh, null)
	_draw_combos()
	_draw_advantage()

## The crown dropping out of the sky onto a man being crowned, with its own
## shadow on the man, until it lands and he is a king.
func _draw_falling_crown(a: Actor, pose, at: Vector2, sc: Vector2) -> void:
	var u := clampf((_now - a.crown_at) / maxf(a.dur, 0.01), 0.0, 1.0)
	if u >= skin.crown_land() or a.type == Rules.KING:
		return
	var key := "crown|%d" % a.side
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build_crown(b, a.side, cell)
		m = b.mesh()
		_meshes[key] = m
	var cp: RefCounted = skin.crown_pose(u)
	var seat: Vector2 = skin.crown_seat(cell) * sc
	var up := clampf(cp.lift, 0.0, 4.0)
	draw_mesh(_shadow_mesh, null, Transform2D(0.0, Vector2(0.45, 0.3) * (1.0 - up * 0.15), 0.0, at + seat + Vector2(up * 0.1, 0.1) * cell),
		Color(1, 1, 1, 0.8 - up * 0.15))
	var grow := 1.0 + 0.25 * up
	draw_mesh(m, null, Transform2D(cp.spin, Vector2.ONE * grow, 0.0, at + seat - Vector2(0.0, up * cell * 0.45)))

func _base_mesh(type: int, side: int) -> ArrayMesh:
	var key := "base|%d|%d" % [type, side]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build_base(b, type, side, cell)
		m = b.mesh()
		_meshes[key] = m
	return m

func _under(type: int, side: int) -> ArrayMesh:
	var key := "under|%d|%d" % [type, side]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build_under(b, type, side, cell)
		m = b.mesh()
		_meshes[key] = m
	return m

func _mesh(type: int, side: int, face: int, gaze: Vector2i) -> ArrayMesh:
	var key := "%d|%d|%d|%d|%d" % [type, side, face, gaze.x, gaze.y]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build(b, type, side, cell, face, gaze)
		m = b.mesh()
		_meshes[key] = m
	return m

## How an actor lies this frame: its moment if it has one, else at rest.
func _pose_of(a: Actor) -> RefCounted:
	if still:
		return skin.idle_pose(a.type, a.at, 0.0, a.phase, false)
	if a.kind != "":
		var u := clampf((_now - a.t0) / a.dur, 0.0, 1.0)
		if _now < a.t0:
			if a.kind == "enter":
				var hidden: RefCounted = skin.enter_pose(a.at, 0.0)
				hidden.alpha = 0.0
				return hidden
			u = 0.0
		match a.kind:
			"move":
				return _move_pose(a)
			"back":
				var p: RefCounted = CheckersSkin.Pose.at_cell(a.from.lerp(a.to, CheckersSkin._ease_in_out(u)))
				p.lift = 0.6 * sin(PI * u)
				p.scale = lerpf(tray_scale, 1.0, u)
				return p
			"knock":
				if Motion.reduce:
					var p: RefCounted = CheckersSkin.Pose.at_cell(a.from.lerp(a.to, u))
					p.scale = lerpf(1.0, tray_scale, u)
					return p
				return skin.knock_pose(a.from, a.to, a.dir, u, tray_scale)
			"shiver":
				var p: RefCounted = skin.shiver_pose(a.at, u)
				p.scale = a.rest_scale
				return p
			"nudge":
				return skin.nudge_pose(a.at, a.dir, u)
			"cheer":
				return skin.cheer_pose(a.at, u)
			"yield":
				return skin.yield_pose(a.at, u)
			"fidget":
				return skin.fidget_pose(a.type, a.at, u, a.fidget)
			"crown":
				return skin.crowned_pose(a.at, u)
			"enter":
				return skin.enter_pose(a.at, u)
	if a.sq < 0:
		var p := CheckersSkin.Pose.at_cell(a.at)
		p.scale = a.rest_scale
		return p
	if a.face_down:
		var p := CheckersSkin.Pose.at_cell(a.at)
		p.flip = PI
		return p
	var lifted := a.sq == _selected or a.sq == _lifted
	if lifted and _dragging and a.sq == _selected:
		var p := CheckersSkin.Pose.at_cell(_drag_cell)
		p.lift = 0.4
		return p
	if Motion.reduce:
		var still_pose := CheckersSkin.Pose.at_cell(a.at)
		still_pose.lift = 0.15 if lifted else 0.0
		return still_pose
	var ip: RefCounted = skin.idle_pose(a.type, a.at, _now, a.phase, lifted)
	if a.sq == _lifted:
		# the computer's "hmm" before it lets go
		ip.spin += 0.1 * sin(_now * 12.0)
	return ip

func _move_pose(a: Actor) -> RefCounted:
	var t := _now - a.t0
	var n := a.legs.size()
	for i in n:
		var leg: Array = a.legs[i]
		if t <= float(leg[2]) + float(leg[3]) or i == n - 1:
			var u := clampf((t - float(leg[2])) / float(leg[3]), 0.0, 1.0)
			var f: Vector2 = leg[0]
			var to: Vector2 = leg[1]
			var kind: int = leg[4]
			if Motion.reduce:
				return CheckersSkin.Pose.at_cell(f.lerp(to, u))
			match kind:
				LEG_JUMP:
					var first := 1 if int(a.legs[0][4]) == LEG_RETURN else 0
					return skin.jump_pose(a.move_type, f, to, u, i - first, n - first)
				LEG_STEP:
					if n == 1 and f.distance_to(to) < 1.0:
						# dropped by hand: it settles
						var p: RefCounted = CheckersSkin.Pose.at_cell(f.lerp(to, CheckersSkin._ease_in_out(u)))
						p.lift = 0.3 * (1.0 - u)
						p.squash = Vector2(1.0 + 0.12 * sin(PI * u), 1.0 - 0.12 * sin(PI * u))
						return p
					return skin.step_pose(a.move_type, f, to, u)
				_:
					var p: RefCounted = CheckersSkin.Pose.at_cell(f.lerp(to, CheckersSkin._ease_in_out(u)))
					p.lift = (0.4 * (1.0 - u)) if kind == LEG_RETURN else 0.25 * sin(PI * u)
					return p
	return CheckersSkin.Pose.at_cell(a.to)

## Where a piece's eyes point, each axis -1, 0 or 1: at whatever just
## moved, at your finger, at the piece you picked up, at the thing it is
## about to take; else now and then a glance of its own.
func _gaze_of(a: Actor, pose) -> Vector2i:
	if still:
		return Vector2i.ZERO
	if pose.gaze != Vector2.ZERO:
		return _quant(pose.gaze)
	if (a.sq < 0 and not a.doomed) or a.face_down or Motion.reduce:
		return Vector2i.ZERO
	var target := Vector2.INF
	if _focus != Vector2.INF and a.kind != "move":
		target = _focus
	elif _dragging and a.sq != _selected:
		target = _drag_cell
	elif _selected >= 0 and a.sq != _selected:
		target = cell_of(_selected)
	elif _thinking and a.side == 1:
		target = Vector2(3.5 + 3.8 * sin(_now * 0.8 + 1.0), 3.5 + 2.5 * sin(_now * 0.53))
	if target != Vector2.INF:
		var d: Vector2 = target - pose.at
		if d.length() > 0.4:
			return _quant(d)
		return Vector2i.ZERO
	if _now >= a.glance_until:
		a.glance_until = _now + _rng.randf_range(1.5, 5.0)
		a.glance = Vector2i.ZERO if _rng.randf() < 0.45 else _quant(Vector2.from_angle(_rng.randf() * TAU))
	return a.glance

static func _quant(d: Vector2) -> Vector2i:
	var k := int(roundf(d.angle() / (PI * 0.25)))
	var v := Vector2.from_angle(k * PI * 0.25)
	return Vector2i(roundi(v.x), roundi(v.y))

func _face_of(a: Actor) -> int:
	if still:
		return CheckersSkin.F_OPEN
	if a.face >= 0 and _now < a.face_until:
		return a.face
	if a.sq < 0:
		return CheckersSkin.F_SLEEP
	match _mood:
		"won":
			return CheckersSkin.F_JOY if a.side == 0 else CheckersSkin.F_WORRY
		"lost":
			return CheckersSkin.F_JOY if a.side == 1 else CheckersSkin.F_WORRY
		"draw":
			return CheckersSkin.F_SLEEP
	if a.kind == "move" and not a.legs.is_empty() and int(a.legs[a.legs.size() - 1][4]) == LEG_JUMP:
		return CheckersSkin.F_BRAVE
	if a.sq == _selected or a.sq == _lifted:
		return CheckersSkin.F_JOY
	if _selected >= 0 and a.side == 1 and _threatened(a.sq):
		return CheckersSkin.F_WORRY
	if _must.has(a.sq):
		return CheckersSkin.F_BRAVE
	if _now >= a.blink_at and not Motion.reduce:
		if _now < a.blink_at + skin.blink_time():
			return CheckersSkin.F_BLINK
		var gap: Vector2 = skin.blink_gap()
		a.blink_at = _now + _rng.randf_range(gap.x, gap.y)
	return CheckersSkin.F_OPEN

## Whether the picked piece's routes take the piece on `sq`.
func _threatened(sq: int) -> bool:
	for m: PackedInt32Array in _routes():
		if Rules.mv_caps(m).has(sq):
			return true
	return false

func _build_board() -> ArrayMesh:
	var b := Face.Builder.new()
	var fr := frame_rect()
	var r := cell * 0.22
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# the trays: a wooden planter above and below, a bed of moss in it and a
	# tuft of grass at each end, where the taken pieces lie asleep
	for t in 2:
		var mid := _tray_mid(t)
		var tr := Rect2(Vector2(fr.position.x + 0.06 * cell, mid - tray_h * 0.5 * cell), Vector2(fr.size.x - 0.12 * cell, tray_h * cell))
		Scenery.soft_disc(b, tr.get_center() + Vector2(0, cell * 0.12), tr.size.x * 0.55, tr.size.y * 0.75, Color(0.2, 0.1, 0.04, 0.16))
		b.fan(Face.Builder.round_rect(tr.position + Vector2(0, 6), tr.size, r), TROUGH_DEEP)
		b.fan(Face.Builder.round_rect(tr.position, tr.size, r), TROUGH)
		b.stroke(PackedVector2Array([tr.position + Vector2(r, 3), tr.position + Vector2(tr.size.x - r, 3)]), 3.0, Color(1, 1, 1, 0.22))
		for g in 2:
			var gy := tr.position.y + (0.06 + 0.84 * g) * tr.size.y
			var pts := PackedVector2Array()
			var x := tr.position.x + r
			var ph := rng.randf() * TAU
			while x < tr.end.x - r:
				pts.append(Vector2(x, gy + sin(x / 60.0 + ph) * 1.5))
				x += 16.0
			b.stroke(pts, 1.5, Color(TROUGH_DEEP, 0.35))
		var soil := tr.grow(-cell * 0.1)
		b.fan(Face.Builder.round_rect(soil.position, soil.size, r * 0.7), SOIL)
		b.fan(Face.Builder.round_rect(soil.position + Vector2(0, cell * 0.05), soil.size - Vector2(0, cell * 0.05), r * 0.7), MOSS_DEEP)
		b.fan(Face.Builder.round_rect(soil.position + Vector2(cell * 0.03, cell * 0.07), soil.size - Vector2(cell * 0.06, cell * 0.12), r * 0.6), MOSS)
		for k in 30:
			var q := Vector2(rng.randf_range(soil.position.x + r, soil.end.x - r), rng.randf_range(soil.position.y + cell * 0.12, soil.end.y - cell * 0.08))
			b.disc(q, cell * rng.randf_range(0.02, 0.045), Color(MOSS_DEEP, 0.55) if k % 3 else Color(1, 1, 1, 0.16))
		for end: float in [soil.position.x + cell * 0.2, soil.end.x - cell * 0.2]:
			Scenery.tuft(b, Vector2(end, soil.end.y - cell * 0.04), cell * 0.26)
	# the frame: a soft drop shadow, the deep edge, the face, the lip
	Scenery.soft_disc(b, fr.get_center() + Vector2(0, cell * 0.2), fr.size.x * 0.62, fr.size.y * 0.6, Color(0.2, 0.1, 0.04, 0.18))
	b.fan(Face.Builder.round_rect(fr.position + Vector2(0, 8), fr.size, r), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(fr.position, fr.size, r), FRAME_COL)
	var band := FRAME * cell
	for side in 4:
		for g in 2:
			var off := band * (0.3 + 0.35 * g)
			var pts := PackedVector2Array()
			var ph := rng.randf() * TAU
			var n := 40
			for k in n + 1:
				var f := float(k) / n
				var wob := sin(f * 11.0 + ph) * 1.6
				match side:
					0: pts.append(Vector2(lerpf(fr.position.x + r, fr.end.x - r, f), fr.position.y + off + wob))
					1: pts.append(Vector2(lerpf(fr.position.x + r, fr.end.x - r, f), fr.end.y - off + wob))
					2: pts.append(Vector2(fr.position.x + off + wob, lerpf(fr.position.y + r, fr.end.y - r, f)))
					3: pts.append(Vector2(fr.end.x - off + wob, lerpf(fr.position.y + r, fr.end.y - r, f)))
			b.stroke(pts, 1.6, Color(FRAME_DEEP, 0.4))
	var inner := Rect2(origin - Vector2.ONE * 5.0, Vector2.ONE * 8.0 * cell + Vector2.ONE * 10.0)
	b.fan(Face.Builder.round_rect(inner.position, inner.size, 6.0), FRAME_LIP)
	b.stroke(PackedVector2Array([fr.position + Vector2(r, 3), fr.position + Vector2(fr.size.x - r, 3)]), 3.0, Color(1, 1, 1, 0.25))
	for cx: float in [fr.position.x + band * 0.5, fr.end.x - band * 0.5]:
		for cy: float in [fr.position.y + band * 0.5, fr.end.y - band * 0.5]:
			b.disc(Vector2(cx, cy + 2.0), band * 0.2, Color(FRAME_DEEP, 0.8))
			b.disc(Vector2(cx, cy), band * 0.2, BRASS_DEEP)
			b.disc(Vector2(cx, cy - 1.0), band * 0.15, BRASS)
			b.disc(Vector2(cx - band * 0.05, cy - band * 0.06), band * 0.05, Color(1, 1, 1, 0.7))
	# the squares: the played ones a mown lawn with a lighter stripe, the
	# others sandstone flecked a little darker
	for row in 8:
		for col in 8:
			var sq := sq_of(Vector2i(col, row))
			var at := origin + Vector2(col, row) * cell
			if Rules.is_dark(sq):
				b.fan(_square(at), DARK)
				b.fan(PackedVector2Array([at + Vector2(0, cell * 0.5), at + Vector2(cell, cell * 0.5),
					at + Vector2(cell, cell), at + Vector2(0, cell)]), Color(DARK_DEEP, 0.35))
				for k in 3:
					var tuft := at + Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.15, 0.88)) * cell
					b.stroke(PackedVector2Array([tuft, tuft + Vector2(-0.03, -0.07) * cell]), cell * 0.018, Color(DARK_DEEP, 0.8))
					b.stroke(PackedVector2Array([tuft, tuft + Vector2(0.03, -0.06) * cell]), cell * 0.018, Color(DARK_DEEP, 0.8))
			else:
				b.fan(_square(at), LIGHT)
				b.fan(PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell * 0.06), at + Vector2(0, cell * 0.06)]),
					Color(1, 1, 1, 0.25))
				for k in 4:
					var q := at + Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.15, 0.88)) * cell
					b.ellipse(q, cell * rng.randf_range(0.02, 0.04), cell * rng.randf_range(0.012, 0.025), Color(0.62, 0.5, 0.33, 0.14))
				# now and then a daisy in the sandstone's cracks
				if rng.randf() < 0.18:
					var q := at + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)) * cell
					for k in 5:
						b.disc(q + Vector2.from_angle(TAU * k / 5.0) * cell * 0.035, cell * 0.028, Color(1, 1, 1, 0.8))
					b.disc(q, cell * 0.022, Pal.SUN_RAY)
	b.fan(PackedVector2Array([origin, origin + Vector2(8.0 * cell, 0), origin + Vector2(8.0 * cell, cell * 0.07), origin + Vector2(0, cell * 0.07)]),
		Color(FRAME_DEEP, 0.18))
	b.fan(PackedVector2Array([origin, origin + Vector2(cell * 0.05, 0), origin + Vector2(cell * 0.05, 8.0 * cell), origin + Vector2(0, 8.0 * cell)]),
		Color(FRAME_DEEP, 0.12))
	return b.mesh()

func _draw_coords() -> void:
	if _font == null or still:
		return
	var fs := int(cell * 0.2)
	var ink := Color(Pal.PAPER, 0.75)
	for i in 8:
		var file_sq := sq_of(Vector2i(i, 7))
		var letter := "abcdefgh"[file_sq & 7]
		var at := Vector2(origin.x + (i + 0.5) * cell, origin.y + 8.0 * cell + FRAME * cell * 0.5 + fs * 0.36)
		var w := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, at - Vector2(w * 0.5, 0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		var rank_sq := sq_of(Vector2i(0, i))
		var num := str((rank_sq >> 3) + 1)
		var at2 := Vector2(origin.x - FRAME * cell * 0.5, origin.y + (i + 0.5) * cell + fs * 0.36)
		var w2 := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, at2 - Vector2(w2 * 0.5, 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

## "+2" on a little paper tag at the end of the tray of whoever has more
## pieces left.
func _draw_advantage() -> void:
	if rules == null or _font == null or still:
		return
	# only what has landed in the tray, not what is still in the air
	var me: int = _trays[0].filter(func(a: Actor) -> bool: return a.kind == "" and not a.doomed).size()
	var them: int = _trays[1].filter(func(a: Actor) -> bool: return a.kind == "" and not a.doomed).size()
	if me == them:
		return
	var tray := 0 if me > them else 1
	var fs := int(cell * 0.28)
	var n: int = me if tray == 0 else them
	var text := "+%d" % absi(me - them)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := minf(origin.x + (0.42 + n * TRAY_STEP) * cell - cell * 0.1, origin.x + 8.0 * cell - w - fs * 0.7)
	var mid := _tray_mid(tray)
	var tag := Rect2(Vector2(x, mid - fs * 0.62), Vector2(w + fs * 0.7, fs * 1.24))
	draw_rect(Rect2(tag.position + Vector2(0, 3), tag.size), Color(SOIL_DEEP, 0.6))
	draw_rect(tag, Pal.PAPER)
	draw_string(_font, Vector2(tag.position.x + fs * 0.35, mid + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)

## A chain's count, "x2", "x3", popping up over the piece just taken and
## floating off.
func _draw_combos() -> void:
	if _font == null:
		return
	var keep: Array = []
	for c: Array in _combos:
		var t := (_now - float(c[2])) / COMBO_TIME
		if t >= 1.0:
			continue
		keep.append(c)
		var pop := CheckersSkin._back_out_k(clampf(t / 0.25, 0.0, 1.0))
		var fs := int(cell * (0.36 + 0.06 * int(c[1])) * pop)
		if fs < 4:
			continue
		var text := "x%d" % int(c[1])
		var at: Vector2 = c[0] - Vector2(0.0, cell * 0.4 * t)
		var alpha := 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.3
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := at - Vector2(w * 0.5, -fs * 0.35)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.22), Color(Pal.PAPER, alpha))
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.SUN, alpha))
	_combos = keep

func _build_marks() -> ArrayMesh:
	var b := Face.Builder.new()
	if _last.size() >= 2:
		# where it came from, faintly; where it ended, warmly; and a trail of
		# footprints along the route
		var at := origin + cell_of(_last[0]) * cell
		b.fan(_square(at), Color(MARK_LAST, 0.2))
		b.stroke(Face.Builder.round_rect(at + Vector2.ONE * cell * 0.08, Vector2.ONE * cell * 0.84, cell * 0.14),
			cell * 0.03, Color(MARK_LAST, 0.7), true)
		b.fan(_square(origin + cell_of(_last[_last.size() - 1]) * cell), MARK_LAST)
		for i in _last.size() - 1:
			var p0 := cell_of(_last[i])
			var p1 := cell_of(_last[i + 1])
			var n := int(p0.distance_to(p1) / 0.26)
			for k in n + 1:
				var q := p0.lerp(p1, float(k) / maxf(n, 1))
				if q.distance_to(cell_of(_last[0])) < 0.42 or q.distance_to(cell_of(_last[_last.size() - 1])) < 0.42:
					continue
				var side := (p1 - p0).normalized().orthogonal() * (0.06 if k % 2 == 0 else -0.06)
				b.ellipse(px(q + side), cell * 0.045, cell * 0.035, Color(0.8, 0.55, 0.2, 0.42))
	if _selected >= 0:
		b.fan(_square(origin + cell_of(_selected) * cell), MARK_PICK)
	if _hover >= 0:
		b.fan(_square(origin + cell_of(_hover) * cell), Color(MARK_PICK, 0.35))
	return null if b.verts.is_empty() else b.mesh()

func _square(at: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)])

# --- the live layers ---

## Under the pieces: the picked piece's ring, its routes and landings
## popping in and out, the rings on the pieces that must capture, the
## hint's route drawing itself, landing ripples and a gliding king's speed
## lines.
func _build_under() -> ArrayMesh:
	var b := Face.Builder.new()
	var reduce := Motion.reduce
	if not _must.is_empty() and _selected < 0:
		var pop := 1.0 if reduce else CheckersSkin._back_out_k(clampf((_now - _must_at) / 0.3, 0.0, 1.0))
		var pulse := 1.0 if reduce else 0.75 + 0.25 * sin(_now * 5.0)
		for sq in _must:
			var c := px(cell_of(sq))
			var rr := cell * 0.47 * pop
			for k in 12:
				var a0 := TAU * float(k) / 12.0 + (0.0 if reduce else _now * 0.8)
				b.stroke(Face.Builder.arc_points(c, rr, a0, a0 + TAU / 12.0 * 0.6), cell * 0.06, Color(Pal.SUN, 0.8 * pulse))
	if _selected >= 0:
		var c := px(cell_of(_selected))
		var s := 1.0 if reduce else CheckersSkin._back_out_k(clampf((_now - _select_at) / 0.2, 0.0, 1.0))
		var w := cell * (0.05 + (0.0 if reduce else 0.012 * sin(_now * 5.0)))
		b.stroke(Face.Builder.ring(c, cell * 0.47 * s, cell * 0.47 * s), w, Color(Pal.SUN, 0.85), true)
		_route_marks(b)
		_target_marks(b, _targets, _selected, _select_at, true)
	if not _gone.is_empty():
		if reduce or _now - _gone_at > 0.4:
			_gone = {}
		else:
			_target_marks(b, _gone, _gone_from, _gone_at, false)
	if not _hint.is_empty():
		_hint_route(b)
	var keep: Array = []
	for r: Array in _ripples:
		var t := (_now - float(r[1])) / RIPPLE_TIME
		if t >= 1.0:
			continue
		keep.append(r)
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		var rx := cell * (0.3 + 0.34 * e) * float(r[2])
		b.stroke(Face.Builder.ring(px(r[0]) + Vector2(0.0, cell * 0.06), rx, rx * 0.8), cell * 0.035 * (1.0 - t) + 1.0,
			Color(1, 1, 1, 0.6 * (1.0 - t)), true)
	_ripples = keep
	if not reduce:
		for a: Actor in _actors:
			if a.kind == "move" and a.type == Rules.KING and _now >= a.t0:
				_speed_lines(b, a)
			elif a.kind == "crown" and _now >= a.t0:
				var u := clampf((_now - a.t0) / a.dur, 0.0, 1.0)
				var land: float = skin.crown_land()
				if u > land:
					var k := (u - land) / (1.0 - land)
					var c := px(a.at)
					var len := cell * 0.8 * sin(PI * k)
					for q in 12:
						var ang := TAU * float(q) / 12.0 + _now * 1.5
						var d := Vector2.from_angle(ang)
						var o := d.orthogonal() * cell * 0.05
						b.fan(PackedVector2Array([c + d * cell * 0.3 + o, c + d * (cell * 0.3 + len), c + d * cell * 0.3 - o]),
							Color(Pal.SUN_RAY, 0.6 * sin(PI * k)))
	return null if b.verts.is_empty() else b.mesh()

## The picked piece's capture routes: footprints along each, and a rose
## ring of dashes round every piece it would take.
func _route_marks(b: Face.Builder) -> void:
	var reduce := Motion.reduce
	var p := 1.0 if reduce else clampf((_now - _select_at) / 0.35, 0.0, 1.0)
	var done := {}
	for m: PackedInt32Array in _routes():
		if Rules.mv_ncaps(m) == 0:
			continue
		var pts: Array = [cell_of(_selected)]
		for sq in Rules.mv_path(m):
			pts.append(cell_of(sq))
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var z: Vector2 = pts[i + 1]
			var n := int(a.distance_to(z) / 0.22)
			for k in range(1, n):
				var f := float(k) / n
				if (float(i) + f) / (pts.size() - 1) > p:
					break
				b.disc(px(a.lerp(z, f)), cell * 0.035, Color(Pal.SUN, 0.55))
		for cap in Rules.mv_caps(m):
			if done.has(cap):
				continue
			done[cap] = true
			var c := px(cell_of(cap))
			var r := cell * 0.46 * p
			for k in 10:
				var a0 := TAU * float(k) / 10.0 + (0.0 if reduce else -_now * 0.9)
				b.stroke(Face.Builder.arc_points(c, r, a0, a0 + TAU / 10.0 * 0.6), cell * 0.06, Color(Pal.BAD, 0.7))

## Where the picked piece can land next, popping in (`coming`) or back out,
## a step a square out from the piece.
func _target_marks(b: Face.Builder, targets: Dictionary, from: int, since: float, coming: bool) -> void:
	var fc := cell_of(from)
	var ends := {}
	if coming:
		for m: PackedInt32Array in _routes():
			ends[Rules.mv_to(m)] = true
	for sq: int in targets:
		var tc := cell_of(sq)
		var dist := maxf(absf(tc.x - fc.x), absf(tc.y - fc.y))
		var s := 1.0
		if Motion.reduce:
			s = 1.0 if coming else 0.0
		elif coming:
			s = CheckersSkin._back_out_k(clampf((_now - since - dist * MARK_STEP) / MARK_POP, 0.0, 1.0))
		else:
			s = 1.0 - clampf((_now - since - dist * 0.02) / 0.14, 0.0, 1.0)
		if s <= 0.01:
			continue
		var c := px(tc)
		if ends.has(sq) or not coming:
			# a seed: a soft dark pip with a glint
			b.disc(c, cell * 0.15 * s, MARK_DOT)
			b.disc(c + Vector2(-0.035, -0.035) * cell * s, cell * 0.05 * s, Color(1, 1, 1, 0.24))
		else:
			# a stepping stone on the way: a smaller gold ring
			b.stroke(Face.Builder.ring(c, cell * 0.14 * s, cell * 0.14 * s), cell * 0.035, Color(Pal.SUN, 0.8), true)

## The hint: the route drawing itself from the piece, an arrow head on its
## last leg and a ring round the piece.
func _hint_route(b: Face.Builder) -> void:
	var reduce := Motion.reduce
	var pts: Array = [px(cell_of(_hint[0]))]
	for sq in Rules.mv_path(_hint):
		pts.append(px(cell_of(sq)))
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var p := 1.0 if reduce else clampf((_now - _hint_at) / 0.5, 0.0, 1.0)
	var glow := 0.8 if reduce else 0.8 + 0.15 * sin(_now * 4.0)
	var run := total * CheckersSkin._ease_in_out(p)
	var line := PackedVector2Array([(pts[0] as Vector2) + ((pts[1] as Vector2) - pts[0]).normalized() * cell * 0.25])
	var walked := 0.0
	var end: Vector2 = pts[0]
	var dir := Vector2.RIGHT
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var z: Vector2 = pts[i + 1]
		var seg := a.distance_to(z)
		dir = (z - a).normalized()
		if i == pts.size() - 2:
			z -= dir * cell * 0.42
			seg = a.distance_to(z)
		if walked + seg >= run:
			end = a + dir * (run - walked)
			line.append(end)
			break
		line.append(z)
		end = z
		walked += seg
	if line.size() > 1:
		b.stroke(line, cell * 0.13, Color(HINT, 0.75 * glow))
	var head := CheckersSkin._back_out_k(clampf((p - 0.6) / 0.4, 0.0, 1.0))
	if head > 0.01:
		var tip: Vector2 = (pts[pts.size() - 1] as Vector2) - dir * cell * 0.2
		var side := Vector2(-dir.y, dir.x) * head
		var back := tip - dir * cell * 0.34 * head
		b.fan(PackedVector2Array([tip, back + side * cell * 0.22, back - side * cell * 0.22]), Color(HINT, 0.85 * glow))
	b.stroke(Face.Builder.ring(pts[0], cell * 0.46, cell * 0.46), cell * 0.06, Color(HINT, 0.8 * glow), true)

## Three soft lines streaming behind a king gliding along the lawn.
func _speed_lines(b: Face.Builder, a: Actor) -> void:
	var t := _now - a.t0
	for leg: Array in a.legs:
		if t < float(leg[2]) or t > float(leg[2]) + float(leg[3]):
			continue
		var u := (t - float(leg[2])) / float(leg[3])
		if u <= 0.02 or u >= 0.98 or int(leg[4]) != LEG_STEP:
			return
		var f: Vector2 = leg[0]
		var z: Vector2 = leg[1]
		var across := (z - f).normalized().orthogonal()
		for h: float in [-0.2, 0.0, 0.2]:
			var prev := Vector2.INF
			for k in 8:
				var uu := u - float(k) * 0.04
				if uu < 0.0:
					break
				var pose: RefCounted = skin.step_pose(a.move_type, f, z, uu)
				var q := px(pose.at) + across * h * cell - Vector2(0.0, pose.lift * cell * LIFT_RISE)
				if prev != Vector2.INF:
					var fade := 1.0 - float(k) / 8.0
					b.stroke(PackedVector2Array([prev, q]), cell * 0.05 * fade + 0.5, Color(1, 1, 1, 0.7 * fade * sin(PI * u)))
				prev = q
		return

## Over the pieces: the capture's impact star, a knocked piece's dizzy
## stars, the sleepers' z's, the computer's thought bubble and the win's
## petals.
func _build_over(poses: Array) -> ArrayMesh:
	var b := Face.Builder.new()
	var reduce := Motion.reduce
	var keep: Array = []
	for im: Array in _impacts:
		var t := (_now - float(im[1])) / IMPACT_TIME
		if t >= 1.0:
			continue
		keep.append(im)
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		var r := cell * (0.22 + 0.4 * e)
		_star(b, im[0], r, r * 0.42, 8, t * 0.8, Color(1, 1, 1, 0.95 * (1.0 - t)))
		_star(b, im[0], r * 0.55, r * 0.25, 8, 0.4 - t * 0.8, Color(Pal.SUN_RAY, 0.9 * (1.0 - t)))
	_impacts = keep
	for e: Array in poses:
		var a: Actor = e[1]
		var p = e[2]
		var up := clampf(p.lift, 0.0, 3.0)
		var centre := px(p.at) - Vector2(0.0, up * cell * LIFT_RISE)
		if a.kind == "knock" and not reduce:
			for i in 3:
				var ang := _now * 7.0 + TAU * float(i) / 3.0
				var q: Vector2 = centre + Vector2(cos(ang) * 0.34, sin(ang) * 0.14 - 0.4) * cell * p.scale
				_star(b, q, cell * 0.08 * p.scale, cell * 0.035 * p.scale, 5, _now * 3.0, Pal.SUN_RAY)
		elif not reduce and a.kind == "" and ((a.sq < 0 and not a.doomed) or (_mood == "draw" and a.phase < 0.4)):
			_zzz(b, a, p)
	if _mood == "" and not reduce:
		var env := clampf((_now - _think_at) / 0.3, 0.0, 1.0) if _thinking else 1.0 - clampf((_now - _think_off) / 0.2, 0.0, 1.0)
		if env > 0.0:
			# the thought bubble stands over the moon's side of the board
			var at := Vector2(origin.x + 7.1 * cell, origin.y - FRAME * cell * 0.2)
			var s := env
			b.disc(at + Vector2(-0.34, 0.32) * cell, cell * 0.05 * s, Color(Pal.PAPER, 0.95))
			b.disc(at + Vector2(-0.22, 0.2) * cell, cell * 0.07 * s, Color(Pal.PAPER, 0.95))
			for q: Vector3 in [Vector3(-0.15, 0.0, 0.15), Vector3(0.0, -0.05, 0.18), Vector3(0.15, 0.0, 0.15), Vector3(0.0, 0.06, 0.16)]:
				b.disc(at + Vector2(q.x, q.y) * cell * s + Vector2(0, cell * 0.02), cell * q.z * s, Color(Pal.TEXT, 0.12))
			for q: Vector3 in [Vector3(-0.15, 0.0, 0.15), Vector3(0.0, -0.05, 0.18), Vector3(0.15, 0.0, 0.15), Vector3(0.0, 0.06, 0.16)]:
				b.disc(at + Vector2(q.x, q.y) * cell * s, cell * q.z * s, Pal.PAPER)
			for k in 3:
				var lit := maxf(0.0, sin(_now * 5.0 - float(k) * 0.9))
				b.disc(at + Vector2((float(k) - 1.0) * 0.1, -0.01 - 0.03 * lit) * cell * s, cell * 0.034 * s,
					Color(Pal.TEXT_DIM, 0.6 + 0.4 * lit))
	if not _petals.is_empty():
		var since := _now - _petal_at
		for pt: Array in _petals:
			var t := (since - float(pt[1])) / (PETAL_FALL * float(pt[4]))
			if t <= 0.0 or t > 1.8:
				continue
			var alpha := 1.0 if t < 1.0 else 1.0 - (t - 1.0) / 0.8
			var fall := minf(t, 1.0)
			var y := lerpf(-1.8, float(pt[2]), fall)
			var x := float(pt[0]) + (0.35 * sin(fall * 6.0 + float(pt[3])) if t < 1.0 else 0.35 * sin(6.0 + float(pt[3])))
			var spin := float(pt[3]) + (fall * 5.0)
			var cols := [Pal.FLOWER, Pal.FLOWER_TILE, Pal.SUN_RAY]
			var c := px(Vector2(x, y))
			var body := PackedVector2Array()
			var flip := absf(cos(fall * 7.0 + float(pt[3]))) if t < 1.0 else 0.8
			for k in 12:
				var ang := TAU * float(k) / 12.0
				var rr := cell * 0.15 * (0.6 + 0.4 * cos(ang * 0.5) * cos(ang * 0.5))
				body.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.55 * maxf(flip, 0.25)).rotated(spin))
			b.polygon(body, Color(cols[int(pt[5])], alpha))
	return null if b.verts.is_empty() else b.mesh()

## A sleeper's z drifting up, fading in and out, one every Z_PERIOD.
func _zzz(b: Face.Builder, a: Actor, p) -> void:
	var t := fmod(_now / Z_PERIOD + a.phase, 1.0)
	if t > 0.6:
		return
	var v := t / 0.6
	var sc := maxf(p.scale, 0.6)
	var c := px(p.at) + Vector2((0.24 + 0.14 * v) * sc * cell, -(0.3 * p.scale + 0.45 * v * sc) * cell)
	var h := cell * 0.075 * (0.6 + 0.6 * v) * sc
	b.stroke(PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(-h, h), c + Vector2(h, h)]),
		cell * 0.028 * sc, Color(Pal.TEXT_DIM, 0.8 * sin(PI * v)))

## An `n`-pointed star round `c`.
func _star(b: Face.Builder, c: Vector2, r: float, inner: float, n: int, turn: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for k in n * 2:
		var ang := turn + PI * float(k) / float(n) - PI * 0.5
		pts.append(c + Vector2.from_angle(ang) * (r if k % 2 == 0 else inner))
	b.polygon(pts, colour)

func _ripple(c: Vector2, strength: float) -> void:
	if not Motion.reduce:
		_ripples.append([c, _now, strength])
