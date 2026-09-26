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

## In cells: the tray strip above and below, the wooden frame, the gap
## between two taken pieces and how small a taken piece stands.
const TRAY := 0.66
const FRAME := 0.3
const TRAY_STEP := 0.44
const TRAY_SCALE := 0.5
const DRAG_START := 14.0

const LIGHT := Color("f5e9cf")
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

var rules: RefCounted
var skin: RefCounted = ChessSkin.named("garden")
## The colour the player moves (Rules.WHITE or BLACK); their pieces are
## always the cream ones and always at the bottom.
var player := Rules.WHITE
var interactive := false
## The tab's picture: drawn once, no clock, no touch.
var still := false

var cell := 100.0
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
	_check_sq = sq
	queue_redraw()

func set_hint(move: int) -> void:
	_hint = Vector2i(-1, -1) if move < 0 else Vector2i(Rules.mv_from(move), Rules.mv_to(move))
	_marks_dirty = true
	if move >= 0 and _fx != null:
		_fx.ring(px(cell_of(_hint.x)), cell * 0.5, HINT)
		_fx.sparkle(px(cell_of(_hint.x)), HINT)

func set_lifted(sq: int) -> void:
	_lifted = sq

func deselect() -> void:
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
	var mid_y: float
	if tray == 0:
		mid_y = origin.y + (8.0 + FRAME + TRAY * 0.5) * cell
	else:
		mid_y = origin.y - (FRAME + TRAY * 0.5) * cell
	var foot := Vector2(origin.x + (0.45 + slot * TRAY_STEP) * cell, mid_y + 0.2 * cell)
	return cell_at(foot - Vector2(0.0, skin.foot_drop() * cell))

func frame_rect() -> Rect2:
	return Rect2(origin - Vector2.ONE * FRAME * cell, Vector2.ONE * (8.0 + 2.0 * FRAME) * cell)

func _layout() -> void:
	var across := 8.0 + 2.0 * FRAME
	var down := across + 2.0 * TRAY
	var c := floorf(minf(size.x / across, size.y / down))
	if c <= 0.0:
		return
	if c != cell:
		_meshes.clear()
	cell = c
	var used := Vector2(across, down) * cell
	var corner := ((size - used) * 0.5).floor()
	used_rect = Rect2(corner, used)
	origin = corner + Vector2(FRAME, FRAME + TRAY) * cell
	for a: Actor in _actors:
		if a.sq >= 0:
			a.at = cell_of(a.sq)
	for t in 2:
		for i in _trays[t].size():
			_trays[t][i].at = tray_cell(t, i)
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
	if int(d.captured) != 0:
		var victim: Actor = _at_sq.get(int(d.captured_at))
		if victim != null:
			_at_sq.erase(int(d.captured_at))
			_knock(victim, to_c - start, contact)
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
			_puff(to_c))
	if int(d.promo) != 0:
		var pt: float = skin.promote_time()
		_after(dur, func() -> void:
			a.move_type = a.type
			_start(a, "promote", 0.2 if reduce else pt, a.to, a.to)
			_cue("promote"))
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
func _knock(victim: Actor, dir: Vector2, contact: float) -> void:
	var tray := 0 if victim.side == 1 else 1
	var slot: int = _trays[tray].size()
	_trays[tray].append(victim)
	victim.sq = -1
	var target := tray_cell(tray, slot)
	_after(contact, func() -> void:
		_start(victim, "knock", 0.25 if Motion.reduce else skin.knock_time(), victim.at, target)
		victim.dir = dir
		victim.rest_scale = TRAY_SCALE
		victim.face = ChessSkin.F_DIZZY
		victim.face_until = INF
		_cue("capture", _rng.randf_range(0.95, 1.05))
		if _fx != null:
			var hit := px(victim.at)
			_fx.ring(hit, cell * 0.35, Color(Pal.PAPER, 0.9), 0.35)
			_fx.puff(hit, Pal.SUN_RAY, 6))

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
	if outcome == "draw":
		return
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
		var pulse := 0.65 + 0.35 * sin(_now * 5.0)
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
	if _shadow_mesh == null:
		var sb := Face.Builder.new()
		var ss: Vector2 = skin.shadow_size()
		Scenery.soft_disc(sb, Vector2.ZERO, cell * ss.x, cell * ss.y, Color(Pal.TEXT, 0.24))
		_shadow_mesh = sb.mesh()
	for e: Array in poses:
		var pose = e[2]
		var up := clampf(pose.lift, 0.0, 2.0)
		var k: float = pose.scale * (1.0 - up * 0.25)
		draw_mesh(_shadow_mesh, null, Transform2D(0.0, Vector2(k, k), 0.0, _foot(pose.at) + Vector2(up * 0.12, 0.0) * cell),
			Color(1, 1, 1, pose.alpha * (1.0 - up * 0.35)))
	for e: Array in poses:
		var a: Actor = e[1]
		var pose = e[2]
		var look: float = pose.look if pose.look != 0.0 else a.look
		var mesh := _mesh(a.type, a.side, _face_of(a), look)
		var xf := Transform2D(pose.tilt, pose.squash * pose.scale, 0.0, _foot(pose.at) - Vector2(0.0, pose.lift * cell))
		draw_mesh(mesh, null, xf, Color(1, 1, 1, pose.alpha))
	_draw_picker()
	_draw_advantage()

func _foot(c: Vector2) -> Vector2:
	return px(c) + Vector2(0.0, skin.foot_drop() * cell)

func _mesh(type: int, side: int, face: int, look: float) -> ArrayMesh:
	var key := "%d|%d|%d|%d" % [type, side, face, 1 if look > 0.0 else 0]
	var m: ArrayMesh = _meshes.get(key)
	if m == null:
		var b := Face.Builder.new()
		skin.build(b, type, side, cell, face, look)
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
				return mp
			"back":
				var p: RefCounted = ChessSkin.Pose.at_cell(a.from.lerp(a.to, ChessSkin._ease_in_out(u)))
				p.lift = 0.5 * sin(PI * u)
				p.scale = lerpf(TRAY_SCALE, 1.0, u)
				return p
			"knock":
				if Motion.reduce:
					var p: RefCounted = ChessSkin.Pose.at_cell(a.from.lerp(a.to, u))
					p.scale = lerpf(1.0, TRAY_SCALE, u)
					return p
				return skin.knock_pose(a.from, a.to, a.dir, u, TRAY_SCALE)
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
	return skin.idle_pose(a.type, a.at, _now, a.phase, lifted)

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
	if _now >= a.blink_at:
		if _now < a.blink_at + skin.blink_time():
			return ChessSkin.F_BLINK
		var gap: Vector2 = skin.blink_gap()
		a.blink_at = _now + _rng.randf_range(gap.x, gap.y)
	return ChessSkin.F_OPEN

func _build_board() -> ArrayMesh:
	var b := Face.Builder.new()
	var fr := frame_rect()
	var r := cell * 0.22
	# the trays: long troughs above and below
	for t in 2:
		var y := origin.y + (8.0 + FRAME + 0.08) * cell if t == 0 else origin.y - (FRAME + TRAY - 0.08) * cell
		var tr := Rect2(Vector2(fr.position.x + 0.1 * cell, y), Vector2(fr.size.x - 0.2 * cell, (TRAY - 0.16) * cell))
		b.fan(Face.Builder.round_rect(tr.position + Vector2(0, 4), tr.size, r), Color(TROUGH_DEEP, 0.5))
		b.fan(Face.Builder.round_rect(tr.position, tr.size, r), TROUGH)
		b.fan(Face.Builder.round_rect(tr.position + Vector2(6, 6), tr.size - Vector2(12, 10), r * 0.8), Color(TROUGH_DEEP, 0.35))
	# the frame: a soft drop shadow, the deep edge, the face, the lip
	Scenery.soft_disc(b, fr.get_center() + Vector2(0, cell * 0.2), fr.size.x * 0.62, fr.size.y * 0.6, Color(0.2, 0.1, 0.04, 0.18))
	b.fan(Face.Builder.round_rect(fr.position + Vector2(0, 8), fr.size, r), FRAME_DEEP)
	b.fan(Face.Builder.round_rect(fr.position, fr.size, r), FRAME_COL)
	var inner := Rect2(origin - Vector2.ONE * 5.0, Vector2.ONE * 8.0 * cell + Vector2.ONE * 10.0)
	b.fan(Face.Builder.round_rect(inner.position, inner.size, 6.0), FRAME_LIP)
	# a lit top edge on the frame
	b.stroke(PackedVector2Array([fr.position + Vector2(r, 3), fr.position + Vector2(fr.size.x - r, 3)]), 3.0, Color(1, 1, 1, 0.25))
	# the squares; the dark ones a mown lawn with a lighter stripe
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for row in 8:
		for col in 8:
			var sq := sq_of(Vector2i(col, row))
			var dark := ((sq & 7) + (sq >> 3)) % 2 == 0
			var at := origin + Vector2(col, row) * cell
			var rect := PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)])
			b.fan(rect, DARK if dark else LIGHT)
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

## "+3" beside the tray of whoever is ahead on material.
func _draw_advantage() -> void:
	if rules == null or _font == null or still:
		return
	var me: int = rules.material(player)
	var them: int = rules.material(1 - player)
	if me == them:
		return
	var tray := 0 if me > them else 1
	var fs := int(cell * 0.3)
	var n: int = _trays[tray].size()
	var x := origin.x + (0.45 + n * TRAY_STEP + 0.05) * cell
	var mid_y := origin.y + (8.0 + FRAME + TRAY * 0.5) * cell if tray == 0 else origin.y - (FRAME + TRAY * 0.5) * cell
	draw_string(_font, Vector2(x, mid_y + fs * 0.36), "+%d" % absi(me - them), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.PAPER, 0.95))

func _build_marks() -> ArrayMesh:
	# null when there is nothing to mark: an empty mesh is an error.
	var b := Face.Builder.new()
	for sq in [_last.x, _last.y]:
		if sq >= 0:
			var at := origin + cell_of(sq) * cell
			b.fan(PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)]), MARK_LAST)
	if _selected >= 0:
		var at := origin + cell_of(_selected) * cell
		b.fan(PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)]), MARK_PICK)
	for sq: int in _targets:
		var c := px(cell_of(sq))
		if sq == _hover:
			var at := origin + cell_of(sq) * cell
			b.fan(PackedVector2Array([at, at + Vector2(cell, 0), at + Vector2(cell, cell), at + Vector2(0, cell)]), Color(MARK_PICK, 0.35))
		if _at_sq.has(sq) or (rules != null and sq == rules.ep and _selected >= 0 and absi(rules.board[_selected]) == Rules.PAWN):
			b.stroke(Face.Builder.ring(c, cell * 0.43, cell * 0.43), cell * 0.07, Color(Pal.BAD, 0.45), true)
		else:
			b.disc(c, cell * 0.15, MARK_DOT)
	if _hint.x >= 0:
		var a := px(cell_of(_hint.x))
		var z := px(cell_of(_hint.y))
		var dir := (z - a).normalized()
		var tip := z - dir * cell * 0.2
		b.stroke(PackedVector2Array([a + dir * cell * 0.25, tip - dir * cell * 0.22]), cell * 0.13, Color(HINT, 0.75))
		var side := Vector2(-dir.y, dir.x)
		b.fan(PackedVector2Array([tip, tip - dir * cell * 0.34 + side * cell * 0.22, tip - dir * cell * 0.34 - side * cell * 0.22]), Color(HINT, 0.85))
		b.stroke(Face.Builder.ring(a, cell * 0.44, cell * 0.44), cell * 0.06, Color(HINT, 0.8), true)
	return null if b.verts.is_empty() else b.mesh()

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
