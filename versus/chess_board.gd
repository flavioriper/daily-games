extends Control

## The chessboard: a top-down board in a wooden frame, a tray above and one
## below for the pieces each side has taken, and the pieces standing on it.
## It draws, it takes the player's touch, and it plays every move as a
## little scene -- but how a piece looks and how it moves is the skin's
## (versus/chess_skin.gd), so none of that is written here.
##
## The truth is the rules object (versus/chess_rules.gd); the board mirrors
## it with one actor a piece, so a piece keeps its identity (its breathing
## phase, where it looks, when it blinks) as it moves. The screen makes a
## move on the rules and then hands the board the move's description
## (play()); the board says `settled` when the scene has finished.
##
## Input: tap a piece of yours to pick it up (its moves appear), tap where
## it goes; or drag it there. A promotion asks which piece with a little
## column over the file.
##
## Draw calls: the board is one mesh, the marks one, every piece a shadow
## and a body (both cached meshes, moved by transform, never rebuilt to
## move), the sixteen coordinates one string each.

signal chosen(move: int)
signal settled
## A tap the rules turned down: "stuck" (the piece has no move at all) or
## "king" (its moves would leave the king in check).
signal refused(reason: String)

const Rules = preload("res://versus/chess_rules.gd")
const ChessSkin = preload("res://versus/chess_skin.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")

## In cells: the tray strip above and below (at least TRAY, growing to
## TRAY_MAX into a tall phone's spare height), the air between it and the
## frame, the wooden frame, the gap between two taken pieces and how small a
## taken piece stands, both at the smallest tray.
const TRAY := 0.66
const TRAY_MAX := 1.0
const TRAY_GAP := 0.12
const FRAME := 0.3
const TRAY_STEP := 0.44
const TRAY_SCALE := 0.5
const DRAG_START := 14.0

## The live layers' timings, seconds: a move's marks popping in (a step a
## square out from the piece), the landing ripple, the capture's impact
## star, the check's attack line, a sleeper's z, the win's petals.
const MARK_STEP := 0.035
const MARK_POP := 0.22
const RIPPLE_TIME := 0.42
const IMPACT_TIME := 0.32
const ATTACK_TIME := 1.0
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
const MARK_DOT := Color(0.23, 0.19, 0.16, 0.2)
const HINT := Color("f5a623")
const SOIL := Color("6f4c33")
const SOIL_DEEP := Color("553823")
const MOSS := Color("9cb97c")
const MOSS_DEEP := Color("7f9f62")
const BRASS := Color("d9a441")
const BRASS_DEEP := Color("a8772a")
const SWEAT := Color("a9d4ef")

var rules: RefCounted
var skin: RefCounted = ChessSkin.named("garden")
## The colour the player moves (Rules.WHITE or BLACK); their pieces are
## always the cream ones and always at the bottom.
var player := Rules.WHITE
var interactive := false
## The tab's picture: drawn once, no clock, no touch.
var still := false

var cell := 100.0
## The trays' depth and their pieces' scale and spacing this layout.
var tray_h := TRAY
var tray_scale := TRAY_SCALE
var tray_step := TRAY_STEP
## The top-left corner of the squares, in pixels.
var origin := Vector2.ZERO

class Actor:
	var type := 0
	var side := 0
	var sq := -1
	var at := Vector2.ZERO
	var rest_scale := 1.0
	var phase := 0.0
	var look := 1.0
	var blink_at := 0.0
	var kind := ""
	var t0 := 0.0
	var dur := 0.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var dir := Vector2.ZERO
	var move_type := 0
	var dropped := false
	var face := -1
	var face_until := 0.0
	## The fraction of its move at which this piece strikes what it takes,
	## -1 when it takes nothing: it leans into the hit there.
	var hit_u := -1.0
	## When its crown was knocked off (the board's clock), -1 while it has
	## it on, and the way it flew.
	var crown_off := -1.0
	var crown_dir := 1.0

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
var _targets := {}
var _last := Vector2i(-1, -1)
var _hint := Vector2i(-1, -1)
var _check_sq := -1
## The computer's piece about to move, held up for a beat.
var _lifted := -1
## How the game ended, for the faces: "" playing, "won", "lost", "draw".
var _mood := ""

var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
var _drag_cell := Vector2.ZERO
var _hover := -1
var _picker: PackedInt32Array = PackedInt32Array()

var _board_mesh: ArrayMesh
var _marks_mesh: ArrayMesh
## The marks mesh drawn before this one, kept alive a frame: a canvas
## command holds a mesh by RID.
var _marks_prev: ArrayMesh
## The whole board, trays included, in this control's pixels.
var used_rect := Rect2()
var _marks_dirty := true
var _glow_mesh: ArrayMesh
var _shadow_mesh: ArrayMesh
var _meshes := {}
var _font: Font

# the live layers: rebuilt a frame at a time while anything in them moves,
# one mesh under the pieces and one over, each kept a frame past its
# replacement because a canvas command holds a mesh by RID
var _under_mesh: ArrayMesh
var _over_mesh: ArrayMesh
var _live_prev: Array = []
var _select_at := 0.0
var _gone: Dictionary = {}
var _gone_from := -1
var _gone_at := -10.0
var _hint_at := 0.0
var _ripples: Array = []
var _impacts: Array = []
var _check_at := 0.0
var _check_from := PackedInt32Array()
var _thinking := false
var _think_at := 0.0
var _think_off := -10.0
var _petals: Array = []
var _petal_at := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_font = get_theme_default_font()
	resized.connect(_layout)
	if not still:
		_fx = Fx2D.new()
		add_child(_fx)

# --- setting up ---

## A fresh set from the rules' position. `enter` drops the pieces in, back
## rank first, and the board says `settled` once they are down.
func setup(the_rules: RefCounted, as_colour: int, enter := true) -> void:
	rules = the_rules
	player = as_colour
	_actors.clear()
	_at_sq.clear()
	_trays = [[], []]
	_events.clear()
	_selected = -1
	_targets = {}
	_last = Vector2i(-1, -1)
	_hint = Vector2i(-1, -1)
	_check_sq = -1
	_lifted = -1
	_mood = ""
	_fallen = -1
	_picker = PackedInt32Array()
	_gone = {}
	_ripples.clear()
	_impacts.clear()
	_petals.clear()
	_check_from = PackedInt32Array()
	_thinking = false
	for sq in 64:
		var p: int = rules.board[sq]
		if p == 0:
			continue
		var a := Actor.new()
		a.crown_off = -1.0
		a.type = absi(p)
		a.side = 0 if Rules.side_of(p) == player else 1
		a.sq = sq
		a.at = cell_of(sq)
		a.phase = _rng.randf()
		a.look = 1.0 if a.at.x < 3.5 else -1.0
		a.blink_at = _rng.randf_range(1.0, 6.0)
		_actors.append(a)
		_at_sq[sq] = a
	_marks_dirty = true
	if enter and not still and not Motion.reduce:
		_busy = true
		for a: Actor in _actors:
			# From the far side forward, a ripple across each rank.
			var row := a.at.y if a.side == 1 else 7.0 - a.at.y
			var delay := (row * 0.09 if a.side == 1 else 0.45 + row * 0.09) + a.at.x * 0.025
			_start(a, "enter", skin.enter_time(), a.at, a.at, delay)
		_after(0.1, func() -> void: _cue("enter"))
	queue_redraw()

func set_check(sq: int) -> void:
	if sq >= 0 and sq != _check_sq:
		_check_at = _now
		# who gives it, for the line that flashes from them to the king
		var king: int = rules.board[sq]
		_check_from = rules.attackers_of(sq, 1 - Rules.side_of(king)) if king != 0 else PackedInt32Array()
	elif sq < 0:
		_check_from = PackedInt32Array()
	_check_sq = sq
	queue_redraw()

## The computer is thinking: its pieces look round the board.
func set_thinking(on: bool) -> void:
	if on and not _thinking:
		_think_at = _now
	elif not on and _thinking:
		_think_off = _now
	_thinking = on

func set_hint(move: int) -> void:
	_hint = Vector2i(-1, -1) if move < 0 else Vector2i(Rules.mv_from(move), Rules.mv_to(move))
	_hint_at = _now
	_marks_dirty = true
	if move >= 0 and _fx != null:
		_fx.ring(px(cell_of(_hint.x)), cell * 0.5, HINT)
		_fx.sparkle(px(cell_of(_hint.x)), HINT)

func set_lifted(sq: int) -> void:
	_lifted = sq

func deselect() -> void:
	if _selected >= 0 and not _targets.is_empty():
		# the marks pop back out rather than vanish
		_gone = _targets
		_gone_from = _selected
		_gone_at = _now
	_selected = -1
	_targets = {}
	_picker = PackedInt32Array()
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
	return Vector2(f, 7 - r) if player == Rules.WHITE else Vector2(7 - f, r)

func sq_of(c: Vector2i) -> int:
	if c.x < 0 or c.x > 7 or c.y < 0 or c.y > 7:
		return -1
	return (7 - c.y) * 8 + c.x if player == Rules.WHITE else c.y * 8 + (7 - c.x)

## A square's centre, in pixels, for a display cell (fractional allowed).
func px(c: Vector2) -> Vector2:
	return origin + (c + Vector2(0.5, 0.5)) * cell

func cell_at(p: Vector2) -> Vector2:
	return (p - origin) / cell - Vector2(0.5, 0.5)

func sq_at(p: Vector2) -> int:
	var c := (p - origin) / cell
	return sq_of(Vector2i(floori(c.x), floori(c.y)))

## Where a taken piece stands in its tray: tray 0 below the board (what the
## player took), 1 above (what the computer took).
func tray_cell(tray: int, slot: int) -> Vector2:
	var foot := Vector2(origin.x + (0.45 + slot * tray_step) * cell, _tray_mid(tray) + 0.4 * tray_scale * cell)
	return cell_at(foot - Vector2(0.0, skin.foot_drop() * cell))

## A tray's middle line, in pixels.
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
	# A tall phone's spare height goes into the trays, up to TRAY_MAX, and
	# the pieces in them grow with it.
	tray_h = clampf((size.y / cell - across) * 0.5 - TRAY_GAP, TRAY, TRAY_MAX)
	var k := (tray_h - TRAY) / (TRAY_MAX - TRAY)
	tray_scale = lerpf(TRAY_SCALE, 0.62, k)
	tray_step = minf(TRAY_STEP * tray_scale / TRAY_SCALE, 0.53)
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
	_glow_mesh = null
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
			if a.kind in ["move", "knock", "promote", "enter", "back"]:
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
	a.hit_u = -1.0
	match kind:
		"move", "knock", "back":
			a.at = a.to
	if kind == "knock":
		a.face = ChessSkin.F_SLEEP
		a.face_until = INF

func _cue(name: String, pitch := 1.0) -> void:
	if _fx != null:
		_fx.cue(name, pitch)

func _puff(c: Vector2, colour := Color("e9dcc3"), n := 5) -> void:
	if _fx != null:
		_fx.puff(px(c) + Vector2(0.0, skin.foot_drop() * cell), colour, n)

# --- playing a move ---

## Plays a move the rules have just made: `d` is rules.describe() taken
## before it. The board says `settled` when everything has landed.
func play(d: Dictionary) -> void:
	var a: Actor = _at_sq.get(int(d.from))
	if a == null:
		return
	_busy = true
	var reduce := Motion.reduce
	var to_c := cell_of(int(d.to))
	var dropped := _dragging or a.at.distance_to(to_c) < 0.01
	var start := _drag_cell if _dragging else cell_of(int(d.from))
	deselect()
	_lifted = -1
	_hint = Vector2i(-1, -1)
	var type := absi(int(d.piece))
	var dur: float = 0.2 if dropped or reduce else skin.move_time(type, start, to_c)
	_at_sq.erase(int(d.from))
	a.sq = int(d.to)
	a.move_type = type
	a.dropped = dropped
	_start(a, "move", dur, start, to_c)
	if start.x != to_c.x:
		a.look = signf(to_c.x - start.x)
	if not dropped and not reduce:
		_cue(skin.takeoff_cue(type))
	var contact: float = dur * (1.0 if dropped or reduce else skin.contact_at(type))
	# What the hand's own move earned knocks as it happens: a capture at the
	# contact, a promotion as the pawn turns. The cues ring for the
	# computer's moves too and are not mapped (docs/agents/haptics.md).
	var hand: bool = int(d.side) == player
	a.hit_u = -1.0
	if int(d.captured) != 0 and not dropped and not reduce:
		a.hit_u = skin.contact_at(type)
	if int(d.captured) != 0:
		var victim: Actor = _at_sq.get(int(d.captured_at))
		if victim != null:
			_at_sq.erase(int(d.captured_at))
			_knock(victim, to_c - start, contact, hand)
	_at_sq[int(d.to)] = a
	if int(d.rook_from) >= 0:
		var rook: Actor = _at_sq.get(int(d.rook_from))
		if rook != null:
			_at_sq.erase(int(d.rook_from))
			rook.sq = int(d.rook_to)
			rook.move_type = Rules.KNIGHT
			_start(rook, "move", 0.2 if reduce else skin.move_time(Rules.KNIGHT, rook.at, cell_of(rook.sq)),
				rook.at, cell_of(rook.sq), 0.0 if reduce else 0.12)
			_at_sq[rook.sq] = rook
	_after(dur, func() -> void:
		if int(d.rook_from) >= 0:
			_cue("castle")
		elif int(d.captured) == 0:
			_cue(skin.land_cue(type), _rng.randf_range(0.94, 1.06))
		if skin.lands_with_dust(type) and not dropped:
			_puff(to_c)
		elif not reduce:
			_puff(to_c, Color("efe4cc"), 3)
		_ripple(to_c, 1.0 if skin.lands_with_dust(type) else 0.7))
	if int(d.promo) != 0:
		var pt: float = skin.promote_time()
		_after(dur, func() -> void:
			a.move_type = a.type
			_start(a, "promote", 0.2 if reduce else pt, a.to, a.to)
			_cue("promote")
			if hand and int(d.captured) == 0 and _fx != null:
				_fx.buzz(Haptics.BUMP))
		_after(dur + pt * 0.5, func() -> void:
			a.type = absi(int(d.promo))
			if _fx != null:
				_fx.sparkle(px(a.to), Pal.SUN)
				_fx.ring(px(a.to), cell * 0.5, Pal.SUN))
	_last = Vector2i(int(d.from), int(d.to))
	_check_sq = -1
	_marks_dirty = true

## Knocks `victim` off the board into its tray, `contact` seconds from now,
## pushed the way it was hit.
func _knock(victim: Actor, dir: Vector2, contact: float, hand := false) -> void:
	var tray := 0 if victim.side == 1 else 1
	var slot: int = _trays[tray].size()
	_trays[tray].append(victim)
	victim.sq = -1
	var target := tray_cell(tray, slot)
	_after(contact, func() -> void:
		_start(victim, "knock", 0.25 if Motion.reduce else skin.knock_time(), victim.at, target)
		victim.dir = dir
		victim.rest_scale = tray_scale
		victim.face = ChessSkin.F_DIZZY
		victim.face_until = INF
		_cue("capture", _rng.randf_range(0.95, 1.05))
		if _fx != null:
			if hand:
				_fx.buzz(Haptics.BUMP)
			var hit := px(victim.at)
			_fx.ring(hit, cell * 0.35, Color(Pal.PAPER, 0.9), 0.35)
			_fx.puff(hit, Pal.SUN_RAY, 6)
		if not Motion.reduce:
			_impacts.append([px(victim.at) - Vector2(0.0, cell * 0.25), _now]))

## Takes a move back (undo): the piece walks home, anything it took comes
## back out of the tray, a castled rook hops back, a queen is a pawn again.
func rewind(d: Dictionary) -> void:
	var a: Actor = _at_sq.get(int(d.to))
	if a == null:
		return
	_busy = true
	var dur := 0.2 if Motion.reduce else 0.38
	_at_sq.erase(int(d.to))
	if int(d.promo) != 0:
		a.type = Rules.PAWN
	a.sq = int(d.from)
	a.move_type = Rules.BISHOP
	_start(a, "move", dur, a.at, cell_of(a.sq))
	_at_sq[a.sq] = a
	if int(d.captured) != 0:
		var tray := 0 if (Rules.side_of(int(d.captured)) != player) else 1
		var victim: Actor = _trays[tray].pop_back() if not _trays[tray].is_empty() else null
		if victim != null:
			victim.sq = int(d.captured_at)
			victim.rest_scale = 1.0
			victim.face = ChessSkin.F_JOY
			victim.face_until = _now + 1.2
			_start(victim, "back", dur, victim.at, cell_of(victim.sq))
			_at_sq[victim.sq] = victim
	if int(d.rook_from) >= 0:
		var rook: Actor = _at_sq.get(int(d.rook_to))
		if rook != null:
			_at_sq.erase(int(d.rook_to))
			rook.sq = int(d.rook_from)
			rook.move_type = Rules.BISHOP
			_start(rook, "move", dur, rook.at, cell_of(rook.sq))
			_at_sq[rook.sq] = rook
	_cue("slide")
	_last = Vector2i(-1, -1)
	_check_sq = -1
	deselect()

## The king in check trembles and looks worried.
func tremble(sq: int) -> void:
	var a: Actor = _at_sq.get(sq)
	if a == null or Motion.reduce:
		return
	_start(a, "tremble", skin.tremble_time(), a.at, a.at)
	a.face = ChessSkin.F_WORRY
	a.face_until = _now + skin.tremble_time()

## The end of the game: the mated king goes over and the winners hop in a
## wave out from the winning piece; a draw puts everyone to sleep.
func finish(outcome: String, king_sq := -1) -> void:
	_mood = outcome
	deselect()
	_lifted = -1
	if Motion.reduce:
		return
	if king_sq >= 0 and _at_sq.has(king_sq):
		_fallen = king_sq
		var k: Actor = _at_sq[king_sq]
		_start(k, "topple", skin.topple_time(), k.at, k.at, 0.2)
		k.face = ChessSkin.F_DIZZY
		k.face_until = INF
		if skin.has_crown(k.type):
			# knocked off the way he falls, unless that would throw it off
			# the board, then the other way
			var dir := -1.0 if k.side == 0 else 1.0
			if k.at.x + dir * 1.5 < -0.2 or k.at.x + dir * 1.5 > 7.2:
				dir = -dir
			k.crown_dir = dir
			_after(0.2 + skin.topple_time() * skin.crown_pop(), func() -> void:
				k.crown_off = _now
				_cue("lift", 1.3)
				if _fx != null:
					_fx.sparkle(_foot(k.at) + skin.crown_seat(k.type, cell), Pal.SUN))
			_after(0.2 + skin.topple_time() * skin.crown_pop() + skin.crown_time() * 0.48, func() -> void:
				_cue("place", 1.33)
				_ripple(k.at + Vector2(k.crown_dir * 1.05, 0.0), 0.6))
	if outcome == "draw":
		return
	if outcome == "won":
		# petals drift down over the board
		_petal_at = _now
		var prng := RandomNumberGenerator.new()
		prng.seed = 4711
		for i in PETALS:
			_petals.append([prng.randf_range(-0.3, 8.3), 0.6 + prng.randf_range(0.0, 1.6),
				prng.randf_range(4.5, 8.4), prng.randf() * TAU, prng.randf_range(0.8, 1.2), i % 3])
	var winners := 0 if outcome == "won" else 1
	var centre := cell_of(_last.y) if _last.y >= 0 else Vector2(3.5, 3.5)
	for a: Actor in _actors:
		if a.side == winners and a.sq >= 0:
			var delay := 0.5 + a.at.distance_to(centre) * 0.07
			for k in 2:
				_after(delay + k * 0.6, func() -> void:
					if a.kind == "":
						_start(a, "cheer", skin.cheer_time(), a.at, a.at))

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
		if a.sq >= 0 and a.kind == "" and a.sq != _selected and a.sq != _lifted and a.sq != _check_sq:
			idle.append(a)
	if idle.is_empty():
		return
	var a: Actor = idle[_rng.randi() % idle.size()]
	_start(a, "fidget", skin.fidget_time(a.type), a.at, a.at)

func _shiver(a: Actor) -> void:
	_start(a, "shiver", skin.shiver_time(), a.at, a.at)
	a.face = ChessSkin.F_WORRY
	a.face_until = _now + 0.6

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
	if not _picker.is_empty():
		_pick_promotion(p)
		return
	var sq := sq_at(p)
	if _selected >= 0 and _targets.has(sq):
		_choose(sq)
		return
	var a: Actor = _at_sq.get(sq)
	if a != null and a.side == 0:
		if sq == _selected:
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
		_drag_cell = cell_at(p - Vector2(0.0, (skin.foot_drop() - 0.35) * cell))
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
		return
	# Dropped nowhere it can go: back to its square.
	var a: Actor = _at_sq.get(_selected)
	_dragging = false
	_hover = -1
	if a != null:
		_start(a, "move", 0.22, _drag_cell, a.at)
		a.move_type = Rules.BISHOP
	_marks_dirty = true

func _select(sq: int) -> void:
	var moves: PackedInt32Array = rules.moves_from(sq)
	var a: Actor = _at_sq[sq]
	if moves.is_empty():
		deselect()
		_shiver(a)
		_cue("refused")
		var has_any := false
		for m in rules.pseudo():
			if Rules.mv_from(m) == sq:
				has_any = true
				break
		refused.emit("king" if has_any else "stuck")
		return
	if a.kind == "fidget":
		a.kind = ""
	_selected = sq
	_select_at = _now
	_gone = {}
	_targets = {}
	for m in moves:
		_targets[Rules.mv_to(m)] = true
	_marks_dirty = true
	_cue("lift")

func _choose(to: int) -> void:
	var options := PackedInt32Array()
	for m in rules.moves_from(_selected):
		if Rules.mv_to(m) == to:
			options.append(m)
	if options.is_empty():
		return
	if options.size() > 1:
		# A promotion: queen, knight, rook, bishop, stacked down the file.
		_picker = options
		_hover = -1
		_marks_dirty = true
		if _dragging:
			var a: Actor = _at_sq.get(_selected)
			_dragging = false
			if a != null:
				_start(a, "move", 0.2, _drag_cell, cell_of(to))
				a.move_type = Rules.BISHOP
		return
	chosen.emit(options[0])

func _picker_cells() -> Array:
	var cells: Array = []
	if _picker.is_empty():
		return cells
	var c := cell_of(Rules.mv_to(_picker[0]))
	for i in _picker.size():
		cells.append(c + Vector2(0.0, i))
	return cells

func _pick_promotion(p: Vector2) -> void:
	var c := cell_at(p)
	var cells := _picker_cells()
	for i in cells.size():
		var k: Vector2 = cells[i]
		if absf(c.x - k.x) <= 0.5 and absf(c.y - k.y) <= 0.5:
			var m := _picker[i]
			_picker = PackedInt32Array()
			chosen.emit(m)
			return
	# Anywhere else puts the pawn back.
	var from := _selected
	deselect()
	var a: Actor = _at_sq.get(from)
	if a != null and a.at != cell_of(from):
		_start(a, "move", 0.2, a.at, cell_of(from))

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
	if _check_sq >= 0:
		if _glow_mesh == null:
			var b := Face.Builder.new()
			Scenery.soft_disc(b, Vector2.ZERO, cell * 0.7, cell * 0.7, Color(Pal.BAD, 0.95))
			_glow_mesh = b.mesh()
		var pulse := 0.8 if Motion.reduce else 0.65 + 0.35 * sin(_now * 5.0)
		var at := origin + cell_of(_check_sq) * cell
		draw_rect(Rect2(at, Vector2.ONE * cell), Color(Pal.BAD, 0.22 + 0.12 * pulse))
		draw_mesh(_glow_mesh, null, Transform2D(0.0, px(cell_of(_check_sq))), Color(1, 1, 1, pulse))
	# Everything standing, in the order it stands: far to near, and whatever
	# is in the air over the rest.
	var poses: Array = []
	for a: Actor in _actors:
		var pose: RefCounted = _pose_of(a)
		var key: float = pose.at.y + (20.0 if pose.lift > 0.2 or a.kind == "knock" or (a.sq == _selected and _dragging) else 0.0)
		poses.append([key, a, pose])
	poses.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	_live_prev = [_under_mesh, _over_mesh]
	_under_mesh = null if still else _build_under()
	_over_mesh = null if still else _build_over(poses)
	if _under_mesh != null:
		draw_mesh(_under_mesh, null)
	if _shadow_mesh == null:
		# a tight contact shadow under the plinth, and the sun's cast
		# shadow falling down and to the right of it
		var sb := Face.Builder.new()
		var ss: Vector2 = skin.shadow_size()
		Scenery.soft_disc(sb, Vector2(cell * 0.09, cell * 0.03), cell * ss.x * 1.2, cell * ss.y * 1.35, Color(Pal.TEXT, 0.2))
		Scenery.soft_disc(sb, Vector2.ZERO, cell * ss.x * 0.92, cell * ss.y * 0.85, Color(Pal.TEXT, 0.3))
		_shadow_mesh = sb.mesh()
	for e: Array in poses:
		var pose = e[2]
		var up := clampf(pose.lift, 0.0, 2.0)
		var k: float = pose.scale * (1.0 - up * 0.25)
		draw_mesh(_shadow_mesh, null, Transform2D(0.0, Vector2(k, k), 0.0, _foot(pose.at) + Vector2(up * 0.22, up * 0.04) * cell),
			Color(1, 1, 1, pose.alpha * (1.0 - up * 0.35)))
	for e: Array in poses:
		var a: Actor = e[1]
		var pose = e[2]
		var look: float = pose.look if pose.look != 0.0 else a.look
		var bare := a.crown_off >= 0.0 and _now >= a.crown_off
		var mesh := _mesh(a.type, a.side, _face_of(a), look, bare)
		var xf := Transform2D(pose.tilt, pose.squash * pose.scale, 0.0, _foot(pose.at) - Vector2(0.0, pose.lift * cell))
		draw_mesh(mesh, null, xf, Color(1, 1, 1, pose.alpha))
		if bare:
			_draw_crown(a)
	if _over_mesh != null:
		draw_mesh(_over_mesh, null)
	_draw_picker()
	_draw_advantage()

## A crown knocked off its king: in flight, then lying where it stopped,
## with its own shadow.
func _draw_crown(a: Actor) -> void:
	var key := "crown|%d|%d" % [a.type, a.side]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build_crown(b, a.type, a.side, cell)
		m = b.mesh()
		_meshes[key] = m
	# the crown's centre rides REST over the ground when it lies there, so
	# its flight starts that much under its seat
	var rest := cell * 0.12
	var seat: float = -skin.crown_seat(a.type, cell).y / cell - 0.12
	var u := clampf((_now - a.crown_off) / skin.crown_time(), 0.0, 1.0)
	var p: RefCounted = skin.crown_pose(u, a.crown_dir, seat)
	var foot := _foot(a.at + p.at)
	var up := clampf(p.lift, 0.0, 2.0)
	var k := 0.55 * (1.0 - up * 0.25)
	draw_mesh(_shadow_mesh, null, Transform2D(0.0, Vector2(k, k * 0.8), 0.0, foot + Vector2(up * 0.22, up * 0.04) * cell),
		Color(1, 1, 1, 1.0 - up * 0.35))
	draw_mesh(m, null, Transform2D(p.tilt, p.squash * p.scale, 0.0, foot - Vector2(0.0, p.lift * cell + rest)))

func _foot(c: Vector2) -> Vector2:
	return px(c) + Vector2(0.0, skin.foot_drop() * cell)

func _mesh(type: int, side: int, face: int, look: float, bare := false) -> ArrayMesh:
	var key := "%d|%d|%d|%d|%d" % [type, side, face, 1 if look > 0.0 else 0, 1 if bare else 0]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build(b, type, side, cell, face, look, bare)
		m = b.mesh()
		_meshes[key] = m
	return m

## How an actor stands this frame: its moment if it has one, else at rest.
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
				if a.dropped:
					var p: RefCounted = ChessSkin.Pose.at_cell(a.from.lerp(a.to, ChessSkin._ease_in_out(u)))
					p.lift = 0.3 * (1.0 - u)
					p.squash = Vector2(1.0 + 0.12 * sin(PI * u), 1.0 - 0.12 * sin(PI * u))
					return p
				if Motion.reduce:
					return ChessSkin.Pose.at_cell(a.from.lerp(a.to, u))
				var mp: RefCounted = skin.move_pose(a.move_type, a.from, a.to, u)
				if a.hit_u > 0.0:
					# leaning into the hit, and a little squashed by it
					var bump := exp(-pow((u - a.hit_u) / 0.09, 2.0))
					mp.tilt += signf(a.to.x - a.from.x) * 0.3 * bump
					mp.squash *= Vector2(1.0 + 0.1 * bump, 1.0 - 0.08 * bump)
				return mp
			"back":
				var p: RefCounted = ChessSkin.Pose.at_cell(a.from.lerp(a.to, ChessSkin._ease_in_out(u)))
				p.lift = 0.5 * sin(PI * u)
				p.scale = lerpf(tray_scale, 1.0, u)
				return p
			"knock":
				if Motion.reduce:
					var p: RefCounted = ChessSkin.Pose.at_cell(a.from.lerp(a.to, u))
					p.scale = lerpf(1.0, tray_scale, u)
					return p
				return skin.knock_pose(a.from, a.to, a.dir, u, tray_scale)
			"shiver":
				var p: RefCounted = skin.shiver_pose(a.at, u)
				p.scale = a.rest_scale
				return p
			"tremble":
				return skin.tremble_pose(a.at, u)
			"topple":
				return skin.topple_pose(a.at, u, -1.0 if a.side == 0 else 1.0)
			"cheer":
				return skin.cheer_pose(a.at, u)
			"fidget":
				return skin.fidget_pose(a.type, a.at, u)
			"promote":
				return skin.promote_pose(a.at, u)
			"enter":
				return skin.enter_pose(a.at, u)
	if a.kind == "" and _mood != "" and a.sq == _check_sq_for_mate():
		return skin.topple_pose(a.at, 1.0, -1.0 if a.side == 0 else 1.0)
	if a.sq < 0:
		var p := ChessSkin.Pose.at_cell(a.at)
		p.scale = a.rest_scale
		return p
	var lifted := a.sq == _selected or a.sq == _lifted
	if lifted and _dragging and a.sq == _selected:
		var p := ChessSkin.Pose.at_cell(_drag_cell)
		p.lift = 0.35
		return p
	if Motion.reduce:
		# nothing idles: a picked piece stands up off its square, still
		var still_pose := ChessSkin.Pose.at_cell(a.at)
		still_pose.lift = 0.12 if lifted else 0.0
		return still_pose
	var ip: RefCounted = skin.idle_pose(a.type, a.at, _now, a.phase, lifted)
	if a.sq == _lifted:
		# the computer's "hmm" before it lets go
		ip.tilt += 0.08 * sin(_now * 12.0)
	elif a.side == 1:
		# while it thinks, its pieces look round the board after something
		var env := clampf((_now - _think_at) / 0.4, 0.0, 1.0) if _thinking else 1.0 - clampf((_now - _think_off) / 0.3, 0.0, 1.0)
		if env > 0.0:
			var roam := 3.5 + 3.8 * sin(_now * 0.8 + 1.0)
			ip.tilt += env * clampf((roam - a.at.x) * 0.025, -0.09, 0.09)
	return ip

## The mated king stays over once it has fallen.
var _fallen := -1

func _check_sq_for_mate() -> int:
	return _fallen

func mark_fallen(sq: int) -> void:
	_fallen = sq

func _face_of(a: Actor) -> int:
	if still:
		return ChessSkin.F_OPEN
	if a.face >= 0 and _now < a.face_until:
		return a.face
	if a.sq < 0:
		return ChessSkin.F_SLEEP
	match _mood:
		"won":
			return ChessSkin.F_JOY if a.side == 0 else ChessSkin.F_WORRY
		"lost":
			return ChessSkin.F_JOY if a.side == 1 else ChessSkin.F_WORRY
		"draw":
			return ChessSkin.F_SLEEP
	if a.sq == _check_sq:
		return ChessSkin.F_WORRY
	if a.sq == _selected or a.sq == _lifted:
		return ChessSkin.F_JOY
	if _selected >= 0 and a.side == 1 and _targets.has(a.sq):
		return ChessSkin.F_WORRY
	if _now >= a.blink_at and not Motion.reduce:
		if _now < a.blink_at + skin.blink_time():
			return ChessSkin.F_BLINK
		var gap: Vector2 = skin.blink_gap()
		a.blink_at = _now + _rng.randf_range(gap.x, gap.y)
	return ChessSkin.F_OPEN

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
		# grain along the rim
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
	# grain running round the frame, a line or two a side
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
	# a lit top edge on the frame
	b.stroke(PackedVector2Array([fr.position + Vector2(r, 3), fr.position + Vector2(fr.size.x - r, 3)]), 3.0, Color(1, 1, 1, 0.25))
	# brass pegs in the corners
	for cx: float in [fr.position.x + band * 0.5, fr.end.x - band * 0.5]:
		for cy: float in [fr.position.y + band * 0.5, fr.end.y - band * 0.5]:
			b.disc(Vector2(cx, cy + 2.0), band * 0.2, Color(FRAME_DEEP, 0.8))
			b.disc(Vector2(cx, cy), band * 0.2, BRASS_DEEP)
			b.disc(Vector2(cx, cy - 1.0), band * 0.15, BRASS)
			b.disc(Vector2(cx - band * 0.05, cy - band * 0.06), band * 0.05, Color(1, 1, 1, 0.7))
	# the squares; the dark ones a mown lawn with a lighter stripe, the light
	# ones sandstone flecked a little darker
	for row in 8:
		for col in 8:
			var sq := sq_of(Vector2i(col, row))
			var dark := ((sq & 7) + (sq >> 3)) % 2 == 0
			var at := origin + Vector2(col, row) * cell
			b.fan(_square(at), DARK if dark else LIGHT)
			if dark:
				b.fan(PackedVector2Array([at + Vector2(0, cell * 0.5), at + Vector2(cell, cell * 0.5),
					at + Vector2(cell, cell), at + Vector2(0, cell)]), Color(DARK_DEEP, 0.35))
				for k in 3:
					var tuft := at + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.85)) * cell
					b.stroke(PackedVector2Array([tuft, tuft + Vector2(-0.03, -0.07) * cell]), cell * 0.018, Color(DARK_DEEP, 0.8))
					b.stroke(PackedVector2Array([tuft, tuft + Vector2(0.03, -0.06) * cell]), cell * 0.018, Color(DARK_DEEP, 0.8))
			else:
				b.fan(PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell * 0.06), at + Vector2(0, cell * 0.06)]),
					Color(1, 1, 1, 0.25))
				for k in 4:
					var q := at + Vector2(rng.randf_range(0.12, 0.88), rng.randf_range(0.15, 0.88)) * cell
					b.ellipse(q, cell * rng.randf_range(0.02, 0.04), cell * rng.randf_range(0.012, 0.025), Color(0.62, 0.5, 0.33, 0.14))
	# the frame's inner edge shades the first row and column of squares
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

## "+3" on a little paper tag at the end of the tray of whoever is ahead
## on material.
func _draw_advantage() -> void:
	if rules == null or _font == null or still:
		return
	var me: int = rules.material(player)
	var them: int = rules.material(1 - player)
	if me == them:
		return
	var tray := 0 if me > them else 1
	var fs := int(cell * 0.28)
	var n: int = _trays[tray].size()
	var text := "+%d" % absi(me - them)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := origin.x + (0.45 + n * tray_step) * cell - cell * 0.05
	var mid := _tray_mid(tray)
	var tag := Rect2(Vector2(x, mid - fs * 0.62), Vector2(w + fs * 0.7, fs * 1.24))
	draw_rect(Rect2(tag.position + Vector2(0, 3), tag.size), Color(SOIL_DEEP, 0.6))
	draw_rect(tag, Pal.PAPER)
	draw_string(_font, Vector2(tag.position.x + fs * 0.35, mid + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)

func _build_marks() -> ArrayMesh:
	# null when there is nothing to mark: an empty mesh is an error.
	var b := Face.Builder.new()
	if _last.x >= 0:
		# where it came from, faintly; where it went, warmly; and a trail of
		# footprints between, round the corner of a knight's L
		var at := origin + cell_of(_last.x) * cell
		b.fan(_square(at), Color(MARK_LAST, 0.2))
		b.stroke(Face.Builder.round_rect(at + Vector2.ONE * cell * 0.08, Vector2.ONE * cell * 0.84, cell * 0.14),
			cell * 0.03, Color(MARK_LAST, 0.7), true)
		b.fan(_square(origin + cell_of(_last.y) * cell), MARK_LAST)
		var p0 := cell_of(_last.x)
		var p1 := cell_of(_last.y)
		var path := [p0, p1]
		if rules != null and absi(rules.board[_last.y]) == Rules.KNIGHT and _at_sq.has(_last.y):
			var d := p1 - p0
			path = [p0, p0 + (Vector2(d.x, 0.0) if absf(d.x) > absf(d.y) else Vector2(0.0, d.y)), p1]
		var walked := 0.0
		for i in path.size() - 1:
			var seg_a: Vector2 = path[i]
			var seg_b: Vector2 = path[i + 1]
			var n := int(seg_a.distance_to(seg_b) / 0.26)
			for k in n + 1:
				var q := seg_a.lerp(seg_b, float(k) / maxf(n, 1))
				walked += 0.26
				if q.distance_to(p0) < 0.42 or q.distance_to(p1) < 0.42:
					continue
				var side := (seg_b - seg_a).normalized().orthogonal() * (0.06 if k % 2 == 0 else -0.06)
				b.ellipse(px(q + side), cell * 0.045, cell * 0.035, Color(0.8, 0.55, 0.2, 0.42))
	if _selected >= 0:
		b.fan(_square(origin + cell_of(_selected) * cell), MARK_PICK)
	if _hover >= 0:
		b.fan(_square(origin + cell_of(_hover) * cell), Color(MARK_PICK, 0.35))
	return null if b.verts.is_empty() else b.mesh()

func _square(at: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)])

# --- the live layers ---

## Under the pieces: the picked piece's ring and its moves popping in and
## out, the hint's arrow drawing itself, landing ripples, the check's
## attack line, a slider's speed lines and a promotion's rays.
func _build_under() -> ArrayMesh:
	var b := Face.Builder.new()
	var reduce := Motion.reduce
	if _selected >= 0:
		var c := px(cell_of(_selected))
		var s := 1.0 if reduce else ChessSkin._back_out_k(clampf((_now - _select_at) / 0.2, 0.0, 1.0))
		var w := cell * (0.05 + (0.0 if reduce else 0.012 * sin(_now * 5.0)))
		b.stroke(Face.Builder.ring(c, cell * 0.47 * s, cell * 0.47 * s), w, Color(Pal.SUN, 0.85), true)
		_target_marks(b, _targets, _selected, _select_at, true)
	if not _gone.is_empty():
		if reduce or _now - _gone_at > 0.4:
			_gone = {}
		else:
			_target_marks(b, _gone, _gone_from, _gone_at, false)
	if _hint.x >= 0:
		var a := px(cell_of(_hint.x))
		var z := px(cell_of(_hint.y))
		var dir := (z - a).normalized()
		var tip := z - dir * cell * 0.2
		var p := 1.0 if reduce else clampf((_now - _hint_at) / 0.4, 0.0, 1.0)
		var glow := 0.8 if reduce else 0.8 + 0.15 * sin(_now * 4.0)
		var start := a + dir * cell * 0.25
		var end := tip - dir * cell * 0.22
		b.stroke(PackedVector2Array([start, start.lerp(end, ChessSkin._ease_in_out(p))]), cell * 0.13, Color(HINT, 0.75 * glow))
		var head := ChessSkin._back_out_k(clampf((p - 0.6) / 0.4, 0.0, 1.0))
		if head > 0.01:
			var side := Vector2(-dir.y, dir.x) * head
			var back := tip - dir * cell * 0.34 * head
			b.fan(PackedVector2Array([tip, back + side * cell * 0.22, back - side * cell * 0.22]), Color(HINT, 0.85 * glow))
		b.stroke(Face.Builder.ring(a, cell * 0.44, cell * 0.44), cell * 0.06, Color(HINT, 0.8 * glow), true)
	var keep: Array = []
	for r: Array in _ripples:
		var t := (_now - float(r[1])) / RIPPLE_TIME
		if t >= 1.0:
			continue
		keep.append(r)
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		var rx := cell * (0.26 + 0.34 * e) * float(r[2])
		b.stroke(Face.Builder.ring(_foot(r[0]), rx, rx * 0.36), cell * 0.035 * (1.0 - t) + 1.0, Color(1, 1, 1, 0.6 * (1.0 - t)), true)
	_ripples = keep
	if _check_sq >= 0 and not reduce:
		var u := (_now - _check_at) / ATTACK_TIME
		if u < 1.0:
			var z := px(cell_of(_check_sq))
			for from in _check_from:
				var a := px(cell_of(from))
				_dashes(b, a, z, cell * 0.07, Color(Pal.BAD, 0.85 * (1.0 - u)), _now * cell * 1.2)
	if not reduce:
		for a: Actor in _actors:
			if a.kind == "move" and not a.dropped and a.move_type in [Rules.BISHOP, Rules.ROOK, Rules.QUEEN] and _now >= a.t0:
				_speed_lines(b, a)
			elif a.kind == "promote" and _now >= a.t0:
				var u := clampf((_now - a.t0) / a.dur, 0.0, 1.0)
				var c := _foot(a.at) - Vector2(0.0, cell * 0.45)
				var len := cell * 0.75 * sin(PI * u)
				for k in 10:
					var ang := TAU * float(k) / 10.0 + _now * 1.5
					var d := Vector2.from_angle(ang)
					var o := d.orthogonal() * cell * 0.05
					b.fan(PackedVector2Array([c + d * cell * 0.2 + o, c + d * (cell * 0.2 + len), c + d * cell * 0.2 - o]),
						Color(Pal.SUN_RAY, 0.55 * sin(PI * u)))
	return null if b.verts.is_empty() else b.mesh()

## The moves from `from` as they pop in (`coming`) or back out, a step a
## square out from the piece.
func _target_marks(b: Face.Builder, targets: Dictionary, from: int, since: float, coming: bool) -> void:
	var fc := cell_of(from)
	for sq: int in targets:
		var tc := cell_of(sq)
		var dist := maxf(absf(tc.x - fc.x), absf(tc.y - fc.y))
		var s := 1.0
		if Motion.reduce:
			s = 1.0 if coming else 0.0
		elif coming:
			s = ChessSkin._back_out_k(clampf((_now - since - dist * MARK_STEP) / MARK_POP, 0.0, 1.0))
		else:
			s = 1.0 - clampf((_now - since - dist * 0.02) / 0.14, 0.0, 1.0)
		if s <= 0.01:
			continue
		var c := px(tc)
		var takes: bool = _at_sq.has(sq) and _at_sq[sq].side == 1
		if takes or (rules != null and sq == rules.ep and from >= 0 and absi(rules.board[from]) == Rules.PAWN):
			# a rose ring of dashes turning slowly round what it would take
			var r := cell * 0.43 * s
			for k in 10:
				var a0 := TAU * float(k) / 10.0 + (0.0 if Motion.reduce else _now * 0.7)
				b.stroke(Face.Builder.arc_points(c, r, a0, a0 + TAU / 10.0 * 0.6), cell * 0.065, Color(Pal.BAD, 0.6))
		else:
			# a seed: a soft dark pip with a glint
			b.disc(c, cell * 0.14 * s, MARK_DOT)
			b.disc(c + Vector2(-0.035, -0.035) * cell * s, cell * 0.045 * s, Color(1, 1, 1, 0.22))

## A dashed line from `a` to `z`, the dashes marching along it by `shift`.
func _dashes(b: Face.Builder, a: Vector2, z: Vector2, width: float, colour: Color, shift: float) -> void:
	var dir := (z - a).normalized()
	var total := a.distance_to(z) - cell * 0.35
	var step := cell * 0.24
	var d := fmod(shift, step) + cell * 0.2
	while d < total:
		var e := minf(d + step * 0.55, total)
		b.stroke(PackedVector2Array([a + dir * d, a + dir * e]), width, colour)
		d += step

## Three soft lines streaming behind a piece gliding along the ground,
## side by side across the way it goes.
func _speed_lines(b: Face.Builder, a: Actor) -> void:
	var u := clampf((_now - a.t0) / a.dur, 0.0, 1.0)
	if u <= 0.02 or u >= 0.98:
		return
	var across := (a.to - a.from).normalized().orthogonal()
	for h: float in [-0.17, 0.0, 0.17]:
		var prev := Vector2.INF
		var lift := 0.42 - absf(h)
		for k in 8:
			var uu := u - float(k) * 0.035
			if uu < 0.0:
				break
			var pose: RefCounted = skin.move_pose(a.move_type, a.from, a.to, uu)
			var q := _foot(pose.at) + (across * h - Vector2(0.0, pose.lift + lift)) * cell
			if prev != Vector2.INF:
				var f := 1.0 - float(k) / 8.0
				b.stroke(PackedVector2Array([prev, q]), cell * 0.05 * f + 0.5, Color(1, 1, 1, 0.75 * f * sin(PI * u)))
			prev = q

## Over the pieces: the capture's impact star, a knocked piece's dizzy
## stars, the sleepers' z's, the check's "!" and sweat, the computer's
## thought bubble and the win's petals.
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
		var r := cell * (0.2 + 0.38 * e)
		_star(b, im[0], r, r * 0.42, 8, t * 0.8, Color(1, 1, 1, 0.95 * (1.0 - t)))
		_star(b, im[0], r * 0.55, r * 0.25, 8, 0.4 - t * 0.8, Color(Pal.SUN_RAY, 0.9 * (1.0 - t)))
	_impacts = keep
	var rose_king: Array = []
	for e: Array in poses:
		var a: Actor = e[1]
		var p = e[2]
		var head := _foot(p.at) - Vector2(0.0, (p.lift + 0.45 * p.scale) * cell)
		if a.kind == "knock" and not reduce:
			for i in 3:
				var ang := _now * 7.0 + TAU * float(i) / 3.0
				var q: Vector2 = head + Vector2(cos(ang) * 0.28, sin(ang) * 0.1) * cell * p.scale
				_star(b, q, cell * 0.08 * p.scale, cell * 0.035 * p.scale, 5, _now * 3.0, Pal.SUN_RAY)
		elif not reduce and a.kind == "" and (a.sq < 0 or (_mood == "draw" and a.phase < 0.4)):
			_zzz(b, a, p)
		if a.type == Rules.KING and a.side == 1 and a.sq >= 0:
			rose_king = [a, p]
		if a.sq == _check_sq and _check_sq >= 0 and _mood == "":
			var pop := 1.0 if reduce else ChessSkin._back_out_k(clampf((_now - _check_at) / 0.25, 0.0, 1.0))
			var bob := 0.0 if reduce else 0.04 * sin(_now * 6.0)
			var top := _foot(p.at) - Vector2(0.0, (p.lift + 1.42 + bob) * cell)
			var r := cell * 0.17 * pop
			b.disc(top + Vector2(0.0, cell * 0.02), r * 1.08, Color(Pal.TEXT, 0.25))
			b.disc(top, r, Pal.BAD)
			b.stroke(PackedVector2Array([top + Vector2(0.0, -0.09) * cell * pop, top + Vector2(0.0, 0.02) * cell * pop]),
				cell * 0.055 * pop, Pal.PAPER)
			b.disc(top + Vector2(0.0, 0.075) * cell * pop, cell * 0.03 * pop, Pal.PAPER)
			if not reduce:
				# a bead of sweat sliding down beside the face
				var t := fmod(_now / 1.1, 1.0)
				var dp := _foot(p.at) + Vector2(0.27 * cell, -(p.lift + 0.85 - 0.25 * t) * cell)
				var a_alpha := sin(PI * t)
				var drop := PackedVector2Array()
				for k in 12:
					var ang := TAU * float(k) / 12.0
					var rr := cell * 0.05 * (1.0 + 0.6 * maxf(0.0, -sin(ang)))
					drop.append(dp + Vector2(cos(ang) * cell * 0.045, sin(ang) * rr))
				b.polygon(drop, Color(SWEAT, a_alpha))
				b.disc(dp + Vector2(-0.012, 0.0) * cell, cell * 0.014, Color(1, 1, 1, 0.8 * a_alpha))
	if not rose_king.is_empty() and _mood == "":
		var env := clampf((_now - _think_at) / 0.3, 0.0, 1.0) if _thinking else 1.0 - clampf((_now - _think_off) / 0.2, 0.0, 1.0)
		if env > 0.0:
			var p = rose_king[1]
			var at := _foot(p.at) + Vector2(0.42 * cell, -(p.lift + 1.3) * cell)
			if at.y < origin.y - FRAME * cell:
				at.y += cell * 0.5
			var s := env
			b.disc(at + Vector2(-0.3, 0.3) * cell, cell * 0.045 * s, Color(Pal.PAPER, 0.95))
			b.disc(at + Vector2(-0.2, 0.2) * cell, cell * 0.065 * s, Color(Pal.PAPER, 0.95))
			for q: Vector3 in [Vector3(-0.14, 0.0, 0.14), Vector3(0.0, -0.05, 0.17), Vector3(0.14, 0.0, 0.14), Vector3(0.0, 0.06, 0.15)]:
				b.disc(at + Vector2(q.x, q.y) * cell * s + Vector2(0, cell * 0.02), cell * q.z * s, Color(Pal.TEXT, 0.12))
			for q: Vector3 in [Vector3(-0.14, 0.0, 0.14), Vector3(0.0, -0.05, 0.17), Vector3(0.14, 0.0, 0.14), Vector3(0.0, 0.06, 0.15)]:
				b.disc(at + Vector2(q.x, q.y) * cell * s, cell * q.z * s, Pal.PAPER)
			for k in 3:
				var lit := 0.0 if reduce else maxf(0.0, sin(_now * 5.0 - float(k) * 0.9))
				b.disc(at + Vector2((float(k) - 1.0) * 0.1, -0.01 - 0.03 * lit) * cell * s, cell * 0.032 * s,
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
	var c := _foot(p.at) + Vector2((0.22 + 0.14 * v) * sc * cell, -(0.8 * p.scale + 0.45 * v * sc) * cell)
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

func _draw_picker() -> void:
	var cells := _picker_cells()
	if cells.is_empty():
		return
	var top := origin + (cells[0] as Vector2) * cell
	var rect := Rect2(top - Vector2(0.06, 0.06) * cell, Vector2(1.12, cells.size() + 0.12) * cell)
	var box := StyleBoxFlat.new()
	box.bg_color = Pal.SURFACE
	box.set_corner_radius_all(int(cell * 0.2))
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = int(cell * 0.12)
	box.shadow_offset = Vector2(0, cell * 0.06)
	box.border_color = Pal.SUN
	box.set_border_width_all(4)
	draw_style_box(box, rect)
	for i in cells.size():
		var type := Rules.mv_promo(_picker[i])
		var mesh := _mesh(type, 0, ChessSkin.F_JOY, 1.0)
		var bob := 0.03 * sin(_now * 5.0 + i)
		draw_mesh(mesh, null, Transform2D(0.0, Vector2.ONE * 0.8, 0.0, _foot(cells[i]) - Vector2(0, (0.12 + bob) * cell)))
