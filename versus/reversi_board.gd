extends Control

## Reversi's board, seen from straight above as it lies on the deck: a painted
## blue tray of eight squares by eight in a wooden frame, and discs with two
## faces. The player's face is the sun's (cream, a sun stamped on it), the
## other player's the moon's (night blue, a crescent stamped on it), whichever
## of them moves first; a disc's edge shows the face underneath.
##
## While it is the player's turn every square that may be played carries a
## small dot. A finger on a square frames it and rings the discs it would
## turn, since the thumb hides the square it is on; letting go sets the disc
## there. The disc lands, and the runs it shut turn over one after another
## outwards from it.
##
## Everything that does not move is one baked mesh. A disc is one cached mesh
## a face, drawn under a transform wherever it lies and squashed across to
## turn it over. What changes shape (the dots, the frame under the finger, the
## rings, the tally under the board) is one small mesh rebuilt only while
## something moves.
##
## The board shows what it has been told (`play`, `sync`), not the rules it
## was set up from, so a disc is turned only once its move has been shown.

## The player let go over a square that may be played.
signal chosen(cell: int)
## What was being shown has finished: the board is set, a move's discs have
## turned, a move taken back is off.
signal settled
## The square let go over may not be played: "taken" or "none".
signal refused(reason: String)

const Rules = preload("res://versus/reversi_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A square's side in the meshes' own space, whose origin is the top left of
## the squares.
const U := 100.0
const GRID := Vector2(Rules.W * U, Rules.W * U)
const FRAME := 34.0
const DISC_R := 40.0
## The tally under the board: its top, its height.
const TALLY_Y := 866.0
const TALLY_H := 22.0
## The space the board takes, alone and with the room over it (the screen's
## line of words) and the tally under it.
const SPACE := Rect2(-FRAME - 6.0, -FRAME - 6.0, GRID.x + 2.0 * FRAME + 12.0, GRID.y + 2.0 * FRAME + 22.0)
const SPACE_TALLY := Rect2(-FRAME - 6.0, -FRAME - 96.0, GRID.x + 2.0 * FRAME + 12.0, GRID.y + 2.0 * FRAME + 96.0 + 76.0)

const FIELD := Color("5f93cf")
const FIELD_LIT := Color("6ea2da")
const LINE := Color("47739f")
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
## A disc's face, the ring raised on it, its shine and its stamp, by look: the
## sun's, the moon's.
const DISC := [Color("fbf1dc"), Color("2c3768")]
const RING := [Color("e6d4ae"), Color("3e4b86")]
const SHINE := [Color("ffffff"), Color("6f7fc4")]
const STAMP := [Color("e9a826"), Color("aab8ee")]
const HALO := Color("fff6e0")
const HINT := Color("f9c04a")

## Seconds: a disc landing, a disc turning over, the wait between one ring of
## turning discs and the next, the look at a move before the game goes on, a
## move taken back, the board cleared.
const POP := 0.2
const FLIP := 0.34
const STEP := 0.085
const WATCH := 0.22
const REWIND := 0.3
const SWEEP := 0.5

## The notches at play (docs/agents/sound.md, rule 2). A notch is never the
## same sound twice: `place`, `lift` and `refused` are played 0.94 to 1.06 at
## random (they were 1.0 every time). `flip` is played once a ring of discs
## turned, half a step higher a ring from FLIP_PITCH.x, and the whole run of
## a move is moved by one such draw, so it still climbs: 0.893 to 1.185 at
## the widest, 4.9 semitones. It was `0.92 + 0.045 * k` with no variation,
## 4.5 semitones over seven rings, which the variation would take to 6.5.
const TICK_VARY := Vector2(0.94, 1.06)
const VARIED := ["place", "lift", "refused"]
const FLIP_PITCH := Vector2(0.95, 0.028)

var rules: RefCounted
## The rules' side the player is: its face is the sun's.
var player := 0
var interactive := false:
	set(v):
		interactive = v
		queue_redraw()
## A picture, not a game (the Versus tab's card): drawn when asked, no input,
## no tally, as wide as the control.
var still := false
## Whether the tally under the board is drawn (not on a tutorial page).
var tally := true
## A tutorial page's board: it moves as a game's does, but hears no finger
## and makes no sound.
var deaf := false
## The rectangle the board takes.
var used_rect := Rect2()

var _xf := Transform2D.IDENTITY
var _base: ArrayMesh
var _disc: Array[ArrayMesh] = []
var _over_mesh: ArrayMesh
var _shown: Array = []
var _fx: Node2D
var _run := 0
var _t := 0.0
var _busy_until := 0.0
## What lies on each square as shown: 0 empty, else a look plus one.
var _cells := PackedByteArray()
## Discs turning over: cell -> {from: the look it shows first, at: when}.
var _turning := {}
## Discs landing: cell -> when.
var _pop := {}
## Discs going off the board: {cell, look, at}.
var _gone: Array[Dictionary] = []
## The square under the finger (-1 none), and whether a finger is down.
var _over := -1
var _down := false
var _hint := -1
## The square the other player has chosen and not yet played.
var _lifted := -1
var _last := -1
var _shake_at := -10.0
var _shake_cell := -1
## How the game ended, "" while it is on.
var _mood := ""
## The sun's share of the tally as drawn.
var _share := 0.5

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still or deaf else Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if not still and not deaf:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## A board showing `the_rules` as they stand, the player being `side`. With
## `enter`, whatever lay on the board before is swept off first, and `settled`
## is said once the opening's discs are down.
func setup(the_rules: RefCounted, side: int, enter := false) -> void:
	_run += 1
	var old := _cells
	rules = the_rules
	player = side
	_cells = PackedByteArray()
	_cells.resize(Rules.CELLS)
	for c in Rules.CELLS:
		if rules.cells[c] != Rules.EMPTY:
			_cells[c] = look_of(rules.cells[c] - 1) + 1
	_turning = {}
	_pop = {}
	_gone.clear()
	_over = -1
	_down = false
	_hint = -1
	_lifted = -1
	_last = -1
	_mood = ""
	_share = _want_share()
	var wait := 0.0
	if enter and not Motion.reduce:
		if old.size() == Rules.CELLS and old != _cells:
			for c in Rules.CELLS:
				if old[c] != 0:
					_gone.append({"cell": c, "look": old[c] - 1, "at": _t + 0.022 * (c % Rules.W + c / Rules.W)})
			if not _gone.is_empty():
				_cue("sweep")
				wait = SWEEP
		for c in Rules.CELLS:
			if _cells[c] != 0:
				_pop[c] = _t + wait + 0.06 * _pop.size()
		wait += 0.24 + POP
	if enter:
		_after(wait + 0.05, func() -> void: settled.emit())
	_busy(wait + 0.4)
	queue_redraw()

## The look of a rules' side: 0 the sun's (the player's), 1 the moon's.
func look_of(side: int) -> int:
	return 0 if side == player else 1

## The middle of a square, in the meshes' space.
static func mid(c: int) -> Vector2:
	return Vector2((c % Rules.W + 0.5) * U, (c / Rules.W + 0.5) * U)

## A point of the meshes' space, in the board's own.
func point_of(p: Vector2) -> Vector2:
	return _xf * p

## Where a line of words can stand without hiding a square: over the board.
func toast_point() -> Vector2:
	return _xf * Vector2(GRID.x * 0.5, -FRAME - 48.0)

# --- what the screen tells it ---

## The disc of the rules' `side` is set on `cell` and turns `turned` over,
## the nearest first.
func play(cell: int, turned: PackedInt32Array, side: int) -> void:
	var look := look_of(side)
	_hint = -1
	_lifted = -1
	_over = -1
	_down = false
	_cells[cell] = look + 1
	_last = cell
	if Motion.reduce:
		for q in turned:
			_cells[q] = look + 1
		_cue("place")
		_share = _want_share()
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		queue_redraw()
		return
	_cue("place")
	_pop[cell] = _t
	# The runs turn outwards from the disc, a ring of squares at a time.
	var far := 0
	for q in turned:
		var ring := maxi(absi(q % Rules.W - cell % Rules.W), absi(q / Rules.W - cell / Rules.W))
		far = maxi(far, ring)
		_turning[q] = {"from": _cells[q] - 1, "at": _t + POP * 0.6 + STEP * (ring - 1)}
		_cells[q] = look + 1
	var vary := randf_range(TICK_VARY.x, TICK_VARY.y)
	for ring in far:
		var k: int = ring
		_after(POP * 0.6 + STEP * k + FLIP * 0.5, func() -> void: _cue("flip", (FLIP_PITCH.x + FLIP_PITCH.y * k) * vary, -3.0 + 0.5 * k))
	var total := POP * 0.6 + STEP * (far - 1) + FLIP
	_busy(total + WATCH + 0.3)
	_after(total + WATCH, func() -> void: settled.emit())

## The board is made to show the rules as they now stand (a move taken back):
## a disc no longer there goes off, a disc turned turns back.
func sync() -> void:
	_hint = -1
	_lifted = -1
	_last = -1
	if not rules.history.is_empty():
		_last = rules.history[rules.history.size() - 1][0]
	var changed := false
	for c in Rules.CELLS:
		var want: int = 0 if rules.cells[c] == Rules.EMPTY else look_of(rules.cells[c] - 1) + 1
		if _cells[c] == want:
			continue
		changed = true
		if not Motion.reduce:
			if want == 0:
				_gone.append({"cell": c, "look": _cells[c] - 1, "at": _t})
			elif _cells[c] != 0:
				_turning[c] = {"from": _cells[c] - 1, "at": _t}
			else:
				_pop[c] = _t
		_cells[c] = want
	if changed:
		_cue("lift")
	_busy(REWIND + 0.4)
	_after(Motion.REDUCED_TIME if Motion.reduce else REWIND + 0.1, func() -> void: settled.emit())
	queue_redraw()

## The bulb's square, -1 for none.
func set_hint(cell: int) -> void:
	_hint = cell
	_busy(0.2)
	queue_redraw()

## The other player has chosen `cell`: it is ringed until the disc is down.
func set_lifted(cell: int) -> void:
	_lifted = cell
	_busy(0.3)
	queue_redraw()

## The game is over: the winner's discs glint (`side` the rules', -1 a draw).
func finish(outcome: String, side := -1) -> void:
	_mood = outcome
	_hint = -1
	_lifted = -1
	_over = -1
	_down = false
	if side >= 0 and not Motion.reduce and _fx != null:
		var look := look_of(side)
		var mine: Array[int] = []
		for c in Rules.CELLS:
			if _cells[c] == look + 1:
				mine.append(c)
		var every := maxi(1, mine.size() / 9)
		var n := 0
		for i in range(0, mine.size(), every):
			var at := point_of(mid(mine[i]))
			_after(0.15 + 0.08 * n, func() -> void: _fx.sparkle(at, Pal.SUN_SPARK))
			n += 1
	_busy(1.2)
	queue_redraw()

## Whether a disc is still landing, turning or going off.
func is_busy() -> bool:
	return not _turning.is_empty() or not _pop.is_empty() or not _gone.is_empty()

# --- layout and time ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var space := SPACE_TALLY if tally and not still else SPACE
	var s := size.x / space.size.x if still else minf(size.x / space.size.x, size.y / space.size.y)
	var at := (size - space.size * s) * 0.5
	_xf = Transform2D(0.0, Vector2(s, s), 0.0, at - space.position * s)
	used_rect = Rect2(at, space.size * s)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var live := _t < _busy_until or _down
	for c: int in _turning.keys():
		if _t >= float(_turning[c].at) + FLIP:
			_turning.erase(c)
	for c: int in _pop.keys():
		if _t >= float(_pop[c]) + POP:
			_pop.erase(c)
	var i := 0
	while i < _gone.size():
		if _t >= float(_gone[i].at) + POP:
			_gone.remove_at(i)
		else:
			i += 1
	if is_busy():
		live = true
	var want := _want_share()
	if _share != want:
		_share = want if Motion.reduce else move_toward(_share, want, delta * 0.6)
		live = true
	if live:
		queue_redraw()

## The sun's share of the discs on the board, counting a disc as turned when
## it is seen to turn.
func _want_share() -> float:
	var sun := 0
	var moon := 0
	for c in Rules.CELLS:
		if _cells[c] == 0:
			continue
		var look := _cells[c] - 1
		if _turning.has(c) and _t < float(_turning[c].at) + FLIP * 0.5:
			look = int(_turning[c].from)
		if look == 0:
			sun += 1
		else:
			moon += 1
	return 0.5 if sun + moon == 0 else float(sun) / float(sun + moon)

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(seconds, 0.01)).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _fx != null:
		if cue_name in VARIED:
			pitch *= randf_range(TICK_VARY.x, TICK_VARY.y)
		_fx.cue(cue_name, pitch, volume_db)

# --- input ---

## The square a point of the board is over, -1 off the squares.
func cell_at(p: Vector2) -> int:
	var q := _xf.affine_inverse() * p
	if q.x < 0.0 or q.y < 0.0 or q.x >= GRID.x or q.y >= GRID.y:
		return -1
	return int(q.x / U) + int(q.y / U) * Rules.W

func _gui_input(event: InputEvent) -> void:
	if still or deaf or not interactive:
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
	var cell := cell_at(at)
	if release:
		if not _down:
			return
		_down = false
		_over = -1
		if cell >= 0:
			if rules.can(cell):
				chosen.emit(cell)
			else:
				_shake_at = _t
				_shake_cell = cell
				_busy(0.4)
				_cue("refused")
				refused.emit("taken" if _cells[cell] != 0 else "none")
		queue_redraw()
		return
	if press:
		_down = true
	if not _down:
		return
	if cell != _over:
		_over = cell
		_busy(0.2)
	queue_redraw()

# --- drawing ---

func _draw() -> void:
	if rules == null or used_rect.size.x <= 0.0:
		return
	if _base == null:
		_base = _build_base()
		_disc = [_build_disc(0), _build_disc(1)]
	_over_mesh = _build_over()
	_shown = [_base, _disc, _over_mesh]
	draw_mesh(_base, null, _xf)
	for g: Dictionary in _gone:
		var f := clampf((_t - float(g.at)) / POP, 0.0, 1.0)
		if f >= 1.0:
			continue
		var k := 1.0 - 0.35 * f
		draw_mesh(_disc[int(g.look)], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, mid(int(g.cell))), Color(1, 1, 1, 1.0 - f))
	for c in Rules.CELLS:
		if _cells[c] == 0:
			continue
		var look := _cells[c] - 1
		var at := mid(c)
		if _pop.has(c):
			var f := (_t - float(_pop[c])) / POP
			if f < 0.0:
				continue
			if f < 1.0:
				var k := lerpf(1.35, 1.0, ease(f, 0.4))
				draw_mesh(_disc[look], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, at), Color(1, 1, 1, minf(1.0, f * 2.5)))
				continue
		if _turning.has(c):
			var f := (_t - float(_turning[c].at)) / FLIP
			if f < 0.5:
				look = int(_turning[c].from)
			if f > 0.0 and f < 1.0:
				var lift := 1.0 + 0.16 * sin(PI * f)
				var across := maxf(0.04, absf(cos(PI * f)))
				draw_mesh(_disc[look], null, _xf * Transform2D(0.0, Vector2(across * lift, lift), 0.0, at))
				continue
		draw_mesh(_disc[look], null, _xf * Transform2D(0.0, at))
	if _over_mesh != null:
		draw_mesh(_over_mesh, null, _xf)

## The shadow the board throws on the deck, its wooden frame, the painted
## field and the lines between its squares.
func _build_base() -> ArrayMesh:
	var b := Face.Builder.new()
	var out := Vector2(FRAME, FRAME)
	Scenery.soft_disc(b, GRID * 0.5 + Vector2(0.0, 18.0), GRID.x * 0.66, 34.0, Color(0.15, 0.08, 0.03, 0.22))
	b.fan(Face.Builder.round_rect(-out + Vector2(0.0, 8.0), GRID + out * 2.0, 30.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(-out, GRID + out * 2.0, 30.0), WOOD)
	b.stroke(PackedVector2Array([Vector2(-6.0, -FRAME + 9.0), Vector2(GRID.x + 6.0, -FRAME + 9.0)]), 5.0, Color(WOOD_LIT, 0.8))
	b.fan(Face.Builder.round_rect(Vector2(-8.0, -8.0), GRID + Vector2(16.0, 16.0), 14.0), LINE)
	b.fan(Face.Builder.round_rect(Vector2.ZERO, GRID, 8.0), FIELD)
	# every other square a touch lighter, so a row is easy to follow
	for c in Rules.CELLS:
		if (c % Rules.W + c / Rules.W) % 2 == 0:
			b.fan(Face.Builder.round_rect(Vector2(c % Rules.W, c / Rules.W) * U + Vector2(3.0, 3.0), Vector2(U - 6.0, U - 6.0), 10.0), FIELD_LIT)
	for i in range(1, Rules.W):
		b.stroke(PackedVector2Array([Vector2(i * U, 4.0), Vector2(i * U, GRID.y - 4.0)]), 3.0, LINE)
		b.stroke(PackedVector2Array([Vector2(4.0, i * U), Vector2(GRID.x - 4.0, i * U)]), 3.0, LINE)
	for p: Vector2 in [Vector2(2, 2), Vector2(6, 2), Vector2(2, 6), Vector2(6, 6)]:
		b.disc(p * U, 7.0, LINE)
	return b.mesh()

## One disc about the origin: its shadow, the edge showing the face that is
## underneath, the face, a raised ring, a shine, and the side's stamp -- a
## sun with its rays, or a crescent -- so the two are told apart by more than
## their colour.
func _build_disc(look: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var r := DISC_R
	b.disc(Vector2(0.0, 8.0), r + 1.0, Color(0.05, 0.1, 0.2, 0.28))
	b.disc(Vector2(0.0, 4.5), r, DISC[1 - look].darkened(0.12))
	b.disc(Vector2.ZERO, r, RING[look])
	b.disc(Vector2(0.0, -1.0), r - 4.0, DISC[look])
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 10.0, r - 10.0), 2.5, Color(RING[look], 0.9), true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r - 6.5, PI * 1.08, PI * 1.5), 3.5, Color(SHINE[look], 0.75))
	if look == 0:
		b.disc(Vector2.ZERO, 9.5, STAMP[look])
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([d * 14.5, d * 20.5]), 4.5, STAMP[look])
	else:
		# a crescent: the outer arc of one disc, then back along another's
		var pts := Face.Builder.arc_points(Vector2(-2.0, 0.0), 17.0, PI * 0.32, PI * 1.68)
		pts.append_array(Face.Builder.arc_points(Vector2(6.0, 0.0), 14.0, PI * 1.5, PI * 0.5))
		b.polygon(pts, STAMP[look])
	return b.mesh()

## What lies over the discs: a dot on every square that may be played, the
## frame under the finger and the rings on what it would turn, the ring on
## the last disc set down, the bulb's ring, the other player's choice, and
## the tally.
func _build_over() -> ArrayMesh:
	var b := Face.Builder.new()
	if interactive and _mood == "":
		for c: int in rules.legal_moves():
			if c != _over or not _down:
				b.disc(mid(c), 9.0, Color(HALO, 0.55))
	if _down and _over >= 0:
		var ok: bool = rules.can(_over)
		var col := Color(HALO, 0.95) if ok else Color(Pal.BAD, 0.9)
		var at := Vector2(_over % Rules.W, _over / Rules.W) * U
		b.stroke(Face.Builder.round_rect(at + Vector2(5.0, 5.0), Vector2(U - 10.0, U - 10.0), 12.0), 6.0, col, true)
		if ok:
			b.disc(mid(_over), 13.0, Color(HALO, 0.9))
			for q: int in rules.flips(_over, rules.turn):
				b.stroke(Face.Builder.ring(mid(q), DISC_R + 4.0, DISC_R + 4.0), 5.0, Color(HALO, 0.95), true)
	var shake := _t - _shake_at
	if shake < 0.35 and _shake_cell >= 0:
		var m := mid(_shake_cell)
		var a := 0.9 * (1.0 - shake / 0.35)
		b.stroke(PackedVector2Array([m + Vector2(-16.0, -16.0), m + Vector2(16.0, 16.0)]), 8.0, Color(Pal.BAD, a))
		b.stroke(PackedVector2Array([m + Vector2(16.0, -16.0), m + Vector2(-16.0, 16.0)]), 8.0, Color(Pal.BAD, a))
	if _last >= 0 and _cells[_last] != 0 and not _pop.has(_last):
		b.stroke(Face.Builder.ring(mid(_last), DISC_R + 3.5, DISC_R + 3.5), 3.5, Color(HALO, 0.9), true)
	if _lifted >= 0:
		b.stroke(Face.Builder.ring(mid(_lifted), DISC_R - 8.0, DISC_R - 8.0), 6.0, Color(STAMP[1], 0.95), true)
	if _hint >= 0 and _cells[_hint] == 0:
		var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 5.0)
		var r := DISC_R - 9.0 + 4.0 * beat
		b.stroke(Face.Builder.ring(mid(_hint), r, r), 7.0, HINT, true)
		b.disc(mid(_hint), 8.0, HINT)
		if not Motion.reduce:
			_busy(0.2)
	if tally and not still:
		# The sun's discs from the left, the moon's from the right, a notch at
		# the half: who is ahead without counting.
		var w := GRID.x
		var cut := clampf(_share, 0.0, 1.0) * w
		b.fan(Face.Builder.round_rect(Vector2(-4.0, TALLY_Y - 4.0), Vector2(w + 8.0, TALLY_H + 8.0), (TALLY_H + 8.0) * 0.5), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(Vector2.ZERO + Vector2(0.0, TALLY_Y), Vector2(w, TALLY_H), TALLY_H * 0.5), DISC[1])
		if cut > TALLY_H:
			b.fan(Face.Builder.round_rect(Vector2(0.0, TALLY_Y), Vector2(cut, TALLY_H), TALLY_H * 0.5), DISC[0])
		b.stroke(PackedVector2Array([Vector2(w * 0.5, TALLY_Y - 9.0), Vector2(w * 0.5, TALLY_Y + TALLY_H + 9.0)]), 4.0, STAMP[0])
	return null if b.verts.is_empty() else b.mesh()
